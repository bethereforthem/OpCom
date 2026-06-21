import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { getCallHistory } from '../api/client';
import { formatDistanceToNow } from '../utils/time';
import Avatar from './Avatar';

function durationLabel(seconds) {
    if (seconds === null || seconds === undefined) return null;
    const m = Math.floor(seconds / 60);
    const s = seconds % 60;
    return `${m}:${s.toString().padStart(2, '0')}`;
}

function CallTypeIcon({ type }) {
    if (type === 'video') {
        return (
            <svg className="w-4 h-4 text-gray-400 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2}
                    d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z" />
            </svg>
        );
    }
    return (
        <svg className="w-4 h-4 text-gray-400 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2}
                d="M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z" />
        </svg>
    );
}

function DirectionIcon({ outgoing, missed }) {
    const color = missed ? 'text-red-500' : 'text-green-500';
    return (
        <svg className={`w-3 h-3 ${color} flex-shrink-0`} fill="none" viewBox="0 0 24 24" stroke="currentColor">
            {outgoing
                ? <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M7 17L17 7M17 7H8M17 7v9" />
                : <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M17 7L7 17M7 17h9M7 17V8" />}
        </svg>
    );
}

function CallRow({ call, currentUserId, t }) {
    const outgoing = call.caller?.id === currentUserId;
    const other = outgoing ? call.callee : call.caller;
    const missed = call.status === 'missed';

    let statusText;
    if (call.status === 'missed') statusText = outgoing ? t('chat.callHistory.noAnswer') : t('chat.callHistory.missed');
    else if (call.status === 'rejected') statusText = t('chat.callHistory.declined');
    else if (call.status === 'ended') statusText = call.duration_seconds != null
        ? `${t('chat.callHistory.answered')} · ${durationLabel(call.duration_seconds)}`
        : t('chat.callHistory.answered');
    else if (call.status === 'failed') statusText = t('chat.callHistory.failed');
    else statusText = call.status;

    return (
        <div className="flex items-center gap-3 px-4 py-3 border-b border-gray-700/50">
            <Avatar name={other?.full_name} url={other?.avatar_url} />
            <div className="flex-1 min-w-0">
                <p className="text-sm text-gray-200 truncate">{other?.full_name || t('common.unknown')}</p>
                <div className="flex items-center gap-1.5 mt-0.5">
                    <DirectionIcon outgoing={outgoing} missed={missed} />
                    <CallTypeIcon type={call.type} />
                    <span className={`text-xs ${missed ? 'text-red-400' : 'text-gray-500'}`}>{statusText}</span>
                </div>
            </div>
            <span className="text-xs text-gray-600 flex-shrink-0">{formatDistanceToNow(call.started_at)}</span>
        </div>
    );
}

export default function CallHistoryButton({ currentUserId }) {
    const { t } = useTranslation();
    const [calls, setCalls]   = useState([]);
    const [open, setOpen]     = useState(false);
    const [loaded, setLoaded] = useState(false);

    async function load() {
        const { data } = await getCallHistory();
        setCalls(data.calls || []);
        setLoaded(true);
    }

    function toggleOpen() {
        setOpen(o => !o);
        if (!loaded) load();
    }

    return (
        <div className="relative">
            <button onClick={toggleOpen} title={t('chat.callHistory.title')}
                className="w-8 h-8 rounded-full bg-gray-700 hover:bg-gray-600 flex items-center justify-center transition-colors">
                <svg className="w-4 h-4 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2}
                        d="M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z" />
                </svg>
            </button>

            {open && (
                <div className="absolute right-0 mt-2 w-96 bg-gray-800 border border-gray-700 rounded-xl shadow-2xl z-30 max-h-96 overflow-y-auto">
                    <div className="px-4 py-3 border-b border-gray-700 text-sm font-semibold text-white">{t('chat.callHistory.title')}</div>
                    {calls.length === 0 && (
                        <p className="text-center text-gray-500 text-sm py-8">{t('chat.callHistory.empty')}</p>
                    )}
                    {calls.map(c => (
                        <CallRow key={c.id} call={c} currentUserId={currentUserId} t={t} />
                    ))}
                </div>
            )}
        </div>
    );
}
