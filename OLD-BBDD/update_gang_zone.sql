-- RPC to update Gang Zone Image
CREATE OR REPLACE FUNCTION update_gang_zone(p_gang_id UUID, p_image TEXT) RETURNS VOID AS $$
BEGIN
    IF NOT auth_is_gang_authorized() THEN RAISE EXCEPTION 'Access Denied'; END IF;
    
    UPDATE public.gangs 
    SET zones_image = p_image 
    WHERE id = p_gang_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
