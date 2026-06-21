import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { getUsers, lockUser, unlockUser, updateUser } from '../../api/admin';
import { formatDate } from '../../utils/time';

const BADGE = {
    active:   'bg-green-900/50 text-green-400 border border-green-700/50',
    locked:   'bg-red-900/50   text-red-400   border border-red-700/50',
    inactive: 'bg-gray-700     text-gray-400',
};

function statusInfo(u, t) {
    if (u.is_locked)  return { label: t('admin.users.statusLocked'),   style: BADGE.locked };
    if (!u.is_active) return { label: t('admin.users.statusInactive'), style: BADGE.inactive };
    return { label: t('admin.users.statusActive'), style: BADGE.active };
}

export default function AdminUsers() {
    const { t } = useTranslation();
    const [users, setUsers]     = useState([]);
    const [total, setTotal]     = useState(0);
    const [search, setSearch]   = useState('');
    const [loading, setLoading] = useState(false);
    const [acting, setActing]   = useState(null);

    async function load(q = search) {
        setLoading(true);
        const { data } = await getUsers({ search: q, limit: 100 }).finally(() => setLoading(false));
        setUsers(data.users || []);
        setTotal(data.total || 0);
    }

    useEffect(() => { load(); }, []);

    async function toggleLock(user) {
        setActing(user.id);
        try {
            if (user.is_locked) await unlockUser(user.id);
            else                await lockUser(user.id);
            await load();
        } finally { setActing(null); }
    }

    async function approve(user) {
        setActing(user.id);
        try {
            await updateUser(user.id, { is_active: true });
            await load();
        } finally { setActing(null); }
    }

    return (
        <div>
            <div className="flex items-center justify-between mb-6">
                <h1 className="text-2xl font-bold text-white">{t('admin.layout.nav.users')} <span className="text-gray-500 text-lg font-normal">({total})</span></h1>
                <input
                    value={search}
                    onChange={e => { setSearch(e.target.value); load(e.target.value); }}
                    placeholder={t('admin.users.searchPlaceholder')}
                    className="bg-gray-800 border border-gray-700 rounded-lg px-3 py-1.5 text-sm text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-indigo-500 w-64"
                />
            </div>

            <div className="bg-gray-800 rounded-xl border border-gray-700 overflow-hidden">
                <table className="w-full text-sm">
                    <thead>
                        <tr className="border-b border-gray-700 text-gray-400 text-xs uppercase tracking-wider">
                            <th className="text-left px-4 py-3">{t('admin.users.columnUser')}</th>
                            <th className="text-left px-4 py-3">{t('admin.users.columnRole')}</th>
                            <th className="text-left px-4 py-3">{t('admin.users.columnStatus')}</th>
                            <th className="text-left px-4 py-3">{t('admin.users.columnLastLogin')}</th>
                            <th className="text-left px-4 py-3">{t('admin.users.columnJoined')}</th>
                            <th className="text-right px-4 py-3">{t('admin.users.columnActions')}</th>
                        </tr>
                    </thead>
                    <tbody className="divide-y divide-gray-700">
                        {loading && (
                            <tr><td colSpan={6} className="text-center py-8 text-gray-500">{t('common.loading')}</td></tr>
                        )}
                        {!loading && users.length === 0 && (
                            <tr><td colSpan={6} className="text-center py-8 text-gray-500">{t('admin.users.noUsersFound')}</td></tr>
                        )}
                        {users.map(u => {
                            const { label, style } = statusInfo(u, t);
                            return (
                                <tr key={u.id} className="hover:bg-gray-700/30 transition-colors">
                                    <td className="px-4 py-3">
                                        <div className="font-medium text-white">{u.full_name}</div>
                                        <div className="text-gray-400 text-xs">@{u.username} {u.staff_id ? `· ${u.staff_id}` : ''} {u.locale ? `· ${u.locale.toUpperCase()}` : ''}</div>
                                    </td>
                                    <td className="px-4 py-3 text-gray-300 capitalize">{u.roles?.name || '—'}</td>
                                    <td className="px-4 py-3">
                                        <span className={`text-xs px-2 py-0.5 rounded-full ${style}`}>{label}</span>
                                        {u.failed_attempts > 0 && (
                                            <span className="ml-2 text-xs text-yellow-500">{t('admin.users.failedAttempts', { count: u.failed_attempts })}</span>
                                        )}
                                    </td>
                                    <td className="px-4 py-3 text-gray-400">{formatDate(u.last_login_at)}</td>
                                    <td className="px-4 py-3 text-gray-400">{formatDate(u.created_at)}</td>
                                    <td className="px-4 py-3 text-right space-x-2">
                                        {!u.is_active && !u.is_locked && (
                                            <button
                                                onClick={() => approve(u)}
                                                disabled={acting === u.id}
                                                className="text-xs px-3 py-1 rounded-lg transition-colors disabled:opacity-50 bg-indigo-900/40 text-indigo-400 hover:bg-indigo-900/70"
                                            >
                                                {acting === u.id ? '…' : t('admin.users.approve')}
                                            </button>
                                        )}
                                        <button
                                            onClick={() => toggleLock(u)}
                                            disabled={acting === u.id}
                                            className={`text-xs px-3 py-1 rounded-lg transition-colors disabled:opacity-50
                                                        ${u.is_locked
                                                            ? 'bg-green-900/40 text-green-400 hover:bg-green-900/70'
                                                            : 'bg-red-900/40   text-red-400   hover:bg-red-900/70'}`}
                                        >
                                            {acting === u.id ? '…' : u.is_locked ? t('admin.users.unlock') : t('admin.users.lock')}
                                        </button>
                                    </td>
                                </tr>
                            );
                        })}
                    </tbody>
                </table>
            </div>
        </div>
    );
}
