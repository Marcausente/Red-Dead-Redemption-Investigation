
-- RESET
-- DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
-- DROP FUNCTION IF EXISTS public.handle_new_user();
-- DROP FUNCTION IF EXISTS public.get_evaluations(uuid);
-- DROP FUNCTION IF EXISTS public.add_evaluation(uuid, text);
-- DROP FUNCTION IF EXISTS public.create_new_personnel(text, text, text, text, text, app_rank, app_role, timestamp with time zone, timestamp with time zone, text);
-- DROP FUNCTION IF EXISTS public.update_personnel_admin(uuid, text, text, text, text, text, app_rank, app_role, timestamp with time zone, timestamp with time zone, text);
-- DROP FUNCTION IF EXISTS public.delete_personnel(uuid);
-- DROP TABLE IF EXISTS public.evaluations;
-- DROP TABLE IF EXISTS public.users;
-- DROP TYPE IF EXISTS app_rank;
-- DROP TYPE IF EXISTS app_role;

-- 0. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 1. ENUMS
DO $$ BEGIN
    CREATE TYPE app_rank AS ENUM (
        'Oficial II', 'Oficial III', 'Oficial III+',
        'Detective I', 'Detective II', 'Detective III',
        'Teniente', 'Capitan'  -- Matches frontend "Capitan"
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE app_role AS ENUM (
        'Externo', -- Matches frontend
        'Ayudante', 'Detective', 'Coordinador',
        'Comisionado', 'Administrador'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- 2. USERS TABLE
CREATE TABLE IF NOT EXISTS public.users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  nombre TEXT,
  apellido TEXT,
  no_placa TEXT,
  rango app_rank DEFAULT 'Oficial II',
  rol app_role DEFAULT 'Ayudante',
  fecha_ingreso TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  profile_image TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- Policies for Users
DROP POLICY IF EXISTS "Allow read access for all authenticated users" ON public.users;
CREATE POLICY "Allow read access for all authenticated users"
  ON public.users FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Allow update for own profile" ON public.users;
CREATE POLICY "Allow update for own profile"
  ON public.users FOR UPDATE TO authenticated USING (auth.uid() = id);

-- 3. EVALUATIONS TABLE
CREATE TABLE IF NOT EXISTS public.evaluations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  target_user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  author_user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
  content TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE public.evaluations ENABLE ROW LEVEL SECURITY;

-- Policies for Evaluations
DROP POLICY IF EXISTS "Allow read access for evaluations" ON public.evaluations;
CREATE POLICY "Allow read access for evaluations"
  ON public.evaluations FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Allow create evaluation" ON public.evaluations;
CREATE POLICY "Allow create evaluation"
  ON public.evaluations FOR INSERT TO authenticated WITH CHECK (auth.uid() = author_user_id);

-- 4. TRIGGER FOR NEW USER CREATION (Sync Auth -> Public)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  -- AUTOMATICALLY CONFIRM EMAIL (Bypass Email Confirmation)
  UPDATE auth.users SET email_confirmed_at = NOW() WHERE id = new.id;

  IF new.email = 'georgevance@lspd.com' THEN
      INSERT INTO public.users (id, email, nombre, apellido, no_placa, rango, rol, fecha_ingreso)
      VALUES (
        new.id,
        new.email,
        COALESCE(new.raw_user_meta_data->>'first_name', 'George'),
        COALESCE(new.raw_user_meta_data->>'last_name', 'Vance'),
        '763',
        'Detective II',
        'Administrador',
        '2025-11-08 00:00:00+00'
      );
  ELSE
      INSERT INTO public.users (id, email, nombre, apellido, no_placa, rango, rol)
      VALUES (
        new.id,
        new.email,
        COALESCE(new.raw_user_meta_data->>'nombre', 'Unknown'),
        COALESCE(new.raw_user_meta_data->>'apellido', 'User'),
        COALESCE(new.raw_user_meta_data->>'no_placa', '000'),
        'Oficial II',
        'Ayudante'
      );
  END IF;
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- *** CRITICAL FIX: CONFIRM ALL EXISTING USERS ***
UPDATE auth.users SET email_confirmed_at = NOW() WHERE email_confirmed_at IS NULL;

-- 5. RPCs

-- get_evaluations
CREATE OR REPLACE FUNCTION get_evaluations(p_target_user_id UUID)
RETURNS TABLE (
  id UUID,
  content TEXT,
  created_at TIMESTAMP WITH TIME ZONE,
  author_name TEXT,
  author_rank app_rank
) AS $$
BEGIN
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

-- add_evaluation
CREATE OR REPLACE FUNCTION add_evaluation(p_target_user_id UUID, p_content TEXT)
RETURNS VOID AS $$
BEGIN
  INSERT INTO public.evaluations (target_user_id, author_user_id, content)
  VALUES (p_target_user_id, auth.uid(), p_content);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- create_new_personnel (Admin Helper)
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

  -- 1. Insert into auth.users (Mimicking Sabbathweb structure)
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
    NOW(), -- Auto-confirm
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

  -- 2. Insert into auth.identities (CRITICAL FIX from Sabbathweb)
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

  -- 3. Handle Public User Data
  -- UPSERT to handle potential trigger firing
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

-- update_personnel_admin
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
  p_profile_image TEXT
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
    updated_at = NOW()
  WHERE id = p_user_id;

  UPDATE auth.users SET email = p_email WHERE id = p_user_id;

  IF p_password IS NOT NULL AND trim(p_password) <> '' THEN
     UPDATE auth.users SET encrypted_password = crypt(p_password, gen_salt('bf')) WHERE id = p_user_id;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, extensions; -- FIX: Ensure extensions like pgcrypto are found

-- Permissions
GRANT EXECUTE ON FUNCTION public.create_new_personnel TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_personnel_admin TO authenticated;

-- delete_personnel
CREATE OR REPLACE FUNCTION delete_personnel(target_user_id UUID)
RETURNS VOID AS $$
BEGIN
  DELETE FROM auth.users WHERE id = target_user_id;
  -- Cascade deletes public.users
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
