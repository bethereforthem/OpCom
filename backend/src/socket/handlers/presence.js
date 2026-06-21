const supabase = require('../../utils/supabase');

// Fetch all user IDs that share at least one conversation with this user
async function getContactIds(userId) {
    const { data } = await supabase
        .from('conversation_members')
        .select('conversation_id')
        .eq('user_id', userId)
        .is('left_at', null);

    if (!data?.length) return [];

    const convIds = data.map(r => r.conversation_id);

    const { data: peers } = await supabase
        .from('conversation_members')
        .select('user_id')
        .in('conversation_id', convIds)
        .neq('user_id', userId)
        .is('left_at', null);

    return [...new Set(peers?.map(p => p.user_id) ?? [])];
}

async function broadcastOnline(io, socket, onlineUsers) {
    const contactIds = await getContactIds(socket.userId);

    // Tell online contacts that this user came online
    for (const contactId of contactIds) {
        if (onlineUsers.has(contactId)) {
            for (const socketId of onlineUsers.get(contactId)) {
                io.to(socketId).emit('presence_update', {
                    user_id: socket.userId,
                    status: 'online',
                });
            }
        }
    }

    // Tell this new socket which of their contacts are currently online
    const onlineContacts = contactIds.filter(id => onlineUsers.has(id));
    if (onlineContacts.length) {
        socket.emit('contacts_online', { user_ids: onlineContacts });
    }
}

async function broadcastOffline(io, socket) {
    const contactIds = await getContactIds(socket.userId);

    const lastSeen = new Date().toISOString();

    for (const contactId of contactIds) {
        // We can't iterate onlineUsers here because it was already cleaned
        // Emit to conv rooms instead — members listening will receive it
    }

    // Broadcast to all rooms this socket was in
    for (const room of socket.rooms) {
        if (room.startsWith('conv:')) {
            socket.to(room).emit('presence_update', {
                user_id: socket.userId,
                status: 'offline',
                last_seen: lastSeen,
            });
        }
    }
}

module.exports = { broadcastOnline, broadcastOffline };
