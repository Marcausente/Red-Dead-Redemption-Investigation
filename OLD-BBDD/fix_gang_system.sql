-- FIX SCRIPT FOR GANGS SYSTEM

-- 1. Create the missing update_gang_zone RPC
CREATE OR REPLACE FUNCTION update_gang_zone(p_gang_id UUID, p_image TEXT) RETURNS VOID AS $$
BEGIN
    IF NOT auth_is_gang_authorized() THEN RAISE EXCEPTION 'Access Denied'; END IF;
    
    UPDATE public.gangs 
    SET zones_image = p_image 
    WHERE id = p_gang_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 2. Ensure VIP functions are robust (Case Insensitive)
CREATE OR REPLACE FUNCTION auth_is_gang_vip() RETURNS BOOLEAN AS $$
DECLARE
    v_role TEXT;
BEGIN
    SELECT TRIM(rol::text) INTO v_role FROM public.users WHERE id = auth.uid();
    -- Check case insensitive
    RETURN LOWER(v_role) IN ('coordinador', 'comisionado', 'administrador', 'admin');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Ensure General Authorization is robust
CREATE OR REPLACE FUNCTION auth_is_gang_authorized() RETURNS BOOLEAN AS $$
DECLARE
    v_role TEXT;
BEGIN
    SELECT TRIM(rol::text) INTO v_role FROM public.users WHERE id = auth.uid();
    RETURN LOWER(v_role) IN ('detective', 'coordinador', 'comisionado', 'administrador', 'admin');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Re-grant permissions (just in case)
GRANT EXECUTE ON FUNCTION update_gang_zone TO authenticated;
GRANT EXECUTE ON FUNCTION auth_is_gang_vip TO authenticated;
GRANT EXECUTE ON FUNCTION auth_is_gang_authorized TO authenticated;
