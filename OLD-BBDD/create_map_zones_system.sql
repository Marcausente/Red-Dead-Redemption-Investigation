-- CRIME MAP ZONES SYSTEM
-- Access Control: Auth users can view, specific roles can edit.

-- 1. Create Table
CREATE TABLE IF NOT EXISTS public.map_zones (
    id UUID DEFAULT extensions.uuid_generate_v4() PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    coordinates JSONB NOT NULL, -- Storing array of [lat, lng] or GeoJSON
    type TEXT DEFAULT 'polygon', -- 'polygon', 'rectangle', 'marker'
    gang_id UUID REFERENCES public.gangs(id) ON DELETE SET NULL,
    case_id UUID REFERENCES public.cases(id) ON DELETE SET NULL,
    color TEXT DEFAULT '#ef4444', -- Default red
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID REFERENCES public.users(id)
);

-- 2. Enable RLS
ALTER TABLE public.map_zones ENABLE ROW LEVEL SECURITY;

-- 3. Policies
-- Everyone authenticated can view
CREATE POLICY "Auth can view zones" ON public.map_zones
    FOR SELECT TO authenticated USING (true);

-- Only authorized personnel can insert/update/delete
-- Re-using auth_is_gang_authorized() as it covers Detectives+
CREATE POLICY "Auth can insert zones" ON public.map_zones
    FOR INSERT WITH CHECK (auth_is_gang_authorized());

CREATE POLICY "Auth can update zones" ON public.map_zones
    FOR UPDATE USING (auth_is_gang_authorized());

CREATE POLICY "Auth can delete zones" ON public.map_zones
    FOR DELETE USING (auth_is_gang_authorized());

-- 4. RPCs

-- Create Zone
CREATE OR REPLACE FUNCTION create_map_zone(
    p_name TEXT,
    p_description TEXT,
    p_coordinates JSONB,
    p_type TEXT,
    p_gang_id UUID DEFAULT NULL,
    p_case_id UUID DEFAULT NULL,
    p_color TEXT DEFAULT '#ef4444'
) RETURNS UUID AS $$
DECLARE
    v_id UUID;
BEGIN
    IF NOT auth_is_gang_authorized() THEN RAISE EXCEPTION 'Access Denied'; END IF;

    INSERT INTO public.map_zones (name, description, coordinates, type, gang_id, case_id, color, created_by)
    VALUES (p_name, p_description, p_coordinates, p_type, p_gang_id, p_case_id, p_color, auth.uid())
    RETURNING id INTO v_id;

    RETURN v_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- Update Zone
CREATE OR REPLACE FUNCTION update_map_zone(
    p_id UUID,
    p_name TEXT,
    p_description TEXT,
    p_gang_id UUID,
    p_case_id UUID,
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
        color = p_color
    WHERE id = p_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Delete Zone
CREATE OR REPLACE FUNCTION delete_map_zone(p_id UUID) RETURNS VOID AS $$
BEGIN
    IF NOT auth_is_gang_authorized() THEN RAISE EXCEPTION 'Access Denied'; END IF;
    DELETE FROM public.map_zones WHERE id = p_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Get Zones (With joins for tooltips)
CREATE OR REPLACE FUNCTION get_map_zones()
RETURNS TABLE (
    id UUID,
    name TEXT,
    description TEXT,
    coordinates JSONB,
    type TEXT,
    color TEXT,
    gang_name TEXT,
    case_title TEXT,
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
        g.name AS gang_name,
        c.title AS case_title,
        mz.created_at
    FROM public.map_zones mz
    LEFT JOIN public.gangs g ON mz.gang_id = g.id
    LEFT JOIN public.cases c ON mz.case_id = c.id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
