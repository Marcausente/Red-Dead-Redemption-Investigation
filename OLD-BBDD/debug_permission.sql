
-- Debug Permission RPC
-- Run this in Supabase SQL Editor

CREATE OR REPLACE FUNCTION debug_my_role()
RETURNS JSON AS $$
DECLARE
  v_uid UUID;
  v_rec RECORD;
BEGIN
  v_uid := auth.uid();
  SELECT * INTO v_rec FROM public.users WHERE id = v_uid;
  
  RETURN json_build_object(
    'uid', v_uid,
    'rol_raw', v_rec.rol,
    'rol_text', v_rec.rol::text,
    'matches_admin', (v_rec.rol::text ILIKE '%Admin%'),
    'matches_detective', (v_rec.rol::text ILIKE '%Detective%'),
    'matches_coordinador', (v_rec.rol::text ILIKE '%Coordinador%')
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
