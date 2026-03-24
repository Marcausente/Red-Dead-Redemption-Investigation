-- Fix IA Case Dropdown
-- Creates a new function to ensure fresh definition and no filtering issues

DROP FUNCTION IF EXISTS get_ia_cases_dropdown();

CREATE OR REPLACE FUNCTION get_ia_cases_dropdown()
RETURNS TABLE (
  id UUID,
  title TEXT,
  case_number INT,
  status TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT i.id, i.title, i.case_number, i.status
  FROM public.ia_cases i
  ORDER BY i.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
