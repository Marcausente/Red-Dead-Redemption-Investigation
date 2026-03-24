-- RPC to get a user's practice attendance history
CREATE OR REPLACE FUNCTION get_user_practice_history(p_user_id UUID)
RETURNS TABLE (
    event_id UUID,
    practice_title TEXT,
    event_date TIMESTAMP WITH TIME ZONE,
    event_status TEXT,
    user_role TEXT,
    attendance_status TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        e.id AS event_id,
        p.title AS practice_title,
        e.event_date,
        e.status AS event_status,
        CASE 
            WHEN e.organizer_id = p_user_id OR a.is_organizer = true THEN 'organizer'::text
            ELSE 'attendee'::text
        END AS user_role,
        CASE 
            WHEN e.organizer_id = p_user_id THEN 'PRESENT'::text
            WHEN a.status = 'ATTENDED' THEN 'PRESENT'::text
            WHEN a.status = 'ABSENT' THEN 'ABSENT'::text
            ELSE 'REGISTERED'::text
        END AS attendance_status
    FROM dtp_events e
    JOIN dtp_practices p ON e.practice_id = p.id
    LEFT JOIN dtp_event_attendees a ON e.id = a.event_id AND a.user_id = p_user_id
    WHERE e.organizer_id = p_user_id OR a.user_id = p_user_id
    ORDER BY e.event_date DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
