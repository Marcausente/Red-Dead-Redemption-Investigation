-- 1. Create Documentation Table
CREATE TABLE IF NOT EXISTS public.documentation_posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT,
  url TEXT NOT NULL,
  category TEXT DEFAULT 'documentation',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  author_id UUID REFERENCES public.users(id) ON DELETE SET NULL
);

-- 2. RLS Policies
ALTER TABLE public.documentation_posts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow read access for documentation" ON public.documentation_posts;
CREATE POLICY "Allow read access for documentation"
  ON public.documentation_posts FOR SELECT TO authenticated USING (true);

-- 3. RPCs for Management
CREATE OR REPLACE FUNCTION public.manage_documentation(
  p_action TEXT, -- 'create', 'update', 'delete'
  p_id UUID DEFAULT NULL,
  p_title TEXT DEFAULT NULL,
  p_description TEXT DEFAULT NULL,
  p_url TEXT DEFAULT NULL,
  p_category TEXT DEFAULT 'documentation'
)
RETURNS VOID AS $$
DECLARE
  v_user_role app_role;
BEGIN
  -- Get Requesting User Role
  SELECT rol INTO v_user_role FROM public.users WHERE id = auth.uid();

  -- Check Permissions (BOI Rules: Coordinators and Admins only)
  IF v_user_role NOT IN ('Coordinador', 'Administrador') THEN
    RAISE EXCEPTION 'Acceso denegado: Rango insuficiente para gestionar archivos oficiales.';
  END IF;

  IF p_action = 'create' THEN
    INSERT INTO public.documentation_posts (title, description, url, category, author_id)
    VALUES (p_title, p_description, p_url, p_category, auth.uid());
    
  ELSIF p_action = 'update' THEN
    UPDATE public.documentation_posts
    SET title = p_title, description = p_description, url = p_url, category = p_category
    WHERE id = p_id;
    
  ELSIF p_action = 'delete' THEN
    DELETE FROM public.documentation_posts WHERE id = p_id;
    
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
