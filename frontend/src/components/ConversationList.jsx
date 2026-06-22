import { useMemo, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { formatDistanceToNow } from '../utils/time';
import Avatar from './Avatar';

export function isEffectivelyMuted(conv) {
    if (!conv?.is_muted) return false;
    return conv.muted_until === null || new Date(conv.muted_until) > new Date();
}

function getOtherMember(conv, currentUserId) {
    return conv.conversation_members?.find(m => m.users?.id !== currentUserId) ?? null;
}

function getDisplayName(conv, currentUserId, t) {
    if (conv.type === 'group') return conv.name || t('common.unknown');
    return getOtherMember(conv, currentUserId)?.users?.full_name || t('common.unknown');
}

function getAvatarUrl(conv, currentUserId) {
    if (conv.type === 'group') return conv.avatar_url;
    return getOtherMember(conv, currentUserId)?.users?.avatar_url;
}

// Tick state for a message this user sent: 'read' > 'delivered' > 'sent'.
function deliveryState(message) {
    if (message.message_status?.some(s => s.read_at)) return 'read';
    if (message.message_status?.some(s => s.delivered_at)) return 'delivered';
    return 'sent';
}

function getLastMessagePreview(conv, currentUserId, t) {
    const msg = conv.last_message;
    if (!msg) return { text: '', isMine: false, ticks: null };

    const senderId = msg.sender_id ?? msg.users?.id;
    const isMine = senderId === currentUserId;

    if (msg.is_deleted) {
        return { text: isMine ? t('chat.bubble.youDeleted') : t('chat.bubble.messageDeleted'), isMine, ticks: isMine ? deliveryState(msg) : null };
    }

    const body = msg.type === 'text'
        ? (msg.content ?? '')
        : ({ image: t('chat.bubble.photo'), audio: t('chat.bubble.audioType'), video: t('chat.bubble.videoType'), document: t('chat.bubble.documentType') }[msg.type] || t('common.media'));

    let text = body;
    if (conv.type === 'group') {
        const senderName = isMine
            ? t('chat.list.you')
            : (msg.users?.full_name || conv.conversation_members?.find(m => m.users?.id === senderId)?.users?.full_name || t('common.unknown'));
        text = `${senderName}: ${body}`;
    }

    return { text, isMine, ticks: isMine ? deliveryState(msg) : null };
}

function Ticks({ state }) {
    if (!state) return null;
    const color = state === 'read' ? 'text-indigo-400' : 'text-gray-500';
    return <span className={`text-xs flex-shrink-0 ${color}`}>{state === 'sent' ? '✓' : '✓✓'}</span>;
}

// Hover-revealed "⋮" menu for pin/archive/mute actions.
function ConvMenu({ isArchived, muted, pinned, onArchive, onUnarchive, onMute, onUnmute, onTogglePin }) {
    const { t } = useTranslation();
    const [open, setOpen]       = useState(false);
    const [showMute, setShowMute] = useState(false);

    const MUTE_OPTIONS = [
        { value: '8h', label: t('chat.list.muteFor8h') },
        { value: '1w', label: t('chat.list.muteFor1w') },
        { value: 'always', label: t('chat.list.muteAlways') },
    ];

    function close() {
        setOpen(false);
        setShowMute(false);
    }

    return (
        <div className="relative flex-shrink-0" onClick={e => e.stopPropagation()}>
            <button
                onClick={() => setOpen(o => !o)}
                title={t('chat.list.moreOptions')}
                className="opacity-0 group-hover:opacity-100 w-7 h-7 rounded-full hover:bg-gray-600 flex items-center justify-center transition-opacity text-gray-300"
            >
                <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                    <path d="M10 6a2 2 0 100-4 2 2 0 000 4zM10 12a2 2 0 100-4 2 2 0 000 4zM10 18a2 2 0 100-4 2 2 0 000 4z" />
                </svg>
            </button>

            {open && !showMute && (
                <div className="absolute z-20 top-8 right-0 bg-gray-800 border border-gray-600 rounded-xl shadow-lg py-1 w-44 whitespace-nowrap">
                    <button onClick={() => { close(); onTogglePin(); }} className="w-full text-left px-3 py-2 text-sm text-gray-200 hover:bg-gray-700">
                        {pinned ? t('chat.list.unpin') : t('chat.list.pin')}
                    </button>
                    <button
                        onClick={() => { close(); isArchived ? onUnarchive() : onArchive(); }}
                        className="w-full text-left px-3 py-2 text-sm text-gray-200 hover:bg-gray-700"
                    >
                        {isArchived ? t('chat.list.unarchive') : t('chat.list.archive')}
                    </button>
                    {muted ? (
                        <button
                            onClick={() => { close(); onUnmute(); }}
                            className="w-full text-left px-3 py-2 text-sm text-gray-200 hover:bg-gray-700"
                        >
                            {t('chat.list.unmute')}
                        </button>
                    ) : (
                        <button
                            onClick={() => setShowMute(true)}
                            className="w-full text-left px-3 py-2 text-sm text-gray-200 hover:bg-gray-700"
                        >
                            {t('chat.list.mute')}
                        </button>
                    )}
                </div>
            )}

            {open && showMute && (
                <div className="absolute z-20 top-8 right-0 bg-gray-800 border border-gray-600 rounded-xl shadow-lg py-1 w-44 whitespace-nowrap">
                    {MUTE_OPTIONS.map(opt => (
                        <button
                            key={opt.value}
                            onClick={() => { close(); onMute(opt.value); }}
                            className="w-full text-left px-3 py-2 text-sm text-gray-200 hover:bg-gray-700"
                        >
                            {opt.label}
                        </button>
                    ))}
                </div>
            )}
        </div>
    );
}

function ConvItem({
    conv, isActive, isArchived, onClick, currentUserId, online, pinned,
    onArchive, onUnarchive, onMute, onUnmute, onTogglePin,
}) {
    const { t } = useTranslation();
    const isGroup = conv.type === 'group';

    const displayName = getDisplayName(conv, currentUserId, t);
    const avatarUrl = getAvatarUrl(conv, currentUserId);
    const lastMsgTime = conv.updated_at ? formatDistanceToNow(conv.updated_at) : '';
    const muted = isEffectivelyMuted(conv);
    const unreadCount = conv.unread_count ?? 0;
    const preview = getLastMessagePreview(conv, currentUserId, t);

    return (
        <div
            className={`group w-full flex items-center gap-3 px-4 py-3 hover:bg-gray-700/50 transition-colors
                        ${isActive ? 'bg-gray-700' : ''}`}
        >
            <button onClick={() => onClick(conv)} className="flex-1 flex items-center gap-3 text-left min-w-0">
                <Avatar name={displayName} url={avatarUrl} online={online} />
                <div className="flex-1 min-w-0">
                    <div className="flex justify-between items-baseline">
                        <span className="font-medium text-white truncate flex items-center gap-1.5">
                            {pinned && (
                                <svg className="w-3 h-3 text-amber-400 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
                                    <path d="M11 2a1 1 0 10-2 0v1.323l-3.954 1.582A1 1 0 004 5.854V10c0 2.21 1.79 4 4 4h.5l-1.3 3.9a.5.5 0 00.948.316L9.5 14H10.5l1.352 4.216a.5.5 0 00.948-.316L11.5 14h.5c2.21 0 4-1.79 4-4V5.854a1 1 0 00-.046-.95L13 3.323V2a1 1 0 10-2 0v1H11V2z" />
                                </svg>
                            )}
                            {displayName}
                            {muted && (
                                <svg className="w-3.5 h-3.5 text-gray-500 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" title={t('chat.list.muted')}>
                                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2}
                                        d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9" />
                                    <path strokeLinecap="round" strokeWidth={2} d="M3 3l18 18" />
                                </svg>
                            )}
                        </span>
                        <span className="text-xs text-gray-500 flex-shrink-0 ml-2">{lastMsgTime}</span>
                    </div>
                    <div className="flex justify-between items-center gap-2">
                        <p className={`text-sm truncate flex items-center gap-1 ${unreadCount > 0 ? 'text-gray-200 font-medium' : 'text-gray-400'}`}>
                            {preview.isMine && <Ticks state={preview.ticks} />}
                            <span className="truncate">
                                {preview.text || (isGroup ? t('chat.members', { count: conv.conversation_members?.length || 0 }) : '')}
                            </span>
                        </p>
                        {unreadCount > 0 && (
                            <span className="flex-shrink-0 min-w-[1.25rem] h-5 px-1.5 rounded-full bg-green-500 text-white text-xs font-semibold flex items-center justify-center">
                                {unreadCount > 99 ? '99+' : unreadCount}
                            </span>
                        )}
                    </div>
                </div>
            </button>

            <ConvMenu
                isArchived={isArchived}
                muted={muted}
                pinned={pinned}
                onArchive={() => onArchive(conv)}
                onUnarchive={() => onUnarchive(conv)}
                onMute={duration => onMute(conv, duration)}
                onUnmute={() => onUnmute(conv)}
                onTogglePin={() => onTogglePin(conv)}
            />
        </div>
    );
}

const FILTERS = ['all', 'unread', 'favorites'];

export default function ConversationList({
    conversations, archivedConversations = [], activeId, onSelect, currentUserId, onNewChat,
    onArchive, onUnarchive, onMute, onUnmute, isPinned, onTogglePin, onlineUserIds,
}) {
    const { t } = useTranslation();
    const [showArchived, setShowArchived] = useState(false);
    const [search, setSearch] = useState('');
    const [filter, setFilter] = useState('all');

    const isOnline = conv => conv.type === 'private' && onlineUserIds?.has(getOtherMember(conv, currentUserId)?.users?.id);

    const filtered = useMemo(() => {
        const q = search.trim().toLowerCase();
        let list = conversations.filter(c => !q || getDisplayName(c, currentUserId, t).toLowerCase().includes(q));
        if (filter === 'unread') list = list.filter(c => (c.unread_count ?? 0) > 0);
        if (filter === 'favorites') list = list.filter(c => isPinned(c.id));
        return [...list].sort((a, b) => (isPinned(b.id) ? 1 : 0) - (isPinned(a.id) ? 1 : 0));
    }, [conversations, search, filter, currentUserId, t, isPinned]);

    const filterLabel = { all: t('chat.list.filterAll'), unread: t('chat.list.filterUnread'), favorites: t('chat.list.filterFavorites') };

    return (
        <div className="flex flex-col h-full bg-gray-800 border-r border-gray-700">
            {/* Header */}
            <div className="flex items-center justify-between px-4 py-4 border-b border-gray-700">
                <h2 className="text-lg font-bold text-white">{t('chat.list.title')}</h2>
                <button
                    onClick={onNewChat}
                    title={t('chat.list.newConversation')}
                    className="w-8 h-8 rounded-full bg-indigo-600 hover:bg-indigo-500 flex items-center justify-center transition-colors"
                >
                    <svg className="w-4 h-4 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
                    </svg>
                </button>
            </div>

            {/* Search */}
            <div className="px-3 pt-3 pb-2">
                <div className="relative">
                    <svg className="w-4 h-4 text-gray-500 absolute left-3 top-1/2 -translate-y-1/2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                    </svg>
                    <input
                        value={search}
                        onChange={e => setSearch(e.target.value)}
                        placeholder={t('chat.list.searchPlaceholder')}
                        className="w-full bg-gray-900/60 border border-gray-700 rounded-full pl-9 pr-3 py-2 text-sm text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-indigo-500"
                    />
                </div>
            </div>

            {/* Filter tabs */}
            <div className="flex gap-1.5 px-3 pb-2">
                {FILTERS.map(key => (
                    <button
                        key={key}
                        onClick={() => setFilter(key)}
                        className={`px-3 py-1 rounded-full text-xs font-medium transition-colors
                                    ${filter === key ? 'bg-indigo-600 text-white' : 'bg-gray-700 text-gray-300 hover:bg-gray-600'}`}
                    >
                        {filterLabel[key]}
                    </button>
                ))}
            </div>

            {/* List */}
            <div className="flex-1 overflow-y-auto border-t border-gray-700">
                {conversations.length === 0 && archivedConversations.length === 0 && (
                    <p className="text-center text-gray-500 text-sm mt-12 px-4">
                        {t('chat.list.empty')}<br />{t('chat.list.emptyHint')}
                    </p>
                )}

                {conversations.length > 0 && filtered.length === 0 && (
                    <p className="text-center text-gray-500 text-sm mt-12 px-4">{t('chat.list.noMatches')}</p>
                )}

                {archivedConversations.length > 0 && (
                    <button
                        onClick={() => setShowArchived(s => !s)}
                        className="w-full flex items-center justify-between px-4 py-2.5 text-sm text-gray-400 hover:bg-gray-700/50 transition-colors border-b border-gray-700"
                    >
                        <span>{t('chat.list.archived')} ({archivedConversations.length})</span>
                        <svg className={`w-3.5 h-3.5 transition-transform ${showArchived ? 'rotate-180' : ''}`} fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                        </svg>
                    </button>
                )}

                {showArchived && archivedConversations.map(conv => (
                    <ConvItem
                        key={conv.id}
                        conv={conv}
                        isActive={conv.id === activeId}
                        isArchived
                        onClick={onSelect}
                        currentUserId={currentUserId}
                        online={isOnline(conv)}
                        pinned={isPinned(conv.id)}
                        onArchive={onArchive}
                        onUnarchive={onUnarchive}
                        onMute={onMute}
                        onUnmute={onUnmute}
                        onTogglePin={onTogglePin}
                    />
                ))}

                {filtered.map(conv => (
                    <ConvItem
                        key={conv.id}
                        conv={conv}
                        isActive={conv.id === activeId}
                        isArchived={false}
                        onClick={onSelect}
                        currentUserId={currentUserId}
                        online={isOnline(conv)}
                        pinned={isPinned(conv.id)}
                        onArchive={onArchive}
                        onUnarchive={onUnarchive}
                        onMute={onMute}
                        onUnmute={onUnmute}
                        onTogglePin={onTogglePin}
                    />
                ))}
            </div>
        </div>
    );
}
