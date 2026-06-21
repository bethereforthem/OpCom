const supabase = require('../../utils/supabase');
const audit = require('../../services/auditLog');

// In-memory active call state: callId → { callerId, calleeId, type, conversationId, startedAt }
// Using a module-level Map so it persists for the server lifetime
const activeCalls = new Map();

// Find all socket IDs for a given userId
function socketsForUser(onlineUsers, userId) {
    return [...(onlineUsers.get(userId) ?? [])];
}

module.exports = function callingHandler(io, socket, onlineUsers) {

    // ── call_initiate ──────────────────────────────────────────
    // Caller starts a call.
    // Payload: { target_user_id, type: 'audio'|'video', conversation_id? }
    socket.on('call_initiate', async (payload, ack) => {
        const { target_user_id, type = 'audio', conversation_id = null } = payload ?? {};

        if (!target_user_id) return ack?.({ error: 'target_user_id required' });
        if (!['audio', 'video'].includes(type)) return ack?.({ error: 'type must be audio or video' });
        if (target_user_id === socket.userId) return ack?.({ error: 'Cannot call yourself' });

        // Check callee exists and is active
        const { data: callee } = await supabase
            .from('users')
            .select('id, full_name, username, avatar_url')
            .eq('id', target_user_id)
            .eq('is_active', true)
            .eq('is_locked', false)
            .single();

        if (!callee) return ack?.({ error: 'User not found or inactive' });

        // Check callee is not already in a call
        const calleeAlreadyBusy = [...activeCalls.values()]
            .some(c => c.calleeId === target_user_id || c.callerId === target_user_id);

        if (calleeAlreadyBusy) {
            ack?.({ error: 'busy' });
            socket.emit('call_busy', { target_user_id });
            return;
        }

        // Create call log row
        const { data: callLog, error: callLogError } = await supabase
            .from('call_logs')
            .insert({
                conversation_id,
                caller_id: socket.userId,
                callee_id: target_user_id,
                type,
                status: 'ringing',
            })
            .select('id')
            .single();

        if (callLogError || !callLog) {
            console.error('call_initiate: failed to create call_logs row:', callLogError);
            return ack?.({ error: 'Failed to start call' });
        }

        const callId = callLog.id;

        // Track in memory
        activeCalls.set(callId, {
            callerId: socket.userId,
            calleeId: target_user_id,
            type,
            conversationId: conversation_id,
            startedAt: Date.now(),
        });

        // Notify callee on all their devices
        const callerInfo = {
            id: socket.user.id,
            username: socket.user.username,
            full_name: socket.user.full_name,
            avatar_url: socket.user.avatar_url,
        };

        const calleeSocketIds = socketsForUser(onlineUsers, target_user_id);
        if (calleeSocketIds.length === 0) {
            // Callee is offline — mark as missed immediately
            await supabase
                .from('call_logs')
                .update({ status: 'missed', ended_at: new Date().toISOString() })
                .eq('id', callId);
            activeCalls.delete(callId);
            ack?.({ error: 'offline', call_id: callId });
            return;
        }

        calleeSocketIds.forEach(sid => {
            io.to(sid).emit('incoming_call', {
                call_id: callId,
                type,
                caller: callerInfo,
                conversation_id,
            });
        });

        // Auto-miss if callee doesn't answer within 45 seconds
        setTimeout(async () => {
            const call = activeCalls.get(callId);
            if (call && call.calleeId === target_user_id) {
                activeCalls.delete(callId);
                await supabase
                    .from('call_logs')
                    .update({ status: 'missed', ended_at: new Date().toISOString() })
                    .eq('id', callId)
                    .eq('status', 'ringing');

                // Notify both parties
                socketsForUser(onlineUsers, socket.userId).forEach(sid =>
                    io.to(sid).emit('call_missed', { call_id: callId, target_user_id })
                );
                calleeSocketIds.forEach(sid =>
                    io.to(sid).emit('call_missed', { call_id: callId, caller_id: socket.userId })
                );
            }
        }, 45_000);

        await audit.log('call_initiate', {
            userId: socket.userId,
            targetType: 'call',
            targetId: callId,
            metadata: { type, callee_id: target_user_id },
        });

        ack?.({ ok: true, call_id: callId });
    });

    // ── call_offer ─────────────────────────────────────────────
    // Caller sends SDP offer to callee after call is accepted.
    // Payload: { call_id, target_user_id, sdp }
    socket.on('call_offer', ({ call_id, target_user_id, sdp } = {}) => {
        if (!call_id || !target_user_id || !sdp) return;
        socketsForUser(onlineUsers, target_user_id).forEach(sid => {
            io.to(sid).emit('call_offer_received', {
                call_id,
                sdp,
                caller_id: socket.userId,
            });
        });
    });

    // ── call_answer ────────────────────────────────────────────
    // Callee accepts and sends SDP answer.
    // Payload: { call_id, caller_user_id, sdp }
    socket.on('call_answer', async ({ call_id, caller_user_id, sdp } = {}) => {
        if (!call_id || !caller_user_id || !sdp) return;

        const call = activeCalls.get(call_id);
        if (!call) return;

        await supabase
            .from('call_logs')
            .update({ status: 'active', answered_at: new Date().toISOString() })
            .eq('id', call_id);

        socketsForUser(onlineUsers, caller_user_id).forEach(sid => {
            io.to(sid).emit('call_answered', { call_id, sdp });
        });
    });

    // ── call_ice_candidate ─────────────────────────────────────
    // Exchange ICE candidates between peers.
    // Payload: { call_id, target_user_id, candidate }
    socket.on('call_ice_candidate', ({ call_id, target_user_id, candidate } = {}) => {
        if (!call_id || !target_user_id || !candidate) return;
        socketsForUser(onlineUsers, target_user_id).forEach(sid => {
            io.to(sid).emit('ice_candidate', {
                call_id,
                candidate,
                from_user_id: socket.userId,
            });
        });
    });

    // ── call_reject ────────────────────────────────────────────
    // Callee declines the call.
    // Payload: { call_id, caller_user_id }
    socket.on('call_reject', async ({ call_id, caller_user_id } = {}) => {
        if (!call_id) return;

        activeCalls.delete(call_id);

        await supabase
            .from('call_logs')
            .update({ status: 'rejected', ended_at: new Date().toISOString() })
            .eq('id', call_id);

        socketsForUser(onlineUsers, caller_user_id).forEach(sid => {
            io.to(sid).emit('call_rejected', {
                call_id,
                by_user_id: socket.userId,
            });
        });

        await audit.log('call_rejected', {
            userId: socket.userId,
            targetType: 'call',
            targetId: call_id,
        });
    });

    // ── call_end ───────────────────────────────────────────────
    // Either party ends an active call.
    // Payload: { call_id }
    socket.on('call_end', async ({ call_id } = {}) => {
        if (!call_id) return;

        const call = activeCalls.get(call_id);
        if (!call) return;

        activeCalls.delete(call_id);

        const endedAt = new Date().toISOString();
        await supabase
            .from('call_logs')
            .update({ status: 'ended', ended_at: endedAt, ended_by: socket.userId })
            .eq('id', call_id);

        // Notify the other party
        const otherId = call.callerId === socket.userId ? call.calleeId : call.callerId;
        socketsForUser(onlineUsers, otherId).forEach(sid => {
            io.to(sid).emit('call_ended', {
                call_id,
                by_user_id: socket.userId,
            });
        });

        await audit.log('call_ended', {
            userId: socket.userId,
            targetType: 'call',
            targetId: call_id,
        });
    });
};

module.exports.activeCalls = activeCalls;
