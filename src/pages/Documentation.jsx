import { useState, useEffect } from 'react';
import { supabase } from '../supabaseClient';
import '../index.css';
import './DashboardRDR.css'; // Mantenemos para botones modales globales
import './DocumentationRDR.css';

function Documentation() {
    const [posts, setPosts] = useState([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);
    const [userRole, setUserRole] = useState(null);

    // Modal State
    const [showModal, setShowModal] = useState(false);
    const [modalMode, setModalMode] = useState('create');
    const [editingId, setEditingId] = useState(null);
    const [targetCategory, setTargetCategory] = useState('documentation');
    const [inputType, setInputType] = useState('url'); // 'url' or 'file'
    const [formData, setFormData] = useState({ title: '', description: '', url: '' });
    const [submitLoading, setSubmitLoading] = useState(false);

    useEffect(() => {
        loadData();
    }, []);

    const loadData = async () => {
        try {
            setLoading(true);

            // 1. Get User Role
            const { data: { user } } = await supabase.auth.getUser();
            if (user) {
                const { data: profile } = await supabase
                    .from('users')
                    .select('rol')
                    .eq('id', user.id)
                    .single();
                if (profile) setUserRole(profile.rol);
            }

            // 2. Fetch Documentation
            const { data, error } = await supabase
                .from('documentation_posts')
                .select('*')
                .order('created_at', { ascending: false });

            if (error) throw error;
            setPosts(data || []);

        } catch (err) {
            console.error('Error loading documentation:', err);
            setError(err.message);
        } finally {
            setLoading(false);
        }
    };

    const handleAction = async (e) => {
        e.preventDefault();
        setSubmitLoading(true);

        try {
            const { error } = await supabase.rpc('manage_documentation', {
                p_action: modalMode,
                p_id: editingId,
                p_title: formData.title,
                p_description: formData.description,
                p_url: formData.url,
                p_category: targetCategory
            });

            if (error) throw error;

            setShowModal(false);
            loadData(); // Refresh

        } catch (err) {
            alert('Error: ' + err.message);
        } finally {
            setSubmitLoading(false);
        }
    };

    const handleDelete = async (id) => {
        if (!window.confirm("¿Estás seguro de que quieres destruir este archivo?")) return;
        try {
            const { error } = await supabase.rpc('manage_documentation', {
                p_action: 'delete',
                p_id: id
            });
            if (error) throw error;
            loadData();
        } catch (err) {
            alert('Error deleting: ' + err.message);
        }
    };

    const handleFileChange = (e) => {
        const file = e.target.files[0];
        if (file) {
            if (file.size > 10 * 1024 * 1024) {
                alert("El archivo es demasiado extenso (Máx 10MB original).");
                return;
            }

            const reader = new FileReader();
            reader.onload = (event) => {
                const img = new Image();
                img.onload = () => {
                    const canvas = document.createElement('canvas');
                    let width = img.width;
                    let height = img.height;

                    // Optimización extrema para Base de Datos
                    const MAX_WIDTH = 800; 
                    if (width > MAX_WIDTH) {
                        height = Math.round(height * (MAX_WIDTH / width));
                        width = MAX_WIDTH;
                    }

                    canvas.width = width;
                    canvas.height = height;
                    const ctx = canvas.getContext('2d');
                    ctx.drawImage(img, 0, 0, width, height);

                    // Uso de WEBP para máxima compresión en Base64
                    const dataUrl = canvas.toDataURL('image/webp', 0.6);
                    setFormData({ ...formData, url: dataUrl });
                };
                img.src = event.target.result;
            };
            reader.readAsDataURL(file);
        }
    };

    const openCreate = (category) => {
        setModalMode('create');
        setTargetCategory(category);
        setInputType('url');
        setFormData({ title: '', description: '', url: '' });
        setShowModal(true);
    };

    const openEdit = (post) => {
        setModalMode('update');
        setEditingId(post.id);
        setTargetCategory(post.category || 'documentation');

        const isDataUrl = post.url && post.url.startsWith('data:');
        setInputType(isDataUrl ? 'file' : 'url');

        setFormData({ title: post.title, description: post.description || '', url: post.url });
        setShowModal(true);
    };

    const canManage = ['Coordinador', 'Administrador'].includes(userRole);

    // Image Modal State
    const [viewImage, setViewImage] = useState(null);

    // Filter Posts
    const docs = posts.filter(p => !p.category || p.category === 'documentation');
    const resources = posts.filter(p => p.category === 'resource');

    const handleCardClick = (e, post) => {
        const isImage = post.url && post.url.startsWith('data:image');
        if (isImage) {
            e.preventDefault();
            setViewImage(post.url);
        }
    };

    const renderGrid = (items, emptyMsg) => (
        <div className="rdr-doc-grid">
            {items.length === 0 ? (
                <div style={{ gridColumn: '1/-1', textAlign: 'center', color: '#c0a080', fontSize: '1.2rem', padding: '2rem' }}>
                    {emptyMsg}
                </div>
            ) : (
                items.map(post => {
                    const isImage = post.url && post.url.startsWith('data:image');
                    return (
                        <div key={post.id} className="rdr-doc-card" onClick={(e) => handleCardClick(e, post)}>
                            {canManage && (
                                <div className="rdr-doc-actions">
                                    <button onClick={(e) => { e.stopPropagation(); openEdit(post); }} title="Editar Archivo">✏️</button>
                                    <button onClick={(e) => { e.stopPropagation(); handleDelete(post.id); }} title="Destruir Archivo">🗑️</button>
                                </div>
                            )}
                            <a
                                href={post.url}
                                target={isImage ? undefined : "_blank"}
                                rel={isImage ? undefined : "noopener noreferrer"}
                                className="rdr-doc-link-wrapper"
                                onClick={(e) => isImage && e.preventDefault()}
                            >
                                <div className="rdr-doc-icon" style={isImage ? { padding: 0, overflow: 'hidden', background: 'transparent', border: 'none' } : {}}>
                                    {isImage ? (
                                        <img src={post.url} alt="Resource" style={{ width: '100%', height: '140px', objectFit: 'cover', borderRadius: '2px', border: '1px solid #1a0f0a' }} />
                                    ) : (
                                        post.category === 'resource' ? '📜' : '📓'
                                    )}
                                </div>
                                <h3 className="rdr-doc-title">{post.title}</h3>
                                {post.description && <p className="rdr-doc-desc">{post.description}</p>}
                                <span className="rdr-doc-hint">{isImage ? 'Investigar Imagen' : 'Desglosar Archivo'}</span>
                            </a>
                        </div>
                    );
                })
            )}
        </div>
    );

    return (
        <div className="rdr-doc-container">
            {loading ? (
                <div style={{textAlign: 'center', marginTop: '5rem', color: '#c0a080'}}>Buscando en los polvorientos archivos...</div>
            ) : (
                <>
                    {/* Documentation Section */}
                    <div style={{marginBottom: '5rem'}}>
                        <div className="rdr-doc-section-header">
                            <h2 className="rdr-board-title" style={{fontSize: '2rem', margin: 0}}>ARCHIVOS DEL BUREAU</h2>
                            {canManage && (
                                <button className="rdr-btn-brown" onClick={() => openCreate('documentation')}>
                                    + ARCHIVAR DOCUMENTO
                                </button>
                            )}
                        </div>
                        {renderGrid(docs, "Los archivos del bureau están misteriosamente vacíos.")}
                    </div>

                    {/* Resources Section */}
                    <div style={{marginBottom: '3rem'}}>
                        <div className="rdr-doc-section-header">
                            <h2 className="rdr-board-title" style={{fontSize: '2rem', margin: 0}}>RECURSOS DE CAMPO</h2>
                            {canManage && (
                                <button className="rdr-btn-brown" onClick={() => openCreate('resource')}>
                                    + AÑADIR RECURSO
                                </button>
                            )}
                        </div>
                        {renderGrid(resources, "Ningún recurso incautado fue archivado.")}
                    </div>
                </>
            )}

            {/* Image Viewer Modal */}
            {viewImage && (
                <div
                    className="rdr-modal-overlay"
                    onClick={() => setViewImage(null)}
                    style={{ zIndex: 3000, cursor: 'zoom-out' }}
                >
                    <div
                        style={{ position: 'relative', maxWidth: '90vw', maxHeight: '90vh' }}
                        onClick={(e) => e.stopPropagation()}
                    >
                        <img
                            src={viewImage}
                            alt="Full View"
                            style={{
                                maxWidth: '100%',
                                maxHeight: '90vh',
                                objectFit: 'contain',
                                borderRadius: '4px',
                                boxShadow: '0 0 50px rgba(0,0,0,0.9)',
                                border: '2px solid #3b2b1d',
                                cursor: 'default'
                            }}
                        />
                        <button
                            className="rdr-btn-brown"
                            style={{
                                position: 'absolute',
                                top: '-50px',
                                right: '0',
                                padding: '0.5rem 1rem'
                            }}
                            onClick={() => setViewImage(null)}
                        >
                            Cerrar Archivo ✕
                        </button>
                    </div>
                </div>
            )}

            {/* Create / Edit Modal */}
            {showModal && (
                <div className="rdr-modal-overlay">
                    <div className="rdr-modal-content">
                        <h3>{modalMode === 'create' ? `REGISTRAR NUEVO ${targetCategory === 'resource' ? 'RECURSO' : 'DOCUMENTO'}` : 'EDITAR ARCHIVO OFICIAL'}</h3>
                        <form onSubmit={handleAction} style={{ textAlign: 'left', marginTop: '1rem' }}>

                            {/* Toggle for Resources Only */}
                            {targetCategory === 'resource' && (
                                <div style={{ display: 'flex', gap: '1rem', marginBottom: '1.5rem', borderBottom: '1px solid rgba(212, 175, 55, 0.3)', paddingBottom: '1rem' }}>
                                    <button
                                        type="button"
                                        className="rdr-btn-brown"
                                        style={inputType === 'url' ? {borderColor: '#d4af37', boxShadow: 'inset 0 0 10px rgba(212,175,55,0.2)'} : {opacity: 0.6}}
                                        onClick={() => setInputType('url')}
                                    >
                                        Enlace Externo
                                    </button>
                                    <button
                                        type="button"
                                        className="rdr-btn-brown"
                                        style={inputType === 'file' ? {borderColor: '#d4af37', boxShadow: 'inset 0 0 10px rgba(212,175,55,0.2)'} : {opacity: 0.6}}
                                        onClick={() => setInputType('file')}
                                    >
                                        Incrustar Imagen
                                    </button>
                                </div>
                            )}

                            <div>
                                <label style={{color: '#c0a080', fontSize: '0.9rem', textTransform: 'uppercase'}}>Título del Archivo</label>
                                <input className="rdr-input" required value={formData.title} onChange={e => setFormData({ ...formData, title: e.target.value })} />
                            </div>
                            
                            <div>
                                <label style={{color: '#c0a080', fontSize: '0.9rem', textTransform: 'uppercase'}}>Descripción (Opcional)</label>
                                <textarea className="rdr-input" rows="3" value={formData.description} onChange={e => setFormData({ ...formData, description: e.target.value })} style={{resize: 'vertical'}} />
                            </div>

                            <div>
                                <label style={{color: '#c0a080', fontSize: '0.9rem', textTransform: 'uppercase'}}>{inputType === 'file' ? 'Fotografía/Boceto' : 'Enlace / URL Externa'}</label>
                                {inputType === 'file' ? (
                                    <>
                                        <label className="rdr-btn-brown" style={{display: 'inline-block', width: '100%', textAlign: 'center', boxSizing: 'border-box', marginTop: '0.5rem', marginBottom: '1.5rem'}}>
                                            <input type="file" accept="image/*" onChange={handleFileChange} style={{display: 'none'}} />
                                            {formData.url && formData.url.startsWith('data:') ? 'CAMBIAR FOTOGRAFÍA' : 'ADJUNTAR FOTOGRAFÍA'}
                                        </label>
                                        {formData.url && formData.url.startsWith('data:') && (
                                            <div style={{ marginTop: '-1rem', marginBottom: '1.5rem', fontSize: '0.8rem', color: '#d4af37', textAlign: 'center' }}>
                                                ✓ FOTOGRAFÍA INCORPORADA AL EXPEDIENTE
                                            </div>
                                        )}
                                    </>
                                ) : (
                                    <input
                                        className="rdr-input"
                                        required={inputType === 'url'}
                                        type="url"
                                        placeholder="https://..."
                                        value={formData.url.startsWith('data:') ? '' : formData.url}
                                        onChange={e => setFormData({ ...formData, url: e.target.value })}
                                    />
                                )}
                            </div>

                            <div style={{ display: 'flex', gap: '1rem', justifyContent: 'flex-end', marginTop: '1rem' }}>
                                <button type="button" className="rdr-btn-brown" onClick={() => setShowModal(false)} style={{background: 'transparent', color: '#c0a080', borderColor: '#c0a080'}}>Cancelar</button>
                                <button type="submit" className="rdr-btn-brown" disabled={submitLoading}>{submitLoading ? 'Sellando...' : 'Sellar Archivo'}</button>
                            </div>
                        </form>
                    </div>
                </div>
            )}
        </div>
    );
}

export default Documentation;
