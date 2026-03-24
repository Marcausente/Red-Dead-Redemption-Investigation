
CREATE EXTENSION IF NOT EXISTS pgcrypto;

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
  p_profile_image TEXT DEFAULT NULL
)
RETURNS VOID AS $$
DECLARE
  new_user_id UUID;
BEGIN
  new_user_id := gen_random_uuid();

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

  INSERT INTO public.users (
    id, email, nombre, apellido, no_placa, rango, rol, fecha_ingreso, profile_image
  ) VALUES (
    new_user_id,
    p_email,
    p_nombre,
    p_apellido,
    p_no_placa,
    p_rango,
    p_rol,
    COALESCE(p_fecha_ingreso, NOW()),
    p_profile_image
  )
  ON CONFLICT (id) DO UPDATE SET
    rango = EXCLUDED.rango,
    rol = EXCLUDED.rol,
    fecha_ingreso = EXCLUDED.fecha_ingreso,
    profile_image = EXCLUDED.profile_image,
    nombre = EXCLUDED.nombre,
    apellido = EXCLUDED.apellido,
    no_placa = EXCLUDED.no_placa;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, extensions;
