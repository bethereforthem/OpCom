import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { useAuth } from '../contexts/AuthContext';
import { useSocket } from '../contexts/SocketContext';
import { useWebRTC } from '../hooks/useWebRTC';
import usePinnedConversations from '../hooks/usePinnedConversations';
import {
    getConversations, createConversation, lookupUser, leaveConversation,
    archiveConversation, unarchiveConversation, muteConversation, unmuteConversation,
} from '../api/client';
import ConversationList from '../components/ConversationList';
import MessageThread from '../components/MessageThread';
import IncomingCallModal from '../components/IncomingCallModal';
import CallOverlay from '../components/CallOverlay';
import NotificationBell from '../components/NotificationBell';
import CallHistoryButton from '../components/CallHistoryButton';
import SearchPanel from '../components/SearchPanel';
import Avatar from '../components/Avatar';

function NewChatModal({ onClose, onCreate }) {
    const { t } = useTranslation();
    const [username, setUsername] = useState('');
    const [type, setType]         = useState('private');
    const [groupName, setGroupName] = useState('');
    const [loading, setLoading]   = useState(false);
    const [error, setError]       = useState('');

    async function handleSubmit(e) {
        e.preventDefault();
        setError('');
        setLoading(true);
        try {
            await onCreate(type, username.trim(), groupName.trim());
            onClose();
        } catch (err) {
            setError(err.response?.data?.error || t('chat.newChat.failed'));
        } finally {
            setLoading(false);
        }
    }

    return (
        <div className="fixed inset-0 z-30 flex items-center justify-center bg-black/60">
            <div className="bg-gray-800 rounded-2xl p-6 w-96 border border-gray-700 shadow-2xl">
                <h3 className="text-white font-semibold text-lg mb-4">{t('chat.newChat.title')}</h3>

                <form onSubmit={handleSubmit} className="space-y-4">
                    <div>
                        <label className="block text-sm text-gray-400 mb-1">{t('chat.newChat.type')}</label>
                        <div className="flex gap-2">
                            {['private', 'group'].map(tp => (
                                <button key={tp} type="button" onClick={() => setType(tp)}
                                    className={`flex-1 py-2 rounded-lg text-sm font-medium transition-colors
                                                ${type === tp ? 'bg-indigo-600 text-white' : 'bg-gray-700 text-gray-300 hover:bg-gray-600'}`}>
                                    {tp === 'private' ? t('chat.newChat.private') : t('chat.newChat.group')}
                                </button>
                            ))}
                        </div>
                    </div>

                    {type === 'group' && (
                        <div>
                            <label className="block text-sm text-gray-400 mb-1">{t('chat.newChat.groupNameLabel')}</label>
                            <input value={groupName} onChange={e => setGroupName(e.target.value)} required
                                className="w-full bg-gray-700 border border-gray-600 rounded-lg px-3 py-2 text-white text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
                                placeholder={t('chat.newChat.groupNamePlaceholder')} />
                        </div>
                    )}

                    <div>
                        <label className="block text-sm text-gray-400 mb-1">
                            {type === 'private' ? t('chat.newChat.recipientLabel') : t('chat.newChat.addMemberLabel')}
                        </label>
                        <input value={username} onChange={e => setUsername(e.target.value)} required
                            className="w-full bg-gray-700 border border-gray-600 rounded-lg px-3 py-2 text-white text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
                            placeholder={t('chat.newChat.usernamePlaceholder')} />
                    </div>

                    {error && <p className="text-red-400 text-sm">{error}</p>}

                    <div className="flex gap-2 pt-1">
                        <button type="button" onClick={onClose}
                            className="flex-1 py-2 rounded-lg bg-gray-700 text-gray-300 hover:bg-gray-600 text-sm transition-colors">
                            {t('common.cancel')}
                        </button>
                        <button type="submit" disabled={loading}
                            className="flex-1 py-2 rounded-lg bg-indigo-600 hover:bg-indigo-500 text-white text-sm font-medium disabled:opacity-50 transition-colors">
                            {loading ? t('chat.newChat.creating') : t('chat.newChat.create')}
                        </button>
                    </div>
                </form>
            </div>
        </div>
    );
}

export default function ChatPage() {
    const { t }                         = useTranslation();
    const navigate                      = useNavigate();
    const { user, logout }              = useAuth();
    const { connected, on }             = useSocket();
    const webrtc                        = useWebRTC();

    const [conversations, setConversations] = useState([]);
    const [archivedConversations, setArchivedConversations] = useState([]);
    const [activeConv, setActiveConv]       = useState(null);
    const [showNewChat, setShowNewChat]     = useState(false);
    const [showSearch, setShowSearch]       = useState(false);
    const [searchScopeConvId, setSearchScopeConvId] = useState(null);
    const [onlineUserIds, setOnlineUserIds] = useState(() => new Set());

    const { isPinned, togglePin } = usePinnedConversations(user?.id);

    // Load conversations on mount
    useEffect(() => {
        getConversations().then(r => setConversations(r.data.conversations || []));
        getConversations(true).then(r => setArchivedConversations(r.data.conversations || []));
    }, []);

    // Online presence — populated from the existing presence socket events
    // (already broadcast by the backend; just wasn't consumed on web before).
    useEffect(() => {
        const unsubs = [
            on('contacts_online', ({ user_ids }) => setOnlineUserIds(new Set(user_ids))),
            on('presence_update', ({ user_id, status }) => {
                setOnlineUserIds(prev => {
                    const next = new Set(prev);
                    status === 'online' ? next.add(user_id) : next.delete(user_id);
                    return next;
                });
            }),
        ];
        return () => unsubs.forEach(u => u?.());
    }, [on]);

    // Update conversation list order when a new message arrives. If the
    // conversation was archived, the backend auto-unarchives it for other
    // members on new activity — mirror that by moving it back into the
    // active list here too. Unread count is bumped client-side here (not
    // mine, and not the conversation currently open) so the sidebar badge
    // updates live without a full refetch.
    useEffect(() => {
        return on('new_message', msg => {
            const isMine = msg.sender_id === user?.id || msg.users?.id === user?.id;
            const isActive = msg.conversation_id === activeConv?.id;
            const bump = c => ({
                ...c,
                updated_at: msg.created_at,
                last_message: msg,
                unread_count: (!isMine && !isActive) ? (c.unread_count ?? 0) + 1 : (c.unread_count ?? 0),
            });

            setConversations(prev => {
                const idx = prev.findIndex(c => c.id === msg.conversation_id);
                if (idx !== -1) {
                    const updated = bump(prev[idx]);
                    const rest = prev.filter((_, i) => i !== idx);
                    return [updated, ...rest];
                }
                const archivedIdx = archivedConversations.findIndex(c => c.id === msg.conversation_id);
                if (archivedIdx === -1) return prev;
                const reactivated = { ...bump(archivedConversations[archivedIdx]), archived_at: null };
                setArchivedConversations(a => a.filter((_, i) => i !== archivedIdx));
                return [reactivated, ...prev];
            });
        });
    }, [on, archivedConversations, activeConv, user]);

    function patchConv(id, patch) {
        setConversations(prev => prev.map(c => c.id === id ? { ...c, ...patch } : c));
        setArchivedConversations(prev => prev.map(c => c.id === id ? { ...c, ...patch } : c));
    }

    async function handleArchive(conv) {
        await archiveConversation(conv.id);
        setConversations(prev => prev.filter(c => c.id !== conv.id));
        setArchivedConversations(prev => [{ ...conv, archived_at: new Date().toISOString() }, ...prev]);
    }

    async function handleUnarchive(conv) {
        await unarchiveConversation(conv.id);
        setArchivedConversations(prev => prev.filter(c => c.id !== conv.id));
        setConversations(prev => [{ ...conv, archived_at: null }, ...prev]);
    }

    async function handleMute(conv, duration) {
        const { data } = await muteConversation(conv.id, duration);
        patchConv(conv.id, { is_muted: true, muted_until: data.muted_until });
    }

    async function handleUnmute(conv) {
        await unmuteConversation(conv.id);
        patchConv(conv.id, { is_muted: false, muted_until: null });
    }

    async function handleCreateConversation(type, username, groupName) {
        const { data: lookup } = await lookupUser(username);
        const { data } = await createConversation(type, [lookup.user.id], groupName || null);
        setConversations(prev => [data.conversation, ...prev]);
        setActiveConv(data.conversation);
    }

    function handleInitiateCall(peer, type) {
        webrtc.initiateCall(peer.id, peer, type);
    }

    // Selecting a conversation clears its unread badge immediately, without
    // waiting on a server round-trip (the per-message read receipts still
    // happen normally inside MessageThread).
    function selectConversation(conv) {
        setActiveConv(conv);
        if (conv) patchConv(conv.id, { unread_count: 0 });
    }

    function openConversationById(conversationId) {
        const conv = conversations.find(c => c.id === conversationId);
        if (conv) selectConversation(conv);
        setShowSearch(false);
    }

    function openSearchInChat(conversationId) {
        setSearchScopeConvId(conversationId);
        setShowSearch(true);
    }

    async function handleLeave(conv) {
        if (!window.confirm(t('chat.thread.confirmLeave'))) return;
        await leaveConversation(conv.id);
        setConversations(prev => prev.filter(c => c.id !== conv.id));
        setArchivedConversations(prev => prev.filter(c => c.id !== conv.id));
        if (activeConv?.id === conv.id) setActiveConv(null);
    }

    return (
        <div className="h-full flex flex-col">
            {/* Top bar */}
            <header className="flex items-center justify-between px-4 py-2.5 bg-gray-800 border-b border-gray-700 flex-shrink-0">
                <div className="flex items-center gap-2">
                    <div className="w-7 h-7 rounded-lg bg-indigo-600 flex items-center justify-center">
                        <svg className="w-4 h-4 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2}
                                d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
                        </svg>
                    </div>
                    <span className="font-bold text-white text-sm">{t('common.appName')}</span>
                </div>

                <div className="flex items-center gap-3">
                    {/* Connection indicator */}
                    <div className="flex items-center gap-1.5">
                        <div className={`w-2 h-2 rounded-full ${connected ? 'bg-green-400' : 'bg-red-500'}`} />
                        <span className="text-xs text-gray-400">{connected ? t('chat.header.connected') : t('chat.header.reconnecting')}</span>
                    </div>

                    <button onClick={() => { setSearchScopeConvId(null); setShowSearch(true); }} title={t('chat.header.searchMessages')}
                        className="w-8 h-8 rounded-full bg-gray-700 hover:bg-gray-600 flex items-center justify-center transition-colors">
                        <svg className="w-4 h-4 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2}
                                d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                        </svg>
                    </button>

                    <CallHistoryButton currentUserId={user?.id} />

                    <NotificationBell />

                    {/* User info + logout */}
                    <div className="flex items-center gap-2">
                        <button onClick={() => navigate('/settings')} title={t('settings.title')}
                            className="flex items-center gap-1.5 px-1.5 py-1 rounded-lg hover:bg-gray-700 transition-colors">
                            <Avatar name={user?.full_name || user?.username} url={user?.avatar_url} size="sm" />
                            <span className="text-sm text-gray-300">{user?.username}</span>
                        </button>
                        {user?.roles?.name === 'admin' && (
                            <a href="/admin"
                                className="text-xs text-indigo-400 hover:text-indigo-300 transition-colors px-2 py-1 rounded hover:bg-gray-700">
                                {t('chat.header.admin')}
                            </a>
                        )}
                        <button onClick={logout}
                            className="text-xs text-gray-500 hover:text-gray-300 transition-colors px-2 py-1 rounded hover:bg-gray-700">
                            {t('common.signOut')}
                        </button>
                    </div>
                </div>
            </header>

            {/* Main layout */}
            <div className="flex flex-1 min-h-0">
                {/* Sidebar */}
                <div className="w-72 flex-shrink-0">
                    <ConversationList
                        conversations={conversations}
                        archivedConversations={archivedConversations}
                        activeId={activeConv?.id}
                        onSelect={selectConversation}
                        currentUserId={user?.id}
                        onNewChat={() => setShowNewChat(true)}
                        onArchive={handleArchive}
                        onUnarchive={handleUnarchive}
                        onMute={handleMute}
                        onUnmute={handleUnmute}
                        isPinned={isPinned}
                        onTogglePin={conv => togglePin(conv.id)}
                        onlineUserIds={onlineUserIds}
                    />
                </div>

                {/* Message area */}
                <div className="flex-1 min-w-0">
                    <MessageThread
                        conversation={activeConv}
                        currentUser={user}
                        conversations={conversations}
                        onInitiateCall={handleInitiateCall}
                        onlineUserIds={onlineUserIds}
                        onSearchInThisChat={openSearchInChat}
                        onArchive={handleArchive}
                        onUnarchive={handleUnarchive}
                        onMute={handleMute}
                        onUnmute={handleUnmute}
                        onLeave={handleLeave}
                    />
                </div>
            </div>

            {/* Modals */}
            {showSearch && (
                <SearchPanel
                    onClose={() => { setShowSearch(false); setSearchScopeConvId(null); }}
                    onOpenConversation={openConversationById}
                    conversationId={searchScopeConvId}
                />
            )}
            {showNewChat && (
                <NewChatModal
                    onClose={() => setShowNewChat(false)}
                    onCreate={handleCreateConversation}
                />
            )}

            {/* Incoming call */}
            <IncomingCallModal
                callInfo={webrtc.callState === 'incoming' ? webrtc.callInfo : null}
                onAccept={webrtc.acceptCall}
                onReject={webrtc.rejectCall}
            />

            {/* Active / outgoing call overlay */}
            <CallOverlay
                callState={webrtc.callState}
                callInfo={webrtc.callInfo}
                localStream={webrtc.localStream}
                remoteStream={webrtc.remoteStream}
                isMuted={webrtc.isMuted}
                isVideoOff={webrtc.isVideoOff}
                onEnd={webrtc.endCall}
                onToggleMute={webrtc.toggleMute}
                onToggleVideo={webrtc.toggleVideo}
            />
        </div>
    );
}
