
-- GET PERSONNEL VISIBLE CASES (FIXED AMBIGUITY)
-- Added strict table aliasing (u.id) to prevent conflict with output parameter 'id'.

CREATE OR REPLACE FUNCTION get_personnel_visible_cases(p_target_user_id UUID)
RETURNS TABLE (
  id UUID,
  case_number INT,
  title TEXT,
  status TEXT,
  created_at TIMESTAMP WITH TIME ZONE
) AS $$
DECLARE
  v_uid UUID;
  v_user_role TEXT;
  v_is_vip BOOLEAN;
BEGIN
  v_uid := auth.uid();
  
  -- 1. Check Permissions of Viewer (Aliased 'u')
  SELECT TRIM(u.rol::text) INTO v_user_role 
  FROM public.users u 
  WHERE u.id = v_uid;

  v_is_vip := (
      v_user_role IN ('Administrador', 'Coordinador', 'Comisionado', 'Detective') OR
      v_user_role ILIKE '%Detective%'
  );

  RETURN QUERY
  SELECT
    c.id,
    c.case_number,
    c.title,
    c.status,
    c.created_at
  FROM public.cases c
  JOIN public.case_assignments ca_target ON c.id = ca_target.case_id
  WHERE ca_target.user_id = p_target_user_id
  AND (
      -- Accessibility Check
      v_is_vip -- Viewer is VIP
      OR
      (c.created_by = v_uid) -- Viewer is Creator
      OR
      (EXISTS (SELECT 1 FROM public.case_assignments ca_viewer WHERE ca_viewer.case_id = c.id AND ca_viewer.user_id = v_uid)) -- Viewer is ALSO assigned
  )
  ORDER BY c.created_at DESC;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
