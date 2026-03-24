-- RPC to get incidents for a specific gang
CREATE OR REPLACE FUNCTION get_gang_incidents(p_gang_id UUID)
RETURNS TABLE (
    record_id UUID,
    title TEXT,
    location TEXT,
    occurred_at TIMESTAMPTZ,
    tablet_incident_number TEXT,
    description TEXT,
    images JSONB,
    author_id UUID,
    author_name TEXT,
    author_rank TEXT,
    author_avatar TEXT,
    is_author BOOLEAN,
    can_delete BOOLEAN,
    gang_names TEXT[]
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_rango TEXT;
    v_user_id UUID;
BEGIN
    -- Get current user context
    v_user_id := auth.uid();
    SELECT rol INTO v_user_rango FROM users WHERE id = v_user_id;

    RETURN QUERY
    SELECT
        i.id as record_id,
        i.title,
        i.location,
        i.occurred_at,
        i.tablet_incident_number,
        i.description,
        i.images,
        i.author_id,
        (u.nombre || ' ' || u.apellido) as author_name,
        u.rango::TEXT as author_rank,
        u.profile_image as author_avatar,
        (i.author_id = v_user_id) as is_author,
        (
            i.author_id = v_user_id OR
            v_user_rango IN ('Coordinador', 'Comisionado', 'Administrador', 'Admin')
        ) as can_delete,
        -- Get all gangs linked to this incident (even if we are filtering by one, we want to see the others)
        COALESCE((
            SELECT array_agg(g.name)
            FROM incident_gangs ig2
            JOIN gangs g ON g.id = ig2.gang_id
            WHERE ig2.incident_id = i.id
        ), ARRAY[]::TEXT[]) as gang_names
    FROM incidents i
    JOIN incident_gangs ig ON ig.incident_id = i.id
    LEFT JOIN users u ON i.author_id = u.id
    WHERE ig.gang_id = p_gang_id
    ORDER BY i.occurred_at DESC;
END;
$$;

-- RPC to get outings for a specific gang
CREATE OR REPLACE FUNCTION get_gang_outings(p_gang_id UUID)
RETURNS TABLE (
    record_id UUID,
    title TEXT,
    occurred_at TIMESTAMPTZ,
    reason TEXT,
    info_obtained TEXT,
    images JSONB,
    author_id UUID, -- Creator of the outing
    is_author BOOLEAN,
    can_delete BOOLEAN,
    detectives JSONB -- List of detectives present
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_rango TEXT;
    v_user_id UUID;
BEGIN
    -- Get current user context
    v_user_id := auth.uid();
    SELECT rol INTO v_user_rango FROM users WHERE id = v_user_id;

    RETURN QUERY
    SELECT
        o.id as record_id,
        o.title,
        o.occurred_at,
        o.reason,
        o.info_obtained,
        o.images,
        o.created_by as author_id,
        (o.created_by = v_user_id) as is_author,
        (
            o.created_by = v_user_id OR
            v_user_rango IN ('Coordinador', 'Comisionado', 'Administrador', 'Admin')
        ) as can_delete,
        (
            SELECT jsonb_agg(jsonb_build_object(
                'id', u.id,
                'name', u.nombre || ' ' || u.apellido,
                'rank', u.rango,
                'avatar', u.profile_image
            ))
            FROM outing_detectives od
            JOIN users u ON u.id = od.user_id
            WHERE od.outing_id = o.id
        ) as detectives
    FROM outings o
    JOIN outing_gangs og ON og.outing_id = o.id
    WHERE og.gang_id = p_gang_id
    ORDER BY o.occurred_at DESC;
END;
$$;
