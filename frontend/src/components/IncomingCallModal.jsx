import { useTranslation } from 'react-i18next';

export default function IncomingCallModal({ callInfo, onAccept, onReject }) {
    const { t } = useTranslation();
    if (!callInfo) return null;
    const { peer, type } = callInfo;

    return (
        <div className="fixed inset-0 z-50 flex items-end justify-center pb-8 sm:items-center pointer-events-none">
            <div className="bg-gray-800 border border-gray-700 rounded-2xl shadow-2xl p-6 w-80 pointer-events-auto animate-bounce-once">
                <div className="text-center">
                    {/* Avatar */}
                    <div className="w-16 h-16 rounded-full bg-indigo-700 flex items-center justify-center mx-auto mb-3">
                        <span className="text-xl font-bold text-white">
                            {peer?.full_name?.split(' ').map(w => w[0]).join('').slice(0, 2).toUpperCase() || '?'}
                        </span>
                    </div>

                    <p className="text-gray-400 text-sm mb-1">
                        {t('chat.call.incomingCall', { type: t(type === 'video' ? 'chat.call.video' : 'chat.call.audio') })}
                    </p>
                    <h3 className="text-white font-semibold text-lg mb-6">{peer?.full_name}</h3>

                    {/* Pulse ring animation */}
                    <div className="flex justify-center gap-8">
                        {/* Reject */}
                        <button
                            onClick={onReject}
                            className="w-14 h-14 rounded-full bg-red-600 hover:bg-red-500 flex items-center justify-center transition-colors shadow-lg"
                            title={t('chat.call.decline')}
                        >
                            <svg className="w-6 h-6 text-white rotate-135" fill="currentColor" viewBox="0 0 24 24">
                                <path d="M6.62 10.79c1.44 2.83 3.76 5.14 6.59 6.59l2.2-2.2c.27-.27.67-.36 1.02-.24 1.12.37 2.33.57 3.57.57.55 0 1 .45 1 1V20c0 .55-.45 1-1 1-9.39 0-17-7.61-17-17 0-.55.45-1 1-1h3.5c.55 0 1 .45 1 1 0 1.25.2 2.45.57 3.57.11.35.03.74-.25 1.02l-2.2 2.2z"/>
                            </svg>
                        </button>

                        {/* Accept */}
                        <button
                            onClick={onAccept}
                            className="w-14 h-14 rounded-full bg-green-600 hover:bg-green-500 flex items-center justify-center transition-colors shadow-lg"
                            title={t('chat.call.accept')}
                        >
                            <svg className="w-6 h-6 text-white" fill="currentColor" viewBox="0 0 24 24">
                                <path d="M6.62 10.79c1.44 2.83 3.76 5.14 6.59 6.59l2.2-2.2c.27-.27.67-.36 1.02-.24 1.12.37 2.33.57 3.57.57.55 0 1 .45 1 1V20c0 .55-.45 1-1 1-9.39 0-17-7.61-17-17 0-.55.45-1 1-1h3.5c.55 0 1 .45 1 1 0 1.25.2 2.45.57 3.57.11.35.03.74-.25 1.02l-2.2 2.2z"/>
                            </svg>
                        </button>
                    </div>
                </div>
            </div>
        </div>
    );
}
