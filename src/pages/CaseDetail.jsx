import { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { supabase } from '../supabaseClient';
import './CaseDetailRDR.css';

function CaseDetail() {
    const { id } = useParams();
    const navigate = useNavigate();
    const [caseData, setCaseData] = useState(null);
    const [loading, setLoading] = useState(true);

    // Forum State
    const [newUpdateContent, setNewUpdateContent] = useState('');
    const [newUpdateImages, setNewUpdateImages] = useState([]); // Base64 WebP Strings
    const [submittingUpdate, setSubmittingUpdate] = useState(false);
    const [expandedImage, setExpandedImage] = useState(null);

    // Modal State
    const [detectives, setDetectives] = useState([]);
    const [showAssignModal, setShowAssignModal] = useState(false);
    const [selectedAssignments, setSelectedAssignments] = useState([]);

    // Logic State
    const [currentUser, setCurrentUser] = useState(null);
    const [isEditingInfo, setIsEditingInfo] = useState(false);

    // Temp Form state for editing Case Details
    const [editTitle, setEditTitle] = useState("");
    const [editLocation, setEditLocation] = useState("");
    const [editOccurredAt, setEditOccurredAt] = useState("");
    const [editDescription, setEditDescription] = useState("");

    useEffect(() => {
        loadCaseDetails();
        loadCurrentUser();
    }, [id]);

    const loadCurrentUser = async () => {
        const { data: { user } } = await supabase.auth.getUser();
        if (user) {
            const { data: profile } = await supabase.from('users').select('*').eq('id', user.id).single();
            setCurrentUser(profile);
        }
    };

    const loadCaseDetails = async () => {
        setLoading(true);
        const { data, error } = await supabase.rpc('get_case_details', { p_case_id: id });
        if (error) {
            console.error('Error loading case:', error);
            alert('Error abriendo el archivo del caso.');
        } else {
            setCaseData(data);
            const currentIds = data.assignments ? data.assignments.map(a => a.user_id) : [];
            setSelectedAssignments(currentIds);
        }
        setLoading(false);
    };

    const formatTo1880 = (isoString) => {
        if (!isoString) return '';
        const dateObj = new Date(isoString);
        
        // Formatear día, mes en castellano y forzar 1880
        const day = dateObj.getDate().toString().padStart(2, '0');
        const months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
        const month = months[dateObj.getMonth()];
        const hours = dateObj.getHours().toString().padStart(2, '0');
        const mins = dateObj.getMinutes().toString().padStart(2, '0');
        
        return `${day} ${month}. 1880 - ${hours}:${mins}`;
    };

    const handleImageUpload = (e) => {
        const files = Array.from(e.target.files);
        if (files.length === 0) return;

        files.forEach(file => {
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

                    // Formato ligero para optimizar
                    const dataUrl = canvas.toDataURL('image/webp', 0.6);
                    setNewUpdateImages(prev => [...prev, dataUrl]);
                };
            };
        });
    };

    const handlePostUpdate = async (e) => {
        e.preventDefault();
        if (!newUpdateContent.trim() && newUpdateImages.length === 0) return alert("Escribe testimonio o adjunta prueba fotográfica.");

        setSubmittingUpdate(true);
        try {
            const { error } = await supabase.rpc('add_case_update', {
                p_case_id: id,
                p_content: newUpdateContent,
                p_images: newUpdateImages
            });
            if (error) throw error;

            setNewUpdateContent('');
            setNewUpdateImages([]);
            loadCaseDetails();
        } catch (err) {
            alert('Error grabando informe: ' + err.message);
        } finally {
            setSubmittingUpdate(false);
        }
    };

    const handleDeleteUpdate = async (updateId) => {
        if (!window.confirm("¿Arrancar hoja del informe?")) return;
        try {
            const { error } = await supabase.rpc('delete_case_update', { p_update_id: updateId });
            if (error) throw error;
            loadCaseDetails();
        } catch (err) {
            alert("Error: " + err.message);
        }
    };

    // --- CASE MANAGEMENT (ONLY ADMIN/COORD/JEF) ---
    const handleStatusChange = async (newStatus) => {
        if (!window.confirm(`¿Sellar caso permanentemente como "${newStatus}"?`)) return;
        try {
            const { error } = await supabase.rpc('set_case_status', { p_case_id: id, p_status: newStatus });
            if (error) throw error;
            loadCaseDetails();
        } catch (err) {
            alert('Error de sellado: ' + err.message);
        }
    };

    const handleDeleteCase = async () => {
        if (!window.confirm("🛑 INSTRUCCIÓN CRÍTICA 🛑\n\n¿Estás seguro de que quieres DESTRUIR TODO EL ARCHIVO para siempre?\nEsta información se consumirá en el fuego.")) return;
        try {
            setLoading(true);
            const { data: result, error } = await supabase.rpc('delete_case_fully', { p_case_id: id });
            if (error) throw error;
            navigate('/cases');
        } catch (err) {
            alert('Error eliminando: ' + err.message);
            setLoading(false);
        }
    };

    // -- ASSIGNMENTS --
    const openAssignModal = async () => {
        if (detectives.length === 0) {
            const { data } = await supabase.from('users').select('id, nombre, apellido, rango, profile_image, rol')
                           .in('rol', ['Administrador', 'Coordinador', 'Agente BOI', 'Ayudante BOI']).order('rol');
            setDetectives(data || []);
        }
        if (caseData?.assignments) setSelectedAssignments(caseData.assignments.map(a => a.user_id));
        setShowAssignModal(true);
    };

    const handleUpdateAssignments = async () => {
        try {
            const { error } = await supabase.rpc('update_case_assignments', { p_case_id: id, p_assigned_ids: selectedAssignments });
            if (error) throw error;
            setShowAssignModal(false);
            loadCaseDetails();
        } catch (err) {
            alert('Error asignando placas: ' + err.message);
        }
    };

    const toggleAssignmentSelection = (userId) => {
        if (selectedAssignments.includes(userId)) {
            setSelectedAssignments(prev => prev.filter(uid => uid !== userId));
        } else {
            setSelectedAssignments(prev => [...prev, userId]);
        }
    };

    if (loading) return <div style={{color: '#c0a080', fontFamily: 'Cinzel', textAlign: 'center', marginTop: '3rem'}}>Abriendo caja fuerte...</div>;
    if (!caseData) return <div style={{color: '#8b0000', fontFamily: 'Cinzel', textAlign: 'center', marginTop: '3rem'}}>Documento Expurgado.</div>;

    const { info, assignments, updates } = caseData;
    const canManage = currentUser && ['Administrador', 'Coordinador', 'Jefatura'].includes(currentUser.rol);

    return (
        <div className="rdr-case-detail-container">
            <button onClick={() => navigate('/cases')} style={{ background: 'none', border: 'none', color: '#c0a080', cursor: 'pointer', marginBottom: '1rem', fontFamily: 'Cinzel', fontSize: '1rem' }}>
                ← VOLVER AL ARCHIVO GENERAL
            </button>

            {/* HEADER PAPER CARD */}
            <div className="rdr-detail-header-card">
                <div className={`rdr-case-stamp status-${info.status.toLowerCase()}`}>
                    {info.status}
                </div>

                <div className="rdr-detail-id">EXPEDIENTE #{String(info.case_number).padStart(4, '0')}</div>
                <h1 className="rdr-detail-title">{info.title}</h1>

                <div className="rdr-detail-meta" style={{marginBottom: '2rem'}}>
                    Sucedió en <b>{info.location}</b> | Documentado el <b>{formatTo1880(info.occurred_at)}</b>
                </div>

                <div style={{fontFamily: 'Playfair Display', fontSize: '1.1rem', color: '#2c1e16', padding: '1rem', background: 'rgba(255,255,255,0.2)', border: '1px dashed #8b5a2b', borderRadius: '2px'}}>
                    <h3 style={{fontFamily: 'Cinzel', marginTop: 0, borderBottom: '1px solid', paddingBottom: '5px'}}>DESCRIPCIÓN INICIAL DE LOS HECHOS</h3>
                    <p style={{whiteSpace: 'pre-line', margin: 0}}>{info.description}</p>
                    
                    {info.initial_image_url && (
                        <div style={{marginTop: '15px'}} onClick={() => setExpandedImage(info.initial_image_url)}>
                            <img src={info.initial_image_url} alt="Prueba Inicial" style={{maxWidth: '300px', border: '4px solid #1a0f0a', cursor: 'zoom-in', borderRadius: '2px'}}/>
                        </div>
                    )}
                </div>
            </div>

            <div className="rdr-layout-grid">
                
                {/* FORUM FEED */}
                <div>
                    <h2 style={{fontFamily: 'Cinzel', color: '#d4af37', borderBottom: '1px solid', paddingBottom: '10px', marginBottom: '1.5rem'}}>
                        VACIADO DE INFORMACIÓN (AVANCES)
                    </h2>

                    {info.status === 'Abierto' && (
                        <form className="rdr-create-update-box" onSubmit={handlePostUpdate}>
                            <textarea
                                className="rdr-input"
                                rows="3"
                                placeholder="Escribe el testimonio, reporte o conclusión..."
                                value={newUpdateContent}
                                onChange={e => setNewUpdateContent(e.target.value)}
                                style={{ marginBottom: '1rem' }}
                            />

                            {newUpdateImages.length > 0 && (
                                <div style={{ display: 'flex', gap: '10px', flexWrap: 'wrap', margin: '1rem 0' }}>
                                    {newUpdateImages.map((imgSrc, idx) => (
                                        <div key={idx} style={{ position: 'relative' }}>
                                            <img src={imgSrc} alt="" style={{ height: '80px', borderRadius: '2px', border: '2px solid #8b5a2b' }} />
                                            <button type="button" onClick={() => setNewUpdateImages(prev => prev.filter((_, i) => i !== idx))} style={{ position: 'absolute', top: -10, right: -10, background: '#8b0000', color: 'white', border: 'none', cursor: 'pointer', padding: '5px' }}>X</button>
                                        </div>
                                    ))}
                                </div>
                            )}

                            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                                <label className="rdr-btn-brown" style={{margin: 0, padding: '0.5rem 1rem', background: 'transparent', borderColor: '#d4af37', color: '#d4af37', cursor: 'pointer'}}>
                                    <input type="file" accept="image/*" multiple onChange={handleImageUpload} style={{display:'none'}} />
                                    + AÑADIR PRUEBAS GRÁFICAS
                                </label>
                                <button type="submit" className="rdr-btn-brown" style={{margin: 0, padding: '0.5rem 2rem'}} disabled={submittingUpdate}>
                                    {submittingUpdate ? 'SELLANDO...' : 'REGISTRAR APUNTE'}
                                </button>
                            </div>
                        </form>
                    )}

                    <div className="rdr-forum-list">
                        {updates.length === 0 ? <p style={{color: '#8b5a2b', fontStyle: 'italic'}}>Nadie ha escrito notas al respecto.</p> : [...updates].sort((a, b) => new Date(b.created_at) - new Date(a.created_at)).map(update => (
                            <div key={update.id} className="rdr-forum-post">
                                <div className="rdr-forum-author-box">
                                    <img src={update.author_avatar || '/anon.png'} alt="" className="rdr-forum-avatar" />
                                    <div style={{flex: 1}}>
                                        <div className="rdr-forum-name">{update.author_rank} {update.author_name}</div>
                                        <div className="rdr-forum-date">Registrado el {formatTo1880(update.created_at)}</div>
                                    </div>
                                    
                                    {(currentUser?.id === update.user_id || canManage) && (
                                        <button onClick={() => handleDeleteUpdate(update.id)} style={{background: 'none', border: 'none', color: '#8b0000', cursor: 'pointer', fontWeight: 'bold'}}>
                                            [Quemar Hoja]
                                        </button>
                                    )}
                                </div>

                                <div className="rdr-forum-text">{update.content}</div>

                                {update.images && update.images.length > 0 && (
                                    <div className="rdr-forum-images-grid">
                                        {update.images.map((img, i) => (
                                            <img key={i} src={img} alt="" onClick={() => setExpandedImage(img)}/>
                                        ))}
                                    </div>
                                )}
                            </div>
                        ))}
                    </div>
                </div>

                {/* SIDEBAR */}
                <div>
                    <div className="rdr-sidebar-box">
                        <div className="rdr-sidebar-title">
                            INVESTIGADORES
                            {canManage && info.status === 'Abierto' && (
                                <button className="rdr-btn-brown" style={{padding: '3px 10px', fontSize: '0.7rem', margin: 0}} onClick={openAssignModal}>
                                    ASIGNAR
                                </button>
                            )}
                        </div>
                        
                        {assignments.length === 0 ? <div style={{color: '#c0a080', fontStyle: 'italic', fontSize: '0.9rem'}}>Desierto (Agentes sin asignar).</div> : assignments.map(u => (
                            <div key={u.user_id} style={{display: 'flex', alignItems: 'center', marginBottom: '15px'}}>
                                <img src={u.avatar || '/anon.png'} alt="" style={{width: '35px', height: '35px', borderRadius: '50%', border: '2px solid #8b5a2b', marginRight: '10px', objectFit: 'cover'}}/>
                                <div>
                                    <div style={{color: '#e4d5b7', fontFamily: 'Cinzel', fontSize: '0.85rem', fontWeight: 'bold'}}>{u.rank}</div>
                                    <div style={{color: '#c0a080', fontFamily: 'Playfair Display', fontSize: '0.9rem'}}>{u.full_name}</div>
                                </div>
                            </div>
                        ))}
                    </div>

                    {canManage && (
                        <div className="rdr-sidebar-box" style={{borderColor: '#8b0000'}}>
                            <div className="rdr-sidebar-title" style={{color: '#8b0000', borderBottomColor: '#8b0000'}}>
                                PROTOCOLOS ALTA ESTRUCTURA
                            </div>
                            
                            {info.status === 'Abierto' ? (
                                <>
                                    <button className="rdr-btn-brown" style={{width: '100%', marginBottom: '10px'}} onClick={() => handleStatusChange('Cerrado')}>
                                        DECLARAR CASO CERRADO
                                    </button>
                                    <button className="rdr-btn-brown" style={{width: '100%', background: 'transparent', borderColor: '#4a3321', color: '#c0a080'}} onClick={() => handleStatusChange('Archivado')}>
                                        ARCHIVAR CASO Y ABANDONAR
                                    </button>
                                </>
                            ) : (
                                <button className="rdr-btn-brown" style={{width: '100%', marginBottom: '10px'}} onClick={() => handleStatusChange('Abierto')}>
                                    REAPERTURA DEL CASO
                                </button>
                            )}

                            <button className="rdr-btn-brown" style={{width: '100%', marginTop: '30px', background: '#8b0000', color: '#fff', borderColor: '#8b0000'}} onClick={handleDeleteCase}>
                                QUEMAR REGISTROS (BORRAR CASO)
                            </button>
                        </div>
                    )}
                </div>
            </div>

            {/* ASSIGN MODAL */}
            {showAssignModal && (
                <div className="rdr-modal-overlay">
                    <div className="rdr-modal-content" style={{maxWidth: '450px'}}>
                        <h2 style={{fontFamily: 'Cinzel', textAlign: 'center', marginBottom: '1.5rem'}}>REASIGNACIÓN DE AGENTES</h2>
                        
                        <div className="rdr-cases-form-scroll" style={{maxHeight:'300px', marginBottom: '1.5rem', border: '1px solid #8b5a2b', background: 'rgba(26,15,10,0.5)'}}>
                            {detectives.map(u => (
                                <div key={u.id} className={`rdr-assign-row ${selectedAssignments.includes(u.id) ? 'selected' : ''}`} onClick={() => toggleAssignmentSelection(u.id)}>
                                    <input type="checkbox" checked={selectedAssignments.includes(u.id)} readOnly style={{marginRight: '15px'}}/>
                                    <img src={u.profile_image || '/anon.png'} alt="" style={{width: '30px', height: '30px', borderRadius: '50%', border:'1px solid #d4af37', marginRight: '10px'}}/>
                                    <span style={{fontFamily: 'Cinzel', fontSize: '0.85rem', marginRight: '5px', fontWeight: 'bold'}}>{u.rango}</span>
                                    <span style={{fontFamily: 'Playfair Display', fontSize: '0.95rem'}}>{u.nombre} {u.apellido}</span>
                                </div>
                            ))}
                        </div>

                        <div style={{display: 'flex', gap: '10px', justifyContent: 'center'}}>
                            <button className="rdr-btn-brown" style={{background: 'transparent', borderColor: '#c0a080', color: '#c0a080'}} onClick={() => setShowAssignModal(false)}>CANCELAR</button>
                            <button className="rdr-btn-brown" onClick={handleUpdateAssignments}>GUARDAR ASIGNACIONES</button>
                        </div>
                    </div>
                </div>
            )}

            {/* EXPAND IMAGE MODAL */}
            {expandedImage && (
                <div style={{position: 'fixed', top: 0, left: 0, width: '100%', height: '100%', backgroundColor: 'rgba(0,0,0,0.9)', zIndex: 9999, display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'zoom-out'}} onClick={() => setExpandedImage(null)}>
                    <img src={expandedImage} alt="Expanded Photo" style={{maxWidth: '90vw', maxHeight: '90vh', border: '5px solid #1a0f0a', borderRadius: '2px', boxShadow: '0 0 20px #000'}}/>
                    <div style={{position: 'absolute', top: '20px', right: '40px', color: '#d4af37', fontSize: '3rem', fontWeight: 'bold'}}>×</div>
                </div>
            )}
        </div>
    );
}

export default CaseDetail;
