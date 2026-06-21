import { createContext, useContext, useState, useEffect } from 'react';
import { getMe, logout as apiLogout } from '../api/client';
import i18n from '../i18n';

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
    const [user, setUser]           = useState(null);
    const [token, setToken]         = useState(() => localStorage.getItem('opcom_token'));
    const [loading, setLoading]     = useState(true);

    // Fetch the user profile whenever the token changes (mount, login, mfa verify)
    useEffect(() => {
        if (!token) { setUser(null); setLoading(false); return; }
        setLoading(true);
        getMe()
            .then(r => {
                setUser(r.data.user);
                if (r.data.user?.locale) i18n.changeLanguage(r.data.user.locale);
            })
            .catch(() => { localStorage.removeItem('opcom_token'); setToken(null); })
            .finally(() => setLoading(false));
    }, [token]);

    function completeLogin(newToken) {
        localStorage.setItem('opcom_token', newToken);
        setToken(newToken);
    }

    // Merges a partial update (the response from a profile/avatar/settings
    // PATCH) into the in-memory user so every screen reading `user` reflects
    // the change immediately, without a full re-fetch.
    function updateUser(patch) {
        setUser(prev => prev ? { ...prev, ...patch } : prev);
    }

    async function logout() {
        try { await apiLogout(); } catch {}
        localStorage.removeItem('opcom_token');
        setToken(null);
        setUser(null);
    }

    return (
        <AuthContext.Provider value={{ user, token, loading, completeLogin, logout, updateUser }}>
            {children}
        </AuthContext.Provider>
    );
}

export const useAuth = () => useContext(AuthContext);
