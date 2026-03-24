-- Helper script to ensure the Interrogation RPCs are clean and correct
-- RUN THIS IN SUPABASE SQL EDITOR

-- 1. Drop existing functions to avoid conflicts or signature mismatches
DROP FUNCTION IF EXISTS public.get_interrogations();
-- Drop with arguments if it was created that way by mistake previously
DROP FUNCTION IF EXISTS public.manage_interrogation(text, uuid, text, date, text, text, text, text);

-- 2. Re-create get_interrogations with AMBIGUITY FIX
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
  
  -- Handle case where user is not logged in or user record missing
  -- FIX: qualified 'id' with table alias 'u' to avoid ambiguity with output column 'id'
  SELECT rol INTO v_user_role FROM public.users u WHERE u.id = v_user_id;

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
    -- Logic: If high rank, see all. If Ayudante/Detective, see only own? 
    CASE 
      WHEN v_user_role IN ('Detective', 'Coordinador', 'Comisionado', 'Administrador') THEN TRUE
      ELSE i.author_id = v_user_id OR v_user_role IS NULL -- Fallback
    END
  ORDER BY i.interrogation_date DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Re-create manage_interrogation
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
  SELECT rol INTO v_user_role FROM public.users u WHERE u.id = auth.uid();

  -- Get author of the target post if updating/deleting
  IF p_id IS NOT NULL THEN
    SELECT author_id INTO v_author_id FROM public.interrogations WHERE id = p_id;
  END IF;

  IF p_action = 'create' THEN
    INSERT INTO public.interrogations (author_id, title, interrogation_date, agents_present, subjects, transcription, media_url)
    VALUES (auth.uid(), p_title, p_date, p_agents, p_subjects, p_transcription, p_url);
    
  ELSIF p_action = 'update' THEN
    IF v_user_role IN ('Coordinador', 'Comisionado', 'Administrador') OR v_author_id = auth.uid() THEN
        UPDATE public.interrogations
        SET title = p_title, interrogation_date = p_date, agents_present = p_agents, subjects = p_subjects, transcription = p_transcription, media_url = p_url
        WHERE id = p_id;
    ELSE
        RAISE EXCEPTION 'Access Denied: You cannot edit this interrogation.';
    END IF;
    
  ELSIF p_action = 'delete' THEN
    IF v_user_role IN ('Coordinador', 'Comisionado', 'Administrador') OR v_author_id = auth.uid() THEN
        DELETE FROM public.interrogations WHERE id = p_id;
    ELSE
        RAISE EXCEPTION 'Access Denied: You cannot delete this interrogation.';
    END IF;
    
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
