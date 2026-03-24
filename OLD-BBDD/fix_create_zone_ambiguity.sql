-- Fix Create Zone Ambiguity
-- This script drops the old function signatures that did not include 'incident_id'
-- to resolve the "Could not choose the best candidate function" error.

BEGIN;

-- 1. Drop old create_map_zone (7 arguments)
-- The new one has 8 arguments (including p_incident_id)
DROP FUNCTION IF EXISTS public.create_map_zone(text, text, jsonb, text, uuid, uuid, text);

-- 2. Drop old update_map_zone (6 arguments)
-- The new one has 7 arguments (including p_incident_id)
DROP FUNCTION IF EXISTS public.update_map_zone(uuid, text, text, uuid, uuid, text);

COMMIT;
