import { useState, useEffect, useRef } from 'react';
import { supabase } from '../supabaseClient';
import html2canvas from 'html2canvas';
import './WantedRDR.css';

function Wanted() {
    const [view, setView] = useState('active'); // 'active' | 'archived'
    const [posters, setPosters] = useState({ active: [], archived: [] });
    const [loading, setLoading] = useState(true);
    const [showModal, setShowModal] = useState(false);
    const [editingId, setEditingId] = useState(null);
    const [submitting, setSubmitting] = useState(false);
    const [exportingId, setExportingId] = useState(null);

    // Towns list
    const towns = ['Saint Denis', 'Rhodes', 'Valentine', 'Annesburg', 'Blackwater', 'Strawberry', 'Armadillo', 'Tumbleweed'];

    // State mapping
    const getStateName = (t) => {
        if (!t) return 'Estado de New Hanover';
        const tn = t.toLowerCase();
        if (tn === 'tumbleweed' || tn === 'armadillo') return 'Estado de New Austin';
        if (tn === 'blackwater' || tn === 'strawberry') return 'Estado de West Elizabeth';
        if (tn === 'valentine' || tn === 'annesburg') return 'Estado de New Hanover';
        if (tn === 'rhodes' || tn === 'saint denis') return 'Estado de Lemoyne';
        return 'Estado de New Hanover';
    };

    // Date helper
    const getToday1880 = () => {
        const d = new Date();
        const mm = String(d.getMonth() + 1).padStart(2, '0');
        const dd = String(d.getDate()).padStart(2, '0');
        return `1880-${mm}-${dd}`;
    };

    // Form fields
    const [photo, setPhoto] = useState('');
    const [name, setName] = useState('');
    const [surname, setSurname] = useState('');
    const [alias, setAlias] = useState('');
    const [town, setTown] = useState('Valentine');
    const [reward, setReward] = useState('');
    const [wantedType, setWantedType] = useState('VIVO O MUERTO');
    const [isDangerous, setIsDangerous] = useState(false);
    const [publishedAt, setPublishedAt] = useState(getToday1880());

    // Refs for export
    const exportRefs = useRef({});

    useEffect(() => { loadPosters(); }, []);

    const loadPosters = async () => {
        setLoading(true);
        try {
            const { data, error } = await supabase.rpc('get_wanted_posters');
            if (error) throw error;
            if (data) setPosters(data);
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
        setTown('Valentine');
        setReward(''); setWantedType('VIVO O MUERTO'); setIsDangerous(false);
        setPublishedAt(getToday1880());
    };

    const openEdit = (poster) => {
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

    const handleSubmit = async (e) => {
        e.preventDefault();
        setSubmitting(true);
        try {
            const p_published = new Date(publishedAt + 'T12:00:00Z').toISOString();
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
            closeModal();
            loadPosters();
        } catch (err) { alert('Error al guardar: ' + err.message); } finally { setSubmitting(false); }
    };

    const handleArchive = async (id) => {
        try {
            const { error } = await supabase.rpc('archive_wanted_poster', { p_id: id });
            if (error) throw error;
            loadPosters();
        } catch (err) { alert('Error al archivar: ' + err.message); }
    };

    const handleDelete = async (id) => {
        if (!window.confirm('¿Quemar este cartel permanentemente?')) return;
        try {
            const { error } = await supabase.rpc('delete_wanted_poster', { p_id: id });
            if (error) throw error;
            loadPosters();
        } catch (err) { alert('Error al quemar: ' + err.message); }
    };

    const handleExport = async (poster) => {
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
            link.download = `cartel_${poster.fugitive_name}_${poster.fugitive_surname || ''}.png`;
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

    const PosterCard = ({ poster }) => (
        <div className="wanted-card">
            {/* Hidden export version */}
            {exportingId === poster.id && (
                    <div ref={el => exportRefs.current[poster.id] = el} className="wanted-export-poster">
                    <div className="wep-inner">
                        <div className="wep-main-block">
                            <div className="wep-bureau">Bureau of Investigation — {getStateName(poster.town)}</div>
                            <div className="wep-wanted">WANTED</div>
                            <div className="wep-photo">
                                {poster.photo
                                    ? <img src={poster.photo} alt="Fugitive" />
                                    : <div style={{ width: '100%', height: '100%', background: '#c8b88a', display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: 'Cinzel', color: '#7a4f1d', fontSize: '1rem' }}>SIN FOTO</div>
                                }
                            </div>
                            <div className="wep-name">{poster.fugitive_name} {poster.fugitive_surname}</div>
                            {poster.fugitive_alias && <div className="wep-alias">"{poster.fugitive_alias}"</div>}
                            <div className="wep-type">{poster.wanted_type}</div>
                            <div style={{ fontSize: '1.1rem', color: '#5c3a15', textTransform: 'uppercase', letterSpacing: '3px', fontWeight: 'bold', fontFamily: 'Cinzel, serif', marginBottom: '8px' }}>BUSCANDO EN: {poster.town || 'Desconocido'}</div>
                            {poster.is_dangerous && <div className="wep-dangerous">⚠ INDIVIDUO PELIGROSO ⚠</div>}
                            <div className="wep-reward-section">
                                <div className="wep-reward-label">Recompensa</div>
                                <div className="wep-reward-amount">{formatReward(poster.reward_amount)}</div>
                            </div>
                        </div>
                        <div className="wep-footer">
                            Emitido el {formatDate(poster.published_at)} — Contacte a su Oficial más cercano
                        </div>
                    </div>
                </div>
            )}

            <div className="wanted-card-inner">
                <div style={{ position: 'absolute', top: '10px', left: '0', width: '100%', textAlign: 'center', fontFamily: 'Cinzel', fontSize: '0.5rem', color: 'rgba(92, 58, 21, 0.6)', textTransform: 'uppercase', letterSpacing: '1px' }}>
                    Bureau of Investigation — {getStateName(poster.town)}
                </div>
                <div className="wanted-label-wanted">WANTED</div>
                <div className="wanted-photo-container">
                    {poster.photo
                        ? <img src={poster.photo} alt="Fugitivo" />
                        : <div className="wanted-no-photo">SIN FOTOGRAFÍA<br />DISPONIBLE</div>
                    }
                </div>
                <div className="wanted-fugitive-name">
                    {poster.fugitive_name} {poster.fugitive_surname}
                </div>
                {poster.fugitive_alias && (
                    <div className="wanted-fugitive-alias" style={{ marginBottom: '0.2rem' }}>"{poster.fugitive_alias}"</div>
                )}
                <div style={{ fontSize: '0.75rem', color: '#5c3a15', textTransform: 'uppercase', letterSpacing: '1px', fontWeight: 'bold' }}>BUSCANDO EN: {poster.town || 'Desconocido'}</div>
                <div className="wanted-type-badge">{poster.wanted_type}</div>
                {poster.is_dangerous && <div className="wanted-dangerous-badge">⚠ individuo peligroso ⚠</div>}
                <div className="wanted-reward-section">
                    <div className="wanted-reward-label">Recompensa</div>
                    <div className="wanted-reward-amount">{formatReward(poster.reward_amount)}</div>
                </div>
                <div className="wanted-date">Emitido: {formatDate(poster.published_at)}</div>
            </div>

            <div className="wanted-card-actions">
                <button className="wanted-action-btn" onClick={() => handleExport(poster)} disabled={exportingId === poster.id}>
                    {exportingId === poster.id ? '...' : '📷 PNG'}
                </button>
                <button className="wanted-action-btn" onClick={() => openEdit(poster)}>✏ Editar</button>
                <button className="wanted-action-btn archive" onClick={() => handleArchive(poster.id)}>
                    {poster.is_archived ? '↩ Activar' : '📦 Archivar'}
                </button>
                <button className="wanted-action-btn danger" onClick={() => handleDelete(poster.id)}>🔥 Quemar</button>
            </div>
        </div>
    );

    const currentList = view === 'active' ? posters.active : posters.archived;

    return (
        <div className="wanted-container">
            <div className="wanted-header">
                <h1 className="wanted-title">Carteles de Se Busca</h1>
                <p className="wanted-subtitle">Archivo de Fugitivos — Bureau of Investigation</p>
            </div>

            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '2rem', flexWrap: 'wrap', gap: '1rem' }}>
                <div className="wanted-tabs">
                    <button className={`wanted-tab${view === 'active' ? ' active' : ''}`} onClick={() => setView('active')}>
                        📋 Carteles Activos ({posters.active?.length || 0})
                    </button>
                    <button className={`wanted-tab${view === 'archived' ? ' active' : ''}`} onClick={() => setView('archived')}>
                        📦 Archivo ({posters.archived?.length || 0})
                    </button>
                </div>
                <button
                    onClick={() => setShowModal(true)}
                    style={{ fontFamily: 'Cinzel', fontSize: '0.85rem', fontWeight: 700, textTransform: 'uppercase', letterSpacing: '2px', padding: '0.7rem 1.5rem', background: 'rgba(139,90,43,0.4)', border: '2px solid #d4af37', color: '#d4af37', cursor: 'pointer' }}
                >
                    + Emitir Nuevo Cartel
                </button>
            </div>

            {loading ? (
                <div style={{ textAlign: 'center', color: '#c0a080', fontFamily: 'Cinzel', marginTop: '3rem' }}>Consultando los archivos...</div>
            ) : (
                <div className="wanted-grid">
                    {currentList.length === 0
                        ? <div className="wanted-empty">{view === 'active' ? 'No hay carteles activos. El Estado está en paz...' : 'El archivo está vacío.'}</div>
                        : currentList.map(p => <PosterCard key={p.id} poster={p} />)
                    }
                </div>
            )}

            {/* CREATE / EDIT MODAL */}
            {showModal && (
                <div className="wanted-modal-overlay" onClick={(e) => e.target === e.currentTarget && closeModal()}>
                    <div className="wanted-modal-content">
                        <h2 className="wanted-modal-title">{editingId ? 'Editar Cartel' : 'Emitir Cartel'}</h2>
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
                            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: '0.7rem', marginBottom: '1rem' }}>
                                <div>
                                    <label style={{ display: 'block', fontFamily: 'Cinzel', fontSize: '0.65rem', color: '#8b5a2b', marginBottom: '0.3rem', textTransform: 'uppercase', letterSpacing: '1px' }}>Nombre *</label>
                                    <input required value={name} onChange={e => setName(e.target.value)} style={{ width: '100%', background: 'rgba(255,255,255,0.05)', border: '1px solid #8b5a2b', color: '#e5d8c5', fontFamily: 'Playfair Display', fontSize: '0.95rem', padding: '0.5rem' }} />
                                </div>
                                <div>
                                    <label style={{ display: 'block', fontFamily: 'Cinzel', fontSize: '0.65rem', color: '#8b5a2b', marginBottom: '0.3rem', textTransform: 'uppercase', letterSpacing: '1px' }}>Apellido</label>
                                    <input value={surname} onChange={e => setSurname(e.target.value)} style={{ width: '100%', background: 'rgba(255,255,255,0.05)', border: '1px solid #8b5a2b', color: '#e5d8c5', fontFamily: 'Playfair Display', fontSize: '0.95rem', padding: '0.5rem' }} />
                                </div>
                                <div>
                                    <label style={{ display: 'block', fontFamily: 'Cinzel', fontSize: '0.65rem', color: '#8b5a2b', marginBottom: '0.3rem', textTransform: 'uppercase', letterSpacing: '1px' }}>Mote / Alias</label>
                                    <input value={alias} onChange={e => setAlias(e.target.value)} style={{ width: '100%', background: 'rgba(255,255,255,0.05)', border: '1px solid #8b5a2b', color: '#e5d8c5', fontFamily: 'Playfair Display', fontSize: '0.95rem', padding: '0.5rem' }} placeholder='"El Coyote"' />
                                </div>
                            </div>

                            {/* Reward & Type */}
                            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '0.7rem', marginBottom: '1rem' }}>
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
                            </div>

                            {/* Town & Date */}
                            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '0.7rem', marginBottom: '1rem' }}>
                                <div>
                                    <label style={{ display: 'block', fontFamily: 'Cinzel', fontSize: '0.65rem', color: '#8b5a2b', marginBottom: '0.3rem', textTransform: 'uppercase', letterSpacing: '1px' }}>Visto en (Pueblo)</label>
                                    <select value={town} onChange={e => setTown(e.target.value)} style={{ width: '100%', background: '#1a0f0a', border: '1px solid #8b5a2b', color: '#e5d8c5', fontFamily: 'Cinzel', fontSize: '0.8rem', padding: '0.5rem', appearance: 'auto' }}>
                                        {towns.map(t => <option key={t} value={t}>{t}</option>)}
                                    </select>
                                </div>
                                <div>
                                    <label style={{ display: 'block', fontFamily: 'Cinzel', fontSize: '0.65rem', color: '#8b5a2b', marginBottom: '0.3rem', textTransform: 'uppercase', letterSpacing: '1px' }}>Fecha de Emisión (1880)</label>
                                    <input type="date" value={publishedAt} onChange={e => setPublishedAt(e.target.value)} style={{ width: '100%', background: 'rgba(255,255,255,0.05)', border: '1px solid #8b5a2b', color: '#e5d8c5', fontFamily: 'Playfair Display', fontSize: '0.95rem', padding: '0.5rem', colorScheme: 'dark' }} />
                                </div>
                            </div>

                            {/* Dangerous */}
                            <div style={{ marginBottom: '1.5rem' }}>
                                <label style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', color: '#c0a080', fontFamily: 'Cinzel', fontSize: '0.75rem', textTransform: 'uppercase', letterSpacing: '1px', cursor: 'pointer' }}>
                                    <input type="checkbox" checked={isDangerous} onChange={e => setIsDangerous(e.target.checked)} style={{ accentColor: '#8b0000', width: '16px', height: '16px' }} />
                                    ⚠ Individuo Peligroso
                                </label>
                            </div>

                            <div style={{ display: 'flex', gap: '1rem', justifyContent: 'flex-end' }}>
                                <button type="button" onClick={closeModal} style={{ fontFamily: 'Cinzel', fontSize: '0.75rem', textTransform: 'uppercase', letterSpacing: '1px', padding: '0.6rem 1.2rem', background: 'transparent', border: '1px solid #8b5a2b', color: '#c0a080', cursor: 'pointer' }}>Cancelar</button>
                                <button type="submit" disabled={submitting} style={{ fontFamily: 'Cinzel', fontSize: '0.75rem', fontWeight: 700, textTransform: 'uppercase', letterSpacing: '1px', padding: '0.6rem 1.5rem', background: 'rgba(139,90,43,0.4)', border: '2px solid #d4af37', color: '#d4af37', cursor: 'pointer' }}>
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
