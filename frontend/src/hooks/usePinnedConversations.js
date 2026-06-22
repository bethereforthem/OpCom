import { useCallback, useState } from 'react';

// "Favorites" are pinned conversations. Kept client-side (localStorage,
// scoped per user id) rather than in the database, so this feature needs no
// schema or API change — it just doesn't sync across devices/browsers.
function storageKey(userId) {
    return `opcom_pinned_conversations_${userId}`;
}

function load(userId) {
    try {
        const raw = localStorage.getItem(storageKey(userId));
        return new Set(raw ? JSON.parse(raw) : []);
    } catch {
        return new Set();
    }
}

// `userId` is expected to be stable for the component's mount lifetime —
// ChatPage only mounts once a user is authenticated, and logging out
// navigates away from it entirely (see App.jsx's ProtectedRoute) — so a
// lazy initializer is enough; no effect is needed to react to it changing.
export default function usePinnedConversations(userId) {
    const [pinnedIds, setPinnedIds] = useState(() => (userId ? load(userId) : new Set()));

    const togglePin = useCallback((conversationId) => {
        if (!userId) return;
        setPinnedIds(prev => {
            const next = new Set(prev);
            next.has(conversationId) ? next.delete(conversationId) : next.add(conversationId);
            localStorage.setItem(storageKey(userId), JSON.stringify([...next]));
            return next;
        });
    }, [userId]);

    const isPinned = useCallback(id => pinnedIds.has(id), [pinnedIds]);

    return { pinnedIds, isPinned, togglePin };
}
