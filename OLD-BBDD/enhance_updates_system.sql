-- ENHANCE UPDATES SYSTEM: MULTI-IMAGE SUPPORT

-- 1. Schema Migration: Add 'images' JSONB column
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='case_updates' AND column_name='images') THEN
        ALTER TABLE public.case_updates ADD COLUMN images JSONB DEFAULT '[]'::jsonb;
        
        -- Migrate existing single images to the new array format
        UPDATE public.case_updates 
        SET images = jsonb_build_array(image_url) 
        WHERE image_url IS NOT NULL AND image_url != '';
    END IF;
END
$$;

-- 2. Update RPC: add_case_update
-- Now accepts p_images (JSONB array) and allow p_content to be empty IF images exist.
CREATE OR REPLACE FUNCTION add_case_update(
  p_case_id UUID,
  p_content TEXT,
  p_images JSONB DEFAULT '[]'::jsonb 
)
RETURNS VOID AS $$
BEGIN
  -- Validation: Must have either content OR images
  IF (p_content IS NULL OR TRIM(p_content) = '') AND (jsonb_array_length(p_images) = 0) THEN
      RAISE EXCEPTION 'Update must contain either text or images.';
  END IF;

  INSERT INTO public.case_updates (case_id, author_id, content, images, created_at)
  VALUES (p_case_id, auth.uid(), p_content, p_images, NOW());
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 3. Update RPC: get_case_details
-- Updated to select the 'images' column
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
  SELECT TRIM(rol::text) INTO v_user_role FROM public.users WHERE id = v_uid;

  v_is_authorized := 
      (v_user_role IN ('Administrador', 'Coordinador', 'Comisionado', 'Detective')) OR
      (v_user_role ILIKE '%Detective%') OR
      (v_case.created_by = v_uid) OR
      (EXISTS (SELECT 1 FROM public.case_assignments ca WHERE ca.case_id = p_case_id AND ca.user_id = v_uid));

  IF NOT v_is_authorized THEN
     RAISE EXCEPTION 'Access Denied: You do not have permission to view this case.';
  END IF;

  -- 3. Fetch Data

  -- Get Assignments
  SELECT json_agg(json_build_object(
    'user_id', u.id,
    'full_name', u.nombre || ' ' || u.apellido,
    'rank', u.rango,
    'avatar', u.profile_image
  )) INTO v_assignments
  FROM public.case_assignments ca
  JOIN public.users u ON ca.user_id = u.id
  WHERE ca.case_id = p_case_id;

  -- Get Updates (Including NEW images column)
  SELECT json_agg(json_build_object(
    'id', cu.id,
    'content', cu.content,
    'images', cu.images,       -- <--- NEW FIELD
    'image', cu.image_url,     -- Keep for backward compatibility if needed, but UI should prefer 'images'
    'created_at', cu.created_at,
    'author_name', u.nombre || ' ' || u.apellido,
    'author_rank', u.rango,
    'author_avatar', u.profile_image,
    'user_id', u.id
  ) ORDER BY cu.created_at DESC) INTO v_updates
  FROM public.case_updates cu
  JOIN public.users u ON cu.author_id = u.id
  WHERE cu.case_id = p_case_id;

  -- Get Linked Interrogations
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
