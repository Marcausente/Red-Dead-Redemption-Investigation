
-- 1. Helper Function: Get Numeric Rank Level
-- Levels:
-- 1: Oficial II, Oficial III, Oficial III+
-- 2: Detective I
-- 3: Detective II
-- 4: Detective III
-- 5: Teniente, Capitan

CREATE OR REPLACE FUNCTION public.get_rank_level(r app_rank) RETURNS INTEGER AS $$
BEGIN
    RETURN CASE r
        WHEN 'Oficial II' THEN 1
        WHEN 'Oficial III' THEN 1
        WHEN 'Oficial III+' THEN 1
        WHEN 'Detective I' THEN 2
        WHEN 'Detective II' THEN 3
        WHEN 'Detective III' THEN 4
        WHEN 'Teniente' THEN 5
        WHEN 'Capitan' THEN 5
        ELSE 0
    END;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- 2. Check Access Function
CREATE OR REPLACE FUNCTION public.check_evaluation_access(viewer_id UUID, target_id UUID) RETURNS BOOLEAN AS $$
DECLARE
    viewer_rank app_rank;
    target_rank app_rank;
BEGIN
    -- Get ranks
    SELECT rango INTO viewer_rank FROM public.users WHERE id = viewer_id;
    SELECT rango INTO target_rank FROM public.users WHERE id = target_id;

    IF viewer_rank IS NULL OR target_rank IS NULL THEN
        RETURN FALSE;
    END IF;

    -- Logic: Viewer must be STRICTLY HIGHER than Target
    RETURN get_rank_level(viewer_rank) > get_rank_level(target_rank);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Update get_evaluations RPC
CREATE OR REPLACE FUNCTION get_evaluations(p_target_user_id UUID)
RETURNS TABLE (
  id UUID,
  content TEXT,
  created_at TIMESTAMP WITH TIME ZONE,
  author_name TEXT,
  author_rank app_rank
) AS $$
BEGIN
  -- Enforce Access Logic
  IF NOT public.check_evaluation_access(auth.uid(), p_target_user_id) THEN
     RAISE EXCEPTION 'Access Denied: Level insufficient for viewing evaluations.';
  END IF;

  RETURN QUERY
  SELECT
    e.id,
    e.content,
    e.created_at,
    (u.nombre || ' ' || u.apellido) as author_name,
    u.rango as author_rank
  FROM public.evaluations e
  LEFT JOIN public.users u ON e.author_user_id = u.id
  WHERE e.target_user_id = p_target_user_id
  ORDER BY e.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Update add_evaluation RPC
CREATE OR REPLACE FUNCTION add_evaluation(p_target_user_id UUID, p_content TEXT)
RETURNS VOID AS $$
BEGIN
  -- Enforce Access Logic
  IF NOT public.check_evaluation_access(auth.uid(), p_target_user_id) THEN
     RAISE EXCEPTION 'Access Denied: Level insufficient for creating evaluation.';
  END IF;

  INSERT INTO public.evaluations (target_user_id, author_user_id, content)
  VALUES (p_target_user_id, auth.uid(), p_content);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. RLS Policies (Backup Security)
-- Although RPCs are Security Definier and handle checks, RLS on the table is good practice
-- if direct table access is ever allowed.
ALTER TABLE public.evaluations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Rank Based Read Access" ON public.evaluations;
CREATE POLICY "Rank Based Read Access"
  ON public.evaluations FOR SELECT TO authenticated
  USING (
    public.check_evaluation_access(auth.uid(), target_user_id)
  );

DROP POLICY IF EXISTS "Rank Based Insert Access" ON public.evaluations;
CREATE POLICY "Rank Based Insert Access"
  ON public.evaluations FOR INSERT TO authenticated
  WITH CHECK (
    public.check_evaluation_access(auth.uid(), target_user_id) AND
    auth.uid() = author_user_id
  );
