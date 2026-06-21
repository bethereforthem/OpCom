const express = require('express');
const supabase = require('../utils/supabase');
const { requireAuth } = require('../middleware/auth');
const audit = require('../services/auditLog');

const router = express.Router({ mergeParams: true });

router.use(requireAuth);

// ── POST /conversations/:id/scheduled-messages ─────────────────
router.post('/', async (req, res) => {
    const conversation_id = req.params.id;
    const { type = 'text', content, media_id, reply_to_id, send_at } = req.body ?? {};

    if (type === 'text' && !content?.trim()) {
        return res.status(400).json({ error: 'content required for text messages' });
    }
    if (!send_at || new Date(send_at) <= new Date()) {
        return res.status(400).json({ error: 'send_at must be a future timestamp' });
    }

    const { data: membership } = await supabase
        .from('conversation_members')
        .select('role')
        .eq('conversation_id', conversation_id)
        .eq('user_id', req.user.id)
        .is('left_at', null)
        .single();

    if (!membership) return res.status(403).json({ error: 'Not a member of this conversation' });

    const { data, error } = await supabase
        .from('scheduled_messages')
        .insert({
            conversation_id,
            sender_id: req.user.id,
            type,
            content: content?.trim() ?? null,
            media_id: media_id ?? null,
            reply_to_id: reply_to_id ?? null,
            send_at,
        })
        .select('id, type, content, media_id, reply_to_id, send_at, created_at')
        .single();

    if (error) return res.status(500).json({ error: 'Failed to schedule message' });

    await audit.log('schedule_message', {
        userId: req.user.id, targetType: 'conversation', targetId: conversation_id, metadata: { send_at },
    });

    res.status(201).json({ scheduled_message: data });
});

// ── GET /conversations/:id/scheduled-messages ───────────────────
// Only the caller's own pending scheduled messages — invisible to every
// other member, even though they're in the same conversation.
router.get('/', async (req, res) => {
    const { data, error } = await supabase
        .from('scheduled_messages')
        .select('id, type, content, media_id, reply_to_id, send_at, created_at')
        .eq('conversation_id', req.params.id)
        .eq('sender_id', req.user.id)
        .is('sent_at', null)
        .order('send_at', { ascending: true });

    if (error) return res.status(500).json({ error: 'Failed to fetch scheduled messages' });

    res.json({ scheduled_messages: data });
});

// ── DELETE /conversations/:id/scheduled-messages/:scheduledId ──
router.delete('/:scheduledId', async (req, res) => {
    const { data, error } = await supabase
        .from('scheduled_messages')
        .delete()
        .eq('id', req.params.scheduledId)
        .eq('conversation_id', req.params.id)
        .eq('sender_id', req.user.id)
        .is('sent_at', null)
        .select('id')
        .single();

    if (error || !data) return res.status(404).json({ error: 'Scheduled message not found' });

    res.json({ message: 'Scheduled message cancelled' });
});

module.exports = router;
