
-- Delete Case Fully RPC (Enhanced with Return Value)
-- Returns 'SUCCESS' if case deleted, 'NOT_FOUND' if ID didn't match.

DROP FUNCTION IF EXISTS delete_case_fully(uuid);

CREATE OR REPLACE FUNCTION delete_case_fully(p_case_id UUID)
RETURNS TEXT AS $$
DECLARE
  v_deleted_count INT;
BEGIN
  -- 1. Unlink interrogations (preserve the interrogation logs, just remove case link)
  UPDATE public.interrogations 
  SET case_id = NULL 
  WHERE case_id = p_case_id;

  -- 2. Delete assignments associated with the case
  DELETE FROM public.case_assignments 
  WHERE case_id = p_case_id;

  -- 3. Delete case updates (evidence/logs)
  DELETE FROM public.case_updates 
  WHERE case_id = p_case_id;

  -- 4. Finally, delete the case record
  DELETE FROM public.cases 
  WHERE id = p_case_id;
  
  GET DIAGNOSTICS v_deleted_count = ROW_COUNT;

  IF v_deleted_count > 0 THEN
    RETURN 'SUCCESS';
  ELSE
    RETURN 'NOT_FOUND';
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
