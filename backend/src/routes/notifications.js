const express = require('express');
const supabase = require('../utils/supabase');
const { requireAuth } = require('../middleware/auth');

const router = express.Router();

router.use(requireAuth);

// ── GET /notifications ─────────────────────────────────────────
router.get('/', async (req, res) => {
    const limit  = Math.min(parseInt(req.query.limit, 10) || 50, 100);
    const offset = parseInt(req.query.offset, 10) || 0;

    const { data, count, error } = await supabase
        .from('notifications')
        .select('id, type, title, body, metadata, is_read, read_at, created_at', { count: 'exact' })
        .eq('user_id', req.user.id)
        .order('created_at', { ascending: false })
        .range(offset, offset + limit - 1);

    if (error) return res.status(500).json({ error: 'Failed to fetch notifications' });

    res.json({ notifications: data, total: count });
});

// ── PATCH /notifications/:id/read ──────────────────────────────
router.patch('/:id/read', async (req, res) => {
    const { data, error } = await supabase
        .from('notifications')
        .update({ is_read: true, read_at: new Date().toISOString() })
        .eq('id', req.params.id)
        .eq('user_id', req.user.id)
        .select('id')
        .single();

    if (error || !data) return res.status(404).json({ error: 'Notification not found' });

    res.json({ message: 'Marked as read' });
});

module.exports = router;
