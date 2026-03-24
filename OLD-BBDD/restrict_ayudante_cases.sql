-- RESTRICT 'AYUDANTE' PERMISSIONS
-- Specifically denies access to modification RPCs for users with role 'Ayudante'

-- 1. Create New Case
CREATE OR REPLACE FUNCTION create_new_case(
  p_title TEXT,
  p_location TEXT,
  p_occurred_at TIMESTAMP WITH TIME ZONE,
  p_description TEXT,
  p_assigned_ids UUID[]
)
RETURNS UUID AS $$
DECLARE
  v_new_case_id UUID;
  v_uid UUID;
  v_user_rol TEXT;
BEGIN
  -- Check Role
  SELECT u.rol::text INTO v_user_rol FROM public.users u WHERE u.id = auth.uid();
  IF v_user_rol = 'Ayudante' THEN
      RAISE EXCEPTION 'Access Denied: Ayudantes cannot create cases.';
  END IF;

  -- Insert Case
  INSERT INTO public.cases (title, location, occurred_at, description, created_by)
  VALUES (p_title, p_location, p_occurred_at, p_description, auth.uid())
  RETURNING id INTO v_new_case_id;

  -- Insert Assignments
  IF p_assigned_ids IS NOT NULL THEN
    FOREACH v_uid IN ARRAY p_assigned_ids
    LOOP
      INSERT INTO public.case_assignments (case_id, user_id) VALUES (v_new_case_id, v_uid);
    END LOOP;
  END IF;

  RETURN v_new_case_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 2. Set Case Status (Close/Archive/Open)
CREATE OR REPLACE FUNCTION set_case_status(p_case_id UUID, p_status TEXT)
RETURNS VOID AS $$
DECLARE
  v_user_rol TEXT;
BEGIN
  -- Check Role
  SELECT u.rol::text INTO v_user_rol FROM public.users u WHERE u.id = auth.uid();
  IF v_user_rol = 'Ayudante' THEN
      RAISE EXCEPTION 'Access Denied: Ayudantes cannot change case status.';
  END IF;

  UPDATE public.cases SET status = p_status WHERE id = p_case_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 3. Update Case Details (Edit Info)
CREATE OR REPLACE FUNCTION update_case_details(
  p_case_id UUID,
  p_title TEXT,
  p_location TEXT,
  p_occurred_at TIMESTAMP WITH TIME ZONE,
  p_description TEXT
)
RETURNS VOID AS $$
DECLARE
  v_uid UUID;
  v_user_role TEXT;
  v_creator_id UUID;
  v_is_admin_or_coord BOOLEAN;
BEGIN
  v_uid := auth.uid();

  -- 1. Get User Role safely
  SELECT TRIM(rol::text) INTO v_user_role FROM public.users WHERE id = v_uid;
  
  -- Explicit check for Ayudante
  IF v_user_role = 'Ayudante' THEN
      RAISE EXCEPTION 'Access Denied: Ayudantes cannot edit case details.';
  END IF;

  -- 2. Get Case Creator
  SELECT created_by INTO v_creator_id FROM public.cases WHERE id = p_case_id;

  IF v_creator_id IS NULL THEN
      RAISE EXCEPTION 'Case not found';
  END IF;

  -- 3. Check Permissions
  v_is_admin_or_coord := (v_user_role IN ('Administrador', 'Coordinador', 'Comisionado'));

  -- Allow if Admin/Coord OR if Current User is the Creator
  IF (v_is_admin_or_coord) OR (v_creator_id = v_uid) THEN
      -- Proceed with Update
      UPDATE public.cases
      SET 
        title = p_title,
        location = p_location,
        occurred_at = p_occurred_at,
        description = p_description
      WHERE id = p_case_id;
  ELSE
      RAISE EXCEPTION 'Access Denied: You do not have permission to edit this case.';
  END IF;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 4. Update Assignments
CREATE OR REPLACE FUNCTION update_case_assignments(
  p_case_id UUID,
  p_assigned_ids UUID[]
)
RETURNS VOID AS $$
DECLARE
  v_uid UUID;
  v_user_role TEXT;
BEGIN
  -- Check Permissions
  SELECT u.rol::text INTO v_user_role FROM public.users u WHERE u.id = auth.uid();
  
  IF v_user_role = 'Ayudante' THEN
    RAISE EXCEPTION 'Access Denied: Ayudantes cannot manage assignments.';
  END IF;
  
  -- Existing generic check (expanded to allow text comparison safely)
  IF v_user_role NOT IN ('Detective', 'Coordinador', 'Comisionado', 'Administrador') AND v_user_role NOT ILIKE '%Detective%' THEN
     -- Only block strict non-matches. If logic was permissive before, we keep it, but Ayudante is blocked above.
     -- Ideally, assignments should be restricted to high ranks, but matching existing logic:
     IF v_user_role NOT IN ('Detective', 'Coordinador', 'Comisionado', 'Administrador') THEN
        RAISE EXCEPTION 'Access Denied: You cannot manage assignments.';
     END IF;
  END IF;

  -- 1. Remove all current assignments for this case
  DELETE FROM public.case_assignments WHERE case_id = p_case_id;

  -- 2. Insert new ones
  IF p_assigned_ids IS NOT NULL THEN
    FOREACH v_uid IN ARRAY p_assigned_ids
    LOOP
      INSERT INTO public.case_assignments (case_id, user_id) VALUES (p_case_id, v_uid);
    END LOOP;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 5. Link Interrogation
CREATE OR REPLACE FUNCTION link_interrogation_to_case(p_interrogation_id UUID, p_case_id UUID)
RETURNS VOID AS $$
DECLARE
  v_user_rol TEXT;
BEGIN
  SELECT u.rol::text INTO v_user_rol FROM public.users u WHERE u.id = auth.uid();
  IF v_user_rol = 'Ayudante' THEN
      RAISE EXCEPTION 'Access Denied: Ayudantes cannot link interrogations.';
  END IF;

  UPDATE public.interrogations SET case_id = p_case_id WHERE id = p_interrogation_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 6. Unlink Interrogation
CREATE OR REPLACE FUNCTION unlink_interrogation(p_interrogation_id UUID)
RETURNS VOID AS $$
DECLARE
  v_user_rol TEXT;
BEGIN
  SELECT u.rol::text INTO v_user_rol FROM public.users u WHERE u.id = auth.uid();
  IF v_user_rol = 'Ayudante' THEN
      RAISE EXCEPTION 'Access Denied: Ayudantes cannot unlink interrogations.';
  END IF;

  UPDATE public.interrogations SET case_id = NULL WHERE id = p_interrogation_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
