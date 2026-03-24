-- DOJ LICENSES SYSTEM
-- Manages license types, civilian profiles, and license assignments

-- 1. License Types Table
CREATE TABLE IF NOT EXISTS public.doj_license_types (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_by UUID REFERENCES public.users(id)
);

-- 2. Civilian Profiles Table
CREATE TABLE IF NOT EXISTS public.doj_civilian_profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre TEXT NOT NULL,
  apellido TEXT NOT NULL,
  id_number TEXT NOT NULL UNIQUE, -- ID/DNI number
  phone_number TEXT,
  profile_image TEXT, -- Base64 or URL
  notes TEXT, -- General notes about the civilian
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_by UUID REFERENCES public.users(id)
);

-- 3. Civilian Licenses Junction Table
CREATE TABLE IF NOT EXISTS public.doj_civilian_licenses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  civilian_id UUID REFERENCES public.doj_civilian_profiles(id) ON DELETE CASCADE,
  license_type_id UUID REFERENCES public.doj_license_types(id) ON DELETE CASCADE,
  issued_date DATE DEFAULT CURRENT_DATE,
  expires_date DATE,
  status TEXT DEFAULT 'Active' CHECK (status IN ('Active', 'Expired', 'Suspended', 'Revoked')),
  issued_by UUID REFERENCES public.users(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(civilian_id, license_type_id) -- One license type per civilian
);

-- Enable RLS
ALTER TABLE public.doj_license_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.doj_civilian_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.doj_civilian_licenses ENABLE ROW LEVEL SECURITY;

-- Policies (Allow authenticated users - frontend filters by division)
DROP POLICY IF EXISTS "Auth Read License Types" ON public.doj_license_types;
CREATE POLICY "Auth Read License Types" ON public.doj_license_types FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Auth Write License Types" ON public.doj_license_types;
CREATE POLICY "Auth Write License Types" ON public.doj_license_types FOR ALL TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Auth Read Civilian Profiles" ON public.doj_civilian_profiles;
CREATE POLICY "Auth Read Civilian Profiles" ON public.doj_civilian_profiles FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Auth Write Civilian Profiles" ON public.doj_civilian_profiles;
CREATE POLICY "Auth Write Civilian Profiles" ON public.doj_civilian_profiles FOR ALL TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Auth Read Civilian Licenses" ON public.doj_civilian_licenses;
CREATE POLICY "Auth Read Civilian Licenses" ON public.doj_civilian_licenses FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Auth Write Civilian Licenses" ON public.doj_civilian_licenses;
CREATE POLICY "Auth Write Civilian Licenses" ON public.doj_civilian_licenses FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- =============================================
-- LICENSE TYPES RPCs
-- =============================================

-- Get all license types
CREATE OR REPLACE FUNCTION get_doj_license_types()
RETURNS TABLE (
  id UUID,
  name TEXT,
  description TEXT,
  created_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
  RETURN QUERY
  SELECT lt.id, lt.name, lt.description, lt.created_at
  FROM public.doj_license_types lt
  ORDER BY lt.name ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Manage license types (create, update, delete)
CREATE OR REPLACE FUNCTION manage_doj_license_type(
  p_action TEXT, -- 'create', 'update', 'delete'
  p_id UUID DEFAULT NULL,
  p_name TEXT DEFAULT NULL,
  p_description TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  v_id UUID;
BEGIN
  IF p_action = 'create' THEN
    INSERT INTO public.doj_license_types (name, description, created_by)
    VALUES (p_name, p_description, auth.uid())
    RETURNING id INTO v_id;
    RETURN v_id;
    
  ELSIF p_action = 'update' THEN
    UPDATE public.doj_license_types
    SET name = p_name, description = p_description
    WHERE id = p_id;
    RETURN p_id;
    
  ELSIF p_action = 'delete' THEN
    DELETE FROM public.doj_license_types WHERE id = p_id;
    RETURN p_id;
  END IF;
  
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- CIVILIAN PROFILES RPCs
-- =============================================

-- Get all civilian profiles with license count
CREATE OR REPLACE FUNCTION get_doj_civilians()
RETURNS TABLE (
  id UUID,
  nombre TEXT,
  apellido TEXT,
  id_number TEXT,
  phone_number TEXT,
  profile_image TEXT,
  license_count BIGINT,
  created_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    cp.id,
    cp.nombre,
    cp.apellido,
    cp.id_number,
    cp.phone_number,
    cp.profile_image,
    (SELECT COUNT(*) FROM public.doj_civilian_licenses cl WHERE cl.civilian_id = cp.id) as license_count,
    cp.created_at
  FROM public.doj_civilian_profiles cp
  ORDER BY cp.apellido ASC, cp.nombre ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create civilian profile
CREATE OR REPLACE FUNCTION create_doj_civilian(
  p_nombre TEXT,
  p_apellido TEXT,
  p_id_number TEXT,
  p_phone_number TEXT DEFAULT NULL,
  p_profile_image TEXT DEFAULT NULL,
  p_notes TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  v_id UUID;
BEGIN
  INSERT INTO public.doj_civilian_profiles (nombre, apellido, id_number, phone_number, profile_image, notes, created_by)
  VALUES (p_nombre, p_apellido, p_id_number, p_phone_number, p_profile_image, p_notes, auth.uid())
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update civilian profile
CREATE OR REPLACE FUNCTION update_doj_civilian(
  p_id UUID,
  p_nombre TEXT,
  p_apellido TEXT,
  p_id_number TEXT,
  p_phone_number TEXT,
  p_profile_image TEXT,
  p_notes TEXT
)
RETURNS VOID AS $$
BEGIN
  UPDATE public.doj_civilian_profiles
  SET 
    nombre = p_nombre,
    apellido = p_apellido,
    id_number = p_id_number,
    phone_number = p_phone_number,
    profile_image = p_profile_image,
    notes = p_notes
  WHERE id = p_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Delete civilian profile
CREATE OR REPLACE FUNCTION delete_doj_civilian(p_id UUID)
RETURNS VOID AS $$
BEGIN
  DELETE FROM public.doj_civilian_profiles WHERE id = p_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Get civilian profile details with licenses
CREATE OR REPLACE FUNCTION get_doj_civilian_details(p_civilian_id UUID)
RETURNS JSON AS $$
DECLARE
  v_profile RECORD;
  v_licenses JSON;
BEGIN
  -- Get profile
  SELECT * INTO v_profile FROM public.doj_civilian_profiles WHERE id = p_civilian_id;
  
  -- Get licenses
  SELECT COALESCE(json_agg(json_build_object(
    'id', cl.id,
    'license_type_id', lt.id,
    'license_name', lt.name,
    'license_description', lt.description,
    'issued_date', cl.issued_date,
    'expires_date', cl.expires_date,
    'status', cl.status,
    'issued_by_name', u.nombre || ' ' || u.apellido
  ) ORDER BY cl.issued_date DESC), '[]'::json)
  INTO v_licenses
  FROM public.doj_civilian_licenses cl
  JOIN public.doj_license_types lt ON cl.license_type_id = lt.id
  LEFT JOIN public.users u ON cl.issued_by = u.id
  WHERE cl.civilian_id = p_civilian_id;
  
  RETURN json_build_object(
    'profile', v_profile,
    'licenses', v_licenses
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- LICENSE ASSIGNMENTS RPCs
-- =============================================

-- Assign license to civilian
CREATE OR REPLACE FUNCTION assign_doj_license(
  p_civilian_id UUID,
  p_license_type_id UUID,
  p_issued_date DATE,
  p_expires_date DATE DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  v_id UUID;
BEGIN
  INSERT INTO public.doj_civilian_licenses (civilian_id, license_type_id, issued_date, expires_date, issued_by)
  VALUES (p_civilian_id, p_license_type_id, p_issued_date, p_expires_date, auth.uid())
  ON CONFLICT (civilian_id, license_type_id) DO NOTHING
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update license status
CREATE OR REPLACE FUNCTION update_doj_license_status(
  p_license_id UUID,
  p_status TEXT
)
RETURNS VOID AS $$
BEGIN
  UPDATE public.doj_civilian_licenses
  SET status = p_status
  WHERE id = p_license_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Revoke/Remove license
CREATE OR REPLACE FUNCTION revoke_doj_license(p_license_id UUID)
RETURNS VOID AS $$
BEGIN
  DELETE FROM public.doj_civilian_licenses WHERE id = p_license_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
