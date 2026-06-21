import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { formatDistanceToNow } from '../utils/time';
import Avatar from './Avatar';

export function isEffectivelyMuted(conv) {
    if (!conv?.is_muted) return false;
    return conv.muted_until === null || new Date(conv.muted_until) > new Date();
}

// Hover-revealed "⋮" menu for archive/mute actions, mirroring the popover
// pattern used by ReactionPicker.
function ConvMenu({ isArchived, muted, onArchive, onUnarchive, onMute, onUnmute }) {
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

function ConvItem({ conv, isActive, isArchived, onClick, currentUserId, onArchive, onUnarchive, onMute, onUnmute }) {
    const { t } = useTranslation();
    const isGroup   = conv.type === 'group';
    const otherMember = !isGroup
        ? conv.conversation_members?.find(m => m.users?.id !== currentUserId)
        : null;

    const displayName = isGroup
        ? conv.name
        : otherMember?.users?.full_name || t('common.unknown');

    const avatarUrl = isGroup ? conv.avatar_url : otherMember?.users?.avatar_url;
    const lastMsgTime = conv.updated_at ? formatDistanceToNow(conv.updated_at) : '';
    const muted = isEffectivelyMuted(conv);

    return (
        <div
            className={`group w-full flex items-center gap-3 px-4 py-3 hover:bg-gray-700/50 transition-colors
                        ${isActive ? 'bg-gray-700' : ''}`}
        >
            <button onClick={() => onClick(conv)} className="flex-1 flex items-center gap-3 text-left min-w-0">
                <Avatar name={displayName} url={avatarUrl} />
                <div className="flex-1 min-w-0">
                    <div className="flex justify-between items-baseline">
                        <span className="font-medium text-white truncate flex items-center gap-1.5">
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
                    <p className="text-sm text-gray-400 truncate">
                        {isGroup ? t('chat.members', { count: conv.conversation_members?.length || 0 }) : ''}
                    </p>
                </div>
            </button>

            <ConvMenu
                isArchived={isArchived}
                muted={muted}
                onArchive={() => onArchive(conv)}
                onUnarchive={() => onUnarchive(conv)}
                onMute={duration => onMute(conv, duration)}
                onUnmute={() => onUnmute(conv)}
            />
        </div>
    );
}

export default function ConversationList({
    conversations, archivedConversations = [], activeId, onSelect, currentUserId, onNewChat,
    onArchive, onUnarchive, onMute, onUnmute,
}) {
    const { t } = useTranslation();
    const [showArchived, setShowArchived] = useState(false);

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

            {/* List */}
            <div className="flex-1 overflow-y-auto">
                {conversations.length === 0 && archivedConversations.length === 0 && (
                    <p className="text-center text-gray-500 text-sm mt-12 px-4">
                        {t('chat.list.empty')}<br />{t('chat.list.emptyHint')}
                    </p>
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
                        onArchive={onArchive}
                        onUnarchive={onUnarchive}
                        onMute={onMute}
                        onUnmute={onUnmute}
                    />
                ))}

                {conversations.map(conv => (
                    <ConvItem
                        key={conv.id}
                        conv={conv}
                        isActive={conv.id === activeId}
                        isArchived={false}
                        onClick={onSelect}
                        currentUserId={currentUserId}
                        onArchive={onArchive}
                        onUnarchive={onUnarchive}
                        onMute={onMute}
                        onUnmute={onUnmute}
                    />
                ))}
            </div>
        </div>
    );
}
