const supabase = require('../../utils/supabase');
const audit = require('../../services/auditLog');

// Shared by the live `send_message` socket event and the background poller
// (`backend/src/jobs/poller.js`) dispatching due scheduled messages — both
// paths need identical mentions/notifications/delivery-status/expiry handling.
async function createMessage({
    io, onlineUsers, conversationId, senderId, senderUser,
    type = 'text', content, mediaId, replyToId,
}) {
    if (type === 'text' && !content?.trim()) return { error: 'content required for text messages' };

    // Verify sender is a member of this conversation
    const { data: membership } = await supabase
        .from('conversation_members')
        .select('role, conversations ( type, disappearing_duration_seconds )')
        .eq('conversation_id', conversationId)
        .eq('user_id', senderId)
        .is('left_at', null)
        .single();

    if (!membership) return { error: 'Not a member of this conversation' };
    const conversationType = membership.conversations?.type;
    const disappearingSeconds = membership.conversations?.disappearing_duration_seconds;

    // If replying, the target message must belong to this same conversation.
    // Fetched here (not via a PostgREST embed below — self-referencing FKs on
    // the same table are ambiguous to embed) and reused as the reply preview.
    let replyTo = null;
    if (replyToId) {
        const { data: target } = await supabase
            .from('messages')
            .select('id, conversation_id, content, type, is_deleted, users!sender_id ( id, username, full_name )')
            .eq('id', replyToId)
            .single();

        if (!target || target.conversation_id !== conversationId) {
            return { error: 'reply_to_id does not belong to this conversation' };
        }
        const { conversation_id: _omit, ...preview } = target;
        replyTo = preview;
    }

    // Computed from the conversation's disappearing-messages setting — only
    // ever forward-looking, never stamped onto messages sent before it was enabled.
    const expiresAt = disappearingSeconds
        ? new Date(Date.now() + disappearingSeconds * 1000).toISOString()
        : null;

    // Insert message
    const { data: message, error } = await supabase
        .from('messages')
        .insert({
            conversation_id: conversationId,
            sender_id: senderId,
            type,
            content: content?.trim() ?? null,
            media_id: mediaId ?? null,
            reply_to_id: replyToId ?? null,
            expires_at: expiresAt,
        })
        .select(`
            id, sender_id, conversation_id, type, content, media_id, reply_to_id,
            forwarded_from_id, edited_at, expires_at, created_at,
            users!sender_id ( id, username, full_name, avatar_url ),
            message_reactions ( user_id, emoji ),
            message_mentions ( mentioned_user_id )
        `)
        .single();

    if (error) return { error: 'Failed to save message' };

    message.reply_to = replyTo;

    // ── Mentions ────────────────────────────────────────────
    // Parsed server-side against the real member list — never trust the
    // client about who is actually in this conversation. Computed before
    // the broadcast below so `message.message_mentions` is accurate for
    // every recipient, not just in the sender's ack.
    if (type === 'text' && message.content) {
        const tokens = [...new Set(
            (message.content.match(/@(\w+)/g) || []).map(t => t.slice(1).toLowerCase())
        )];

        if (tokens.length) {
            const { data: allMembers } = await supabase
                .from('conversation_members')
                .select('user_id, is_muted, muted_until, users ( username )')
                .eq('conversation_id', conversationId)
                .is('left_at', null);

            const others = (allMembers ?? []).filter(m => m.user_id !== senderId);
            const wantsAll = tokens.includes('all') || tokens.includes('everyone');
            const mentionedIds = new Set();

            if (wantsAll && conversationType === 'group') {
                others.forEach(m => mentionedIds.add(m.user_id));
            }
            tokens.forEach(token => {
                const match = others.find(m => m.users?.username?.toLowerCase() === token);
                if (match) mentionedIds.add(match.user_id);
            });

            if (mentionedIds.size) {
                await supabase.from('message_mentions').insert(
                    [...mentionedIds].map(uid => ({ message_id: message.id, mentioned_user_id: uid }))
                );

                // Muting this conversation suppresses the alert (notification + socket
                // ping) only — the mention itself is still recorded above for search/audit.
                const isMuted = (uid) => {
                    const m = others.find(o => o.user_id === uid);
                    return !!m?.is_muted && (m.muted_until === null || new Date(m.muted_until) > new Date());
                };
                const alertIds = [...mentionedIds].filter(uid => !isMuted(uid));

                if (alertIds.length) {
                    await supabase.from('notifications').insert(
                        alertIds.map(uid => ({
                            user_id: uid,
                            type: 'mention',
                            title: `${senderUser.full_name} mentioned you`,
                            body: message.content.slice(0, 200),
                            metadata: {
                                conversation_id: conversationId,
                                message_id: message.id,
                                // Lets clients render the title in the viewer's own
                                // language instead of trusting the English `title` above.
                                mentioned_by: { username: senderUser.username, full_name: senderUser.full_name },
                            },
                        }))
                    );

                    alertIds.forEach(uid => {
                        const sockets = onlineUsers.get(uid);
                        if (!sockets) return;
                        sockets.forEach(sid => io.to(sid).emit('mention_received', {
                            message_id: message.id,
                            conversation_id: conversationId,
                            mentioned_by: { id: senderId, username: senderUser.username, full_name: senderUser.full_name },
                            content_preview: message.content.slice(0, 120),
                        }));
                    });
                }

                message.message_mentions = [...mentionedIds].map(uid => ({ mentioned_user_id: uid }));
            }
        }
    }

    // Update conversation's updated_at so it surfaces at top of list
    await supabase
        .from('conversations')
        .update({ updated_at: new Date().toISOString() })
        .eq('id', conversationId);

    // New activity un-archives this conversation for any other member who had
    // archived it (matches WhatsApp's default behavior — no "keep archived" setting).
    await supabase
        .from('conversation_members')
        .update({ archived_at: null })
        .eq('conversation_id', conversationId)
        .neq('user_id', senderId)
        .not('archived_at', 'is', null);

    // Broadcast to everyone in the room (including sender for multi-device sync)
    io.to(`conv:${conversationId}`).emit('new_message', message);

    // Insert "sent" status rows for all OTHER members who are online
    const { data: members } = await supabase
        .from('conversation_members')
        .select('user_id')
        .eq('conversation_id', conversationId)
        .is('left_at', null)
        .neq('user_id', senderId);

    if (members?.length) {
        const deliveredMembers = members.filter(m => onlineUsers.has(m.user_id));
        if (deliveredMembers.length) {
            await supabase.from('message_status').insert(
                deliveredMembers.map(m => ({
                    message_id: message.id,
                    user_id: m.user_id,
                    delivered_at: new Date().toISOString(),
                }))
            );
            // Notify sender of delivery
            io.to(`conv:${conversationId}`).emit('message_delivered', {
                message_id: message.id,
                delivered_to: deliveredMembers.map(m => m.user_id),
            });
        }
    }

    await audit.log('send_message', {
        userId: senderId,
        targetType: 'message',
        targetId: message.id,
    });

    return { ok: true, message };
}

module.exports = function messageHandler(io, socket, onlineUsers) {

    // ── send_message ───────────────────────────────────────────
    // Payload: { conversation_id, type, content, media_id?, reply_to_id? }
    socket.on('send_message', async (payload, ack) => {
        const { conversation_id, type = 'text', content, media_id, reply_to_id } = payload ?? {};

        if (!conversation_id) return ack?.({ error: 'conversation_id required' });

        const result = await createMessage({
            io, onlineUsers,
            conversationId: conversation_id,
            senderId: socket.userId,
            senderUser: socket.user,
            type, content, mediaId: media_id, replyToId: reply_to_id,
        });

        ack?.(result);
    });

    // ── edit_message ───────────────────────────────────────────
    // Payload: { message_id, content }
    socket.on('edit_message', async (payload, ack) => {
        const { message_id, content } = payload ?? {};
        const trimmed = content?.trim();
        if (!message_id) return ack?.({ error: 'message_id required' });
        if (!trimmed) return ack?.({ error: 'content required' });

        const { data: msg } = await supabase
            .from('messages')
            .select('sender_id, conversation_id, type, content, is_deleted')
            .eq('id', message_id)
            .single();

        if (!msg) return ack?.({ error: 'Message not found' });
        if (msg.sender_id !== socket.userId) return ack?.({ error: 'Can only edit your own messages' });
        if (msg.type !== 'text') return ack?.({ error: 'Only text messages can be edited' });
        if (msg.is_deleted) return ack?.({ error: 'Cannot edit a deleted message' });

        await supabase.from('message_edit_history').insert({
            message_id,
            prev_content: msg.content,
        });

        const edited_at = new Date().toISOString();
        const { error } = await supabase
            .from('messages')
            .update({ content: trimmed, edited_at })
            .eq('id', message_id);

        if (error) return ack?.({ error: 'Failed to edit message' });

        io.to(`conv:${msg.conversation_id}`).emit('message_edited', {
            message_id,
            content: trimmed,
            edited_at,
        });

        await audit.log('edit_message', {
            userId: socket.userId,
            targetType: 'message',
            targetId: message_id,
            metadata: { old_length: msg.content?.length ?? 0, new_length: trimmed.length },
        });

        ack?.({ ok: true, message_id, content: trimmed, edited_at });
    });

    // ── forward_message ────────────────────────────────────────
    // Payload: { message_id, conversation_ids: [...] }
    socket.on('forward_message', async (payload, ack) => {
        const { message_id, conversation_ids } = payload ?? {};
        if (!message_id) return ack?.({ error: 'message_id required' });
        if (!Array.isArray(conversation_ids) || conversation_ids.length === 0) {
            return ack?.({ error: 'conversation_ids array required' });
        }

        const { data: source } = await supabase
            .from('messages')
            .select('id, conversation_id, type, content, media_id, is_deleted, users!sender_id ( id, username, full_name )')
            .eq('id', message_id)
            .single();

        if (!source || source.is_deleted) return ack?.({ error: 'Message not found' });

        const { data: sourceMembership } = await supabase
            .from('conversation_members')
            .select('role')
            .eq('conversation_id', source.conversation_id)
            .eq('user_id', socket.userId)
            .is('left_at', null)
            .single();

        if (!sourceMembership) return ack?.({ error: 'Not a member of the source conversation' });

        // Preview reused for every target — it's always the same source message
        const sourceSender = source.users;

        const forwarded = [];
        const failed = [];

        for (const targetId of conversation_ids) {
            const { data: targetMembership } = await supabase
                .from('conversation_members')
                .select('role')
                .eq('conversation_id', targetId)
                .eq('user_id', socket.userId)
                .is('left_at', null)
                .single();

            if (!targetMembership) {
                failed.push({ conversation_id: targetId, error: 'Not a member of this conversation' });
                continue;
            }

            const { data: message, error } = await supabase
                .from('messages')
                .insert({
                    conversation_id: targetId,
                    sender_id: socket.userId,
                    type: source.type,
                    content: source.content,
                    media_id: source.media_id,
                    forwarded_from_id: source.id,
                    reply_to_id: null,
                })
                .select(`
                    id, conversation_id, type, content, media_id, reply_to_id,
                    forwarded_from_id, edited_at, created_at,
                    users!sender_id ( id, username, full_name, avatar_url ),
                    message_reactions ( user_id, emoji )
                `)
                .single();

            if (error) {
                failed.push({ conversation_id: targetId, error: 'Failed to forward message' });
                continue;
            }

            message.reply_to = null;
            message.forwarded_from = { id: source.id, content: source.content, type: source.type, users: sourceSender };

            await supabase.from('conversations').update({ updated_at: new Date().toISOString() }).eq('id', targetId);
            io.to(`conv:${targetId}`).emit('new_message', message);
            forwarded.push(targetId);
        }

        await audit.log('forward_message', {
            userId: socket.userId,
            targetType: 'message',
            targetId: source.id,
            metadata: { target_conversation_ids: conversation_ids, forwarded_count: forwarded.length },
        });

        ack?.({ ok: true, forwarded, failed });
    });

    // ── react_to_message ───────────────────────────────────────
    // Payload: { message_id, emoji }
    socket.on('react_to_message', async (payload, ack) => {
        const { message_id, emoji } = payload ?? {};
        if (!message_id) return ack?.({ error: 'message_id required' });
        if (!emoji) return ack?.({ error: 'emoji required' });

        const { data: msg } = await supabase
            .from('messages')
            .select('conversation_id')
            .eq('id', message_id)
            .single();

        if (!msg) return ack?.({ error: 'Message not found' });

        const { data: membership } = await supabase
            .from('conversation_members')
            .select('role')
            .eq('conversation_id', msg.conversation_id)
            .eq('user_id', socket.userId)
            .is('left_at', null)
            .single();

        if (!membership) return ack?.({ error: 'Not a member of this conversation' });

        const { error } = await supabase
            .from('message_reactions')
            .upsert({ message_id, user_id: socket.userId, emoji }, { onConflict: 'message_id,user_id' });

        if (error) return ack?.({ error: 'Failed to save reaction' });

        io.to(`conv:${msg.conversation_id}`).emit('message_reaction_updated', {
            message_id, user_id: socket.userId, emoji,
        });

        await audit.log('react_to_message', {
            userId: socket.userId, targetType: 'message', targetId: message_id, metadata: { emoji },
        });

        ack?.({ ok: true });
    });

    // ── remove_reaction ─────────────────────────────────────────
    // Payload: { message_id }
    socket.on('remove_reaction', async (payload, ack) => {
        const { message_id } = payload ?? {};
        if (!message_id) return ack?.({ error: 'message_id required' });

        const { data: msg } = await supabase
            .from('messages')
            .select('conversation_id')
            .eq('id', message_id)
            .single();

        if (!msg) return ack?.({ error: 'Message not found' });

        await supabase
            .from('message_reactions')
            .delete()
            .eq('message_id', message_id)
            .eq('user_id', socket.userId);

        io.to(`conv:${msg.conversation_id}`).emit('message_reaction_updated', {
            message_id, user_id: socket.userId, emoji: null,
        });

        await audit.log('remove_reaction', { userId: socket.userId, targetType: 'message', targetId: message_id });

        ack?.({ ok: true });
    });

    // ── message_read ───────────────────────────────────────────
    // Payload: { message_id }
    socket.on('message_read', async (payload, ack) => {
        const { message_id } = payload ?? {};
        if (!message_id) return ack?.({ error: 'message_id required' });

        const now = new Date().toISOString();

        // Upsert read receipt
        await supabase.from('message_status').upsert(
            { message_id, user_id: socket.userId, read_at: now, delivered_at: now },
            { onConflict: 'message_id,user_id' }
        );

        // Tell the sender their message was read
        const { data: msg } = await supabase
            .from('messages')
            .select('conversation_id, sender_id')
            .eq('id', message_id)
            .single();

        if (msg) {
            io.to(`conv:${msg.conversation_id}`).emit('message_read_receipt', {
                message_id,
                read_by: socket.userId,
                read_at: now,
            });
        }

        ack?.({ ok: true });
    });

    // ── typing_start / typing_stop ─────────────────────────────
    // Payload: { conversation_id }
    socket.on('typing_start', ({ conversation_id } = {}) => {
        if (!conversation_id) return;
        socket.to(`conv:${conversation_id}`).emit('user_typing', {
            conversation_id,
            user_id: socket.userId,
            username: socket.user.username,
        });
    });

    socket.on('typing_stop', ({ conversation_id } = {}) => {
        if (!conversation_id) return;
        socket.to(`conv:${conversation_id}`).emit('user_stopped_typing', {
            conversation_id,
            user_id: socket.userId,
        });
    });

    // ── delete_message ─────────────────────────────────────────
    // Payload: { message_id }
    socket.on('delete_message', async (payload, ack) => {
        const { message_id } = payload ?? {};
        if (!message_id) return ack?.({ error: 'message_id required' });

        const { data: msg } = await supabase
            .from('messages')
            .select('sender_id, conversation_id')
            .eq('id', message_id)
            .single();

        if (!msg) return ack?.({ error: 'Message not found' });
        if (msg.sender_id !== socket.userId) return ack?.({ error: 'Can only delete your own messages' });

        await supabase
            .from('messages')
            .update({ is_deleted: true, content: null, deleted_at: new Date().toISOString() })
            .eq('id', message_id);

        io.to(`conv:${msg.conversation_id}`).emit('message_deleted', { message_id });
        ack?.({ ok: true });
    });
};

module.exports.createMessage = createMessage;
