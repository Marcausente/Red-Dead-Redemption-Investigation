-- JUDICIAL ORDERS SYSTEM (Replaces Warrant Requests)

-- 1. Signup/Cleanup of previous attempt if exists
DROP TABLE IF EXISTS public.warrant_requests CASCADE;
DROP TABLE IF EXISTS public.judicial_orders CASCADE;
DROP FUNCTION IF EXISTS create_warrant_request;
DROP FUNCTION IF EXISTS get_warrant_requests;
DROP FUNCTION IF EXISTS review_warrant_request;


-- 2. Create Table
CREATE TABLE IF NOT EXISTS public.judicial_orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_type TEXT NOT NULL CHECK (order_type IN (
      'Orden de Registro (Casa)', 
      'Orden de Registro (Coche)', 
      'Orden de Arresto', 
      'Orden de Revision Telefonica', 
      'Orden de Revision Bancaria', 
      'Orden de Identificacion Red Social',
      'Orden de Identificacion Telefono Movil',
      'Orden de Decomiso', 
      'Orden de Alejamiento', 
      'Orden de Precinto',
      'Ley Rico',
      'Revision de Camaras'
  )),
  title TEXT NOT NULL, -- e.g. "Arresto - Pepe Garcia"
  content JSONB NOT NULL DEFAULT '{}'::jsonb, -- Stores dynamic fields
  status TEXT NOT NULL DEFAULT 'Pendiente' CHECK (status IN ('Pendiente', 'Aprobada', 'Rechazada')),
  
  created_by UUID REFERENCES public.users(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. Enable RLS
ALTER TABLE public.judicial_orders ENABLE ROW LEVEL SECURITY;

-- 4. Policies
CREATE POLICY "Read orders allowed for auth" ON public.judicial_orders FOR SELECT TO authenticated USING (true);
CREATE POLICY "Insert orders allowed for auth" ON public.judicial_orders FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Update orders allowed for auth" ON public.judicial_orders FOR UPDATE TO authenticated USING (true);
-- Normally we don't delete orders unless admin, but default RLS denies delete unless policy added.

-- 5. RPC: Create Order
CREATE OR REPLACE FUNCTION create_judicial_order(
  p_type TEXT,
  p_title TEXT,
  p_content JSONB
)
RETURNS UUID AS $$
DECLARE
  v_new_id UUID;
  v_user_rol TEXT;
BEGIN
  -- Restrict Ayudante
  SELECT u.rol::text INTO v_user_rol FROM public.users u WHERE u.id = auth.uid();
  IF v_user_rol = 'Ayudante' THEN
      RAISE EXCEPTION 'Access Denied: Ayudantes cannot create orders.';
  END IF;

  INSERT INTO public.judicial_orders (order_type, title, content, created_by, status)
  VALUES (p_type, p_title, p_content, auth.uid(), 'Pendiente')
  RETURNING id INTO v_new_id;

  RETURN v_new_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 6. RPC: Get Orders
DROP FUNCTION IF EXISTS get_judicial_orders(text);
CREATE OR REPLACE FUNCTION get_judicial_orders(p_type_filter TEXT DEFAULT NULL)
RETURNS TABLE (
  id UUID,
  order_type TEXT,
  title TEXT,
  content JSONB,
  status TEXT,
  created_at TIMESTAMP WITH TIME ZONE,
  author_name TEXT,
  author_rank TEXT,
  author_avatar TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    o.id,
    o.order_type,
    o.title,
    o.content,
    o.status,
    o.created_at,
    (u.nombre || ' ' || u.apellido) as author_name,
    u.rango::text as author_rank,
    u.profile_image as author_avatar
  FROM public.judicial_orders o
  JOIN public.users u ON o.created_by = u.id
  WHERE (p_type_filter IS NULL OR p_type_filter = 'Todas' OR o.order_type = p_type_filter)
  ORDER BY o.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. RPC: Update Order Status
CREATE OR REPLACE FUNCTION update_judicial_order_status(
  p_order_id UUID,
  p_new_status TEXT
)
RETURNS VOID AS $$
DECLARE
  v_user_rol TEXT;
BEGIN
  -- Check Role
  SELECT u.rol::text INTO v_user_rol FROM public.users u WHERE u.id = auth.uid();
  
  -- Ayudante cannot change status
  IF v_user_rol = 'Ayudante' THEN
      RAISE EXCEPTION 'Access Denied: Ayudantes cannot change order status.';
  END IF;

  UPDATE public.judicial_orders
  SET status = p_new_status
  WHERE id = p_order_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 8. RPC: Delete Order
CREATE OR REPLACE FUNCTION delete_judicial_order(p_order_id UUID)
RETURNS VOID AS $$
DECLARE
  v_user_rol TEXT;
BEGIN
  -- Check Role
  SELECT u.rol::text INTO v_user_rol FROM public.users u WHERE u.id = auth.uid();
  
  -- Ayudante cannot delete
  IF v_user_rol = 'Ayudante' THEN
      RAISE EXCEPTION 'Access Denied: Ayudantes cannot delete orders.';
  END IF;

  DELETE FROM public.judicial_orders WHERE id = p_order_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
