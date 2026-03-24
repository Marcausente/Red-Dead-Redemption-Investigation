
-- Get Cases Assigned to a Specific User
CREATE OR REPLACE FUNCTION get_personnel_cases(p_user_id UUID)
RETURNS TABLE (
  id UUID,
  case_number INT,
  title TEXT,
  status TEXT,
  created_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    c.id,
    c.case_number,
    c.title,
    c.status,
    c.created_at
  FROM public.cases c
  JOIN public.case_assignments ca ON c.id = ca.case_id
  WHERE ca.user_id = p_user_id
  ORDER BY c.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
