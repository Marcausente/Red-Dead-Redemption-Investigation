-- LINK INCIDENTS TO INTERROGATIONS
-- 1. Create Junction Table
CREATE TABLE IF NOT EXISTS public.incident_interrogations (
    incident_id UUID REFERENCES public.incidents(id) ON DELETE CASCADE,
    interrogation_id UUID REFERENCES public.interrogations(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    PRIMARY KEY (incident_id, interrogation_id)
);

ALTER TABLE public.incident_interrogations ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Access incident_interrogations" ON public.incident_interrogations;
CREATE POLICY "Access incident_interrogations" ON public.incident_interrogations FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- 2. Link/Unlink RPCs
CREATE OR REPLACE FUNCTION link_incident_interrogation(p_incident_id UUID, p_interrogation_id UUID)
RETURNS VOID AS $$
BEGIN
    INSERT INTO public.incident_interrogations (incident_id, interrogation_id)
    VALUES (p_incident_id, p_interrogation_id)
    ON CONFLICT DO NOTHING;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION unlink_incident_interrogation(p_incident_id UUID, p_interrogation_id UUID)
RETURNS VOID AS $$
BEGIN
    DELETE FROM public.incident_interrogations
    WHERE incident_id = p_incident_id AND interrogation_id = p_interrogation_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_incident_interrogations(p_incident_id UUID)
RETURNS TABLE (id UUID, title TEXT, created_at TIMESTAMP WITH TIME ZONE) AS $$
BEGIN
    RETURN QUERY
    SELECT i.id, i.title, i.created_at
    FROM public.incident_interrogations ii
    JOIN public.interrogations i ON ii.interrogation_id = i.id
    WHERE ii.incident_id = p_incident_id
    ORDER BY i.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Update get_incidents_v2 to Include Linked Interrogations
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
    gang_id UUID,
    gang_names TEXT[],
    author_name TEXT,
    author_rank TEXT,
    author_avatar TEXT,
    is_author BOOLEAN,
    can_delete BOOLEAN,
    interrogations JSONB -- NEW COLUMN
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
        COALESCE(u.rango::text, 'N/A'),
        u.profile_image,
        (i.author_id = v_uid) as is_author,
        (v_user_role IN ('Administrador', 'Coordinador', 'Comisionado', 'Detective')) as can_delete,
        -- Fetch linked interrogations as JSON array
        COALESCE(
            (SELECT jsonb_agg(jsonb_build_object(
                'id', inter.id,
                'title', inter.title
            ))
            FROM public.incident_interrogations ii
            JOIN public.interrogations inter ON ii.interrogation_id = inter.id
            WHERE ii.incident_id = i.id),
            '[]'::jsonb
        ) as interrogations
    FROM public.incidents i
    LEFT JOIN public.users u ON i.author_id = u.id
    ORDER BY i.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
