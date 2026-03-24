-- CASE EDITING PERMISSIONS RPC

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
