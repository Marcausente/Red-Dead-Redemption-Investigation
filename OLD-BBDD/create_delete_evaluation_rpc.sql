-- 1. Create a function to delete evaluations securely
CREATE OR REPLACE FUNCTION delete_evaluation(p_evaluation_id UUID)
RETURNS VOID AS $$
DECLARE
  v_viewer_id UUID;
  v_viewer_rank app_rank;
  v_target_user_id UUID;
  v_target_user_rank app_rank;
BEGIN
  v_viewer_id := auth.uid();

  -- Get Viewer Rank
  SELECT rango INTO v_viewer_rank FROM public.users WHERE id = v_viewer_id;

  -- Get Target User ID and Rank from the evaluation
  SELECT e.target_user_id, u.rango 
  INTO v_target_user_id, v_target_user_rank
  FROM public.evaluations e
  JOIN public.users u ON e.target_user_id = u.id
  WHERE e.id = p_evaluation_id;

  -- Verify existence
  IF v_target_user_id IS NULL THEN
    RAISE EXCEPTION 'Evaluation not found';
  END IF;

  -- Perform the same check as the frontend (Viewer > Target in rank hierarchy)
  -- Since SQL enums are ordered, we can usually compare them, but our custom order might differ.
  -- To be safe and reuse logic, let's just assume if they're calling this they likely have the right, but let's implement a quick check.
  -- Simplified check: If you are Captain or Lieutenant you can delete. Or if you are the author?
  -- User requested: "Delete evaluations they are able to see".
  -- Frontend logic is: Viewer Rank > Target Rank.
  -- We'll implement a helper function for Rank Level or just hardcode the hierarchy check here.
  
  -- Re-implementing simplified rank check for security context
  -- (Ideally we'd have a function `get_rank_level` in SQL but let's do a quick CASE here)
  
  IF (
     CASE v_viewer_rank
       WHEN 'Capitan' THEN 100
       WHEN 'Teniente' THEN 90
       WHEN 'Detective III' THEN 80
       WHEN 'Detective II' THEN 70
       WHEN 'Detective I' THEN 60
       WHEN 'Oficial III+' THEN 50
       WHEN 'Oficial III' THEN 40
       WHEN 'Oficial II' THEN 30
       ELSE 0
     END
     >
     CASE v_target_user_rank
       WHEN 'Capitan' THEN 100
       WHEN 'Teniente' THEN 90
       WHEN 'Detective III' THEN 80
       WHEN 'Detective II' THEN 70
       WHEN 'Detective I' THEN 60
       WHEN 'Oficial III+' THEN 50
       WHEN 'Oficial III' THEN 40
       WHEN 'Oficial II' THEN 30
       ELSE 0
     END
  ) THEN
     DELETE FROM public.evaluations WHERE id = p_evaluation_id;
  ELSE
     RAISE EXCEPTION 'Access Denied: You do not have sufficient rank to delete this evaluation.';
  END IF;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
