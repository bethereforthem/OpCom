import { useEffect, useRef, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { useSocket } from '../contexts/SocketContext';
import {
    getMessages, scheduleMessage, getScheduledMessages, cancelScheduledMessage, setDisappearing,
} from '../api/client';
import MessageBubble from './MessageBubble';
import MessageInput from './MessageInput';
import ForwardModal from './ForwardModal';
import ScheduledMessagesBar from './ScheduledMessagesBar';

const DISAPPEARING_SECONDS = { '24h': 86400, '7d': 604800, '90d': 7776000 };

// Header popover for the disappearing-messages setting.
function DisappearingToggle({ seconds, canToggle, onSet }) {
    const { t } = useTranslation();
    const [open, setOpen] = useState(false);

    const DISAPPEARING_OPTIONS = [
        { value: null, label: t('chat.thread.disappearingOff') },
        { value: '24h', label: t('chat.thread.disappearing24h') },
        { value: '7d', label: t('chat.thread.disappearing7d') },
        { value: '90d', label: t('chat.thread.disappearing90d') },
    ];
    const current = DISAPPEARING_OPTIONS.find(o => o.value ? DISAPPEARING_SECONDS[o.value] === seconds : !seconds)?.label;

    return (
        <div className="relative">
            <button
                onClick={() => canToggle && setOpen(o => !o)}
                title={canToggle ? t('chat.thread.disappearingMessages') : t('chat.thread.disappearingRestricted')}
                className={`w-9 h-9 rounded-full flex items-center justify-center transition-colors
                            ${seconds ? 'bg-indigo-600 hover:bg-indigo-500' : 'bg-gray-700 hover:bg-gray-600'}
                            ${!canToggle ? 'opacity-50 cursor-not-allowed' : ''}`}
            >
                <svg className="w-4 h-4 text-gray-200" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2}
                        d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
            </button>

            {open && canToggle && (
                <div className="absolute z-20 top-11 right-0 bg-gray-800 border border-gray-600 rounded-xl shadow-lg py-1 w-44">
                    {DISAPPEARING_OPTIONS.map(opt => (
                        <button
                            key={opt.label}
                            onClick={() => { setOpen(false); onSet(opt.value); }}
                            className={`w-full text-left px-3 py-2 text-sm hover:bg-gray-700
                                        ${current === opt.label ? 'text-indigo-300' : 'text-gray-200'}`}
                        >
                            {opt.label}
                        </button>
                    ))}
                </div>
            )}
        </div>
    );
}

function TypingIndicator({ typingUsers }) {
    const { t } = useTranslation();
    if (!typingUsers.size) return null;
    const names = [...typingUsers.values()].join(', ');
    return (
        <div className="px-4 py-1 text-xs text-gray-500 italic">
            {names} {typingUsers.size === 1 ? t('chat.thread.isTyping') : t('chat.thread.areTyping')}
        </div>
    );
}

export default function MessageThread({ conversation, currentUser, conversations, onInitiateCall }) {
    const { t }                   = useTranslation();
    const { on, emit }            = useSocket();
    const [messages, setMessages] = useState([]);
    const [hasMore, setHasMore]   = useState(false);
    const [loading, setLoading]   = useState(false);
    const [typingUsers, setTypingUsers] = useState(new Map());
    const [editingId, setEditingId]     = useState(null);
    const [replyTarget, setReplyTarget] = useState(null);
    const [forwardTarget, setForwardTarget] = useState(null);
    const [scheduledMessages, setScheduledMessages] = useState([]);
    const [disappearingSeconds, setDisappearingSeconds] = useState(null);
    const bottomRef               = useRef(null);
    const typingTimers            = useRef({});

    const convId = conversation?.id;

    // Load initial messages
    useEffect(() => {
        if (!convId) return;
        setMessages([]);
        setEditingId(null);
        setReplyTarget(null);
        setLoading(true);

        getMessages(convId)
            .then(r => {
                setMessages(r.data.messages);
                setHasMore(r.data.has_more);
            })
            .finally(() => setLoading(false));
    }, [convId]);

    // Load this user's own pending scheduled messages + the conversation's
    // current disappearing-messages setting
    useEffect(() => {
        if (!convId) return;
        setDisappearingSeconds(conversation.disappearing_duration_seconds ?? null);
        getScheduledMessages(convId).then(r => setScheduledMessages(r.data.scheduled_messages || []));
    }, [convId]);

    // Scroll to bottom on new messages
    useEffect(() => {
        bottomRef.current?.scrollIntoView({ behavior: 'smooth' });
    }, [messages]);

    // Load older messages
    async function loadMore() {
        if (!hasMore || loading || !messages.length) return;
        setLoading(true);
        const oldest = messages[0]?.created_at;
        const r = await getMessages(convId, oldest).finally(() => setLoading(false));
        setMessages(prev => [...r.data.messages, ...prev]);
        setHasMore(r.data.has_more);
    }

    // Mark messages as read
    useEffect(() => {
        messages
            .filter(m => m.users?.id !== currentUser.id)
            .forEach(m => emit('message_read', { message_id: m.id }));
    }, [messages]);

    // Real-time socket events
    useEffect(() => {
        const unsubs = [
            on('new_message', msg => {
                if (msg.conversation_id !== convId) return;
                setMessages(prev => [...prev, msg]);
                if (msg.sender_id !== currentUser.id) {
                    emit('message_read', { message_id: msg.id });
                }
            }),

            on('message_deleted', ({ message_id }) => {
                setMessages(prev =>
                    prev.map(m => m.id === message_id ? { ...m, is_deleted: true, content: null } : m)
                );
            }),

            on('message_edited', ({ message_id, content, edited_at }) => {
                setMessages(prev =>
                    prev.map(m => m.id === message_id ? { ...m, content, edited_at } : m)
                );
            }),

            on('message_reaction_updated', ({ message_id, user_id, emoji }) => {
                setMessages(prev =>
                    prev.map(m => {
                        if (m.id !== message_id) return m;
                        const without = (m.message_reactions || []).filter(r => r.user_id !== user_id);
                        return { ...m, message_reactions: emoji ? [...without, { user_id, emoji }] : without };
                    })
                );
            }),

            on('message_read_receipt', ({ message_id, read_by, read_at }) => {
                setMessages(prev =>
                    prev.map(m => m.id === message_id
                        ? { ...m, message_status: [...(m.message_status || []).filter(s => s.user_id !== read_by), { user_id: read_by, read_at }] }
                        : m)
                );
            }),

            on('user_typing', ({ conversation_id, user_id, username }) => {
                if (conversation_id !== convId) return;
                setTypingUsers(prev => new Map(prev).set(user_id, username));
                clearTimeout(typingTimers.current[user_id]);
                typingTimers.current[user_id] = setTimeout(() => {
                    setTypingUsers(prev => { const n = new Map(prev); n.delete(user_id); return n; });
                }, 3000);
            }),

            on('user_stopped_typing', ({ conversation_id, user_id }) => {
                if (conversation_id !== convId) return;
                setTypingUsers(prev => { const n = new Map(prev); n.delete(user_id); return n; });
            }),

            on('disappearing_settings_updated', ({ conversation_id, disappearing_duration_seconds }) => {
                if (conversation_id !== convId) return;
                setDisappearingSeconds(disappearing_duration_seconds);
            }),
        ];

        return () => unsubs.forEach(u => u?.());
    }, [on, emit, convId, currentUser.id]);

    // Typing indicator emission
    const typingTimer = useRef(null);
    function handleTyping() {
        emit('typing_start', { conversation_id: convId });
        clearTimeout(typingTimer.current);
        typingTimer.current = setTimeout(() => {
            emit('typing_stop', { conversation_id: convId });
        }, 2000);
    }

    function sendText(content) {
        emit('send_message', { conversation_id: convId, type: 'text', content, reply_to_id: replyTarget?.id });
        setReplyTarget(null);
    }

    function sendMedia(mediaId, mimeType) {
        const type = mimeType.startsWith('image/') ? 'image'
                   : mimeType.startsWith('audio/') ? 'audio'
                   : mimeType.startsWith('video/') ? 'video'
                   : 'document';
        emit('send_message', { conversation_id: convId, type, media_id: mediaId, reply_to_id: replyTarget?.id });
        setReplyTarget(null);
    }

    function editMessage(messageId, content) {
        emit('edit_message', { message_id: messageId, content });
        setEditingId(null);
    }

    function deleteMessage(message) {
        if (!window.confirm(t('chat.actions.confirmDelete'))) return;
        emit('delete_message', { message_id: message.id });
    }

    function reactToMessage(message, emoji) {
        emit('react_to_message', { message_id: message.id, emoji });
    }

    function removeReaction(message) {
        emit('remove_reaction', { message_id: message.id });
    }

    function forwardMessage(messageId, conversationIds) {
        return new Promise((resolve, reject) => {
            emit('forward_message', { message_id: messageId, conversation_ids: conversationIds }, ack => {
                if (ack?.ok) resolve(ack);
                else reject(ack?.error);
            });
        });
    }

    async function handleSchedule(content, sendAt) {
        const { data } = await scheduleMessage(convId, {
            type: 'text', content, send_at: sendAt, reply_to_id: replyTarget?.id,
        });
        setScheduledMessages(prev => [...prev, data.scheduled_message].sort((a, b) => new Date(a.send_at) - new Date(b.send_at)));
        setReplyTarget(null);
    }

    async function handleCancelScheduled(scheduledId) {
        await cancelScheduledMessage(convId, scheduledId);
        setScheduledMessages(prev => prev.filter(sm => sm.id !== scheduledId));
    }

    async function handleSetDisappearing(duration) {
        await setDisappearing(convId, duration);
    }

    if (!conversation) {
        return (
            <div className="flex-1 flex items-center justify-center bg-gray-900">
                <div className="text-center text-gray-600">
                    <svg className="w-16 h-16 mx-auto mb-3 opacity-30" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1}
                            d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
                    </svg>
                    <p>{t('chat.thread.selectConversation')}</p>
                </div>
            </div>
        );
    }

    const isGroup = conversation.type === 'group';
    const otherMember = !isGroup
        ? conversation.conversation_members?.find(m => m.users?.id !== currentUser.id)
        : null;
    const headerName = isGroup ? conversation.name : otherMember?.users?.full_name || t('common.unknown');
    const memberCount = conversation.conversation_members?.length || 0;
    const memberUsernames = new Set(
        (conversation.conversation_members ?? [])
            .map(m => m.users?.username?.toLowerCase())
            .filter(Boolean)
    );

    return (
        <div className="flex flex-col h-full">
            {/* Header */}
            <div className="flex items-center justify-between px-4 py-3 bg-gray-800 border-b border-gray-700 flex-shrink-0">
                <div>
                    <h2 className="font-semibold text-white">{headerName}</h2>
                    <p className="text-xs text-gray-400">
                        {isGroup ? t('chat.members', { count: memberCount }) : otherMember?.users?.username || ''}
                    </p>
                </div>

                <div className="flex items-center gap-2">
                    <DisappearingToggle
                        seconds={disappearingSeconds}
                        canToggle={!isGroup || ['owner', 'admin'].includes(conversation.my_role)}
                        onSet={handleSetDisappearing}
                    />

                    {/* Call buttons — only for private conversations */}
                    {!isGroup && otherMember && (
                        <>
                            <button
                                onClick={() => onInitiateCall(otherMember.users, 'audio')}
                                title={t('chat.thread.voiceCall')}
                                className="w-9 h-9 rounded-full bg-gray-700 hover:bg-gray-600 flex items-center justify-center transition-colors"
                            >
                                <svg className="w-4 h-4 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2}
                                        d="M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z" />
                                </svg>
                            </button>
                            <button
                                onClick={() => onInitiateCall(otherMember.users, 'video')}
                                title={t('chat.thread.videoCall')}
                                className="w-9 h-9 rounded-full bg-gray-700 hover:bg-gray-600 flex items-center justify-center transition-colors"
                            >
                                <svg className="w-4 h-4 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2}
                                        d="M15 10l4.553-2.069A1 1 0 0121 8.82v6.36a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z" />
                                </svg>
                            </button>
                        </>
                    )}
                </div>
            </div>

            {/* Messages */}
            <div className="flex-1 overflow-y-auto px-4 py-4 bg-gray-900" onScroll={e => {
                if (e.target.scrollTop < 60) loadMore();
            }}>
                {loading && (
                    <div className="text-center text-gray-600 text-sm py-2">{t('common.loading')}</div>
                )}
                {hasMore && !loading && (
                    <button onClick={loadMore}
                        className="w-full text-center text-xs text-gray-500 hover:text-gray-300 py-2 mb-2">
                        {t('chat.thread.loadOlder')}
                    </button>
                )}
                {messages.map(msg => (
                    <MessageBubble
                        key={msg.id}
                        message={msg}
                        isMine={msg.users?.id === currentUser.id || msg.sender_id === currentUser.id}
                        currentUserId={currentUser.id}
                        isEditing={editingId === msg.id}
                        onStartEdit={m => setEditingId(m.id)}
                        onSaveEdit={editMessage}
                        onCancelEdit={() => setEditingId(null)}
                        onDelete={deleteMessage}
                        onReply={setReplyTarget}
                        onForward={setForwardTarget}
                        onReact={reactToMessage}
                        onRemoveReaction={removeReaction}
                        memberUsernames={memberUsernames}
                    />
                ))}
                <TypingIndicator typingUsers={typingUsers} />
                <div ref={bottomRef} />
            </div>

            <TypingIndicator typingUsers={typingUsers} />

            <ScheduledMessagesBar scheduledMessages={scheduledMessages} onCancel={handleCancelScheduled} />

            {/* Input */}
            <div onKeyDown={handleTyping}>
                <MessageInput
                    onSendText={sendText}
                    onSendMedia={sendMedia}
                    onSchedule={handleSchedule}
                    replyTarget={replyTarget}
                    onCancelReply={() => setReplyTarget(null)}
                    isGroup={isGroup}
                    members={(conversation.conversation_members ?? [])
                        .filter(m => m.users?.id !== currentUser.id)
                        .map(m => m.users)}
                />
            </div>

            {forwardTarget && (
                <ForwardModal
                    message={forwardTarget}
                    conversations={conversations}
                    currentUserId={currentUser.id}
                    onClose={() => setForwardTarget(null)}
                    onForward={forwardMessage}
                />
            )}
        </div>
    );
}
