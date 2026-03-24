-- COMPREHENSIVE FIX FOR INCIDENTS AND OUTINGS
-- Ensures all necessary tables and functions exist for the frontend to work correctly.

-- 1. ENSURE JUNCTION TABLES EXIST
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

CREATE TABLE IF NOT EXISTS public.outing_detectives (
    outing_id UUID REFERENCES public.outings(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.users(id),
    PRIMARY KEY (outing_id, user_id)
);

-- Enable RLS (just in case)
ALTER TABLE public.incident_gangs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.outing_gangs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.outing_detectives ENABLE ROW LEVEL SECURITY;

-- Helper policies (broad access for internal tools/authenticated users)
DROP POLICY IF EXISTS "Access incident_gangs" ON public.incident_gangs;
CREATE POLICY "Access incident_gangs" ON public.incident_gangs FOR ALL TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Access outing_gangs" ON public.outing_gangs;
CREATE POLICY "Access outing_gangs" ON public.outing_gangs FOR ALL TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Access outing_detectives" ON public.outing_detectives;
CREATE POLICY "Access outing_detectives" ON public.outing_detectives FOR ALL TO authenticated USING (true) WITH CHECK (true);


-- 2. GET INCIDENTS V2 (Matches Frontend Expectations)
DROP FUNCTION IF EXISTS get_incidents_v2();
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
    gang_id UUID,        -- Expected by Frontend
    gang_names TEXT[],   -- Expected by Frontend
    author_name TEXT,
    author_rank TEXT,
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
        i.id,
        i.title,
        i.location,
        i.occurred_at,
        i.tablet_incident_number,
        i.description,
        i.images,
        i.created_at,
        (SELECT ig.gang_id FROM public.incident_gangs ig WHERE ig.incident_id = i.id LIMIT 1),
        ARRAY(
            SELECT g.name 
            FROM public.incident_gangs ig 
            JOIN public.gangs g ON ig.gang_id = g.id 
            WHERE ig.incident_id = i.id
            ORDER BY g.name
        )::TEXT[],
        COALESCE(u.nombre || ' ' || u.apellido, 'Unknown'),
        COALESCE(u.rango, 'N/A'),
        u.profile_image,
        (i.author_id = v_uid) as is_author,
        (v_user_role IN ('Administrador', 'Coordinador', 'Comisionado', 'Detective')) as can_delete -- Permission check
    FROM public.incidents i
    LEFT JOIN public.users u ON i.author_id = u.id
    ORDER BY i.occurred_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 3. GET OUTINGS (Matches Frontend Expectations)
DROP FUNCTION IF EXISTS get_outings();
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
    gang_id UUID,       -- Expected by Frontend
    gang_names TEXT[],  -- Expected by Frontend
    author_name TEXT,
    author_rank TEXT,
    author_avatar TEXT,
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
        o.id,
        o.title,
        o.occurred_at,
        o.reason,
        o.info_obtained,
        o.images,
        o.created_at,
        COALESCE(
            (SELECT jsonb_agg(jsonb_build_object(
                'id', u.id, 
                'name', u.nombre || ' ' || u.apellido, 
                'rank', u.rango,
                'avatar', u.profile_image
            ))
             FROM public.outing_detectives od
             JOIN public.users u ON od.user_id = u.id 
             WHERE od.outing_id = o.id),
            '[]'::jsonb
        ),
        (SELECT og.gang_id FROM public.outing_gangs og WHERE og.outing_id = o.id LIMIT 1),
        ARRAY(
            SELECT g.name 
            FROM public.outing_gangs og 
            JOIN public.gangs g ON og.gang_id = g.id 
            WHERE og.outing_id = o.id
            ORDER BY g.name
        )::TEXT[],
        COALESCE(u.nombre || ' ' || u.apellido, 'Unknown'),
        COALESCE(u.rango, 'N/A'),
        u.profile_image,
        (v_user_role IN ('Administrador', 'Coordinador', 'Comisionado') OR o.created_by = v_uid) as can_delete
    FROM public.outings o
    LEFT JOIN public.users u ON o.created_by = u.id
    ORDER BY o.occurred_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 4. HELPER RPCS FOR EDITING
CREATE OR REPLACE FUNCTION get_incident_gangs(p_incident_id UUID)
RETURNS TABLE (gang_id UUID, gang_name TEXT) AS $$
BEGIN
    RETURN QUERY
    SELECT g.id, g.name
    FROM public.incident_gangs ig
    JOIN public.gangs g ON ig.gang_id = g.id
    WHERE ig.incident_id = p_incident_id
    ORDER BY g.name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_outing_gangs(p_outing_id UUID)
RETURNS TABLE (gang_id UUID, gang_name TEXT) AS $$
BEGIN
    RETURN QUERY
    SELECT g.id, g.name
    FROM public.outing_gangs og
    JOIN public.gangs g ON og.gang_id = g.id
    WHERE og.outing_id = p_outing_id
    ORDER BY g.name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_outing_detectives(p_outing_id UUID)
RETURNS TABLE (user_id UUID) AS $$
BEGIN
    RETURN QUERY
    SELECT od.user_id
    FROM public.outing_detectives od
    WHERE od.outing_id = p_outing_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 5. LINK/UNLINK RPCS
CREATE OR REPLACE FUNCTION link_incident_gang(p_incident_id UUID, p_gang_id UUID)
RETURNS VOID AS $$
BEGIN
    INSERT INTO public.incident_gangs (incident_id, gang_id) VALUES (p_incident_id, p_gang_id) ON CONFLICT DO NOTHING;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION unlink_incident_gang(p_incident_id UUID, p_gang_id UUID)
RETURNS VOID AS $$
BEGIN
    DELETE FROM public.incident_gangs WHERE incident_id = p_incident_id AND gang_id = p_gang_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION link_outing_gang(p_outing_id UUID, p_gang_id UUID)
RETURNS VOID AS $$
BEGIN
    INSERT INTO public.outing_gangs (outing_id, gang_id) VALUES (p_outing_id, p_gang_id) ON CONFLICT DO NOTHING;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION unlink_outing_gang(p_outing_id UUID, p_gang_id UUID)
RETURNS VOID AS $$
BEGIN
    DELETE FROM public.outing_gangs WHERE outing_id = p_outing_id AND gang_id = p_gang_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION link_outing_detective(p_outing_id UUID, p_user_id UUID)
RETURNS VOID AS $$
BEGIN
    INSERT INTO public.outing_detectives (outing_id, user_id) VALUES (p_outing_id, p_user_id) ON CONFLICT DO NOTHING;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION unlink_outing_detective(p_outing_id UUID, p_user_id UUID)
RETURNS VOID AS $$
BEGIN
    DELETE FROM public.outing_detectives WHERE outing_id = p_outing_id AND user_id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
