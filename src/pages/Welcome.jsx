import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { supabase } from '../supabaseClient';
import '../index.css';
import './WelcomeRDR.css';

function Welcome() {
    const [profile, setProfile] = useState(null);
    const navigate = useNavigate();

    useEffect(() => {
        const fetchProfile = async () => {
            const { data: { user } } = await supabase.auth.getUser();
            if (!user) {
                navigate('/');
                return;
            }

            const { data, error } = await supabase
                .from('users')
                .select('*')
                .eq('id', user.id)
                .single();

            if (error) {
                console.error('Error fetching profile:', error);
                navigate('/dashboard'); // Fallback
            } else {
                setProfile(data);
                // Redirect after delay
                setTimeout(() => {
                    navigate('/dashboard');
                }, 4000); // 4 seconds total welcome time
            }
        };

        fetchProfile();
    }, [navigate]);

    if (!profile) {
        // While fetching, keep the container dark with background but no text
        return (
            <div className="rdr-welcome-container">
                <div className="rdr-welcome-overlay"></div>
            </div>
        );
    }

    return (
        <div className="rdr-welcome-container">
            <div className="rdr-welcome-overlay"></div>
            
            <div className="rdr-welcome-content">
                <div className="rdr-welcome-avatar rdr-fade-in-avatar">
                    {profile.profile_image ? (
                        <img src={profile.profile_image} alt="Profile" />
                    ) : (
                        // Fallback avatar using initial
                        <div className="rdr-welcome-initial">{profile.nombre ? profile.nombre[0].toUpperCase() : 'U'}</div>
                    )}
                </div>

                <h1 className="rdr-welcome-title rdr-fade-in-scale">BIENVENIDO</h1>
                <h2 className="rdr-welcome-subtitle rdr-fade-in-delayed">
                    {profile.rango} {profile.nombre} {profile.apellido}
                </h2>
                <div className="rdr-welcome-line rdr-expand-line"></div>
            </div>
        </div>
    );
}

export default Welcome;
