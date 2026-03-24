-- Fix User Deletion FK Constraints
-- This script updates foreign key constraints to allow user deletion by setting references to NULL or Cascading.

-- 1. case_updates (author_id) -> SET NULL
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_name = 'case_updates_author_id_fkey') THEN
        ALTER TABLE public.case_updates DROP CONSTRAINT case_updates_author_id_fkey;
    END IF;
    
    ALTER TABLE public.case_updates 
    ADD CONSTRAINT case_updates_author_id_fkey 
    FOREIGN KEY (author_id) REFERENCES public.users(id) ON DELETE SET NULL;
END $$;

-- 2. cases (created_by) -> SET NULL
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_name = 'cases_created_by_fkey') THEN
        ALTER TABLE public.cases DROP CONSTRAINT cases_created_by_fkey;
    END IF;

    ALTER TABLE public.cases 
    ADD CONSTRAINT cases_created_by_fkey 
    FOREIGN KEY (created_by) REFERENCES public.users(id) ON DELETE SET NULL;
END $$;

-- 3. map_zones (created_by) -> SET NULL
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_name = 'map_zones_created_by_fkey') THEN
        ALTER TABLE public.map_zones DROP CONSTRAINT map_zones_created_by_fkey;
    END IF;

    ALTER TABLE public.map_zones 
    ADD CONSTRAINT map_zones_created_by_fkey 
    FOREIGN KEY (created_by) REFERENCES public.users(id) ON DELETE SET NULL;
END $$;

-- 4. gangs (created_by) -> SET NULL
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_name = 'gangs_created_by_fkey') THEN
        ALTER TABLE public.gangs DROP CONSTRAINT gangs_created_by_fkey;
    END IF;

    ALTER TABLE public.gangs 
    ADD CONSTRAINT gangs_created_by_fkey 
    FOREIGN KEY (created_by) REFERENCES public.users(id) ON DELETE SET NULL;
END $$;

-- 5. gang_info (author_id) -> SET NULL
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_name = 'gang_info_author_id_fkey') THEN
        ALTER TABLE public.gang_info DROP CONSTRAINT gang_info_author_id_fkey;
    END IF;

    ALTER TABLE public.gang_info 
    ADD CONSTRAINT gang_info_author_id_fkey 
    FOREIGN KEY (author_id) REFERENCES public.users(id) ON DELETE SET NULL;
END $$;

-- 6. incidents (author_id) -> SET NULL
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_name = 'incidents_author_id_fkey') THEN
        ALTER TABLE public.incidents DROP CONSTRAINT incidents_author_id_fkey;
    END IF;

    ALTER TABLE public.incidents 
    ADD CONSTRAINT incidents_author_id_fkey 
    FOREIGN KEY (author_id) REFERENCES public.users(id) ON DELETE SET NULL;
END $$;

-- 7. outings (created_by) -> SET NULL
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_name = 'outings_created_by_fkey') THEN
        ALTER TABLE public.outings DROP CONSTRAINT outings_created_by_fkey;
    END IF;

    ALTER TABLE public.outings 
    ADD CONSTRAINT outings_created_by_fkey 
    FOREIGN KEY (created_by) REFERENCES public.users(id) ON DELETE SET NULL;
END $$;

-- 8. outing_detectives (user_id) -> CASCADE (Join table)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_name = 'outing_detectives_user_id_fkey') THEN
        ALTER TABLE public.outing_detectives DROP CONSTRAINT outing_detectives_user_id_fkey;
    END IF;

    ALTER TABLE public.outing_detectives 
    ADD CONSTRAINT outing_detectives_user_id_fkey 
    FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;
END $$;
