
-- Function to get database size (Admin Only)
CREATE OR REPLACE FUNCTION public.get_db_usage()
RETURNS json AS $$
DECLARE
  total_size BIGINT;
BEGIN
  -- Check if requester is Admin
  IF NOT EXISTS (
    SELECT 1 FROM public.users 
    WHERE id = auth.uid() 
    AND rol = 'Administrador'
  ) THEN
    RAISE EXCEPTION 'Access Denied: Only Administrators can view database usage.';
  END IF;

  -- Get DB Size
  SELECT pg_database_size(current_database()) INTO total_size;

  RETURN json_build_object(
    'used_bytes', total_size
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
