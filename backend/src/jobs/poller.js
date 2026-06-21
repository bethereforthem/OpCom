const supabase = require('../utils/supabase');
const { createMessage } = require('../socket/handlers/message');

const POLL_INTERVAL_MS = 30 * 1000;

// Started once from socket/index.js's initSocket, which already has `io`
// and `onlineUsers` in scope. Two unrelated jobs share one timer since
// neither needs sub-second precision and this app has no job queue elsewhere.
function startPoller(io, onlineUsers) {
    setInterval(() => {
        dispatchScheduledMessages(io, onlineUsers).catch(err => console.error('poller: scheduled dispatch failed', err));
        expireDisappearingMessages(io).catch(err => console.error('poller: expiry failed', err));
    }, POLL_INTERVAL_MS);
}

async function dispatchScheduledMessages(io, onlineUsers) {
    const { data: due } = await supabase
        .from('scheduled_messages')
        .select('id, conversation_id, sender_id, type, content, media_id, reply_to_id')
        .is('sent_at', null)
        .lte('send_at', new Date().toISOString());

    if (!due?.length) return;

    for (const sm of due) {
        const { data: senderUser } = await supabase
            .from('users')
            .select('id, username, full_name, avatar_url')
            .eq('id', sm.sender_id)
            .single();

        // createMessage re-checks membership itself (the sender may have left
        // the conversation since scheduling) — a rejection here is dropped
        // silently, same precedent as non-member mentions from Batch C.
        if (senderUser) {
            await createMessage({
                io, onlineUsers,
                conversationId: sm.conversation_id,
                senderId: sm.sender_id,
                senderUser,
                type: sm.type,
                content: sm.content,
                mediaId: sm.media_id,
                replyToId: sm.reply_to_id,
            });
        }

        // Marked sent regardless of outcome so it's never retried.
        await supabase.from('scheduled_messages').update({ sent_at: new Date().toISOString() }).eq('id', sm.id);
    }
}

async function expireDisappearingMessages(io) {
    const { data: expired } = await supabase
        .from('messages')
        .select('id, conversation_id')
        .not('expires_at', 'is', null)
        .lte('expires_at', new Date().toISOString());

    if (!expired?.length) return;

    // Hard delete — cascades remove reactions/status/mentions/edit-history;
    // any reply/forward pointing here already auto-nulls via ON DELETE SET NULL.
    await supabase
        .from('messages')
        .delete()
        .in('id', expired.map(m => m.id));

    expired.forEach(m => {
        io.to(`conv:${m.conversation_id}`).emit('message_deleted', { message_id: m.id });
    });
}

module.exports = { startPoller };
