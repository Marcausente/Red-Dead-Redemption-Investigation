import { useState, useEffect, useRef } from 'react';
import { supabase } from '../supabaseClient';
import './GangsRDR.css';

function Gangs() {
    const [groups, setGroups] = useState([]);
    const [loading, setLoading] = useState(true);
    const [currentUser, setCurrentUser] = useState(null);
    const [viewMode, setViewMode] = useState('active'); // 'active' | 'archived'

    // Modal states
    const [activeModal, setActiveModal] = useState(null);
    const [activeGroupId, setActiveGroupId] = useState(null);
    const [editingItemId, setEditingItemId] = useState(null);
    const [submitting, setSubmitting] = useState(false);
    const [expandedImage, setExpandedImage] = useState(null);
    
    // Drag to scroll
    const boardRef = useRef(null);
    const [isDragging, setIsDragging] = useState(false);
    const [startX, setStartX] = useState(0);
    const [scrollLeft, setScrollLeft] = useState(0);

    // Form fields
    const [groupName, setGroupName] = useState('');
    const [groupColor, setGroupColor] = useState('#8b0000');
    const [groupImage, setGroupImage] = useState(null);
    
    const [charContent, setCharContent] = useState('');
    
    const [campMapPhoto, setCampMapPhoto] = useState(null);
    const [campPhoto, setCampPhoto] = useState(null);
    const [campStatus, setCampStatus] = useState('Activo');
    const [campNotes, setCampNotes] = useState('');
    
    const [memName, setMemName] = useState('');
    const [memAlias, setMemAlias] = useState('');
    const [memRole, setMemRole] = useState('Sospechoso');
    const [memNotes, setMemNotes] = useState('');
    const [memPhoto, setMemPhoto] = useState(null);

    useEffect(() => {
        loadCurrentUser();
        loadGroups();
    }, []);

    const loadCurrentUser = async () => {
        const { data: { user } } = await supabase.auth.getUser();
        if (user) {
            const { data } = await supabase.from('users').select('rol').eq('id', user.id).single();
            setCurrentUser(data);
        }
    };

    const loadGroups = async () => {
        setLoading(true);
        const { data, error } = await supabase.rpc('get_groups_data');
        if (error) {
            console.error(error);
            alert('Error cargando el archivo de bandas.');
        } else {
            setGroups(data || []);
        }
        setLoading(false);
    };

    const handleImageUpload = (e, fileSetter) => {
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
                fileSetter(canvas.toDataURL('image/webp', 0.6));
            };
        };
    };

    const closeModal = () => {
        setActiveModal(null);
        setActiveGroupId(null);
        setEditingItemId(null);
        // Clean forms
        setGroupName(''); setGroupColor('#8b0000'); setGroupImage(null);
        setCharContent('');
        setCampMapPhoto(null); setCampPhoto(null); setCampStatus('Activo'); setCampNotes('');
        setMemName(''); setMemAlias(''); setMemRole('Sospechoso'); setMemNotes(''); setMemPhoto(null);
    };

    const handleEditItem = (type, groupId, item) => {
        setActiveGroupId(groupId);
        setEditingItemId(item.id);
        setActiveModal(type);
        if (type === 'createGroup') {
            setGroupName(item.name);
            setGroupColor(item.color);
            setGroupImage(item.influence_zone_image);
        } else if (type === 'addChar') {
            setCharContent(item.content);
        } else if (type === 'addCamp') {
            setCampMapPhoto(item.map_photo);
            setCampPhoto(item.camp_photo);
            setCampStatus(item.status);
            setCampNotes(item.notes);
        } else if (type === 'addMember') {
            setMemName(item.name);
            setMemAlias(item.alias || '');
            setMemRole(item.role);
            setMemNotes(item.notes || '');
            setMemPhoto(item.photo);
        }
    };

    const handleDeleteItem = async (table, id) => {
        if (!window.confirm("¿Seguro que quieres arrancar este registro del informe?")) return;
        try {
            await supabase.rpc('delete_group_item', { p_table: table, p_id: id });
            loadGroups();
        } catch (err) { alert(err.message); }
    };

    // Submits
    const handleCreateGroup = async (e) => {
        e.preventDefault();
        setSubmitting(true);
        try {
            if (editingItemId) {
                await supabase.rpc('update_criminal_group', { p_group_id: editingItemId, p_name: groupName, p_color: groupColor, p_image: groupImage });
            } else {
                await supabase.rpc('create_criminal_group', { p_name: groupName, p_color: groupColor, p_image: groupImage });
            }
            closeModal();
            loadGroups();
        } catch (err) { alert(err.message); } finally { setSubmitting(false); }
    };

    const handleAddCharacteristic = async (e) => {
        e.preventDefault();
        setSubmitting(true);
        try {
            if (editingItemId) {
                await supabase.rpc('update_group_characteristic', { p_id: editingItemId, p_content: charContent });
            } else {
                await supabase.rpc('add_group_characteristic', { p_group_id: activeGroupId, p_content: charContent });
            }
            closeModal();
            loadGroups();
        } catch (err) { alert(err.message); } finally { setSubmitting(false); }
    };

    const handleAddCamp = async (e) => {
        e.preventDefault();
        setSubmitting(true);
        try {
            if (editingItemId) {
                await supabase.rpc('update_group_camp', { p_id: editingItemId, p_map_photo: campMapPhoto, p_camp_photo: campPhoto, p_status: campStatus, p_notes: campNotes });
            } else {
                await supabase.rpc('add_group_camp', { p_group_id: activeGroupId, p_map_photo: campMapPhoto, p_camp_photo: campPhoto, p_status: campStatus, p_notes: campNotes });
            }
            closeModal();
            loadGroups();
        } catch (err) { alert(err.message); } finally { setSubmitting(false); }
    };

    const handleAddMember = async (e) => {
        e.preventDefault();
        setSubmitting(true);
        try {
            if (editingItemId) {
                await supabase.rpc('update_group_member', { p_id: editingItemId, p_name: memName, p_alias: memAlias, p_role: memRole, p_notes: memNotes, p_photo: memPhoto });
            } else {
                await supabase.rpc('add_group_member', { p_group_id: activeGroupId, p_name: memName, p_alias: memAlias, p_role: memRole, p_notes: memNotes, p_photo: memPhoto });
            }
            closeModal();
            loadGroups();
        } catch (err) { alert(err.message); } finally { setSubmitting(false); }
    };

    const handleToggleArchive = async (id, currentStatus) => {
        if (!window.confirm(currentStatus ? "¿Reabrir investigación y transferir a Operativos Activos?" : "¿Sellar y trasladar a los Archivos Muertos de la agencia?")) return;
        try {
            await supabase.rpc('toggle_group_archive', { p_group_id: id, p_archive: !currentStatus });
            loadGroups();
        } catch (err) { alert(err.message); }
    };

    const handleDeleteGroup = async (id) => {
        if (!window.confirm("🛑 ADVERTENCIA DE JEFATURA: Vas a expurgar y quemar la columna entera de esta banda, borrando todos sus sujetos, fotos y mapas permanentemente. ¿Estás absolutamente seguro?")) return;
        try {
            await supabase.rpc('delete_criminal_group_fully', { p_group_id: id });
            loadGroups();
        } catch (err) { alert(err.message); }
    };

    // --- Drag to Scroll Handlers ---
    const handleMouseDown = (e) => {
        if (!boardRef.current) return;
        setIsDragging(true);
        setStartX(e.pageX - boardRef.current.offsetLeft);
        setScrollLeft(boardRef.current.scrollLeft);
        boardRef.current.style.cursor = 'grabbing';
    };

    const handleMouseLeave = () => {
        setIsDragging(false);
        if (boardRef.current) boardRef.current.style.cursor = 'grab';
    };

    const handleMouseUp = () => {
        setIsDragging(false);
        if (boardRef.current) boardRef.current.style.cursor = 'grab';
    };

    const handleMouseMove = (e) => {
        if (!isDragging) return;
        e.preventDefault();
        const x = e.pageX - boardRef.current.offsetLeft;
        const walk = (x - startX) * 2; 
        boardRef.current.scrollLeft = scrollLeft - walk;
    };

    const canManageAll = currentUser && ['Administrador', 'Coordinador', 'Jefatura'].includes(currentUser.rol);
    const canManageBasics = canManageAll; // Expandible a Agentes si es necesario, pero actualmente restringimos a High Command

    const filteredGroups = groups.filter(g => viewMode === 'active' ? !g.is_archived : g.is_archived);

    return (
        <div className="rdr-trello-container">
            <div className="rdr-trello-header">
                <div style={{display: 'flex', flexDirection: 'column'}}>
                    <h2 className="rdr-trello-title">ORGANIZACIONES CRIMINALES</h2>
                    <div style={{display: 'flex', gap: '15px', marginTop: '15px'}}>
                        <button className="rdr-btn-brown" style={{margin: 0, padding: '5px 15px', opacity: viewMode === 'active' ? 1 : 0.5}} onClick={() => setViewMode('active')}>
                            OPERATIVOS ACTIVOS
                        </button>
                        <button className="rdr-btn-brown" style={{margin: 0, padding: '5px 15px', opacity: viewMode === 'archived' ? 1 : 0.5}} onClick={() => setViewMode('archived')}>
                            ARCHIVOS MUERTOS
                        </button>
                    </div>
                </div>
                {canManageAll && viewMode === 'active' && (
                    <button className="rdr-btn-brown" style={{margin: 0}} onClick={() => setActiveModal('createGroup')}>
                        + RASTREAR NUEVA BANDA
                    </button>
                )}
            </div>

            {loading ? <div style={{color: '#c0a080', fontFamily: 'Cinzel', textAlign: 'center', marginTop: '3rem'}}>Desplegando la mesa de mapas...</div> : (
                <div 
                    className="rdr-trello-board"
                    ref={boardRef}
                    onMouseDown={handleMouseDown}
                    onMouseLeave={handleMouseLeave}
                    onMouseUp={handleMouseUp}
                    onMouseMove={handleMouseMove}
                    style={{ cursor: 'grab', userSelect: isDragging ? 'none' : 'auto' }}
                >
                    {filteredGroups.length === 0 ? <p style={{color: '#c0a080', fontStyle: 'italic', margin: 'auto'}}>No hay expedientes en esta bandeja.</p> : filteredGroups.map(g => (
                        <div key={g.id} className="rdr-trello-column">
                            <div className="rdr-col-color-bar" style={{backgroundColor: g.color}}></div>
                            
                            <div className="rdr-col-head">
                                <div style={{display: 'flex', justifyContent: 'center', alignItems: 'center', gap: '10px', marginBottom: '1rem'}}>
                                    <h3 className="rdr-col-name" style={{margin: 0}}>{g.name}</h3>
                                    {canManageAll && <span style={{cursor:'pointer', fontSize:'1rem'}} onClick={() => handleEditItem('createGroup', g.id, g)} title="Editar datos de Banda">✏️</span>}
                                </div>
                                {g.influence_zone_image ? (
                                    <div style={{position: 'relative'}}>
                                        <div style={{position: 'absolute', top: 5, left: 5, background: 'rgba(0,0,0,0.7)', color: '#d4af37', padding: '2px 5px', fontSize: '0.7rem', fontFamily: 'Cinzel', border: '1px solid #d4af37'}}>ZONA DE INFLUENCIA</div>
                                        <img src={g.influence_zone_image} className="rdr-col-zone-img" alt="Zona" onClick={() => setExpandedImage(g.influence_zone_image)}/>
                                    </div>
                                ) : (
                                    <div className="rdr-col-zone-img" style={{display: 'flex', alignItems: 'center', justifyContent: 'center', backgroundColor: '#d4c5a7', color: '#8b5a2b', fontStyle: 'italic'}}>Sin Mapa Asignado</div>
                                )}
                            </div>

                            <div className="rdr-col-stats">
                                <div>Incidentes: <span style={{color: '#8b0000'}}>0</span></div>
                                <div>Salidas: <span style={{color: '#2e4a2e'}}>0</span></div>
                            </div>

                            <div className="rdr-col-body">
                                {/* Características */}
                                <div className="rdr-section-title">
                                    CARACTERÍSTICAS
                                    {canManageBasics && <button onClick={() => {setActiveGroupId(g.id); setActiveModal('addChar');}} style={{float:'right', background:'none', border:'none', color:'#8b0000', cursor:'pointer'}}>+</button>}
                                </div>
                                {g.characteristics.length === 0 ? <div style={{fontSize:'0.85rem', color:'#8b5a2b', fontStyle:'italic'}}>Faltan datos...</div> : g.characteristics.map(c => (
                                    <div key={c.id} className="rdr-trello-card" style={{borderLeftColor: g.color}}>
                                        {canManageBasics && (
                                            <div style={{position: 'absolute', right: '5px', top: '5px', display: 'flex', gap: '10px'}}>
                                                <span style={{cursor:'pointer', fontSize:'0.8rem'}} onClick={() => handleEditItem('addChar', g.id, c)}>✏️</span>
                                                <span style={{cursor:'pointer', fontSize:'0.8rem'}} onClick={() => handleDeleteItem('group_characteristics', c.id)}>🗑️</span>
                                            </div>
                                        )}
                                        <div className="rdr-card-text" style={{marginTop:'5px'}}>• {c.content}</div>
                                    </div>
                                ))}

                                {/* Campamentos */}
                                <div className="rdr-section-title">
                                    CAMPAMENTOS & ESCONDITES
                                    {canManageBasics && <button onClick={() => {setActiveGroupId(g.id); setActiveModal('addCamp');}} style={{float:'right', background:'none', border:'none', color:'#8b0000', cursor:'pointer'}}>+</button>}
                                </div>
                                {g.camps.length === 0 ? <div style={{fontSize:'0.85rem', color:'#8b5a2b', fontStyle:'italic'}}>Desconocidos...</div> : g.camps.map(c => (
                                    <div key={c.id} className="rdr-trello-card" style={{borderLeftColor: g.color}}>
                                        {canManageBasics && (
                                            <div style={{position: 'absolute', right: '5px', top: '5px', display: 'flex', gap: '10px'}}>
                                                <span style={{cursor:'pointer', fontSize:'0.8rem'}} onClick={() => handleEditItem('addCamp', g.id, c)}>✏️</span>
                                                <span style={{cursor:'pointer', fontSize:'0.8rem'}} onClick={() => handleDeleteItem('group_camps', c.id)}>🗑️</span>
                                            </div>
                                        )}
                                        <div style={{display: 'flex', justifyContent: 'flex-start', marginBottom: '8px'}}>
                                            <span className={`status-${c.status.toLowerCase()}`}>{c.status}</span>
                                        </div>
                                        <div className="rdr-card-text">{c.notes}</div>
                                        <div className="rdr-camp-imgs">
                                            {c.map_photo && <img src={c.map_photo} alt="Map" onClick={() => setExpandedImage(c.map_photo)} title="Ubicación en el Mapa"/>}
                                            {c.camp_photo && <img src={c.camp_photo} alt="Camp" onClick={() => setExpandedImage(c.camp_photo)} title="Fotografía del Campamento"/>}
                                        </div>
                                    </div>
                                ))}

                                {/* Miembros */}
                                <div className="rdr-section-title">
                                    MIEMBROS DEL GRUPO
                                    {canManageBasics && <button onClick={() => {setActiveGroupId(g.id); setActiveModal('addMember');}} style={{float:'right', background:'none', border:'none', color:'#8b0000', cursor:'pointer'}}>+</button>}
                                </div>
                                {g.members.length === 0 ? <div style={{fontSize:'0.85rem', color:'#8b5a2b', fontStyle:'italic'}}>Sin sujetos registrados...</div> : g.members.map(m => (
                                    <div key={m.id} className="rdr-trello-card" style={{borderLeftColor: g.color}}>
                                        {canManageBasics && (
                                            <div style={{position: 'absolute', right: '5px', top: '5px', display: 'flex', gap: '10px'}}>
                                                <span style={{cursor:'pointer', fontSize:'0.8rem'}} onClick={() => handleEditItem('addMember', g.id, m)}>✏️</span>
                                                <span style={{cursor:'pointer', fontSize:'0.8rem'}} onClick={() => handleDeleteItem('group_members', m.id)}>🗑️</span>
                                            </div>
                                        )}
                                        <div className="rdr-member-header">
                                            {m.photo ? <img src={m.photo} className="rdr-member-avatar" alt="Mugshot" onClick={() => setExpandedImage(m.photo)}/> : <div className="rdr-member-avatar" style={{background:'#d4c5a7', display:'flex', alignItems:'center', justifyContent:'center'}}>?</div>}
                                            <div>
                                                <div className={`rdr-card-title role-${m.role.toLowerCase()}`} style={{marginBottom: 0, border: 'none'}}>{m.role.toUpperCase()}</div>
                                                <div style={{fontFamily: 'Playfair Display', fontWeight: 'bold'}}>{m.name}</div>
                                                {m.alias && <div style={{fontSize: '0.8rem', color: '#8b5a2b'}}>Alias: "{m.alias}"</div>}
                                            </div>
                                        </div>
                                        <div className="rdr-card-text">{m.notes}</div>
                                    </div>
                                ))}

                                <div style={{marginTop: '30px', display: 'flex', flexDirection: 'column', gap: '10px'}}>
                                    {canManageAll && (
                                        <button onClick={() => handleToggleArchive(g.id, g.is_archived)} style={{width: '100%', background: 'rgba(212, 175, 55, 0.1)', border: '1px solid #d4af37', color: '#1a0f0a', padding: '10px', fontFamily: 'Cinzel', cursor: 'pointer', fontWeight: 'bold'}}>
                                            {g.is_archived ? "RESTAURAR A OPERATIVOS" : "ARCHIVAR BANDA"}
                                        </button>
                                    )}
                                    {canManageAll && (
                                        <button onClick={() => handleDeleteGroup(g.id)} style={{width: '100%', background: 'transparent', border: '1px dashed #8b0000', color: '#8b0000', padding: '10px', fontFamily: 'Cinzel', cursor: 'pointer', opacity: 0.8}}>QUEMAR ARCHIVO DE BANDA</button>
                                    )}
                                </div>
                            </div>
                        </div>
                    ))}
                </div>
            )}

            {/* MODALS */}
            {activeModal === 'createGroup' && (
                <div className="rdr-modal-overlay">
                    <div className="rdr-modal-content" style={{maxWidth: '500px'}}>
                        <h2 style={{textTransform: 'uppercase', marginBottom: '1.5rem', textAlign: 'center'}}>{editingItemId ? 'ACTUALIZAR DATOS DE BANDA' : 'NUEVO REGISTRO DE BANDA'}</h2>
                        <form onSubmit={handleCreateGroup}>
                            <div className="rdr-form-group">
                                <label className="rdr-form-label">Nombre de la Banda</label>
                                <input type="text" className="rdr-input" required value={groupName} onChange={e => setGroupName(e.target.value)} />
                            </div>
                            <div className="rdr-form-group">
                                <label className="rdr-form-label">Tinta Identificativa</label>
                                <input type="color" className="rdr-input" style={{height:'50px', padding:0}} value={groupColor} onChange={e => setGroupColor(e.target.value)} />
                            </div>
                            <div className="rdr-form-group">
                                <label className="rdr-form-label">Mapa de Zona de Influencia</label>
                                <label className="rdr-btn-brown" style={{ width: '100%', display: 'block', cursor: 'pointer', textAlign: 'center', background: 'transparent', borderColor: '#8b5a2b', color: '#e4d5b7', borderStyle: 'dashed', padding: '10px', boxSizing: 'border-box' }}>
                                    {groupImage ? 'MODIFICAR SELECCIÓN' : 'ADJUNTAR ESTAMPA (MAPA)'}
                                    <input type="file" accept="image/*" onChange={e => handleImageUpload(e, setGroupImage)} style={{ display: 'none' }} />
                                </label>
                                {groupImage && <img src={groupImage} alt="Preview" style={{width: '100px', marginTop: '10px', border: '2px solid #8b5a2b', borderRadius: '2px'}}/>}
                            </div>
                            <div style={{display:'flex', gap:'10px', justifyContent:'flex-end', marginTop:'2rem'}}>
                                <button type="button" className="rdr-btn-brown" style={{background:'transparent'}} onClick={closeModal}>Cancelar</button>
                                <button type="submit" className="rdr-btn-brown" disabled={submitting}>{editingItemId ? 'Actualizar Banda' : 'Crear Banda'}</button>
                            </div>
                        </form>
                    </div>
                </div>
            )}

            {activeModal === 'addChar' && (
                <div className="rdr-modal-overlay">
                    <div className="rdr-modal-content" style={{maxWidth: '400px'}}>
                        <h2 style={{textTransform: 'uppercase', marginBottom: '1.5rem', textAlign: 'center'}}>{editingItemId ? 'ACTUALIZAR NOTA' : 'AÑADIR CARACTERÍSTICA'}</h2>
                        <form onSubmit={handleAddCharacteristic}>
                            <div className="rdr-form-group">
                                <label className="rdr-form-label">Comportamiento / Descripción</label>
                                <textarea className="rdr-input" rows="4" required value={charContent} onChange={e => setCharContent(e.target.value)} />
                            </div>
                            <div style={{display:'flex', gap:'10px', justifyContent:'flex-end', marginTop:'2rem'}}>
                                <button type="button" className="rdr-btn-brown" style={{background:'transparent'}} onClick={closeModal}>Cancelar</button>
                                <button type="submit" className="rdr-btn-brown" disabled={submitting}>{editingItemId ? 'Guardar' : 'Añadir'}</button>
                            </div>
                        </form>
                    </div>
                </div>
            )}

            {activeModal === 'addCamp' && (
                <div className="rdr-modal-overlay">
                    <div className="rdr-modal-content" style={{maxWidth: '500px'}}>
                        <h2 style={{textTransform: 'uppercase', marginBottom: '1.5rem', textAlign: 'center'}}>{editingItemId ? 'MODIFICAR CAMPAMENTO' : 'REGISTRAR CAMPAMENTO'}</h2>
                        <form onSubmit={handleAddCamp}>
                            <div className="rdr-form-group">
                                <label className="rdr-form-label">Estado Actual</label>
                                <select className="rdr-input" value={campStatus} onChange={e => setCampStatus(e.target.value)}>
                                    <option value="Activo">Aún Activo</option>
                                    <option value="Abandonado">Abandonado / Destruido</option>
                                </select>
                            </div>
                            <div className="rdr-form-group">
                                <label className="rdr-form-label">Notas e Información del Terreno</label>
                                <textarea className="rdr-input" rows="3" required value={campNotes} onChange={e => setCampNotes(e.target.value)} />
                            </div>
                            <div style={{display:'grid', gridTemplateColumns:'1fr 1fr', gap:'1rem'}}>
                                <div className="rdr-form-group">
                                    <label className="rdr-form-label">Foto de Posición (Mapa)</label>
                                    <label className="rdr-btn-brown" style={{ width: '100%', display: 'block', cursor: 'pointer', textAlign: 'center', background: 'transparent', borderColor: '#8b5a2b', color: '#e4d5b7', borderStyle: 'dashed', padding: '10px', boxSizing: 'border-box' }}>
                                        {campMapPhoto ? 'MODIFICAR ARCHIVO' : 'SUBIR CROQUIS'}
                                        <input type="file" accept="image/*" onChange={e => handleImageUpload(e, setCampMapPhoto)} style={{ display: 'none' }} />
                                    </label>
                                    {campMapPhoto && <img src={campMapPhoto} style={{width:'100%', marginTop:'5px', border: '2px solid #8b5a2b'}}/>}
                                </div>
                                <div className="rdr-form-group">
                                    <label className="rdr-form-label">Foto del Frontal (Terreno)</label>
                                    <label className="rdr-btn-brown" style={{ width: '100%', display: 'block', cursor: 'pointer', textAlign: 'center', background: 'transparent', borderColor: '#8b5a2b', color: '#e4d5b7', borderStyle: 'dashed', padding: '10px', boxSizing: 'border-box' }}>
                                        {campPhoto ? 'MODIFICAR ARCHIVO' : 'SUBIR FOTOGRAFÍA'}
                                        <input type="file" accept="image/*" onChange={e => handleImageUpload(e, setCampPhoto)} style={{ display: 'none' }} />
                                    </label>
                                    {campPhoto && <img src={campPhoto} style={{width:'100%', marginTop:'5px', border: '2px solid #8b5a2b'}}/>}
                                </div>
                            </div>
                            <div style={{display:'flex', gap:'10px', justifyContent:'flex-end', marginTop:'2rem'}}>
                                <button type="button" className="rdr-btn-brown" style={{background:'transparent'}} onClick={closeModal}>Cancelar</button>
                                <button type="submit" className="rdr-btn-brown" disabled={submitting}>Sellar Campamento</button>
                            </div>
                        </form>
                    </div>
                </div>
            )}

            {activeModal === 'addMember' && (
                <div className="rdr-modal-overlay">
                    <div className="rdr-modal-content" style={{maxWidth: '450px'}}>
                        <h2 style={{textTransform: 'uppercase', marginBottom: '1.5rem', textAlign: 'center'}}>{editingItemId ? 'EDITAR FICHA' : 'FICHAR MIEMBRO'}</h2>
                        <form onSubmit={handleAddMember}>
                            <div className="rdr-form-group">
                                <label className="rdr-form-label">Nombres y Apellidos</label>
                                <input type="text" className="rdr-input" required value={memName} onChange={e => setMemName(e.target.value)} />
                            </div>
                            <div className="rdr-form-group">
                                <label className="rdr-form-label">Alias Registrado</label>
                                <input type="text" className="rdr-input" value={memAlias} onChange={e => setMemAlias(e.target.value)} />
                            </div>
                            <div className="rdr-form-group">
                                <label className="rdr-form-label">Jerarquía u Oficialidad</label>
                                <select className="rdr-input" value={memRole} onChange={e => setMemRole(e.target.value)} style={{appearance: 'auto'}}>
                                    <option value="Lider" style={{background: '#1a0f0a', color: '#d4af37'}}>Líder (Jefe Supremo)</option>
                                    <option value="Miembro" style={{background: '#1a0f0a', color: '#d4af37'}}>Miembro de la Banda</option>
                                    <option value="Sospechoso" style={{background: '#1a0f0a', color: '#d4af37'}}>Sospechoso de ser Cómplice</option>
                                </select>
                            </div>
                            <div className="rdr-form-group">
                                <label className="rdr-form-label">Fotografía o Retrato</label>
                                <label className="rdr-btn-brown" style={{ width: '100%', display: 'block', cursor: 'pointer', textAlign: 'center', background: 'transparent', borderColor: '#8b5a2b', color: '#e4d5b7', borderStyle: 'dashed', padding: '10px', boxSizing: 'border-box' }}>
                                    {memPhoto ? 'MODIFICAR RETRATO' : 'ADJUNTAR ESTAMPA'}
                                    <input type="file" accept="image/*" onChange={e => handleImageUpload(e, setMemPhoto)} style={{ display: 'none' }} />
                                </label>
                                {memPhoto && <img src={memPhoto} style={{width:'80px', marginTop:'5px', border: '2px solid #8b5a2b'}}/>}
                            </div>
                            <div className="rdr-form-group">
                                <label className="rdr-form-label">Anotaciones del Sujeto</label>
                                <textarea className="rdr-input" rows="3" value={memNotes} onChange={e => setMemNotes(e.target.value)} />
                            </div>
                            <div style={{display:'flex', gap:'10px', justifyContent:'flex-end', marginTop:'2rem'}}>
                                <button type="button" className="rdr-btn-brown" style={{background:'transparent'}} onClick={closeModal}>Cancelar</button>
                                <button type="submit" className="rdr-btn-brown" disabled={submitting}>Encolar Ficha</button>
                            </div>
                        </form>
                    </div>
                </div>
            )}

            {expandedImage && (
                <div style={{position: 'fixed', top: 0, left: 0, width: '100%', height: '100%', backgroundColor: 'rgba(0,0,0,0.9)', zIndex: 9999, display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'zoom-out'}} onClick={() => setExpandedImage(null)}>
                    <img src={expandedImage} alt="Expanded" style={{maxWidth: '90vw', maxHeight: '90vh', border: '5px solid #1a0f0a', borderRadius: '2px', boxShadow: '0 0 20px #000'}}/>
                    <div style={{position: 'absolute', top: '20px', right: '40px', color: '#d4af37', fontSize: '3rem', fontWeight: 'bold'}}>×</div>
                </div>
            )}
        </div>
    );
}

export default Gangs;
