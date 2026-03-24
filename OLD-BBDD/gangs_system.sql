-- GANGS INTELLIGENCE SYSTEM
-- Access Control: Restricted to Detectives, Coordinators, Commissioners, Admins.

-- 1. TABLES

CREATE TABLE IF NOT EXISTS public.gangs (
    id UUID DEFAULT extensions.uuid_generate_v4() PRIMARY KEY,
    name TEXT NOT NULL,
    color TEXT DEFAULT '#ffffff', -- Hex Code
    zones_image TEXT, -- Base64 or URL
    is_archived BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID REFERENCES public.users(id)
);

-- Note: If running this script on existing DB, column is_archived might not exist if created previously. 
-- We add it safely:
DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='gangs' AND column_name='is_archived') THEN 
        ALTER TABLE public.gangs ADD COLUMN is_archived BOOLEAN DEFAULT FALSE; 
    END IF; 
END $$;


CREATE TABLE IF NOT EXISTS public.gang_vehicles (
    id UUID DEFAULT extensions.uuid_generate_v4() PRIMARY KEY,
    gang_id UUID REFERENCES public.gangs(id) ON DELETE CASCADE,
    model TEXT,
    plate TEXT,
    owner_name TEXT,
    notes TEXT,
    images JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.gang_homes (
    id UUID DEFAULT extensions.uuid_generate_v4() PRIMARY KEY,
    gang_id UUID REFERENCES public.gangs(id) ON DELETE CASCADE,
    owner_name TEXT,
    address_notes TEXT,
    images JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Member Roles: 'Lider', 'Sublider', 'Miembro', 'Sospechoso'
CREATE TABLE IF NOT EXISTS public.gang_members (
    id UUID DEFAULT extensions.uuid_generate_v4() PRIMARY KEY,
    gang_id UUID REFERENCES public.gangs(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    role TEXT DEFAULT 'Sospechoso', 
    photo TEXT, -- Base64
    notes TEXT,
    status TEXT DEFAULT 'Active', -- Active, Arrested, Deceased
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.gang_info (
    id UUID DEFAULT extensions.uuid_generate_v4() PRIMARY KEY,
    gang_id UUID REFERENCES public.gangs(id) ON DELETE CASCADE,
    type TEXT NOT NULL, -- 'info' or 'characteristic'
    content TEXT,
    images JSONB DEFAULT '[]'::jsonb,
    author_id UUID REFERENCES public.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. SECURITY (RLS)
-- Only allow read/write to authorized roles.

ALTER TABLE public.gangs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gang_vehicles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gang_homes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gang_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gang_info ENABLE ROW LEVEL SECURITY;

-- Helper function to check gang permission (General Access)
CREATE OR REPLACE FUNCTION auth_is_gang_authorized() RETURNS BOOLEAN AS $$
DECLARE
    v_role TEXT;
BEGIN
    SELECT TRIM(rol::text) INTO v_role FROM public.users WHERE id = auth.uid();
    RETURN v_role IN ('Detective', 'Coordinador', 'Comisionado', 'Administrador');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Helper function for VIP Access (Archive/Delete)
CREATE OR REPLACE FUNCTION auth_is_gang_vip() RETURNS BOOLEAN AS $$
DECLARE
    v_role TEXT;
BEGIN
    SELECT TRIM(rol::text) INTO v_role FROM public.users WHERE id = auth.uid();
    RETURN v_role IN ('Coordinador', 'Comisionado', 'Administrador');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- Policies (Drop existing first to allow re-run)
DROP POLICY IF EXISTS "Authorized can view gangs" ON public.gangs;
DROP POLICY IF EXISTS "Authorized can insert gangs" ON public.gangs;
DROP POLICY IF EXISTS "Authorized can update gangs" ON public.gangs;
DROP POLICY IF EXISTS "Authorized can delete gangs" ON public.gangs; -- Add Delete policy for VIP
CREATE POLICY "Authorized can view gangs" ON public.gangs FOR SELECT USING (auth_is_gang_authorized());
CREATE POLICY "Authorized can insert gangs" ON public.gangs FOR INSERT WITH CHECK (auth_is_gang_authorized());
CREATE POLICY "Authorized can update gangs" ON public.gangs FOR UPDATE USING (auth_is_gang_authorized());
CREATE POLICY "Authorized can delete gangs" ON public.gangs FOR DELETE USING (auth_is_gang_vip());

DROP POLICY IF EXISTS "Authorized can view vehicles" ON public.gang_vehicles;
DROP POLICY IF EXISTS "Authorized can insert vehicles" ON public.gang_vehicles;
DROP POLICY IF EXISTS "Authorized can update vehicles" ON public.gang_vehicles;
DROP POLICY IF EXISTS "Authorized can delete vehicles" ON public.gang_vehicles;
CREATE POLICY "Authorized can view vehicles" ON public.gang_vehicles FOR SELECT USING (auth_is_gang_authorized());
CREATE POLICY "Authorized can insert vehicles" ON public.gang_vehicles FOR INSERT WITH CHECK (auth_is_gang_authorized());
CREATE POLICY "Authorized can update vehicles" ON public.gang_vehicles FOR UPDATE USING (auth_is_gang_authorized());
CREATE POLICY "Authorized can delete vehicles" ON public.gang_vehicles FOR DELETE USING (auth_is_gang_authorized());

DROP POLICY IF EXISTS "Authorized can view homes" ON public.gang_homes;
DROP POLICY IF EXISTS "Authorized can insert homes" ON public.gang_homes;
DROP POLICY IF EXISTS "Authorized can update homes" ON public.gang_homes;
DROP POLICY IF EXISTS "Authorized can delete homes" ON public.gang_homes;
CREATE POLICY "Authorized can view homes" ON public.gang_homes FOR SELECT USING (auth_is_gang_authorized());
CREATE POLICY "Authorized can insert homes" ON public.gang_homes FOR INSERT WITH CHECK (auth_is_gang_authorized());
CREATE POLICY "Authorized can update homes" ON public.gang_homes FOR UPDATE USING (auth_is_gang_authorized());
CREATE POLICY "Authorized can delete homes" ON public.gang_homes FOR DELETE USING (auth_is_gang_authorized());

DROP POLICY IF EXISTS "Authorized can view members" ON public.gang_members;
DROP POLICY IF EXISTS "Authorized can insert members" ON public.gang_members;
DROP POLICY IF EXISTS "Authorized can update members" ON public.gang_members;
DROP POLICY IF EXISTS "Authorized can delete members" ON public.gang_members;
CREATE POLICY "Authorized can view members" ON public.gang_members FOR SELECT USING (auth_is_gang_authorized());
CREATE POLICY "Authorized can insert members" ON public.gang_members FOR INSERT WITH CHECK (auth_is_gang_authorized());
CREATE POLICY "Authorized can update members" ON public.gang_members FOR UPDATE USING (auth_is_gang_authorized());
CREATE POLICY "Authorized can delete members" ON public.gang_members FOR DELETE USING (auth_is_gang_authorized());

DROP POLICY IF EXISTS "Authorized can view info" ON public.gang_info;
DROP POLICY IF EXISTS "Authorized can insert info" ON public.gang_info;
DROP POLICY IF EXISTS "Authorized can update info" ON public.gang_info;
DROP POLICY IF EXISTS "Authorized can delete info" ON public.gang_info;
CREATE POLICY "Authorized can view info" ON public.gang_info FOR SELECT USING (auth_is_gang_authorized());
CREATE POLICY "Authorized can insert info" ON public.gang_info FOR INSERT WITH CHECK (auth_is_gang_authorized());
CREATE POLICY "Authorized can update info" ON public.gang_info FOR UPDATE USING (auth_is_gang_authorized());
CREATE POLICY "Authorized can delete info" ON public.gang_info FOR DELETE USING (auth_is_gang_authorized());


-- 3. RPCs

-- Create Gang
CREATE OR REPLACE FUNCTION create_gang(
    p_name TEXT,
    p_color TEXT,
    p_zones_image TEXT
) RETURNS UUID AS $$
DECLARE
    v_id UUID;
BEGIN
    IF NOT auth_is_gang_authorized() THEN RAISE EXCEPTION 'Access Denied'; END IF;
    
    INSERT INTO public.gangs (name, color, zones_image, created_by)
    VALUES (p_name, p_color, p_zones_image, auth.uid())
    RETURNING id INTO v_id;
    
    RETURN v_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Get Gangs (Full Data Load)
DROP FUNCTION IF EXISTS get_gangs_data();
CREATE OR REPLACE FUNCTION get_gangs_data()
RETURNS TABLE (
    gang_id UUID,
    name TEXT,
    color TEXT,
    zones_image TEXT,
    is_archived BOOLEAN,
    vehicles JSONB,
    homes JSONB,
    members JSONB,
    info JSONB,
    incident_count BIGINT,
    outing_count BIGINT
) AS $$
BEGIN
    IF NOT auth_is_gang_authorized() THEN 
        RETURN; -- Validate return empty if not authorized
    END IF;

    RETURN QUERY
    SELECT 
        g.id AS gang_id,
        g.name,
        g.color,
        g.zones_image,
        g.is_archived, -- Added field
        -- Vehicles
        COALESCE((
            SELECT jsonb_agg(jsonb_build_object('id', v.id, 'model', v.model, 'plate', v.plate, 'owner', v.owner_name, 'notes', v.notes, 'images', v.images))
            FROM public.gang_vehicles v WHERE v.gang_id = g.id
        ), '[]'::jsonb),
        -- Homes
        COALESCE((
            SELECT jsonb_agg(jsonb_build_object('id', h.id, 'owner', h.owner_name, 'notes', h.address_notes, 'images', h.images))
            FROM public.gang_homes h WHERE h.gang_id = g.id
        ), '[]'::jsonb),
        -- Members
        COALESCE((
            SELECT jsonb_agg(jsonb_build_object('id', m.id, 'name', m.name, 'role', m.role, 'photo', m.photo, 'notes', m.notes, 'status', m.status))
            FROM public.gang_members m WHERE m.gang_id = g.id
        ), '[]'::jsonb),
        -- Info
        COALESCE((
            SELECT jsonb_agg(jsonb_build_object('id', i.id, 'type', i.type, 'content', i.content, 'images', i.images, 'author', (SELECT nombre||' '||apellido FROM public.users WHERE id=i.author_id)))
            FROM public.gang_info i WHERE i.gang_id = g.id
        ), '[]'::jsonb),
        -- Counts
        (SELECT COUNT(*) FROM public.incidents inc WHERE inc.gang_id = g.id),
        (SELECT COUNT(*) FROM public.outings out WHERE out.gang_id = g.id)
        
    FROM public.gangs g
    ORDER BY g.created_at ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- Add Sub-Items
CREATE OR REPLACE FUNCTION add_gang_vehicle(p_gang_id UUID, p_model TEXT, p_plate TEXT, p_owner TEXT, p_notes TEXT, p_images JSONB) RETURNS UUID AS $$
DECLARE v_id UUID; BEGIN
    IF NOT auth_is_gang_authorized() THEN RAISE EXCEPTION 'Access Denied'; END IF;
    INSERT INTO public.gang_vehicles (gang_id, model, plate, owner_name, notes, images) VALUES (p_gang_id, p_model, p_plate, p_owner, p_notes, p_images) RETURNING id INTO v_id;
    RETURN v_id;
END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION add_gang_home(p_gang_id UUID, p_owner TEXT, p_notes TEXT, p_images JSONB) RETURNS UUID AS $$
DECLARE v_id UUID; BEGIN
    IF NOT auth_is_gang_authorized() THEN RAISE EXCEPTION 'Access Denied'; END IF;
    INSERT INTO public.gang_homes (gang_id, owner_name, address_notes, images) VALUES (p_gang_id, p_owner, p_notes, p_images) RETURNING id INTO v_id;
    RETURN v_id;
END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION add_gang_member(p_gang_id UUID, p_name TEXT, p_role TEXT, p_photo TEXT, p_notes TEXT) RETURNS UUID AS $$
DECLARE v_id UUID; BEGIN
    IF NOT auth_is_gang_authorized() THEN RAISE EXCEPTION 'Access Denied'; END IF;
    INSERT INTO public.gang_members (gang_id, name, role, photo, notes) VALUES (p_gang_id, p_name, p_role, p_photo, p_notes) RETURNING id INTO v_id;
    RETURN v_id;
END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION add_gang_info(p_gang_id UUID, p_type TEXT, p_content TEXT, p_images JSONB) RETURNS UUID AS $$
DECLARE v_id UUID; BEGIN
    IF NOT auth_is_gang_authorized() THEN RAISE EXCEPTION 'Access Denied'; END IF;
    INSERT INTO public.gang_info (gang_id, type, content, images, author_id) VALUES (p_gang_id, p_type, p_content, p_images, auth.uid()) RETURNING id INTO v_id;
    RETURN v_id;
END; $$ LANGUAGE plpgsql SECURITY DEFINER;


-- Link Incident/Outing
CREATE OR REPLACE FUNCTION link_incident_gang(p_incident_id UUID, p_gang_id UUID) RETURNS VOID AS $$
BEGIN
    IF NOT auth_is_gang_authorized() THEN RAISE EXCEPTION 'Access Denied'; END IF;
    UPDATE public.incidents SET gang_id = p_gang_id WHERE id = p_incident_id;
END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION link_outing_gang(p_outing_id UUID, p_gang_id UUID) RETURNS VOID AS $$
BEGIN
    IF NOT auth_is_gang_authorized() THEN RAISE EXCEPTION 'Access Denied'; END IF;
    UPDATE public.outings SET gang_id = p_gang_id WHERE id = p_outing_id;
END; $$ LANGUAGE plpgsql SECURITY DEFINER;

-- DELETE / ARCHIVE FUNCTIONS

CREATE OR REPLACE FUNCTION toggle_gang_archive(p_gang_id UUID, p_archive BOOLEAN) RETURNS VOID AS $$
BEGIN
    IF NOT auth_is_gang_vip() THEN RAISE EXCEPTION 'Access Denied: High Command Only'; END IF;
    UPDATE public.gangs SET is_archived = p_archive WHERE id = p_gang_id;
END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION delete_gang_fully(p_gang_id UUID) RETURNS VOID AS $$
BEGIN
    IF NOT auth_is_gang_vip() THEN RAISE EXCEPTION 'Access Denied: High Command Only'; END IF;
    -- ON DELETE CASCADE handles sub-tables (vehicles, etc)
    DELETE FROM public.gangs WHERE id = p_gang_id;
END; $$ LANGUAGE plpgsql SECURITY DEFINER;


-- DELETE ITEM FUNCTIONS (Standard)
CREATE OR REPLACE FUNCTION delete_gang_item(p_table TEXT, p_id UUID) RETURNS VOID AS $$
BEGIN
    IF NOT auth_is_gang_authorized() THEN RAISE EXCEPTION 'Access Denied'; END IF;
    
    IF p_table = 'vehicle' THEN DELETE FROM public.gang_vehicles WHERE id = p_id;
    ELSIF p_table = 'home' THEN DELETE FROM public.gang_homes WHERE id = p_id;
    ELSIF p_table = 'member' THEN DELETE FROM public.gang_members WHERE id = p_id;
    ELSIF p_table = 'info' THEN DELETE FROM public.gang_info WHERE id = p_id;
    END IF;
END; $$ LANGUAGE plpgsql SECURITY DEFINER;
