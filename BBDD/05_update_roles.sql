-- 05. Update Roles
-- Agregamos el rol "Jefatura" al ENUM existente si aún no existe.

ALTER TYPE app_role ADD VALUE IF NOT EXISTS 'Jefatura';
