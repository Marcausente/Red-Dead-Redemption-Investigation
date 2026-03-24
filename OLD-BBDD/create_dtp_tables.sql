-- Table: dtp_practices (Archivo de Prácticas)
CREATE TABLE dtp_practices (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT,
    documents_urls TEXT[] DEFAULT '{}',
    author_id UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Table: dtp_events (Programación de Prácticas)
CREATE TABLE dtp_events (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    practice_id UUID REFERENCES dtp_practices(id) ON DELETE CASCADE,
    event_date TIMESTAMP WITH TIME ZONE NOT NULL,
    organizer_id UUID REFERENCES users(id) ON DELETE SET NULL,
    status TEXT DEFAULT 'SCHEDULED' CHECK (status IN ('SCHEDULED', 'COMPLETED', 'CANCELLED')),
    notes TEXT,
    extra_personnel TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Table: dtp_event_attendees (Asistencia a Prácticas)
CREATE TABLE dtp_event_attendees (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    event_id UUID REFERENCES dtp_events(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    status TEXT DEFAULT 'REGISTERED' CHECK (status IN ('REGISTERED', 'ATTENDED', 'ABSENT')),
    is_organizer BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(event_id, user_id) -- Un agente solo puede registrarse una vez por evento
);

-- ==========================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ==========================================

-- Habilitar RLS en las nuevas tablas
ALTER TABLE dtp_practices ENABLE ROW LEVEL SECURITY;
ALTER TABLE dtp_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE dtp_event_attendees ENABLE ROW LEVEL SECURITY;

-- Políticas para dtp_practices: Todos los autenticados pueden verlas. Todos los autenticados pueden crearlas/editarlas.
CREATE POLICY "Enable read access for all users" ON dtp_practices FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Enable insert access for all users" ON dtp_practices FOR INSERT WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Enable update access for all users" ON dtp_practices FOR UPDATE USING (auth.role() = 'authenticated');
CREATE POLICY "Enable delete access for all users" ON dtp_practices FOR DELETE USING (auth.role() = 'authenticated');

-- Políticas para dtp_events: Todos pueden verlos, crearlos, actualizarlos y eliminarlos.
CREATE POLICY "Enable read access for all users" ON dtp_events FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Enable insert access for all users" ON dtp_events FOR INSERT WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Enable update access for all users" ON dtp_events FOR UPDATE USING (auth.role() = 'authenticated');
CREATE POLICY "Enable delete access for all users" ON dtp_events FOR DELETE USING (auth.role() = 'authenticated');

-- Políticas para dtp_event_attendees: Todos pueden ver la asistencia. Cualquiera puede registrarse a sí mismo o a otros (por facilidad, o limitarlo a auto-registro).
CREATE POLICY "Enable read access for all users" ON dtp_event_attendees FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Enable insert access for all users" ON dtp_event_attendees FOR INSERT WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Enable update access for all users" ON dtp_event_attendees FOR UPDATE USING (auth.role() = 'authenticated');
CREATE POLICY "Enable delete access for all users" ON dtp_event_attendees FOR DELETE USING (auth.role() = 'authenticated');
