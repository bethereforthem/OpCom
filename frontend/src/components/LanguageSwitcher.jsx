import { useTranslation } from 'react-i18next';
import { useAuth } from '../contexts/AuthContext';
import { setLocale as persistLocale } from '../api/client';

// Native-script labels — these never change with the active language, so a
// French speaker viewing the English UI by mistake can still find "Français".
const LANGUAGES = [
    { code: 'en', label: 'English' },
    { code: 'fr', label: 'Français' },
    { code: 'rw', label: 'Ikinyarwanda' },
];

export default function LanguageSwitcher({ className = '' }) {
    const { i18n } = useTranslation();
    const { user } = useAuth();

    async function handleChange(e) {
        const locale = e.target.value;
        i18n.changeLanguage(locale);
        if (user) {
            try { await persistLocale(locale); } catch { /* keep the local UI change even if the sync fails */ }
        }
    }

    return (
        <select
            value={i18n.language}
            onChange={handleChange}
            className={`bg-gray-700 border border-gray-600 rounded-lg text-sm text-gray-200 px-2 py-1.5
                        focus:outline-none focus:ring-2 focus:ring-indigo-500 ${className}`}
        >
            {LANGUAGES.map(l => (
                <option key={l.code} value={l.code}>{l.label}</option>
            ))}
        </select>
    );
}
