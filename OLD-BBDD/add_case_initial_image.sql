-- 1. Add image column to cases table
ALTER TABLE public.cases ADD COLUMN IF NOT EXISTS initial_image_url TEXT DEFAULT NULL;

-- 2. Update Create Case RPC
CREATE OR REPLACE FUNCTION create_new_case(
  p_title TEXT,
  p_location TEXT,
  p_occurred_at TIMESTAMP WITH TIME ZONE,
  p_description TEXT,
  p_assigned_ids UUID[],
  p_image TEXT DEFAULT NULL  -- New Parameter
)
RETURNS UUID AS $$
DECLARE
  v_new_case_id UUID;
  v_uid UUID;
BEGIN
  -- Insert Case
  INSERT INTO public.cases (title, location, occurred_at, description, created_by, initial_image_url)
  VALUES (p_title, p_location, p_occurred_at, p_description, auth.uid(), p_image)
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

-- 3. Update Get Case Details RPC
CREATE OR REPLACE FUNCTION get_case_details(p_case_id UUID)
RETURNS JSON AS $$
DECLARE
  v_case RECORD;
  v_assignments JSON;
  v_updates JSON;
  v_interrogations JSON;
BEGIN
  -- Get Case Data (select * automatically includes new column)
  SELECT * INTO v_case FROM public.cases WHERE id = p_case_id;

  -- Get Assignments... (unchanged)
  SELECT json_agg(json_build_object(
    'user_id', u.id,
    'full_name', u.nombre || ' ' || u.apellido,
    'rank', u.rango,
    'avatar', u.profile_image
  )) INTO v_assignments
  FROM public.case_assignments ca
  JOIN public.users u ON ca.user_id = u.id
  WHERE ca.case_id = p_case_id;

  -- Get Updates... (unchanged)
  SELECT json_agg(json_build_object(
    'id', cu.id,
    'content', cu.content,
    'image', cu.image_url,
    'images', cu.images,
    'created_at', cu.created_at,
    'author_name', u.nombre || ' ' || u.apellido,
    'author_rank', u.rango,
    'author_avatar', u.profile_image
  ) ORDER BY cu.created_at DESC) INTO v_updates
  FROM public.case_updates cu
  JOIN public.users u ON cu.author_id = u.id
  WHERE cu.case_id = p_case_id;

  -- Get Linked Interrogations... (unchanged)
  SELECT json_agg(json_build_object(
    'id', i.id,
    'title', i.title,
    'created_at', i.created_at,
    'subjects', i.subjects
  )) INTO v_interrogations
  FROM public.interrogations i
  WHERE i.case_id = p_case_id;

  RETURN json_build_object(
    'info', v_case, -- Will now include initial_image_url
    'assignments', COALESCE(v_assignments, '[]'::json),
    'updates', COALESCE(v_updates, '[]'::json),
    'interrogations', COALESCE(v_interrogations, '[]'::json)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
