-- 06_setup_map.sql
-- Drop everything related to mapping to start fresh with BOI
DROP FUNCTION IF EXISTS public.get_map_zones();
DROP FUNCTION IF EXISTS public.create_map_zone(text, text, jsonb, text);
DROP FUNCTION IF EXISTS public.update_map_zone(uuid, text, text, text);
DROP FUNCTION IF EXISTS public.delete_map_zone(uuid);
DROP TABLE IF EXISTS public.map_zones CASCADE;

CREATE TABLE public.map_zones (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    coordinates JSONB NOT NULL,
    color TEXT DEFAULT '#8b5a2b',
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE public.map_zones ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Todos pueden ver las zonas" ON public.map_zones;
CREATE POLICY "Todos pueden ver las zonas"
    ON public.map_zones FOR SELECT TO authenticated USING (true);

-- RPC for fetching
CREATE OR REPLACE FUNCTION get_map_zones()
RETURNS TABLE (
    id UUID,
    name TEXT,
    description TEXT,
    coordinates JSONB,
    color TEXT,
    created_by UUID
) AS $$
BEGIN
    RETURN QUERY SELECT m.id, m.name, m.description, m.coordinates, m.color, m.created_by FROM public.map_zones m;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC for create
CREATE OR REPLACE FUNCTION create_map_zone(
    p_name TEXT,
    p_description TEXT,
    p_coordinates JSONB,
    p_color TEXT
)
RETURNS VOID AS $$
DECLARE
    v_rol public.app_role;
    v_user_id UUID;
BEGIN
    v_user_id := auth.uid();
    SELECT rol INTO v_rol FROM public.users WHERE id = v_user_id;

    IF v_rol IN ('Coordinador', 'Jefatura', 'Agente BOI', 'Administrador') THEN
        INSERT INTO public.map_zones (name, description, coordinates, color, created_by)
        VALUES (p_name, p_description, p_coordinates, p_color, v_user_id);
    ELSE
        RAISE EXCEPTION 'No tienes permiso para marcar zonas corporativas en el mapa.';
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC for update
CREATE OR REPLACE FUNCTION update_map_zone(
    p_id UUID,
    p_name TEXT,
    p_description TEXT,
    p_color TEXT
)
RETURNS VOID AS $$
DECLARE
    v_rol public.app_role;
BEGIN
    SELECT rol INTO v_rol FROM public.users WHERE id = auth.uid();

    IF v_rol IN ('Coordinador', 'Jefatura', 'Agente BOI', 'Administrador') THEN
        UPDATE public.map_zones
        SET name = p_name,
            description = p_description,
            color = p_color,
            updated_at = NOW()
        WHERE id = p_id;
    ELSE
        RAISE EXCEPTION 'No tienes permiso para modificar la cartografía.';
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC for delete
CREATE OR REPLACE FUNCTION delete_map_zone(p_id UUID)
RETURNS VOID AS $$
DECLARE
    v_rol public.app_role;
BEGIN
    SELECT rol INTO v_rol FROM public.users WHERE id = auth.uid();

    IF v_rol IN ('Coordinador', 'Jefatura', 'Agente BOI', 'Administrador') THEN
        DELETE FROM public.map_zones WHERE id = p_id;
    ELSE
        RAISE EXCEPTION 'No tienes autorización para destruir documentos cartográficos.';
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
