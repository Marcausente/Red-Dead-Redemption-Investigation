import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { supabase } from '../supabaseClient';
import './CasesRDR.css';

function Cases() {
    const navigate = useNavigate();
    const [cases, setCases] = useState([]);
    const [loading, setLoading] = useState(true);
    const [filter, setFilter] = useState('Abierto'); // Abierto, Cerrado, Archivado
    const [showCreateModal, setShowCreateModal] = useState(false);

    // Form State (Defaulting to 1880)
    const [newCase, setNewCase] = useState({
        title: '',
        location: '',
        occurred_at: '1880-05-25T12:00', 
        description: '',
        assignments: [],
        initialImage: null
    });
    
    // Only agents permitted for assigning
    const [detectives, setDetectives] = useState([]); 
    const [submitting, setSubmitting] = useState(false);
    const [currentUser, setCurrentUser] = useState(null);

    useEffect(() => {
        const getCurrentUser = async () => {
            const { data: { user } } = await supabase.auth.getUser();
            if (user) {
                const { data } = await supabase.from('users').select('rol').eq('id', user.id).single();
                setCurrentUser(data);
            }
        };
        getCurrentUser();
        fetchCases();
        fetchDetectives();
    }, [filter]);

    const fetchCases = async () => {
        setLoading(true);
        const { data, error } = await supabase.rpc('get_cases', { p_status_filter: filter });
        if (error) console.error('Error fetching cases:', error);
        else setCases(data || []);
        setLoading(false);
    };

    const fetchDetectives = async () => {
        // Fetch users who are strictly Investigators + Admins
        const { data, error } = await supabase
            .from('users')
            .select('id, nombre, apellido, rango, profile_image, rol')
            .in('rol', ['Administrador', 'Coordinador', 'Agente BOI', 'Ayudante BOI'])
            .order('rol');
            
        if (!error && data) {
            setDetectives(data);
        }
    };

    const handleCreateCase = async (e) => {
        e.preventDefault();
        setSubmitting(true);
        try {
            // Check date to ensure 1880 constraint manually on frontend to prevent mistakes
            const yearObj = new Date(newCase.occurred_at).getFullYear();
            if (yearObj !== 1880) {
                alert("AVISO: Todos los reportes deben datarse en el año 1880.");
                setSubmitting(false);
                return;
            }

            const timestamp = new Date(newCase.occurred_at).toISOString();

            const { data: newId, error } = await supabase.rpc('create_new_case', {
                p_title: newCase.title,
                p_location: newCase.location,
                p_occurred_at: timestamp,
                p_description: newCase.description,
                p_assigned_ids: newCase.assignments,
                p_image: newCase.initialImage
            });

            if (error) throw error;

            setShowCreateModal(false);
            navigate(`/cases/${newId}`);

        } catch (err) {
            alert('Error abriendo caso: ' + err.message);
        } finally {
            setSubmitting(false);
        }
    };

    const toggleAssignment = (userId) => {
        const current = newCase.assignments;
        if (current.includes(userId)) {
            setNewCase({ ...newCase, assignments: current.filter(id => id !== userId) });
        } else {
            setNewCase({ ...newCase, assignments: [...current, userId] });
        }
    };

    const handleImageUpload = (e) => {
        const file = e.target.files[0];
        if (!file) return;

        const reader = new FileReader();
        reader.readAsDataURL(file);
        reader.onload = (event) => {
            const img = new Image();
            img.src = event.target.result;
            img.onload = () => {
                const canvas = document.createElement('canvas');
                const MAX_WIDTH = 800;
                const scaleSize = img.width > MAX_WIDTH ? (MAX_WIDTH / img.width) : 1;
                canvas.width = img.width * scaleSize;
                canvas.height = img.height * scaleSize;
                
                const ctx = canvas.getContext('2d');
                ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
                
                // Compress severely to WebP to maintain fast DB speeds and RDR aesthetic
                const dataUrl = canvas.toDataURL('image/webp', 0.6);
                setNewCase({ ...newCase, initialImage: dataUrl });
            };
        };
    };

    const getStatusClass = (status) => {
        if(status === 'Abierto') return 'status-abierto';
        if(status === 'Cerrado') return 'status-cerrado';
        return 'status-archivado';
    };

    return (
        <div className="rdr-cases-container">
            <div className="rdr-cases-header">
                <h2 className="rdr-cases-title">ARCHIVO CRIMINAL (BOI)</h2>
                {currentUser?.rol !== 'Externo' && (
                    <button className="rdr-btn-brown" style={{margin: 0}} onClick={() => setShowCreateModal(true)}>
                        + FUNDAR EXPEDIENTE
                    </button>
                )}
            </div>

            <div className="rdr-cases-tabs">
                {['Abierto', 'Cerrado', 'Archivado'].map(status => (
                    <button
                        key={status}
                        onClick={() => setFilter(status)}
                        className={`rdr-tab-btn ${filter === status ? 'active' : ''}`}
                    >
                        Expedientes {status}s
                    </button>
                ))}
            </div>

            {loading ? (
                <div style={{color: '#c0a080', fontFamily: 'Cinzel', textAlign: 'center', marginTop: '3rem'}}>Buscando en los archivadores...</div>
            ) : cases.length === 0 ? (
                <div style={{color: '#8b5a2b', fontFamily: 'Playfair Display', textAlign: 'center', marginTop: '3rem'}}>No se encontraron expedientes con la condición de "{filter}".</div>
            ) : (
                <div className="rdr-cases-grid">
                    {cases.map(c => (
                        <div key={c.id} className="rdr-case-folder" onClick={() => navigate(`/cases/${c.id}`)}>
                            <div className="rdr-case-id">CÓDIGO #{String(c.case_number).padStart(4, '0')}</div>
                            <div className={`rdr-case-status ${getStatusClass(c.status)}`}>{c.status}</div>
                            
                            <h3 className="rdr-case-name">{c.title}</h3>

                            <div className="rdr-case-meta">
                                <b>Lugar:</b> {c.location}<br/>
                                <b>Fecha:</b> {new Date(c.occurred_at).toLocaleDateString()}
                            </div>

                            <div className="rdr-case-footer">
                                <span style={{fontSize: '0.85rem', color: '#4a3321', fontFamily: 'Cinzel', fontWeight: 'bold'}}>INVESTIGADORES</span>
                                <div className="rdr-assigned-group">
                                    {c.assigned_avatars && c.assigned_avatars.length > 0 ? c.assigned_avatars.map((img, idx) => (
                                        <img
                                            key={idx}
                                            src={img || '/anon.png'}
                                            className="rdr-assigned-avatar"
                                            alt="Inv"
                                        />
                                    )) : (
                                        <span style={{fontSize: '0.8rem', fontStyle: 'italic', color: '#8b5a2b'}}>Nadie</span>
                                    )}
                                </div>
                            </div>
                        </div>
                    ))}
                </div>
            )}

            {/* CREATE MODAL */}
            {showCreateModal && (
                <div className="rdr-modal-overlay">
                    <div className="rdr-modal-content" style={{maxWidth: '700px'}}>
                        <h2 style={{textTransform: 'uppercase', marginBottom: '1.5rem', textAlign: 'center'}}>NUEVO REGISTRO CRIMINAL</h2>
                        
                        <form onSubmit={handleCreateCase} className="rdr-cases-form-scroll">
                            <div className="rdr-form-group">
                                <label className="rdr-form-label">Títular del Caso</label>
                                <input type="text" className="rdr-input" required
                                    value={newCase.title} onChange={e => setNewCase({ ...newCase, title: e.target.value })} placeholder="Ej: Los asaltos a los trenes del valle..." />
                            </div>

                            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1.5rem', marginBottom: '1rem' }}>
                                <div className="rdr-form-group">
                                    <label className="rdr-form-label">Ubicación Primaria</label>
                                    <input type="text" className="rdr-input" required
                                        value={newCase.location} onChange={e => setNewCase({ ...newCase, location: e.target.value })} placeholder="Ej: Blackwater" />
                                </div>
                                <div className="rdr-form-group">
                                    <label className="rdr-form-label">Sucedido (Año 1880)</label>
                                    <input type="datetime-local" className="rdr-input" required
                                        value={newCase.occurred_at} onChange={e => setNewCase({ ...newCase, occurred_at: e.target.value })} />
                                </div>
                            </div>

                            <div className="rdr-form-group">
                                <label className="rdr-form-label">Descripción Inicial / Testimonios</label>
                                <textarea className="rdr-input" rows="5" required
                                    value={newCase.description} onChange={e => setNewCase({ ...newCase, description: e.target.value })} placeholder="Redacta la escena original con pluma o dicta testigos..." />
                            </div>

                            <div className="rdr-form-group" style={{marginTop: '1rem'}}>
                                <label className="rdr-form-label">Fotografía del Suceso (Opcional)</label>
                                <label className="rdr-btn-brown" style={{ width: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer', textAlign: 'center', background: 'transparent', borderColor: '#8b5a2b', color: '#4a3321', borderStyle: 'dashed' }}>
                                    ADJUNTAR ESTAMPA FOTOGRÁFICA
                                    <input type="file" accept="image/*" onChange={handleImageUpload} style={{ display: 'none' }} />
                                </label>
                                {newCase.initialImage && (
                                    <div style={{ position: 'relative', marginTop: '10px' }}>
                                        <img src={newCase.initialImage} style={{ width: '100%', maxHeight: '300px', objectFit: 'cover', borderRadius: '2px', border: '5px solid #2b1d12' }} alt="Muestra" />
                                        <button type="button" onClick={() => setNewCase({ ...newCase, initialImage: null })} style={{ position: 'absolute', top: 10, right: 10, background: '#8b0000', color: 'white', border: 'none', padding: '5px 10px', fontWeight: 'bold', cursor: 'pointer', borderRadius: '2px' }}>XT</button>
                                    </div>
                                )}
                            </div>

                            <div className="rdr-form-group" style={{marginTop: '1.5rem'}}>
                                <label className="rdr-form-label">Asignar Investigadores de Campo</label>
                                <div className="rdr-assign-list">
                                    {detectives.map(u => (
                                        <div key={u.id}
                                            className={`rdr-assign-row ${newCase.assignments.includes(u.id) ? 'selected' : ''}`}
                                            onClick={() => toggleAssignment(u.id)}>
                                            <input type="checkbox" checked={newCase.assignments.includes(u.id)} readOnly style={{ marginRight: '15px', accentColor: '#8b5a2b' }} />
                                            <img src={u.profile_image || '/anon.png'} alt="" style={{ width: '32px', height: '32px', borderRadius: '50%', marginRight: '15px', border: '1px solid #8b5a2b', objectFit: 'cover' }} />
                                            <span style={{ fontSize: '1rem', fontFamily: 'Cinzel', fontWeight: 'bold' }}>{u.rango}</span>
                                            <span style={{ fontSize: '1rem', marginLeft: '8px', fontFamily: 'Playfair Display' }}>{u.nombre} {u.apellido}</span>
                                        </div>
                                    ))}
                                    {detectives.length === 0 && <div style={{padding: '1rem', fontStyle: 'italic', color: '#8b5a2b'}}>No hay agentes en servicio aún.</div>}
                                </div>
                            </div>

                            <div style={{ display: 'flex', gap: '15px', justifyContent: 'flex-end', marginTop: '2.5rem' }}>
                                <button type="button" className="rdr-btn-brown" onClick={() => setShowCreateModal(false)} style={{ background: 'transparent', borderColor: '#8b0000', color: '#8b0000' }}>Canclar</button>
                                <button type="submit" className="rdr-btn-brown" disabled={submitting}>{submitting ? 'Sellando...' : 'INSCRIBIR CASO'}</button>
                            </div>
                        </form>
                    </div>
                </div>
            )}
        </div>
    );
}

export default Cases;
