-- 07_setup_cases.sql
DROP FUNCTION IF EXISTS public.get_cases(text);
DROP FUNCTION IF EXISTS public.create_new_case(text, text, timestamp with time zone, text, uuid[], text);
DROP TABLE IF EXISTS public.case_assignments CASCADE;
DROP TABLE IF EXISTS public.cases CASCADE;

CREATE TABLE public.cases (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    case_number SERIAL,
    title TEXT NOT NULL,
    location TEXT NOT NULL,
    occurred_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    description TEXT,
    initial_image TEXT,
    status TEXT DEFAULT 'Abierto', -- Abierto, Cerrado, Archivado
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE public.case_assignments (
    case_id UUID REFERENCES public.cases(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    assigned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    PRIMARY KEY (case_id, user_id)
);

ALTER TABLE public.cases ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.case_assignments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Lectura de casos pública para miembros" ON public.cases FOR SELECT TO authenticated USING (true);
CREATE POLICY "Lectura asignaciones pública" ON public.case_assignments FOR SELECT TO authenticated USING (true);

-- RPC for fetching
CREATE OR REPLACE FUNCTION get_cases(p_status_filter text)
RETURNS TABLE (
    id UUID,
    case_number INT,
    title TEXT,
    location TEXT,
    occurred_at TIMESTAMP WITH TIME ZONE,
    status TEXT,
    assigned_avatars TEXT[]
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.id, c.case_number, c.title, c.location, c.occurred_at, c.status,
        ARRAY(
            SELECT u.profile_image 
            FROM public.case_assignments ca
            JOIN public.users u ON u.id = ca.user_id
            WHERE ca.case_id = c.id
        ) as assigned_avatars
    FROM public.cases c
    WHERE (p_status_filter = 'Todos' OR c.status = p_status_filter)
    ORDER BY c.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- CREATE CASE
CREATE OR REPLACE FUNCTION create_new_case(
    p_title TEXT,
    p_location TEXT,
    p_occurred_at TIMESTAMP WITH TIME ZONE,
    p_description TEXT,
    p_assigned_ids UUID[],
    p_image TEXT
)
RETURNS UUID AS $$
DECLARE
    new_case_id UUID;
    v_user_id UUID;
BEGIN
    v_user_id := auth.uid();

    INSERT INTO public.cases (title, location, occurred_at, description, initial_image, created_by)
    VALUES (p_title, p_location, p_occurred_at, p_description, p_image, v_user_id)
    RETURNING id INTO new_case_id;

    IF array_length(p_assigned_ids, 1) > 0 THEN
        INSERT INTO public.case_assignments (case_id, user_id)
        SELECT new_case_id, unnest(p_assigned_ids);
    END IF;

    RETURN new_case_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
