-- ============================================================
-- 12_setup_missing_posters.sql — Módulo de Carteles de Desaparecidos
-- ============================================================

-- Drop if exists for re-running
DROP FUNCTION IF EXISTS get_missing_posters();
DROP FUNCTION IF EXISTS create_missing_poster(TEXT,TEXT,TEXT,BOOLEAN,NUMERIC,TIMESTAMP WITH TIME ZONE,TEXT,TEXT);
DROP FUNCTION IF EXISTS update_missing_poster(UUID,TEXT,TEXT,TEXT,BOOLEAN,NUMERIC,TIMESTAMP WITH TIME ZONE,TEXT,TEXT);
DROP FUNCTION IF EXISTS archive_missing_poster(UUID);
DROP FUNCTION IF EXISTS delete_missing_poster(UUID);

-- TABLE
CREATE TABLE IF NOT EXISTS public.missing_posters (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    person_name TEXT NOT NULL,
    person_surname TEXT,
    last_seen TEXT, -- Último lugar visto
    description TEXT, -- Descripción de la persona
    offer_reward BOOLEAN DEFAULT false,
    reward_amount NUMERIC(10,2) DEFAULT 0,
    published_at TIMESTAMP WITH TIME ZONE DEFAULT '1880-01-01T12:00:00Z',
    photo TEXT,
    is_archived BOOLEAN DEFAULT false,
    created_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- RLS
DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='missing_posters' AND column_name='description') THEN
        ALTER TABLE public.missing_posters ADD COLUMN description TEXT;
    END IF;
END $$;

ALTER TABLE public.missing_posters ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can read missing_posters" ON public.missing_posters;
DROP POLICY IF EXISTS "Authenticated users can insert missing_posters" ON public.missing_posters;
DROP POLICY IF EXISTS "Authenticated users can update missing_posters" ON public.missing_posters;
DROP POLICY IF EXISTS "Authenticated users can delete missing_posters" ON public.missing_posters;

CREATE POLICY "Authenticated users can read missing_posters" ON public.missing_posters FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated users can insert missing_posters" ON public.missing_posters FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Authenticated users can update missing_posters" ON public.missing_posters FOR UPDATE TO authenticated USING (true);
CREATE POLICY "Authenticated users can delete missing_posters" ON public.missing_posters FOR DELETE TO authenticated USING (true);

-- GET ALL
CREATE OR REPLACE FUNCTION get_missing_posters()
RETURNS JSONB AS $$
DECLARE
    active_posters JSONB;
    archived_posters JSONB;
BEGIN
    SELECT COALESCE(json_agg(
        json_build_object(
            'id', mp.id,
            'person_name', mp.person_name,
            'person_surname', mp.person_surname,
            'last_seen', mp.last_seen,
            'description', mp.description,
            'offer_reward', mp.offer_reward,
            'reward_amount', mp.reward_amount,
            'published_at', mp.published_at,
            'photo', mp.photo,
            'is_archived', mp.is_archived,
            'created_at', mp.created_at
        ) ORDER BY mp.created_at DESC
    ), '[]') INTO active_posters
    FROM public.missing_posters mp WHERE mp.is_archived = false;

    SELECT COALESCE(json_agg(
        json_build_object(
            'id', mp.id,
            'person_name', mp.person_name,
            'person_surname', mp.person_surname,
            'last_seen', mp.last_seen,
            'description', mp.description,
            'offer_reward', mp.offer_reward,
            'reward_amount', mp.reward_amount,
            'published_at', mp.published_at,
            'photo', mp.photo,
            'is_archived', mp.is_archived,
            'created_at', mp.created_at
        ) ORDER BY mp.created_at DESC
    ), '[]') INTO archived_posters
    FROM public.missing_posters mp WHERE mp.is_archived = true;

    RETURN jsonb_build_object('active', active_posters, 'archived', archived_posters);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- CREATE
CREATE OR REPLACE FUNCTION create_missing_poster(
    p_name TEXT, p_surname TEXT, p_last_seen TEXT, p_offer_reward BOOLEAN,
    p_reward NUMERIC, p_published_at TIMESTAMP WITH TIME ZONE, p_photo TEXT, p_description TEXT
) RETURNS VOID AS $$
BEGIN
    INSERT INTO public.missing_posters (person_name, person_surname, last_seen, offer_reward, reward_amount, published_at, photo, created_by, description)
    VALUES (p_name, p_surname, p_last_seen, p_offer_reward, p_reward, p_published_at, p_photo, auth.uid(), p_description);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- UPDATE
CREATE OR REPLACE FUNCTION update_missing_poster(
    p_id UUID, p_name TEXT, p_surname TEXT, p_last_seen TEXT, p_offer_reward BOOLEAN,
    p_reward NUMERIC, p_published_at TIMESTAMP WITH TIME ZONE, p_photo TEXT, p_description TEXT
) RETURNS VOID AS $$
BEGIN
    UPDATE public.missing_posters SET
        person_name = p_name, person_surname = p_surname, last_seen = p_last_seen,
        offer_reward = p_offer_reward, reward_amount = p_reward, published_at = p_published_at, photo = p_photo, description = p_description
    WHERE id = p_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ARCHIVE TOGGLE
CREATE OR REPLACE FUNCTION archive_missing_poster(p_id UUID) RETURNS VOID AS $$
BEGIN
    UPDATE public.missing_posters SET is_archived = NOT is_archived WHERE id = p_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- DELETE
CREATE OR REPLACE FUNCTION delete_missing_poster(p_id UUID) RETURNS VOID AS $$
BEGIN
    DELETE FROM public.missing_posters WHERE id = p_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
