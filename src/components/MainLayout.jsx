import { useState, useEffect } from 'react';
import { Outlet, Link, useNavigate, useLocation } from 'react-router-dom';
import { supabase } from '../supabaseClient';
import '../index.css';
import BOILogo from '../assets/logoboi.png';

function MainLayout() {
    const [profile, setProfile] = useState(null);
    const navigate = useNavigate();
    const location = useLocation();

    useEffect(() => {
        let mounted = true;

        const getProfile = async (session) => {
            if (!session?.user) return;

            try {
                const { data, error } = await supabase
                    .from('users')
                    .select('*')
                    .eq('id', session.user.id)
                    .single();

                if (error) {
                    console.error('Error fetching profile:', error);
                } else if (mounted) {
                    setProfile(data);
                }
            } catch (err) {
                console.error("Profile load error:", err);
            }
        };

        supabase.auth.getSession().then(({ data: { session } }) => {
            if (!session) {
                navigate('/');
            } else {
                getProfile(session);
            }
        });

        const { data: authListener } = supabase.auth.onAuthStateChange((event, session) => {
            if (event === 'SIGNED_OUT' || !session) {
                navigate('/');
            } else if (event === 'SIGNED_IN' || event === 'TOKEN_REFRESHED') {
                getProfile(session);
            }
        });

        return () => {
            mounted = false;
            authListener.subscription.unsubscribe();
        };
    }, [navigate]);

    const handleLogout = async () => {
        await supabase.auth.signOut();
        navigate('/');
    };

    const navItems = [
        { name: 'Tablón de anuncios', path: '/dashboard' },
        { name: 'Documentación', path: '/documentation' },
        { name: 'Casos', path: '/cases' },
        { name: 'Grupos Criminales', path: '/gangs' },
        { name: 'Incidentes', path: '/incidents' },
        { name: 'Mapa del Estado', path: '/crimemap' },
        { name: 'Personal', path: '/personnel' }
    ];

    return (
        <div className="layout-container">
            {/* Sidebar */}
            <aside className="sidebar">
                <div className="sidebar-header">
                    <img src={BOILogo} alt="BOI" className="sidebar-logo" />
                    <div className="sidebar-title">BUREAU OF INVESTIGATION</div>
                </div>

                <nav className="sidebar-nav">
                    {navItems.map((item) => (
                        <Link
                            key={item.path}
                            to={item.path}
                            className={`nav-item ${location.pathname === item.path ? 'active' : ''}`}
                        >
                            {item.name}
                        </Link>
                    ))}
                </nav>

                <div className="sidebar-footer">
                    {profile && (
                        <div className="user-profile-summary">
                            <div className="user-avatar-small">
                                {profile.profile_image ? (
                                    <img src={profile.profile_image} alt="Profile" />
                                ) : (
                                    <div className="user-avatar-initial" style={{width: '40px', height: '40px', borderRadius: '50%', backgroundColor: '#3b2b1d', color: '#d4af37', display: 'flex', justifyContent: 'center', alignItems: 'center', fontSize: '1.2rem', fontFamily: 'Cinzel, serif'}}>
                                        {profile.nombre ? profile.nombre[0].toUpperCase() : 'U'}
                                    </div>
                                )}
                            </div>
                            <div className="user-info">
                                <div className="user-name">{profile.rango} {profile.nombre} {profile.apellido}</div>
                                <div className="user-badge">{profile.rol}</div>
                            </div>
                        </div>
                    )}
                    <div className="sidebar-actions">
                        <button onClick={() => navigate('/profile')} className="action-btn">Editar Expediente</button>
                        <button onClick={handleLogout} className="action-btn logout">Cerrar Sesión</button>
                    </div>
                </div>
            </aside>

            {/* Main Content Area */}
            <main className="layout-content">
                <header className="content-header">
                    <h2 className="page-title">{navItems.find(i => i.path === location.pathname)?.name || 'Bureau of Investigation'}</h2>
                </header>
                <div className="content-body">
                    <Outlet />
                </div>
            </main>
        </div>
    );
}

export default MainLayout;
