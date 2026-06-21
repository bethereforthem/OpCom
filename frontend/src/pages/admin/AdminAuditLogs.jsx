import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { getAuditLogs } from '../../api/admin';
import { formatDateTime } from '../../utils/time';

const ACTION_COLORS = {
    login:            'text-green-400',
    logout:           'text-gray-400',
    login_mfa_success:'text-green-400',
    lock_user:        'text-red-400',
    unlock_user:      'text-green-400',
    create_user:      'text-indigo-400',
    edit_user:        'text-yellow-400',
    send_message:     'text-blue-400',
    upload_media:     'text-purple-400',
    approve_device:   'text-green-400',
    revoke_device:    'text-red-400',
    resolve_alert:    'text-green-400',
    call_initiate:    'text-cyan-400',
    call_ended:       'text-gray-400',
};

export default function AdminAuditLogs() {
    const { t } = useTranslation();
    const [logs, setLogs]       = useState([]);
    const [total, setTotal]     = useState(0);
    const [offset, setOffset]   = useState(0);
    const [action, setAction]   = useState('');
    const [loading, setLoading] = useState(true);
    const LIMIT = 50;

    async function load(o = 0, a = action) {
        setLoading(true);
        const { data } = await getAuditLogs({ limit: LIMIT, offset: o, action: a })
            .finally(() => setLoading(false));
        setLogs(data.logs || []);
        setTotal(data.total || 0);
        setOffset(o);
    }

    useEffect(() => { load(0); }, []);

    return (
        <div>
            <div className="flex items-center justify-between mb-6">
                <h1 className="text-2xl font-bold text-white">
                    {t('admin.auditLogs.title')} <span className="text-gray-500 text-lg font-normal">({total})</span>
                </h1>
                <input
                    value={action}
                    onChange={e => { setAction(e.target.value); load(0, e.target.value); }}
                    placeholder={t('admin.auditLogs.filterPlaceholder')}
                    className="bg-gray-800 border border-gray-700 rounded-lg px-3 py-1.5 text-sm text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-indigo-500 w-56"
                />
            </div>

            <div className="bg-gray-800 rounded-xl border border-gray-700 overflow-hidden mb-4">
                <table className="w-full text-sm">
                    <thead>
                        <tr className="border-b border-gray-700 text-gray-400 text-xs uppercase tracking-wider">
                            <th className="text-left px-4 py-3">{t('admin.auditLogs.columnTime')}</th>
                            <th className="text-left px-4 py-3">{t('admin.auditLogs.columnUser')}</th>
                            <th className="text-left px-4 py-3">{t('admin.auditLogs.columnAction')}</th>
                            <th className="text-left px-4 py-3">{t('admin.auditLogs.columnTarget')}</th>
                            <th className="text-left px-4 py-3">{t('admin.auditLogs.columnIp')}</th>
                        </tr>
                    </thead>
                    <tbody className="divide-y divide-gray-700 font-mono text-xs">
                        {loading && (
                            <tr><td colSpan={5} className="text-center py-8 text-gray-500">{t('common.loading')}</td></tr>
                        )}
                        {!loading && logs.length === 0 && (
                            <tr><td colSpan={5} className="text-center py-8 text-gray-500">{t('admin.auditLogs.noLogs')}</td></tr>
                        )}
                        {logs.map(l => (
                            <tr key={l.id} className="hover:bg-gray-700/30 transition-colors">
                                <td className="px-4 py-2.5 text-gray-500 whitespace-nowrap">
                                    {formatDateTime(l.created_at)}
                                </td>
                                <td className="px-4 py-2.5 text-gray-300">
                                    {l.users?.username || '—'}
                                </td>
                                <td className={`px-4 py-2.5 font-semibold ${ACTION_COLORS[l.action] || 'text-gray-300'}`}>
                                    {l.action}
                                </td>
                                <td className="px-4 py-2.5 text-gray-400">
                                    {l.target_type ? `${l.target_type}` : '—'}
                                </td>
                                <td className="px-4 py-2.5 text-gray-500">{l.ip_address || '—'}</td>
                            </tr>
                        ))}
                    </tbody>
                </table>
            </div>

            {/* Pagination */}
            <div className="flex items-center justify-between text-sm text-gray-400">
                <span>{offset + 1}–{Math.min(offset + LIMIT, total)} {t('admin.auditLogs.paginationOf')} {total}</span>
                <div className="flex gap-2">
                    <button onClick={() => load(Math.max(0, offset - LIMIT))}
                        disabled={offset === 0}
                        className="px-3 py-1 rounded-lg bg-gray-800 border border-gray-700 disabled:opacity-40 hover:bg-gray-700 transition-colors">
                        ← {t('admin.auditLogs.prev')}
                    </button>
                    <button onClick={() => load(offset + LIMIT)}
                        disabled={offset + LIMIT >= total}
                        className="px-3 py-1 rounded-lg bg-gray-800 border border-gray-700 disabled:opacity-40 hover:bg-gray-700 transition-colors">
                        {t('admin.auditLogs.next')} →
                    </button>
                </div>
            </div>
        </div>
    );
}
