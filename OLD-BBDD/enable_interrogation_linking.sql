
-- Enable Linking for Visible Interrogations (FIXED AMBIGUITY)
-- Aliased table 'users' access to prevent 'id' ambiguity error.

DROP FUNCTION IF EXISTS get_available_interrogations_to_link();

CREATE OR REPLACE FUNCTION get_available_interrogations_to_link()
RETURNS TABLE (
  id UUID,
  title TEXT,
  created_at TIMESTAMP WITH TIME ZONE,
  subjects TEXT
) AS $$
DECLARE
  v_uid UUID;
  v_user_fullname TEXT;
  v_user_lastname TEXT;
  v_is_vip BOOLEAN;
BEGIN
  v_uid := auth.uid();
  
  -- Get user name safely (Handle NULLs) - FIXED ALIAS u
  SELECT 
    TRIM(COALESCE(u.nombre, '') || ' ' || COALESCE(u.apellido, '')),
    TRIM(COALESCE(u.apellido, ''))
  INTO v_user_fullname, v_user_lastname
  FROM public.users u 
  WHERE u.id = v_uid;
  
  -- If name is empty, provide a dummy
  IF v_user_fullname = '' THEN v_user_fullname := '___NOMATCH___'; END IF;
  IF v_user_lastname = '' THEN v_user_lastname := '___NOMATCH___'; END IF;

  -- Check VIP Status - FIXED ALIAS u
  SELECT EXISTS (
    SELECT 1 FROM public.users u 
    WHERE u.id = v_uid 
    AND (
       TRIM(u.rol::text) IN ('Administrador', 'Coordinador', 'Comisionado', 'Detective') 
       OR u.rol::text ILIKE '%Detective%'
       OR u.rol::text ILIKE '%Admin%'
    )
  ) INTO v_is_vip;

  IF v_is_vip THEN
      -- VIP
      RETURN QUERY
      SELECT i.id, i.title, i.created_at, i.subjects
      FROM public.interrogations i
      WHERE i.case_id IS NULL
      ORDER BY i.created_at DESC;
  ELSE
      -- REGULAR
      RETURN QUERY
      SELECT i.id, i.title, i.created_at, i.subjects
      FROM public.interrogations i
      WHERE i.case_id IS NULL
      AND (
          (i.author_id = v_uid)
          OR
          (i.agents_present ILIKE '%' || v_user_fullname || '%')
          OR
          (LENGTH(v_user_lastname) > 2 AND i.agents_present ILIKE '%' || v_user_lastname || '%')
      )
      ORDER BY i.created_at DESC;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
