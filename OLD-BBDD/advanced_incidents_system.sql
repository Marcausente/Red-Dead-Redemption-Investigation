-- ADVANCED INCIDENTS & OUTINGS SYSTEM
-- FIXED V4: Added casts ::text for enum types (app_rank) to avoid type mismatches.

-- 1. Create/Upgrade Incidents Table
CREATE TABLE IF NOT EXISTS public.incidents (
    id UUID DEFAULT extensions.uuid_generate_v4() PRIMARY KEY,
    title TEXT NOT NULL,
    location TEXT,
    occurred_at TIMESTAMP WITH TIME ZONE,
    description TEXT,
    author_id UUID REFERENCES public.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS for Incidents
ALTER TABLE public.incidents ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Everyone can view incidents" ON public.incidents;
CREATE POLICY "Everyone can view incidents" ON public.incidents FOR SELECT USING (true);
DROP POLICY IF EXISTS "Authenticated users can insert incidents" ON public.incidents;
CREATE POLICY "Authenticated users can insert incidents" ON public.incidents FOR INSERT WITH CHECK (auth.role() = 'authenticated');
DROP POLICY IF EXISTS "Authenticated users can delete incidents" ON public.incidents;
CREATE POLICY "Authenticated users can delete incidents" ON public.incidents FOR DELETE USING (auth.role() = 'authenticated');


DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='incidents' AND column_name='tablet_incident_number') THEN
        ALTER TABLE public.incidents ADD COLUMN tablet_incident_number TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='incidents' AND column_name='images') THEN
        ALTER TABLE public.incidents ADD COLUMN images JSONB DEFAULT '[]'::jsonb;
    END IF;
    -- Placeholder for future Gangs integration
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='incidents' AND column_name='gang_id') THEN
        ALTER TABLE public.incidents ADD COLUMN gang_id UUID;
    END IF;
END
$$;

-- 2. Create Outings Tables
CREATE TABLE IF NOT EXISTS public.outings (
    id UUID DEFAULT extensions.uuid_generate_v4() PRIMARY KEY,
    title TEXT NOT NULL,
    occurred_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    reason TEXT,
    info_obtained TEXT,
    images JSONB DEFAULT '[]'::jsonb,
    gang_id UUID, -- Placeholder
    created_by UUID REFERENCES public.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
ALTER TABLE public.outings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Everyone can view outings" ON public.outings;
CREATE POLICY "Everyone can view outings" ON public.outings FOR SELECT USING (true);
DROP POLICY IF EXISTS "Auth can insert outings" ON public.outings;
CREATE POLICY "Auth can insert outings" ON public.outings FOR INSERT WITH CHECK (auth.role() = 'authenticated');
DROP POLICY IF EXISTS "Auth can delete outings" ON public.outings;
CREATE POLICY "Auth can delete outings" ON public.outings FOR DELETE USING (auth.role() = 'authenticated');


CREATE TABLE IF NOT EXISTS public.outing_detectives (
    outing_id UUID REFERENCES public.outings(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.users(id),
    PRIMARY KEY (outing_id, user_id)
);
ALTER TABLE public.outing_detectives ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Everyone can view outing_detectives" ON public.outing_detectives;
CREATE POLICY "Everyone can view outing_detectives" ON public.outing_detectives FOR SELECT USING (true);
DROP POLICY IF EXISTS "Auth can insert outing_detectives" ON public.outing_detectives;
CREATE POLICY "Auth can insert outing_detectives" ON public.outing_detectives FOR INSERT WITH CHECK (auth.role() = 'authenticated');


-- 3. RPCs

-- Create Incident V2
CREATE OR REPLACE FUNCTION create_incident_v2(
    p_title TEXT,
    p_location TEXT,
    p_occurred_at TIMESTAMP WITH TIME ZONE,
    p_tablet_number TEXT,
    p_description TEXT,
    p_images JSONB DEFAULT '[]'::jsonb
)
RETURNS UUID AS $$
DECLARE
    v_new_id UUID;
BEGIN
    INSERT INTO public.incidents (title, location, occurred_at, tablet_incident_number, description, images, author_id)
    VALUES (p_title, p_location, p_occurred_at, p_tablet_number, p_description, p_images, auth.uid())
    RETURNING id INTO v_new_id;
    RETURN v_new_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Get Incidents V2
DROP FUNCTION IF EXISTS get_incidents_v2();
CREATE OR REPLACE FUNCTION get_incidents_v2()
RETURNS TABLE (
    record_id UUID,
    title TEXT,
    location TEXT,
    occurred_at TIMESTAMP WITH TIME ZONE,
    tablet_incident_number TEXT,
    description TEXT,
    images JSONB,
    created_at TIMESTAMP WITH TIME ZONE,
    author_name TEXT,
    author_rank TEXT, -- This expects TEXT
    author_avatar TEXT,
    is_author BOOLEAN,
    can_delete BOOLEAN
) AS $$
DECLARE
    v_uid UUID;
    v_user_role TEXT;
BEGIN
    v_uid := auth.uid();
    SELECT TRIM(u_auth.rol::text) INTO v_user_role FROM public.users u_auth WHERE u_auth.id = v_uid;

    RETURN QUERY
    SELECT 
        i.id AS record_id,
        i.title,
        i.location,
        i.occurred_at,
        i.tablet_incident_number,
        i.description,
        i.images,
        i.created_at,
        (u.nombre || ' ' || u.apellido) as author_name,
        u.rango::text as author_rank, -- CAST TO TEXT
        u.profile_image as author_avatar,
        (i.author_id = v_uid) as is_author,
        (v_user_role IN ('Administrador', 'Coordinador', 'Comisionado')) as can_delete
    FROM public.incidents i
    LEFT JOIN public.users u ON i.author_id = u.id
    ORDER BY i.occurred_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- Create Outing
CREATE OR REPLACE FUNCTION create_outing(
    p_title TEXT,
    p_occurred_at TIMESTAMP WITH TIME ZONE,
    p_reason TEXT,
    p_info_obtained TEXT,
    p_images JSONB DEFAULT '[]'::jsonb,
    p_detective_ids UUID[] DEFAULT '{}'
)
RETURNS UUID AS $$
DECLARE
    v_new_id UUID;
    v_user_id UUID;
BEGIN
    INSERT INTO public.outings (title, occurred_at, reason, info_obtained, images, created_by)
    VALUES (p_title, p_occurred_at, p_reason, p_info_obtained, p_images, auth.uid())
    RETURNING id INTO v_new_id;

    -- Insert Detectives
    IF array_length(p_detective_ids, 1) > 0 THEN
        FOREACH v_user_id IN ARRAY p_detective_ids
        LOOP
            INSERT INTO public.outing_detectives (outing_id, user_id) VALUES (v_new_id, v_user_id);
        END LOOP;
    END IF;

    RETURN v_new_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- Get Outings
DROP FUNCTION IF EXISTS get_outings();
CREATE OR REPLACE FUNCTION get_outings()
RETURNS TABLE (
    record_id UUID,
    title TEXT,
    occurred_at TIMESTAMP WITH TIME ZONE,
    reason TEXT,
    info_obtained TEXT,
    images JSONB,
    created_by_name TEXT,
    created_at TIMESTAMP WITH TIME ZONE,
    detectives JSONB,
    can_delete BOOLEAN
) AS $$
DECLARE
    v_uid UUID;
    v_user_role TEXT;
BEGIN
    v_uid := auth.uid();
    SELECT TRIM(u_auth.rol::text) INTO v_user_role FROM public.users u_auth WHERE u_auth.id = v_uid;

    RETURN QUERY
    SELECT 
        o.id AS record_id,
        o.title,
        o.occurred_at,
        o.reason,
        o.info_obtained,
        o.images,
        (u.nombre || ' ' || u.apellido) as created_by_name,
        o.created_at,
        COALESCE((
            SELECT jsonb_agg(jsonb_build_object('name', du.nombre || ' ' || du.apellido, 'rank', du.rango::text, 'avatar', du.profile_image)) -- CAST TO TEXT
            FROM public.outing_detectives od
            JOIN public.users du ON od.user_id = du.id
            WHERE od.outing_id = o.id
        ), '[]'::jsonb) as detectives,
        (v_user_role IN ('Administrador', 'Coordinador', 'Comisionado') OR o.created_by = v_uid) as can_delete
    FROM public.outings o
    LEFT JOIN public.users u ON o.created_by = u.id
    ORDER BY o.occurred_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Delete functions
CREATE OR REPLACE FUNCTION delete_incident(p_id UUID) RETURNS VOID AS $$
DECLARE
    v_uid UUID;
    v_user_role TEXT;
    v_author_id UUID;
BEGIN
    v_uid := auth.uid();
    SELECT TRIM(rol::text) INTO v_user_role FROM public.users WHERE id = v_uid;
    SELECT author_id INTO v_author_id FROM public.incidents WHERE id = p_id;

    IF (v_user_role IN ('Administrador', 'Coordinador', 'Comisionado', 'Detective')) OR (v_author_id = v_uid) THEN
        DELETE FROM public.incidents WHERE id = p_id;
    ELSE
         RAISE EXCEPTION 'Access Denied: You cannot delete this incident.';
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION delete_outing(p_id UUID) RETURNS VOID AS $$
DECLARE
    v_uid UUID;
    v_user_role TEXT;
    v_creator_id UUID;
BEGIN
    v_uid := auth.uid();
    SELECT TRIM(rol::text) INTO v_user_role FROM public.users WHERE id = v_uid;
    SELECT created_by INTO v_creator_id FROM public.outings WHERE id = p_id;

    IF (v_user_role IN ('Administrador', 'Coordinador', 'Comisionado', 'Detective')) OR (v_creator_id = v_uid) THEN
        DELETE FROM public.outings WHERE id = p_id;
    ELSE
         RAISE EXCEPTION 'Access Denied: You cannot delete this outing.';
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
