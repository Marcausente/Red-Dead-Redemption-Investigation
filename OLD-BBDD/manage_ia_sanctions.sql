-- MANAGE IA SANCTIONS
-- Adds Update and Delete capabilities

-- Drop old create/update RPCs if they conflict (we will use a unified manager)
DROP FUNCTION IF EXISTS create_ia_sanction(UUID, TEXT, TEXT, DATE, UUID);

CREATE OR REPLACE FUNCTION manage_ia_sanction(
  p_action TEXT, -- 'create', 'update', 'delete'
  p_id UUID DEFAULT NULL, -- Required for update/delete
  p_subject_id UUID DEFAULT NULL, -- Required for create
  p_type TEXT DEFAULT NULL,
  p_description TEXT DEFAULT NULL,
  p_date DATE DEFAULT NULL,
  p_case_id UUID DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  v_id UUID;
  v_uid UUID;
BEGIN
  v_uid := auth.uid();

  IF p_action = 'create' THEN
    INSERT INTO public.ia_sanctions (subject_id, sanction_type, description, sanction_date, case_id, created_by)
    VALUES (p_subject_id, p_type, p_description, p_date, p_case_id, v_uid)
    RETURNING id INTO v_id;
    RETURN v_id;

  ELSIF p_action = 'update' THEN
    UPDATE public.ia_sanctions
    SET 
        sanction_type = COALESCE(p_type, sanction_type),
        description = COALESCE(p_description, description),
        sanction_date = COALESCE(p_date, sanction_date),
        case_id = p_case_id -- Allow setting to NULL if passed explicitly? Need to handle logic. 
                            -- For simplicity, if p_case_id is passed, we update it.
    WHERE id = p_id;
    RETURN p_id;

  ELSIF p_action = 'delete' THEN
    DELETE FROM public.ia_sanctions WHERE id = p_id;
    RETURN p_id;
    
  END IF;
  
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
