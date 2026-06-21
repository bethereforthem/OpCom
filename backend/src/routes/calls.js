const express = require('express');
const crypto = require('crypto');
const supabase = require('../utils/supabase');
const { requireAuth } = require('../middleware/auth');

const router = express.Router();

// ── GET /calls/history ─────────────────────────────────────────
// Paginated call log for the current user
router.get('/history', requireAuth, async (req, res) => {
    const limit = Math.min(parseInt(req.query.limit, 10) || 30, 100);
    const before = req.query.before;

    let query = supabase
        .from('call_logs')
        .select(`
            id, type, status, started_at, answered_at, ended_at, duration_seconds,
            caller:users!caller_id ( id, username, full_name, avatar_url ),
            callee:users!callee_id ( id, username, full_name, avatar_url )
        `)
        .or(`caller_id.eq.${req.user.id},callee_id.eq.${req.user.id}`)
        .order('started_at', { ascending: false })
        .limit(limit);

    if (before) query = query.lt('started_at', before);

    const { data, error } = await query;
    if (error) return res.status(500).json({ error: 'Failed to fetch call history' });

    res.json({ calls: data, has_more: data.length === limit });
});

// ── GET /calls/turn-credentials ───────────────────────────────
// Returns short-lived TURN credentials for WebRTC ICE negotiation.
// Uses HMAC-based time-limited credentials (coturn compatible).
router.get('/turn-credentials', requireAuth, (req, res) => {
    const turnSecret = process.env.TURN_SECRET;
    const turnHost   = process.env.TURN_HOST || 'localhost';
    const turnPort   = process.env.TURN_PORT || '3478';

    if (!turnSecret) {
        // In development without a TURN server, return public Google STUN only
        return res.json({
            ice_servers: [
                { urls: 'stun:stun.l.google.com:19302' },
                { urls: 'stun:stun1.l.google.com:19302' },
            ],
        });
    }

    // HMAC time-limited credential — valid for 1 hour
    const ttl       = 3600;
    const timestamp = Math.floor(Date.now() / 1000) + ttl;
    const username  = `${timestamp}:${req.user.id}`;
    const password  = crypto
        .createHmac('sha1', turnSecret)
        .update(username)
        .digest('base64');

    res.json({
        ice_servers: [
            { urls: `stun:${turnHost}:${turnPort}` },
            {
                urls: [
                    `turn:${turnHost}:${turnPort}?transport=udp`,
                    `turn:${turnHost}:${turnPort}?transport=tcp`,
                ],
                username,
                credential: password,
            },
        ],
        ttl,
    });
});

module.exports = router;
