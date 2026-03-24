
-- CASE TO-DO SYSTEM (Categories & Tasks)

-- 1. Create Tables
CREATE TABLE IF NOT EXISTS public.case_todo_categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  case_id UUID REFERENCES public.cases(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.case_todos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  category_id UUID REFERENCES public.case_todo_categories(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  is_completed BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.case_todo_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.case_todos ENABLE ROW LEVEL SECURITY;

-- Policies (Simplified: Authenticated users can read/write - Frontend validates permissions via role logic)
CREATE POLICY "Auth Read Cats" ON public.case_todo_categories FOR SELECT TO authenticated USING (true);
CREATE POLICY "Auth Write Cats" ON public.case_todo_categories FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Auth Update Cats" ON public.case_todo_categories FOR UPDATE TO authenticated USING (true);
CREATE POLICY "Auth Delete Cats" ON public.case_todo_categories FOR DELETE TO authenticated USING (true);

CREATE POLICY "Auth Read Todos" ON public.case_todos FOR SELECT TO authenticated USING (true);
CREATE POLICY "Auth Write Todos" ON public.case_todos FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Auth Update Todos" ON public.case_todos FOR UPDATE TO authenticated USING (true);
CREATE POLICY "Auth Delete Todos" ON public.case_todos FOR DELETE TO authenticated USING (true);


-- 2. RPCs

-- FETCH TODOs (Hierarchical JSON)
CREATE OR REPLACE FUNCTION get_case_todos(p_case_id UUID)
RETURNS JSON AS $$
DECLARE
  v_result JSON;
BEGIN
  SELECT json_agg(
      json_build_object(
          'id', c.id,
          'name', c.name,
          'created_at', c.created_at,
          'tasks', (
              SELECT COALESCE(json_agg(
                  json_build_object(
                      'id', t.id,
                      'content', t.content,
                      'is_completed', t.is_completed,
                      'created_at', t.created_at
                  ) ORDER BY t.created_at ASC
              ), '[]'::json)
              FROM public.case_todos t
              WHERE t.category_id = c.id
          )
      ) ORDER BY c.created_at ASC
  ) INTO v_result
  FROM public.case_todo_categories c
  WHERE c.case_id = p_case_id;

  RETURN COALESCE(v_result, '[]'::json);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- CREATE CATEGORY
CREATE OR REPLACE FUNCTION create_todo_category(p_case_id UUID, p_name TEXT)
RETURNS UUID AS $$
DECLARE
  v_id UUID;
BEGIN
  INSERT INTO public.case_todo_categories (case_id, name)
  VALUES (p_case_id, p_name)
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- UPDATE CATEGORY NAME
CREATE OR REPLACE FUNCTION update_todo_category(p_category_id UUID, p_name TEXT)
RETURNS VOID AS $$
BEGIN
  UPDATE public.case_todo_categories SET name = p_name WHERE id = p_category_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- DELETE CATEGORY
CREATE OR REPLACE FUNCTION delete_todo_category(p_category_id UUID)
RETURNS VOID AS $$
BEGIN
  DELETE FROM public.case_todo_categories WHERE id = p_category_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- CREATE TASK
CREATE OR REPLACE FUNCTION create_todo_task(p_category_id UUID, p_content TEXT)
RETURNS UUID AS $$
DECLARE
  v_id UUID;
BEGIN
  INSERT INTO public.case_todos (category_id, content)
  VALUES (p_category_id, p_content)
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- TOGGLE TASK
CREATE OR REPLACE FUNCTION toggle_todo_task(p_task_id UUID, p_status BOOLEAN)
RETURNS VOID AS $$
BEGIN
  UPDATE public.case_todos SET is_completed = p_status WHERE id = p_task_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- DELETE TASK
CREATE OR REPLACE FUNCTION delete_todo_task(p_task_id UUID)
RETURNS VOID AS $$
BEGIN
  DELETE FROM public.case_todos WHERE id = p_task_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
