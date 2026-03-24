-- Link Incidents to Map Zones
-- This script adds an incident_id column to map_zones and updates the relevant RPCs.

-- 1. Add column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='map_zones' AND column_name='incident_id') THEN
        ALTER TABLE public.map_zones ADD COLUMN incident_id UUID REFERENCES public.incidents(id) ON DELETE SET NULL;
    END IF;
END
$$;

-- 2. Update create_map_zone RPC
CREATE OR REPLACE FUNCTION create_map_zone(
    p_name TEXT,
    p_description TEXT,
    p_coordinates JSONB,
    p_type TEXT,
    p_gang_id UUID DEFAULT NULL,
    p_case_id UUID DEFAULT NULL,
    p_incident_id UUID DEFAULT NULL, -- Added
    p_color TEXT DEFAULT '#ef4444'
) RETURNS UUID AS $$
DECLARE
    v_id UUID;
BEGIN
    IF NOT auth_is_gang_authorized() THEN RAISE EXCEPTION 'Access Denied'; END IF;

    INSERT INTO public.map_zones (name, description, coordinates, type, gang_id, case_id, incident_id, color, created_by)
    VALUES (p_name, p_description, p_coordinates, p_type, p_gang_id, p_case_id, p_incident_id, p_color, auth.uid())
    RETURNING id INTO v_id;

    RETURN v_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 3. Update update_map_zone RPC
CREATE OR REPLACE FUNCTION update_map_zone(
    p_id UUID,
    p_name TEXT,
    p_description TEXT,
    p_gang_id UUID,
    p_case_id UUID,
    p_incident_id UUID, -- Added
    p_color TEXT
) RETURNS VOID AS $$
BEGIN
    IF NOT auth_is_gang_authorized() THEN RAISE EXCEPTION 'Access Denied'; END IF;

    UPDATE public.map_zones
    SET 
        name = p_name,
        description = p_description,
        gang_id = p_gang_id,
        case_id = p_case_id,
        incident_id = p_incident_id, -- Added
        color = p_color
    WHERE id = p_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 4. Update get_map_zones RPC
DROP FUNCTION IF EXISTS get_map_zones();
CREATE OR REPLACE FUNCTION get_map_zones()
RETURNS TABLE (
    id UUID,
    name TEXT,
    description TEXT,
    coordinates JSONB,
    type TEXT,
    color TEXT,
    gang_id UUID,
    gang_name TEXT,
    case_id UUID,
    case_title TEXT,
    incident_id UUID, -- Added
    incident_title TEXT, -- Added
    created_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        mz.id,
        mz.name,
        mz.description,
        mz.coordinates,
        mz.type,
        mz.color,
        mz.gang_id,
        g.name AS gang_name,
        mz.case_id,
        c.title AS case_title,
        mz.incident_id, -- Added
        i.title AS incident_title, -- Added
        mz.created_at
    FROM public.map_zones mz
    LEFT JOIN public.gangs g ON mz.gang_id = g.id
    LEFT JOIN public.cases c ON mz.case_id = c.id
    LEFT JOIN public.incidents i ON mz.incident_id = i.id; -- Added
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
