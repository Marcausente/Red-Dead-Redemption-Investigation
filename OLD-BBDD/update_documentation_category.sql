-- Add category column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'documentation_posts' AND column_name = 'category') THEN
        ALTER TABLE public.documentation_posts ADD COLUMN category TEXT DEFAULT 'documentation';
        -- Optional: Add constraint
        ALTER TABLE public.documentation_posts ADD CONSTRAINT check_category CHECK (category IN ('documentation', 'resource'));
    END IF;
END $$;

-- Update the RPC to handle category
CREATE OR REPLACE FUNCTION public.manage_documentation(
  p_action TEXT, -- 'create', 'update', 'delete'
  p_id UUID DEFAULT NULL,
  p_title TEXT DEFAULT NULL,
  p_description TEXT DEFAULT NULL,
  p_url TEXT DEFAULT NULL,
  p_category TEXT DEFAULT 'documentation' -- New parameter with default
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
    INSERT INTO public.documentation_posts (title, description, url, author_id, category)
    VALUES (p_title, p_description, p_url, auth.uid(), p_category);
    
  ELSIF p_action = 'update' THEN
    UPDATE public.documentation_posts
    SET title = p_title, description = p_description, url = p_url, category = p_category
    WHERE id = p_id;
    
  ELSIF p_action = 'delete' THEN
    DELETE FROM public.documentation_posts WHERE id = p_id;
    
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
