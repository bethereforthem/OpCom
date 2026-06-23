const express = require('express');
const bcrypt = require('bcryptjs');
const { authenticator } = require('otplib');
const QRCode = require('qrcode');
const { v4: uuidv4 } = require('uuid');
const supabase = require('../utils/supabase');
const { signToken } = require('../utils/jwt');
const { sendOtpEmail } = require('../utils/email');
const { requireAuth } = require('../middleware/auth');
const audit = require('../services/auditLog');

const router = express.Router();
const BCRYPT_ROUNDS = parseInt(process.env.BCRYPT_ROUNDS, 10) || 12;
const OTP_MINUTES = parseInt(process.env.OTP_EXPIRES_MINUTES, 10) || 10;

// Username/email/staff_id only ever contain these characters — reject anything
// else before it reaches the PostgREST `.or()` filter string, since that
// string is built by raw interpolation and a comma/parenthesis would let the
// caller append arbitrary extra filter clauses.
const SAFE_IDENTIFIER = /^[\w.+@-]+$/;
const VALID_LOCALES = ['en', 'rw', 'fr'];

// ── POST /auth/register ──────────────────────────────────────
// Admin-only endpoint to create new user accounts
router.post('/register', requireAuth, async (req, res) => {
    if (!req.permissions.has('create_user')) {
        return res.status(403).json({ error: 'Permission denied: create_user' });
    }

    const { username, email, staff_id, password, full_name, role_id, locale } = req.body;

    if (!username || !password || !full_name) {
        return res.status(400).json({ error: 'username, password, and full_name are required' });
    }

    const password_hash = await bcrypt.hash(password, BCRYPT_ROUNDS);

    const { data: user, error } = await supabase
        .from('users')
        .insert({
            username, email, staff_id, password_hash, full_name, role_id,
            locale: VALID_LOCALES.includes(locale) ? locale : 'en',
        })
        .select('id, username, email, staff_id, full_name, role_id, locale')
        .single();

    if (error) {
        if (error.code === '23505') {
            return res.status(409).json({ error: 'Username, email, or staff_id already exists' });
        }
        return res.status(500).json({ error: 'Failed to create user' });
    }

    await audit.log('create_user', {
        userId: req.user.id,
        targetType: 'user',
        targetId: user.id,
        ipAddress: req.ip,
    });

    res.status(201).json({ message: 'User created', user });
});

// ── POST /auth/signup ────────────────────────────────────────
// Public self-registration. Accounts start inactive and locked out of
// login until an admin approves them from Admin > Users (matches the
// app's existing approval-gated posture: device approval, RBAC, audit log).
const OFFICER_ROLE_ID = '00000000-0000-0000-0000-000000000003'; // seeded in 001_seed_roles_permissions.sql
router.post('/signup', async (req, res) => {
    const { username, password, full_name, email, staff_id, phone_number, locale } = req.body;

    if (!username || !password || !full_name) {
        return res.status(400).json({ error: 'username, password, and full_name are required' });
    }
    if (password.length < 8) {
        return res.status(400).json({ error: 'Password must be at least 8 characters' });
    }

    const password_hash = await bcrypt.hash(password, BCRYPT_ROUNDS);

    const { data: user, error } = await supabase
        .from('users')
        .insert({
            username,
            email: email || null,
            staff_id: staff_id || null,
            phone_number: phone_number || null,
            password_hash,
            full_name,
            role_id: OFFICER_ROLE_ID,
            is_active: false,
            locale: VALID_LOCALES.includes(locale) ? locale : 'en',
        })
        .select('id, username, full_name')
        .single();

    if (error) {
        if (error.code === '23505') {
            return res.status(409).json({ error: 'Username, email, phone number, or staff_id already exists' });
        }
        return res.status(500).json({ error: 'Failed to create account' });
    }

    await audit.log('self_register', {
        userId: user.id,
        targetType: 'user',
        targetId: user.id,
        ipAddress: req.ip,
    });

    res.status(201).json({
        message: 'Account created. An administrator must approve your account before you can sign in.',
    });
});

// ── POST /auth/login ─────────────────────────────────────────
// Step 1: validate credentials → returns mfa_required flag
router.post('/login', async (req, res) => {
    const { identifier, password, device_fingerprint } = req.body;

    if (!identifier || !password) {
        return res.status(400).json({ error: 'identifier and password are required' });
    }
    if (!SAFE_IDENTIFIER.test(identifier)) {
        return res.status(401).json({ error: 'Invalid credentials' });
    }

    // Find user by username, email, or staff_id
    const { data: user } = await supabase
        .from('users')
        .select('id, username, email, staff_id, full_name, password_hash, is_active, is_locked, role_id, locale')
        .or(`username.eq.${identifier},email.eq.${identifier},staff_id.eq.${identifier}`)
        .single();

    const recordAttempt = async (success, reason = null) => {
        await supabase.from('login_attempts').insert({
            identifier,
            user_id: user?.id ?? null,
            success,
            failure_reason: reason,
            ip_address: req.ip,
            user_agent: req.headers['user-agent'],
        });
    };

    if (!user) {
        await recordAttempt(false, 'user_not_found');
        return res.status(401).json({ error: 'Invalid credentials' });
    }

    if (user.is_locked) {
        await recordAttempt(false, 'account_locked');
        return res.status(403).json({ error: 'Account is locked. Contact your administrator.' });
    }

    if (!user.is_active) {
        await recordAttempt(false, 'account_inactive');
        return res.status(403).json({ error: 'Account is inactive.' });
    }

    const passwordOk = await bcrypt.compare(password, user.password_hash);
    if (!passwordOk) {
        await recordAttempt(false, 'bad_password');
        return res.status(401).json({ error: 'Invalid credentials' });
    }

    // Check if device is approved (if fingerprint provided)
    if (device_fingerprint) {
        const { data: device } = await supabase
            .from('authorized_devices')
            .select('id, is_active')
            .eq('user_id', user.id)
            .eq('device_fingerprint', device_fingerprint)
            .single();

        if (!device || !device.is_active) {
            await recordAttempt(false, 'unauthorized_device');
            return res.status(403).json({ error: 'Device not authorized. Request approval from your administrator.' });
        }
    }

    // Check MFA config
    const { data: mfa } = await supabase
        .from('user_mfa')
        .select('method, is_enabled')
        .eq('user_id', user.id)
        .single();

    if (mfa?.is_enabled) {
        // Issue a short-lived pre-auth token so the MFA step knows who is verifying
        const { token: preAuthToken } = signToken({ sub: user.id, stage: 'pre_mfa' });

        if (mfa.method === 'email_otp') {
            const rawCode = Math.floor(100000 + Math.random() * 900000).toString();
            const code_hash = await bcrypt.hash(rawCode, 10);
            const expires_at = new Date(Date.now() + OTP_MINUTES * 60 * 1000).toISOString();

            await supabase.from('otp_codes').insert({
                user_id: user.id,
                code_hash,
                purpose: 'mfa',
                expires_at,
            });

            await sendOtpEmail(user.email, rawCode, user.full_name, user.locale);
        }

        await recordAttempt(true);
        return res.json({
            mfa_required: true,
            mfa_method: mfa.method,
            pre_auth_token: preAuthToken,
        });
    }

    // No MFA — issue full session token
    await recordAttempt(true);
    const expiresAt = new Date(Date.now() + 8 * 60 * 60 * 1000);
    const { token, jti } = signToken({ sub: user.id, role_id: user.role_id });

    await supabase.from('sessions').insert({
        user_id: user.id,
        jwt_jti: jti,
        ip_address: req.ip,
        user_agent: req.headers['user-agent'],
        expires_at: expiresAt.toISOString(),
    });

    await supabase.from('users').update({ last_login_at: new Date().toISOString() }).eq('id', user.id);
    await audit.log('login', { userId: user.id, ipAddress: req.ip });

    res.json({ token, expires_at: expiresAt });
});

// ── POST /auth/mfa/verify ────────────────────────────────────
// Step 2: submit the OTP or TOTP code to complete login
router.post('/mfa/verify', async (req, res) => {
    const { pre_auth_token, code } = req.body;

    if (!pre_auth_token || !code) {
        return res.status(400).json({ error: 'pre_auth_token and code are required' });
    }

    let payload;
    try {
        const jwt = require('../utils/jwt');
        payload = jwt.verifyToken(pre_auth_token);
    } catch {
        return res.status(401).json({ error: 'Invalid or expired pre-auth token' });
    }

    if (payload.stage !== 'pre_mfa') {
        return res.status(400).json({ error: 'Invalid token stage' });
    }

    const userId = payload.sub;

    const { data: mfa } = await supabase
        .from('user_mfa')
        .select('method, totp_secret')
        .eq('user_id', userId)
        .single();

    if (!mfa) {
        return res.status(400).json({ error: 'MFA not configured' });
    }

    let valid = false;

    if (mfa.method === 'totp') {
        valid = authenticator.verify({ token: code, secret: mfa.totp_secret });
    } else {
        // email_otp — find the most recent unused, unexpired code
        const { data: otpRow } = await supabase
            .from('otp_codes')
            .select('id, code_hash, expires_at')
            .eq('user_id', userId)
            .eq('purpose', 'mfa')
            .is('used_at', null)
            .gte('expires_at', new Date().toISOString())
            .order('created_at', { ascending: false })
            .limit(1)
            .single();

        if (otpRow) {
            valid = await bcrypt.compare(code, otpRow.code_hash);
            if (valid) {
                await supabase
                    .from('otp_codes')
                    .update({ used_at: new Date().toISOString() })
                    .eq('id', otpRow.id);
            }
        }
    }

    if (!valid) {
        return res.status(401).json({ error: 'Invalid verification code' });
    }

    // MFA passed — fetch user role and issue full session
    const { data: user } = await supabase
        .from('users')
        .select('id, role_id')
        .eq('id', userId)
        .single();

    const expiresAt = new Date(Date.now() + 8 * 60 * 60 * 1000);
    const { token, jti } = signToken({ sub: user.id, role_id: user.role_id });

    await supabase.from('sessions').insert({
        user_id: user.id,
        jwt_jti: jti,
        ip_address: req.ip,
        user_agent: req.headers['user-agent'],
        expires_at: expiresAt.toISOString(),
    });

    await supabase.from('users').update({ last_login_at: new Date().toISOString() }).eq('id', user.id);
    await audit.log('login_mfa_success', { userId: user.id, ipAddress: req.ip });

    res.json({ token, expires_at: expiresAt });
});

// ── POST /auth/mfa/setup/totp ─────────────────────────────────
// Generate a TOTP secret and QR code for Google Authenticator
router.post('/mfa/setup/totp', requireAuth, async (req, res) => {
    const secret = authenticator.generateSecret();
    const otpauth = authenticator.keyuri(
        req.user.username,
        'OpCom',
        secret
    );
    const qrCodeDataUrl = await QRCode.toDataURL(otpauth);

    // Store secret (not yet enabled — user must confirm first)
    await supabase.from('user_mfa').upsert({
        user_id: req.user.id,
        method: 'totp',
        totp_secret: secret,
        is_enabled: false,
    }, { onConflict: 'user_id' });

    res.json({ qr_code: qrCodeDataUrl, secret });
});

// ── POST /auth/mfa/setup/confirm ─────────────────────────────
// User confirms TOTP by submitting a valid code — activates MFA
router.post('/mfa/setup/confirm', requireAuth, async (req, res) => {
    const { code } = req.body;

    const { data: mfa } = await supabase
        .from('user_mfa')
        .select('totp_secret')
        .eq('user_id', req.user.id)
        .single();

    if (!mfa) return res.status(400).json({ error: 'Run /mfa/setup/totp first' });

    const valid = authenticator.verify({ token: code, secret: mfa.totp_secret });
    if (!valid) return res.status(401).json({ error: 'Invalid code — try again' });

    await supabase.from('user_mfa')
        .update({ is_enabled: true })
        .eq('user_id', req.user.id);

    await audit.log('mfa_enabled', { userId: req.user.id, ipAddress: req.ip });

    res.json({ message: 'TOTP MFA enabled successfully' });
});

// ── POST /auth/logout ─────────────────────────────────────────
router.post('/logout', requireAuth, async (req, res) => {
    const header = req.headers.authorization;
    const token = header.slice(7);
    const { verifyToken } = require('../utils/jwt');
    const payload = verifyToken(token);

    await supabase.from('sessions').delete().eq('jwt_jti', payload.jti);
    await audit.log('logout', { userId: req.user.id, ipAddress: req.ip });

    res.json({ message: 'Logged out' });
});

// ── GET /auth/me ──────────────────────────────────────────────
router.get('/me', requireAuth, async (req, res) => {
    const { password_hash, ...safeUser } = req.user;
    res.json({ user: safeUser, permissions: [...req.permissions] });
});

// ── PATCH /auth/me/locale ──────────────────────────────────────
router.patch('/me/locale', requireAuth, async (req, res) => {
    const { locale } = req.body ?? {};
    if (!VALID_LOCALES.includes(locale)) {
        return res.status(400).json({ error: `locale must be one of ${VALID_LOCALES.join(', ')}` });
    }

    const { error } = await supabase
        .from('users')
        .update({ locale })
        .eq('id', req.user.id);

    if (error) return res.status(500).json({ error: 'Failed to update locale' });

    res.json({ message: 'Locale updated', locale });
});

// ── PATCH /auth/me/profile ───────────────────────────────────────
router.patch('/me/profile', requireAuth, async (req, res) => {
    const { full_name, username, bio, status_message } = req.body ?? {};
    const updates = {};

    if (full_name !== undefined) {
        if (!full_name.trim()) return res.status(400).json({ error: 'full_name cannot be empty' });
        updates.full_name = full_name.trim();
    }
    if (username !== undefined) {
        if (!username.trim()) return res.status(400).json({ error: 'username cannot be empty' });
        updates.username = username.trim();
    }
    if (bio !== undefined) updates.bio = bio?.trim() || null;
    if (status_message !== undefined) updates.status_message = status_message?.trim() || null;

    if (Object.keys(updates).length === 0) {
        return res.status(400).json({ error: 'No fields to update' });
    }

    const { data: user, error } = await supabase
        .from('users')
        .update(updates)
        .eq('id', req.user.id)
        .select('id, username, email, staff_id, full_name, bio, status_message, locale')
        .single();

    if (error) {
        if (error.code === '23505') return res.status(409).json({ error: 'Username already taken' });
        return res.status(500).json({ error: 'Failed to update profile' });
    }

    await audit.log('update_profile', { userId: req.user.id, targetType: 'user', targetId: req.user.id, ipAddress: req.ip });

    res.json({ message: 'Profile updated', user });
});

// ── PATCH /auth/me/avatar ─────────────────────────────────────────
// Body: { media_id } — the media must already exist via POST /media/upload
// (same upload flow chat attachments use) and belong to the caller.
router.patch('/me/avatar', requireAuth, async (req, res) => {
    const { media_id } = req.body ?? {};
    if (!media_id) return res.status(400).json({ error: 'media_id is required' });

    const { data: media } = await supabase
        .from('media_files')
        .select('id, object_key, mime_type, uploader_id')
        .eq('id', media_id)
        .single();

    if (!media || media.uploader_id !== req.user.id) {
        return res.status(404).json({ error: 'Media file not found' });
    }
    if (!media.mime_type.startsWith('image/')) {
        return res.status(400).json({ error: 'Avatar must be an image' });
    }

    // avatar_url is a stable resolve-on-request path, not a baked-in
    // presigned URL — see migration 010 for why.
    const avatar_url = `/media/avatar/${req.user.id}`;

    const { error } = await supabase
        .from('users')
        .update({ avatar_object_key: media.object_key, avatar_url })
        .eq('id', req.user.id);

    if (error) return res.status(500).json({ error: 'Failed to update avatar' });

    await audit.log('update_avatar', { userId: req.user.id, targetType: 'user', targetId: req.user.id, ipAddress: req.ip });

    res.json({ message: 'Avatar updated', avatar_url });
});

// ── PATCH /auth/me/password ───────────────────────────────────────
router.patch('/me/password', requireAuth, async (req, res) => {
    const { current_password, new_password } = req.body ?? {};
    if (!current_password || !new_password) {
        return res.status(400).json({ error: 'current_password and new_password are required' });
    }
    if (new_password.length < 8) {
        return res.status(400).json({ error: 'New password must be at least 8 characters' });
    }

    const { data: user } = await supabase
        .from('users')
        .select('password_hash')
        .eq('id', req.user.id)
        .single();

    const currentOk = await bcrypt.compare(current_password, user.password_hash);
    if (!currentOk) return res.status(401).json({ error: 'Current password is incorrect' });

    const password_hash = await bcrypt.hash(new_password, BCRYPT_ROUNDS);
    const { error } = await supabase
        .from('users')
        .update({ password_hash })
        .eq('id', req.user.id);

    if (error) return res.status(500).json({ error: 'Failed to update password' });

    // Revoke every other session — keep the one making this request alive
    // so changing your own password doesn't immediately log you out too.
    const { jti } = require('../utils/jwt').verifyToken(req.headers.authorization.slice(7));
    await supabase.from('sessions').delete().eq('user_id', req.user.id).neq('jwt_jti', jti);

    await audit.log('change_password', { userId: req.user.id, targetType: 'user', targetId: req.user.id, ipAddress: req.ip });

    res.json({ message: 'Password updated' });
});

// ── PATCH /auth/me/settings ───────────────────────────────────────
const VALID_THEMES = ['dark', 'light', 'system'];
const VALID_TEXT_SCALES = ['small', 'medium', 'large'];
const BOOLEAN_SETTINGS = [
    'notif_sound_enabled', 'notif_vibrate_enabled',
    'privacy_read_receipts', 'privacy_show_typing',
    'chat_auto_download_media',
];

router.patch('/me/settings', requireAuth, async (req, res) => {
    const body = req.body ?? {};
    const updates = {};

    if (body.theme_preference !== undefined) {
        if (!VALID_THEMES.includes(body.theme_preference)) {
            return res.status(400).json({ error: `theme_preference must be one of ${VALID_THEMES.join(', ')}` });
        }
        updates.theme_preference = body.theme_preference;
    }
    if (body.chat_message_text_scale !== undefined) {
        if (!VALID_TEXT_SCALES.includes(body.chat_message_text_scale)) {
            return res.status(400).json({ error: `chat_message_text_scale must be one of ${VALID_TEXT_SCALES.join(', ')}` });
        }
        updates.chat_message_text_scale = body.chat_message_text_scale;
    }
    for (const key of BOOLEAN_SETTINGS) {
        if (body[key] !== undefined) {
            if (typeof body[key] !== 'boolean') {
                return res.status(400).json({ error: `${key} must be a boolean` });
            }
            updates[key] = body[key];
        }
    }

    if (Object.keys(updates).length === 0) {
        return res.status(400).json({ error: 'No settings to update' });
    }

    const { data: settings, error } = await supabase
        .from('users')
        .update(updates)
        .eq('id', req.user.id)
        .select(`theme_preference, notif_sound_enabled, notif_vibrate_enabled,
                 privacy_read_receipts, privacy_show_typing,
                 chat_auto_download_media, chat_message_text_scale`)
        .single();

    if (error) return res.status(500).json({ error: 'Failed to update settings' });

    await audit.log('update_settings', { userId: req.user.id, targetType: 'user', targetId: req.user.id, metadata: updates, ipAddress: req.ip });

    res.json({ message: 'Settings updated', settings });
});

module.exports = router;
