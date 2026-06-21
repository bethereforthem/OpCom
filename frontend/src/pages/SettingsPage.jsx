import { useRef, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { useAuth } from '../contexts/AuthContext';
import { updateProfile, updateAvatar, updatePassword, updateSettings, uploadMedia } from '../api/client';
import Avatar from '../components/Avatar';
import LanguageSwitcher from '../components/LanguageSwitcher';

function Toggle({ checked, onChange }) {
    return (
        <button
            type="button"
            onClick={() => onChange(!checked)}
            className={`w-11 h-6 rounded-full relative transition-colors flex-shrink-0 ${checked ? 'bg-indigo-600' : 'bg-gray-600'}`}
        >
            <span className={`absolute top-0.5 left-0.5 w-5 h-5 bg-white rounded-full transition-transform ${checked ? 'translate-x-5' : ''}`} />
        </button>
    );
}

function Section({ title, children }) {
    return (
        <div className="bg-gray-800 rounded-xl border border-gray-700 p-5">
            <h2 className="text-white font-semibold mb-4">{title}</h2>
            <div className="space-y-4">{children}</div>
        </div>
    );
}

function Field({ label, children }) {
    return (
        <div>
            <label className="block text-sm text-gray-400 mb-1">{label}</label>
            {children}
        </div>
    );
}

const inputCls = 'w-full bg-gray-700 border border-gray-600 rounded-lg px-3 py-2 text-white text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500';

function SaveButton({ onClick, loading, children }) {
    return (
        <button onClick={onClick} disabled={loading}
            className="px-4 py-2 rounded-lg bg-indigo-600 hover:bg-indigo-500 text-white text-sm font-medium disabled:opacity-50 transition-colors">
            {children}
        </button>
    );
}

export default function SettingsPage() {
    const { t } = useTranslation();
    const navigate = useNavigate();
    const { user, updateUser } = useAuth();
    const fileInputRef = useRef(null);

    const [profile, setProfile] = useState({
        full_name: user?.full_name || '',
        username: user?.username || '',
        bio: user?.bio || '',
        status_message: user?.status_message || '',
    });
    const [profileMsg, setProfileMsg] = useState(null);
    const [profileSaving, setProfileSaving] = useState(false);
    const [avatarUploading, setAvatarUploading] = useState(false);

    const [theme, setTheme] = useState(user?.theme_preference || 'dark');
    const [notifSound, setNotifSound] = useState(user?.notif_sound_enabled ?? true);
    const [notifVibrate, setNotifVibrate] = useState(user?.notif_vibrate_enabled ?? true);
    const [readReceipts, setReadReceipts] = useState(user?.privacy_read_receipts ?? true);
    const [showTyping, setShowTyping] = useState(user?.privacy_show_typing ?? true);
    const [autoDownload, setAutoDownload] = useState(user?.chat_auto_download_media ?? false);
    const [textScale, setTextScale] = useState(user?.chat_message_text_scale || 'medium');
    const [settingsSaving, setSettingsSaving] = useState(false);
    const [settingsMsg, setSettingsMsg] = useState(null);

    const [pwForm, setPwForm] = useState({ current_password: '', new_password: '', confirm_password: '' });
    const [pwSaving, setPwSaving] = useState(false);
    const [pwMsg, setPwMsg] = useState(null);

    async function handleAvatarChange(e) {
        const file = e.target.files?.[0];
        if (!file) return;
        setAvatarUploading(true);
        try {
            const { data: uploaded } = await uploadMedia(file);
            const { data } = await updateAvatar(uploaded.media_id);
            // avatar_url is a deliberately stable path (same string every
            // upload, so it never expires) — but that means the <img> tag's
            // src never changes either, so the browser keeps showing the old
            // cached photo. Appending a cache-busting query param (the
            // backend route ignores its query string) forces a fresh fetch.
            updateUser({ avatar_url: `${data.avatar_url}?t=${Date.now()}` });
        } catch {
            setProfileMsg({ type: 'error', text: t('settings.profile.avatarFailed') });
        } finally {
            setAvatarUploading(false);
            e.target.value = '';
        }
    }

    async function saveProfile() {
        setProfileSaving(true);
        setProfileMsg(null);
        try {
            const { data } = await updateProfile(profile);
            updateUser(data.user);
            setProfileMsg({ type: 'success', text: t('settings.profile.saved') });
        } catch (err) {
            setProfileMsg({ type: 'error', text: err.response?.data?.error || t('settings.profile.failed') });
        } finally {
            setProfileSaving(false);
        }
    }

    async function saveSettings(extra = {}) {
        setSettingsSaving(true);
        setSettingsMsg(null);
        const payload = {
            theme_preference: theme,
            notif_sound_enabled: notifSound,
            notif_vibrate_enabled: notifVibrate,
            privacy_read_receipts: readReceipts,
            privacy_show_typing: showTyping,
            chat_auto_download_media: autoDownload,
            chat_message_text_scale: textScale,
            ...extra,
        };
        try {
            const { data } = await updateSettings(payload);
            updateUser(data.settings);
            setSettingsMsg({ type: 'success', text: t('settings.settingsSaved') });
        } catch {
            setSettingsMsg({ type: 'error', text: t('settings.settingsFailed') });
        } finally {
            setSettingsSaving(false);
        }
    }

    async function savePassword() {
        setPwMsg(null);
        if (pwForm.new_password !== pwForm.confirm_password) {
            setPwMsg({ type: 'error', text: t('settings.security.mismatch') });
            return;
        }
        setPwSaving(true);
        try {
            await updatePassword(pwForm.current_password, pwForm.new_password);
            setPwForm({ current_password: '', new_password: '', confirm_password: '' });
            setPwMsg({ type: 'success', text: t('settings.security.success') });
        } catch (err) {
            setPwMsg({ type: 'error', text: err.response?.data?.error || t('settings.security.failed') });
        } finally {
            setPwSaving(false);
        }
    }

    return (
        <div className="min-h-screen bg-gray-900">
            <header className="flex items-center justify-between px-4 py-2.5 bg-gray-800 border-b border-gray-700">
                <button onClick={() => navigate('/')} className="text-sm text-indigo-400 hover:text-indigo-300 transition-colors">
                    {t('settings.backToChat')}
                </button>
                <span className="font-semibold text-white text-sm">{t('settings.title')}</span>
                <span className="w-16" />
            </header>

            <div className="max-w-2xl mx-auto p-6 space-y-6">
                {/* Profile */}
                <Section title={t('settings.profile.title')}>
                    <div className="flex items-center gap-4">
                        <button onClick={() => fileInputRef.current?.click()} disabled={avatarUploading} className="relative">
                            <Avatar name={profile.full_name} url={user?.avatar_url} size="lg" />
                        </button>
                        <input ref={fileInputRef} type="file" accept="image/*" className="hidden" onChange={handleAvatarChange} />
                        <button onClick={() => fileInputRef.current?.click()} disabled={avatarUploading}
                            className="text-sm text-indigo-400 hover:text-indigo-300 transition-colors disabled:opacity-50">
                            {avatarUploading ? t('common.loading') : t('settings.profile.changePhoto')}
                        </button>
                    </div>

                    <Field label={t('settings.profile.fullNameLabel')}>
                        <input className={inputCls} value={profile.full_name}
                            onChange={e => setProfile(p => ({ ...p, full_name: e.target.value }))} />
                    </Field>
                    <Field label={t('settings.profile.usernameLabel')}>
                        <input className={inputCls} value={profile.username}
                            onChange={e => setProfile(p => ({ ...p, username: e.target.value }))} />
                    </Field>
                    <Field label={t('settings.profile.bioLabel')}>
                        <textarea className={inputCls} rows={2} placeholder={t('settings.profile.bioPlaceholder')}
                            value={profile.bio} onChange={e => setProfile(p => ({ ...p, bio: e.target.value }))} />
                    </Field>
                    <Field label={t('settings.profile.statusLabel')}>
                        <input className={inputCls} placeholder={t('settings.profile.statusPlaceholder')}
                            value={profile.status_message} onChange={e => setProfile(p => ({ ...p, status_message: e.target.value }))} />
                    </Field>

                    {profileMsg && (
                        <p className={`text-sm ${profileMsg.type === 'error' ? 'text-red-400' : 'text-green-400'}`}>{profileMsg.text}</p>
                    )}
                    <SaveButton onClick={saveProfile} loading={profileSaving}>
                        {profileSaving ? t('common.loading') : t('settings.profile.save')}
                    </SaveButton>
                </Section>

                {/* Appearance */}
                <Section title={t('settings.appearance.title')}>
                    <Field label={t('settings.appearance.theme')}>
                        <div className="flex gap-2">
                            {['dark', 'light', 'system'].map(opt => (
                                <button key={opt} type="button" onClick={() => setTheme(opt)}
                                    className={`flex-1 py-2 rounded-lg text-sm font-medium transition-colors
                                                ${theme === opt ? 'bg-indigo-600 text-white' : 'bg-gray-700 text-gray-300 hover:bg-gray-600'}`}>
                                    {t(`settings.appearance.theme${opt[0].toUpperCase()}${opt.slice(1)}`)}
                                </button>
                            ))}
                        </div>
                        <p className="text-xs text-gray-500 mt-1.5">{t('settings.appearance.themeWipNote')}</p>
                    </Field>
                    <Field label={t('settings.appearance.language')}>
                        <LanguageSwitcher />
                    </Field>
                </Section>

                {/* Notifications */}
                <Section title={t('settings.notifications.title')}>
                    <div className="flex items-center justify-between">
                        <span className="text-sm text-gray-300">{t('settings.notifications.sound')}</span>
                        <Toggle checked={notifSound} onChange={setNotifSound} />
                    </div>
                    <div className="flex items-center justify-between">
                        <span className="text-sm text-gray-300">{t('settings.notifications.vibrate')}</span>
                        <Toggle checked={notifVibrate} onChange={setNotifVibrate} />
                    </div>
                </Section>

                {/* Privacy */}
                <Section title={t('settings.privacy.title')}>
                    <div className="flex items-center justify-between">
                        <span className="text-sm text-gray-300">{t('settings.privacy.readReceipts')}</span>
                        <Toggle checked={readReceipts} onChange={setReadReceipts} />
                    </div>
                    <div className="flex items-center justify-between">
                        <span className="text-sm text-gray-300">{t('settings.privacy.showTyping')}</span>
                        <Toggle checked={showTyping} onChange={setShowTyping} />
                    </div>
                </Section>

                {/* Chat */}
                <Section title={t('settings.chat.title')}>
                    <div className="flex items-center justify-between">
                        <span className="text-sm text-gray-300">{t('settings.chat.autoDownload')}</span>
                        <Toggle checked={autoDownload} onChange={setAutoDownload} />
                    </div>
                    <Field label={t('settings.chat.textScale')}>
                        <div className="flex gap-2">
                            {['small', 'medium', 'large'].map(opt => (
                                <button key={opt} type="button" onClick={() => setTextScale(opt)}
                                    className={`flex-1 py-2 rounded-lg text-sm font-medium transition-colors
                                                ${textScale === opt ? 'bg-indigo-600 text-white' : 'bg-gray-700 text-gray-300 hover:bg-gray-600'}`}>
                                    {t(`settings.chat.textScale${opt[0].toUpperCase()}${opt.slice(1)}`)}
                                </button>
                            ))}
                        </div>
                    </Field>

                    {settingsMsg && (
                        <p className={`text-sm ${settingsMsg.type === 'error' ? 'text-red-400' : 'text-green-400'}`}>{settingsMsg.text}</p>
                    )}
                    <SaveButton onClick={() => saveSettings()} loading={settingsSaving}>
                        {settingsSaving ? t('common.loading') : t('common.save')}
                    </SaveButton>
                </Section>

                {/* Security */}
                <Section title={t('settings.security.title')}>
                    <Field label={t('settings.security.currentPasswordLabel')}>
                        <input type="password" className={inputCls} value={pwForm.current_password}
                            onChange={e => setPwForm(p => ({ ...p, current_password: e.target.value }))} />
                    </Field>
                    <Field label={t('settings.security.newPasswordLabel')}>
                        <input type="password" className={inputCls} value={pwForm.new_password}
                            onChange={e => setPwForm(p => ({ ...p, new_password: e.target.value }))} />
                    </Field>
                    <Field label={t('settings.security.confirmPasswordLabel')}>
                        <input type="password" className={inputCls} value={pwForm.confirm_password}
                            onChange={e => setPwForm(p => ({ ...p, confirm_password: e.target.value }))} />
                    </Field>

                    {pwMsg && (
                        <p className={`text-sm ${pwMsg.type === 'error' ? 'text-red-400' : 'text-green-400'}`}>{pwMsg.text}</p>
                    )}
                    <SaveButton onClick={savePassword} loading={pwSaving}>
                        {pwSaving ? t('common.loading') : t('settings.security.changePassword')}
                    </SaveButton>
                </Section>
            </div>
        </div>
    );
}
