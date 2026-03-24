-- UPDATE OUTING RESOURCES
-- Adds support for editing outings (linking detectives) and improved display (avatars)

-- 1. Update get_outings to return IDs and Avatars
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
             JOIN public.users u ON od.user_id = u.id -- note: checked table def, it is user_id not detective_id in create_outing
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

-- 2. Link Detective RPC
CREATE OR REPLACE FUNCTION link_outing_detective(p_outing_id UUID, p_user_id UUID)
RETURNS VOID AS $$
BEGIN
    INSERT INTO public.outing_detectives (outing_id, user_id)
    VALUES (p_outing_id, p_user_id)
    ON CONFLICT DO NOTHING;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Unlink Detective RPC
CREATE OR REPLACE FUNCTION unlink_outing_detective(p_outing_id UUID, p_user_id UUID)
RETURNS VOID AS $$
BEGIN
    DELETE FROM public.outing_detectives
    WHERE outing_id = p_outing_id AND user_id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Get Outing Detectives (helper for edit state if needed, though get_outings returns it)
CREATE OR REPLACE FUNCTION get_outing_detectives(p_outing_id UUID)
RETURNS TABLE (user_id UUID) AS $$
BEGIN
    RETURN QUERY
    SELECT od.user_id
    FROM public.outing_detectives od
    WHERE od.outing_id = p_outing_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
