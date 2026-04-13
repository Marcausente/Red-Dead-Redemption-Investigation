import { useState, useEffect, useRef } from 'react';
import { supabase } from '../supabaseClient';
import html2canvas from 'html2canvas';
import './WantedRDR.css';

function Wanted() {
    const [tabType, setTabType] = useState('wanted'); // 'wanted' | 'missing'
    const [view, setView] = useState('active'); // 'active' | 'archived'
    const [selectedTown, setSelectedTown] = useState('all');
    
    // Distintos estados para los arrays
    const [posters, setPosters] = useState({ active: [], archived: [] });
    const [missingPosters, setMissingPosters] = useState({ active: [], archived: [] });
    
    const [loading, setLoading] = useState(true);
    const [showModal, setShowModal] = useState(false);
    const [modalType, setModalType] = useState('wanted'); // 'wanted' | 'missing'
    const [editingId, setEditingId] = useState(null);
    const [submitting, setSubmitting] = useState(false);
    const [exportingId, setExportingId] = useState(null);

    // Towns list
    const towns = ['Saint Denis', 'Rhodes', 'Valentine', 'Annesburg', 'Blackwater', 'Strawberry', 'Armadillo', 'Tumbleweed'];

    // County mapping
    const getStateName = (t) => {
        if (!t) return 'Condado de New Hanover';
        const tn = t.toLowerCase();
        if (tn === 'todos los pueblos') return 'State of Flat Iron';
        if (tn === 'tumbleweed' || tn === 'armadillo') return 'Condado de New Austin';
        if (tn === 'blackwater' || tn === 'strawberry') return 'Condado de West Elizabeth';
        if (tn === 'valentine' || tn === 'annesburg') return 'Condado de New Hanover';
        if (tn === 'rhodes' || tn === 'saint denis') return 'Condado de Lemoyne';
        return 'Condado de New Hanover';
    };

    // Date helper
    const getToday1880 = () => {
        const d = new Date();
        const mm = String(d.getMonth() + 1).padStart(2, '0');
        const dd = String(d.getDate()).padStart(2, '0');
        return `1880-${mm}-${dd}`;
    };

    // Form fields (compartidos y específicos)
    const [photo, setPhoto] = useState('');
    const [name, setName] = useState('');
    const [surname, setSurname] = useState('');
    const [publishedAt, setPublishedAt] = useState(getToday1880());
    
    // Specific WANTED
    const [alias, setAlias] = useState('');
    const [town, setTown] = useState('Valentine');
    const [wantedType, setWantedType] = useState('VIVO O MUERTO');
    const [isDangerous, setIsDangerous] = useState(false);
    
    // Specific MISSING
    const [lastSeen, setLastSeen] = useState('');
    const [description, setDescription] = useState('');
    const [offerReward, setOfferReward] = useState(false);
    
    // Shared reward
    const [reward, setReward] = useState('');

    // Refs for export
    const exportRefs = useRef({});

    useEffect(() => { loadPosters(); }, []);

    const loadPosters = async () => {
        setLoading(true);
        try {
            const { data: wData, error: wErr } = await supabase.rpc('get_wanted_posters');
            if (wErr) throw wErr;
            if (wData) setPosters(wData);

            const { data: mData, error: mErr } = await supabase.rpc('get_missing_posters');
            if (mErr) throw mErr;
            if (mData) setMissingPosters(mData);
        } catch (err) {
            console.error('Error loading posters:', err);
            alert('Error al cargar carteles: ' + err.message);
        } finally {
            setLoading(false);
        }
    };

    const handlePhotoUpload = (e) => {
        const file = e.target.files[0];
        if (!file) return;
        const reader = new FileReader();
        reader.readAsDataURL(file);
        reader.onload = (ev) => {
            const img = new Image();
            img.src = ev.target.result;
            img.onload = () => {
                const canvas = document.createElement('canvas');
                const MAX = 600;
                const scale = img.width > MAX ? MAX / img.width : 1;
                canvas.width = img.width * scale;
                canvas.height = img.height * scale;
                const ctx = canvas.getContext('2d');
                ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
                setPhoto(canvas.toDataURL('image/webp', 0.7));
            };
        };
        e.target.value = '';
    };

    const closeModal = () => {
        setShowModal(false); setEditingId(null);
        setPhoto(''); setName(''); setSurname(''); setAlias('');
        setTown('Valentine'); setReward(''); setWantedType('VIVO O MUERTO'); setIsDangerous(false);
        setLastSeen(''); setDescription(''); setOfferReward(false);
        setPublishedAt(getToday1880());
    };

    const openEditWanted = (poster) => {
        setModalType('wanted');
        setEditingId(poster.id);
        setName(poster.fugitive_name || '');
        setSurname(poster.fugitive_surname || '');
        setAlias(poster.fugitive_alias || '');
        setTown(poster.town || 'Valentine');
        setReward(poster.reward_amount?.toString() || '');
        setWantedType(poster.wanted_type || 'VIVO O MUERTO');
        setIsDangerous(poster.is_dangerous || false);
        setPublishedAt(poster.published_at ? poster.published_at.substring(0, 10) : getToday1880());
        setPhoto(poster.photo || '');
        setShowModal(true);
    };

    const openEditMissing = (poster) => {
        setModalType('missing');
        setEditingId(poster.id);
        setName(poster.person_name || '');
        setSurname(poster.person_surname || '');
        setLastSeen(poster.last_seen || '');
        setDescription(poster.description || '');
        setOfferReward(poster.offer_reward || false);
        setReward(poster.reward_amount?.toString() || '');
        setPublishedAt(poster.published_at ? poster.published_at.substring(0, 10) : getToday1880());
        setPhoto(poster.photo || '');
        setShowModal(true);
    };
    
    const openCreateWanted = () => {
        setModalType('wanted');
        closeModal(); // Reset fields
        setShowModal(true);
    };
    
    const openCreateMissing = () => {
        setModalType('missing');
        closeModal(); // Reset fields
        setShowModal(true);
    }

    const handleSubmit = async (e) => {
        e.preventDefault();
        setSubmitting(true);
        try {
            const p_published = new Date(publishedAt + 'T12:00:00Z').toISOString();
            if (modalType === 'wanted') {
                if (editingId) {
                    const { error } = await supabase.rpc('update_wanted_poster', {
                        p_id: editingId, p_name: name, p_surname: surname,
                        p_alias: alias, p_town: town, p_reward: reward || '0',
                        p_wanted_type: wantedType, p_is_dangerous: isDangerous,
                        p_published_at: p_published, p_photo: photo
                    });
                    if (error) throw error;
                } else {
                    const { error } = await supabase.rpc('create_wanted_poster', {
                        p_name: name, p_surname: surname, p_alias: alias,
                        p_town: town, p_reward: reward || '0', p_wanted_type: wantedType,
                        p_is_dangerous: isDangerous, p_published_at: p_published,
                        p_photo: photo
                    });
                    if (error) throw error;
                }
            } else {
                if (editingId) {
                    const { error } = await supabase.rpc('update_missing_poster', {
                        p_id: editingId, p_name: name, p_surname: surname,
                        p_last_seen: lastSeen, p_offer_reward: offerReward,
                        p_reward: reward || '0', p_published_at: p_published, p_photo: photo,
                        p_description: description
                    });
                    if (error) throw error;
                } else {
                    const { error } = await supabase.rpc('create_missing_poster', {
                        p_name: name, p_surname: surname, p_last_seen: lastSeen,
                        p_offer_reward: offerReward, p_reward: reward || '0',
                        p_published_at: p_published, p_photo: photo,
                        p_description: description
                    });
                    if (error) throw error;
                }
            }
            closeModal();
            loadPosters();
        } catch (err) { alert('Error al guardar: ' + err.message); } finally { setSubmitting(false); }
    };

    const handleArchive = async (id, isMissing = false) => {
        try {
            const { error } = await supabase.rpc(isMissing ? 'archive_missing_poster' : 'archive_wanted_poster', { p_id: id });
            if (error) throw error;
            loadPosters();
        } catch (err) { alert('Error al archivar: ' + err.message); }
    };

    const handleDelete = async (id, isMissing = false) => {
        if (!window.confirm('¿Quemar este cartel permanentemente?')) return;
        try {
            const { error } = await supabase.rpc(isMissing ? 'delete_missing_poster' : 'delete_wanted_poster', { p_id: id });
            if (error) throw error;
            loadPosters();
        } catch (err) { alert('Error al quemar: ' + err.message); }
    };

    const handleExport = async (poster, isMissing = false) => {
        setExportingId(poster.id);
        await new Promise(r => setTimeout(r, 200)); // let DOM render
        const el = exportRefs.current[poster.id];
        if (!el) { setExportingId(null); return; }
        try {
            const canvas = await html2canvas(el, {
                scale: 1,
                useCORS: true,
                backgroundColor: null,
                logging: false,
                width: 800,
                height: 1024
            });
            const link = document.createElement('a');
            const n = isMissing ? poster.person_name : poster.fugitive_name;
            const sn = isMissing ? poster.person_surname : poster.fugitive_surname;
            link.download = `cartel_${n}_${sn || ''}.png`;
            link.href = canvas.toDataURL('image/png');
            link.click();
        } catch (err) { alert('Error al exportar: ' + err.message); }
        setExportingId(null);
    };

    const formatDate = (d) => {
        if (!d) return '';
        return new Date(d).toLocaleDateString('es-ES', { day: '2-digit', month: 'long', year: 'numeric' });
    };

    const formatReward = (n) => {
        if (!n) return '$0';
        return '$' + Number(n).toLocaleString('en-US');
    };



    const targetPosters = tabType === 'wanted' ? posters : missingPosters;
    const allForView = view === 'active' ? targetPosters.active : targetPosters.archived;
    const currentList = tabType === 'wanted' && selectedTown !== 'all'
        ? allForView.filter(p => p.town === selectedTown)
        : allForView;

    return (
        <div className="wanted-container">
            <div className="wanted-header">
                <h1 className="wanted-title">Carteles y Archivos</h1>
                <p className="wanted-subtitle">Directorio de Fugitivos y Desaparecidos — Bureau of Investigation</p>
            </div>

            <div style={{ display: 'flex', gap: '1rem', marginBottom: '1.5rem' }}>
                <button 
                    onClick={() => setTabType('wanted')}
                    style={{ flex: 1, padding: '0.8rem', fontFamily: 'Cinzel', fontSize: '0.9rem', fontWeight: 700, textTransform: 'uppercase', letterSpacing: '2px', background: tabType === 'wanted' ? 'rgba(139,90,43,0.4)' : 'transparent', border: tabType === 'wanted' ? '2px solid #d4af37' : '1px solid #8b5a2b', color: tabType === 'wanted' ? '#d4af37' : '#c0a080', cursor: 'pointer', transition: 'all 0.2s'}}
                >
                    Fugitivos
                </button>
                <button 
                    onClick={() => setTabType('missing')}
                    style={{ flex: 1, padding: '0.8rem', fontFamily: 'Cinzel', fontSize: '0.9rem', fontWeight: 700, textTransform: 'uppercase', letterSpacing: '2px', background: tabType === 'missing' ? 'rgba(139,90,43,0.4)' : 'transparent', border: tabType === 'missing' ? '2px solid #d4af37' : '1px solid #8b5a2b', color: tabType === 'missing' ? '#d4af37' : '#c0a080', cursor: 'pointer', transition: 'all 0.2s'}}
                >
                    Desaparecidos
                </button>
            </div>

            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1rem', flexWrap: 'wrap', gap: '1rem' }}>
                <div className="wanted-tabs">
                    <button className={`wanted-tab${view === 'active' ? ' active' : ''}`} onClick={() => setView('active')}>
                        📋 Activos ({targetPosters.active?.length || 0})
                    </button>
                    <button className={`wanted-tab${view === 'archived' ? ' active' : ''}`} onClick={() => setView('archived')}>
                        📦 Archivo ({targetPosters.archived?.length || 0})
                    </button>
                </div>
                <div style={{ display: 'flex', gap: '0.5rem' }}>
                    {tabType === 'wanted' && (
                        <button
                            onClick={openCreateWanted}
                            style={{ fontFamily: 'Cinzel', fontSize: '0.8rem', fontWeight: 700, textTransform: 'uppercase', letterSpacing: '2px', padding: '0.7rem 1.2rem', background: 'rgba(139,90,43,0.4)', border: '2px solid #d4af37', color: '#d4af37', cursor: 'pointer' }}
                        >
                            + Emitir Se Busca
                        </button>
                    )}
                    {tabType === 'missing' && (
                        <button
                            onClick={openCreateMissing}
                            style={{ fontFamily: 'Cinzel', fontSize: '0.8rem', fontWeight: 700, textTransform: 'uppercase', letterSpacing: '2px', padding: '0.7rem 1.2rem', background: 'transparent', border: '2px solid #4a6fa5', color: '#4a6fa5', cursor: 'pointer' }}
                        >
                            + Emitir Desaparecido
                        </button>
                    )}
                </div>
            </div>

            {/* Town filter solo para Wanted */}
            {tabType === 'wanted' && (
                <div style={{ display: 'flex', alignItems: 'center', gap: '0.7rem', marginBottom: '2rem', flexWrap: 'wrap' }}>
                    <span style={{ fontFamily: 'Cinzel', fontSize: '0.65rem', color: '#8b5a2b', textTransform: 'uppercase', letterSpacing: '2px' }}>Se busca en:</span>
                    <button
                        onClick={() => setSelectedTown('all')}
                        style={{ fontFamily: 'Cinzel', fontSize: '0.7rem', textTransform: 'uppercase', letterSpacing: '1px', padding: '0.35rem 0.9rem', background: selectedTown === 'all' ? 'rgba(139,90,43,0.5)' : 'transparent', border: selectedTown === 'all' ? '1px solid #d4af37' : '1px solid #8b5a2b', color: selectedTown === 'all' ? '#d4af37' : '#c0a080', cursor: 'pointer', transition: 'all 0.2s' }}
                    >
                        Todos los Pueblos
                    </button>
                    {towns.map(t => (
                        <button
                            key={t}
                            onClick={() => setSelectedTown(t)}
                            style={{ fontFamily: 'Cinzel', fontSize: '0.7rem', textTransform: 'uppercase', letterSpacing: '1px', padding: '0.35rem 0.9rem', background: selectedTown === t ? 'rgba(139,90,43,0.5)' : 'transparent', border: selectedTown === t ? '1px solid #d4af37' : '1px solid #8b5a2b', color: selectedTown === t ? '#d4af37' : '#c0a080', cursor: 'pointer', transition: 'all 0.2s' }}
                        >
                            {t}
                        </button>
                    ))}
                </div>
            )}

            {loading ? (
                <div style={{ textAlign: 'center', color: '#c0a080', fontFamily: 'Cinzel', marginTop: '3rem' }}>Consultando los archivos...</div>
            ) : (
                <div className="wanted-grid">
                    {currentList.length === 0
                        ? <div className="wanted-empty">{view === 'active' ? (tabType === 'wanted' ? 'No hay carteles activos. El Estado está en paz...' : 'No hay personas desaparecidas registradas.') : 'El archivo está vacío.'}</div>
                        : currentList.map(p => (
                            <PosterCard 
                                key={p.id} 
                                poster={p} 
                                isMissing={tabType === 'missing'} 
                                exportingId={exportingId}
                                exportRefs={exportRefs}
                                handleExport={handleExport}
                                handleArchive={handleArchive}
                                handleDelete={handleDelete}
                                openEditWanted={openEditWanted}
                                openEditMissing={openEditMissing}
                                formatDate={formatDate}
                                formatReward={formatReward}
                            />
                        ))
                    }
                </div>
            )}

            {/* CREATE / EDIT MODAL */}
            {showModal && (
                <div className="wanted-modal-overlay" onClick={(e) => e.target === e.currentTarget && closeModal()}>
                    <div className="wanted-modal-content">
                        <h2 className="wanted-modal-title">
                            {editingId 
                                ? (modalType === 'missing' ? 'Editar Cartel de Desaparecido' : 'Editar Cartel de Se Busca') 
                                : (modalType === 'missing' ? 'Emitir Cartel de Desaparecido' : 'Emitir Cartel de Se Busca')
                            }
                        </h2>
                        
                        <form onSubmit={handleSubmit}>

                            {/* Photo */}
                            <div style={{ marginBottom: '1.2rem', textAlign: 'center' }}>
                                {photo && <img src={photo} alt="preview" style={{ width: '120px', height: '140px', objectFit: 'cover', border: '2px solid #8b5a2b', display: 'block', margin: '0 auto 0.7rem', filter: 'sepia(0.4)' }} />}
                                <label style={{ display: 'inline-block', background: 'transparent', border: '1px dashed #8b5a2b', color: '#c0a080', fontFamily: 'Cinzel', fontSize: '0.7rem', textTransform: 'uppercase', letterSpacing: '1px', padding: '0.5rem 1rem', cursor: 'pointer' }}>
                                    {photo ? 'Cambiar Fotografía' : 'Adjuntar Fotografía'}
                                    <input type="file" accept="image/*" style={{ display: 'none' }} onChange={handlePhotoUpload} />
                                </label>
                            </div>

                            {/* Name row */}
                            <div style={{ display: 'grid', gridTemplateColumns: modalType === 'missing' ? '1fr 1fr' : '1fr 1fr 1fr', gap: '0.7rem', marginBottom: '1rem' }}>
                                <div>
                                    <label style={{ display: 'block', fontFamily: 'Cinzel', fontSize: '0.65rem', color: '#8b5a2b', marginBottom: '0.3rem', textTransform: 'uppercase', letterSpacing: '1px' }}>Nombre *</label>
                                    <input required value={name} onChange={e => setName(e.target.value)} style={{ width: '100%', background: 'rgba(255,255,255,0.05)', border: '1px solid #8b5a2b', color: '#e5d8c5', fontFamily: 'Playfair Display', fontSize: '0.95rem', padding: '0.5rem' }} />
                                </div>
                                <div>
                                    <label style={{ display: 'block', fontFamily: 'Cinzel', fontSize: '0.65rem', color: '#8b5a2b', marginBottom: '0.3rem', textTransform: 'uppercase', letterSpacing: '1px' }}>Apellido {modalType === 'missing' && '*'}</label>
                                    <input required={modalType === 'missing'} value={surname} onChange={e => setSurname(e.target.value)} style={{ width: '100%', background: 'rgba(255,255,255,0.05)', border: '1px solid #8b5a2b', color: '#e5d8c5', fontFamily: 'Playfair Display', fontSize: '0.95rem', padding: '0.5rem' }} />
                                </div>
                                {modalType === 'wanted' && (
                                    <div>
                                        <label style={{ display: 'block', fontFamily: 'Cinzel', fontSize: '0.65rem', color: '#8b5a2b', marginBottom: '0.3rem', textTransform: 'uppercase', letterSpacing: '1px' }}>Mote / Alias</label>
                                        <input value={alias} onChange={e => setAlias(e.target.value)} style={{ width: '100%', background: 'rgba(255,255,255,0.05)', border: '1px solid #8b5a2b', color: '#e5d8c5', fontFamily: 'Playfair Display', fontSize: '0.95rem', padding: '0.5rem' }} placeholder='"El Coyote"' />
                                    </div>
                                )}
                            </div>

                            {modalType === 'missing' && (
                                <>
                                    <div style={{ marginBottom: '1rem' }}>
                                        <label style={{ display: 'block', fontFamily: 'Cinzel', fontSize: '0.65rem', color: '#8b5a2b', marginBottom: '0.3rem', textTransform: 'uppercase', letterSpacing: '1px' }}>Descripción de la Persona</label>
                                        <textarea value={description} onChange={e => setDescription(e.target.value)} rows="3" style={{ width: '100%', background: 'rgba(255,255,255,0.05)', border: '1px solid #8b5a2b', color: '#e5d8c5', fontFamily: 'Playfair Display', fontSize: '0.95rem', padding: '0.5rem', resize: 'vertical' }} placeholder="Ojos azules, cicatriz en la mejilla izquierda..." />
                                    </div>
                                    <div style={{ marginBottom: '1rem' }}>
                                        <label style={{ display: 'block', fontFamily: 'Cinzel', fontSize: '0.65rem', color: '#8b5a2b', marginBottom: '0.3rem', textTransform: 'uppercase', letterSpacing: '1px' }}>Último Lugar Visto *</label>
                                        <input required value={lastSeen} onChange={e => setLastSeen(e.target.value)} style={{ width: '100%', background: 'rgba(255,255,255,0.05)', border: '1px solid #8b5a2b', color: '#e5d8c5', fontFamily: 'Playfair Display', fontSize: '0.95rem', padding: '0.5rem' }} placeholder="Ej: Cerca de Valentine, saliendo en carreta..." />
                                    </div>
                                </>
                            )}

                            {/* Reward & Type */}
                            <div style={{ display: 'grid', gridTemplateColumns: modalType === 'missing' ? '1fr 1fr' : '1fr 1fr', gap: '0.7rem', marginBottom: '1rem' }}>
                                {modalType === 'missing' ? (
                                    <div style={{ display: 'flex', flexDirection: 'column', justifyContent: 'center' }}>
                                        <label style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', color: '#c0a080', fontFamily: 'Cinzel', fontSize: '0.75rem', textTransform: 'uppercase', letterSpacing: '1px', cursor: 'pointer', marginBottom: '0.3rem' }}>
                                            <input type="checkbox" checked={offerReward} onChange={e => setOfferReward(e.target.checked)} style={{ accentColor: '#8b5a2b', width: '16px', height: '16px' }} />
                                            Ofrecer Recompensa
                                        </label>
                                        {offerReward && (
                                            <input type="number" min="0" step="0.01" value={reward} onChange={e => setReward(e.target.value)} placeholder="Cantidad ($)" style={{ width: '100%', background: 'rgba(255,255,255,0.05)', border: '1px solid #8b5a2b', color: '#e5d8c5', fontFamily: 'Playfair Display', fontSize: '0.95rem', padding: '0.5rem', marginTop: '0.5rem' }} />
                                        )}
                                    </div>
                                ) : (
                                    <>
                                        <div>
                                            <label style={{ display: 'block', fontFamily: 'Cinzel', fontSize: '0.65rem', color: '#8b5a2b', marginBottom: '0.3rem', textTransform: 'uppercase', letterSpacing: '1px' }}>Recompensa ($)</label>
                                            <input type="number" min="0" step="0.01" value={reward} onChange={e => setReward(e.target.value)} placeholder="0" style={{ width: '100%', background: 'rgba(255,255,255,0.05)', border: '1px solid #8b5a2b', color: '#e5d8c5', fontFamily: 'Playfair Display', fontSize: '0.95rem', padding: '0.5rem' }} />
                                        </div>
                                        <div>
                                            <label style={{ display: 'block', fontFamily: 'Cinzel', fontSize: '0.65rem', color: '#8b5a2b', marginBottom: '0.3rem', textTransform: 'uppercase', letterSpacing: '1px' }}>Se busca</label>
                                            <select value={wantedType} onChange={e => setWantedType(e.target.value)} style={{ width: '100%', background: '#1a0f0a', border: '1px solid #8b5a2b', color: '#e5d8c5', fontFamily: 'Cinzel', fontSize: '0.8rem', padding: '0.5rem', appearance: 'auto' }}>
                                                <option value="VIVO">VIVO</option>
                                                <option value="VIVO O MUERTO">VIVO O MUERTO</option>
                                            </select>
                                        </div>
                                    </>
                                )}
                            </div>

                            {/* Town (Only Wanted) & Date */}
                            <div style={{ display: 'grid', gridTemplateColumns: modalType === 'missing' ? '1fr' : '1fr 1fr', gap: '0.7rem', marginBottom: '1rem' }}>
                                {modalType === 'wanted' && (
                                    <div>
                                        <label style={{ display: 'block', fontFamily: 'Cinzel', fontSize: '0.65rem', color: '#8b5a2b', marginBottom: '0.3rem', textTransform: 'uppercase', letterSpacing: '1px' }}>Se busca en (Pueblo)</label>
                                        <select value={town} onChange={e => setTown(e.target.value)} style={{ width: '100%', background: '#1a0f0a', border: '1px solid #8b5a2b', color: '#e5d8c5', fontFamily: 'Cinzel', fontSize: '0.8rem', padding: '0.5rem', appearance: 'auto' }}>
                                            <option value="Todos los Pueblos">Todos los Pueblos</option>
                                            {towns.map(t => <option key={t} value={t}>{t}</option>)}
                                        </select>
                                    </div>
                                )}
                                <div>
                                    <label style={{ display: 'block', fontFamily: 'Cinzel', fontSize: '0.65rem', color: '#8b5a2b', marginBottom: '0.3rem', textTransform: 'uppercase', letterSpacing: '1px' }}>Fecha de Emisión (1880)</label>
                                    <input type="date" value={publishedAt} onChange={e => setPublishedAt(e.target.value)} style={{ width: '100%', background: 'rgba(255,255,255,0.05)', border: '1px solid #8b5a2b', color: '#e5d8c5', fontFamily: 'Playfair Display', fontSize: '0.95rem', padding: '0.5rem', colorScheme: 'dark' }} />
                                </div>
                            </div>

                            {/* Dangerous (Only Wanted) */}
                            {modalType === 'wanted' && (
                                <div style={{ marginBottom: '1.5rem' }}>
                                    <label style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', color: '#c0a080', fontFamily: 'Cinzel', fontSize: '0.75rem', textTransform: 'uppercase', letterSpacing: '1px', cursor: 'pointer' }}>
                                        <input type="checkbox" checked={isDangerous} onChange={e => setIsDangerous(e.target.checked)} style={{ accentColor: '#8b0000', width: '16px', height: '16px' }} />
                                        ⚠ Individuo Peligroso
                                    </label>
                                </div>
                            )}

                            <div style={{ display: 'flex', gap: '1rem', justifyContent: 'flex-end', marginTop: modalType === 'missing' ? '1.5rem' : '0' }}>
                                <button type="button" onClick={closeModal} style={{ fontFamily: 'Cinzel', fontSize: '0.75rem', textTransform: 'uppercase', letterSpacing: '1px', padding: '0.6rem 1.2rem', background: 'transparent', border: '1px solid #8b5a2b', color: '#c0a080', cursor: 'pointer' }}>Cancelar</button>
                                <button type="submit" disabled={submitting} style={{ fontFamily: 'Cinzel', fontSize: '0.75rem', fontWeight: 700, textTransform: 'uppercase', letterSpacing: '1px', padding: '0.6rem 1.5rem', background: 'rgba(139,90,43,0.4)', border: modalType === 'missing' ? '2px solid #4a6fa5' : '2px solid #d4af37', color: modalType === 'missing' ? '#4a6fa5' : '#d4af37', cursor: 'pointer' }}>
                                    {submitting ? 'Sellando...' : (editingId ? 'Actualizar Cartel' : 'Emitir Cartel')}
                                </button>
                            </div>
                        </form>
                    </div>
                </div>
            )}
        </div>
    );
}

export default Wanted;

function PosterCard({ 
    poster, isMissing, exportingId, exportRefs, handleExport, 
    handleArchive, handleDelete, openEditWanted, openEditMissing, 
    formatDate, formatReward 
}) {
    const [sepiaPhoto, setSepiaPhoto] = useState(null);

    useEffect(() => {
        if (!poster.photo) return;
        const img = new Image();
        img.onload = () => {
            const canvas = document.createElement('canvas');
            canvas.width = img.width;
            canvas.height = img.height;
            const ctx = canvas.getContext('2d');
            ctx.filter = 'sepia(0.85) contrast(1.15) brightness(0.85)';
            ctx.drawImage(img, 0, 0);
            setSepiaPhoto(canvas.toDataURL('image/webp', 0.9));
        };
        img.src = poster.photo;
    }, [poster.photo]);
    
    const mName = isMissing ? poster.person_name : poster.fugitive_name;
    const mSurname = isMissing ? poster.person_surname : poster.fugitive_surname;

    return (
    <div className="wanted-card">
        {/* Hidden export version */}
        {exportingId === poster.id && (
                <div ref={el => exportRefs.current[poster.id] = el} className="wanted-export-poster">
                <div className="wep-inner">
                    <div className="wep-wanted-type">{isMissing ? 'DESAPARECIDO' : poster.wanted_type}</div>
                    
                    <div className="wep-photo">
                        {poster.photo
                            ? <img src={sepiaPhoto || poster.photo} alt="Person" />
                            : <div style={{ width: '100%', height: '100%', background: '#c8b88a', display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: 'Special Elite', color: '#1a0f0a', fontSize: '2rem' }}>SIN FOTO</div>
                        }
                    </div>
                    
                    <div className="wep-name">{mName} {mSurname}</div>
                    {!isMissing && poster.fugitive_alias && <div className="wep-alias">"{poster.fugitive_alias}"</div>}
                    
                    <div className="wep-town">
                        {isMissing 
                            ? `Visto por última vez en: ${poster.last_seen || 'Desconocido'}`
                            : `Buscado en: ${poster.town || 'Todos los Pueblos'}`}
                    </div>
                    
                    {!isMissing && poster.is_dangerous && <div className="wep-dangerous">PELIGROSO</div>}
                    
                    {(!isMissing || poster.offer_reward) && (
                        <div className="wep-reward-section">
                            <div className="wep-reward-amount">{formatReward(poster.reward_amount)}</div>
                        </div>
                    )}
                    
                    <div className="wep-footer-date">
                        Emitido el {formatDate(poster.published_at)}
                    </div>
                </div>
            </div>
        )}

        <div className="wanted-card-inner">
            <div className="wanted-type-badge">
                {isMissing ? 'DESAPARECIDO' : poster.wanted_type}
            </div>
            
            <div className="wanted-photo-container">
                {poster.photo
                    ? <img src={sepiaPhoto || poster.photo} alt="Persona" />
                    : <div className="wanted-no-photo" style={{ fontFamily: 'Special Elite', color: '#1a0f0a' }}>SIN FOTO</div>
                }
            </div>
            
            <div className="wanted-fugitive-name">
                {mName} {mSurname}
            </div>
            
            {!isMissing && poster.fugitive_alias && (
                <div className="wanted-fugitive-alias">"{poster.fugitive_alias}"</div>
            )}
            
            <div className="wanted-town-display">
                {isMissing 
                    ? (poster.last_seen || 'Desconocido')
                    : (poster.town || 'Todos los Pueblos')}
            </div>
            
            {!isMissing && poster.is_dangerous && (
                <div className="wanted-dangerous-display">PELIGROSO</div>
            )}
            
            {(!isMissing || poster.offer_reward) && (
                <div className="wanted-reward-section">
                    <div className="wanted-reward-amount">{formatReward(poster.reward_amount)}</div>
                </div>
            )}
            
            <div className="wanted-date">Emitido: {formatDate(poster.published_at)}</div>
        </div>

        <div className="wanted-card-actions">
            <button className="wanted-action-btn" onClick={() => handleExport(poster, isMissing)} disabled={exportingId === poster.id}>
                {exportingId === poster.id ? '...' : '📷 PNG'}
            </button>
            <button className="wanted-action-btn" onClick={() => isMissing ? openEditMissing(poster) : openEditWanted(poster)}>✏ Editar</button>
            <button className="wanted-action-btn archive" onClick={() => handleArchive(poster.id, isMissing)}>
                {poster.is_archived ? '↩ Activar' : '📦 Archivar'}
            </button>
            <button className="wanted-action-btn danger" onClick={() => handleDelete(poster.id, isMissing)}>🔥 Quemar</button>
        </div>
    </div>
    );
}
