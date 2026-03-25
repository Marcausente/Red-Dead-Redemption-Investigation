-- ============================================================
-- 11_setup_wanted.sql  — Módulo de Carteles de Se Busca
-- ============================================================

-- Drop if exists for re-running
DROP FUNCTION IF EXISTS get_wanted_posters();
DROP FUNCTION IF EXISTS create_wanted_poster(TEXT,TEXT,TEXT,TEXT,NUMERIC,TEXT,BOOLEAN,TIMESTAMP WITH TIME ZONE,TEXT);
DROP FUNCTION IF EXISTS update_wanted_poster(UUID,TEXT,TEXT,TEXT,TEXT,NUMERIC,TEXT,BOOLEAN,TIMESTAMP WITH TIME ZONE,TEXT);
DROP FUNCTION IF EXISTS archive_wanted_poster(UUID);
DROP FUNCTION IF EXISTS delete_wanted_poster(UUID);

-- TABLE
CREATE TABLE IF NOT EXISTS public.wanted_posters (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    fugitive_name TEXT NOT NULL,
    fugitive_surname TEXT,
    fugitive_alias TEXT,
    town TEXT, -- Ciudad donde se le busca
    reward_amount NUMERIC(10,2) DEFAULT 0,
    wanted_type TEXT DEFAULT 'VIVO O MUERTO' CHECK (wanted_type IN ('VIVO', 'VIVO O MUERTO')),
    is_dangerous BOOLEAN DEFAULT false,
    published_at TIMESTAMP WITH TIME ZONE DEFAULT '1880-01-01T12:00:00Z',
    photo TEXT,
    is_archived BOOLEAN DEFAULT false,
    created_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Asegurar que la columna 'town' existe si la tabla ya fue creada previamente
DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='wanted_posters' AND column_name='town') THEN
        ALTER TABLE public.wanted_posters ADD COLUMN town TEXT;
    END IF;
END $$;

-- RLS
ALTER TABLE public.wanted_posters ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can read wanted_posters" ON public.wanted_posters;
DROP POLICY IF EXISTS "Authenticated users can insert wanted_posters" ON public.wanted_posters;
DROP POLICY IF EXISTS "Authenticated users can update wanted_posters" ON public.wanted_posters;
DROP POLICY IF EXISTS "Authenticated users can delete wanted_posters" ON public.wanted_posters;

CREATE POLICY "Authenticated users can read wanted_posters" ON public.wanted_posters FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated users can insert wanted_posters" ON public.wanted_posters FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Authenticated users can update wanted_posters" ON public.wanted_posters FOR UPDATE TO authenticated USING (true);
CREATE POLICY "Authenticated users can delete wanted_posters" ON public.wanted_posters FOR DELETE TO authenticated USING (true);

-- GET ALL
CREATE OR REPLACE FUNCTION get_wanted_posters()
RETURNS JSONB AS $$
DECLARE
    active_posters JSONB;
    archived_posters JSONB;
BEGIN
    SELECT COALESCE(json_agg(
        json_build_object(
            'id', wp.id,
            'fugitive_name', wp.fugitive_name,
            'fugitive_surname', wp.fugitive_surname,
            'fugitive_alias', wp.fugitive_alias,
            'town', wp.town,
            'reward_amount', wp.reward_amount,
            'wanted_type', wp.wanted_type,
            'is_dangerous', wp.is_dangerous,
            'published_at', wp.published_at,
            'photo', wp.photo,
            'is_archived', wp.is_archived,
            'created_at', wp.created_at
        ) ORDER BY wp.created_at DESC
    ), '[]') INTO active_posters
    FROM public.wanted_posters wp WHERE wp.is_archived = false;

    SELECT COALESCE(json_agg(
        json_build_object(
            'id', wp.id,
            'fugitive_name', wp.fugitive_name,
            'fugitive_surname', wp.fugitive_surname,
            'fugitive_alias', wp.fugitive_alias,
            'town', wp.town,
            'reward_amount', wp.reward_amount,
            'wanted_type', wp.wanted_type,
            'is_dangerous', wp.is_dangerous,
            'published_at', wp.published_at,
            'photo', wp.photo,
            'is_archived', wp.is_archived,
            'created_at', wp.created_at
        ) ORDER BY wp.created_at DESC
    ), '[]') INTO archived_posters
    FROM public.wanted_posters wp WHERE wp.is_archived = true;

    RETURN jsonb_build_object('active', active_posters, 'archived', archived_posters);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- CREATE
CREATE OR REPLACE FUNCTION create_wanted_poster(
    p_name TEXT, p_surname TEXT, p_alias TEXT, p_town TEXT, p_reward TEXT,
    p_wanted_type TEXT, p_is_dangerous BOOLEAN, p_published_at TIMESTAMP WITH TIME ZONE, p_photo TEXT
) RETURNS VOID AS $$
BEGIN
    INSERT INTO public.wanted_posters (fugitive_name, fugitive_surname, fugitive_alias, town, reward_amount, wanted_type, is_dangerous, published_at, photo, created_by)
    VALUES (p_name, p_surname, p_alias, p_town, p_reward::NUMERIC, p_wanted_type, p_is_dangerous, p_published_at, p_photo, auth.uid());
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- UPDATE
CREATE OR REPLACE FUNCTION update_wanted_poster(
    p_id UUID, p_name TEXT, p_surname TEXT, p_alias TEXT, p_town TEXT, p_reward TEXT,
    p_wanted_type TEXT, p_is_dangerous BOOLEAN, p_published_at TIMESTAMP WITH TIME ZONE, p_photo TEXT
) RETURNS VOID AS $$
BEGIN
    UPDATE public.wanted_posters SET
        fugitive_name = p_name, fugitive_surname = p_surname, fugitive_alias = p_alias,
        town = p_town, reward_amount = p_reward::NUMERIC, wanted_type = p_wanted_type,
        is_dangerous = p_is_dangerous, published_at = p_published_at, photo = p_photo
    WHERE id = p_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ARCHIVE TOGGLE
CREATE OR REPLACE FUNCTION archive_wanted_poster(p_id UUID) RETURNS VOID AS $$
BEGIN
    UPDATE public.wanted_posters SET is_archived = NOT is_archived WHERE id = p_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- DELETE
CREATE OR REPLACE FUNCTION delete_wanted_poster(p_id UUID) RETURNS VOID AS $$
BEGIN
    DELETE FROM public.wanted_posters WHERE id = p_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
