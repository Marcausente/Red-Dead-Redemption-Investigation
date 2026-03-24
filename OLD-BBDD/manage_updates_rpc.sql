
-- Functions to manage Case Updates (Edit/Delete)

-- 1. Delete Update
DROP FUNCTION IF EXISTS delete_case_update(uuid);
CREATE OR REPLACE FUNCTION delete_case_update(p_update_id UUID)
RETURNS VOID AS $$
BEGIN
  DELETE FROM public.case_updates WHERE id = p_update_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Edit Update Content
DROP FUNCTION IF EXISTS update_case_update_content(uuid, text);
CREATE OR REPLACE FUNCTION update_case_update_content(p_update_id UUID, p_content TEXT)
RETURNS VOID AS $$
BEGIN
  UPDATE public.case_updates
  SET content = p_content
  WHERE id = p_update_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
