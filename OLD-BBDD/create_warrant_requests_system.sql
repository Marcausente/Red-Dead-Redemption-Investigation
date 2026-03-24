-- Warrant Requests System

-- 1. Create Table
CREATE TABLE IF NOT EXISTS public.warrant_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  request_type TEXT NOT NULL CHECK (request_type IN ('Orden de Allanamiento', 'Orden de Arresto', 'Orden de Vigilancia', 'Otro')),
  target_name TEXT NOT NULL,
  location TEXT,
  reason TEXT,
  status TEXT DEFAULT 'Pendiente' CHECK (status IN ('Pendiente', 'Aprobada', 'Rechazada')),
  
  requested_by UUID REFERENCES public.users(id),
  reviewed_by UUID REFERENCES public.users(id),
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Enable RLS
ALTER TABLE public.warrant_requests ENABLE ROW LEVEL SECURITY;

-- 3. Policies
-- Read: Authenticated users can read
CREATE POLICY "Read warrants allowed for auth" ON public.warrant_requests FOR SELECT TO authenticated USING (true);
-- Insert: Authenticated users can insert
CREATE POLICY "Insert warrants allowed for auth" ON public.warrant_requests FOR INSERT TO authenticated WITH CHECK (true);
-- Update: Authenticated users can update (RPC will handle specific logic)
CREATE POLICY "Update warrants allowed for auth" ON public.warrant_requests FOR UPDATE TO authenticated USING (true);


-- 4. RPC: Create Request
CREATE OR REPLACE FUNCTION create_warrant_request(
  p_type TEXT,
  p_target TEXT,
  p_location TEXT,
  p_reason TEXT
)
RETURNS UUID AS $$
DECLARE
  v_new_id UUID;
  v_user_rol TEXT;
BEGIN
  -- Restrict Ayudante if needed, or allow them to request? Usually Ayudante shouldn't requesting warrants alone.
  -- Let's block Ayudante from requesting for consistency with Cases.
  SELECT u.rol::text INTO v_user_rol FROM public.users u WHERE u.id = auth.uid();
  IF v_user_rol = 'Ayudante' THEN
      RAISE EXCEPTION 'Access Denied: Ayudantes cannot submit warrant requests.';
  END IF;

  INSERT INTO public.warrant_requests (request_type, target_name, location, reason, requested_by)
  VALUES (p_type, p_target, p_location, p_reason, auth.uid())
  RETURNING id INTO v_new_id;

  RETURN v_new_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 5. RPC: Get Requests
CREATE OR REPLACE FUNCTION get_warrant_requests(p_status_filter TEXT DEFAULT NULL)
RETURNS TABLE (
  id UUID,
  request_type TEXT,
  target_name TEXT,
  location TEXT,
  reason TEXT,
  status TEXT,
  created_at TIMESTAMP WITH TIME ZONE,
  requester_name TEXT,
  requester_rank TEXT,
  requester_avatar TEXT,
  reviewer_name TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    w.id,
    w.request_type,
    w.target_name,
    w.location,
    w.reason,
    w.status,
    w.created_at,
    (u1.nombre || ' ' || u1.apellido) as requester_name,
    u1.rango as requester_rank,
    u1.profile_image as requester_avatar,
    (u2.nombre || ' ' || u2.apellido) as reviewer_name
  FROM public.warrant_requests w
  JOIN public.users u1 ON w.requested_by = u1.id
  LEFT JOIN public.users u2 ON w.reviewed_by = u2.id
  WHERE (p_status_filter IS NULL OR 
         (p_status_filter = 'Pendiente' AND w.status = 'Pendiente') OR
         (p_status_filter = 'Historial' AND w.status != 'Pendiente'))
  ORDER BY w.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 6. RPC: Review Request (Approve/Reject)
CREATE OR REPLACE FUNCTION review_warrant_request(
  p_request_id UUID,
  p_status TEXT -- 'Aprobada' or 'Rechazada'
)
RETURNS VOID AS $$
DECLARE
  v_user_rol TEXT;
BEGIN
  -- Strict Check: Only High Command
  SELECT u.rol::text INTO v_user_rol FROM public.users u WHERE u.id = auth.uid();
  
  IF v_user_rol NOT IN ('Administrador', 'Coordinador', 'Comisionado', 'Jefe', 'Capitan') THEN
      RAISE EXCEPTION 'Access Denied: You do not have permission to review warrants.';
  END IF;

  UPDATE public.warrant_requests
  SET 
    status = p_status,
    reviewed_by = auth.uid(),
    updated_at = NOW()
  WHERE id = p_request_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
