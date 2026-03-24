-- FINAL FIX: Compatible RPC with all required fields
-- This maintains backward compatibility with the frontend

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
    author_rank TEXT,
    author_avatar TEXT,
    is_author BOOLEAN,
    can_delete BOOLEAN,
    gang_id UUID,
    gang_names TEXT[]
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
        COALESCE(u.nombre || ' ' || u.apellido, 'Unknown') as author_name,
        COALESCE(u.rango::text, 'N/A') as author_rank,
        u.profile_image as author_avatar,
        (i.author_id = v_uid) as is_author,
        (v_user_role IN ('Administrador', 'Coordinador', 'Comisionado')) as can_delete,
        (SELECT ig.gang_id FROM public.incident_gangs ig WHERE ig.incident_id = i.id LIMIT 1),
        ARRAY(
            SELECT g.name 
            FROM public.incident_gangs ig 
            JOIN public.gangs g ON ig.gang_id = g.id 
            WHERE ig.incident_id = i.id
            ORDER BY g.name
        )::TEXT[]
    FROM public.incidents i
    LEFT JOIN public.users u ON i.author_id = u.id
    ORDER BY i.occurred_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

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
        (SELECT og.gang_id FROM public.outing_gangs og WHERE og.outing_id = o.id LIMIT 1),
        ARRAY(
            SELECT g.name 
            FROM public.outing_gangs og 
            JOIN public.gangs g ON og.gang_id = g.id 
            WHERE og.outing_id = o.id
            ORDER BY g.name
        )::TEXT[],
        COALESCE(u.nombre || ' ' || u.apellido, 'Unknown') as author_name,
        COALESCE(u.rango::text, 'N/A') as author_rank,
        u.profile_image as author_avatar,
        (o.created_by = v_uid) as is_author,
        (v_user_role IN ('Administrador', 'Coordinador', 'Comisionado')) as can_delete
    FROM public.outings o
    LEFT JOIN public.users u ON o.created_by = u.id
    ORDER BY o.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
