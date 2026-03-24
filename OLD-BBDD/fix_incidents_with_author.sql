-- COMPLETE FIX: Incidents Display with Author Info and Edit Support
-- This replaces get_incidents_v2 and get_outings with full author information

-- 1. Drop and recreate get_incidents_v2 WITH AUTHOR INFO
DROP FUNCTION IF EXISTS get_incidents_v2();
CREATE OR REPLACE FUNCTION get_incidents_v2()
RETURNS TABLE (
    record_id UUID,
    title TEXT,
    location TEXT,
    occurred_at TIMESTAMP WITH TIME ZONE,
    tablet_number TEXT,
    description TEXT,
    images JSONB,
    created_at TIMESTAMP WITH TIME ZONE,
    gang_id UUID,
    gang_names TEXT[],
    author_name TEXT,
    author_rank TEXT,
    author_avatar TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        i.id,
        i.title,
        i.location,
        i.occurred_at,
        i.tablet_incident_number,
        i.description,
        i.images,
        i.created_at,
        (SELECT ig.gang_id FROM public.incident_gangs ig WHERE ig.incident_id = i.id LIMIT 1),
        ARRAY(
            SELECT g.name 
            FROM public.incident_gangs ig 
            JOIN public.gangs g ON ig.gang_id = g.id 
            WHERE ig.incident_id = i.id
            ORDER BY g.name
        )::TEXT[],
        COALESCE(u.nombre || ' ' || u.apellido, 'Unknown'),
        COALESCE(u.rango, 'N/A'),
        u.profile_image
    FROM public.incidents i
    LEFT JOIN public.users u ON i.author_id = u.id
    ORDER BY i.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Drop and recreate get_outings WITH AUTHOR INFO
DROP FUNCTION IF EXISTS get_outings();
CREATE OR REPLACE FUNCTION get_outings()
RETURNS TABLE (
    record_id UUID,
    title TEXT,
    occurred_at TIMESTAMP WITH TIME ZONE,
    reason TEXT,
    info_obtained TEXT,
    images JSONB,
    created_at TIMESTAMP WITH TIME ZONE,
    detectives JSONB,
    gang_id UUID,
    gang_names TEXT[],
    author_name TEXT,
    author_rank TEXT,
    author_avatar TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        o.id,
        o.title,
        o.occurred_at,
        o.reason,
        o.info_obtained,
        o.images,
        o.created_at,
        COALESCE(
            (SELECT jsonb_agg(jsonb_build_object('name', u.nombre || ' ' || u.apellido, 'rank', u.rango))
             FROM public.outing_detectives od
             JOIN public.users u ON od.detective_id = u.id
             WHERE od.outing_id = o.id),
            '[]'::jsonb
        ),
        (SELECT og.gang_id FROM public.outing_gangs og WHERE og.outing_id = o.id LIMIT 1),
        ARRAY(
            SELECT g.name 
            FROM public.outing_gangs og 
            JOIN public.gangs g ON og.gang_id = g.id 
            WHERE og.outing_id = o.id
            ORDER BY g.name
        )::TEXT[],
        COALESCE(u.nombre || ' ' || u.apellido, 'Unknown'),
        COALESCE(u.rango, 'N/A'),
        u.profile_image
    FROM public.outings o
    LEFT JOIN public.users u ON o.created_by = u.id
    ORDER BY o.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Get linked gangs for an incident (for editing)
CREATE OR REPLACE FUNCTION get_incident_gangs(p_incident_id UUID)
RETURNS TABLE (gang_id UUID, gang_name TEXT) AS $$
BEGIN
    RETURN QUERY
    SELECT g.id, g.name
    FROM public.incident_gangs ig
    JOIN public.gangs g ON ig.gang_id = g.id
    WHERE ig.incident_id = p_incident_id
    ORDER BY g.name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Get linked gangs for an outing (for editing)
CREATE OR REPLACE FUNCTION get_outing_gangs(p_outing_id UUID)
RETURNS TABLE (gang_id UUID, gang_name TEXT) AS $$
BEGIN
    RETURN QUERY
    SELECT g.id, g.name
    FROM public.outing_gangs og
    JOIN public.gangs g ON og.gang_id = g.id
    WHERE og.outing_id = p_outing_id
    ORDER BY g.name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Add UPDATE policy for incidents
DROP POLICY IF EXISTS "Authenticated users can update incidents" ON public.incidents;
CREATE POLICY "Authenticated users can update incidents" ON public.incidents 
FOR UPDATE USING (auth.role() = 'authenticated');

-- 6. Add UPDATE policy for outings
DROP POLICY IF EXISTS "Authenticated users can update outings" ON public.outings;
CREATE POLICY "Authenticated users can update outings" ON public.outings 
FOR UPDATE USING (auth.role() = 'authenticated');
