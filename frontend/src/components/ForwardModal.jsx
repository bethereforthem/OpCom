import { useState } from 'react';
import { useTranslation } from 'react-i18next';

function convName(conv, currentUserId, t) {
    if (conv.type === 'group') return conv.name || t('chat.newChat.group');
    const other = conv.conversation_members?.find(m => m.users?.id !== currentUserId);
    return other?.users?.full_name || t('common.unknown');
}

export default function ForwardModal({ message, conversations, currentUserId, onClose, onForward }) {
    const { t } = useTranslation();
    const [selected, setSelected] = useState(new Set());
    const [sending, setSending]   = useState(false);
    const [error, setError]       = useState('');

    function toggle(id) {
        setSelected(prev => {
            const next = new Set(prev);
            next.has(id) ? next.delete(id) : next.add(id);
            return next;
        });
    }

    async function handleSend() {
        if (selected.size === 0) return;
        setSending(true);
        setError('');
        try {
            await onForward(message.id, [...selected]);
            onClose();
        } catch {
            setError(t('chat.forward.failed'));
        } finally {
            setSending(false);
        }
    }

    return (
        <div className="fixed inset-0 z-30 flex items-center justify-center bg-black/60">
            <div className="bg-gray-800 rounded-2xl p-6 w-96 border border-gray-700 shadow-2xl">
                <h3 className="text-white font-semibold text-lg mb-1">{t('chat.forward.title')}</h3>
                <p className="text-gray-400 text-sm mb-4 truncate">
                    {message.type === 'text' ? message.content : t('chat.forward.mediaMessage')}
                </p>

                <div className="max-h-64 overflow-y-auto space-y-1 mb-4">
                    {conversations.map(conv => (
                        <label key={conv.id}
                            className="flex items-center gap-3 px-3 py-2 rounded-lg hover:bg-gray-700 cursor-pointer">
                            <input
                                type="checkbox"
                                checked={selected.has(conv.id)}
                                onChange={() => toggle(conv.id)}
                                className="rounded"
                            />
                            <span className="text-sm text-gray-200">{convName(conv, currentUserId, t)}</span>
                        </label>
                    ))}
                    {conversations.length === 0 && (
                        <p className="text-gray-500 text-sm px-3 py-2">{t('chat.forward.noConversations')}</p>
                    )}
                </div>

                {error && <p className="text-red-400 text-sm mb-3">{error}</p>}

                <div className="flex gap-2">
                    <button onClick={onClose}
                        className="flex-1 py-2 rounded-lg bg-gray-700 text-gray-300 hover:bg-gray-600 text-sm transition-colors">
                        {t('common.cancel')}
                    </button>
                    <button onClick={handleSend} disabled={selected.size === 0 || sending}
                        className="flex-1 py-2 rounded-lg bg-indigo-600 hover:bg-indigo-500 text-white text-sm font-medium disabled:opacity-50 transition-colors">
                        {sending ? t('chat.forward.forwarding') : `${t('chat.forward.forward')}${selected.size ? ` (${selected.size})` : ''}`}
                    </button>
                </div>
            </div>
        </div>
    );
}
