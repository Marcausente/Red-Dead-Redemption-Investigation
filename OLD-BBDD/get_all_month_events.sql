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
    author_image TEXT
) AS $$
BEGIN
    RETURN QUERY
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
        u.profile_image AS author_image
    FROM events e
    LEFT JOIN users u ON e.created_by = u.id
    WHERE EXTRACT(YEAR FROM e.event_date) = p_year 
      AND EXTRACT(MONTH FROM e.event_date) = p_month
    ORDER BY e.event_date ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
