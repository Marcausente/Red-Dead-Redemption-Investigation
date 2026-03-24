-- UPDATE VEHICLE
CREATE OR REPLACE FUNCTION update_gang_vehicle(
    p_vehicle_id UUID,
    p_model TEXT,
    p_plate TEXT,
    p_owner TEXT,
    p_notes TEXT,
    p_images JSONB
) RETURNS VOID AS $$
BEGIN
    IF NOT auth_is_gang_authorized() THEN RAISE EXCEPTION 'Access Denied'; END IF;
    
    UPDATE public.gang_vehicles
    SET model = p_model,
        plate = p_plate,
        owner_name = p_owner,
        notes = p_notes,
        images = p_images
    WHERE id = p_vehicle_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- UPDATE HOME
CREATE OR REPLACE FUNCTION update_gang_home(
    p_home_id UUID,
    p_owner TEXT,
    p_notes TEXT,
    p_images JSONB
) RETURNS VOID AS $$
BEGIN
    IF NOT auth_is_gang_authorized() THEN RAISE EXCEPTION 'Access Denied'; END IF;

    UPDATE public.gang_homes
    SET owner_name = p_owner,
        address_notes = p_notes,
        images = p_images
    WHERE id = p_home_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- UPDATE MEMBER
CREATE OR REPLACE FUNCTION update_gang_member(
    p_member_id UUID,
    p_name TEXT,
    p_role TEXT,
    p_photo TEXT,
    p_notes TEXT
) RETURNS VOID AS $$
BEGIN
    IF NOT auth_is_gang_authorized() THEN RAISE EXCEPTION 'Access Denied'; END IF;

    UPDATE public.gang_members
    SET name = p_name,
        role = p_role,
        photo = p_photo,
        notes = p_notes
    WHERE id = p_member_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- UPDATE INFO
CREATE OR REPLACE FUNCTION update_gang_info(
    p_info_id UUID,
    p_type TEXT,
    p_content TEXT,
    p_images JSONB
) RETURNS VOID AS $$
BEGIN
    IF NOT auth_is_gang_authorized() THEN RAISE EXCEPTION 'Access Denied'; END IF;

    UPDATE public.gang_info
    SET type = p_type,
        content = p_content,
        images = p_images
    WHERE id = p_info_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
