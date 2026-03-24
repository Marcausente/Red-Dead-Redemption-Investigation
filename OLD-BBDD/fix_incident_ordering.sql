-- FIX INCIDENT ORDERING
-- Updates get_incidents_v2 to sort by created_at instead of occurred_at
-- This ensures that the most recently "uploaded" incidents appear at the top.

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
        COALESCE(u.rango::text, 'N/A'), -- Kept critical fix: Cast to TEXT
        u.profile_image,
        (i.author_id = v_uid) as is_author,
        (v_user_role IN ('Administrador', 'Coordinador', 'Comisionado', 'Detective')) as can_delete
    FROM public.incidents i
    LEFT JOIN public.users u ON i.author_id = u.id
    ORDER BY i.created_at DESC; -- CHANGED FROM occurred_at TO created_at
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
