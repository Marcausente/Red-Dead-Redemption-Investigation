
-- 1. Create Enums if needed (re-using existing logic)
-- 'Open', 'Closed', 'Archived' will be text or a new enum. Let's use text for simplicity/flexibility.

-- 2. Create Cases Table
CREATE TABLE IF NOT EXISTS public.cases (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  case_number SERIAL, -- Auto-incrementing integer (1, 2, 3...)
  title TEXT NOT NULL,
  status TEXT DEFAULT 'Open' CHECK (status IN ('Open', 'Closed', 'Archived')),
  location TEXT,
  occurred_at TIMESTAMP WITH TIME ZONE,
  description TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_by UUID REFERENCES public.users(id)
);

-- 3. Create Assignments join table
CREATE TABLE IF NOT EXISTS public.case_assignments (
  case_id UUID REFERENCES public.cases(id) ON DELETE CASCADE,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  PRIMARY KEY (case_id, user_id)
);

-- 4. Create Updates/Novedades table
CREATE TABLE IF NOT EXISTS public.case_updates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  case_id UUID REFERENCES public.cases(id) ON DELETE CASCADE,
  author_id UUID REFERENCES public.users(id),
  content TEXT,
  image_url TEXT, -- Base64 strings will be stored here
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 5. Modify Interrogations to link to cases
-- Add case_id column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='interrogations' AND column_name='case_id') THEN
        ALTER TABLE public.interrogations ADD COLUMN case_id UUID REFERENCES public.cases(id) ON DELETE SET NULL;
    END IF;
END
$$;

-- Enable RLS
ALTER TABLE public.cases ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.case_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.case_updates ENABLE ROW LEVEL SECURITY;

-- Policies (Read: Authenticated, Write: Authenticated - Simplified for now)
CREATE POLICY "Read cases allowed for auth" ON public.cases FOR SELECT TO authenticated USING (true);
CREATE POLICY "Read assignments allowed for auth" ON public.case_assignments FOR SELECT TO authenticated USING (true);
CREATE POLICY "Read updates allowed for auth" ON public.case_updates FOR SELECT TO authenticated USING (true);
CREATE POLICY "Insert cases allowed for auth" ON public.cases FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Update cases allowed for auth" ON public.cases FOR UPDATE TO authenticated USING (true);
CREATE POLICY "Insert updates allowed for auth" ON public.case_updates FOR INSERT TO authenticated WITH CHECK (true);

-- --- RPCs ---

-- 1. Create Case Transaction
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
BEGIN
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

-- 2. Fetch Cases (List View)
CREATE OR REPLACE FUNCTION get_cases(p_status_filter TEXT DEFAULT NULL)
RETURNS TABLE (
  id UUID,
  case_number INT,
  title TEXT,
  status TEXT,
  location TEXT,
  occurred_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE,
  assigned_avatars TEXT[] -- Array of profile images for UI
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
      FROM public.case_assignments ca
      JOIN public.users u ON ca.user_id = u.id
      WHERE ca.case_id = c.id
      LIMIT 3 -- Just show first 3 avatars in list
    ) as assigned_avatars
  FROM public.cases c
  WHERE (p_status_filter IS NULL OR c.status = p_status_filter)
  ORDER BY c.case_number DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Get Full Case Detail
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

  -- Get Updates
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

  -- Get Linked Interrogations (Fixed ambiguity)
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

-- 4. Add Update
CREATE OR REPLACE FUNCTION add_case_update(
  p_case_id UUID,
  p_content TEXT,
  p_image TEXT DEFAULT NULL
)
RETURNS VOID AS $$
BEGIN
  INSERT INTO public.case_updates (case_id, author_id, content, image_url)
  VALUES (p_case_id, auth.uid(), p_content, p_image);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Update Status
CREATE OR REPLACE FUNCTION set_case_status(p_case_id UUID, p_status TEXT)
RETURNS VOID AS $$
BEGIN
  UPDATE public.cases SET status = p_status WHERE id = p_case_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. Link Interrogation
CREATE OR REPLACE FUNCTION link_interrogation_to_case(p_interrogation_id UUID, p_case_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE public.interrogations SET case_id = p_case_id WHERE id = p_interrogation_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. Unlink Interrogation
CREATE OR REPLACE FUNCTION unlink_interrogation(p_interrogation_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE public.interrogations SET case_id = NULL WHERE id = p_interrogation_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
