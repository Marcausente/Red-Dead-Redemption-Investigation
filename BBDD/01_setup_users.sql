-- RESET PREVIOUS (if any)
-- DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
-- DROP FUNCTION IF EXISTS public.handle_new_user();
-- DROP FUNCTION IF EXISTS public.create_new_personnel(...);
-- DROP FUNCTION IF EXISTS public.update_personnel_admin(...);
-- DROP FUNCTION IF EXISTS public.delete_personnel(uuid);
-- DROP TABLE IF EXISTS public.users CASCADE;
-- DROP TYPE IF EXISTS app_rank;
-- DROP TYPE IF EXISTS app_role;

-- 0. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 1. ENUMS
DO $$ BEGIN
    CREATE TYPE app_rank AS ENUM (
        'Recluta', 'Aguacil de Segunda', 'Aguacil de Primera', 
        'Oficial', 'Oficial Supervisor', 'Ayudante del Sheriff', 
        'Sheriff de Pueblo', 'Sheriff de Condado', 'Marshal'
    );
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE app_role AS ENUM (
        'Externo', 'Ayudante BOI', 'Agente BOI', 'Coordinador', 'Administrador'
    );
EXCEPTION WHEN duplicate_object THEN null; END $$;

-- 2. USERS TABLE
CREATE TABLE IF NOT EXISTS public.users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  nombre TEXT,
  apellido TEXT,
  rango app_rank DEFAULT 'Recluta',
  rol app_role DEFAULT 'Externo',
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

-- 3. TRIGGER FOR NEW USER CREATION (Sync Auth -> Public)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  -- AUTOMATICALLY CONFIRM EMAIL
  UPDATE auth.users SET email_confirmed_at = NOW() WHERE id = new.id;

  INSERT INTO public.users (id, email, nombre, apellido, rango, rol)
  VALUES (
    new.id,
    new.email,
    COALESCE(new.raw_user_meta_data->>'nombre', 'Desconocido'),
    COALESCE(new.raw_user_meta_data->>'apellido', 'Usuario'),
    'Recluta',
    'Externo'
  );
  
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- *** CRITICAL FIX: CONFIRM ALL EXISTING USERS ***
UPDATE auth.users SET email_confirmed_at = NOW() WHERE email_confirmed_at IS NULL;

-- 4. RPCs

-- create_new_personnel (Admin Helper)
CREATE OR REPLACE FUNCTION create_new_personnel(
  p_email TEXT,
  p_password TEXT,
  p_nombre TEXT,
  p_apellido TEXT,
  p_rango app_rank,
  p_rol app_role,
  p_fecha_ingreso TIMESTAMP WITH TIME ZONE DEFAULT NULL,
  p_profile_image TEXT DEFAULT NULL
)
RETURNS VOID AS $$
DECLARE
  new_user_id UUID;
BEGIN
  new_user_id := gen_random_uuid();

  -- 1. Insert into auth.users 
  INSERT INTO auth.users (
    instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    created_at, updated_at, raw_app_meta_data, raw_user_meta_data,
    recovery_token, confirmation_token, email_change_token_new, email_change
  ) VALUES (
    '00000000-0000-0000-0000-000000000000', new_user_id, 'authenticated', 'authenticated', p_email,
    crypt(p_password, gen_salt('bf')), NOW(), NOW(), NOW(),
    '{"provider": "email", "providers": ["email"]}',
    jsonb_build_object('nombre', p_nombre, 'apellido', p_apellido),
    '', '', '', ''
  );

  -- 2. Insert into auth.identities
  INSERT INTO auth.identities (
    id, user_id, identity_data, provider, provider_id, created_at, updated_at
  ) VALUES (
    gen_random_uuid(), new_user_id,
    format('{"sub": "%s", "email": "%s"}', new_user_id::text, p_email)::jsonb,
    'email', new_user_id::text, NOW(), NOW()
  );

  -- 3. Handle Public User Data (UPSERT)
  INSERT INTO public.users (
    id, email, nombre, apellido, rango, rol, fecha_ingreso, profile_image
  ) VALUES (
    new_user_id, p_email, p_nombre, p_apellido, p_rango, p_rol,
    COALESCE(p_fecha_ingreso, NOW()), p_profile_image
  )
  ON CONFLICT (id) DO UPDATE SET
    rango = EXCLUDED.rango,
    rol = EXCLUDED.rol,
    fecha_ingreso = EXCLUDED.fecha_ingreso,
    profile_image = EXCLUDED.profile_image,
    nombre = EXCLUDED.nombre,
    apellido = EXCLUDED.apellido;

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
  p_rango app_rank,
  p_rol app_role,
  p_fecha_ingreso TIMESTAMP WITH TIME ZONE,
  p_profile_image TEXT
)
RETURNS VOID AS $$
BEGIN
  UPDATE public.users
  SET
    email = p_email,
    nombre = p_nombre,
    apellido = p_apellido,
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
SET search_path = public, extensions;

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
