import { useEffect, useRef, useState } from 'react';
import { useTranslation } from 'react-i18next';

function useCallTimer(active) {
    const [seconds, setSeconds] = useState(0);
    useEffect(() => {
        if (!active) { setSeconds(0); return; }
        const id = setInterval(() => setSeconds(s => s + 1), 1000);
        return () => clearInterval(id);
    }, [active]);
    const m = String(Math.floor(seconds / 60)).padStart(2, '0');
    const s = String(seconds % 60).padStart(2, '0');
    return `${m}:${s}`;
}

export default function CallOverlay({ callState, callInfo, localStream, remoteStream, isMuted, isVideoOff, onEnd, onToggleMute, onToggleVideo }) {
    const { t } = useTranslation();
    const localVideoRef  = useRef(null);
    const remoteVideoRef = useRef(null);
    const timer          = useCallTimer(callState === 'active');

    useEffect(() => {
        if (localVideoRef.current && localStream)   localVideoRef.current.srcObject  = localStream;
        if (remoteVideoRef.current && remoteStream) remoteVideoRef.current.srcObject = remoteStream;
    }, [localStream, remoteStream]);

    if (!callState || callState === 'incoming') return null;

    const isVideo   = callInfo?.type === 'video';
    const peerName  = callInfo?.peer?.full_name || t('common.unknown');
    const isActive  = callState === 'active';
    const isOutgoing = callState === 'outgoing';

    return (
        <div className="fixed inset-0 z-40 bg-gray-900 flex flex-col">
            {/* Video streams */}
            {isVideo && (
                <div className="relative flex-1 bg-black">
                    {/* Remote (full screen) */}
                    <video
                        ref={remoteVideoRef}
                        autoPlay
                        playsInline
                        className="w-full h-full object-cover"
                    />

                    {/* Local (picture-in-picture) */}
                    <div className="absolute bottom-4 right-4 w-32 h-24 rounded-xl overflow-hidden border-2 border-gray-600 bg-gray-800 shadow-xl">
                        {isVideoOff
                            ? <div className="w-full h-full flex items-center justify-center">
                                <svg className="w-6 h-6 text-gray-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2}
                                        d="M18.364 18.364A9 9 0 005.636 5.636m12.728 12.728A9 9 0 015.636 5.636m12.728 12.728L5.636 5.636" />
                                </svg>
                              </div>
                            : <video ref={localVideoRef} autoPlay muted playsInline className="w-full h-full object-cover" />
                        }
                    </div>
                </div>
            )}

            {/* Audio call UI */}
            {!isVideo && (
                <div className="flex-1 flex flex-col items-center justify-center gap-4">
                    <div className="w-24 h-24 rounded-full bg-indigo-700 flex items-center justify-center text-3xl font-bold text-white">
                        {peerName.split(' ').map(w => w[0]).join('').slice(0, 2).toUpperCase()}
                    </div>
                    <h2 className="text-2xl font-semibold text-white">{peerName}</h2>
                    <p className="text-gray-400 text-sm">
                        {isOutgoing ? t('chat.call.calling') : isActive ? timer : ''}
                    </p>
                    <audio ref={remoteVideoRef} autoPlay />
                </div>
            )}

            {/* Timer for video calls */}
            {isVideo && isActive && (
                <div className="absolute top-4 left-1/2 -translate-x-1/2 bg-black/60 rounded-full px-4 py-1">
                    <span className="text-white text-sm font-mono">{timer}</span>
                </div>
            )}

            {/* Peer name for video */}
            {isVideo && (
                <div className="absolute top-4 left-4">
                    <p className="text-white font-semibold">{peerName}</p>
                    {isOutgoing && <p className="text-gray-300 text-sm">{t('chat.call.calling')}</p>}
                </div>
            )}

            {/* Controls */}
            <div className="flex items-center justify-center gap-6 py-8 bg-gray-900/90 flex-shrink-0">
                {/* Mute */}
                <button onClick={onToggleMute}
                    className={`w-14 h-14 rounded-full flex items-center justify-center transition-colors
                                ${isMuted ? 'bg-red-600 hover:bg-red-500' : 'bg-gray-700 hover:bg-gray-600'}`}
                    title={isMuted ? t('chat.call.unmute') : t('chat.call.mute')}
                >
                    <svg className="w-6 h-6 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        {isMuted
                            ? <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2}
                                d="M5.586 15H4a1 1 0 01-1-1v-4a1 1 0 011-1h1.586l4.707-4.707C10.923 3.663 12 4.109 12 5v14c0 .891-1.077 1.337-1.707.707L5.586 15z M17 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2" />
                            : <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2}
                                d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z" />
                        }
                    </svg>
                </button>

                {/* End call */}
                <button onClick={onEnd}
                    className="w-16 h-16 rounded-full bg-red-600 hover:bg-red-500 flex items-center justify-center transition-colors shadow-xl"
                    title={t('chat.call.endCall')}
                >
                    <svg className="w-7 h-7 text-white rotate-135" fill="currentColor" viewBox="0 0 24 24">
                        <path d="M6.62 10.79c1.44 2.83 3.76 5.14 6.59 6.59l2.2-2.2c.27-.27.67-.36 1.02-.24 1.12.37 2.33.57 3.57.57.55 0 1 .45 1 1V20c0 .55-.45 1-1 1-9.39 0-17-7.61-17-17 0-.55.45-1 1-1h3.5c.55 0 1 .45 1 1 0 1.25.2 2.45.57 3.57.11.35.03.74-.25 1.02l-2.2 2.2z"/>
                    </svg>
                </button>

                {/* Toggle video (only in video calls) */}
                {isVideo && (
                    <button onClick={onToggleVideo}
                        className={`w-14 h-14 rounded-full flex items-center justify-center transition-colors
                                    ${isVideoOff ? 'bg-red-600 hover:bg-red-500' : 'bg-gray-700 hover:bg-gray-600'}`}
                        title={isVideoOff ? t('chat.call.turnOnCamera') : t('chat.call.turnOffCamera')}
                    >
                        <svg className="w-6 h-6 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2}
                                d="M15 10l4.553-2.069A1 1 0 0121 8.82v6.36a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z" />
                        </svg>
                    </button>
                )}
            </div>
        </div>
    );
}
