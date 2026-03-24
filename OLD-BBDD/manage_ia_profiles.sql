-- MANAGE IA PROFILES
-- Adds support for updating and deleting sanctioned profiles

-- Update Profile RPC
CREATE OR REPLACE FUNCTION update_ia_subject_profile(
    p_id UUID,
    p_nombre TEXT,
    p_apellido TEXT,
    p_no_placa TEXT
)
RETURNS VOID AS $$
BEGIN
    UPDATE public.ia_subject_profiles
    SET 
        nombre = p_nombre,
        apellido = p_apellido,
        no_placa = p_no_placa
    WHERE id = p_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Delete Profile RPC
CREATE OR REPLACE FUNCTION delete_ia_subject_profile(
    p_id UUID
)
RETURNS VOID AS $$
BEGIN
    DELETE FROM public.ia_subject_profiles
    WHERE id = p_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
