const express = require('express');
const supabase = require('../utils/supabase');
const { requireAuth } = require('../middleware/auth');
const audit = require('../services/auditLog');

const router = express.Router();

const VALID_MEDIA_TYPES = ['text', 'image', 'audio', 'video', 'document'];

// ── GET /search/messages ───────────────────────────────────────
// Searches only within conversations the caller is actually a member of.
router.get('/messages', requireAuth, async (req, res) => {
    const { q, conversation_id, sender_id, from_date, to_date, media_type } = req.query;
    const limit = Math.min(parseInt(req.query.limit, 10) || 30, 100);
    const before = req.query.before;

    // Conversations the caller belongs to
    const { data: ownMemberships } = await supabase
        .from('conversation_members')
        .select('conversation_id')
        .eq('user_id', req.user.id)
        .is('left_at', null);

    const ownConvIds = (ownMemberships ?? []).map(m => m.conversation_id);
    if (ownConvIds.length === 0) return res.json({ messages: [], has_more: false });

    let targetConvIds = ownConvIds;
    if (conversation_id) {
        if (!ownConvIds.includes(conversation_id)) {
            return res.status(403).json({ error: 'Not a member of this conversation' });
        }
        targetConvIds = [conversation_id];
    }

    let query = supabase
        .from('messages')
        .select(`
            id, conversation_id, type, content, media_id, created_at,
            users!sender_id ( id, username, full_name, avatar_url ),
            conversations ( id, name, type )
        `)
        .in('conversation_id', targetConvIds)
        .eq('is_deleted', false)
        .order('created_at', { ascending: false })
        .limit(limit);

    if (q) query = query.ilike('content', `%${q}%`);
    if (sender_id) query = query.eq('sender_id', sender_id);
    if (from_date) query = query.gte('created_at', from_date);
    if (to_date) query = query.lte('created_at', to_date);
    if (media_type && VALID_MEDIA_TYPES.includes(media_type)) query = query.eq('type', media_type);
    if (before) query = query.lt('created_at', before);

    const { data: messages, error } = await query;

    if (error) return res.status(500).json({ error: 'Search failed' });

    await audit.log('search_messages', {
        userId: req.user.id,
        metadata: { q: q || null, conversation_id: conversation_id || null, sender_id: sender_id || null, media_type: media_type || null },
        ipAddress: req.ip,
    });

    res.json({ messages, has_more: messages.length === limit });
});

module.exports = router;
