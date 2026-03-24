
-- Update get_case_details to order interrogations by date
CREATE OR REPLACE FUNCTION get_case_details(p_case_id UUID)
RETURNS JSON AS $$
DECLARE
  v_case RECORD;
  v_assignments JSON;
  v_updates JSON;
  v_interrogations JSON;
BEGIN
  -- Get Case Data
  SELECT * INTO v_case FROM public.cases WHERE id = p_case_id;

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

  -- Get Updates (Ordered by Date DESC)
  SELECT json_agg(json_build_object(
    'id', cu.id,
    'content', cu.content,
    'image', cu.image_url,
    'created_at', cu.created_at,
    'author_name', u.nombre || ' ' || u.apellido,
    'author_rank', u.rango,
    'author_avatar', u.profile_image
  ) ORDER BY cu.created_at DESC) INTO v_updates
  FROM public.case_updates cu
  JOIN public.users u ON cu.author_id = u.id
  WHERE cu.case_id = p_case_id;

  -- Get Linked Interrogations (Ordered by Date DESC)
  SELECT json_agg(json_build_object(
    'id', i.id,
    'title', i.title,
    'created_at', i.created_at,
    'subjects', i.subjects
  ) ORDER BY i.created_at DESC) INTO v_interrogations
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
