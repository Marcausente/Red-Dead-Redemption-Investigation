-- Add is_gang_zone flag and public access

-- 1. Add column
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='map_zones' AND column_name='is_gang_zone') THEN
        ALTER TABLE public.map_zones ADD COLUMN is_gang_zone BOOLEAN DEFAULT false;
    END IF;
END
$$;

-- 2. Drop old functions to avoid ambiguity (cleanup)
DROP FUNCTION IF EXISTS public.create_map_zone(text, text, jsonb, text, uuid, uuid, uuid, text);
DROP FUNCTION IF EXISTS public.update_map_zone(uuid, text, text, uuid, uuid, uuid, text);

-- 3. Update create_map_zone
CREATE OR REPLACE FUNCTION create_map_zone(
    p_name TEXT,
    p_description TEXT,
    p_coordinates JSONB,
    p_type TEXT,
    p_gang_id UUID DEFAULT NULL,
    p_case_id UUID DEFAULT NULL,
    p_incident_id UUID DEFAULT NULL,
    p_color TEXT DEFAULT '#ef4444',
    p_is_gang_zone BOOLEAN DEFAULT FALSE -- Added
) RETURNS UUID AS $$
DECLARE
    v_id UUID;
BEGIN
    IF NOT auth_is_gang_authorized() THEN RAISE EXCEPTION 'Access Denied'; END IF;

    INSERT INTO public.map_zones (name, description, coordinates, type, gang_id, case_id, incident_id, color, is_gang_zone, created_by)
    VALUES (p_name, p_description, p_coordinates, p_type, p_gang_id, p_case_id, p_incident_id, p_color, p_is_gang_zone, auth.uid())
    RETURNING id INTO v_id;

    RETURN v_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Update update_map_zone
CREATE OR REPLACE FUNCTION update_map_zone(
    p_id UUID,
    p_name TEXT,
    p_description TEXT,
    p_gang_id UUID,
    p_case_id UUID,
    p_incident_id UUID,
    p_color TEXT,
    p_is_gang_zone BOOLEAN -- Added
) RETURNS VOID AS $$
BEGIN
    IF NOT auth_is_gang_authorized() THEN RAISE EXCEPTION 'Access Denied'; END IF;

    UPDATE public.map_zones
    SET 
        name = p_name,
        description = p_description,
        gang_id = p_gang_id,
        case_id = p_case_id,
        incident_id = p_incident_id,
        color = p_color,
        is_gang_zone = p_is_gang_zone
    WHERE id = p_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Update get_map_zones
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
    incident_id UUID,
    incident_title TEXT,
    is_gang_zone BOOLEAN, -- Added
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
        mz.incident_id,
        i.title AS incident_title,
        mz.is_gang_zone, -- Added
        mz.created_at
    FROM public.map_zones mz
    LEFT JOIN public.gangs g ON mz.gang_id = g.id
    LEFT JOIN public.cases c ON mz.case_id = c.id
    LEFT JOIN public.incidents i ON mz.incident_id = i.id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. Create Public RPC
CREATE OR REPLACE FUNCTION get_public_gang_zones()
RETURNS TABLE (
    name TEXT,
    description TEXT,
    coordinates JSONB,
    type TEXT,
    color TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        mz.name,
        mz.description,
        mz.coordinates,
        mz.type,
        mz.color
    FROM public.map_zones mz
    WHERE mz.is_gang_zone = true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant access to anonymous users for the public map
GRANT EXECUTE ON FUNCTION get_public_gang_zones() TO anon;
GRANT EXECUTE ON FUNCTION get_public_gang_zones() TO authenticated;
