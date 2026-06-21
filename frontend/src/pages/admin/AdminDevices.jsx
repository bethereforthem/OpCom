import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { getDevices, approveDevice, revokeDevice } from '../../api/admin';
import { formatDate } from '../../utils/time';

export default function AdminDevices() {
    const { t } = useTranslation();
    const [devices, setDevices] = useState([]);
    const [status, setStatus]   = useState('pending');
    const [loading, setLoading] = useState(true);
    const [acting, setActing]   = useState(null);

    const TABS = [
        { value: 'pending', label: t('admin.devices.tabPending') },
        { value: 'active',  label: t('admin.devices.tabActive') },
        { value: 'revoked', label: t('admin.devices.tabRevoked') },
    ];

    async function load() {
        setLoading(true);
        const { data } = await getDevices(status).finally(() => setLoading(false));
        setDevices(data.devices || []);
    }

    useEffect(() => { load(); }, [status]);

    async function handleApprove(id) {
        setActing(id);
        try { await approveDevice(id); await load(); }
        finally { setActing(null); }
    }

    async function handleRevoke(id) {
        if (!confirm(t('admin.devices.confirmRevoke'))) return;
        setActing(id);
        try { await revokeDevice(id); await load(); }
        finally { setActing(null); }
    }

    return (
        <div>
            <h1 className="text-2xl font-bold text-white mb-6">{t('admin.devices.title')}</h1>

            {/* Tabs */}
            <div className="flex gap-1 mb-6 bg-gray-800 p-1 rounded-lg w-fit border border-gray-700">
                {TABS.map(tab => (
                    <button key={tab.value} onClick={() => setStatus(tab.value)}
                        className={`px-4 py-1.5 rounded-md text-sm capitalize transition-colors
                                    ${status === tab.value ? 'bg-indigo-600 text-white' : 'text-gray-400 hover:text-white'}`}>
                        {tab.label}
                    </button>
                ))}
            </div>

            {loading && <p className="text-gray-500">{t('common.loading')}</p>}

            {!loading && devices.length === 0 && (
                <div className="text-center py-12 text-gray-600">
                    {t('admin.devices.noDevices', { status: TABS.find(tab => tab.value === status)?.label })}
                </div>
            )}

            <div className="bg-gray-800 rounded-xl border border-gray-700 overflow-hidden">
                {devices.length > 0 && (
                    <table className="w-full text-sm">
                        <thead>
                            <tr className="border-b border-gray-700 text-gray-400 text-xs uppercase tracking-wider">
                                <th className="text-left px-4 py-3">{t('admin.devices.columnDevice')}</th>
                                <th className="text-left px-4 py-3">{t('admin.devices.columnUser')}</th>
                                <th className="text-left px-4 py-3">{t('admin.devices.columnPlatform')}</th>
                                <th className="text-left px-4 py-3">{t('admin.devices.columnRequested')}</th>
                                <th className="text-right px-4 py-3">{t('admin.devices.columnActions')}</th>
                            </tr>
                        </thead>
                        <tbody className="divide-y divide-gray-700">
                            {devices.map(d => (
                                <tr key={d.id} className="hover:bg-gray-700/30 transition-colors">
                                    <td className="px-4 py-3">
                                        <div className="font-medium text-white">{d.device_name}</div>
                                        <div className="text-gray-500 text-xs font-mono truncate max-w-[200px]">
                                            {d.device_fingerprint}
                                        </div>
                                    </td>
                                    <td className="px-4 py-3 text-gray-300">
                                        {d.users?.full_name}<br/>
                                        <span className="text-gray-500 text-xs">@{d.users?.username}</span>
                                    </td>
                                    <td className="px-4 py-3 text-gray-400 capitalize">{d.platform || '—'}</td>
                                    <td className="px-4 py-3 text-gray-400">
                                        {formatDate(d.created_at)}
                                    </td>
                                    <td className="px-4 py-3 text-right flex justify-end gap-2">
                                        {!d.is_active && !d.revoked_at && (
                                            <button onClick={() => handleApprove(d.id)} disabled={acting === d.id}
                                                className="text-xs px-3 py-1 rounded-lg bg-green-900/40 text-green-400 hover:bg-green-900/70 disabled:opacity-50 transition-colors">
                                                {acting === d.id ? '…' : t('admin.devices.approve')}
                                            </button>
                                        )}
                                        {d.is_active && (
                                            <button onClick={() => handleRevoke(d.id)} disabled={acting === d.id}
                                                className="text-xs px-3 py-1 rounded-lg bg-red-900/40 text-red-400 hover:bg-red-900/70 disabled:opacity-50 transition-colors">
                                                {acting === d.id ? '…' : t('admin.devices.revoke')}
                                            </button>
                                        )}
                                        {d.revoked_at && (
                                            <span className="text-xs text-gray-600">{t('admin.devices.revoked')}</span>
                                        )}
                                    </td>
                                </tr>
                            ))}
                        </tbody>
                    </table>
                )}
            </div>
        </div>
    );
}
