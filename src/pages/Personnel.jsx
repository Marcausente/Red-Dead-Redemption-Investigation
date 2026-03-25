import { useState, useEffect, useRef } from 'react';
import { createPortal } from 'react-dom';
import { useNavigate } from 'react-router-dom';
import AvatarEditor from 'react-avatar-editor';
import { supabase } from '../supabaseClient';
import { usePresence } from '../contexts/PresenceContext';
import '../index.css';
import './DashboardRDR.css'; // For common rdr components like modals and buttons
import './PersonnelRDR.css';

function Personnel() {
    const navigate = useNavigate();
    const [users, setUsers] = useState([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);

    // Auth State
    const [currentUserRole, setCurrentUserRole] = useState(null);
    const [currentUserId, setCurrentUserId] = useState(null);

    // Global Presence
    const { onlineUsers } = usePresence();

    // Modal & Form State
    const [showModal, setShowModal] = useState(false);
    const [modalMode, setModalMode] = useState('create'); // 'create' or 'edit'
    const [editingUserId, setEditingUserId] = useState(null);

    const [processing, setProcessing] = useState(false);
    const [message, setMessage] = useState(null);

    // Cropper State
    const [editorOpen, setEditorOpen] = useState(false);
    const [imageSrc, setImageSrc] = useState(null);
    const [scale, setScale] = useState(1.2);
    const editorRef = useRef(null);

    // Default 1880 format for Entry Date
    const get1880Date = () => {
        const today = new Date();
        const month = (today.getMonth() + 1).toString().padStart(2, '0');
        const day = today.getDate().toString().padStart(2, '0');
        return `1880-${month}-${day}`;
    };

    const [formData, setFormData] = useState({
        email: '',
        password: '',
        nombre: '',
        apellido: '',
        no_placa: '',
        rango: 'Recluta',
        rol: 'Externo',
        fecha_ingreso: get1880Date(),
        profile_image: ''
    });

    const fileInputRef = useRef(null);

    useEffect(() => {
        fetchData();
    }, []);

    const fetchData = async () => {
        try {
            setLoading(true);

            // 1. Get Current User and Role
            const { data: { user } } = await supabase.auth.getUser();
            if (user) {
                setCurrentUserId(user.id);
                const { data: profile } = await supabase
                    .from('users')
                    .select('rol')
                    .eq('id', user.id)
                    .single();
                if (profile) setCurrentUserRole(profile.rol);
            }

            // 2. Fetch All Personnel
            const { data, error } = await supabase
                .from('users')
                .select('*');

            if (error) throw error;
            setUsers(data || []);
        } catch (err) {
            console.error('Error fetching data:', err);
            setError(err.message);
        } finally {
            setLoading(false);
        }
    };

    // Strict BOI Rank Priorities
    const RANK_ORDER = [
        'Marshal', 
        'Sheriff de Condado', 
        'Sheriff de Pueblo', 
        'Ayudante del Sheriff', 
        'Oficial Supervisor', 
        'Oficial', 
        'Aguacil de Primera', 
        'Aguacil de Segunda', 
        'Recluta'
    ];

    const getRankPriority = (rank) => {
        const idx = RANK_ORDER.indexOf(rank);
        return idx !== -1 ? idx : 999; // Lower index is HIGHER rank.
    };
    
    // Sort array so lowest index (Marshal) is first.
    const sortUsers = (a, b) => getRankPriority(a.rango) - getRankPriority(b.rango);

    // Filter Logic
    const investigadores = users.filter(u => ['Coordinador', 'Agente BOI', 'Ayudante BOI', 'Administrador'].includes(u.rol)).sort(sortUsers);
    const jefaturaExternos = users.filter(u => ['Externo', 'Jefatura'].includes(u.rol)).sort(sortUsers);

    // --- Actions ---

    const handleInputChange = (e) => {
        setFormData({ ...formData, [e.target.name]: e.target.value });
    };

    const handleFileChange = (e) => {
        const file = e.target.files[0];
        if (file) {
            setImageSrc(file);
            setEditorOpen(true);
            e.target.value = '';
        }
    };

    const handleSaveCroppedImage = () => {
        if (editorRef.current) {
            const canvas = editorRef.current.getImageScaledToCanvas();
            // Extreme optimization for BBDD (WEBP at 0.6)
            const dataUrl = canvas.toDataURL('image/webp', 0.6); 
            setFormData({ ...formData, profile_image: dataUrl });
            setEditorOpen(false);
            setImageSrc(null);
            setScale(1.2);
        }
    };

    const handleCancelCrop = () => {
        setEditorOpen(false);
        setImageSrc(null);
        setScale(1.2);
    };

    const openCreateModal = () => {
        setModalMode('create');
        setEditingUserId(null);
        setFormData({
            email: '', password: '', nombre: '', apellido: '', no_placa: '',
            rango: 'Recluta', rol: 'Externo', fecha_ingreso: get1880Date(), profile_image: ''
        });
        setMessage(null);
        setShowModal(true);
    };

    const openEditModal = (user) => {
        setModalMode('edit');
        setEditingUserId(user.id);
        
        let formattedDate = get1880Date();
        if (user.fecha_ingreso) {
            formattedDate = user.fecha_ingreso.split('T')[0];
        }

        setFormData({
            email: user.email,
            password: '', 
            nombre: user.nombre,
            apellido: user.apellido,
            no_placa: user.no_placa || '',
            rango: user.rango || 'Recluta',
            rol: user.rol || 'Externo',
            fecha_ingreso: formattedDate,
            profile_image: user.profile_image || ''
        });
        setMessage(null);
        setShowModal(true);
    };

    const handleDeleteUser = async (userId) => {
        if (!window.confirm("¿Seguro que deseas eliminar el registro de este agente?")) return;

        try {
            const { error } = await supabase.rpc('delete_personnel', { target_user_id: userId });
            if (error) throw error;

            setUsers(users.filter(u => u.id !== userId));
        } catch (err) {
            alert('Error deleting user: ' + err.message);
        }
    };

    const handleFormSubmit = async (e) => {
        e.preventDefault();
        setProcessing(true);
        setMessage(null);

        try {
            if (modalMode === 'create') {
                const { error } = await supabase.rpc('create_new_personnel', {
                    p_email: formData.email,
                    p_password: formData.password, 
                    p_nombre: formData.nombre,
                    p_apellido: formData.apellido,
                    p_rango: formData.rango,
                    p_rol: formData.rol,
                    p_fecha_ingreso: formData.fecha_ingreso || null,
                    p_profile_image: formData.profile_image || null
                });
                if (error) throw error;
                setMessage({ type: 'success', text: 'Agente alistado exitosamente.' });
            } else {
                // Update
                const { error } = await supabase.rpc('update_personnel_admin', {
                    p_user_id: editingUserId,
                    p_email: formData.email,
                    p_password: formData.password || null, 
                    p_nombre: formData.nombre,
                    p_apellido: formData.apellido,
                    p_rango: formData.rango,
                    p_rol: formData.rol,
                    p_fecha_ingreso: formData.fecha_ingreso || null,
                    p_profile_image: formData.profile_image || null
                });
                if (error) throw error;
                setMessage({ type: 'success', text: 'Expediente actualizado.' });
            }

            setTimeout(() => {
                setShowModal(false);
                fetchData();
            }, 1000);

        } catch (err) {
            console.error('Error saving user:', err);
            setMessage({ type: 'error', text: err.message });
        } finally {
            setProcessing(false);
        }
    };

    const canManagePersonnel = ['Administrador', 'Jefatura', 'Coordinador'].includes(currentUserRole);

    const UserCard = ({ user }) => {
        const isOnline = onlineUsers.has(user.id);

        return (
            <div className="rdr-agent-card" onClick={() => navigate(`/personnel/${user.id}`)}>
                <div style={{position: 'relative'}}>
                    <div className="rdr-agent-image-container">
                        {user.profile_image ? (
                            <img src={user.profile_image} alt={`${user.nombre} `} className="rdr-agent-image" />
                        ) : (
                            <div className="rdr-agent-no-image">{user.nombre ? user.nombre.charAt(0) : 'X'}</div>
                        )}
                    </div>
                    {isOnline && (
                        <div className="rdr-online-dot" title="En servicio activo"></div>
                    )}
                </div>

                <div className="rdr-agent-info">
                    <div className="rdr-agent-rank">{user.rango}</div>
                    <div className="rdr-agent-name">{user.nombre} {user.apellido}</div>
                </div>

                {canManagePersonnel && (
                    <div className="rdr-agent-actions" onClick={(e) => e.stopPropagation()}>
                        <button title="Editar" onClick={() => openEditModal(user)}>✏️</button>
                        <button title="Eliminar" onClick={() => handleDeleteUser(user.id)}>🗑️</button>
                    </div>
                )}
            </div>
        );
    };

    if (loading && users.length === 0) return <div style={{textAlign: 'center', marginTop: '5rem', color: '#c0a080', fontSize: '1.2rem', fontFamily: 'Cinzel'}}>Revisando archivos de personal...</div>;

    return (
        <div className="rdr-personnel-container">
            <div className="rdr-personnel-header">
                <h2 className="rdr-board-title" style={{ margin: 0, fontSize: '2.5rem' }}>PERSONAL DEL BUREAU</h2>
                {canManagePersonnel && (
                    <button className="rdr-btn-brown" onClick={openCreateModal}>
                        + RECLUTAR AGENTE
                    </button>
                )}
            </div>

            {error && <div style={{color: '#ff4444', textAlign: 'center', marginBottom: '2rem'}}>{error}</div>}

            <div className="rdr-personnel-layout">
                
                {/* Column 1: Investigadores */}
                <div className="rdr-personnel-section">
                    <h3 className="rdr-column-title">INVESTIGADORES</h3>
                    <div className="rdr-agents-list">
                        {investigadores.length > 0 ? investigadores.map(u => <UserCard key={u.id} user={u} />) : <div style={{color: '#8b5a2b', fontStyle: 'italic'}}>Sin registros...</div>}
                    </div>
                </div>

                {/* Column 2: Jefatura y Externos */}
                <div className="rdr-personnel-section">
                    <h3 className="rdr-column-title">JEFATURA Y EXTERNOS</h3>
                    <div className="rdr-agents-list">
                        {jefaturaExternos.length > 0 ? jefaturaExternos.map(u => <UserCard key={u.id} user={u} />) : <div style={{color: '#8b5a2b', fontStyle: 'italic'}}>Sin registros...</div>}
                    </div>
                </div>

            </div>

            {/* Add/Edit Modal */}
            {showModal && (
                <div className="rdr-modal-overlay">
                    <div className="rdr-modal-content" style={{ maxWidth: '700px' }}>
                        <h3 style={{ marginBottom: '1.5rem', textAlign: 'center' }}>
                            {modalMode === 'create' ? 'NUEVO EXPEDIENTE DE AGENTE' : 'MODIFICAR EXPEDIENTE'}
                        </h3>

                        {message && (
                            <div style={{
                                padding: '1rem', marginBottom: '1rem', borderRadius: '4px', textAlign: 'center',
                                backgroundColor: message.type === 'success' ? 'rgba(74, 222, 128, 0.1)' : 'rgba(239, 68, 68, 0.1)',
                                color: message.type === 'success' ? '#4ade80' : '#ef4444',
                                border: `1px solid ${message.type === 'success' ? '#4ade80' : '#ef4444'} `
                            }}>
                                {message.text}
                            </div>
                        )}

                        <form onSubmit={handleFormSubmit} style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1.5rem', textAlign: 'left' }}>
                            <div>
                                <label style={{color: '#c0a080', fontSize: '0.9rem', textTransform: 'uppercase'}}>Correo Telegráfico (Email)</label>
                                <input required type="email" name="email" className="rdr-input" value={formData.email} onChange={handleInputChange} />
                            </div>
                            
                            {(modalMode === 'create' || currentUserRole === 'Administrador' || currentUserId === editingUserId) && (
                                <div>
                                    <label style={{color: '#c0a080', fontSize: '0.9rem', textTransform: 'uppercase'}}>Contraseña {modalMode === 'edit' && '(Opcional)'}</label>
                                    <input
                                        type="password"
                                        name="password"
                                        className="rdr-input"
                                        value={formData.password}
                                        onChange={handleInputChange}
                                        required={modalMode === 'create'}
                                        placeholder={modalMode === 'edit' ? "Dejar en blanco para mantener" : ""}
                                    />
                                </div>
                            )}

                            <div>
                                <label style={{color: '#c0a080', fontSize: '0.9rem', textTransform: 'uppercase'}}>Nombre</label>
                                <input required type="text" name="nombre" className="rdr-input" value={formData.nombre} onChange={handleInputChange} />
                            </div>
                            <div>
                                <label style={{color: '#c0a080', fontSize: '0.9rem', textTransform: 'uppercase'}}>Apellido</label>
                                <input required type="text" name="apellido" className="rdr-input" value={formData.apellido} onChange={handleInputChange} />
                            </div>



                            <div>
                                <label style={{color: '#c0a080', fontSize: '0.9rem', textTransform: 'uppercase'}}>Rango de Oficial</label>
                                <select name="rango" className="rdr-input" style={{appearance: 'auto'}} value={formData.rango} onChange={handleInputChange}>
                                    {RANK_ORDER.map(rank => (
                                        <option key={rank} value={rank} style={{background: '#1a0f0a', color: '#d4af37'}}>{rank}</option>
                                    ))}
                                </select>
                            </div>

                            <div>
                                <label style={{color: '#c0a080', fontSize: '0.9rem', textTransform: 'uppercase'}}>Rol del Sistema</label>
                                <select name="rol" className="rdr-input" style={{appearance: 'auto'}} value={formData.rol} onChange={handleInputChange}>
                                    <option value="Externo" style={{background: '#1a0f0a', color: '#d4af37'}}>Externo</option>
                                    <option value="Ayudante BOI" style={{background: '#1a0f0a', color: '#d4af37'}}>Ayudante BOI</option>
                                    <option value="Agente BOI" style={{background: '#1a0f0a', color: '#d4af37'}}>Agente BOI</option>
                                    <option value="Coordinador" style={{background: '#1a0f0a', color: '#d4af37'}}>Coordinador</option>
                                    <option value="Jefatura" style={{background: '#1a0f0a', color: '#d4af37'}}>Jefatura</option>
                                    <option value="Administrador" style={{background: '#1a0f0a', color: '#d4af37'}}>Administrador</option>
                                </select>
                            </div>
                            
                            <div>
                                <label style={{color: '#c0a080', fontSize: '0.9rem', textTransform: 'uppercase'}}>Fecha de Ingreso</label>
                                <input required type="date" name="fecha_ingreso" className="rdr-input" value={formData.fecha_ingreso} onChange={handleInputChange} style={{colorScheme: 'dark'}} />
                            </div>

                            <div style={{ gridColumn: '1 / -1' }}>
                                <label style={{color: '#c0a080', fontSize: '0.9rem', textTransform: 'uppercase', display: 'block', marginBottom: '0.5rem'}}>Fotografía del Agente (Opcional)</label>
                                <label className="rdr-btn-brown" style={{display: 'inline-block', width: '100%', textAlign: 'center'}}>
                                    <input type="file" ref={fileInputRef} accept="image/*" onChange={handleFileChange} style={{display: 'none'}} />
                                    {formData.profile_image ? "IMAGEN DETECTADA (CLICK PARA CAMBIAR)" : "ADJUNTAR FOTOGRAFÍA"}
                                </label>
                            </div>

                            <div style={{ gridColumn: '1 / -1', display: 'flex', gap: '1rem', justifyContent: 'flex-end', marginTop: '1rem' }}>
                                <button type="button" className="rdr-btn-brown" style={{background: 'transparent', borderColor: '#c0a080', color: '#c0a080'}} onClick={() => setShowModal(false)} disabled={processing}>Cancelar</button>
                                <button type="submit" className="rdr-btn-brown" disabled={processing}>
                                    {processing ? 'Sellando...' : (modalMode === 'create' ? 'Registrar Expediente' : 'Actualizar Expediente')}
                                </button>
                            </div>
                        </form>
                    </div>
                </div>
            )}

            {/* Cropper Modal */}
            {editorOpen && createPortal(
                <div className="rdr-modal-overlay" style={{zIndex: 4000}}>
                    <div className="rdr-modal-content">
                        <h3 style={{textAlign: 'center', marginBottom: '1.5rem'}}>RECORTAR FOTOGRAFÍA</h3>
                        <div style={{ display: 'flex', justifyContent: 'center', margin: '2rem 0' }}>
                            <AvatarEditor
                                ref={editorRef}
                                image={imageSrc}
                                width={150}
                                height={150}
                                border={[20, 20]}
                                color={[26, 15, 10, 0.8]} 
                                scale={scale}
                            />
                        </div>
                        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '1.5rem' }}>
                            <div style={{ display: 'flex', alignItems: 'center', gap: '1rem', color: '#d4af37' }}>
                                <span>-</span>
                                <input
                                    type="range" min="1" max="3" step="0.01" value={scale}
                                    style={{accentColor: '#8b5a2b', width: '200px'}}
                                    onChange={(e) => setScale(parseFloat(e.target.value))}
                                />
                                <span>+</span>
                            </div>
                            <div style={{ display: 'flex', gap: '1rem' }}>
                                <button type="button" className="rdr-btn-brown" style={{background: 'transparent', borderColor: '#c0a080', color: '#c0a080'}} onClick={handleCancelCrop}>Cancelar</button>
                                <button type="button" className="rdr-btn-brown" onClick={handleSaveCroppedImage}>Fijar Foto WebP</button>
                            </div>
                        </div>
                    </div>
                </div>,
                document.body
            )}
        </div>
    );
}

export default Personnel;
