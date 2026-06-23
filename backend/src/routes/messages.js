const express = require('express');
const supabase = require('../utils/supabase');
const { requireAuth } = require('../middleware/auth');

const router = express.Router({ mergeParams: true });

// ── GET /conversations/:id/messages ───────────────────────────
// Paginated message history, newest first
router.get('/', requireAuth, async (req, res) => {
    const { id: conversation_id } = req.params;
    const limit = Math.min(parseInt(req.query.limit, 10) || 50, 100);
    const before = req.query.before; // ISO timestamp cursor for pagination

    // Verify membership
    const { data: membership } = await supabase
        .from('conversation_members')
        .select('role')
        .eq('conversation_id', conversation_id)
        .eq('user_id', req.user.id)
        .is('left_at', null)
        .single();

    if (!membership) return res.status(403).json({ error: 'Access denied' });

    let query = supabase
        .from('messages')
        .select(`
            id, sender_id, type, content, media_id, reply_to_id, forwarded_from_id,
            is_deleted, edited_at, system_event, system_params, created_at,
            users!sender_id ( id, username, full_name, avatar_url ),
            message_status ( user_id, delivered_at, read_at ),
            message_reactions ( user_id, emoji ),
            message_mentions ( mentioned_user_id )
        `)
        .eq('conversation_id', conversation_id)
        .order('created_at', { ascending: false })
        .limit(limit);

    if (before) query = query.lt('created_at', before);

    const { data: messages, error } = await query;

    if (error) return res.status(500).json({ error: 'Failed to fetch messages' });

    // Batch-fetch reply-to and forwarded-from previews together. Not done via
    // a PostgREST embed above — self-referencing FKs on the same table are
    // ambiguous to embed (see 004/005 migration notes).
    const relatedIds = [...new Set(
        messages.flatMap(m => [m.reply_to_id, m.forwarded_from_id]).filter(Boolean)
    )];

    let byId = new Map();
    if (relatedIds.length) {
        const { data: related } = await supabase
            .from('messages')
            .select('id, content, type, is_deleted, users!sender_id ( id, username, full_name )')
            .in('id', relatedIds);

        byId = new Map((related ?? []).map(m => [m.id, m]));
    }

    messages.forEach(m => {
        m.reply_to = m.reply_to_id ? (byId.get(m.reply_to_id) ?? null) : null;
        m.forwarded_from = m.forwarded_from_id ? (byId.get(m.forwarded_from_id) ?? null) : null;
    });

    res.json({
        messages: messages.reverse(), // return oldest→newest
        has_more: messages.length === limit,
    });
});

module.exports = router;
