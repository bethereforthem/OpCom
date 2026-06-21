const { verifyToken } = require('../utils/jwt');
const supabase = require('../utils/supabase');

// Verifies JWT and attaches user + permissions to req
async function requireAuth(req, res, next) {
    const header = req.headers.authorization;
    if (!header || !header.startsWith('Bearer ')) {
        return res.status(401).json({ error: 'Missing authorization token' });
    }

    let payload;
    try {
        payload = verifyToken(header.slice(7));
    } catch {
        return res.status(401).json({ error: 'Invalid or expired token' });
    }

    // Check session is still active in DB (covers revocation)
    const { data: session } = await supabase
        .from('sessions')
        .select('id, expires_at')
        .eq('jwt_jti', payload.jti)
        .single();

    if (!session || new Date(session.expires_at) < new Date()) {
        return res.status(401).json({ error: 'Session expired or revoked' });
    }

    // Fetch user with their permissions via role
    const { data: user } = await supabase
        .from('users')
        .select(`
            id, username, email, staff_id, full_name, is_active, is_locked, role_id, locale,
            avatar_url, bio, status_message, theme_preference,
            notif_sound_enabled, notif_vibrate_enabled,
            privacy_read_receipts, privacy_show_typing,
            chat_auto_download_media, chat_message_text_scale,
            roles (
                name,
                role_permissions ( permissions ( name ) )
            )
        `)
        .eq('id', payload.sub)
        .single();

    if (!user || !user.is_active || user.is_locked) {
        return res.status(403).json({ error: 'Account is inactive or locked' });
    }

    // Flatten permissions into a Set for O(1) checks
    const permissions = new Set(
        user.roles?.role_permissions?.map(rp => rp.permissions.name) ?? []
    );

    req.user = user;
    req.permissions = permissions;
    next();
}

// Factory: require a specific permission
function requirePermission(permissionName) {
    return (req, res, next) => {
        if (!req.permissions?.has(permissionName)) {
            return res.status(403).json({ error: `Permission denied: ${permissionName}` });
        }
        next();
    };
}

module.exports = { requireAuth, requirePermission };
