-- LINK OUTINGS TO INTERROGATIONS

-- 1. Create Junction Table
CREATE TABLE IF NOT EXISTS public.outing_interrogations (
    outing_id UUID REFERENCES public.outings(id) ON DELETE CASCADE,
    interrogation_id UUID REFERENCES public.interrogations(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    PRIMARY KEY (outing_id, interrogation_id)
);

ALTER TABLE public.outing_interrogations ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Access outing_interrogations" ON public.outing_interrogations;
CREATE POLICY "Access outing_interrogations" ON public.outing_interrogations FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- 2. Link/Unlink RPCs
CREATE OR REPLACE FUNCTION link_outing_interrogation(p_outing_id UUID, p_interrogation_id UUID)
RETURNS VOID AS $$
BEGIN
    INSERT INTO public.outing_interrogations (outing_id, interrogation_id)
    VALUES (p_outing_id, p_interrogation_id)
    ON CONFLICT DO NOTHING;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION unlink_outing_interrogation(p_outing_id UUID, p_interrogation_id UUID)
RETURNS VOID AS $$
BEGIN
    DELETE FROM public.outing_interrogations
    WHERE outing_id = p_outing_id AND interrogation_id = p_interrogation_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_outing_interrogations(p_outing_id UUID)
RETURNS TABLE (id UUID, title TEXT, created_at TIMESTAMP WITH TIME ZONE) AS $$
BEGIN
    RETURN QUERY
    SELECT i.id, i.title, i.created_at
    FROM public.outing_interrogations oi
    JOIN public.interrogations i ON oi.interrogation_id = i.id
    WHERE oi.outing_id = p_outing_id
    ORDER BY i.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Update get_outings to Include Linked Interrogations
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
    gang_id UUID,
    gang_names TEXT[],
    author_name TEXT,
    author_rank TEXT,
    author_avatar TEXT,
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
        COALESCE(u.rango::text, 'N/A'),
        u.profile_image,
        (v_user_role IN ('Administrador', 'Coordinador', 'Comisionado', 'Detective') OR o.created_by = v_uid) as can_delete,
        -- Fetch linked interrogations as JSON array
        COALESCE(
            (SELECT jsonb_agg(jsonb_build_object(
                'id', inter.id,
                'title', inter.title
            ))
            FROM public.outing_interrogations oi
            JOIN public.interrogations inter ON oi.interrogation_id = inter.id
            WHERE oi.outing_id = o.id),
            '[]'::jsonb
        ) as interrogations
    FROM public.outings o
    LEFT JOIN public.users u ON o.created_by = u.id
    ORDER BY o.occurred_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
