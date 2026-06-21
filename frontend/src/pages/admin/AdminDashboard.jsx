import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { getStats } from '../../api/admin';

function StatCard({ label, value, color = 'indigo', sub }) {
    const colors = {
        indigo: 'bg-indigo-600/20 text-indigo-400 border-indigo-600/30',
        green:  'bg-green-600/20  text-green-400  border-green-600/30',
        red:    'bg-red-600/20    text-red-400    border-red-600/30',
        yellow: 'bg-yellow-600/20 text-yellow-400 border-yellow-600/30',
        gray:   'bg-gray-700/50   text-gray-300   border-gray-600/30',
    };
    return (
        <div className={`rounded-xl border p-5 ${colors[color]}`}>
            <p className="text-xs uppercase tracking-wider opacity-70 mb-1">{label}</p>
            <p className="text-3xl font-bold">{value ?? '—'}</p>
            {sub && <p className="text-xs mt-1 opacity-60">{sub}</p>}
        </div>
    );
}

export default function AdminDashboard() {
    const { t } = useTranslation();
    const [stats, setStats]   = useState(null);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        getStats().then(r => setStats(r.data)).finally(() => setLoading(false));
    }, []);

    if (loading) return <div className="text-gray-500">{t('admin.dashboard.loadingStats')}</div>;

    return (
        <div>
            <h1 className="text-2xl font-bold text-white mb-6">{t('admin.dashboard.title')}</h1>

            <div className="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
                <StatCard label={t('admin.dashboard.totalUsers')}      value={stats?.total_users}     color="indigo" />
                <StatCard label={t('admin.dashboard.activeUsers')}     value={stats?.active_users}    color="green" />
                <StatCard label={t('admin.dashboard.lockedAccounts')}  value={stats?.locked_users}    color="red" />
                <StatCard label={t('admin.dashboard.activeSessions')}  value={stats?.active_sessions} color="gray" />
                <StatCard label={t('admin.dashboard.totalMessages')}   value={stats?.total_messages}  color="indigo"
                          sub={t('admin.dashboard.todaySuffix', { count: stats?.messages_today ?? 0 })} />
                <StatCard label={t('admin.dashboard.totalCalls')}      value={stats?.total_calls}     color="gray" />
                <StatCard label={t('admin.dashboard.unresolvedAlerts')} value={stats?.unresolved_alerts}
                          color={stats?.unresolved_alerts > 0 ? 'red' : 'green'} />
            </div>

            {stats?.unresolved_alerts > 0 && (
                <div className="bg-red-900/30 border border-red-700/50 rounded-xl p-4 flex items-center gap-3">
                    <svg className="w-5 h-5 text-red-400 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2}
                            d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
                    </svg>
                    <p className="text-red-300 text-sm">
                        <strong>{stats.unresolved_alerts}</strong> {t('admin.dashboard.alertWarning', { count: stats.unresolved_alerts })}
                    </p>
                </div>
            )}
        </div>
    );
}
