import { useState, useRef, useEffect } from 'react';
import { useTranslation } from 'react-i18next';
import { useNavigate, useLocation } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';
import { mfaVerify } from '../api/client';

export default function MfaPage() {
    const { t }                 = useTranslation();
    const navigate              = useNavigate();
    const { state }             = useLocation();
    const { completeLogin }     = useAuth();

    const [digits, setDigits]   = useState(['', '', '', '', '', '']);
    const [error, setError]     = useState('');
    const [loading, setLoading] = useState(false);
    const inputRefs             = useRef([]);

    useEffect(() => {
        if (!state?.preAuthToken) navigate('/login');
        else inputRefs.current[0]?.focus();
    }, []);

    function handleDigitChange(idx, val) {
        if (!/^\d?$/.test(val)) return;
        const next = [...digits];
        next[idx] = val;
        setDigits(next);
        if (val && idx < 5) inputRefs.current[idx + 1]?.focus();
    }

    function handleKeyDown(idx, e) {
        if (e.key === 'Backspace' && !digits[idx] && idx > 0) {
            inputRefs.current[idx - 1]?.focus();
        }
    }

    function handlePaste(e) {
        const pasted = e.clipboardData.getData('text').replace(/\D/g, '').slice(0, 6);
        if (!pasted) return;
        e.preventDefault();
        const next = [...digits];
        pasted.split('').forEach((d, i) => { next[i] = d; });
        setDigits(next);
        inputRefs.current[Math.min(pasted.length, 5)]?.focus();
    }

    async function handleSubmit(e) {
        e.preventDefault();
        const code = digits.join('');
        if (code.length < 6) return;
        setError('');
        setLoading(true);

        try {
            const { data } = await mfaVerify(state.preAuthToken, code);
            completeLogin(data.token);
            navigate('/');
        } catch (err) {
            setError(err.response?.data?.error || t('auth.mfa.invalidCode'));
            setDigits(['', '', '', '', '', '']);
            inputRefs.current[0]?.focus();
        } finally {
            setLoading(false);
        }
    }

    const methodLabel = state?.mfaMethod === 'totp'
        ? t('auth.mfa.totpInstructions')
        : t('auth.mfa.emailInstructions');

    return (
        <div className="min-h-screen flex items-center justify-center bg-gray-900 px-4">
            <div className="w-full max-w-sm text-center">
                <div className="inline-flex items-center justify-center w-16 h-16 rounded-2xl bg-indigo-600 mb-6">
                    <svg className="w-8 h-8 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2}
                            d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" />
                    </svg>
                </div>

                <h1 className="text-2xl font-bold text-white mb-2">{t('auth.mfa.title')}</h1>
                <p className="text-gray-400 text-sm mb-8">{methodLabel}</p>

                <form onSubmit={handleSubmit}>
                    <div className="flex justify-center gap-3 mb-6" onPaste={handlePaste}>
                        {digits.map((d, i) => (
                            <input
                                key={i}
                                ref={el => inputRefs.current[i] = el}
                                type="text"
                                inputMode="numeric"
                                maxLength={1}
                                value={d}
                                onChange={e => handleDigitChange(i, e.target.value)}
                                onKeyDown={e => handleKeyDown(i, e)}
                                className="w-12 h-14 text-center text-xl font-bold bg-gray-800
                                           border border-gray-700 rounded-lg text-white
                                           focus:outline-none focus:ring-2 focus:ring-indigo-500"
                            />
                        ))}
                    </div>

                    {error && (
                        <div className="bg-red-900/40 border border-red-700 rounded-lg px-4 py-2.5 text-red-400 text-sm mb-4">
                            {error}
                        </div>
                    )}

                    <button
                        type="submit"
                        disabled={loading || digits.join('').length < 6}
                        className="w-full bg-indigo-600 hover:bg-indigo-500 disabled:opacity-50
                                   text-white font-semibold py-2.5 rounded-lg transition-colors"
                    >
                        {loading ? t('auth.mfa.verifying') : t('auth.mfa.verify')}
                    </button>

                    <button type="button" onClick={() => navigate('/login')}
                        className="mt-3 w-full text-gray-500 hover:text-gray-300 text-sm transition-colors">
                        {t('auth.mfa.backToLogin')}
                    </button>
                </form>
            </div>
        </div>
    );
}
