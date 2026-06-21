import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { getAlerts, resolveAlert } from '../../api/admin';
import { formatDateTime } from '../../utils/time';

const SEV = {
    critical: 'bg-red-900/50    text-red-300    border border-red-700/50',
    high:     'bg-orange-900/50 text-orange-300 border border-orange-700/50',
    medium:   'bg-yellow-900/50 text-yellow-300 border border-yellow-700/50',
    low:      'bg-blue-900/50   text-blue-300   border border-blue-700/50',
};

export default function AdminAlerts() {
    const { t } = useTranslation();
    const [alerts, setAlerts]       = useState([]);
    const [showResolved, setShowResolved] = useState(false);
    const [loading, setLoading]     = useState(true);
    const [acting, setActing]       = useState(null);

    async function load() {
        setLoading(true);
        const { data } = await getAlerts(showResolved).finally(() => setLoading(false));
        setAlerts(data.alerts || []);
    }

    useEffect(() => { load(); }, [showResolved]);

    async function handleResolve(id) {
        setActing(id);
        try { await resolveAlert(id); await load(); }
        finally { setActing(null); }
    }

    return (
        <div>
            <div className="flex items-center justify-between mb-6">
                <h1 className="text-2xl font-bold text-white">{t('admin.layout.nav.alerts')}</h1>
                <label className="flex items-center gap-2 text-sm text-gray-400 cursor-pointer">
                    <input type="checkbox" checked={showResolved}
                        onChange={e => setShowResolved(e.target.checked)}
                        className="rounded" />
                    {t('admin.alerts.showResolved')}
                </label>
            </div>

            {loading && <p className="text-gray-500">{t('common.loading')}</p>}

            {!loading && alerts.length === 0 && (
                <div className="text-center py-16 text-gray-600">
                    <svg className="w-12 h-12 mx-auto mb-3 opacity-30" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1}
                            d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                    </svg>
                    <p>{showResolved ? t('admin.alerts.noAlerts') : t('admin.alerts.noUnresolvedAlerts')}</p>
                </div>
            )}

            <div className="space-y-3">
                {alerts.map(a => (
                    <div key={a.id} className="bg-gray-800 rounded-xl border border-gray-700 p-4">
                        <div className="flex items-start justify-between gap-4">
                            <div className="flex-1">
                                <div className="flex items-center gap-2 mb-1">
                                    <span className={`text-xs px-2 py-0.5 rounded-full font-medium capitalize ${SEV[a.severity]}`}>
                                        {a.severity}
                                    </span>
                                    <span className="text-xs text-gray-500 font-mono">{a.type}</span>
                                    <span className="text-xs text-gray-600">
                                        {formatDateTime(a.created_at)}
                                    </span>
                                </div>
                                <p className="text-white text-sm">{a.description}</p>
                                {a.users && (
                                    <p className="text-gray-400 text-xs mt-1">
                                        {t('admin.alerts.userLabel', { name: a.users.full_name, username: a.users.username })}
                                    </p>
                                )}
                                {a.resolved_at && (
                                    <p className="text-green-500 text-xs mt-1">
                                        {t('admin.alerts.resolvedPrefix')} {formatDateTime(a.resolved_at)}
                                    </p>
                                )}
                            </div>
                            {!a.resolved_at && (
                                <button onClick={() => handleResolve(a.id)} disabled={acting === a.id}
                                    className="flex-shrink-0 text-xs px-3 py-1.5 rounded-lg bg-green-900/40 text-green-400 hover:bg-green-900/70 transition-colors disabled:opacity-50">
                                    {acting === a.id ? '…' : t('admin.alerts.resolve')}
                                </button>
                            )}
                        </div>
                    </div>
                ))}
            </div>
        </div>
    );
}
