import api from './client';

// Note: backend admin endpoints live under /api/admin (not /admin) so they
// never collide with the frontend's own /admin/* page routes.
export const getStats        = ()           => api.get('/api/admin/stats');
export const getUsers        = (p = {})     => api.get('/api/admin/users', { params: p });
export const updateUser      = (id, body)   => api.put(`/api/admin/users/${id}`, body);
export const lockUser        = (id)         => api.post(`/api/admin/users/${id}/lock`);
export const unlockUser      = (id)         => api.post(`/api/admin/users/${id}/unlock`);
export const getAuditLogs    = (p = {})     => api.get('/api/admin/audit-logs', { params: p });
export const getLoginAttempts= (p = {})     => api.get('/api/admin/login-attempts', { params: p });
export const getDevices      = (status)     => api.get('/api/admin/devices', { params: { status } });
export const approveDevice   = (id)         => api.post(`/api/admin/devices/${id}/approve`);
export const revokeDevice    = (id)         => api.post(`/api/admin/devices/${id}/revoke`);
export const getAlerts       = (resolved)   => api.get('/api/admin/alerts', { params: { resolved } });
export const resolveAlert    = (id)         => api.post(`/api/admin/alerts/${id}/resolve`);
export const getRoles        = ()           => api.get('/api/admin/roles');
