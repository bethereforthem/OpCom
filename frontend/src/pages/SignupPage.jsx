import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Link, useNavigate } from 'react-router-dom';
import { signup } from '../api/client';
import LanguageSwitcher from '../components/LanguageSwitcher';

export default function SignupPage() {
    const { t, i18n } = useTranslation();
    const navigate = useNavigate();

    const [fullName, setFullName]   = useState('');
    const [username, setUsername]   = useState('');
    const [email, setEmail]         = useState('');
    const [staffId, setStaffId]     = useState('');
    const [password, setPassword]   = useState('');
    const [error, setError]         = useState('');
    const [done, setDone]           = useState(false);
    const [loading, setLoading]     = useState(false);

    async function handleSubmit(e) {
        e.preventDefault();
        setError('');
        setLoading(true);
        try {
            await signup({
                full_name: fullName.trim(),
                username: username.trim(),
                email: email.trim() || undefined,
                staff_id: staffId.trim() || undefined,
                password,
                locale: i18n.language,
            });
            setDone(true);
        } catch (err) {
            setError(err.response?.data?.error || t('auth.signup.failed'));
        } finally {
            setLoading(false);
        }
    }

    if (done) {
        return (
            <div className="min-h-screen flex items-center justify-center bg-gray-900 px-4">
                <div className="w-full max-w-sm text-center">
                    <div className="inline-flex items-center justify-center w-16 h-16 rounded-2xl bg-green-600 mb-4">
                        <svg className="w-8 h-8 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                        </svg>
                    </div>
                    <h1 className="text-xl font-bold text-white mb-2">{t('auth.signup.doneTitle')}</h1>
                    <p className="text-gray-400 text-sm mb-8">
                        {t('auth.signup.doneMessage')}
                    </p>
                    <Link to="/login" className="text-indigo-400 hover:text-indigo-300 text-sm font-medium">
                        {t('auth.signup.backToSignIn')}
                    </Link>
                </div>
            </div>
        );
    }

    return (
        <div className="min-h-screen flex items-center justify-center bg-gray-900 px-4">
            <div className="w-full max-w-sm">
                <div className="flex justify-end mb-4">
                    <LanguageSwitcher />
                </div>

                <div className="text-center mb-8">
                    <div className="inline-flex items-center justify-center w-16 h-16 rounded-2xl bg-indigo-600 mb-4">
                        <svg className="w-8 h-8 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2}
                                d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
                        </svg>
                    </div>
                    <h1 className="text-2xl font-bold text-white">{t('auth.signup.title')}</h1>
                    <p className="text-gray-400 text-sm mt-1">{t('auth.signup.subtitle')}</p>
                </div>

                <form onSubmit={handleSubmit} className="space-y-4">
                    <div>
                        <label className="block text-sm font-medium text-gray-300 mb-1">{t('auth.signup.fullNameLabel')}</label>
                        <input value={fullName} onChange={e => setFullName(e.target.value)} required
                            className="w-full bg-gray-800 border border-gray-700 rounded-lg px-4 py-2.5 text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-indigo-500"
                            placeholder={t('auth.signup.fullNamePlaceholder')} />
                    </div>

                    <div>
                        <label className="block text-sm font-medium text-gray-300 mb-1">{t('auth.signup.usernameLabel')}</label>
                        <input value={username} onChange={e => setUsername(e.target.value)} required
                            className="w-full bg-gray-800 border border-gray-700 rounded-lg px-4 py-2.5 text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-indigo-500"
                            placeholder={t('auth.signup.usernamePlaceholder')} />
                    </div>

                    <div className="grid grid-cols-2 gap-3">
                        <div>
                            <label className="block text-sm font-medium text-gray-300 mb-1">{t('auth.signup.emailLabel')}</label>
                            <input type="email" value={email} onChange={e => setEmail(e.target.value)}
                                className="w-full bg-gray-800 border border-gray-700 rounded-lg px-3 py-2.5 text-white placeholder-gray-500 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
                                placeholder={t('auth.signup.optionalPlaceholder')} />
                        </div>
                        <div>
                            <label className="block text-sm font-medium text-gray-300 mb-1">{t('auth.signup.staffIdLabel')}</label>
                            <input value={staffId} onChange={e => setStaffId(e.target.value)}
                                className="w-full bg-gray-800 border border-gray-700 rounded-lg px-3 py-2.5 text-white placeholder-gray-500 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
                                placeholder={t('auth.signup.optionalPlaceholder')} />
                        </div>
                    </div>

                    <div>
                        <label className="block text-sm font-medium text-gray-300 mb-1">{t('auth.signup.passwordLabel')}</label>
                        <input type="password" value={password} onChange={e => setPassword(e.target.value)} required minLength={8}
                            className="w-full bg-gray-800 border border-gray-700 rounded-lg px-4 py-2.5 text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-indigo-500"
                            placeholder={t('auth.signup.passwordPlaceholder')} />
                    </div>

                    {error && (
                        <div className="bg-red-900/40 border border-red-700 rounded-lg px-4 py-2.5 text-red-400 text-sm">
                            {error}
                        </div>
                    )}

                    <button type="submit" disabled={loading}
                        className="w-full bg-indigo-600 hover:bg-indigo-500 disabled:opacity-50 text-white font-semibold py-2.5 rounded-lg transition-colors">
                        {loading ? t('auth.signup.creating') : t('auth.signup.create')}
                    </button>
                </form>

                <p className="text-center text-sm text-gray-500 mt-6">
                    {t('auth.signup.haveAccount')}{' '}
                    <Link to="/login" className="text-indigo-400 hover:text-indigo-300 font-medium">{t('auth.signup.signInLink')}</Link>
                </p>
            </div>
        </div>
    );
}
