-- IA Documentation Table
CREATE TABLE IF NOT EXISTS public.ia_documentation (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT,
  url TEXT, -- Link or Base64 image
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_by UUID REFERENCES public.users(id)
);

-- RLS
ALTER TABLE public.ia_documentation ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow Auth Read IA Docs" ON public.ia_documentation FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow Auth Write IA Docs" ON public.ia_documentation FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- RPC to manage
CREATE OR REPLACE FUNCTION manage_ia_documentation(
  p_action TEXT,
  p_id UUID DEFAULT NULL,
  p_title TEXT DEFAULT NULL,
  p_description TEXT DEFAULT NULL,
  p_url TEXT DEFAULT NULL
)
RETURNS VOID AS $$
BEGIN
  IF p_action = 'create' THEN
    INSERT INTO public.ia_documentation (title, description, url, created_by)
    VALUES (p_title, p_description, p_url, auth.uid());
  ELSIF p_action = 'update' THEN
    UPDATE public.ia_documentation
    SET title = p_title, description = p_description, url = p_url
    WHERE id = p_id;
  ELSIF p_action = 'delete' THEN
    DELETE FROM public.ia_documentation WHERE id = p_id;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
