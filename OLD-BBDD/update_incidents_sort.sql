-- Update Incidents Sorting with Missing Gang Logic Restored
-- This script updates get_incidents_v2 to sort by created_at DESC AND includes the gang_id/gang_names columns
-- that were accidentally removed in the previous version.

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
    gang_id UUID, -- Restored
    gang_names TEXT[] -- Restored
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
        u.rango::text as author_rank,
        u.profile_image as author_avatar,
        (i.author_id = v_uid) as is_author,
        (v_user_role IN ('Administrador', 'Coordinador', 'Comisionado')) as can_delete,
        (SELECT ig.gang_id FROM public.incident_gangs ig WHERE ig.incident_id = i.id LIMIT 1), -- Restored logic
        ARRAY(
            SELECT g.name 
            FROM public.incident_gangs ig 
            JOIN public.gangs g ON ig.gang_id = g.id 
            WHERE ig.incident_id = i.id
            ORDER BY g.name
        ) as gang_names -- Restored logic
    FROM public.incidents i
    LEFT JOIN public.users u ON i.author_id = u.id
    ORDER BY i.created_at DESC; -- Sorted by creation date
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
