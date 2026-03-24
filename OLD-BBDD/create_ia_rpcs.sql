-- =============================================
-- IA CASES RPCS
-- =============================================

CREATE OR REPLACE FUNCTION create_ia_case(
  p_title TEXT,
  p_location TEXT,
  p_occurred_at TIMESTAMP WITH TIME ZONE,
  p_description TEXT,
  p_assigned_ids UUID[],
  p_image TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  v_new_case_id UUID;
  v_uid UUID;
BEGIN
  INSERT INTO public.ia_cases (title, location, occurred_at, description, initial_image_url, created_by)
  VALUES (p_title, p_location, p_occurred_at, p_description, p_image, auth.uid())
  RETURNING id INTO v_new_case_id;

  IF p_assigned_ids IS NOT NULL THEN
    FOREACH v_uid IN ARRAY p_assigned_ids
    LOOP
      INSERT INTO public.ia_case_assignments (case_id, user_id) VALUES (v_new_case_id, v_uid);
    END LOOP;
  END IF;

  RETURN v_new_case_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_ia_cases(p_status_filter TEXT DEFAULT NULL)
RETURNS TABLE (
  id UUID,
  case_number INT,
  title TEXT,
  status TEXT,
  location TEXT,
  occurred_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE,
  assigned_avatars TEXT[]
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    c.id,
    c.case_number,
    c.title,
    c.status,
    c.location,
    c.occurred_at,
    c.created_at,
    ARRAY(
      SELECT u.profile_image 
      FROM public.ia_case_assignments ca
      JOIN public.users u ON ca.user_id = u.id
      WHERE ca.case_id = c.id
      LIMIT 3
    )
  FROM public.ia_cases c
  WHERE (p_status_filter IS NULL OR c.status = p_status_filter)
  ORDER BY c.case_number DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_ia_case_details(p_case_id UUID)
RETURNS JSON AS $$
DECLARE
  v_case RECORD;
  v_assignments JSON;
  v_updates JSON;
  v_interrogations JSON;
BEGIN
  SELECT * INTO v_case FROM public.ia_cases WHERE id = p_case_id;

  SELECT json_agg(json_build_object(
    'user_id', u.id,
    'full_name', u.nombre || ' ' || u.apellido,
    'rank', u.rango,
    'avatar', u.profile_image
  )) INTO v_assignments
  FROM public.ia_case_assignments ca
  JOIN public.users u ON ca.user_id = u.id
  WHERE ca.case_id = p_case_id;

  SELECT json_agg(json_build_object(
    'id', cu.id,
    'content', cu.content,
    'images', cu.images,
    'created_at', cu.created_at,
    'author_name', u.nombre || ' ' || u.apellido,
    'author_rank', u.rango,
    'author_avatar', u.profile_image
  ) ORDER BY cu.created_at DESC) INTO v_updates
  FROM public.ia_case_updates cu
  JOIN public.users u ON cu.author_id = u.id
  WHERE cu.case_id = p_case_id;

  SELECT json_agg(json_build_object(
    'id', i.id,
    'title', i.title,
    'created_at', i.created_at,
    'subjects', i.subjects
  )) INTO v_interrogations
  FROM public.ia_interrogations i
  WHERE i.case_id = p_case_id;

  RETURN json_build_object(
    'info', v_case,
    'assignments', COALESCE(v_assignments, '[]'::json),
    'updates', COALESCE(v_updates, '[]'::json),
    'interrogations', COALESCE(v_interrogations, '[]'::json)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION add_ia_case_update(
  p_case_id UUID,
  p_content TEXT,
  p_images TEXT[] DEFAULT NULL
)
RETURNS VOID AS $$
BEGIN
  INSERT INTO public.ia_case_updates (case_id, author_id, content, images)
  VALUES (p_case_id, auth.uid(), p_content, p_images);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION update_ia_case_assignments(p_case_id UUID, p_assigned_ids UUID[])
RETURNS VOID AS $$
DECLARE
  v_uid UUID;
BEGIN
  DELETE FROM public.ia_case_assignments WHERE case_id = p_case_id;
  IF p_assigned_ids IS NOT NULL THEN
    FOREACH v_uid IN ARRAY p_assigned_ids
    LOOP
       INSERT INTO public.ia_case_assignments (case_id, user_id) VALUES (p_case_id, v_uid);
    END LOOP;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- IA SANCTIONS RPCS
-- =============================================

CREATE OR REPLACE FUNCTION create_ia_sanction(
  p_target_id UUID,
  p_type TEXT,
  p_amount INT,
  p_reason TEXT
)
RETURNS VOID AS $$
BEGIN
  INSERT INTO public.ia_sanctions (target_user_id, author_user_id, sanction_type, amount, reason)
  VALUES (p_target_id, auth.uid(), p_type, p_amount, p_reason);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_ia_sanctions()
RETURNS TABLE (
  id UUID,
  sanction_type TEXT,
  amount INT,
  reason TEXT,
  created_at TIMESTAMP WITH TIME ZONE,
  target_name TEXT,
  target_rank app_rank,
  author_name TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    s.id,
    s.sanction_type,
    s.amount,
    s.reason,
    s.created_at,
    (t.nombre || ' ' || t.apellido) as target_name,
    t.rango as target_rank,
    (a.nombre || ' ' || a.apellido) as author_name
  FROM public.ia_sanctions s
  JOIN public.users t ON s.target_user_id = t.id
  LEFT JOIN public.users a ON s.author_user_id = a.id
  ORDER BY s.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- IA INTERROGATIONS RPCS
-- =============================================

CREATE OR REPLACE FUNCTION create_ia_interrogation(
  p_title TEXT,
  p_summary TEXT,
  p_subjects TEXT,
  p_case_id UUID DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  v_id UUID;
BEGIN
  INSERT INTO public.ia_interrogations (title, summary, subjects, case_id, created_by)
  VALUES (p_title, p_summary, p_subjects, p_case_id, auth.uid())
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_ia_interrogations()
RETURNS TABLE (
  id UUID,
  title TEXT,
  subjects TEXT,
  created_at TIMESTAMP WITH TIME ZONE,
  case_number INT,
  author_name TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    i.id,
    i.title,
    i.subjects,
    i.created_at,
    c.case_number,
    (u.nombre || ' ' || u.apellido) as author_name
  FROM public.ia_interrogations i
  LEFT JOIN public.ia_cases c ON i.case_id = c.id
  LEFT JOIN public.users u ON i.created_by = u.id
  ORDER BY i.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
