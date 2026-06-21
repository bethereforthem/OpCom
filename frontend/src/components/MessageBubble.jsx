import { useState, useEffect, useRef } from 'react';
import { useTranslation } from 'react-i18next';
import { getMediaUrl } from '../api/client';
import { formatTime } from '../utils/time';
import MessageActions from './MessageActions';

function ForwardedLabel({ forwardedFrom }) {
    const { t } = useTranslation();
    if (!forwardedFrom) return null;
    return (
        <div className="text-xs italic opacity-70 mb-1">
            {t('chat.bubble.forwardedFrom', { name: forwardedFrom.users?.full_name || t('common.unknown') })}
        </div>
    );
}

function ReactionBar({ reactions, currentUserId, onToggle }) {
    if (!reactions?.length) return null;
    const grouped = {};
    reactions.forEach(r => { (grouped[r.emoji] ??= []).push(r.user_id); });

    return (
        <div className="flex flex-wrap gap-1 mt-1">
            {Object.entries(grouped).map(([emoji, userIds]) => {
                const mine = userIds.includes(currentUserId);
                return (
                    <button key={emoji} onClick={() => onToggle(emoji, mine)}
                        className={`text-xs rounded-full px-2 py-0.5 border transition-colors
                            ${mine ? 'bg-indigo-600/30 border-indigo-400 text-indigo-200' : 'bg-gray-800/60 border-gray-600 text-gray-300'}`}>
                        {emoji} {userIds.length}
                    </button>
                );
            })}
        </div>
    );
}

function renderWithMentions(content, memberUsernames) {
    if (!content) return content;
    const parts = content.split(/(@\w+)/g);
    return parts.map((part, i) => {
        if (part.startsWith('@')) {
            const uname = part.slice(1).toLowerCase();
            if (uname === 'all' || uname === 'everyone' || memberUsernames?.has(uname)) {
                return <span key={i} className="text-indigo-300 font-semibold">{part}</span>;
            }
        }
        return part;
    });
}

function ReplyPreview({ replyTo }) {
    const { t } = useTranslation();
    if (!replyTo) return null;
    const label = replyTo.is_deleted
        ? t('chat.bubble.originalDeleted')
        : replyTo.type !== 'text'
            ? ({ image: t('chat.bubble.photo'), audio: t('chat.bubble.audioType'), video: t('chat.bubble.videoType'), document: t('chat.bubble.documentType') }[replyTo.type] || t('common.media'))
            : replyTo.content;

    return (
        <div className="mb-1.5 pl-2 border-l-2 border-indigo-400/60 text-xs opacity-80">
            <div className="font-medium text-indigo-300">{replyTo.users?.full_name || t('common.unknown')}</div>
            <div className="truncate max-w-[16rem]">{label}</div>
        </div>
    );
}

function MediaContent({ mediaId, type }) {
    const { t } = useTranslation();
    const [url, setUrl]     = useState(null);
    const [loading, setLoading] = useState(false);

    async function load() {
        if (url || loading) return;
        setLoading(true);
        try {
            const { data } = await getMediaUrl(mediaId);
            setUrl(data.url);
        } finally {
            setLoading(false);
        }
    }

    if (type === 'image') {
        return (
            <div onClick={load} className="cursor-pointer">
                {url
                    ? <img src={url} alt="media" className="max-w-xs rounded-lg max-h-64 object-cover" />
                    : <div onClick={load}
                           className="w-40 h-32 bg-gray-700 rounded-lg flex items-center justify-center cursor-pointer hover:bg-gray-600 transition-colors">
                        {loading
                            ? <span className="text-gray-400 text-xs">{t('common.loading')}</span>
                            : <span className="text-gray-400 text-xs">{t('chat.bubble.tapToLoadImage')}</span>}
                      </div>
                }
            </div>
        );
    }

    if (type === 'audio') {
        if (!url) {
            return (
                <button onClick={load}
                    className="flex items-center gap-2 bg-gray-700 hover:bg-gray-600 px-4 py-2 rounded-lg transition-colors">
                    <svg className="w-5 h-5 text-indigo-400" fill="currentColor" viewBox="0 0 24 24">
                        <path d="M8 5v14l11-7z"/>
                    </svg>
                    <span className="text-sm text-gray-300">{loading ? t('common.loading') : t('chat.bubble.playAudio')}</span>
                </button>
            );
        }
        return <audio controls src={url} className="max-w-xs" />;
    }

    if (type === 'video') {
        if (!url) {
            return (
                <button onClick={load}
                    className="w-40 h-32 bg-gray-700 hover:bg-gray-600 rounded-lg flex flex-col items-center justify-center gap-1 transition-colors">
                    <svg className="w-8 h-8 text-indigo-400" fill="currentColor" viewBox="0 0 24 24">
                        <path d="M8 5v14l11-7z"/>
                    </svg>
                    <span className="text-xs text-gray-400">{loading ? t('common.loading') : t('chat.bubble.playVideo')}</span>
                </button>
            );
        }
        return <video controls src={url} className="max-w-xs rounded-lg max-h-64" />;
    }

    // Document
    return (
        <button onClick={async () => { await load(); if (url) window.open(url, '_blank'); }}
            className="flex items-center gap-3 bg-gray-700 hover:bg-gray-600 px-4 py-3 rounded-lg transition-colors max-w-xs">
            <svg className="w-8 h-8 text-indigo-400 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5}
                    d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
            </svg>
            <span className="text-sm text-gray-300 truncate">
                {loading ? t('common.loading') : t('chat.bubble.downloadDocument')}
            </span>
        </button>
    );
}

function EditForm({ message, onSave, onCancel }) {
    const { t } = useTranslation();
    const [draft, setDraft] = useState(message.content || '');
    const textareaRef = useRef(null);

    useEffect(() => { textareaRef.current?.focus(); }, []);

    function handleKeyDown(e) {
        if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); save(); }
        if (e.key === 'Escape') onCancel();
    }

    function save() {
        const trimmed = draft.trim();
        if (trimmed && trimmed !== message.content) onSave(trimmed);
        else onCancel();
    }

    return (
        <div>
            <textarea
                ref={textareaRef}
                value={draft}
                onChange={e => setDraft(e.target.value)}
                onKeyDown={handleKeyDown}
                rows={2}
                className="w-full bg-gray-800 text-white text-sm rounded-lg px-2 py-1.5
                           border border-gray-500 focus:outline-none focus:ring-2 focus:ring-indigo-400 resize-none"
            />
            <div className="flex gap-2 mt-1 justify-end">
                <button onClick={onCancel} className="text-xs text-gray-300 hover:text-white">{t('common.cancel')}</button>
                <button onClick={save} className="text-xs text-indigo-300 hover:text-white font-medium">{t('common.save')}</button>
            </div>
        </div>
    );
}

export default function MessageBubble({
    message, isMine, currentUserId, isEditing, onStartEdit, onSaveEdit, onCancelEdit,
    onDelete, onReply, onForward, onReact, onRemoveReaction, memberUsernames,
}) {
    const { t } = useTranslation();

    if (message.is_deleted) {
        return (
            <div className={`flex ${isMine ? 'justify-end' : 'justify-start'} mb-1`}>
                <span className="text-xs italic text-gray-600 px-3 py-1.5">
                    {isMine ? t('chat.bubble.youDeleted') : t('chat.bubble.messageDeleted')}
                </span>
            </div>
        );
    }

    if (message.type === 'system') {
        return (
            <div className="flex justify-center mb-1">
                <span className="text-xs text-gray-500 bg-gray-800/80 rounded-full px-3 py-1">
                    {message.content}
                </span>
            </div>
        );
    }

    function toggleReaction(emoji, mine) {
        if (mine) onRemoveReaction(message);
        else onReact(message, emoji);
    }

    const actions = (
        <MessageActions
            message={message}
            isMine={isMine}
            onEdit={() => onStartEdit(message)}
            onDelete={onDelete}
            onReply={onReply}
            onForward={onForward}
            onReact={onReact}
        />
    );

    return (
        <div className={`flex ${isMine ? 'justify-end' : 'justify-start'} mb-1 group items-center gap-1`}>
            {isMine && actions}
            <div className={`max-w-sm lg:max-w-md ${isMine ? 'items-end' : 'items-start'} flex flex-col`}>
                {/* Sender name in groups */}
                {!isMine && message.users?.full_name && (
                    <span className="text-xs text-indigo-400 font-medium mb-1 px-1">
                        {message.users.full_name}
                    </span>
                )}

                <div className={`rounded-2xl px-4 py-2.5 min-w-[8rem]
                    ${isMine
                        ? 'bg-indigo-600 text-white rounded-br-sm'
                        : 'bg-gray-700 text-gray-100 rounded-bl-sm'}`}>

                    <ForwardedLabel forwardedFrom={message.forwarded_from} />
                    <ReplyPreview replyTo={message.reply_to} />

                    {/* Media content */}
                    {message.type !== 'text' && message.media_id && (
                        <div className="mb-1">
                            <MediaContent mediaId={message.media_id} type={message.type} />
                        </div>
                    )}

                    {/* Text content / inline edit form */}
                    {isEditing ? (
                        <EditForm message={message} onSave={content => onSaveEdit(message.id, content)} onCancel={onCancelEdit} />
                    ) : (
                        message.content && (
                            <p className="text-sm whitespace-pre-wrap break-words">
                                {renderWithMentions(message.content, memberUsernames)}
                            </p>
                        )
                    )}

                    {/* Timestamp + edited indicator + status */}
                    {!isEditing && (
                        <div className={`flex items-center gap-1 mt-1 ${isMine ? 'justify-end' : 'justify-start'}`}>
                            {message.edited_at && (
                                <span className={`text-xs italic ${isMine ? 'text-indigo-200' : 'text-gray-500'}`}>{t('chat.bubble.edited')}</span>
                            )}
                            <span className={`text-xs ${isMine ? 'text-indigo-200' : 'text-gray-500'}`}>
                                {formatTime(message.created_at)}
                            </span>
                            {isMine && (
                                <span className="text-indigo-200 text-xs">
                                    {/* Double tick if delivered/read */}
                                    {message.message_status?.some(s => s.read_at)
                                        ? '✓✓' : message.message_status?.some(s => s.delivered_at)
                                        ? '✓✓' : '✓'}
                                </span>
                            )}
                        </div>
                    )}
                </div>

                <ReactionBar reactions={message.message_reactions} currentUserId={currentUserId} onToggle={toggleReaction} />
            </div>
            {!isMine && actions}
        </div>
    );
}
