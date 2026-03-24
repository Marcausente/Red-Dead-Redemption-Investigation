-- ----------------------------------------------------------------
-- CLEANUP SCRIPT: REMOVE EMPTY/INVALID GANG ITEMS
-- ----------------------------------------------------------------
-- Run this script in the Supabase SQL Editor to delete "ghost" entries
-- that cannot be seen or edited properly because they are empty.

BEGIN;

-- 1. Remove Empty Vehicles
-- Deletes vehicles where BOTH Model and Plate are empty/null
DELETE FROM public.gang_vehicles 
WHERE (TRIM(model) = '' OR model IS NULL) 
  AND (TRIM(plate) = '' OR plate IS NULL);

-- 2. Remove Empty Properties (Homes)
-- Deletes homes where BOTH Owner Name and Address Notes are empty/null
DELETE FROM public.gang_homes 
WHERE (TRIM(owner_name) = '' OR owner_name IS NULL) 
  AND (TRIM(address_notes) = '' OR address_notes IS NULL);

-- 3. Remove Empty Intelligence (Info)
-- Deletes info/characteristic entries where Content is empty/null
DELETE FROM public.gang_info 
WHERE (TRIM(content) = '' OR content IS NULL);

COMMIT;

-- Output verifying removal
SELECT 'Cleanup Complete' as status;
