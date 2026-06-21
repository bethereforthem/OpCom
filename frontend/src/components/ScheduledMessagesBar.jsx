import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { formatScheduledTime } from '../utils/time';

// Collapsible "Scheduled (n)" strip above the input, mirroring the
// "Archived (n)" row pattern in ConversationList.jsx (Batch D).
export default function ScheduledMessagesBar({ scheduledMessages, onCancel }) {
    const { t } = useTranslation();
    const [open, setOpen] = useState(false);

    if (!scheduledMessages.length) return null;

    return (
        <div className="border-t border-gray-700 bg-gray-800/60 flex-shrink-0">
            <button
                onClick={() => setOpen(o => !o)}
                className="w-full flex items-center justify-between px-4 py-2 text-xs text-gray-400 hover:bg-gray-700/50 transition-colors"
            >
                <span>{t('chat.scheduled.title')} ({scheduledMessages.length})</span>
                <svg className={`w-3 h-3 transition-transform ${open ? 'rotate-180' : ''}`} fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                </svg>
            </button>

            {open && (
                <div className="px-4 pb-2 space-y-1 max-h-32 overflow-y-auto">
                    {scheduledMessages.map(sm => (
                        <div key={sm.id} className="flex items-center justify-between bg-gray-700/50 rounded-lg px-3 py-1.5">
                            <div className="min-w-0">
                                <p className="text-xs text-gray-300 truncate max-w-[14rem]">{sm.content || t('common.media')}</p>
                                <p className="text-xs text-gray-500">{formatScheduledTime(sm.send_at)}</p>
                            </div>
                            <button
                                onClick={() => onCancel(sm.id)}
                                className="text-xs text-red-400 hover:text-red-300 flex-shrink-0 ml-2"
                            >
                                {t('common.cancel')}
                            </button>
                        </div>
                    ))}
                </div>
            )}
        </div>
    );
}
