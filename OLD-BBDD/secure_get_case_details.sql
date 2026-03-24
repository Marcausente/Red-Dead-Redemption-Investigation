
-- SECURE GET_CASE_DETAILS (FIXED SYNTAX)
-- Use PL/pgSQL boolean assignment instead of complex SELECT EXISTS.

CREATE OR REPLACE FUNCTION get_case_details(p_case_id UUID)
RETURNS JSON AS $$
DECLARE
  v_uid UUID;
  v_case RECORD;
  v_assignments JSON;
  v_updates JSON;
  v_interrogations JSON;
  v_is_authorized BOOLEAN;
  v_user_role TEXT;
BEGIN
  v_uid := auth.uid();

  -- 1. Check if Case Exists
  SELECT * INTO v_case FROM public.cases WHERE id = p_case_id;
  IF v_case IS NULL THEN
     RAISE EXCEPTION 'Case not found';
  END IF;

  -- 2. Authorization Check
  -- Fetch current user role safely
  SELECT TRIM(rol::text) INTO v_user_role FROM public.users WHERE id = v_uid;

  -- Determine authorization
  v_is_authorized := 
      -- A. High Command / Detective Check
      (v_user_role IN ('Administrador', 'Coordinador', 'Comisionado', 'Detective')) OR
      (v_user_role ILIKE '%Detective%') OR
      -- B. Creator Check
      (v_case.created_by = v_uid) OR
      -- C. Assignment Check
      (EXISTS (SELECT 1 FROM public.case_assignments ca WHERE ca.case_id = p_case_id AND ca.user_id = v_uid));


  IF NOT v_is_authorized THEN
     RAISE EXCEPTION 'Access Denied: You do not have permission to view this case.';
  END IF;


  -- 3. Fetch Data (If authorized)

  -- Get Assignments with details
  SELECT json_agg(json_build_object(
    'user_id', u.id,
    'full_name', u.nombre || ' ' || u.apellido,
    'rank', u.rango,
    'avatar', u.profile_image
  )) INTO v_assignments
  FROM public.case_assignments ca
  JOIN public.users u ON ca.user_id = u.id
  WHERE ca.case_id = p_case_id;

  -- Get Updates
  SELECT json_agg(json_build_object(
    'id', cu.id,
    'content', cu.content,
    'image', cu.image_url,
    'created_at', cu.created_at,
    'author_name', u.nombre || ' ' || u.apellido,
    'author_rank', u.rango,
    'author_avatar', u.profile_image,
    'user_id', u.id
  )) INTO v_updates
  FROM public.case_updates cu
  JOIN public.users u ON cu.author_id = u.id
  WHERE cu.case_id = p_case_id;

  -- Get Linked Interrogations (Aliased to avoid ambiguity)
  SELECT json_agg(json_build_object(
    'id', i.id,
    'title', i.title,
    'created_at', i.created_at,
    'subjects', i.subjects
  )) INTO v_interrogations
  FROM public.interrogations i
  WHERE i.case_id = p_case_id;

  RETURN json_build_object(
    'info', v_case,
    'assignments', COALESCE(v_assignments, '[]'::json),
    'updates', COALESCE(v_updates, '[]'::json),
    'interrogations', COALESCE(v_interrogations, '[]'::json)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
