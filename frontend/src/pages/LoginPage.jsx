import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { useNavigate, Link } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';
import { login } from '../api/client';
import LanguageSwitcher from '../components/LanguageSwitcher';

export default function LoginPage() {
    const { t }           = useTranslation();
    const navigate       = useNavigate();
    const { completeLogin } = useAuth();

    const [identifier, setIdentifier] = useState('');
    const [password, setPassword]     = useState('');
    const [error, setError]           = useState('');
    const [loading, setLoading]       = useState(false);

    async function handleSubmit(e) {
        e.preventDefault();
        setError('');
        setLoading(true);

        try {
            const { data } = await login(identifier, password);

            if (data.mfa_required) {
                navigate('/mfa', {
                    state: {
                        preAuthToken: data.pre_auth_token,
                        mfaMethod:    data.mfa_method,
                    },
                });
            } else {
                completeLogin(data.token);
                navigate('/');
            }
        } catch (err) {
            setError(err.response?.data?.error || t('auth.login.failed'));
        } finally {
            setLoading(false);
        }
    }

    return (
        <div className="min-h-screen flex items-center justify-center bg-gray-900 px-4">
            <div className="w-full max-w-sm">
                <div className="flex justify-end mb-4">
                    <LanguageSwitcher />
                </div>

                {/* Logo / header */}
                <div className="text-center mb-10">
                    <div className="inline-flex items-center justify-center w-16 h-16 rounded-2xl bg-indigo-600 mb-4">
                        <svg className="w-8 h-8 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2}
                                d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
                        </svg>
                    </div>
                    <h1 className="text-2xl font-bold text-white">{t('common.appName')}</h1>
                    <p className="text-gray-400 text-sm mt-1">{t('auth.login.tagline')}</p>
                </div>

                <form onSubmit={handleSubmit} className="space-y-4">
                    <div>
                        <label className="block text-sm font-medium text-gray-300 mb-1">
                            {t('auth.login.identifierLabel')}
                        </label>
                        <input
                            type="text"
                            value={identifier}
                            onChange={e => setIdentifier(e.target.value)}
                            required
                            autoFocus
                            className="w-full bg-gray-800 border border-gray-700 rounded-lg px-4 py-2.5
                                       text-white placeholder-gray-500 focus:outline-none
                                       focus:ring-2 focus:ring-indigo-500 focus:border-transparent"
                            placeholder={t('auth.login.identifierPlaceholder')}
                        />
                    </div>

                    <div>
                        <label className="block text-sm font-medium text-gray-300 mb-1">{t('auth.login.passwordLabel')}</label>
                        <input
                            type="password"
                            value={password}
                            onChange={e => setPassword(e.target.value)}
                            required
                            className="w-full bg-gray-800 border border-gray-700 rounded-lg px-4 py-2.5
                                       text-white placeholder-gray-500 focus:outline-none
                                       focus:ring-2 focus:ring-indigo-500 focus:border-transparent"
                            placeholder={t('auth.login.passwordPlaceholder')}
                        />
                    </div>

                    {error && (
                        <div className="bg-red-900/40 border border-red-700 rounded-lg px-4 py-2.5 text-red-400 text-sm">
                            {error}
                        </div>
                    )}

                    <button
                        type="submit"
                        disabled={loading}
                        className="w-full bg-indigo-600 hover:bg-indigo-500 disabled:opacity-50
                                   text-white font-semibold py-2.5 rounded-lg transition-colors"
                    >
                        {loading ? t('auth.login.signingIn') : t('auth.login.signIn')}
                    </button>
                </form>

                <p className="text-center text-sm text-gray-500 mt-6">
                    {t('auth.login.needAccount')}{' '}
                    <Link to="/signup" className="text-indigo-400 hover:text-indigo-300 font-medium">{t('auth.login.signUpLink')}</Link>
                </p>

                <p className="text-center text-xs text-gray-600 mt-4">
                    {t('auth.login.restricted')}
                </p>
            </div>
        </div>
    );
}
