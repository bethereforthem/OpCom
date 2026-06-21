import i18n from '../i18n';

export function formatDistanceToNow(dateStr) {
    const diff = Date.now() - new Date(dateStr).getTime();
    const mins  = Math.floor(diff / 60000);
    const hours = Math.floor(diff / 3600000);
    const days  = Math.floor(diff / 86400000);
    if (mins < 1)   return i18n.t('common.justNow');
    if (mins < 60)  return `${mins}m`;
    if (hours < 24) return `${hours}h`;
    if (days < 7)   return `${days}d`;
    return new Date(dateStr).toLocaleDateString(i18n.language);
}

export function formatTime(dateStr) {
    return new Date(dateStr).toLocaleTimeString(i18n.language, { hour: '2-digit', minute: '2-digit' });
}

export function formatDate(dateStr) {
    if (!dateStr) return '—';
    return new Date(dateStr).toLocaleDateString(i18n.language);
}

export function formatDateTime(dateStr) {
    if (!dateStr) return '—';
    return new Date(dateStr).toLocaleString(i18n.language);
}

export function formatScheduledTime(dateStr) {
    return new Date(dateStr).toLocaleString(i18n.language, { dateStyle: 'medium', timeStyle: 'short' });
}
