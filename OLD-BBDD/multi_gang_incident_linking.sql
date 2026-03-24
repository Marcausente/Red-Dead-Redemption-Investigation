-- MULTI-GANG INCIDENT LINKING SYSTEM
-- Allows incidents and outings to be linked to multiple gangs simultaneously

-- 1. Create Junction Tables
CREATE TABLE IF NOT EXISTS public.incident_gangs (
    incident_id UUID REFERENCES public.incidents(id) ON DELETE CASCADE,
    gang_id UUID REFERENCES public.gangs(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    PRIMARY KEY (incident_id, gang_id)
);

CREATE TABLE IF NOT EXISTS public.outing_gangs (
    outing_id UUID REFERENCES public.outings(id) ON DELETE CASCADE,
    gang_id UUID REFERENCES public.gangs(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    PRIMARY KEY (outing_id, gang_id)
);

-- Enable RLS
ALTER TABLE public.incident_gangs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.outing_gangs ENABLE ROW LEVEL SECURITY;

-- Policies
DROP POLICY IF EXISTS "Allow read incident_gangs" ON public.incident_gangs;
CREATE POLICY "Allow read incident_gangs" ON public.incident_gangs FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Allow insert incident_gangs" ON public.incident_gangs;
CREATE POLICY "Allow insert incident_gangs" ON public.incident_gangs FOR INSERT TO authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "Allow delete incident_gangs" ON public.incident_gangs;
CREATE POLICY "Allow delete incident_gangs" ON public.incident_gangs FOR DELETE TO authenticated USING (true);

DROP POLICY IF EXISTS "Allow read outing_gangs" ON public.outing_gangs;
CREATE POLICY "Allow read outing_gangs" ON public.outing_gangs FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Allow insert outing_gangs" ON public.outing_gangs;
CREATE POLICY "Allow insert outing_gangs" ON public.outing_gangs FOR INSERT TO authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "Allow delete outing_gangs" ON public.outing_gangs;
CREATE POLICY "Allow delete outing_gangs" ON public.outing_gangs FOR DELETE TO authenticated USING (true);

-- 2. Migrate existing data from gang_id to junction tables
INSERT INTO public.incident_gangs (incident_id, gang_id)
SELECT id, gang_id FROM public.incidents WHERE gang_id IS NOT NULL
ON CONFLICT DO NOTHING;

INSERT INTO public.outing_gangs (outing_id, gang_id)
SELECT id, gang_id FROM public.outings WHERE gang_id IS NOT NULL
ON CONFLICT DO NOTHING;

-- 3. Drop existing functions to allow signature changes
DROP FUNCTION IF EXISTS get_incidents_v2();
DROP FUNCTION IF EXISTS get_outings();
DROP FUNCTION IF EXISTS get_gangs_data();

-- 4. Update get_incidents_v2 to return gang links as array
CREATE OR REPLACE FUNCTION get_incidents_v2()
RETURNS TABLE (
    record_id UUID,
    title TEXT,
    location TEXT,
    occurred_at TIMESTAMP WITH TIME ZONE,
    tablet_number TEXT,
    description TEXT,
    images JSONB,
    created_at TIMESTAMP WITH TIME ZONE,
    gang_id UUID, -- Keep for backward compatibility (will be first gang or null)
    gang_names TEXT[] -- NEW: Array of gang names
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        i.id,
        i.title,
        i.location,
        i.occurred_at,
        i.tablet_number,
        i.description,
        i.images,
        i.created_at,
        (SELECT ig.gang_id FROM public.incident_gangs ig WHERE ig.incident_id = i.id LIMIT 1), -- First gang for compatibility
        ARRAY(
            SELECT g.name 
            FROM public.incident_gangs ig 
            JOIN public.gangs g ON ig.gang_id = g.id 
            WHERE ig.incident_id = i.id
            ORDER BY g.name
        ) as gang_names
    FROM public.incidents i
    ORDER BY i.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Update get_outings to return gang links as array
CREATE OR REPLACE FUNCTION get_outings()
RETURNS TABLE (
    record_id UUID,
    title TEXT,
    occurred_at TIMESTAMP WITH TIME ZONE,
    reason TEXT,
    info_obtained TEXT,
    images JSONB,
    created_at TIMESTAMP WITH TIME ZONE,
    detectives JSONB,
    gang_id UUID, -- Keep for backward compatibility
    gang_names TEXT[] -- NEW: Array of gang names
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        o.id,
        o.title,
        o.occurred_at,
        o.reason,
        o.info_obtained,
        o.images,
        o.created_at,
        COALESCE(
            (SELECT jsonb_agg(jsonb_build_object('name', u.nombre || ' ' || u.apellido, 'rank', u.rango))
             FROM public.outing_detectives od
             JOIN public.users u ON od.detective_id = u.id
             WHERE od.outing_id = o.id),
            '[]'::jsonb
        ),
        (SELECT og.gang_id FROM public.outing_gangs og WHERE og.outing_id = o.id LIMIT 1), -- First gang for compatibility
        ARRAY(
            SELECT g.name 
            FROM public.outing_gangs og 
            JOIN public.gangs g ON og.gang_id = g.id 
            WHERE og.outing_id = o.id
            ORDER BY g.name
        ) as gang_names
    FROM public.outings o
    ORDER BY o.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Update link_incident_gang to use junction table
CREATE OR REPLACE FUNCTION link_incident_gang(p_incident_id UUID, p_gang_id UUID)
RETURNS VOID AS $$
BEGIN
    INSERT INTO public.incident_gangs (incident_id, gang_id)
    VALUES (p_incident_id, p_gang_id)
    ON CONFLICT DO NOTHING;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. Update link_outing_gang to use junction table
CREATE OR REPLACE FUNCTION link_outing_gang(p_outing_id UUID, p_gang_id UUID)
RETURNS VOID AS $$
BEGIN
    INSERT INTO public.outing_gangs (outing_id, gang_id)
    VALUES (p_outing_id, p_gang_id)
    ON CONFLICT DO NOTHING;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. Create unlink functions
CREATE OR REPLACE FUNCTION unlink_incident_gang(p_incident_id UUID, p_gang_id UUID)
RETURNS VOID AS $$
BEGIN
    DELETE FROM public.incident_gangs 
    WHERE incident_id = p_incident_id AND gang_id = p_gang_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION unlink_outing_gang(p_outing_id UUID, p_gang_id UUID)
RETURNS VOID AS $$
BEGIN
    DELETE FROM public.outing_gangs 
    WHERE outing_id = p_outing_id AND gang_id = p_gang_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 8. Create update_incident function for editing
CREATE OR REPLACE FUNCTION update_incident(
    p_incident_id UUID,
    p_title TEXT,
    p_location TEXT,
    p_occurred_at TIMESTAMP WITH TIME ZONE,
    p_tablet_number TEXT,
    p_description TEXT
)
RETURNS VOID AS $$
BEGIN
    UPDATE public.incidents
    SET title = p_title,
        location = p_location,
        occurred_at = p_occurred_at,
        tablet_number = p_tablet_number,
        description = p_description
    WHERE id = p_incident_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 9. Create update_outing function for editing
CREATE OR REPLACE FUNCTION update_outing(
    p_outing_id UUID,
    p_title TEXT,
    p_occurred_at TIMESTAMP WITH TIME ZONE,
    p_reason TEXT,
    p_info_obtained TEXT
)
RETURNS VOID AS $$
BEGIN
    UPDATE public.outings
    SET title = p_title,
        occurred_at = p_occurred_at,
        reason = p_reason,
        info_obtained = p_info_obtained
    WHERE id = p_outing_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 10. Update get_gangs_data to count from junction tables
CREATE OR REPLACE FUNCTION get_gangs_data()
RETURNS TABLE (
    gang_id UUID,
    name TEXT,
    color TEXT,
    zones_image TEXT,
    is_archived BOOLEAN,
    vehicles JSONB,
    homes JSONB,
    members JSONB,
    info JSONB,
    incident_count BIGINT,
    outing_count BIGINT
) AS $$
BEGIN
    IF NOT auth_is_gang_authorized() THEN 
        RETURN;
    END IF;

    RETURN QUERY
    SELECT 
        g.id AS gang_id,
        g.name,
        g.color,
        g.zones_image,
        g.is_archived,
        COALESCE((
            SELECT jsonb_agg(jsonb_build_object('id', v.id, 'model', v.model, 'plate', v.plate, 'owner', v.owner_name, 'notes', v.notes, 'images', v.images))
            FROM public.gang_vehicles v WHERE v.gang_id = g.id
        ), '[]'::jsonb),
        COALESCE((
            SELECT jsonb_agg(jsonb_build_object('id', h.id, 'owner', h.owner_name, 'notes', h.address_notes, 'images', h.images))
            FROM public.gang_homes h WHERE h.gang_id = g.id
        ), '[]'::jsonb),
        COALESCE((
            SELECT jsonb_agg(jsonb_build_object('id', m.id, 'name', m.name, 'role', m.role, 'photo', m.photo, 'notes', m.notes, 'status', m.status))
            FROM public.gang_members m WHERE m.gang_id = g.id
        ), '[]'::jsonb),
        COALESCE((
            SELECT jsonb_agg(jsonb_build_object('id', i.id, 'type', i.type, 'content', i.content, 'images', i.images, 'author', (SELECT nombre||' '||apellido FROM public.users WHERE id=i.author_id)))
            FROM public.gang_info i WHERE i.gang_id = g.id
        ), '[]'::jsonb),
        (SELECT COUNT(*) FROM public.incident_gangs ig WHERE ig.gang_id = g.id), -- Updated
        (SELECT COUNT(*) FROM public.outing_gangs og WHERE og.gang_id = g.id) -- Updated
    FROM public.gangs g
    ORDER BY g.created_at ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
