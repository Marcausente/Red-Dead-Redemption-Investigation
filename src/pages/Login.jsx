import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { supabase } from '../supabaseClient';
import '../index.css';
import './LoginRDR.css';
import USSLogo from '../assets/USS logo.png';
import BOILogo from '../assets/logoboi.png';

function Login() {
    const [email, setEmail] = useState('');
    const [password, setPassword] = useState('');
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState(null);
    const navigate = useNavigate();

    const handleLogin = async (e) => {
        e.preventDefault();
        setLoading(true);
        setError(null);

        const { data, error } = await supabase.auth.signInWithPassword({
            email,
            password,
        });

        if (error) {
            setError(error.message);
            setLoading(false);
        } else {
            // Successful login
            navigate('/welcome');
        }
    };

    return (
        <div className="rdr-login-container">
            {/* Background Texture Overlay */}
            <div className="rdr-background-overlay"></div>

            {/* Header */}
            <header className="rdr-header">
                <img src={USSLogo} alt="USS Logo" className="rdr-header-logo" />
                <div className="rdr-header-title-container">
                    <h1 className="rdr-header-title">United States Sheriff</h1>
                    <div className="rdr-header-subtitle">Bureau of Investigation</div>
                </div>
                <img src={BOILogo} alt="BOI Logo" className="rdr-header-logo" />
            </header>

            {/* Main Content */}
            <main className="rdr-main-content">
                <div className="rdr-login-card">
                    <div className="rdr-login-header">
                        <h2>Authorized Access</h2>
                        <p>Identify yourself, Deputy.</p>
                    </div>

                    <form onSubmit={handleLogin}>
                        <div className="rdr-form-group">
                            <label className="rdr-form-label">Email:</label>
                            <input
                                type="email"
                                className="rdr-form-input"
                                value={email}
                                onChange={(e) => setEmail(e.target.value)}
                                placeholder="Ex: amorgan@uss.gov"
                                required
                            />
                        </div>

                        <div className="rdr-form-group">
                            <label className="rdr-form-label">Password</label>
                            <input
                                type="password"
                                className="rdr-form-input"
                                value={password}
                                onChange={(e) => setPassword(e.target.value)}
                                placeholder="••••••••"
                                required
                            />
                        </div>

                        {error && <div style={{ color: '#8b0000', marginBottom: '1rem', textAlign: 'center', fontWeight: 'bold' }}>{error}</div>}

                        <button type="submit" className="rdr-login-button" disabled={loading}>
                            {loading ? 'Authenticating...' : 'Access System'}
                        </button>
                    </form>
                </div>
            </main>
        </div>
    );
}

export default Login;
