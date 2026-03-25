import { useState, useEffect, useRef } from 'react';
import { supabase } from '../supabaseClient';
import './GangsRDR.css'; // Inheriting Trello Western Aesthetics

function Incidents() {
    const [board, setBoard] = useState({ unlinked_incidents: [], linked_incidents: [], field_ops: [] });
    const [loading, setLoading] = useState(true);
    const [groupsList, setGroupsList] = useState([]);
    const [usersList, setUsersList] = useState([]);

    // Drag to scroll
    const boardRef = useRef(null);
    const [isDragging, setIsDragging] = useState(false);
    const [startX, setStartX] = useState(0);
    const [scrollLeft, setScrollLeft] = useState(0);

    const [expandedImage, setExpandedImage] = useState(null);
    const [activeModal, setActiveModal] = useState(null); // 'incident' or 'fieldop'
    const [submitting, setSubmitting] = useState(false);

    // Common states
    const [title, setTitle] = useState('');
    const [groupId, setGroupId] = useState('');
    const [occurredAt, setOccurredAt] = useState('');
    const [location, setLocation] = useState('');
    const [description, setDescription] = useState('');
    const [images, setImages] = useState([]);

    // Field Ops specific
    const [reason, setReason] = useState('');
    const [info, setInfo] = useState('');
    const [selectedAgents, setSelectedAgents] = useState([]);

    useEffect(() => {
        loadData();
    }, []);

    const loadData = async () => {
        setLoading(true);
        // Load Board Data
        const { data: boardData, error: e1 } = await supabase.rpc('get_incidents_board_data');
        if (boardData) setBoard(boardData);

        // Load active groups for Drowpdown Form
        const { data: groupData } = await supabase.from('criminal_groups').select('id, name').eq('is_archived', false);
        if (groupData) setGroupsList(groupData);

        // Load Investigators for Field Ops
        const { data: userData } = await supabase.from('users').select('id, nombre, apellido, rol');
        if (userData) {
            setUsersList(userData.filter(u => ['Administrador', 'Jefatura', 'Coordinador', 'Agente BOI', 'Ayudante BOI'].includes(u.rol)));
        }

        setLoading(false);
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
                const webP = canvas.toDataURL('image/webp', 0.6);
                setImages([...images, webP]);
            };
        };
        e.target.value = ''; // reset format
    };

    const removeImage = (idx) => {
        setImages(images.filter((_, i) => i !== idx));
    };

    const closeModal = () => {
        setActiveModal(null);
        setTitle(''); setGroupId(''); setOccurredAt(''); setLocation('');
        setDescription(''); setImages([]); setReason(''); setInfo(''); setSelectedAgents([]);
    };

    const handleAgentToggle = (id) => {
        if (selectedAgents.includes(id)) setSelectedAgents(selectedAgents.filter(a => a !== id));
        else setSelectedAgents([...selectedAgents, id]);
    };

    const handleSubmitIncident = async (e) => {
        e.preventDefault();
        setSubmitting(true);
        try {
            await supabase.rpc('create_incident', {
                p_title: title,
                p_group_id: groupId || null,
                p_occurred_at: occurredAt || new Date().toISOString(),
                p_location: location,
                p_description: description,
                p_images: images
            });
            closeModal();
            loadData();
        } catch (err) { alert(err.message); } finally { setSubmitting(false); }
    };

    const handleSubmitFieldOp = async (e) => {
        e.preventDefault();
        setSubmitting(true);
        try {
            await supabase.rpc('create_field_operation', {
                p_title: title,
                p_group_id: groupId || null,
                p_occurred_at: occurredAt || new Date().toISOString(),
                p_reason: reason,
                p_info: info,
                p_agents: selectedAgents,
                p_images: images
            });
            closeModal();
            loadData();
        } catch (err) { alert(err.message); } finally { setSubmitting(false); }
    };

    const handleDeleteIncident = async (id, type) => {
        if (!window.confirm("¿Seguro que quieres arrancar este informe de los tablones del muro?")) return;
        try {
            if (type === 'inc') await supabase.rpc('delete_incident', { p_id: id });
            else await supabase.rpc('delete_field_operation', { p_id: id });
            loadData();
        } catch (err) { alert(err.message); }
    };

    // Formatear Fecha
    const fd = (dateStr) => {
        if (!dateStr) return '';
        const d = new Date(dateStr);
        return d.toLocaleString('es-ES', { day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' }).toUpperCase();
    };

    // Scroll drag handlers
    const hDown = (e) => { if (!boardRef.current) return; setIsDragging(true); setStartX(e.pageX - boardRef.current.offsetLeft); setScrollLeft(boardRef.current.scrollLeft); boardRef.current.style.cursor = 'grabbing'; };
    const hLeave = () => { setIsDragging(false); if (boardRef.current) boardRef.current.style.cursor = 'grab'; };
    const hUp = () => { setIsDragging(false); if (boardRef.current) boardRef.current.style.cursor = 'grab'; };
    const hMove = (e) => { if (!isDragging) return; e.preventDefault(); const walk = (e.pageX - boardRef.current.offsetLeft - startX) * 2; boardRef.current.scrollLeft = scrollLeft - walk; };


    const IncidentCard = ({ i }) => (
        <div className="rdr-trello-card" style={{ borderLeftColor: i.group_color || '#c0a080' }}>
            <span style={{ cursor: 'pointer', position: 'absolute', right: '5px', top: '5px', fontSize: '0.8rem' }} onClick={() => handleDeleteIncident(i.id, 'inc')}>🗑️</span>

            <div style={{ fontSize: '0.7rem', color: '#8b5a2b', fontWeight: 'bold' }}>INCIDENTE Nº 00{i.number}</div>
            <div style={{ fontFamily: 'Playfair Display', fontWeight: 'bold', fontSize: '1.2rem', color: '#1a0f0a', margin: '5px 0' }}>{i.title.toUpperCase()}</div>

            <div style={{ fontSize: '0.8rem', fontStyle: 'italic', color: '#8b5a2b', display: 'flex', flexDirection: 'column' }}>
                {i.occurred_at && <span>🕒 {fd(i.occurred_at)}</span>}
                {i.location && <span>📍 {i.location}</span>}
                {i.group_name && <span style={{ color: i.group_color || '#8b0000', fontWeight: 'bold' }}>🏴 {i.group_name}</span>}
            </div>

            <div className="rdr-card-text" style={{ marginTop: '10px' }}>{i.description}</div>

            {i.images && i.images.length > 0 && (
                <div className="rdr-camp-imgs" style={{ marginTop: '10px' }}>
                    {i.images.map((img, idx) => (
                        <img key={idx} src={img} alt="Incident" onClick={() => setExpandedImage(img)} title="Evidencia Fotográfica" style={{ width: i.images.length === 1 ? '100%' : '48%', height: 'auto', maxHeight: '150px' }} />
                    ))}
                </div>
            )}
        </div>
    );

    const FieldOpCard = ({ o }) => (
        <div className="rdr-trello-card" style={{ borderLeftColor: o.group_color || '#2e4a2e' }}>
            <span style={{ cursor: 'pointer', position: 'absolute', right: '5px', top: '5px', fontSize: '0.8rem' }} onClick={() => handleDeleteIncident(o.id, 'op')}>🗑️</span>

            <div style={{ fontSize: '0.7rem', color: '#556b2f', fontWeight: 'bold' }}>EXPEDICIÓN Nº OP-{o.number}</div>
            <div style={{ fontFamily: 'Playfair Display', fontWeight: 'bold', fontSize: '1.2rem', color: '#1a0f0a', margin: '5px 0' }}>{o.title.toUpperCase()}</div>

            <div style={{ fontSize: '0.8rem', fontStyle: 'italic', color: '#8b5a2b', display: 'flex', flexDirection: 'column' }}>
                {o.occurred_at && <span>🕒 {fd(o.occurred_at)}</span>}
                {o.group_name && <span style={{ color: o.group_color || '#8b0000', fontWeight: 'bold' }}>🏴 Destino: {o.group_name}</span>}
            </div>

            <div className="rdr-section-title" style={{ marginTop: '10px', fontSize: '0.7rem' }}>OBJETIVO</div>
            <div className="rdr-card-text">{o.reason}</div>

            <div className="rdr-section-title" style={{ marginTop: '10px', fontSize: '0.7rem' }}>INTELIGENCIA RECOPILADA</div>
            <div className="rdr-card-text" style={{ color: '#1a0f0a' }}>{o.info || <span style={{ fontStyle: 'italic', color: '#c0a080' }}>N/A</span>}</div>

            {o.agents && o.agents.length > 0 && (
                <>
                    <div className="rdr-section-title" style={{ marginTop: '10px', fontSize: '0.7rem' }}>AGENTES DEL GRUPO</div>
                    <div style={{ display: 'flex', flexWrap: 'wrap', gap: '5px' }}>
                        {o.agents.map(a => (
                            <div key={a.id} title={`${a.name} ${a.surname}`} style={{ width: '25px', height: '25px', borderRadius: '50%', backgroundColor: '#c0a080', border: '1px solid #1a0f0a', overflow: 'hidden', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                                {a.photo ? <img src={a.photo} style={{ width: '100%', height: '100%', objectFit: 'cover' }} /> : <span style={{ fontSize: '10px', fontWeight: 'bold', color: '#1a0f0a' }}>{a.name?.charAt(0)}</span>}
                            </div>
                        ))}
                    </div>
                </>
            )}

            {o.images && o.images.length > 0 && (
                <div className="rdr-camp-imgs" style={{ marginTop: '10px' }}>
                    {o.images.map((img, idx) => (
                        <img key={idx} src={img} alt="Op" onClick={() => setExpandedImage(img)} title="Documentación Gráfica" style={{ width: o.images.length === 1 ? '100%' : '48%', height: 'auto', maxHeight: '150px' }} />
                    ))}
                </div>
            )}
        </div>
    );

    return (
        <div className="rdr-trello-container">
            <div className="rdr-trello-header">
                <div>
                    <h2 className="rdr-trello-title">TABLÓN DE INCIDENTES Y SALIDAS</h2>
                    <p style={{ fontFamily: 'Playfair Display', color: '#c0a080', fontSize: '0.9rem', fontStyle: 'italic', margin: 0 }}>Muro de seguimiento de la actividad criminal en el Estado</p>
                </div>
                <div style={{ display: 'flex', gap: '15px' }}>
                    <button className="rdr-btn-brown" style={{ margin: 0 }} onClick={() => setActiveModal('incident')}>+ CINTA DE INCIDENTE</button>
                    <button className="rdr-btn-brown" style={{ margin: 0, background: 'rgba(46, 74, 46, 0.4)', borderColor: '#556b2f' }} onClick={() => setActiveModal('fieldop')}>+ REGISTRAR SALIDA</button>
                </div>
            </div>

            {loading ? <div style={{ color: '#c0a080', fontFamily: 'Cinzel', textAlign: 'center', marginTop: '3rem' }}>Clavando fotos en los corchos...</div> : (
                <div className="rdr-trello-board" ref={boardRef} onMouseDown={hDown} onMouseLeave={hLeave} onMouseUp={hUp} onMouseMove={hMove} style={{ cursor: 'grab', userSelect: isDragging ? 'none' : 'auto' }}>

                    {/* COLUMNA 1: Sucesos Perdidos */}
                    <div className="rdr-trello-column">
                        <div className="rdr-col-color-bar" style={{ backgroundColor: '#7c7c7c' }}></div>
                        <div className="rdr-col-head">
                            <h3 className="rdr-col-name" style={{ margin: 0 }}>SUCESOS SIN LIGAR A GRUPOS</h3>
                            <div style={{ fontFamily: 'Playfair Display', fontStyle: 'italic', fontSize: '0.8rem', color: '#8b5a2b', marginTop: '5px' }}>Incidentes carentes de vinculación firme.</div>
                        </div>
                        <div className="rdr-col-body">
                            {board.unlinked_incidents.length === 0 ? <p style={{ color: '#8b5a2b', fontStyle: 'italic', margin: 'auto', textAlign: 'center' }}>Corcho limpio.</p> : board.unlinked_incidents.map(i => <IncidentCard key={i.id} i={i} />)}
                        </div>
                    </div>

                    {/* COLUMNA 2: Sucesos Vinculados */}
                    <div className="rdr-trello-column">
                        <div className="rdr-col-color-bar" style={{ backgroundColor: '#8b0000' }}></div>
                        <div className="rdr-col-head">
                            <h3 className="rdr-col-name" style={{ margin: 0 }}>SUCCESOS LIGADOS A GRUPOS</h3>
                            <div style={{ fontFamily: 'Playfair Display', fontStyle: 'italic', fontSize: '0.8rem', color: '#8b5a2b', marginTop: '5px' }}>Sucesos atribuidos a Bandas Identificadas.</div>
                        </div>
                        <div className="rdr-col-body">
                            {board.linked_incidents.length === 0 ? <p style={{ color: '#8b5a2b', fontStyle: 'italic', margin: 'auto', textAlign: 'center' }}>Corcho limpio.</p> : board.linked_incidents.map(i => <IncidentCard key={i.id} i={i} />)}
                        </div>
                    </div>

                    {/* COLUMNA 3: Salidas / Field Ops */}
                    <div className="rdr-trello-column">
                        <div className="rdr-col-color-bar" style={{ backgroundColor: '#2e4a2e' }}></div>
                        <div className="rdr-col-head">
                            <h3 className="rdr-col-name" style={{ margin: 0 }}>EXPEDICIONES SOBRE EL TERRENO</h3>
                            <div style={{ fontFamily: 'Playfair Display', fontStyle: 'italic', fontSize: '0.8rem', color: '#8b5a2b', marginTop: '5px' }}>Movimientos de Agentes del BOI aprobados.</div>
                        </div>
                        <div className="rdr-col-body">
                            {board.field_ops.length === 0 ? <p style={{ color: '#8b5a2b', fontStyle: 'italic', margin: 'auto', textAlign: 'center' }}>Bandeja de permisos vacía.</p> : board.field_ops.map(o => <FieldOpCard key={o.id} o={o} />)}
                        </div>
                    </div>

                </div>
            )}

            {/* MODAL INCIDENTE */}
            {activeModal === 'incident' && (
                <div className="rdr-modal-overlay">
                    <div className="rdr-modal-content" style={{ maxWidth: '550px' }}>
                        <h2 style={{ textTransform: 'uppercase', marginBottom: '1.5rem', textAlign: 'center' }}>REPORTE DE INCIDENTE</h2>
                        <form onSubmit={handleSubmitIncident}>
                            <div className="rdr-form-group">
                                <label className="rdr-form-label">Titular Oficial</label>
                                <input type="text" className="rdr-input" required value={title} onChange={e => setTitle(e.target.value)} />
                            </div>
                            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem' }}>
                                <div className="rdr-form-group">
                                    <label className="rdr-form-label">Fecha y Hora</label>
                                    <input type="datetime-local" className="rdr-input" required value={occurredAt} onChange={e => setOccurredAt(e.target.value)} style={{ colorScheme: 'dark' }} />
                                </div>
                                <div className="rdr-form-group">
                                    <label className="rdr-form-label">Zona del Suceso (Localización)</label>
                                    <input type="text" className="rdr-input" value={location} onChange={e => setLocation(e.target.value)} />
                                </div>
                            </div>
                            <div className="rdr-form-group">
                                <label className="rdr-form-label">Culpabilidad Presunta de Organización (Opcional)</label>
                                <select className="rdr-input" value={groupId} onChange={e => setGroupId(e.target.value)} style={{ appearance: 'auto' }}>
                                    <option value="" style={{ background: '#1a0f0a', color: '#d4c5a7' }}>-- SIN VÍNCULO DETERMINADO --</option>
                                    {groupsList.map(g => (
                                        <option key={g.id} value={g.id} style={{ background: '#1a0f0a', color: '#d4af37' }}>{g.name}</option>
                                    ))}
                                </select>
                            </div>
                            <div className="rdr-form-group">
                                <label className="rdr-form-label">Descripción de Hechos</label>
                                <textarea className="rdr-input" rows="4" required value={description} onChange={e => setDescription(e.target.value)} />
                            </div>

                            <div className="rdr-form-group">
                                <label className="rdr-form-label">Evidencias Fotográficas (Opcional)</label>
                                <label className="rdr-btn-brown" style={{ width: '100%', display: 'block', cursor: 'pointer', textAlign: 'center', background: 'transparent', borderColor: '#8b5a2b', borderStyle: 'dashed', padding: '10px' }}>
                                    ENGRAPAR NUEVA ESTAMPA
                                    <input type="file" accept="image/*" onChange={handleImageUpload} style={{ display: 'none' }} />
                                </label>
                                {images.length > 0 && (
                                    <div style={{ display: 'flex', gap: '10px', flexWrap: 'wrap', marginTop: '10px' }}>
                                        {images.map((img, idx) => (
                                            <div key={idx} style={{ position: 'relative' }}>
                                                <img src={img} style={{ height: '60px', border: '1px solid #8b5a2b' }} />
                                                <div onClick={() => removeImage(idx)} style={{ position: 'absolute', top: -5, right: -5, background: 'black', color: 'red', borderRadius: '50%', width: '15px', height: '15px', display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer', fontSize: '10px' }}>×</div>
                                            </div>
                                        ))}
                                    </div>
                                )}
                            </div>

                            <div style={{ display: 'flex', gap: '10px', justifyContent: 'flex-end', marginTop: '1.5rem' }}>
                                <button type="button" className="rdr-btn-brown" style={{ background: 'transparent' }} onClick={closeModal}>Cancelar</button>
                                <button type="submit" className="rdr-btn-brown" disabled={submitting}>Oficializar Incidente</button>
                            </div>
                        </form>
                    </div>
                </div>
            )}

            {/* MODAL SALIDA */}
            {activeModal === 'fieldop' && (
                <div className="rdr-modal-overlay">
                    <div className="rdr-modal-content" style={{ maxWidth: '600px' }}>
                        <h2 style={{ textTransform: 'uppercase', marginBottom: '1.5rem', textAlign: 'center' }}>PERMISO DE EXPEDICIÓN</h2>
                        <form onSubmit={handleSubmitFieldOp}>
                            <div className="rdr-form-group">
                                <label className="rdr-form-label">Nombre de la Operación / Titular</label>
                                <input type="text" className="rdr-input" required value={title} onChange={e => setTitle(e.target.value)} />
                            </div>
                            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem' }}>
                                <div className="rdr-form-group">
                                    <label className="rdr-form-label">Fecha y Hora</label>
                                    <input type="datetime-local" className="rdr-input" required value={occurredAt} onChange={e => setOccurredAt(e.target.value)} style={{ colorScheme: 'dark' }} />
                                </div>
                                <div className="rdr-form-group">
                                    <label className="rdr-form-label">Investigación Cruzada (Opcional)</label>
                                    <select className="rdr-input" value={groupId} onChange={e => setGroupId(e.target.value)} style={{ appearance: 'auto' }}>
                                        <option value="" style={{ background: '#1a0f0a', color: '#d4c5a7' }}>-- SIN ORGANIZACIÓN FIJA --</option>
                                        {groupsList.map(g => (
                                            <option key={g.id} value={g.id} style={{ background: '#1a0f0a', color: '#d4af37' }}>{g.name}</option>
                                        ))}
                                    </select>
                                </div>
                            </div>

                            <div className="rdr-form-group">
                                <label className="rdr-form-label">Escuadrón Asignado (Agentes Presentes)</label>
                                <div style={{ height: '100px', overflowY: 'auto', background: 'rgba(0,0,0,0.5)', border: '1px solid #8b5a2b', padding: '10px', display: 'flex', flexDirection: 'column', gap: '5px' }}>
                                    {usersList.map(u => (
                                        <label key={u.id} style={{ display: 'flex', alignItems: 'center', gap: '10px', color: '#e4d5b7', fontSize: '0.85rem' }}>
                                            <input type="checkbox" checked={selectedAgents.includes(u.id)} onChange={() => handleAgentToggle(u.id)} style={{ accentColor: '#8b5a2b' }} />
                                            {u.nombre} {u.apellido} <span style={{ color: '#8b5a2b' }}>({u.rol})</span>
                                        </label>
                                    ))}
                                </div>
                            </div>

                            <div className="rdr-form-group">
                                <label className="rdr-form-label">Motivo de Movilización</label>
                                <textarea className="rdr-input" rows="2" required value={reason} onChange={e => setReason(e.target.value)} />
                            </div>
                            <div className="rdr-form-group">
                                <label className="rdr-form-label">Inteligencia y Datos Obtenidos</label>
                                <textarea className="rdr-input" rows="3" value={info} onChange={e => setInfo(e.target.value)} />
                            </div>

                            <div className="rdr-form-group">
                                <label className="rdr-form-label">Soporte Visual de Terreno (Opcional)</label>
                                <label className="rdr-btn-brown" style={{ width: '100%', display: 'block', cursor: 'pointer', textAlign: 'center', background: 'transparent', borderColor: '#556b2f', borderStyle: 'dashed', padding: '10px' }}>
                                    AGREGAR INFORME FOTOGRÁFICO
                                    <input type="file" accept="image/*" onChange={handleImageUpload} style={{ display: 'none' }} />
                                </label>
                                {images.length > 0 && (
                                    <div style={{ display: 'flex', gap: '10px', flexWrap: 'wrap', marginTop: '10px' }}>
                                        {images.map((img, idx) => (
                                            <div key={idx} style={{ position: 'relative' }}>
                                                <img src={img} style={{ height: '60px', border: '1px solid #556b2f' }} />
                                                <div onClick={() => removeImage(idx)} style={{ position: 'absolute', top: -5, right: -5, background: 'black', color: 'red', borderRadius: '50%', width: '15px', height: '15px', display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer', fontSize: '10px' }}>×</div>
                                            </div>
                                        ))}
                                    </div>
                                )}
                            </div>

                            <div style={{ display: 'flex', gap: '10px', justifyContent: 'flex-end', marginTop: '1.5rem' }}>
                                <button type="button" className="rdr-btn-brown" style={{ background: 'transparent' }} onClick={closeModal}>Cancelar</button>
                                <button type="submit" className="rdr-btn-brown" style={{ background: 'rgba(46, 74, 46, 0.4)', borderColor: '#556b2f' }} disabled={submitting}>Desplegar Unidades</button>
                            </div>
                        </form>
                    </div>
                </div>
            )}

            {expandedImage && (
                <div style={{ position: 'fixed', top: 0, left: 0, width: '100%', height: '100%', backgroundColor: 'rgba(0,0,0,0.9)', zIndex: 9999, display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'zoom-out' }} onClick={() => setExpandedImage(null)}>
                    <img src={expandedImage} alt="Expanded" style={{ maxWidth: '90vw', maxHeight: '90vh', border: '5px solid #1a0f0a', borderRadius: '2px', boxShadow: '0 0 20px #000' }} />
                    <div style={{ position: 'absolute', top: '20px', right: '40px', color: '#d4af37', fontSize: '3rem', fontWeight: 'bold' }}>×</div>
                </div>
            )}

        </div>
    );
}

export default Incidents;
