-- Add image editing support to update RPCs
-- Allows updating images when editing incidents and outings

-- 1. Update update_incident
DROP FUNCTION IF EXISTS update_incident(UUID, TEXT, TEXT, TIMESTAMP WITH TIME ZONE, TEXT, TEXT);
CREATE OR REPLACE FUNCTION update_incident(
    p_incident_id UUID,
    p_title TEXT,
    p_location TEXT,
    p_occurred_at TIMESTAMP WITH TIME ZONE,
    p_tablet_number TEXT,
    p_description TEXT,
    p_images JSONB DEFAULT '[]'::jsonb -- Added images param
)
RETURNS VOID AS $$
BEGIN
    UPDATE public.incidents
    SET title = p_title,
    location = p_location,
    occurred_at = p_occurred_at,
    tablet_incident_number = p_tablet_number, -- Ensure column name matches table (checked schema: tablet_incident_number)
    description = p_description,
    images = p_images
    WHERE id = p_incident_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Update update_outing
DROP FUNCTION IF EXISTS update_outing(UUID, TEXT, TIMESTAMP WITH TIME ZONE, TEXT, TEXT);
CREATE OR REPLACE FUNCTION update_outing(
    p_outing_id UUID,
    p_title TEXT,
    p_occurred_at TIMESTAMP WITH TIME ZONE,
    p_reason TEXT,
    p_info_obtained TEXT,
    p_images JSONB DEFAULT '[]'::jsonb -- Added images param
)
RETURNS VOID AS $$
BEGIN
    UPDATE public.outings
    SET title = p_title,
    occurred_at = p_occurred_at,
    reason = p_reason,
    info_obtained = p_info_obtained,
    images = p_images
    WHERE id = p_outing_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
