const express = require('express');
const supabase = require('../utils/supabase');
const { requireAuth, requirePermission } = require('../middleware/auth');
const audit = require('../services/auditLog');

const router = express.Router();

// All admin routes require authentication + view_users permission at minimum
router.use(requireAuth);

// ── GET /admin/stats ──────────────────────────────────────────
router.get('/stats', requirePermission('view_system_stats'), async (req, res) => {
    const [users, messages, sessions, alerts, calls] = await Promise.all([
        supabase.from('users').select('id, is_active, is_locked, created_at', { count: 'exact' }),
        supabase.from('messages').select('id, created_at', { count: 'exact' }).eq('is_deleted', false),
        supabase.from('sessions').select('id', { count: 'exact' }).gt('expires_at', new Date().toISOString()),
        supabase.from('security_alerts').select('id', { count: 'exact' }).is('resolved_at', null),
        supabase.from('call_logs').select('id', { count: 'exact' }),
    ]);

    const activeUsers  = users.data?.filter(u => u.is_active && !u.is_locked).length ?? 0;
    const lockedUsers  = users.data?.filter(u => u.is_locked).length ?? 0;
    const today        = new Date(); today.setHours(0, 0, 0, 0);
    const msgsToday    = messages.data?.filter(m => new Date(m.created_at) >= today).length ?? 0;

    res.json({
        total_users:     users.count ?? 0,
        active_users:    activeUsers,
        locked_users:    lockedUsers,
        active_sessions: sessions.count ?? 0,
        total_messages:  messages.count ?? 0,
        messages_today:  msgsToday,
        unresolved_alerts: alerts.count ?? 0,
        total_calls:     calls.count ?? 0,
    });
});

// ── GET /admin/users ──────────────────────────────────────────
router.get('/users', requirePermission('view_users'), async (req, res) => {
    const limit  = Math.min(parseInt(req.query.limit, 10) || 50, 100);
    const offset = parseInt(req.query.offset, 10) || 0;
    const search = req.query.search || '';

    let query = supabase
        .from('users')
        .select(`id, username, email, staff_id, full_name, is_active, is_locked,
                 failed_attempts, last_login_at, created_at, locale,
                 roles ( name )`, { count: 'exact' })
        .order('created_at', { ascending: false })
        .range(offset, offset + limit - 1);

    if (search) {
        query = query.or(`username.ilike.%${search}%,full_name.ilike.%${search}%,email.ilike.%${search}%`);
    }

    const { data, count, error } = await query;
    if (error) return res.status(500).json({ error: 'Failed to fetch users' });

    res.json({ users: data, total: count });
});

// ── PUT /admin/users/:id ──────────────────────────────────────
router.put('/users/:id', requirePermission('edit_user'), async (req, res) => {
    const { full_name, role_id, is_active } = req.body;
    const updates = {};
    if (full_name  !== undefined) updates.full_name  = full_name;
    if (role_id    !== undefined) updates.role_id    = role_id;
    if (is_active  !== undefined) updates.is_active  = is_active;

    const { data, error } = await supabase
        .from('users').update(updates).eq('id', req.params.id)
        .select('id, username, full_name, is_active, role_id').single();

    if (error) return res.status(500).json({ error: 'Failed to update user' });

    await audit.log('edit_user', { userId: req.user.id, targetType: 'user', targetId: req.params.id, metadata: updates, ipAddress: req.ip });
    res.json({ user: data });
});

// ── POST /admin/users/:id/lock ────────────────────────────────
router.post('/users/:id/lock', requirePermission('deactivate_user'), async (req, res) => {
    await supabase.from('users').update({ is_locked: true }).eq('id', req.params.id);
    // Revoke all active sessions
    await supabase.from('sessions').delete().eq('user_id', req.params.id);
    await audit.log('lock_user', { userId: req.user.id, targetType: 'user', targetId: req.params.id, ipAddress: req.ip });
    res.json({ message: 'User locked and sessions revoked' });
});

// ── POST /admin/users/:id/unlock ──────────────────────────────
router.post('/users/:id/unlock', requirePermission('deactivate_user'), async (req, res) => {
    await supabase.from('users').update({ is_locked: false, failed_attempts: 0 }).eq('id', req.params.id);
    await audit.log('unlock_user', { userId: req.user.id, targetType: 'user', targetId: req.params.id, ipAddress: req.ip });
    res.json({ message: 'User unlocked' });
});

// ── GET /admin/audit-logs ─────────────────────────────────────
router.get('/audit-logs', requirePermission('view_audit_logs'), async (req, res) => {
    const limit  = Math.min(parseInt(req.query.limit, 10) || 50, 200);
    const offset = parseInt(req.query.offset, 10) || 0;
    const action = req.query.action || '';
    const userId = req.query.user_id || '';

    let query = supabase
        .from('audit_logs')
        .select(`id, action, target_type, target_id, metadata, ip_address, created_at,
                 users ( id, username, full_name )`, { count: 'exact' })
        .order('created_at', { ascending: false })
        .range(offset, offset + limit - 1);

    if (action) query = query.eq('action', action);
    if (userId) query = query.eq('user_id', userId);

    const { data, count, error } = await query;
    if (error) return res.status(500).json({ error: 'Failed to fetch audit logs' });

    res.json({ logs: data, total: count });
});

// ── GET /admin/login-attempts ─────────────────────────────────
router.get('/login-attempts', requirePermission('view_audit_logs'), async (req, res) => {
    const limit = Math.min(parseInt(req.query.limit, 10) || 50, 200);
    const { data, count, error } = await supabase
        .from('login_attempts')
        .select('id, identifier, success, failure_reason, ip_address, user_agent, created_at', { count: 'exact' })
        .order('created_at', { ascending: false })
        .limit(limit);

    if (error) return res.status(500).json({ error: 'Failed to fetch login attempts' });
    res.json({ attempts: data, total: count });
});

// ── GET /admin/devices ────────────────────────────────────────
router.get('/devices', requirePermission('approve_device'), async (req, res) => {
    const status = req.query.status || 'pending'; // pending | active | revoked
    let query = supabase
        .from('authorized_devices')
        .select(`id, device_name, device_fingerprint, platform, is_active,
                 approved_at, revoked_at, created_at,
                 users!user_id ( id, username, full_name )`)
        .order('created_at', { ascending: false });

    if (status === 'pending') query = query.eq('is_active', false).is('revoked_at', null);
    if (status === 'active')  query = query.eq('is_active', true);
    if (status === 'revoked') query = query.not('revoked_at', 'is', null);

    const { data, error } = await query;
    if (error) return res.status(500).json({ error: 'Failed to fetch devices' });
    res.json({ devices: data });
});

// ── POST /admin/devices/:id/approve ───────────────────────────
router.post('/devices/:id/approve', requirePermission('approve_device'), async (req, res) => {
    const { data, error } = await supabase
        .from('authorized_devices')
        .update({ is_active: true, approved_by: req.user.id, approved_at: new Date().toISOString() })
        .eq('id', req.params.id)
        .select('id, device_name').single();

    if (error) return res.status(500).json({ error: 'Failed to approve device' });
    await audit.log('approve_device', { userId: req.user.id, targetType: 'device', targetId: req.params.id, ipAddress: req.ip });
    res.json({ message: 'Device approved', device: data });
});

// ── POST /admin/devices/:id/revoke ────────────────────────────
router.post('/devices/:id/revoke', requirePermission('revoke_device'), async (req, res) => {
    await supabase
        .from('authorized_devices')
        .update({ is_active: false, revoked_at: new Date().toISOString() })
        .eq('id', req.params.id);

    await audit.log('revoke_device', { userId: req.user.id, targetType: 'device', targetId: req.params.id, ipAddress: req.ip });
    res.json({ message: 'Device revoked' });
});

// ── GET /admin/alerts ─────────────────────────────────────────
router.get('/alerts', requirePermission('view_security_alerts'), async (req, res) => {
    const resolved = req.query.resolved === 'true';
    let query = supabase
        .from('security_alerts')
        .select(`id, severity, type, description, metadata, resolved_at, created_at,
                 users!user_id ( id, username, full_name )`)
        .order('created_at', { ascending: false })
        .limit(100);

    if (!resolved) query = query.is('resolved_at', null);

    const { data, error } = await query;
    if (error) return res.status(500).json({ error: 'Failed to fetch alerts' });
    res.json({ alerts: data });
});

// ── POST /admin/alerts/:id/resolve ───────────────────────────
router.post('/alerts/:id/resolve', requirePermission('resolve_security_alert'), async (req, res) => {
    await supabase
        .from('security_alerts')
        .update({ resolved_at: new Date().toISOString(), resolved_by: req.user.id })
        .eq('id', req.params.id);

    await audit.log('resolve_alert', { userId: req.user.id, targetType: 'alert', targetId: req.params.id, ipAddress: req.ip });
    res.json({ message: 'Alert resolved' });
});

// ── GET /admin/roles ──────────────────────────────────────────
router.get('/roles', requirePermission('manage_roles'), async (req, res) => {
    const { data, error } = await supabase
        .from('roles')
        .select(`id, name, description,
                 role_permissions ( permissions ( id, name, description ) )`);
    if (error) return res.status(500).json({ error: 'Failed to fetch roles' });
    res.json({ roles: data });
});

module.exports = router;
