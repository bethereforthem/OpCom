const express = require('express');
const supabase = require('../utils/supabase');
const { requireAuth, requirePermission } = require('../middleware/auth');

const router = express.Router();

// Username/email/staff_id only ever contain these characters — reject anything
// else before it reaches the PostgREST `.or()` filter string, since that
// string is built by raw interpolation and a comma/parenthesis would let the
// caller append arbitrary extra filter clauses.
const SAFE_IDENTIFIER = /^[\w.+@-]+$/;

// ── GET /users/lookup?identifier= ──────────────────────────────
// Resolve a username/email/staff_id to a minimal public profile,
// so a client can start a conversation without knowing the user's UUID.
router.get('/lookup', requireAuth, requirePermission('send_message'), async (req, res) => {
    const identifier = (req.query.identifier || '').trim();
    if (!identifier) return res.status(400).json({ error: 'identifier query param is required' });
    if (!SAFE_IDENTIFIER.test(identifier)) return res.status(404).json({ error: 'User not found' });

    const { data: user, error } = await supabase
        .from('users')
        .select('id, username, full_name, avatar_url, is_active, is_locked')
        .or(`username.eq.${identifier},email.eq.${identifier},staff_id.eq.${identifier}`)
        .single();

    if (error || !user || !user.is_active || user.is_locked) {
        return res.status(404).json({ error: 'User not found' });
    }
    if (user.id === req.user.id) {
        return res.status(400).json({ error: 'Cannot start a conversation with yourself' });
    }

    res.json({
        user: {
            id: user.id,
            username: user.username,
            full_name: user.full_name,
            avatar_url: user.avatar_url,
        },
    });
});

module.exports = router;
