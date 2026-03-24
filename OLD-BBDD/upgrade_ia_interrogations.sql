-- UPGRADE IA INTERROGATIONS SYSTEM
-- Make it match the full Criminal Interrogations system features

-- 1. Alter Table
ALTER TABLE public.ia_interrogations 
ADD COLUMN IF NOT EXISTS interrogation_date DATE DEFAULT CURRENT_DATE,
ADD COLUMN IF NOT EXISTS agents_present TEXT,
ADD COLUMN IF NOT EXISTS transcription TEXT,
ADD COLUMN IF NOT EXISTS media_url TEXT;

-- 2. Drop old RPCs to avoid conflicts
DROP FUNCTION IF EXISTS get_ia_interrogations();
DROP FUNCTION IF EXISTS create_ia_interrogation(TEXT, TEXT, TEXT, UUID);

-- 3. Create New Manage RPC (Create, Update, Delete)
CREATE OR REPLACE FUNCTION manage_ia_interrogation(
  p_action TEXT, -- 'create', 'update', 'delete', 'link', 'unlink'
  p_id UUID DEFAULT NULL,
  p_title TEXT DEFAULT NULL,
  p_date DATE DEFAULT NULL,
  p_agents TEXT DEFAULT NULL,
  p_subjects TEXT DEFAULT NULL,
  p_transcription TEXT DEFAULT NULL,
  p_url TEXT DEFAULT NULL,
  p_case_id UUID DEFAULT NULL
)
RETURNS VOID AS $$
DECLARE
  v_uid UUID;
BEGIN
  v_uid := auth.uid();

  IF p_action = 'create' THEN
    INSERT INTO public.ia_interrogations (
        created_by, 
        title, 
        interrogation_date, 
        agents_present, 
        subjects, 
        transcription, 
        media_url, 
        case_id -- Optional linking on creation
    )
    VALUES (v_uid, p_title, p_date, p_agents, p_subjects, p_transcription, p_url, p_case_id);
    
  ELSIF p_action = 'update' THEN
    UPDATE public.ia_interrogations
    SET 
        title = p_title, 
        interrogation_date = p_date, 
        agents_present = p_agents, 
        subjects = p_subjects, 
        transcription = p_transcription, 
        media_url = p_url
    WHERE id = p_id;
    
  ELSIF p_action = 'delete' THEN
    DELETE FROM public.ia_interrogations WHERE id = p_id;

  ELSIF p_action = 'link' THEN
    UPDATE public.ia_interrogations SET case_id = p_case_id WHERE id = p_id;

  ELSIF p_action = 'unlink' THEN
    UPDATE public.ia_interrogations SET case_id = NULL WHERE id = p_id;

  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 4. Create New Get RPC
CREATE OR REPLACE FUNCTION get_ia_interrogations(p_case_id UUID DEFAULT NULL)
RETURNS TABLE (
  id UUID,
  title TEXT,
  interrogation_date DATE,
  agents_present TEXT,
  subjects TEXT,
  transcription TEXT,
  media_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE,
  author_name TEXT,
  linked_case_number INT,
  linked_case_title TEXT,
  can_edit BOOLEAN
) AS $$
DECLARE
  v_uid UUID;
BEGIN
  v_uid := auth.uid();

  RETURN QUERY
  SELECT
    i.id,
    i.title,
    i.interrogation_date,
    i.agents_present,
    i.subjects,
    i.transcription,
    i.media_url,
    i.created_at,
    (u.nombre || ' ' || u.apellido) as author_name,
    c.case_number as linked_case_number,
    c.title as linked_case_title,
    (i.created_by = v_uid) as can_edit -- Simple edit permission check for now
  FROM public.ia_interrogations i
  LEFT JOIN public.users u ON i.created_by = u.id
  LEFT JOIN public.ia_cases c ON i.case_id = c.id
  WHERE (p_case_id IS NULL OR i.case_id = p_case_id)
  ORDER BY i.interrogation_date DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 5. RPC to get visible/unlinked interrogations for Linking UI
CREATE OR REPLACE FUNCTION get_available_ia_interrogations_to_link()
RETURNS TABLE (
  id UUID,
  title TEXT,
  created_at TIMESTAMP WITH TIME ZONE,
  subjects TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT i.id, i.title, i.created_at, i.subjects
  FROM public.ia_interrogations i
  WHERE i.case_id IS NULL
  ORDER BY i.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
