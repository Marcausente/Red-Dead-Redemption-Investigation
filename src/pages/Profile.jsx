import { useState, useEffect, useRef } from 'react';
import { createPortal } from 'react-dom';
import AvatarEditor from 'react-avatar-editor';
import { supabase } from '../supabaseClient';
import '../index.css';
import './DashboardRDR.css';
import './ProfileRDR.css';

function Profile() {
    const [loading, setLoading] = useState(true);
    const [updating, setUpdating] = useState(false);
    const [message, setMessage] = useState(null);
    const fileInputRef = useRef(null);
    const editorRef = useRef(null);

    // Cropper State
    const [editorOpen, setEditorOpen] = useState(false);
    const [imageSrc, setImageSrc] = useState(null);
    const [scale, setScale] = useState(1.2);

    const [formData, setFormData] = useState({
        nombre: '',
        apellido: '',
        rango: '',
        rol: '',
        profile_image: ''
    });

    const [passwords, setPasswords] = useState({
        newPassword: '',
        confirmPassword: ''
    });

    // DB Usage State
    const [dbUsage, setDbUsage] = useState(null);

    useEffect(() => {
        fetchProfile();
    }, []);

    const fetchProfile = async () => {
        try {
            setLoading(true);
            const { data: { user } } = await supabase.auth.getUser();

            if (!user) throw new Error('Usuario encriptado no encontrado');

            const { data, error } = await supabase
                .from('users')
                .select('*')
                .eq('id', user.id)
                .single();

            if (error) throw error;

            if (data) {
                setFormData({
                    nombre: data.nombre || '',
                    apellido: data.apellido || '',
                    rango: data.rango || '',
                    rol: data.rol || 'Externo',
                    profile_image: data.profile_image || ''
                });

                // Helper to check if admin
                if (data.rol === 'Administrador') {
                    fetchDbUsage();
                }
            }
        } catch (error) {
            console.error('Error fetching profile:', error.message);
        } finally {
            setLoading(false);
        }
    };

    const fetchDbUsage = async () => {
        try {
            const { data, error } = await supabase.rpc('get_db_usage');
            if (error) throw error;
            setDbUsage(data);
        } catch (err) {
            console.error("Failed to fetch DB usage:", err);
        }
    };

    const handleChange = (e) => {
        setFormData({ ...formData, [e.target.name]: e.target.value });
    };

    const handlePasswordChange = (e) => {
        setPasswords({ ...passwords, [e.target.name]: e.target.value });
    };

    // --- Image Handling ---
    const handleImageClick = () => {
        fileInputRef.current.click();
    };

    const handleFileChange = (event) => {
        const file = event.target.files[0];
        if (file) {
            if (file.size > 10000000) { 
                alert("La fotografía es demasiado pesada, elige una más pequeña.");
            }
            setImageSrc(file);
            setEditorOpen(true);
            event.target.value = '';
        }
    };

    const handleSaveImage = () => {
        if (editorRef.current) {
            const canvas = editorRef.current.getImageScaledToCanvas();

            // WebP Compression
            const dataUrl = canvas.toDataURL('image/webp', 0.6);
            setFormData({ ...formData, profile_image: dataUrl });
            setEditorOpen(false);
            setImageSrc(null);
            setScale(1.2);
        }
    };

    const handleCancelImage = () => {
        setEditorOpen(false);
        setImageSrc(null);
        setScale(1.2);
    };

    const handleSubmit = async (e) => {
        e.preventDefault();
        setUpdating(true);
        setMessage(null);

        try {
            const { data: { user } } = await supabase.auth.getUser();
            if (!user) throw new Error('Usuario desaparecido');

            // Update Profile Data
            const { error: profileError } = await supabase
                .from('users')
                .update({
                    nombre: formData.nombre,
                    apellido: formData.apellido,
                    rango: formData.rango,
                    profile_image: formData.profile_image,
                    updated_at: new Date()
                })
                .eq('id', user.id);

            if (profileError) throw profileError;

            // Update Password if provided
            if (passwords.newPassword) {
                if (passwords.newPassword !== passwords.confirmPassword) {
                    throw new Error("Las constraseñas no coinciden en el telégrafo.");
                }
                const { error: passwordError } = await supabase.auth.updateUser({
                    password: passwords.newPassword
                });
                if (passwordError) throw passwordError;
            }

            setMessage({ type: 'success', text: 'Expediente actualizado exitosamente.' });
            setPasswords({ newPassword: '', confirmPassword: '' });

        } catch (error) {
            setMessage({ type: 'error', text: error.message });
        } finally {
            setUpdating(false);
        }
    };

    if (loading) return <div style={{ textAlign: 'center', marginTop: '50px', fontFamily: 'Cinzel', color: '#c0a080', fontSize: '1.2rem' }}>Revisando el archivador...</div>;

    // Permissions
    const canEditRank = ['Coordinador', 'Administrador', 'Jefatura'].includes(formData.rol);

    // Storage formatting
    const formatBytes = (bytes, decimals = 2) => {
        if (!+bytes) return '0 Bytes';
        const k = 1024;
        const dm = decimals < 0 ? 0 : decimals;
        const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
        const i = Math.floor(Math.log(bytes) / Math.log(k));
        return `${parseFloat((bytes / Math.pow(k, i)).toFixed(dm))} ${sizes[i]}`;
    };

    // Calculate Storage % (Assuming 500MB Limit for free tier visualization interaction)
    const MAX_STORAGE_BYTES = 500 * 1024 * 1024; // 500 MB
    const usedBytes = dbUsage ? dbUsage.used_bytes : 0;
    const usagePercent = Math.min(100, Math.max(0, (usedBytes / MAX_STORAGE_BYTES) * 100));

    return (
        <div className="rdr-profile-container">
            <h2 className="rdr-profile-title">MI EXPEDIENTE</h2>

            {message && (
                <div style={{
                    padding: '1rem',
                    marginBottom: '1rem',
                    backgroundColor: message.type === 'success' ? 'rgba(74, 222, 128, 0.1)' : 'rgba(239, 68, 68, 0.1)',
                    border: `1px solid ${message.type === 'success' ? '#4ade80' : '#ef4444'}`,
                    borderRadius: '4px',
                    color: message.type === 'success' ? '#4ade80' : '#ef4444',
                    textAlign: 'center'
                }}>
                    {message.text}
                </div>
            )}

            <form onSubmit={handleSubmit} className="rdr-profile-layout">
                {/* Left Column: Form */}
                <div className="rdr-profile-form-section">
                    <h3 className="rdr-profile-h3">DATOS DEL AGENTE</h3>
                    
                    <div className="rdr-form-group">
                        <label className="rdr-form-label">Nombre</label>
                        <input
                            type="text"
                            className="rdr-form-input"
                            name="nombre"
                            value={formData.nombre}
                            onChange={handleChange}
                            required
                        />
                    </div>

                    <div className="rdr-form-group">
                        <label className="rdr-form-label">Apellido</label>
                        <input
                            type="text"
                            className="rdr-form-input"
                            name="apellido"
                            value={formData.apellido}
                            onChange={handleChange}
                            required
                        />
                    </div>

                    <div className="rdr-form-group">
                        <label className="rdr-form-label">Rango Jerárquico {canEditRank ? '(Modificable por Alta Estructura)' : '(Bloqueado)'}</label>
                        {canEditRank ? (
                            <select
                                className="rdr-form-input"
                                style={{appearance: 'auto'}}
                                name="rango"
                                value={formData.rango}
                                onChange={handleChange}
                            >
                                <option value="Marshal">Marshal</option>
                                <option value="Sheriff de Condado">Sheriff de Condado</option>
                                <option value="Sheriff de Pueblo">Sheriff de Pueblo</option>
                                <option value="Ayudante del Sheriff">Ayudante del Sheriff</option>
                                <option value="Oficial Supervisor">Oficial Supervisor</option>
                                <option value="Oficial">Oficial</option>
                                <option value="Aguacil de Primera">Aguacil de Primera</option>
                                <option value="Aguacil de Segunda">Aguacil de Segunda</option>
                                <option value="Recluta">Recluta</option>
                            </select>
                        ) : (
                            <input
                                type="text"
                                className="rdr-form-input"
                                value={formData.rango}
                                disabled
                            />
                        )}
                    </div>

                    <div className="rdr-profile-divider"></div>

                    <h3 className="rdr-profile-h3">SEGURIDAD (TELÉGRAFO)</h3>
                    
                    <div className="rdr-form-group">
                        <label className="rdr-form-label">Nueva Contraseña</label>
                        <input
                            type="password"
                            className="rdr-form-input"
                            name="newPassword"
                            value={passwords.newPassword}
                            onChange={handlePasswordChange}
                            placeholder="Dejar en blanco para mantener"
                        />
                    </div>

                    <div className="rdr-form-group">
                        <label className="rdr-form-label">Confirmar Contraseña</label>
                        <input
                            type="password"
                            className="rdr-form-input"
                            name="confirmPassword"
                            value={passwords.confirmPassword}
                            onChange={handlePasswordChange}
                        />
                    </div>

                    <div style={{textAlign: 'right', marginTop: '2rem'}}>
                        <button
                            type="submit"
                            className="rdr-btn-brown"
                            style={{padding: '0.8rem 2rem'}}
                            disabled={updating}
                        >
                            {updating ? 'Sellando...' : 'GUARDAR CAMBIOS'}
                        </button>
                    </div>
                </div>

                {/* Right Column: Image */}
                <div className="rdr-profile-image-section">
                    <input
                        type="file"
                        ref={fileInputRef}
                        onChange={handleFileChange}
                        accept="image/*"
                        style={{ display: 'none' }}
                    />

                    <div className="rdr-profile-uploader" onClick={handleImageClick}>
                        {formData.profile_image ? (
                            <img src={formData.profile_image} alt="Profile" />
                        ) : (
                            <div style={{color: '#c0a080', fontFamily: 'Cinzel', fontSize: '3.5rem'}}>
                                {formData.nombre ? formData.nombre.charAt(0).toUpperCase() : '?'}
                            </div>
                        )}
                        <div className="rdr-profile-overlay">
                            <span>REVELAR NUEVA FOTO</span>
                        </div>
                    </div>

                    {/* Database Usage Statistic */}
                    {formData.rol === 'Administrador' && dbUsage && (
                        <div className="rdr-telemetry-block">
                            <h4 className="rdr-telemetry-title">
                                ALMACÉN (Admin)
                            </h4>

                            <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.8rem', color: '#ebd5b3' }}>
                                <span>{formatBytes(usedBytes)}</span>
                                <span>500 MB Max</span>
                            </div>

                            <div className="rdr-telemetry-bar-bg">
                                <div className="rdr-telemetry-bar-fill" style={{
                                    width: `${usagePercent}%`,
                                    backgroundColor: usagePercent > 80 ? '#8b0000' : (usagePercent > 50 ? '#d4af37' : '#4ade80')
                                }} />
                            </div>
                            <div style={{ fontSize: '0.75rem', color: '#c0a080', marginTop: '0.5rem', textAlign: 'right' }}>
                                {usagePercent.toFixed(1)}% ocupado
                            </div>
                        </div>
                    )}
                </div>
            </form>

            {/* Image Cropper Modal */}
            {editorOpen && createPortal(
                <div className="rdr-modal-overlay" style={{zIndex: 4000}}>
                    <div className="rdr-modal-content">
                        <h3 style={{textAlign: 'center', marginBottom: '1.5rem'}}>RECORTAR FOTOGRAFÍA</h3>
                        <div style={{ display: 'flex', justifyContent: 'center', margin: '2rem 0' }}>
                            <AvatarEditor
                                ref={editorRef}
                                image={imageSrc}
                                width={180}
                                height={180}
                                border={[20, 20]}
                                color={[26, 15, 10, 0.8]}
                                scale={scale}
                            />
                        </div>

                        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '1.5rem' }}>
                            <div style={{ display: 'flex', alignItems: 'center', gap: '1rem', color: '#d4af37' }}>
                                <span>-</span>
                                <input
                                    type="range"
                                    min="1"
                                    max="3"
                                    step="0.01"
                                    value={scale}
                                    style={{accentColor: '#8b5a2b', width: '200px'}}
                                    onChange={(e) => setScale(parseFloat(e.target.value))}
                                />
                                <span>+</span>
                            </div>

                            <div style={{ display: 'flex', gap: '1rem' }}>
                                <button type="button" className="rdr-btn-brown" style={{background: 'transparent', borderColor: '#8b5a2b', color: '#c0a080'}} onClick={handleCancelImage}>Cancelar</button>
                                <button type="button" className="rdr-btn-brown" onClick={handleSaveImage}>Fijar Foto WebP</button>
                            </div>
                        </div>
                    </div>
                </div>,
                document.body
            )}
        </div>
    );
}

export default Profile;
