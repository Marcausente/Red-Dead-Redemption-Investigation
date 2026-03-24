-- GANG PATROL TIME CONTROL SYSTEM
-- Allows detectives to log patrol observations with time, people count, and photos

-- 1. Create patrol logs table
CREATE TABLE IF NOT EXISTS public.gang_patrol_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    gang_id UUID REFERENCES public.gangs(id) ON DELETE CASCADE NOT NULL,
    patrol_time TIMESTAMP WITH TIME ZONE NOT NULL,
    people_count INTEGER NOT NULL DEFAULT 0,
    photo TEXT, -- base64 encoded image
    notes TEXT,
    created_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.gang_patrol_logs ENABLE ROW LEVEL SECURITY;

-- Policy: Authenticated users can view all patrol logs
DROP POLICY IF EXISTS "View patrol logs" ON public.gang_patrol_logs;
CREATE POLICY "View patrol logs" ON public.gang_patrol_logs
    FOR SELECT TO authenticated USING (true);

-- Policy: Authenticated users can insert patrol logs
DROP POLICY IF EXISTS "Insert patrol logs" ON public.gang_patrol_logs;
CREATE POLICY "Insert patrol logs" ON public.gang_patrol_logs
    FOR INSERT TO authenticated WITH CHECK (true);

-- Policy: Users can delete their own logs, or admins/coordinators can delete any
DROP POLICY IF EXISTS "Delete patrol logs" ON public.gang_patrol_logs;
CREATE POLICY "Delete patrol logs" ON public.gang_patrol_logs
    FOR DELETE TO authenticated
    USING (
        created_by = auth.uid() 
        OR EXISTS (
            SELECT 1 FROM public.users 
            WHERE id = auth.uid() 
            AND TRIM(rol::text) IN ('Administrador', 'Coordinador', 'Comisionado')
        )
    );

-- 2. Create RPC to add patrol log
CREATE OR REPLACE FUNCTION create_patrol_log(
    p_gang_id UUID,
    p_patrol_time TIMESTAMP WITH TIME ZONE,
    p_people_count INTEGER,
    p_photo TEXT DEFAULT NULL,
    p_notes TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_log_id UUID;
BEGIN
    INSERT INTO public.gang_patrol_logs (
        gang_id,
        patrol_time,
        people_count,
        photo,
        notes,
        created_by
    ) VALUES (
        p_gang_id,
        p_patrol_time,
        p_people_count,
        p_photo,
        p_notes,
        auth.uid()
    ) RETURNING id INTO v_log_id;
    
    RETURN v_log_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Create RPC to get patrol logs for a gang
CREATE OR REPLACE FUNCTION get_patrol_logs(p_gang_id UUID)
RETURNS TABLE (
    id UUID,
    gang_id UUID,
    patrol_time TIMESTAMP WITH TIME ZONE,
    people_count INTEGER,
    photo TEXT,
    notes TEXT,
    detective_name TEXT,
    detective_rank TEXT,
    detective_avatar TEXT,
    created_at TIMESTAMP WITH TIME ZONE,
    can_delete BOOLEAN
) AS $$
DECLARE
    v_uid UUID;
    v_user_role TEXT;
BEGIN
    v_uid := auth.uid();
    SELECT TRIM(u.rol::text) INTO v_user_role 
    FROM public.users u 
    WHERE u.id = v_uid;
    
    RETURN QUERY
    SELECT 
        pl.id,
        pl.gang_id,
        pl.patrol_time,
        pl.people_count,
        pl.photo,
        pl.notes,
        COALESCE(u.nombre || ' ' || u.apellido, 'Unknown') as detective_name,
        COALESCE(u.rango::text, 'N/A') as detective_rank,
        u.profile_image as detective_avatar,
        pl.created_at,
        (pl.created_by = v_uid OR v_user_role IN ('Administrador', 'Coordinador', 'Comisionado')) as can_delete
    FROM public.gang_patrol_logs pl
    LEFT JOIN public.users u ON pl.created_by = u.id
    WHERE pl.gang_id = p_gang_id
    ORDER BY pl.patrol_time DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Create RPC to delete patrol log
CREATE OR REPLACE FUNCTION delete_patrol_log(p_log_id UUID)
RETURNS VOID AS $$
BEGIN
    DELETE FROM public.gang_patrol_logs
    WHERE id = p_log_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
