-- 09_setup_groups.sql

DROP FUNCTION IF EXISTS public.get_groups_data();
DROP FUNCTION IF EXISTS public.create_criminal_group(TEXT, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.add_group_characteristic(UUID, TEXT);
DROP FUNCTION IF EXISTS public.add_group_camp(UUID, TEXT, TEXT, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.add_group_member(UUID, TEXT, TEXT, TEXT, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.delete_criminal_group_fully(UUID);

DROP TABLE IF EXISTS public.group_members CASCADE;
DROP TABLE IF EXISTS public.group_camps CASCADE;
DROP TABLE IF EXISTS public.group_characteristics CASCADE;
DROP TABLE IF EXISTS public.criminal_groups CASCADE;

CREATE TABLE public.criminal_groups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    color TEXT DEFAULT '#8b0000',
    influence_zone_image TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE public.group_characteristics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID REFERENCES public.criminal_groups(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE public.group_camps (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID REFERENCES public.criminal_groups(id) ON DELETE CASCADE,
    map_photo TEXT,
    camp_photo TEXT,
    status TEXT DEFAULT 'Activo', -- 'Activo' or 'Abandonado'
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE public.group_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID REFERENCES public.criminal_groups(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    alias TEXT,
    role TEXT DEFAULT 'Sospechoso', -- 'Sospechoso', 'Miembro', 'Lider'
    notes TEXT,
    photo TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE public.criminal_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.group_characteristics ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.group_camps ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.group_members ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Lectura grupos_criminales publica" ON public.criminal_groups FOR SELECT TO authenticated USING (true);
CREATE POLICY "Lectura caracteristicas_grupos publica" ON public.group_characteristics FOR SELECT TO authenticated USING (true);
CREATE POLICY "Lectura group_camps publica" ON public.group_camps FOR SELECT TO authenticated USING (true);
CREATE POLICY "Lectura group_members publica" ON public.group_members FOR SELECT TO authenticated USING (true);

-- API DATA
CREATE OR REPLACE FUNCTION get_groups_data()
RETURNS JSON AS $$
DECLARE
    result JSON;
BEGIN
    SELECT COALESCE(json_agg(
        json_build_object(
            'id', g.id,
            'name', g.name,
            'color', g.color,
            'influence_zone_image', g.influence_zone_image,
            'characteristics', (SELECT COALESCE(json_agg(row_to_json(c)), '[]') FROM public.group_characteristics c WHERE c.group_id = g.id),
            'camps', (SELECT COALESCE(json_agg(row_to_json(ca)), '[]') FROM public.group_camps ca WHERE ca.group_id = g.id),
            'members', (SELECT COALESCE(json_agg(row_to_json(m)), '[]') FROM public.group_members m WHERE m.group_id = g.id)
        )
    ), '[]') INTO result
    FROM public.criminal_groups g;

    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- CRUD
CREATE OR REPLACE FUNCTION create_criminal_group(p_name TEXT, p_color TEXT, p_image TEXT) RETURNS VOID AS $$
BEGIN INSERT INTO public.criminal_groups (name, color, influence_zone_image) VALUES (p_name, p_color, p_image); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION add_group_characteristic(p_group_id UUID, p_content TEXT) RETURNS VOID AS $$
BEGIN INSERT INTO public.group_characteristics (group_id, content) VALUES (p_group_id, p_content); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION add_group_camp(p_group_id UUID, p_map_photo TEXT, p_camp_photo TEXT, p_status TEXT, p_notes TEXT) RETURNS VOID AS $$
BEGIN INSERT INTO public.group_camps (group_id, map_photo, camp_photo, status, notes) VALUES (p_group_id, p_map_photo, p_camp_photo, p_status, p_notes); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION add_group_member(p_group_id UUID, p_name TEXT, p_alias TEXT, p_role TEXT, p_notes TEXT, p_photo TEXT) RETURNS VOID AS $$
BEGIN INSERT INTO public.group_members (group_id, name, alias, role, notes, photo) VALUES (p_group_id, p_name, p_alias, p_role, p_notes, p_photo); END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION delete_criminal_group_fully(p_group_id UUID) RETURNS VOID AS $$
BEGIN DELETE FROM public.criminal_groups WHERE id = p_group_id; END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
