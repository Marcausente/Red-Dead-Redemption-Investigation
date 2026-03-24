-- IA SANCTIONS SYSTEM
-- Supports non-user officers via Subject Profiles

-- 1. Subject Profiles (The "Profile" mentioned in prompt)
CREATE TABLE IF NOT EXISTS public.ia_subject_profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre TEXT NOT NULL,
  apellido TEXT NOT NULL,
  no_placa TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_by UUID REFERENCES public.users(id),
  -- Optional linking if they become a user later, but primary ID is this table's ID
  linked_user_id UUID REFERENCES public.users(id)
);

-- 2. Sanctions Table (Updated from previous schema to link to Profile)
-- Drop old one if exists to avoid conflicts or just create new one
DROP TABLE IF EXISTS public.ia_sanctions;

CREATE TABLE IF NOT EXISTS public.ia_sanctions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  subject_id UUID REFERENCES public.ia_subject_profiles(id) ON DELETE CASCADE,
  sanction_type TEXT CHECK (sanction_type IN ('Leve', 'Media', 'Grave')),
  description TEXT,
  sanction_date DATE DEFAULT CURRENT_DATE,
  case_id UUID REFERENCES public.ia_cases(id) ON DELETE SET NULL, -- Optional link to IA Case
  created_by UUID REFERENCES public.users(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.ia_subject_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ia_sanctions ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Auth Read Profiles" ON public.ia_subject_profiles FOR SELECT TO authenticated USING (true);
CREATE POLICY "Auth Write Profiles" ON public.ia_subject_profiles FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Auth Update Profiles" ON public.ia_subject_profiles FOR UPDATE TO authenticated USING (true);

CREATE POLICY "Auth Read Sanctions" ON public.ia_sanctions FOR SELECT TO authenticated USING (true);
CREATE POLICY "Auth Write Sanctions" ON public.ia_sanctions FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Auth Update Sanctions" ON public.ia_sanctions FOR UPDATE TO authenticated USING (true);
CREATE POLICY "Auth Delete Sanctions" ON public.ia_sanctions FOR DELETE TO authenticated USING (true);


-- 3. RPCs

-- create_ia_subject_profile
CREATE OR REPLACE FUNCTION create_ia_subject_profile(
  p_nombre TEXT,
  p_apellido TEXT,
  p_no_placa TEXT
)
RETURNS UUID AS $$
DECLARE
  v_id UUID;
BEGIN
  INSERT INTO public.ia_subject_profiles (nombre, apellido, no_placa, created_by)
  VALUES (p_nombre, p_apellido, p_no_placa, auth.uid())
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- get_ia_subjects (List for main view)
CREATE OR REPLACE FUNCTION get_ia_subjects()
RETURNS TABLE (
  id UUID,
  nombre TEXT,
  apellido TEXT,
  no_placa TEXT,
  sanction_count BIGINT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    p.id,
    p.nombre,
    p.apellido,
    p.no_placa,
    (SELECT COUNT(*) FROM public.ia_sanctions s WHERE s.subject_id = p.id) as sanction_count
  FROM public.ia_subject_profiles p
  ORDER BY p.nombre ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- create_ia_sanction (Add sanction to profile)
CREATE OR REPLACE FUNCTION create_ia_sanction(
  p_subject_id UUID,
  p_type TEXT,
  p_description TEXT,
  p_date DATE,
  p_case_id UUID DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  v_id UUID;
BEGIN
  INSERT INTO public.ia_sanctions (subject_id, sanction_type, description, sanction_date, case_id, created_by)
  VALUES (p_subject_id, p_type, p_description, p_date, p_case_id, auth.uid())
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- get_ia_subject_details (Profile + Sanctions History)
CREATE OR REPLACE FUNCTION get_ia_subject_details(p_subject_id UUID)
RETURNS JSON AS $$
DECLARE
  v_profile RECORD;
  v_sanctions JSON;
BEGIN
  SELECT * INTO v_profile FROM public.ia_subject_profiles WHERE id = p_subject_id;
  
  SELECT COALESCE(json_agg(json_build_object(
    'id', s.id,
    'type', s.sanction_type,
    'description', s.description,
    'date', s.sanction_date,
    'case_id', s.case_id,
    'case_title', c.title,
    'case_number', c.case_number,
    'created_by_name', u.nombre || ' ' || u.apellido
  ) ORDER BY s.sanction_date DESC), '[]'::json)
  INTO v_sanctions
  FROM public.ia_sanctions s
  LEFT JOIN public.ia_cases c ON s.case_id = c.id
  LEFT JOIN public.users u ON s.created_by = u.id
  WHERE s.subject_id = p_subject_id;
  
  RETURN json_build_object(
    'profile', v_profile,
    'sanctions', v_sanctions
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Helper to get cases for dropdown
CREATE OR REPLACE FUNCTION get_ia_cases_simple()
RETURNS TABLE (
  id UUID,
  title TEXT,
  case_number INT
) AS $$
BEGIN
  RETURN QUERY
  SELECT id, title, case_number
  FROM public.ia_cases
  WHERE status != 'Archived'
  ORDER BY created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
