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

const sameDay = (a, b) => a.toDateString() === b.toDateString();

// Label for a date-separator pill between messages sent on different days.
export function formatDaySeparator(dateStr) {
    const d = new Date(dateStr);
    const today = new Date();
    const yesterday = new Date();
    yesterday.setDate(today.getDate() - 1);

    if (sameDay(d, today)) return i18n.t('chat.thread.today');
    if (sameDay(d, yesterday)) return i18n.t('chat.thread.yesterday');
    return d.toLocaleDateString(i18n.language, {
        day: 'numeric', month: 'long',
        year: d.getFullYear() !== today.getFullYear() ? 'numeric' : undefined,
    });
}

export function isSameDay(dateStrA, dateStrB) {
    return sameDay(new Date(dateStrA), new Date(dateStrB));
}
