-- Ejecuta esta consulta en el SQL Editor de Supabase para crear el usuario directamente

SELECT public.create_new_personnel(
  'rvance@uss.gov',         -- p_email
  'abc123',                 -- p_password
  'Robert',                 -- p_nombre
  'Vance',                  -- p_apellido
  'Oficial Supervisor',     -- p_rango
  'Administrador',          -- p_rol
  '1880-03-25 00:00:00+00', -- p_fecha_ingreso
  NULL                      -- p_profile_image
);
