import { useEffect, useRef, useState, useCallback } from 'react';
import { useTranslation } from 'react-i18next';
import { useSocket } from '../contexts/SocketContext';
import { getTurnCredentials } from '../api/client';

export function useWebRTC() {
    const { t }               = useTranslation();
    const { on, emit }       = useSocket();
    const pcRef              = useRef(null);
    const localStreamRef     = useRef(null);

    const [callState, setCallState]         = useState(null);  // null | 'incoming' | 'outgoing' | 'active'
    const [callInfo, setCallInfo]           = useState(null);  // { callId, type, peer }
    const callStateRef = useRef(callState);
    const callInfoRef  = useRef(callInfo);
    callStateRef.current = callState;
    callInfoRef.current  = callInfo;
    const [localStream, setLocalStream]     = useState(null);
    const [remoteStream, setRemoteStream]   = useState(null);
    const [isMuted, setIsMuted]             = useState(false);
    const [isVideoOff, setIsVideoOff]       = useState(false);

    // Build RTCPeerConnection with TURN credentials
    async function createPeerConnection(onIceCandidate) {
        const { data } = await getTurnCredentials();
        const pc = new RTCPeerConnection({ iceServers: data.ice_servers });

        pc.onicecandidate = e => {
            if (e.candidate) onIceCandidate(e.candidate);
        };

        pc.ontrack = e => {
            setRemoteStream(e.streams[0]);
        };

        return pc;
    }

    async function getLocalMedia(type) {
        const stream = await navigator.mediaDevices.getUserMedia({
            audio: true,
            video: type === 'video',
        });
        localStreamRef.current = stream;
        setLocalStream(stream);
        return stream;
    }

    // ── Initiate a call ────────────────────────────────────────
    const initiateCall = useCallback(async (targetUserId, targetUser, type = 'audio') => {
        setCallState('outgoing');
        setCallInfo({ type, peer: targetUser });

        emit('call_initiate', { target_user_id: targetUserId, type }, async (res) => {
            if (res.error) {
                setCallState(null);
                setCallInfo(null);
                alert(res.error === 'busy' ? `${targetUser.full_name} is already in a call.` : res.error);
                return;
            }

            const callId = res.call_id;
            setCallInfo(prev => ({ ...prev, callId }));

            try {
                const stream = await getLocalMedia(type);
                const pc = await createPeerConnection(candidate => {
                    emit('call_ice_candidate', { call_id: callId, target_user_id: targetUserId, candidate });
                });

                stream.getTracks().forEach(t => pc.addTrack(t, stream));
                pcRef.current = pc;

                const offer = await pc.createOffer();
                await pc.setLocalDescription(offer);
                emit('call_offer', { call_id: callId, target_user_id: targetUserId, sdp: offer });
            } catch (err) {
                console.error('Call setup error:', err);
                endCall();
            }
        });
    }, [emit]);

    // ── Accept incoming call ───────────────────────────────────
    const acceptCall = useCallback(async () => {
        if (!callInfo) return;
        const { callId, type, peer } = callInfo;
        setCallState('active');

        try {
            const stream = await getLocalMedia(type);
            const pc = await createPeerConnection(candidate => {
                emit('call_ice_candidate', { call_id: callId, target_user_id: peer.id, candidate });
            });

            stream.getTracks().forEach(t => pc.addTrack(t, stream));
            pcRef.current = pc;

            // SDP offer may have already arrived — it's stored in callInfo
            if (callInfo.sdp) {
                await pc.setRemoteDescription(callInfo.sdp);
                const answer = await pc.createAnswer();
                await pc.setLocalDescription(answer);
                emit('call_answer', { call_id: callId, caller_user_id: peer.id, sdp: answer });
            }
        } catch (err) {
            console.error('Accept call error:', err);
            rejectCall();
        }
    }, [callInfo, emit]);

    // ── Reject incoming call ───────────────────────────────────
    const rejectCall = useCallback(() => {
        if (!callInfo) return;
        emit('call_reject', { call_id: callInfo.callId, caller_user_id: callInfo.peer.id });
        cleanup();
    }, [callInfo, emit]);

    // ── End active call ────────────────────────────────────────
    const endCall = useCallback(() => {
        if (callInfo?.callId) emit('call_end', { call_id: callInfo.callId });
        cleanup();
    }, [callInfo, emit]);

    function cleanup() {
        pcRef.current?.close();
        pcRef.current = null;
        localStreamRef.current?.getTracks().forEach(t => t.stop());
        localStreamRef.current = null;
        setLocalStream(null);
        setRemoteStream(null);
        setCallState(null);
        setCallInfo(null);
        setIsMuted(false);
        setIsVideoOff(false);
    }

    function toggleMute() {
        localStreamRef.current?.getAudioTracks().forEach(t => { t.enabled = !t.enabled; });
        setIsMuted(m => !m);
    }

    function toggleVideo() {
        localStreamRef.current?.getVideoTracks().forEach(t => { t.enabled = !t.enabled; });
        setIsVideoOff(v => !v);
    }

    // ── Socket event listeners ─────────────────────────────────
    useEffect(() => {
        const unsubs = [
            on('incoming_call', ({ call_id, type, caller, conversation_id }) => {
                setCallState('incoming');
                setCallInfo({ callId: call_id, type, peer: caller, conversationId: conversation_id });
            }),

            on('call_offer_received', async ({ call_id, sdp, caller_id }) => {
                // Store SDP; acceptCall will use it
                setCallInfo(prev => prev ? { ...prev, sdp, callId: call_id } : null);
                // If already active (accepted before offer arrived), set remote desc now
                if (pcRef.current) {
                    await pcRef.current.setRemoteDescription(sdp);
                    const answer = await pcRef.current.createAnswer();
                    await pcRef.current.setLocalDescription(answer);
                    emit('call_answer', { call_id, caller_user_id: caller_id, sdp: answer });
                }
            }),

            on('call_answered', async ({ call_id, sdp }) => {
                setCallState('active');
                if (pcRef.current) {
                    await pcRef.current.setRemoteDescription(sdp).catch(console.error);
                }
            }),

            on('ice_candidate', async ({ candidate }) => {
                if (pcRef.current && candidate) {
                    await pcRef.current.addIceCandidate(candidate).catch(console.error);
                }
            }),

            on('call_rejected', () => {
                cleanup();
                alert('Call was declined.');
            }),

            on('call_ended', () => {
                cleanup();
            }),

            on('call_missed', () => {
                // Read via refs, not the closed-over state — this listener is
                // attached once (effect deps are [on, emit]) so callState/
                // callInfo from the outer closure would otherwise be stale.
                const peerName = callInfoRef.current?.peer?.full_name;
                const wasIncoming = callStateRef.current === 'incoming';
                cleanup();
                if (peerName) {
                    alert(wasIncoming
                        ? t('chat.call.missedFrom', { name: peerName })
                        : t('chat.call.noAnswerFrom', { name: peerName }));
                }
            }),
        ];

        return () => unsubs.forEach(u => u?.());
    }, [on, emit, t]);

    return {
        callState, callInfo, localStream, remoteStream,
        isMuted, isVideoOff,
        initiateCall, acceptCall, rejectCall, endCall,
        toggleMute, toggleVideo,
    };
}
