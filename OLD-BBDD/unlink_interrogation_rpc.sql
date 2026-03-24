
-- Unlink Interrogation RPC
-- Removes the link between an interrogation and a case without deleting the interrogation itself.

CREATE OR REPLACE FUNCTION unlink_interrogation(p_interrogation_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE public.interrogations
  SET case_id = NULL
  WHERE id = p_interrogation_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
