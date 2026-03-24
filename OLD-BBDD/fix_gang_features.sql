-- FIX SCRIPT: Run this to ensure all features work correctly
-- content: update_gang_name, update_gang_member_notes, and refresh get_gangs_data

-- 1. Function to update gang name (VIP only)
CREATE OR REPLACE FUNCTION update_gang_name(
    p_gang_id UUID,
    p_name TEXT
) RETURNS VOID AS $$
BEGIN
    IF NOT auth_is_gang_vip() THEN 
        RAISE EXCEPTION 'Access Denied: High Command Only'; 
    END IF;
    
    UPDATE public.gangs 
    SET name = p_name 
    WHERE id = p_gang_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Function to update gang member notes
CREATE OR REPLACE FUNCTION update_gang_member_notes(
    p_member_id UUID,
    p_notes TEXT
) RETURNS VOID AS $$
BEGIN
    IF NOT auth_is_gang_authorized() THEN 
        RAISE EXCEPTION 'Access Denied'; 
    END IF;
    
    UPDATE public.gang_members 
    SET notes = p_notes 
    WHERE id = p_member_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Refresh get_gangs_data (Ensure it fetches 'notes')
DROP FUNCTION IF EXISTS get_gangs_data();
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
        RETURN; -- Validate return empty if not authorized
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
        -- Members (Added 'notes' here)
        COALESCE((
            SELECT jsonb_agg(jsonb_build_object('id', m.id, 'name', m.name, 'role', m.role, 'photo', m.photo, 'notes', m.notes, 'status', m.status))
            FROM public.gang_members m WHERE m.gang_id = g.id
        ), '[]'::jsonb),
        -- Info
        COALESCE((
            SELECT jsonb_agg(jsonb_build_object('id', i.id, 'type', i.type, 'content', i.content, 'images', i.images, 'author', (SELECT nombre||' '||apellido FROM public.users WHERE id=i.author_id)))
            FROM public.gang_info i WHERE i.gang_id = g.id
        ), '[]'::jsonb),
        -- Counts
        (SELECT COUNT(*) FROM public.incidents inc WHERE inc.gang_id = g.id),
        (SELECT COUNT(*) FROM public.outings out WHERE out.gang_id = g.id)
        
    FROM public.gangs g
    ORDER BY g.created_at ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
