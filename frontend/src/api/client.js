import axios from 'axios';

const api = axios.create({ baseURL: '/' });

// Inject token from localStorage on every request
api.interceptors.request.use(cfg => {
    const token = localStorage.getItem('opcom_token');
    if (token) cfg.headers.Authorization = `Bearer ${token}`;
    return cfg;
});

// ── Auth ──────────────────────────────────────────────────────
export const login = (identifier, password) =>
    api.post('/auth/login', { identifier, password });

export const signup = (payload) =>
    api.post('/auth/signup', payload);

export const mfaVerify = (preAuthToken, code) =>
    api.post('/auth/mfa/verify', { pre_auth_token: preAuthToken, code });

export const setupTotp = () =>
    api.post('/auth/mfa/setup/totp');

export const confirmTotp = (code) =>
    api.post('/auth/mfa/setup/confirm', { code });

export const getMe = () =>
    api.get('/auth/me');

export const logout = () =>
    api.post('/auth/logout');

export const setLocale = (locale) =>
    api.patch('/auth/me/locale', { locale });

export const updateProfile = (payload) =>
    api.patch('/auth/me/profile', payload);

export const updateAvatar = (mediaId) =>
    api.patch('/auth/me/avatar', { media_id: mediaId });

export const updatePassword = (currentPassword, newPassword) =>
    api.patch('/auth/me/password', { current_password: currentPassword, new_password: newPassword });

export const updateSettings = (payload) =>
    api.patch('/auth/me/settings', payload);

// ── Users ─────────────────────────────────────────────────────
export const lookupUser = (identifier) =>
    api.get('/users/lookup', { params: { identifier } });

// ── Conversations ─────────────────────────────────────────────
export const getConversations = (archived = false) =>
    api.get('/conversations', { params: archived ? { archived: true } : {} });

export const createConversation = (type, memberIds, name) =>
    api.post('/conversations', { type, member_ids: memberIds, name });

export const getConversation = (id) =>
    api.get(`/conversations/${id}`);

export const archiveConversation = (id) =>
    api.patch(`/conversations/${id}/archive`);

export const unarchiveConversation = (id) =>
    api.patch(`/conversations/${id}/unarchive`);

export const muteConversation = (id, duration) =>
    api.patch(`/conversations/${id}/mute`, { duration });

export const unmuteConversation = (id) =>
    api.patch(`/conversations/${id}/unmute`);

export const setDisappearing = (id, duration) =>
    api.patch(`/conversations/${id}/disappearing`, { duration });

export const leaveConversation = (id) =>
    api.delete(`/conversations/${id}/leave`);

// ── Scheduled messages ────────────────────────────────────────
export const scheduleMessage = (conversationId, payload) =>
    api.post(`/conversations/${conversationId}/scheduled-messages`, payload);

export const getScheduledMessages = (conversationId) =>
    api.get(`/conversations/${conversationId}/scheduled-messages`);

export const cancelScheduledMessage = (conversationId, scheduledId) =>
    api.delete(`/conversations/${conversationId}/scheduled-messages/${scheduledId}`);

// ── Messages ──────────────────────────────────────────────────
export const getMessages = (conversationId, before) =>
    api.get(`/conversations/${conversationId}/messages`, {
        params: { limit: 50, before },
    });

// ── Media ─────────────────────────────────────────────────────
export const uploadMedia = (file, onProgress) => {
    const form = new FormData();
    form.append('file', file);
    return api.post('/media/upload', form, {
        headers: { 'Content-Type': 'multipart/form-data' },
        onUploadProgress: e => onProgress?.(Math.round((e.loaded * 100) / e.total)),
    });
};

export const getMediaUrl = (mediaId) =>
    api.get(`/media/${mediaId}/url`);

// ── Calls ─────────────────────────────────────────────────────
export const getTurnCredentials = () =>
    api.get('/calls/turn-credentials');

export const getCallHistory = (before) =>
    api.get('/calls/history', { params: { before } });

// ── Notifications ───────────────────────────────────────────────
export const getNotifications = (p = {}) =>
    api.get('/notifications', { params: p });

export const markNotificationRead = (id) =>
    api.patch(`/notifications/${id}/read`);

// ── Search ──────────────────────────────────────────────────────
export const searchMessages = (params) =>
    api.get('/search/messages', { params });

export default api;
