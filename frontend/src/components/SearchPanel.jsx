import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { searchMessages, lookupUser } from '../api/client';
import { formatTime } from '../utils/time';

function snippet(msg, t) {
    if (msg.type === 'text') return msg.content;
    return { image: t('chat.bubble.photo'), audio: t('chat.bubble.audioType'), video: t('chat.bubble.videoType'), document: t('chat.bubble.documentType') }[msg.type] || t('common.media');
}

export default function SearchPanel({ onClose, onOpenConversation }) {
    const { t } = useTranslation();
    const [q, setQ]               = useState('');
    const [senderUsername, setSenderUsername] = useState('');
    const [fromDate, setFromDate] = useState('');
    const [toDate, setToDate]     = useState('');
    const [mediaType, setMediaType] = useState('');
    const [results, setResults]   = useState(null);
    const [loading, setLoading]   = useState(false);
    const [error, setError]       = useState('');

    const MEDIA_TYPES = [
        { value: '',         label: t('chat.search.anyType') },
        { value: 'text',     label: t('chat.search.text') },
        { value: 'image',    label: t('chat.search.photos') },
        { value: 'video',    label: t('chat.search.videos') },
        { value: 'audio',    label: t('chat.search.audio') },
        { value: 'document', label: t('chat.search.documents') },
    ];

    async function handleSearch(e) {
        e.preventDefault();
        setLoading(true);
        setError('');
        try {
            let sender_id;
            if (senderUsername.trim()) {
                try {
                    const { data } = await lookupUser(senderUsername.trim());
                    sender_id = data.user.id;
                } catch {
                    setResults([]);
                    setError(t('chat.search.noUserFound', { username: senderUsername.trim() }));
                    setLoading(false);
                    return;
                }
            }

            const { data } = await searchMessages({
                q: q.trim() || undefined,
                sender_id,
                from_date: fromDate || undefined,
                to_date: toDate || undefined,
                media_type: mediaType || undefined,
            });
            setResults(data.messages);
        } catch {
            setError(t('chat.search.failed'));
        } finally {
            setLoading(false);
        }
    }

    return (
        <div className="fixed inset-0 z-30 flex items-center justify-center bg-black/60">
            <div className="bg-gray-800 rounded-2xl p-6 w-[32rem] max-h-[80vh] flex flex-col border border-gray-700 shadow-2xl">
                <div className="flex items-center justify-between mb-4">
                    <h3 className="text-white font-semibold text-lg">{t('chat.search.title')}</h3>
                    <button onClick={onClose} className="text-gray-400 hover:text-white text-sm">✕</button>
                </div>

                <form onSubmit={handleSearch} className="space-y-3 flex-shrink-0">
                    <input value={q} onChange={e => setQ(e.target.value)} placeholder={t('chat.search.textPlaceholder')}
                        className="w-full bg-gray-700 border border-gray-600 rounded-lg px-3 py-2 text-white text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />

                    <div className="grid grid-cols-2 gap-3">
                        <input value={senderUsername} onChange={e => setSenderUsername(e.target.value)} placeholder={t('chat.search.senderPlaceholder')}
                            className="bg-gray-700 border border-gray-600 rounded-lg px-3 py-2 text-white text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
                        <select value={mediaType} onChange={e => setMediaType(e.target.value)}
                            className="bg-gray-700 border border-gray-600 rounded-lg px-3 py-2 text-white text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500">
                            {MEDIA_TYPES.map(t2 => <option key={t2.value} value={t2.value}>{t2.label}</option>)}
                        </select>
                    </div>

                    <div className="grid grid-cols-2 gap-3">
                        <input type="date" value={fromDate} onChange={e => setFromDate(e.target.value)}
                            className="bg-gray-700 border border-gray-600 rounded-lg px-3 py-2 text-white text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
                        <input type="date" value={toDate} onChange={e => setToDate(e.target.value)}
                            className="bg-gray-700 border border-gray-600 rounded-lg px-3 py-2 text-white text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
                    </div>

                    <button type="submit" disabled={loading}
                        className="w-full py-2 rounded-lg bg-indigo-600 hover:bg-indigo-500 text-white text-sm font-medium disabled:opacity-50 transition-colors">
                        {loading ? t('common.searching') : t('common.search')}
                    </button>
                </form>

                {error && <p className="text-red-400 text-sm mt-3">{error}</p>}

                <div className="flex-1 overflow-y-auto mt-4 space-y-1">
                    {results?.length === 0 && !error && (
                        <p className="text-center text-gray-500 text-sm py-8">{t('chat.search.noResults')}</p>
                    )}
                    {results?.map(m => (
                        <button key={m.id} onClick={() => onOpenConversation(m.conversation_id)}
                            className="w-full text-left px-3 py-2 rounded-lg hover:bg-gray-700/50 transition-colors">
                            <div className="flex justify-between items-baseline">
                                <span className="text-sm font-medium text-gray-200">{m.users?.full_name || t('common.unknown')}</span>
                                <span className="text-xs text-gray-500">{formatTime(m.created_at)}</span>
                            </div>
                            <p className="text-xs text-gray-400 truncate">{snippet(m, t)}</p>
                            <p className="text-xs text-indigo-400 mt-0.5">
                                {m.conversations?.type === 'group'
                                    ? t('chat.search.inGroup', { name: m.conversations?.name || t('chat.newChat.group') })
                                    : t('chat.search.inDirectMessage')}
                            </p>
                        </button>
                    ))}
                </div>
            </div>
        </div>
    );
}
