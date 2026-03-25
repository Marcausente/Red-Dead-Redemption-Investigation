import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { supabase } from '../supabaseClient';
import '../index.css';
import './DashboardRDR.css';

function Dashboard() {
    const navigate = useNavigate();
    const [user, setUser] = useState(null);
    const [announcements, setAnnouncements] = useState([]);
    const [loading, setLoading] = useState(true);

    // Create/Edit Modal State
    const [showModal, setShowModal] = useState(false);
    const [newPost, setNewPost] = useState({ title: '', content: '', pinned: false });
    const [editingId, setEditingId] = useState(null);
    const [submitting, setSubmitting] = useState(false);

    useEffect(() => {
        loadDashboardData();
    }, []);

    const loadDashboardData = async () => {
        try {
            setLoading(true);
            const { data: { user: authUser } } = await supabase.auth.getUser();
            if (!authUser) {
                navigate('/');
                return;
            }

            // Get User Profile
            const { data: userData, error: userError } = await supabase
                .from('users')
                .select('*')
                .eq('id', authUser.id)
                .single();

            if (userError) throw userError;
            setUser(userData);

            // Get Announcements
            await fetchAnnouncements();
        } catch (error) {
            console.error('Error loading dashboard:', error);
        } finally {
            setLoading(false);
        }
    };

    const fetchAnnouncements = async () => {
        const { data, error } = await supabase.rpc('get_announcements');
        if (error) {
            console.error('Error fetching announcements:', error);
        } else {
            setAnnouncements(data || []);
        }
    };

    const handleSaveAnnouncement = async (e) => {
        e.preventDefault();
        if (!newPost.title.trim() || !newPost.content.trim()) return;

        try {
            setSubmitting(true);

            if (editingId) {
                const { error } = await supabase.rpc('update_announcement', {
                    p_id: editingId,
                    p_title: newPost.title,
                    p_content: newPost.content,
                    p_pinned: newPost.pinned
                });
                if (error) throw error;
            } else {
                const { error } = await supabase.rpc('create_announcement', {
                    p_title: newPost.title,
                    p_content: newPost.content,
                    p_pinned: newPost.pinned
                });
                if (error) throw error;
            }

            closeModal();
            fetchAnnouncements();
        } catch (err) {
            alert('Error saving post: ' + err.message);
        } finally {
            setSubmitting(false);
        }
    };

    const handleEdit = (ann) => {
        setNewPost({ title: ann.title, content: ann.content, pinned: ann.pinned });
        setEditingId(ann.id);
        setShowModal(true);
    };

    const closeModal = () => {
        setShowModal(false);
        setNewPost({ title: '', content: '', pinned: false });
        setEditingId(null);
    };

    const handleDelete = async (id) => {
        if (!window.confirm("¿Seguro que deseas arrancar este cartel del tablón?")) return;
        try {
            const { error } = await supabase.rpc('delete_announcement', { p_id: id });
            if (error) throw error;
            fetchAnnouncements();
        } catch (err) {
            alert(err.message);
        }
    };

    const handlePin = async (id) => {
        try {
            const { error } = await supabase.rpc('toggle_pin_announcement', { p_id: id });
            if (error) throw error;
            fetchAnnouncements();
        } catch (err) {
            alert(err.message);
        }
    };

    // Role-based permissions using old roles mapped to new ones, roughly equivalent
    const canPost = user && ['Agente BOI', 'Ayudante BOI', 'Coordinador', 'Administrador'].includes(user.rol);
    const canPin = user && ['Coordinador', 'Administrador'].includes(user.rol);

    if (loading) return <div style={{textAlign: 'center', marginTop: '5rem', color: '#c0a080'}}>Cargando el tablón...</div>;

    return (
        <div className="rdr-board-container">
            <div className="rdr-board-header">
                <h2 className="rdr-board-title">BUREAU OF INVESTIGATION</h2>
                <h4 className="rdr-board-subtitle">TABLÓN DE ANUNCIOS OFICIAL</h4>
                
                {canPost && (
                    <div className="rdr-board-controls">
                        <button className="rdr-btn-brown" onClick={() => { setEditingId(null); setNewPost({ title: '', content: '', pinned: false }); setShowModal(true); }}>
                            + REDACTAR NUEVO CARTEL
                        </button>
                    </div>
                )}
            </div>

            <div className="rdr-posters-grid">
                {announcements.length === 0 ? (
                    <div style={{ textAlign: 'center', gridColumn: '1 / -1', color: '#c0a080', fontSize: '1.2rem' }}>
                        No hay cárteles pegados en el tablón en este momento.
                    </div>
                ) : (
                    announcements.map(ann => (
                        <div key={ann.id} className={`rdr-poster-card ${ann.pinned ? 'pinned' : ''}`}>
                            <div className="rdr-poster-header">
                                <h4 className="rdr-poster-title">{ann.title}</h4>
                            </div>

                            <div className="rdr-poster-content">{ann.content}</div>

                            <div className="rdr-poster-footer">
                                <div className="rdr-poster-author">
                                    {ann.author_image ? (
                                        <img src={ann.author_image} alt="Author" className="rdr-poster-avatar" />
                                    ) : (
                                        <div className="rdr-poster-avatar-placeholder">{ann.author_name?.charAt(0) || 'U'}</div>
                                    )}
                                    <div className="rdr-poster-meta-text">
                                        <span className="rdr-poster-meta-name">{ann.author_rank} {ann.author_name}</span>
                                        <span className="rdr-poster-meta-date">
                                            {(() => {
                                                const d = new Date(ann.created_at);
                                                const day = d.getDate().toString().padStart(2, '0');
                                                const month = (d.getMonth() + 1).toString().padStart(2, '0');
                                                const time = d.toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'});
                                                return `${day}/${month}/1880 - ${time}`;
                                            })()}
                                        </span>
                                    </div>
                                </div>
                                <div className="rdr-poster-actions">
                                    {canPin && (
                                        <button onClick={() => handlePin(ann.id)} className="rdr-btn-brown" title={ann.pinned ? "Desclavar" : "Clavar importante"} style={{padding: '5px 10px', fontSize: '0.8rem'}}>
                                            {ann.pinned ? "📌 Quitar" : "📌 Clavar"}
                                        </button>
                                    )}
                                    {ann.cur_user_can_delete && (
                                        <>
                                            <button onClick={() => handleEdit(ann)} className="rdr-btn-brown" title="Editar" style={{padding: '5px 10px', fontSize: '0.8rem'}}>
                                                ✏️
                                            </button>
                                            <button onClick={() => handleDelete(ann.id)} className="rdr-btn-brown" title="Arrancar" style={{padding: '5px 10px', fontSize: '0.8rem', color: '#a52a2a'}}>
                                                ✖
                                            </button>
                                        </>
                                    )}
                                </div>
                            </div>
                        </div>
                    ))
                )}
            </div>

            {/* Create/Edit Modal */}
            {showModal && (
                <div className="rdr-modal-overlay">
                    <div className="rdr-modal-content">
                        <h3>{editingId ? 'EDITAR CARTEL' : 'REDACTAR CARTEL NOVEDOSO'}</h3>
                        <form onSubmit={handleSaveAnnouncement}>
                            <div>
                                <label style={{color: '#c0a080', fontSize: '0.9rem', textTransform: 'uppercase'}}>Titular del Cartel</label>
                                <input
                                    type="text"
                                    className="rdr-input"
                                    value={newPost.title}
                                    onChange={e => setNewPost({ ...newPost, title: e.target.value })}
                                    placeholder="Ej: SE BUSCA / ATENCIÓN AGENTES"
                                    required
                                />
                            </div>
                            <div>
                                <label style={{color: '#c0a080', fontSize: '0.9rem', textTransform: 'uppercase'}}>Contenido</label>
                                <textarea
                                    className="rdr-input"
                                    rows="10"
                                    value={newPost.content}
                                    onChange={e => setNewPost({ ...newPost, content: e.target.value })}
                                    required
                                    style={{resize: 'vertical'}}
                                />
                            </div>
                            {canPin && (
                                <div style={{ display: 'flex', alignItems: 'center', gap: '0.8rem', marginBottom: '1.5rem' }}>
                                    <input
                                        type="checkbox"
                                        id="pinCheck"
                                        checked={newPost.pinned}
                                        onChange={e => setNewPost({ ...newPost, pinned: e.target.checked })}
                                        style={{transform: 'scale(1.5)', accentColor: '#d4af37'}}
                                    />
                                    <label htmlFor="pinCheck" style={{ color: '#c0a080', cursor: 'pointer', fontFamily: 'Cinzel, serif' }}>Clavar con urgencia (Fijar arriba)</label>
                                </div>
                            )}
                            <div style={{ display: 'flex', gap: '1rem', justifyContent: 'flex-end', marginTop: '1rem' }}>
                                <button type="button" className="rdr-btn-brown" onClick={closeModal} style={{background: 'transparent', color: '#c0a080', borderColor: '#c0a080'}}>
                                    Cancelar
                                </button>
                                <button type="submit" className="rdr-btn-brown" disabled={submitting}>
                                    {submitting ? 'Pegando...' : (editingId ? 'Actualizar' : 'Pegar Cartel')}
                                </button>
                            </div>
                        </form>
                    </div>
                </div>
            )}
        </div>
    );
}

export default Dashboard;
