-- Add category column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='ia_documentation' AND column_name='category') THEN
        ALTER TABLE public.ia_documentation ADD COLUMN category TEXT DEFAULT 'documentation';
    END IF;
END
$$;

-- Update RPC to handle category
CREATE OR REPLACE FUNCTION manage_ia_documentation(
  p_action TEXT,
  p_id UUID DEFAULT NULL,
  p_title TEXT DEFAULT NULL,
  p_description TEXT DEFAULT NULL,
  p_url TEXT DEFAULT NULL,
  p_category TEXT DEFAULT 'documentation'
)
RETURNS VOID AS $$
BEGIN
  IF p_action = 'create' THEN
    INSERT INTO public.ia_documentation (title, description, url, category, created_by)
    VALUES (p_title, p_description, p_url, p_category, auth.uid());
  ELSIF p_action = 'update' THEN
    UPDATE public.ia_documentation
    SET title = p_title, description = p_description, url = p_url, category = p_category
    WHERE id = p_id;
  ELSIF p_action = 'delete' THEN
    DELETE FROM public.ia_documentation WHERE id = p_id;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
