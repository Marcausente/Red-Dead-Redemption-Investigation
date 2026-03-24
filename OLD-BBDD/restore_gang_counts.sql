-- FIX: Restore correct count logic for Gangs List
-- This function was previously overwritten by 'fix_gang_features.sql' with outdated logic.
-- We restore it to use the proper junction tables (incident_gangs, outing_gangs).

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
        -- Vehicles
        COALESCE((
            SELECT jsonb_agg(jsonb_build_object('id', v.id, 'model', v.model, 'plate', v.plate, 'owner', v.owner_name, 'notes', v.notes, 'images', v.images))
            FROM public.gang_vehicles v WHERE v.gang_id = g.id
        ), '[]'::jsonb),
        -- Homes
        COALESCE((
            SELECT jsonb_agg(jsonb_build_object('id', h.id, 'owner', h.owner_name, 'notes', h.address_notes, 'images', h.images))
            FROM public.gang_homes h WHERE h.gang_id = g.id
        ), '[]'::jsonb),
        -- Members
        COALESCE((
            SELECT jsonb_agg(jsonb_build_object('id', m.id, 'name', m.name, 'role', m.role, 'photo', m.photo, 'notes', m.notes, 'status', m.status))
            FROM public.gang_members m WHERE m.gang_id = g.id
        ), '[]'::jsonb),
        -- Info
        COALESCE((
            SELECT jsonb_agg(jsonb_build_object('id', i.id, 'type', i.type, 'content', i.content, 'images', i.images, 'author', (SELECT nombre||' '||apellido FROM public.users WHERE id=i.author_id)))
            FROM public.gang_info i WHERE i.gang_id = g.id
        ), '[]'::jsonb),
        -- Counts (Using JOIN tables)
        (SELECT COUNT(*) FROM public.incident_gangs ig WHERE ig.gang_id = g.id), 
        (SELECT COUNT(*) FROM public.outing_gangs og WHERE og.gang_id = g.id)
        
    FROM public.gangs g
    ORDER BY g.created_at ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
