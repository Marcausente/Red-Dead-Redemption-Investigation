-- PERSONNEL EQUIPMENT MANAGEMENT SYSTEM
-- Manages equipment types and assignments to personnel

-- Drop existing tables to ensure clean schema
DROP TABLE IF EXISTS public.personnel_equipment CASCADE;
DROP TABLE IF EXISTS public.equipment_types CASCADE;

-- 1. Equipment Types Table
CREATE TABLE public.equipment_types (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  description TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_by UUID REFERENCES public.users(id)
);

-- 2. Personnel Equipment Assignments Table
CREATE TABLE public.personnel_equipment (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  civilian_id UUID REFERENCES public.doj_civilian_profiles(id) ON DELETE CASCADE,
  equipment_type_id UUID REFERENCES public.equipment_types(id) ON DELETE CASCADE,
  serial_number TEXT,
  issued_date DATE NOT NULL,
  return_date DATE,
  status TEXT DEFAULT 'Active' CHECK (status IN ('Active', 'Missing', 'Retired')),
  issued_by UUID REFERENCES public.users(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.equipment_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.personnel_equipment ENABLE ROW LEVEL SECURITY;

-- Policies
DROP POLICY IF EXISTS "Auth Read Equipment Types" ON public.equipment_types;
CREATE POLICY "Auth Read Equipment Types" ON public.equipment_types FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Auth Write Equipment Types" ON public.equipment_types;
CREATE POLICY "Auth Write Equipment Types" ON public.equipment_types FOR ALL TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Auth Read Personnel Equipment" ON public.personnel_equipment;
CREATE POLICY "Auth Read Personnel Equipment" ON public.personnel_equipment FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Auth Write Personnel Equipment" ON public.personnel_equipment;
CREATE POLICY "Auth Write Personnel Equipment" ON public.personnel_equipment FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- =============================================
-- EQUIPMENT TYPES RPCs
-- =============================================

-- Get all equipment types
CREATE OR REPLACE FUNCTION get_equipment_types()
RETURNS TABLE (
  id UUID,
  name TEXT,
  description TEXT,
  created_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
  RETURN QUERY
  SELECT et.id, et.name, et.description, et.created_at
  FROM public.equipment_types et
  ORDER BY et.name ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Manage equipment types (create, update, delete)
CREATE OR REPLACE FUNCTION manage_equipment_type(
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
    INSERT INTO public.equipment_types (name, description, created_by)
    VALUES (p_name, p_description, auth.uid())
    RETURNING id INTO v_id;
    RETURN v_id;
    
  ELSIF p_action = 'update' THEN
    UPDATE public.equipment_types
    SET name = p_name, description = p_description
    WHERE id = p_id;
    RETURN p_id;
    
  ELSIF p_action = 'delete' THEN
    DELETE FROM public.equipment_types WHERE id = p_id;
    RETURN p_id;
  END IF;
  
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- PERSONNEL EQUIPMENT RPCs
-- =============================================

-- Drop existing functions if they exist (to allow parameter name changes)
DROP FUNCTION IF EXISTS get_user_equipment(UUID);
DROP FUNCTION IF EXISTS get_civilian_equipment(UUID);
DROP FUNCTION IF EXISTS assign_equipment(UUID, UUID, DATE, TEXT);

-- Get equipment for a specific civilian
CREATE OR REPLACE FUNCTION get_civilian_equipment(p_civilian_id UUID)
RETURNS JSON AS $$
BEGIN
  RETURN COALESCE(
    (SELECT json_agg(json_build_object(
      'id', pe.id,
      'equipment_type_id', et.id,
      'equipment_name', et.name,
      'equipment_description', et.description,
      'serial_number', pe.serial_number,
      'issued_date', pe.issued_date,
      'return_date', pe.return_date,
      'status', pe.status,
      'issued_by_name', u.nombre || ' ' || u.apellido
    ) ORDER BY pe.issued_date DESC)
    FROM public.personnel_equipment pe
    JOIN public.equipment_types et ON pe.equipment_type_id = et.id
    LEFT JOIN public.users u ON pe.issued_by = u.id
    WHERE pe.civilian_id = p_civilian_id),
    '[]'::json
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Assign equipment to civilian
CREATE OR REPLACE FUNCTION assign_equipment(
  p_civilian_id UUID,
  p_equipment_type_id UUID,
  p_issued_date DATE,
  p_serial_number TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  v_id UUID;
BEGIN
  INSERT INTO public.personnel_equipment (civilian_id, equipment_type_id, issued_date, serial_number, issued_by)
  VALUES (p_civilian_id, p_equipment_type_id, p_issued_date, p_serial_number, auth.uid())
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update equipment status
CREATE OR REPLACE FUNCTION update_equipment_status(
  p_equipment_id UUID,
  p_status TEXT,
  p_return_date DATE DEFAULT NULL
)
RETURNS VOID AS $$
BEGIN
  UPDATE public.personnel_equipment
  SET 
    status = p_status,
    return_date = CASE 
      WHEN p_status IN ('Missing', 'Retired') AND p_return_date IS NOT NULL THEN p_return_date
      WHEN p_status IN ('Missing', 'Retired') AND p_return_date IS NULL THEN CURRENT_DATE
      ELSE return_date
    END
  WHERE id = p_equipment_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Remove equipment assignment
CREATE OR REPLACE FUNCTION remove_equipment(p_equipment_id UUID)
RETURNS VOID AS $$
BEGIN
  DELETE FROM public.personnel_equipment WHERE id = p_equipment_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
