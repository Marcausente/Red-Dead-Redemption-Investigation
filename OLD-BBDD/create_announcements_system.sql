
-- 1. Create Announcements Table (IF NOT EXISTS)
CREATE TABLE IF NOT EXISTS public.announcements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  author_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  pinned BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE public.announcements ENABLE ROW LEVEL SECURITY;

-- 2. Policies
-- Read: All authenticated
DROP POLICY IF EXISTS "Allow read access for all authenticated users" ON public.announcements;
CREATE POLICY "Allow read access for all authenticated users"
  ON public.announcements FOR SELECT TO authenticated USING (true);

-- 3. RPC: get_announcements (FIXED AMBIGUITY)
CREATE OR REPLACE FUNCTION get_announcements()
RETURNS TABLE (
  id UUID,
  title TEXT,
  content TEXT,
  pinned BOOLEAN,
  created_at TIMESTAMP WITH TIME ZONE,
  author_name TEXT,
  author_image TEXT,
  author_rank app_rank,
  cur_user_can_delete BOOLEAN
) AS $$
DECLARE
  v_viewer_id UUID;
  v_viewer_role app_role;
BEGIN
  v_viewer_id := auth.uid();
  
  -- Get Viewer Role safely
  SELECT u.rol INTO v_viewer_role FROM public.users u WHERE u.id = v_viewer_id;

  RETURN QUERY
  SELECT
    a.id,
    a.title,
    a.content,
    a.pinned,
    a.created_at,
    (u.nombre || ' ' || u.apellido) as author_name,
    u.profile_image as author_image,
    u.rango as author_rank,
    (a.author_id = v_viewer_id OR v_viewer_role IN ('Administrador', 'Comisionado', 'Coordinador')) as cur_user_can_delete
  FROM public.announcements a
  LEFT JOIN public.users u ON a.author_id = u.id
  ORDER BY a.pinned DESC, a.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. RPC: create_announcement
CREATE OR REPLACE FUNCTION create_announcement(
  p_title TEXT,
  p_content TEXT,
  p_pinned BOOLEAN DEFAULT FALSE
)
RETURNS VOID AS $$
DECLARE
  v_user_role app_role;
BEGIN
  -- Check Permissions
  SELECT u.rol INTO v_user_role FROM public.users u WHERE u.id = auth.uid();
  
  IF v_user_role NOT IN ('Detective', 'Coordinador', 'Comisionado', 'Administrador') THEN
    RAISE EXCEPTION 'Access Denied: You do not have permission to post announcements.';
  END IF;

  INSERT INTO public.announcements (author_id, title, content, pinned)
  VALUES (auth.uid(), p_title, p_content, p_pinned);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. RPC: update_announcement (NEW)
CREATE OR REPLACE FUNCTION update_announcement(
  p_id UUID,
  p_title TEXT,
  p_content TEXT,
  p_pinned BOOLEAN
)
RETURNS VOID AS $$
DECLARE
  v_author_id UUID;
  v_user_role app_role;
BEGIN
  SELECT a.author_id INTO v_author_id FROM public.announcements a WHERE a.id = p_id;
  SELECT u.rol INTO v_user_role FROM public.users u WHERE u.id = auth.uid();

  -- Verify existence
  IF v_author_id IS NULL THEN
     RAISE EXCEPTION 'Announcement not found';
  END IF;

  -- Logic: Allow edit if Author OR High Command
  IF auth.uid() = v_author_id OR v_user_role IN ('Administrador', 'Comisionado', 'Coordinador') THEN
    UPDATE public.announcements
    SET title = p_title,
        content = p_content
    WHERE id = p_id;

    -- Only allow updating Pinned if High Command
    IF v_user_role IN ('Administrador', 'Comisionado', 'Coordinador') THEN
        UPDATE public.announcements SET pinned = p_pinned WHERE id = p_id;
    END IF;
  ELSE
    RAISE EXCEPTION 'Access Denied: You cannot edit this announcement.';
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. RPC: delete_announcement
CREATE OR REPLACE FUNCTION delete_announcement(p_id UUID)
RETURNS VOID AS $$
DECLARE
  v_user_role app_role;
  v_author_id UUID;
BEGIN
  SELECT a.author_id INTO v_author_id FROM public.announcements a WHERE a.id = p_id;
  SELECT u.rol INTO v_user_role FROM public.users u WHERE u.id = auth.uid();

  -- Allow if own post OR if High Rank Role
  IF auth.uid() = v_author_id OR v_user_role IN ('Administrador', 'Comisionado', 'Coordinador') THEN
    DELETE FROM public.announcements WHERE id = p_id;
  ELSE
    RAISE EXCEPTION 'Access Denied: Cannot delete this announcement.';
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. RPC: toggle_pin_announcement
CREATE OR REPLACE FUNCTION toggle_pin_announcement(p_id UUID)
RETURNS VOID AS $$
DECLARE
  v_user_role app_role;
BEGIN
  SELECT u.rol INTO v_user_role FROM public.users u WHERE u.id = auth.uid();

  IF v_user_role IN ('Administrador', 'Comisionado', 'Coordinador') THEN
    UPDATE public.announcements SET pinned = NOT pinned WHERE id = p_id;
  ELSE
    RAISE EXCEPTION 'Access Denied: Only High Command can pin posts.';
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
