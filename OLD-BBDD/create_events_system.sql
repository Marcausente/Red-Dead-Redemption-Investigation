-- Create the events table
CREATE TABLE IF NOT EXISTS public.events (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT,
    event_date TIMESTAMP WITH TIME ZONE NOT NULL,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS
ALTER TABLE public.events ENABLE ROW LEVEL SECURITY;

-- Policies for events
CREATE POLICY "Enable read access for all users" ON public.events FOR SELECT USING (true);

CREATE POLICY "Enable insert for authenticated users with valid role" ON public.events 
FOR INSERT WITH CHECK (
    auth.uid() = created_by AND 
    EXISTS (
        SELECT 1 FROM users WHERE id = auth.uid() AND rol IN ('Detective', 'Coordinador', 'Comisionado', 'Administrador')
    )
);

CREATE POLICY "Enable update for users based on id" ON public.events 
FOR UPDATE USING (
    auth.uid() = created_by OR
    EXISTS (
        SELECT 1 FROM users WHERE id = auth.uid() AND rol IN ('Coordinador', 'Comisionado', 'Administrador')
    )
);

CREATE POLICY "Enable delete for users based on id" ON public.events 
FOR DELETE USING (
    auth.uid() = created_by OR
    EXISTS (
        SELECT 1 FROM users WHERE id = auth.uid() AND rol IN ('Coordinador', 'Comisionado', 'Administrador')
    )
);


-- Create the event participants table
CREATE TABLE IF NOT EXISTS public.event_participants (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    event_id UUID REFERENCES public.events(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(event_id, user_id)
);

-- Enable RLS
ALTER TABLE public.event_participants ENABLE ROW LEVEL SECURITY;

-- Policies for event participants
CREATE POLICY "Enable read access for all users" ON public.event_participants FOR SELECT USING (true);

CREATE POLICY "Enable insert for authenticated users" ON public.event_participants 
FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Enable delete for users based on user_id" ON public.event_participants 
FOR DELETE USING (auth.uid() = user_id);

-- RPC to get upcoming events with participation status
CREATE OR REPLACE FUNCTION get_upcoming_events(p_user_id UUID)
RETURNS TABLE (
    id UUID,
    title TEXT,
    description TEXT,
    event_date TIMESTAMP WITH TIME ZONE,
    created_by UUID,
    created_at TIMESTAMP WITH TIME ZONE,
    participant_count BIGINT,
    is_participating BOOLEAN,
    author_name TEXT,
    author_rank TEXT,
    author_image TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        e.id,
        e.title,
        e.description,
        e.event_date,
        e.created_by,
        e.created_at,
        (SELECT COUNT(*) FROM event_participants ep WHERE ep.event_id = e.id) AS participant_count,
        EXISTS (SELECT 1 FROM event_participants ep WHERE ep.event_id = e.id AND ep.user_id = p_user_id) AS is_participating,
        u.nombre || ' ' || u.apellido AS author_name,
        u.rango::text AS author_rank,
        u.profile_image AS author_image
    FROM events e
    LEFT JOIN users u ON e.created_by = u.id
    WHERE e.event_date >= CURRENT_DATE
    ORDER BY e.event_date ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC to toggle participation in an event
CREATE OR REPLACE FUNCTION toggle_event_registration(p_event_id UUID, p_user_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    v_exists BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM event_participants ep WHERE ep.event_id = p_event_id AND ep.user_id = p_user_id
    ) INTO v_exists;

    IF v_exists THEN
        DELETE FROM event_participants WHERE event_id = p_event_id AND user_id = p_user_id;
        RETURN FALSE; -- Currently not participating
    ELSE
        INSERT INTO event_participants (event_id, user_id) VALUES (p_event_id, p_user_id);
        RETURN TRUE; -- Currently participating
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC to create event safely mapping to auth
CREATE OR REPLACE FUNCTION create_event(p_title TEXT, p_description TEXT, p_event_date TIMESTAMP WITH TIME ZONE)
RETURNS UUID AS $$
DECLARE
    v_event_id UUID;
    v_user_role TEXT;
BEGIN
    -- Check permissions
    SELECT rol INTO v_user_role FROM users WHERE id = auth.uid();
    IF v_user_role NOT IN ('Detective', 'Coordinador', 'Comisionado', 'Administrador', 'DOJ General', 'Fiscal General', 'Juez', 'Juez Supremo') THEN
        RAISE EXCEPTION 'No permissions to create an event';
    END IF;

    INSERT INTO events (title, description, event_date, created_by)
    VALUES (p_title, p_description, p_event_date, auth.uid())
    RETURNING id INTO v_event_id;

    RETURN v_event_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC to update event safely
CREATE OR REPLACE FUNCTION update_event(p_id UUID, p_title TEXT, p_description TEXT, p_event_date TIMESTAMP WITH TIME ZONE)
RETURNS VOID AS $$
DECLARE
    v_event RECORD;
    v_user_role TEXT;
BEGIN
    SELECT * INTO v_event FROM events WHERE id = p_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Event not found';
    END IF;

    SELECT rol INTO v_user_role FROM users WHERE id = auth.uid();
    
    IF v_event.created_by != auth.uid() AND v_user_role NOT IN ('Coordinador', 'Comisionado', 'Administrador', 'Juez Supremo') THEN
       RAISE EXCEPTION 'No permissions to update this event';
    END IF;

    UPDATE events 
    SET title = p_title, description = p_description, event_date = p_event_date 
    WHERE id = p_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC to delete event safely
CREATE OR REPLACE FUNCTION delete_event(p_id UUID)
RETURNS VOID AS $$
DECLARE
    v_event RECORD;
    v_user_role TEXT;
BEGIN
    SELECT * INTO v_event FROM events WHERE id = p_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Event not found';
    END IF;

    SELECT rol INTO v_user_role FROM users WHERE id = auth.uid();
    
    IF v_event.created_by != auth.uid() AND v_user_role NOT IN ('Coordinador', 'Comisionado', 'Administrador', 'Juez Supremo') THEN
       RAISE EXCEPTION 'No permissions to update this event';
    END IF;

    DELETE FROM events WHERE id = p_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
