
-- 8. Update Case Assignments
CREATE OR REPLACE FUNCTION update_case_assignments(
  p_case_id UUID,
  p_assigned_ids UUID[]
)
RETURNS VOID AS $$
DECLARE
  v_uid UUID;
  v_user_role app_role;
BEGIN
  -- Check Permissions (Detective, Coordinator, Commissioner, Admin)
  SELECT u.rol INTO v_user_role FROM public.users u WHERE u.id = auth.uid();
  
  IF v_user_role NOT IN ('Detective', 'Coordinador', 'Comisionado', 'Administrador') THEN
    RAISE EXCEPTION 'Access Denied: You cannot manage assignments.';
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
