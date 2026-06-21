import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { useSocket } from '../contexts/SocketContext';
import { getNotifications, markNotificationRead } from '../api/client';
import { formatDistanceToNow } from '../utils/time';

export default function NotificationBell() {
    const { t } = useTranslation();
    const { on } = useSocket();
    const [notifications, setNotifications] = useState([]);
    const [open, setOpen]                   = useState(false);
    const [loaded, setLoaded]               = useState(false);

    const unreadCount = notifications.filter(n => !n.is_read).length;

    async function load() {
        const { data } = await getNotifications({ limit: 20 });
        setNotifications(data.notifications || []);
        setLoaded(true);
    }

    useEffect(() => { load(); }, []);
    useEffect(() => on('mention_received', load), [on]);

    function toggleOpen() {
        setOpen(o => !o);
        if (!loaded) load();
    }

    async function handleOpenNotification(n) {
        if (!n.is_read) {
            await markNotificationRead(n.id);
            setNotifications(prev => prev.map(x => x.id === n.id ? { ...x, is_read: true } : x));
        }
    }

    return (
        <div className="relative">
            <button onClick={toggleOpen}
                className="relative w-8 h-8 rounded-full bg-gray-700 hover:bg-gray-600 flex items-center justify-center transition-colors">
                <svg className="w-4 h-4 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2}
                        d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9" />
                </svg>
                {unreadCount > 0 && (
                    <span className="absolute -top-1 -right-1 bg-red-600 text-white text-[10px] rounded-full w-4 h-4 flex items-center justify-center">
                        {unreadCount > 9 ? '9+' : unreadCount}
                    </span>
                )}
            </button>

            {open && (
                <div className="absolute right-0 mt-2 w-80 bg-gray-800 border border-gray-700 rounded-xl shadow-2xl z-30 max-h-96 overflow-y-auto">
                    <div className="px-4 py-3 border-b border-gray-700 text-sm font-semibold text-white">{t('chat.notifications.title')}</div>
                    {notifications.length === 0 && (
                        <p className="text-center text-gray-500 text-sm py-8">{t('chat.notifications.empty')}</p>
                    )}
                    {notifications.map(n => (
                        <button key={n.id} onClick={() => handleOpenNotification(n)}
                            className={`w-full text-left px-4 py-3 border-b border-gray-700/50 hover:bg-gray-700/40 transition-colors
                                        ${!n.is_read ? 'bg-indigo-900/20' : ''}`}>
                            <p className="text-sm text-gray-200">{n.title}</p>
                            {n.body && <p className="text-xs text-gray-400 truncate mt-0.5">{n.body}</p>}
                            <p className="text-xs text-gray-600 mt-1">{formatDistanceToNow(n.created_at)}</p>
                        </button>
                    ))}
                </div>
            )}
        </div>
    );
}
