
-- 1. Create Documentation Table
CREATE TABLE IF NOT EXISTS public.documentation_posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT,
  url TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  author_id UUID REFERENCES public.users(id) ON DELETE SET NULL
);

-- 2. RLS Policies
ALTER TABLE public.documentation_posts ENABLE ROW LEVEL SECURITY;

-- Read: All authenticated
DROP POLICY IF EXISTS "Allow read access for documentation" ON public.documentation_posts;
CREATE POLICY "Allow read access for documentation"
  ON public.documentation_posts FOR SELECT TO authenticated USING (true);

-- Write (RPC-based preferred for complex role checks, but we can do a policy if we had a role claim.
-- For now, we will use an RPC to handle Add/Update/Delete to safely check roles on the server side).

-- 3. RPCs for Management
CREATE OR REPLACE FUNCTION public.manage_documentation(
  p_action TEXT, -- 'create', 'update', 'delete'
  p_id UUID DEFAULT NULL,
  p_title TEXT DEFAULT NULL,
  p_description TEXT DEFAULT NULL,
  p_url TEXT DEFAULT NULL
)
RETURNS VOID AS $$
DECLARE
  v_user_role app_role;
BEGIN
  -- Get Requesting User Role
  SELECT rol INTO v_user_role FROM public.users WHERE id = auth.uid();

  -- Check Permissions
  IF v_user_role NOT IN ('Coordinador', 'Comisionado', 'Administrador') THEN
    RAISE EXCEPTION 'Access Denied: Insufficient permissions to manage documentation.';
  END IF;

  IF p_action = 'create' THEN
    INSERT INTO public.documentation_posts (title, description, url, author_id)
    VALUES (p_title, p_description, p_url, auth.uid());
    
  ELSIF p_action = 'update' THEN
    UPDATE public.documentation_posts
    SET title = p_title, description = p_description, url = p_url
    WHERE id = p_id;
    
  ELSIF p_action = 'delete' THEN
    DELETE FROM public.documentation_posts WHERE id = p_id;
    
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
