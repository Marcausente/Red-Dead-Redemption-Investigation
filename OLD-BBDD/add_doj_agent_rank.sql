-- Add Department of Justice Agent to the rank enum

-- First, check the current enum values
-- SELECT enum_range(NULL::app_rank);

-- Add the new rank value to the enum
ALTER TYPE app_rank ADD VALUE IF NOT EXISTS 'Department of Justice Agent';

-- Verify the update
-- SELECT enum_range(NULL::app_rank);
