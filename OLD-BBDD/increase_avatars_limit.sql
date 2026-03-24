-- INCREASE AVATARS LIMIT to 10
-- User requested seeing more assigned people in the case list.

CREATE OR REPLACE FUNCTION get_cases(p_status_filter TEXT DEFAULT NULL)
RETURNS TABLE (
  id UUID,
  case_number INT,
  title TEXT,
  status TEXT,
  location TEXT,
  occurred_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE,
  assigned_avatars TEXT[]
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    c.id,
    c.case_number,
    c.title,
    c.status,
    c.location,
    c.occurred_at,
    c.created_at,
    COALESCE(
      ARRAY(
        SELECT u.profile_image 
        FROM public.case_assignments ca
        JOIN public.users u ON ca.user_id = u.id
        WHERE ca.case_id = c.id
        LIMIT 10 -- CHANGED FROM 3 TO 10
      ), 
      ARRAY[]::TEXT[]
    ) as assigned_avatars
  FROM public.cases c
  WHERE (p_status_filter IS NULL OR c.status = p_status_filter)
  AND (
      EXISTS (
        SELECT 1 FROM public.users u 
        WHERE u.id = auth.uid() 
        AND (
            TRIM(u.rol::text) IN ('Administrador', 'Coordinador', 'Comisionado', 'Detective')
            OR u.rol::text ILIKE '%Detective%'
        )
      )
      OR
      (c.created_by = auth.uid()) 
      OR
      (EXISTS (SELECT 1 FROM public.case_assignments ca WHERE ca.case_id = c.id AND ca.user_id = auth.uid()))
  )
  ORDER BY c.case_number DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
