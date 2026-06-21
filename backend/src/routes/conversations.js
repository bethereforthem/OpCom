const express = require('express');
const supabase = require('../utils/supabase');
const { requireAuth, requirePermission } = require('../middleware/auth');
const audit = require('../services/auditLog');

const router = express.Router();

// ── GET /conversations ─────────────────────────────────────────
// List all conversations for the current user, newest activity first.
// ?archived=true returns only this user's archived conversations instead.
router.get('/', requireAuth, async (req, res) => {
    const wantArchived = req.query.archived === 'true';

    let query = supabase
        .from('conversation_members')
        .select(`
            joined_at, archived_at, is_muted, muted_until, role,
            conversations (
                id, type, name, avatar_url, updated_at, disappearing_duration_seconds,
                conversation_members (
                    user_id,
                    users ( id, username, full_name, avatar_url )
                )
            )
        `)
        .eq('user_id', req.user.id)
        .is('left_at', null)
        .order('conversations(updated_at)', { ascending: false });

    query = wantArchived ? query.not('archived_at', 'is', null) : query.is('archived_at', null);

    const { data, error } = await query;

    if (error) return res.status(500).json({ error: 'Failed to fetch conversations' });

    res.json({
        conversations: data.map(d => ({
            ...d.conversations,
            archived_at: d.archived_at,
            is_muted: d.is_muted,
            muted_until: d.muted_until,
            my_role: d.role,
        })),
    });
});

// ── POST /conversations ────────────────────────────────────────
// Create a private (2-person) or group conversation
router.post('/', requireAuth, requirePermission('send_message'), async (req, res) => {
    const { type, name, member_ids } = req.body;

    if (!type || !['private', 'group'].includes(type)) {
        return res.status(400).json({ error: 'type must be "private" or "group"' });
    }
    if (!Array.isArray(member_ids) || member_ids.length === 0) {
        return res.status(400).json({ error: 'member_ids array required' });
    }
    if (type === 'private' && member_ids.length !== 1) {
        return res.status(400).json({ error: 'Private conversation requires exactly 1 other member' });
    }
    if (type === 'group' && !name?.trim()) {
        return res.status(400).json({ error: 'Group conversations require a name' });
    }

    // Prevent duplicate private conversations
    if (type === 'private') {
        const otherId = member_ids[0];
        const { data: existing } = await supabase.rpc('find_private_conversation', {
            user_a: req.user.id,
            user_b: otherId,
        });
        if (existing?.length) {
            return res.json({ conversation: existing[0], already_existed: true });
        }
    }

    // Create conversation
    const { data: conversation, error: convErr } = await supabase
        .from('conversations')
        .insert({ type, name: name?.trim() ?? null, created_by: req.user.id })
        .select('id, type, name, created_at')
        .single();

    if (convErr) return res.status(500).json({ error: 'Failed to create conversation' });

    // Add creator + all members
    const allMembers = [
        { conversation_id: conversation.id, user_id: req.user.id, role: type === 'group' ? 'owner' : 'member' },
        ...member_ids.map(uid => ({ conversation_id: conversation.id, user_id: uid, role: 'member' })),
    ];

    await supabase.from('conversation_members').insert(allMembers);

    await audit.log('create_conversation', {
        userId: req.user.id,
        targetType: 'conversation',
        targetId: conversation.id,
        metadata: { type, member_count: allMembers.length },
        ipAddress: req.ip,
    });

    res.status(201).json({ conversation });
});

// ── GET /conversations/:id ─────────────────────────────────────
// Get a single conversation with its members
router.get('/:id', requireAuth, async (req, res) => {
    const { data, error } = await supabase
        .from('conversations')
        .select(`
            id, type, name, avatar_url, created_at, updated_at,
            conversation_members (
                role, joined_at,
                users ( id, username, full_name, avatar_url )
            )
        `)
        .eq('id', req.params.id)
        .single();

    if (error || !data) return res.status(404).json({ error: 'Conversation not found' });

    // Ensure requester is a member
    const isMember = data.conversation_members.some(m => m.users.id === req.user.id);
    if (!isMember) return res.status(403).json({ error: 'Access denied' });

    res.json({ conversation: data });
});

// ── PATCH /conversations/:id/archive ───────────────────────────
router.patch('/:id/archive', requireAuth, async (req, res) => {
    const { data, error } = await supabase
        .from('conversation_members')
        .update({ archived_at: new Date().toISOString() })
        .eq('conversation_id', req.params.id)
        .eq('user_id', req.user.id)
        .is('left_at', null)
        .select('conversation_id')
        .single();

    if (error || !data) return res.status(404).json({ error: 'Not a member of this conversation' });

    await audit.log('archive_conversation', {
        userId: req.user.id, targetType: 'conversation', targetId: req.params.id,
    });

    res.json({ message: 'Conversation archived' });
});

// ── PATCH /conversations/:id/unarchive ─────────────────────────
router.patch('/:id/unarchive', requireAuth, async (req, res) => {
    const { data, error } = await supabase
        .from('conversation_members')
        .update({ archived_at: null })
        .eq('conversation_id', req.params.id)
        .eq('user_id', req.user.id)
        .is('left_at', null)
        .select('conversation_id')
        .single();

    if (error || !data) return res.status(404).json({ error: 'Not a member of this conversation' });

    await audit.log('unarchive_conversation', {
        userId: req.user.id, targetType: 'conversation', targetId: req.params.id,
    });

    res.json({ message: 'Conversation unarchived' });
});

// ── PATCH /conversations/:id/mute ──────────────────────────────
// Body: { duration: '8h' | '1w' | 'always' }
const MUTE_DURATIONS = {
    '8h': () => new Date(Date.now() + 8 * 60 * 60 * 1000).toISOString(),
    '1w': () => new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString(),
    always: () => null,
};

router.patch('/:id/mute', requireAuth, async (req, res) => {
    const { duration } = req.body ?? {};
    if (!MUTE_DURATIONS[duration]) {
        return res.status(400).json({ error: "duration must be one of '8h', '1w', 'always'" });
    }

    const { data, error } = await supabase
        .from('conversation_members')
        .update({ is_muted: true, muted_until: MUTE_DURATIONS[duration]() })
        .eq('conversation_id', req.params.id)
        .eq('user_id', req.user.id)
        .is('left_at', null)
        .select('conversation_id, muted_until')
        .single();

    if (error || !data) return res.status(404).json({ error: 'Not a member of this conversation' });

    await audit.log('mute_conversation', {
        userId: req.user.id, targetType: 'conversation', targetId: req.params.id, metadata: { duration },
    });

    res.json({ message: 'Conversation muted', muted_until: data.muted_until });
});

// ── PATCH /conversations/:id/unmute ────────────────────────────
router.patch('/:id/unmute', requireAuth, async (req, res) => {
    const { data, error } = await supabase
        .from('conversation_members')
        .update({ is_muted: false, muted_until: null })
        .eq('conversation_id', req.params.id)
        .eq('user_id', req.user.id)
        .is('left_at', null)
        .select('conversation_id')
        .single();

    if (error || !data) return res.status(404).json({ error: 'Not a member of this conversation' });

    await audit.log('unmute_conversation', {
        userId: req.user.id, targetType: 'conversation', targetId: req.params.id,
    });

    res.json({ message: 'Conversation unmuted' });
});

// ── PATCH /conversations/:id/disappearing ──────────────────────
// Body: { duration: '24h' | '7d' | '90d' | null }
// Shared conversation-level setting (unlike archive/mute above, which are
// per-user) — every member sees the same state.
const DISAPPEARING_DURATIONS = { '24h': 24 * 60 * 60, '7d': 7 * 24 * 60 * 60, '90d': 90 * 24 * 60 * 60 };
const DISAPPEARING_LABELS = { '24h': '24 hours', '7d': '7 days', '90d': '90 days' };

router.patch('/:id/disappearing', requireAuth, async (req, res) => {
    const { duration } = req.body ?? {};
    if (duration !== null && !DISAPPEARING_DURATIONS[duration]) {
        return res.status(400).json({ error: "duration must be one of '24h', '7d', '90d', or null" });
    }

    const { data: membership } = await supabase
        .from('conversation_members')
        .select('role, conversations ( type )')
        .eq('conversation_id', req.params.id)
        .eq('user_id', req.user.id)
        .is('left_at', null)
        .single();

    if (!membership) return res.status(404).json({ error: 'Not a member of this conversation' });

    // Groups require owner/admin; private conversations allow either member.
    if (membership.conversations?.type === 'group' && !['owner', 'admin'].includes(membership.role)) {
        return res.status(403).json({ error: 'Only group owners/admins can change disappearing messages' });
    }

    const seconds = duration ? DISAPPEARING_DURATIONS[duration] : null;

    const { error } = await supabase
        .from('conversations')
        .update({ disappearing_duration_seconds: seconds })
        .eq('id', req.params.id);

    if (error) return res.status(500).json({ error: 'Failed to update disappearing messages setting' });

    const label = duration
        ? `turned on disappearing messages (${DISAPPEARING_LABELS[duration]})`
        : 'turned off disappearing messages';

    const { data: sysMsg } = await supabase
        .from('messages')
        .insert({
            conversation_id: req.params.id,
            sender_id: req.user.id,
            type: 'system',
            // `content` is an English fallback for any client that hasn't been
            // updated to render from system_event/system_params yet.
            content: `${req.user.full_name} ${label}`,
            system_event: duration ? 'disappearing_on' : 'disappearing_off',
            system_params: { actor_full_name: req.user.full_name, duration_key: duration },
        })
        .select('id, conversation_id, type, content, system_event, system_params, created_at')
        .single();

    const io = req.app.get('io');
    if (sysMsg) io.to(`conv:${req.params.id}`).emit('new_message', sysMsg);
    io.to(`conv:${req.params.id}`).emit('disappearing_settings_updated', {
        conversation_id: req.params.id,
        disappearing_duration_seconds: seconds,
    });

    await audit.log('set_disappearing', {
        userId: req.user.id, targetType: 'conversation', targetId: req.params.id, metadata: { duration },
    });

    res.json({ message: 'Disappearing messages updated', disappearing_duration_seconds: seconds });
});

// ── DELETE /conversations/:id/leave ───────────────────────────
router.delete('/:id/leave', requireAuth, async (req, res) => {
    await supabase
        .from('conversation_members')
        .update({ left_at: new Date().toISOString() })
        .eq('conversation_id', req.params.id)
        .eq('user_id', req.user.id);

    res.json({ message: 'Left conversation' });
});

module.exports = router;
