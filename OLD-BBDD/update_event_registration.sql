-- update_event_registration.sql

-- 1. Modify the toggle_event_registration RPC to handle both events and dtp_events tables
CREATE OR REPLACE FUNCTION toggle_event_registration(p_event_id UUID, p_user_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    v_is_dtp BOOLEAN;
    v_exists BOOLEAN;
BEGIN
    -- First, check if the event exists in dtp_events
    SELECT EXISTS (
        SELECT 1 FROM dtp_events WHERE id = p_event_id
    ) INTO v_is_dtp;

    IF v_is_dtp THEN
        -- Handle registration for DTP practice
        SELECT EXISTS (
            SELECT 1 FROM dtp_event_attendees WHERE event_id = p_event_id AND user_id = p_user_id
        ) INTO v_exists;

        IF v_exists THEN
            DELETE FROM dtp_event_attendees WHERE event_id = p_event_id AND user_id = p_user_id;
            RETURN FALSE; -- Currently not participating
        ELSE
            -- Default status is 'REGISTERED' which means 'Pendiente'
            INSERT INTO dtp_event_attendees (event_id, user_id, status) VALUES (p_event_id, p_user_id, 'REGISTERED');
            RETURN TRUE; -- Currently participating
        END IF;

    ELSE
        -- Assume it's a regular event (or it doesn't exist, in which case the FK constraint will fail and error cleanly)
        SELECT EXISTS (
             SELECT 1 FROM event_participants WHERE event_id = p_event_id AND user_id = p_user_id
        ) INTO v_exists;
        
        IF v_exists THEN
            DELETE FROM event_participants WHERE event_id = p_event_id AND user_id = p_user_id;
            RETURN FALSE;
        ELSE
            INSERT INTO event_participants (event_id, user_id) VALUES (p_event_id, p_user_id);
            RETURN TRUE;
        END IF;
    END IF;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 2. Update get_upcoming_events to return the 'status' column for DTP events (and null for normal events)
DROP FUNCTION IF EXISTS get_upcoming_events(UUID);

CREATE OR REPLACE FUNCTION get_upcoming_events(p_user_id UUID)
RETURNS TABLE (
    id UUID,
    title TEXT,
    description TEXT,
    event_date TIMESTAMP WITH TIME ZONE,
    created_by UUID,
    created_at TIMESTAMP WITH TIME ZONE,
    participant_count BIGINT,
    is_participating BOOLEAN,
    author_name TEXT,
    author_rank TEXT,
    author_image TEXT,
    user_status TEXT
) AS $$
BEGIN
    RETURN QUERY
    
    -- 1. Standard General Events
    SELECT 
        e.id,
        e.title,
        e.description,
        e.event_date,
        e.created_by,
        e.created_at,
        (SELECT COUNT(*) FROM event_participants ep WHERE ep.event_id = e.id) AS participant_count,
        EXISTS (SELECT 1 FROM event_participants ep WHERE ep.event_id = e.id AND ep.user_id = p_user_id) AS is_participating,
        u.nombre || ' ' || u.apellido AS author_name,
        u.rango::text AS author_rank,
        u.profile_image AS author_image,
        NULL::TEXT AS user_status -- Normal events don't have attendance status
    FROM events e
    LEFT JOIN users u ON e.created_by = u.id
    WHERE e.event_date >= CURRENT_DATE
    
    UNION ALL
    
    -- 2. DTP Practice Events
    SELECT 
        de.id,
        dp.title AS title,
        COALESCE(dp.description, '') || CHR(10) || CHR(10) || 'Lugar/Notas: ' || COALESCE(de.notes, 'N/A') AS description,
        de.event_date,
        de.organizer_id AS created_by,
        de.created_at,
        (SELECT COUNT(*) FROM dtp_event_attendees dpea WHERE dpea.event_id = de.id) AS participant_count,
        EXISTS (SELECT 1 FROM dtp_event_attendees dpea WHERE dpea.event_id = de.id AND dpea.user_id = p_user_id) AS is_participating,
        u.nombre || ' ' || u.apellido AS author_name,
        u.rango::text AS author_rank,
        u.profile_image AS author_image,
        (SELECT status FROM dtp_event_attendees dpea WHERE dpea.event_id = de.id AND dpea.user_id = p_user_id LIMIT 1) AS user_status
    FROM dtp_events de
    JOIN dtp_practices dp ON de.practice_id = dp.id
    LEFT JOIN users u ON de.organizer_id = u.id
    WHERE de.event_date >= CURRENT_DATE 
      AND de.status != 'CANCELLED'
      
    ORDER BY event_date ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 3. Update get_all_month_events to also return user_status
DROP FUNCTION IF EXISTS get_all_month_events(UUID, INT, INT);

CREATE OR REPLACE FUNCTION get_all_month_events(p_user_id UUID, p_year INT, p_month INT)
RETURNS TABLE (
    id UUID,
    title TEXT,
    description TEXT,
    event_date TIMESTAMP WITH TIME ZONE,
    created_by UUID,
    created_at TIMESTAMP WITH TIME ZONE,
    participant_count BIGINT,
    is_participating BOOLEAN,
    author_name TEXT,
    author_rank TEXT,
    author_image TEXT,
    user_status TEXT
) AS $$
BEGIN
    RETURN QUERY
    
    -- 1. Standard General Events
    SELECT 
        e.id,
        e.title,
        e.description,
        e.event_date,
        e.created_by,
        e.created_at,
        (SELECT COUNT(*) FROM event_participants ep WHERE ep.event_id = e.id) AS participant_count,
        EXISTS (SELECT 1 FROM event_participants ep WHERE ep.event_id = e.id AND ep.user_id = p_user_id) AS is_participating,
        u.nombre || ' ' || u.apellido AS author_name,
        u.rango::text AS author_rank,
        u.profile_image AS author_image,
        NULL::TEXT AS user_status
    FROM events e
    LEFT JOIN users u ON e.created_by = u.id
    WHERE EXTRACT(YEAR FROM e.event_date) = p_year 
      AND EXTRACT(MONTH FROM e.event_date) = p_month
      
    UNION ALL
    
    -- 2. DTP Practice Events
    SELECT 
        de.id,
        dp.title AS title,
        COALESCE(dp.description, '') || CHR(10) || CHR(10) || 'Lugar/Notas: ' || COALESCE(de.notes, 'N/A') AS description,
        de.event_date,
        de.organizer_id AS created_by,
        de.created_at,
        (SELECT COUNT(*) FROM dtp_event_attendees dpea WHERE dpea.event_id = de.id) AS participant_count,
        EXISTS (SELECT 1 FROM dtp_event_attendees dpea WHERE dpea.event_id = de.id AND dpea.user_id = p_user_id) AS is_participating,
        u.nombre || ' ' || u.apellido AS author_name,
        u.rango::text AS author_rank,
        u.profile_image AS author_image,
        (SELECT status FROM dtp_event_attendees dpea WHERE dpea.event_id = de.id AND dpea.user_id = p_user_id LIMIT 1) AS user_status
    FROM dtp_events de
    JOIN dtp_practices dp ON de.practice_id = dp.id
    LEFT JOIN users u ON de.organizer_id = u.id
    WHERE EXTRACT(YEAR FROM de.event_date) = p_year 
      AND EXTRACT(MONTH FROM de.event_date) = p_month
      AND de.status != 'CANCELLED'
      
    ORDER BY event_date ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
