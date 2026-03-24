-- Update get_map_zones to include IDs
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
        mz.gang_id, -- Added
        g.name AS gang_name,
        mz.case_id, -- Added
        c.title AS case_title,
        mz.created_at
    FROM public.map_zones mz
    LEFT JOIN public.gangs g ON mz.gang_id = g.id
    LEFT JOIN public.cases c ON mz.case_id = c.id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
