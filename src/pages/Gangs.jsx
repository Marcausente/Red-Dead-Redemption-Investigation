import { useState, useEffect } from 'react';
import { supabase } from '../supabaseClient';
import './GangsRDR.css';

function Gangs() {
    const [groups, setGroups] = useState([]);
    const [loading, setLoading] = useState(true);
    const [currentUser, setCurrentUser] = useState(null);

    // Modal states
    const [activeModal, setActiveModal] = useState(null);
    const [activeGroupId, setActiveGroupId] = useState(null);
    const [submitting, setSubmitting] = useState(false);
    const [expandedImage, setExpandedImage] = useState(null);

    // Form fields
    // Group
    const [groupName, setGroupName] = useState('');
    const [groupColor, setGroupColor] = useState('#8b0000');
    const [groupImage, setGroupImage] = useState(null);
    // Char
    const [charContent, setCharContent] = useState('');
    // Camp
    const [campMapPhoto, setCampMapPhoto] = useState(null);
    const [campPhoto, setCampPhoto] = useState(null);
    const [campStatus, setCampStatus] = useState('Activo');
    const [campNotes, setCampNotes] = useState('');
    // Member
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
        // Clean forms
        setGroupName(''); setGroupColor('#8b0000'); setGroupImage(null);
        setCharContent('');
        setCampMapPhoto(null); setCampPhoto(null); setCampStatus('Activo'); setCampNotes('');
        setMemName(''); setMemAlias(''); setMemRole('Sospechoso'); setMemNotes(''); setMemPhoto(null);
    };

    // Submits
    const handleCreateGroup = async (e) => {
        e.preventDefault();
        setSubmitting(true);
        try {
            await supabase.rpc('create_criminal_group', { p_name: groupName, p_color: groupColor, p_image: groupImage });
            closeModal();
            loadGroups();
        } catch (err) { alert(err.message); } finally { setSubmitting(false); }
    };

    const handleAddCharacteristic = async (e) => {
        e.preventDefault();
        setSubmitting(true);
        try {
            await supabase.rpc('add_group_characteristic', { p_group_id: activeGroupId, p_content: charContent });
            closeModal();
            loadGroups();
        } catch (err) { alert(err.message); } finally { setSubmitting(false); }
    };

    const handleAddCamp = async (e) => {
        e.preventDefault();
        setSubmitting(true);
        try {
            await supabase.rpc('add_group_camp', { p_group_id: activeGroupId, p_map_photo: campMapPhoto, p_camp_photo: campPhoto, p_status: campStatus, p_notes: campNotes });
            closeModal();
            loadGroups();
        } catch (err) { alert(err.message); } finally { setSubmitting(false); }
    };

    const handleAddMember = async (e) => {
        e.preventDefault();
        setSubmitting(true);
        try {
            await supabase.rpc('add_group_member', { p_group_id: activeGroupId, p_name: memName, p_alias: memAlias, p_role: memRole, p_notes: memNotes, p_photo: memPhoto });
            closeModal();
            loadGroups();
        } catch (err) { alert(err.message); } finally { setSubmitting(false); }
    };

    const handleDeleteGroup = async (id) => {
        if (!window.confirm("🛑 ¿Quemar y destruir por completo la columna de esta banda?")) return;
        try {
            await supabase.rpc('delete_criminal_group_fully', { p_group_id: id });
            loadGroups();
        } catch (err) { alert(err.message); }
    };

    const canManage = currentUser && ['Administrador', 'Coordinador', 'Jefatura'].includes(currentUser.rol);

    return (
        <div className="rdr-trello-container">
            <div className="rdr-trello-header">
                <h2 className="rdr-trello-title">BANDAS Y GRUPOS CRIMINALES</h2>
                {canManage && (
                    <button className="rdr-btn-brown" style={{margin: 0}} onClick={() => setActiveModal('createGroup')}>
                        + RASTREAR NUEVA BANDA
                    </button>
                )}
            </div>

            {loading ? <div style={{color: '#c0a080', fontFamily: 'Cinzel', textAlign: 'center', marginTop: '3rem'}}>Desplegando la mesa de mapas...</div> : (
                <div className="rdr-trello-board">
                    {groups.length === 0 ? <p style={{color: '#c0a080', fontStyle: 'italic', margin: 'auto'}}>No hay grupos criminales detectados en el territorio.</p> : groups.map(g => (
                        <div key={g.id} className="rdr-trello-column">
                            <div className="rdr-col-color-bar" style={{backgroundColor: g.color}}></div>
                            
                            <div className="rdr-col-head">
                                <h3 className="rdr-col-name">{g.name}</h3>
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
                                    {canManage && <button onClick={() => {setActiveGroupId(g.id); setActiveModal('addChar');}} style={{float:'right', background:'none', border:'none', color:'#8b0000', cursor:'pointer'}}>+</button>}
                                </div>
                                {g.characteristics.length === 0 ? <div style={{fontSize:'0.85rem', color:'#8b5a2b', fontStyle:'italic'}}>Faltan datos...</div> : g.characteristics.map(c => (
                                    <div key={c.id} className="rdr-trello-card" style={{borderLeftColor: g.color}}>
                                        <div className="rdr-card-text">• {c.content}</div>
                                    </div>
                                ))}

                                {/* Campamentos */}
                                <div className="rdr-section-title">
                                    CAMPAMENTOS & ESCONDITES
                                    {canManage && <button onClick={() => {setActiveGroupId(g.id); setActiveModal('addCamp');}} style={{float:'right', background:'none', border:'none', color:'#8b0000', cursor:'pointer'}}>+</button>}
                                </div>
                                {g.camps.length === 0 ? <div style={{fontSize:'0.85rem', color:'#8b5a2b', fontStyle:'italic'}}>Desconocidos...</div> : g.camps.map(c => (
                                    <div key={c.id} className="rdr-trello-card" style={{borderLeftColor: g.color}}>
                                        <div style={{display: 'flex', justifyContent: 'space-between', marginBottom: '5px'}}>
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
                                    {canManage && <button onClick={() => {setActiveGroupId(g.id); setActiveModal('addMember');}} style={{float:'right', background:'none', border:'none', color:'#8b0000', cursor:'pointer'}}>+</button>}
                                </div>
                                {g.members.length === 0 ? <div style={{fontSize:'0.85rem', color:'#8b5a2b', fontStyle:'italic'}}>Sin sujetos registrados...</div> : g.members.map(m => (
                                    <div key={m.id} className="rdr-trello-card" style={{borderLeftColor: g.color}}>
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

                                {canManage && (
                                    <button onClick={() => handleDeleteGroup(g.id)} style={{width: '100%', marginTop: '20px', background: 'transparent', border: '1px dashed #8b0000', color: '#8b0000', padding: '10px', fontFamily: 'Cinzel', cursor: 'pointer', opacity: 0.5}}>QUEMAR ARCHIVO DE BANDA</button>
                                )}
                            </div>
                        </div>
                    ))}
                </div>
            )}

            {/* MODALS */}
            {activeModal === 'createGroup' && (
                <div className="rdr-modal-overlay">
                    <div className="rdr-modal-content" style={{maxWidth: '500px'}}>
                        <h2 style={{textTransform: 'uppercase', marginBottom: '1.5rem', textAlign: 'center'}}>NUEVO REGISTRO DE BANDA</h2>
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
                                <input type="file" className="rdr-input" accept="image/*" onChange={e => handleImageUpload(e, setGroupImage)} />
                                {groupImage && <img src={groupImage} alt="Preview" style={{width: '100px', marginTop: '10px'}}/>}
                            </div>
                            <div style={{display:'flex', gap:'10px', justifyContent:'flex-end', marginTop:'2rem'}}>
                                <button type="button" className="rdr-btn-brown" style={{background:'transparent'}} onClick={closeModal}>Cancelar</button>
                                <button type="submit" className="rdr-btn-brown" disabled={submitting}>Crear Banda</button>
                            </div>
                        </form>
                    </div>
                </div>
            )}

            {activeModal === 'addChar' && (
                <div className="rdr-modal-overlay">
                    <div className="rdr-modal-content" style={{maxWidth: '400px'}}>
                        <h2 style={{textTransform: 'uppercase', marginBottom: '1.5rem', textAlign: 'center'}}>AÑADIR CARACTERÍSTICA</h2>
                        <form onSubmit={handleAddCharacteristic}>
                            <div className="rdr-form-group">
                                <label className="rdr-form-label">Comportamiento / Descripción</label>
                                <textarea className="rdr-input" rows="4" required value={charContent} onChange={e => setCharContent(e.target.value)} />
                            </div>
                            <div style={{display:'flex', gap:'10px', justifyContent:'flex-end', marginTop:'2rem'}}>
                                <button type="button" className="rdr-btn-brown" style={{background:'transparent'}} onClick={closeModal}>Cancelar</button>
                                <button type="submit" className="rdr-btn-brown" disabled={submitting}>Añadir</button>
                            </div>
                        </form>
                    </div>
                </div>
            )}

            {activeModal === 'addCamp' && (
                <div className="rdr-modal-overlay">
                    <div className="rdr-modal-content" style={{maxWidth: '500px'}}>
                        <h2 style={{textTransform: 'uppercase', marginBottom: '1.5rem', textAlign: 'center'}}>REGISTRAR CAMPAMENTO</h2>
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
                                    <input type="file" accept="image/*" onChange={e => handleImageUpload(e, setCampMapPhoto)}/>
                                    {campMapPhoto && <img src={campMapPhoto} style={{width:'100%', marginTop:'5px'}}/>}
                                </div>
                                <div className="rdr-form-group">
                                    <label className="rdr-form-label">Foto del Frontal (Terreno)</label>
                                    <input type="file" accept="image/*" onChange={e => handleImageUpload(e, setCampPhoto)}/>
                                    {campPhoto && <img src={campPhoto} style={{width:'100%', marginTop:'5px'}}/>}
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
                        <h2 style={{textTransform: 'uppercase', marginBottom: '1.5rem', textAlign: 'center'}}>FICHAR MIEMBRO</h2>
                        <form onSubmit={handleAddMember}>
                            <div className="rdr-form-group">
                                <label className="rdr-form-label">Nombres y Apellidos</label>
                                <input type="text" className="rdr-input" required value={memName} onChange={e => setMemName(e.target.value)} />
                            </div>
                            <div style={{display:'grid', gridTemplateColumns:'1fr 1fr', gap:'1rem'}}>
                                <div className="rdr-form-group">
                                    <label className="rdr-form-label">Alias Registrado</label>
                                    <input type="text" className="rdr-input" value={memAlias} onChange={e => setMemAlias(e.target.value)} />
                                </div>
                                <div className="rdr-form-group">
                                    <label className="rdr-form-label">Jerarquía Detectada</label>
                                    <select className="rdr-input" value={memRole} onChange={e => setMemRole(e.target.value)}>
                                        <option value="Lider">Líder (Boss)</option>
                                        <option value="Miembro">Miembro Activo</option>
                                        <option value="Sospechoso">Sospechoso de Cómplice</option>
                                    </select>
                                </div>
                            </div>
                            <div className="rdr-form-group">
                                <label className="rdr-form-label">Fotografía o Retrato</label>
                                <input type="file" accept="image/*" onChange={e => handleImageUpload(e, setMemPhoto)}/>
                                {memPhoto && <img src={memPhoto} style={{width:'80px', marginTop:'5px'}}/>}
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
