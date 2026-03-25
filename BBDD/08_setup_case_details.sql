-- 08_setup_case_details.sql

DROP FUNCTION IF EXISTS public.add_case_update(uuid, text, text[]);
DROP FUNCTION IF EXISTS public.delete_case_update(uuid);
DROP FUNCTION IF EXISTS public.update_case_update_content(uuid, text);
DROP FUNCTION IF EXISTS public.delete_case_fully(uuid);
DROP FUNCTION IF EXISTS public.update_case_details(uuid, text, text, timestamp with time zone, text);
DROP FUNCTION IF EXISTS public.get_case_details(uuid);
DROP FUNCTION IF EXISTS public.update_case_assignments(uuid, uuid[]);
DROP FUNCTION IF EXISTS public.set_case_status(uuid, text);

DROP TABLE IF EXISTS public.case_updates CASCADE;

CREATE TABLE public.case_updates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    case_id UUID REFERENCES public.cases(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    images TEXT[] DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE public.case_updates ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Lectura updates compartidas" ON public.case_updates FOR SELECT TO authenticated USING (true);

-- LECTURA DE DETALLE COMPLETO
CREATE OR REPLACE FUNCTION get_case_details(p_case_id UUID)
RETURNS JSON AS $$
DECLARE
    v_info JSON;
    v_assignments JSON;
    v_updates JSON;
BEGIN
    SELECT row_to_json(c) INTO v_info
    FROM (
        SELECT id, case_number, title, location, occurred_at, description, initial_image as initial_image_url, status, created_by, created_at
        FROM public.cases WHERE id = p_case_id
    ) c;

    IF v_info IS NULL THEN RETURN NULL; END IF;

    SELECT COALESCE(json_agg(row_to_json(a)), '[]'::json) INTO v_assignments
    FROM (
        SELECT ca.user_id, u.rango as rank, u.nombre || ' ' || u.apellido as full_name, u.profile_image as avatar
        FROM public.case_assignments ca
        JOIN public.users u ON ca.user_id = u.id
        WHERE ca.case_id = p_case_id
    ) a;

    SELECT COALESCE(json_agg(row_to_json(u)), '[]'::json) INTO v_updates
    FROM (
        SELECT cu.id, cu.user_id, us.rango as author_rank, us.nombre || ' ' || us.apellido as author_name, us.profile_image as author_avatar, cu.content, cu.images, cu.created_at
        FROM public.case_updates cu
        JOIN public.users us ON cu.user_id = us.id
        WHERE cu.case_id = p_case_id
        ORDER BY cu.created_at DESC
    ) u;

    RETURN json_build_object(
        'info', v_info,
        'assignments', v_assignments,
        'updates', v_updates
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- CREAR RESPUESTA (FORO)
CREATE OR REPLACE FUNCTION add_case_update(p_case_id UUID, p_content TEXT, p_images TEXT[])
RETURNS VOID AS $$
BEGIN
    INSERT INTO public.case_updates (case_id, user_id, content, images)
    VALUES (p_case_id, auth.uid(), p_content, p_images);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION delete_case_update(p_update_id UUID)
RETURNS VOID AS $$
BEGIN
    DELETE FROM public.case_updates WHERE id = p_update_id AND user_id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION update_case_update_content(p_update_id UUID, p_content TEXT)
RETURNS VOID AS $$
BEGIN
    UPDATE public.case_updates SET content = p_content, updated_at = NOW() WHERE id = p_update_id AND user_id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- GESTION DEL CASO POR ALTOS CARGOS
CREATE OR REPLACE FUNCTION set_case_status(p_case_id UUID, p_status TEXT)
RETURNS VOID AS $$
DECLARE v_rol TEXT;
BEGIN
    SELECT rol INTO v_rol FROM public.users WHERE id = auth.uid();
    IF v_rol IN ('Administrador', 'Coordinador', 'Jefatura') THEN
        UPDATE public.cases SET status = p_status WHERE id = p_case_id;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION delete_case_fully(p_case_id UUID)
RETURNS TEXT AS $$
DECLARE v_rol TEXT;
BEGIN
    SELECT rol INTO v_rol FROM public.users WHERE id = auth.uid();
    IF v_rol IN ('Administrador', 'Coordinador', 'Jefatura') THEN
        DELETE FROM public.cases WHERE id = p_case_id;
        RETURN 'OK';
    END IF;
    RAISE EXCEPTION 'Solo Coordinadores y Administración pueden quemar archivos.';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION update_case_assignments(p_case_id UUID, p_assigned_ids UUID[])
RETURNS VOID AS $$
DECLARE v_rol TEXT;
BEGIN
    SELECT rol INTO v_rol FROM public.users WHERE id = auth.uid();
    IF v_rol IN ('Administrador', 'Coordinador', 'Jefatura') THEN
        DELETE FROM public.case_assignments WHERE case_id = p_case_id;
        IF array_length(p_assigned_ids, 1) > 0 THEN
            INSERT INTO public.case_assignments (case_id, user_id)
            SELECT p_case_id, unnest(p_assigned_ids);
        END IF;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION update_case_details(
    p_case_id UUID,
    p_title TEXT,
    p_location TEXT,
    p_occurred_at TIMESTAMP WITH TIME ZONE,
    p_description TEXT
)
RETURNS VOID AS $$
DECLARE v_rol TEXT;
BEGIN
    SELECT rol INTO v_rol FROM public.users WHERE id = auth.uid();
    IF v_rol IN ('Administrador', 'Coordinador', 'Jefatura') THEN
        UPDATE public.cases 
        SET title = p_title, location = p_location, occurred_at = p_occurred_at, description = p_description
        WHERE id = p_case_id;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
