-- Function to update gang member notes
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
