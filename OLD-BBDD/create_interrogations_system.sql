-- 1. Create Interrogations Table
CREATE TABLE IF NOT EXISTS public.interrogations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  author_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
  title TEXT NOT NULL,
  interrogation_date DATE NOT NULL,
  agents_present TEXT,
  subjects TEXT,
  transcription TEXT,
  media_url TEXT
);

-- 2. RLS Policies (We'll use RPCs for main logic, but secure the table)
ALTER TABLE public.interrogations ENABLE ROW LEVEL SECURITY;

-- Read policy (Fallback, though RPC handles it mostly)
CREATE POLICY "RLS_Interrogations_Select" ON public.interrogations
FOR SELECT USING (
  (SELECT rol FROM public.users WHERE id = auth.uid()) IN ('Detective', 'Coordinador', 'Comisionado', 'Administrador')
  OR
  author_id = auth.uid()
);

-- 3. RPC to Get Interrogations (Enforcing the specific view logic)
CREATE OR REPLACE FUNCTION get_interrogations()
RETURNS TABLE (
  id UUID,
  created_at TIMESTAMP WITH TIME ZONE,
  author_id UUID,
  author_name TEXT,
  title TEXT,
  interrogation_date DATE,
  agents_present TEXT,
  subjects TEXT,
  transcription TEXT,
  media_url TEXT,
  can_edit BOOLEAN
) AS $$
DECLARE
  v_user_role app_role;
  v_user_id UUID;
BEGIN
  v_user_id := auth.uid();
  SELECT rol INTO v_user_role FROM public.users WHERE id = v_user_id;

  RETURN QUERY
  SELECT 
    i.id,
    i.created_at,
    i.author_id,
    (u.nombre || ' ' || u.apellido) as author_name,
    i.title,
    i.interrogation_date,
    i.agents_present,
    i.subjects,
    i.transcription,
    i.media_url,
    -- Determine if current user can edit this specific row
    (v_user_role IN ('Coordinador', 'Comisionado', 'Administrador') OR i.author_id = v_user_id) as can_edit
  FROM public.interrogations i
  LEFT JOIN public.users u ON i.author_id = u.id
  WHERE 
    -- Logic: If high rank, see all. If Ayudante, see only own.
    CASE 
      WHEN v_user_role IN ('Detective', 'Coordinador', 'Comisionado', 'Administrador') THEN TRUE
      ELSE i.author_id = v_user_id
    END
  ORDER BY i.interrogation_date DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. RPC to Manage Interrogations (Create, Update, Delete)
CREATE OR REPLACE FUNCTION manage_interrogation(
  p_action TEXT, -- 'create', 'update', 'delete'
  p_id UUID DEFAULT NULL,
  p_title TEXT DEFAULT NULL,
  p_date DATE DEFAULT NULL,
  p_agents TEXT DEFAULT NULL,
  p_subjects TEXT DEFAULT NULL,
  p_transcription TEXT DEFAULT NULL,
  p_url TEXT DEFAULT NULL
)
RETURNS VOID AS $$
DECLARE
  v_user_role app_role;
  v_author_id UUID;
BEGIN
  SELECT rol INTO v_user_role FROM public.users WHERE id = auth.uid();

  -- Get author of the target post if updating/deleting
  IF p_id IS NOT NULL THEN
    SELECT author_id INTO v_author_id FROM public.interrogations WHERE id = p_id;
  END IF;

  IF p_action = 'create' THEN
    -- Anyone logged in can likely create, or restrict to specific roles? 
    -- Assuming all personnel (including Ayudante) can create their own.
    INSERT INTO public.interrogations (author_id, title, interrogation_date, agents_present, subjects, transcription, media_url)
    VALUES (auth.uid(), p_title, p_date, p_agents, p_subjects, p_transcription, p_url);
    
  ELSIF p_action = 'update' THEN
    -- Logic: Admins/Coord/Comis OR the original author
    IF v_user_role IN ('Coordinador', 'Comisionado', 'Administrador') OR v_author_id = auth.uid() THEN
        UPDATE public.interrogations
        SET title = p_title, interrogation_date = p_date, agents_present = p_agents, subjects = p_subjects, transcription = p_transcription, media_url = p_url
        WHERE id = p_id;
    ELSE
        RAISE EXCEPTION 'Access Denied: You cannot edit this interrogation.';
    END IF;
    
  ELSIF p_action = 'delete' THEN
    -- Logic: Admins/Coord/Comis OR the original author
    IF v_user_role IN ('Coordinador', 'Comisionado', 'Administrador') OR v_author_id = auth.uid() THEN
        DELETE FROM public.interrogations WHERE id = p_id;
    ELSE
        RAISE EXCEPTION 'Access Denied: You cannot delete this interrogation.';
    END IF;
    
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
