-- 10_setup_incidents.sql

DROP FUNCTION IF EXISTS public.get_incidents_board_data();
DROP FUNCTION IF EXISTS public.create_incident(TEXT, UUID, TIMESTAMP WITH TIME ZONE, TEXT, TEXT, TEXT[]);
DROP FUNCTION IF EXISTS public.create_field_operation(TEXT, UUID, TIMESTAMP WITH TIME ZONE, TEXT, TEXT, UUID[], TEXT[]);
DROP FUNCTION IF EXISTS public.delete_incident(UUID);
DROP FUNCTION IF EXISTS public.delete_field_operation(UUID);

DROP TABLE IF EXISTS public.field_op_images CASCADE;
DROP TABLE IF EXISTS public.field_op_agents CASCADE;
DROP TABLE IF EXISTS public.field_operations CASCADE;
DROP TABLE IF EXISTS public.incident_images CASCADE;
DROP TABLE IF EXISTS public.incidents CASCADE;

CREATE TABLE public.incidents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    incident_number TEXT,
    title TEXT NOT NULL,
    group_id UUID REFERENCES public.criminal_groups(id) ON DELETE SET NULL,
    occurred_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    location TEXT,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID REFERENCES public.users(id) ON DELETE SET NULL
);

CREATE TABLE public.incident_images (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    incident_id UUID REFERENCES public.incidents(id) ON DELETE CASCADE,
    photo TEXT
);

CREATE TABLE public.field_operations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    op_number TEXT,
    title TEXT NOT NULL,
    group_id UUID REFERENCES public.criminal_groups(id) ON DELETE SET NULL,
    occurred_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    reason TEXT,
    information_obtained TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID REFERENCES public.users(id) ON DELETE SET NULL
);

CREATE TABLE public.field_op_agents (
    op_id UUID REFERENCES public.field_operations(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    PRIMARY KEY (op_id, user_id)
);

CREATE TABLE public.field_op_images (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    op_id UUID REFERENCES public.field_operations(id) ON DELETE CASCADE,
    photo TEXT
);

ALTER TABLE public.incidents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.incident_images ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.field_operations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.field_op_agents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.field_op_images ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Lectura general incidentes" ON public.incidents FOR SELECT TO authenticated USING (true);
CREATE POLICY "Lectura img incidentes" ON public.incident_images FOR SELECT TO authenticated USING (true);
CREATE POLICY "Lectura general fieldops" ON public.field_operations FOR SELECT TO authenticated USING (true);
CREATE POLICY "Lectura agents fieldops" ON public.field_op_agents FOR SELECT TO authenticated USING (true);
CREATE POLICY "Lectura img fieldops" ON public.field_op_images FOR SELECT TO authenticated USING (true);

-- Endpoints for Incidents Board
CREATE OR REPLACE FUNCTION get_incidents_board_data()
RETURNS JSON AS $$
DECLARE
    result JSON;
BEGIN
    result := json_build_object(
        'unlinked_incidents', (SELECT COALESCE(json_agg(
            json_build_object(
                'id', i.id, 'number', i.incident_number, 'title', i.title, 
                'occurred_at', i.occurred_at, 'location', i.location, 'description', i.description,
                'images', (SELECT COALESCE(array_agg(img.photo), ARRAY[]::TEXT[]) FROM public.incident_images img WHERE img.incident_id = i.id)
            ) ORDER BY i.created_at DESC
        ), '[]') FROM public.incidents i WHERE i.group_id IS NULL),

        'linked_incidents', (SELECT COALESCE(json_agg(
            json_build_object(
                'id', i.id, 'number', i.incident_number, 'title', i.title,
                'group_id', i.group_id, 'group_name', (SELECT name FROM public.criminal_groups WHERE id = i.group_id), 'group_color', (SELECT color FROM public.criminal_groups WHERE id = i.group_id),
                'occurred_at', i.occurred_at, 'location', i.location, 'description', i.description,
                'images', (SELECT COALESCE(array_agg(img.photo), ARRAY[]::TEXT[]) FROM public.incident_images img WHERE img.incident_id = i.id)
            ) ORDER BY i.created_at DESC
        ), '[]') FROM public.incidents i WHERE i.group_id IS NOT NULL),

        'field_ops', (SELECT COALESCE(json_agg(
            json_build_object(
                'id', o.id, 'number', o.op_number, 'title', o.title,
                'group_id', o.group_id, 'group_name', (SELECT name FROM public.criminal_groups WHERE id = o.group_id), 'group_color', (SELECT color FROM public.criminal_groups WHERE id = o.group_id),
                'occurred_at', o.occurred_at, 'reason', o.reason, 'info', o.information_obtained,
                'agents', (SELECT COALESCE(json_agg(json_build_object('id', u.id, 'name', u.nombre, 'surname', u.apellido, 'photo', u.profile_image)), '[]') FROM public.field_op_agents foa JOIN public.users u ON u.id = foa.user_id WHERE foa.op_id = o.id),
                'images', (SELECT COALESCE(array_agg(img.photo), ARRAY[]::TEXT[]) FROM public.field_op_images img WHERE img.op_id = o.id)
            ) ORDER BY o.created_at DESC
        ), '[]') FROM public.field_operations o)
    );
    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- CREATE
CREATE OR REPLACE FUNCTION create_incident(
    p_number TEXT, p_title TEXT, p_group_id UUID, p_occurred_at TIMESTAMP WITH TIME ZONE, 
    p_location TEXT, p_description TEXT, p_images TEXT[]
) RETURNS VOID AS $$
DECLARE
    new_id UUID;
BEGIN
    INSERT INTO public.incidents (incident_number, title, group_id, occurred_at, location, description, created_by)
    VALUES (p_number, p_title, p_group_id, p_occurred_at, p_location, p_description, auth.uid()) RETURNING id INTO new_id;

    IF array_length(p_images, 1) > 0 THEN
        INSERT INTO public.incident_images (incident_id, photo) SELECT new_id, unnest(p_images);
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION create_field_operation(
    p_number TEXT, p_title TEXT, p_group_id UUID, p_occurred_at TIMESTAMP WITH TIME ZONE,
    p_reason TEXT, p_info TEXT, p_agents UUID[], p_images TEXT[]
) RETURNS VOID AS $$
DECLARE
    new_id UUID;
BEGIN
    INSERT INTO public.field_operations (op_number, title, group_id, occurred_at, reason, information_obtained, created_by)
    VALUES (p_number, p_title, p_group_id, p_occurred_at, p_reason, p_info, auth.uid()) RETURNING id INTO new_id;

    IF array_length(p_agents, 1) > 0 THEN
        INSERT INTO public.field_op_agents (op_id, user_id) SELECT new_id, unnest(p_agents);
    END IF;

    IF array_length(p_images, 1) > 0 THEN
        INSERT INTO public.field_op_images (op_id, photo) SELECT new_id, unnest(p_images);
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION delete_incident(p_id UUID) RETURNS VOID AS $$
BEGIN DELETE FROM public.incidents WHERE id = p_id; END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION delete_field_operation(p_id UUID) RETURNS VOID AS $$
BEGIN DELETE FROM public.field_operations WHERE id = p_id; END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION update_incident(
    p_id UUID, p_number TEXT, p_title TEXT, p_group_id UUID, p_occurred_at TIMESTAMP WITH TIME ZONE, 
    p_location TEXT, p_description TEXT, p_images TEXT[]
) RETURNS VOID AS $$
BEGIN
    UPDATE public.incidents SET incident_number = p_number, title = p_title, group_id = p_group_id, occurred_at = p_occurred_at, location = p_location, description = p_description WHERE id = p_id;
    DELETE FROM public.incident_images WHERE incident_id = p_id;
    IF array_length(p_images, 1) > 0 THEN INSERT INTO public.incident_images (incident_id, photo) SELECT p_id, unnest(p_images); END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION update_field_operation(
    p_id UUID, p_number TEXT, p_title TEXT, p_group_id UUID, p_occurred_at TIMESTAMP WITH TIME ZONE,
    p_reason TEXT, p_info TEXT, p_agents UUID[], p_images TEXT[]
) RETURNS VOID AS $$
BEGIN
    UPDATE public.field_operations SET op_number = p_number, title = p_title, group_id = p_group_id, occurred_at = p_occurred_at, reason = p_reason, information_obtained = p_info WHERE id = p_id;
    DELETE FROM public.field_op_agents WHERE op_id = p_id;
    IF array_length(p_agents, 1) > 0 THEN INSERT INTO public.field_op_agents (op_id, user_id) SELECT p_id, unnest(p_agents); END IF;
    DELETE FROM public.field_op_images WHERE op_id = p_id;
    IF array_length(p_images, 1) > 0 THEN INSERT INTO public.field_op_images (op_id, photo) SELECT p_id, unnest(p_images); END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- REDEFINIR GET GROUPS DATA PARA INCLUIR CONTEOS
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
            'is_archived', g.is_archived,
            'incidents', (SELECT COALESCE(json_agg(json_build_object('id', i.id, 'number', i.incident_number, 'title', i.title, 'date', i.occurred_at, 'location', i.location)), '[]') FROM public.incidents i WHERE i.group_id = g.id),
            'field_ops', (SELECT COALESCE(json_agg(json_build_object('id', fo.id, 'number', fo.op_number, 'title', fo.title, 'date', fo.occurred_at, 'reason', fo.reason)), '[]') FROM public.field_operations fo WHERE fo.group_id = g.id),
            'characteristics', (SELECT COALESCE(json_agg(row_to_json(c)), '[]') FROM public.group_characteristics c WHERE c.group_id = g.id),
            'camps', (SELECT COALESCE(json_agg(row_to_json(ca)), '[]') FROM public.group_camps ca WHERE ca.group_id = g.id),
            'cases', (SELECT COALESCE(json_agg(json_build_object('id', gc.id, 'case_id', cc.id, 'case_number', cc.case_number, 'title', cc.title, 'status', cc.status, 'notes', gc.notes)), '[]') FROM public.group_cases gc JOIN public.cases cc ON cc.id = gc.case_id WHERE gc.group_id = g.id),
            'members', (SELECT COALESCE(json_agg(row_to_json(m)), '[]') FROM public.group_members m WHERE m.group_id = g.id)
        )
    ), '[]') INTO result
    FROM public.criminal_groups g;

    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
