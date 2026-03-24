-- Function to update gang name (VIP only)
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
