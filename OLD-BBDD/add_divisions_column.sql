-- 1. Add divisions column to public.users
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS divisions TEXT[] DEFAULT ARRAY['Detective Bureau'];

-- 2. Backfill existing users (safety check)
UPDATE public.users 
SET divisions = ARRAY['Detective Bureau'] 
WHERE divisions IS NULL OR cardinality(divisions) = 0;

-- 3. Update create_new_personnel to include divisions
CREATE OR REPLACE FUNCTION create_new_personnel(
  p_email TEXT,
  p_password TEXT,
  p_nombre TEXT,
  p_apellido TEXT,
  p_no_placa TEXT,
  p_rango app_rank,
  p_rol app_role,
  p_fecha_ingreso TIMESTAMP WITH TIME ZONE DEFAULT NULL,
  p_fecha_ultimo_ascenso TIMESTAMP WITH TIME ZONE DEFAULT NULL,
  p_profile_image TEXT DEFAULT NULL,
  p_divisions TEXT[] DEFAULT ARRAY['Detective Bureau']
)
RETURNS VOID AS $$
DECLARE
  new_user_id UUID;
BEGIN
  new_user_id := gen_random_uuid();

  -- 1. Insert into auth.users
  INSERT INTO auth.users (
    instance_id,
    id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    recovery_sent_at,
    last_sign_in_at,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at,
    confirmation_token,
    email_change,
    email_change_token_new,
    recovery_token
  ) VALUES (
    '00000000-0000-0000-0000-000000000000',
    new_user_id,
    'authenticated',
    'authenticated',
    p_email,
    crypt(p_password, gen_salt('bf')),
    NOW(),
    null,
    null,
    '{"provider": "email", "providers": ["email"]}',
    jsonb_build_object('nombre', p_nombre, 'apellido', p_apellido, 'no_placa', p_no_placa),
    NOW(),
    NOW(),
    '',
    '',
    '',
    ''
  );

  -- 2. Insert into auth.identities
  INSERT INTO auth.identities (
    id,
    user_id,
    identity_data,
    provider,
    provider_id,
    last_sign_in_at,
    created_at,
    updated_at
  ) VALUES (
    gen_random_uuid(),
    new_user_id,
    format('{"sub": "%s", "email": "%s"}', new_user_id::text, p_email)::jsonb,
    'email',
    new_user_id::text,
    null,
    NOW(),
    NOW()
  );

  -- 3. Insert into public.users with divisions
  INSERT INTO public.users (
    id, email, nombre, apellido, no_placa, rango, rol, fecha_ingreso, profile_image, divisions
  ) VALUES (
    new_user_id,
    p_email,
    p_nombre,
    p_apellido,
    p_no_placa,
    p_rango,
    p_rol,
    COALESCE(p_fecha_ingreso, NOW()),
    p_profile_image,
    COALESCE(p_divisions, ARRAY['Detective Bureau'])
  )
  ON CONFLICT (id) DO UPDATE SET
    rango = EXCLUDED.rango,
    rol = EXCLUDED.rol,
    fecha_ingreso = EXCLUDED.fecha_ingreso,
    profile_image = EXCLUDED.profile_image,
    nombre = EXCLUDED.nombre,
    apellido = EXCLUDED.apellido,
    no_placa = EXCLUDED.no_placa,
    divisions = EXCLUDED.divisions;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, extensions;

-- 4. Update update_personnel_admin to include divisions
CREATE OR REPLACE FUNCTION update_personnel_admin(
  p_user_id UUID,
  p_email TEXT,
  p_password TEXT,
  p_nombre TEXT,
  p_apellido TEXT,
  p_no_placa TEXT,
  p_rango app_rank,
  p_rol app_role,
  p_fecha_ingreso TIMESTAMP WITH TIME ZONE,
  p_fecha_ultimo_ascenso TIMESTAMP WITH TIME ZONE,
  p_profile_image TEXT,
  p_divisions TEXT[] DEFAULT NULL
)
RETURNS VOID AS $$
BEGIN
  UPDATE public.users
  SET
    email = p_email,
    nombre = p_nombre,
    apellido = p_apellido,
    no_placa = p_no_placa,
    rango = p_rango,
    rol = p_rol,
    fecha_ingreso = p_fecha_ingreso,
    profile_image = p_profile_image,
    updated_at = NOW(),
    divisions = CASE WHEN p_divisions IS NOT NULL THEN p_divisions ELSE divisions END
  WHERE id = p_user_id;

  UPDATE auth.users SET email = p_email WHERE id = p_user_id;

  IF p_password IS NOT NULL AND trim(p_password) <> '' THEN
     UPDATE auth.users SET encrypted_password = crypt(p_password, gen_salt('bf')) WHERE id = p_user_id;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, extensions;
