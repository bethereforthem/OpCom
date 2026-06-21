import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../core/api/api_client.dart';
import '../../core/socket/socket_service.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/avatar.dart';

class CallScreen extends StatefulWidget {
  final Map<String, dynamic> callInfo;
  final bool isIncoming;
  const CallScreen({super.key, required this.callInfo, required this.isIncoming});
  @override State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  final _localRenderer  = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();

  bool _isMuted    = false;
  bool _isVideoOff = false;
  bool _isActive   = false;
  String? _callId;
  int _seconds     = 0;

  bool get _isVideo => (widget.callInfo['type'] ?? 'audio') == 'video';

  @override
  void initState() {
    super.initState();
    _localRenderer.initialize();
    _remoteRenderer.initialize();
    _registerSocketListeners();

    if (!widget.isIncoming) {
      _startOutgoingCall();
    }
    // Incoming: wait for user to tap Accept
  }

  void _registerSocketListeners() {
    SocketService.on('call_offer_received', _onOfferReceived);
    SocketService.on('call_answered',       _onAnswered);
    SocketService.on('ice_candidate',       _onIceCandidate);
    SocketService.on('call_rejected',       (_) { _cleanup(); Navigator.pop(context); });
    SocketService.on('call_ended',          (_) { _cleanup(); Navigator.pop(context); });
    SocketService.on('call_missed',         (_) => _onMissed());
  }

  void _onMissed() {
    final l10n = AppLocalizations.of(context)!;
    final peer = widget.callInfo['caller'] ?? widget.callInfo['peer'];
    final peerName = peer?['full_name'] as String?;
    if (peerName != null) {
      // ScaffoldMessenger is a single app-wide overlay (provided once near
      // MaterialApp's root) — showing it here, before the pop below, still
      // displays correctly on whichever screen is current after navigating
      // back, since the message isn't tied to this screen's own Scaffold.
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
          widget.isIncoming ? l10n.callMissedFrom(peerName) : l10n.callNoAnswerFrom(peerName))));
    }
    _cleanup();
    Navigator.pop(context);
  }

  Future<void> _startOutgoingCall() async {
    final targetId = widget.callInfo['target_user_id'];
    final type     = widget.callInfo['type'] ?? 'audio';

    SocketService.emit('call_initiate', {'target_user_id': targetId, 'type': type}, (res) async {
      if (res is Map && res['error'] != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['error'].toString())));
        Navigator.pop(context);
        return;
      }
      _callId = res['call_id'];
      await _setupPeerConnection(targetId);

      final offer = await _pc!.createOffer();
      await _pc!.setLocalDescription(offer);
      SocketService.emit('call_offer', {'call_id': _callId, 'target_user_id': targetId, 'sdp': offer.toMap()});
    });
  }

  Future<void> _acceptIncomingCall() async {
    setState(() => _isActive = true);
    _callId = widget.callInfo['call_id'];
    final callerId = widget.callInfo['caller']?['id'];
    await _setupPeerConnection(callerId);
    // Offer may already be in callInfo (set by socket event) or will arrive via call_offer_received
  }

  Future<void> _setupPeerConnection(String? peerId) async {
    final turnRes = await ApiClient.getTurnCredentials();
    final iceServers = (turnRes.data['ice_servers'] as List).map((s) {
      return {
        'urls': s['urls'],
        if (s['username'] != null) 'username': s['username'],
        if (s['credential'] != null) 'credential': s['credential'],
      };
    }).toList();

    _pc = await createPeerConnection({'iceServers': iceServers});

    _localStream = await navigator.mediaDevices.getUserMedia({'audio': true, 'video': _isVideo});
    _localRenderer.srcObject = _localStream;
    _localStream!.getTracks().forEach((t) => _pc!.addTrack(t, _localStream!));

    _pc!.onIceCandidate = (c) {
      if (c.candidate != null) {
        SocketService.emit('call_ice_candidate', {
          'call_id': _callId, 'target_user_id': peerId, 'candidate': c.toMap()});
      }
    };

    _pc!.onTrack = (e) {
      setState(() {
        _remoteStream = e.streams.isNotEmpty ? e.streams[0] : null;
        _remoteRenderer.srcObject = _remoteStream;
      });
    };

    setState(() {});
  }

  void _onOfferReceived(dynamic data) async {
    if (_pc == null) return;
    final sdp = RTCSessionDescription(data['sdp']['sdp'], data['sdp']['type']);
    await _pc!.setRemoteDescription(sdp);
    final answer = await _pc!.createAnswer();
    await _pc!.setLocalDescription(answer);
    final callerId = data['caller_id'];
    SocketService.emit('call_answer', {'call_id': _callId, 'caller_user_id': callerId, 'sdp': answer.toMap()});
    setState(() => _isActive = true);
    _startTimer();
  }

  void _onAnswered(dynamic data) async {
    if (_pc == null) return;
    final sdp = RTCSessionDescription(data['sdp']['sdp'], data['sdp']['type']);
    await _pc!.setRemoteDescription(sdp);
    setState(() => _isActive = true);
    _startTimer();
  }

  void _onIceCandidate(dynamic data) async {
    if (_pc == null) return;
    final c = RTCIceCandidate(data['candidate']['candidate'],
        data['candidate']['sdpMid'], data['candidate']['sdpMLineIndex']);
    await _pc!.addCandidate(c);
  }

  void _startTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted || !_isActive) return false;
      setState(() => _seconds++);
      return true;
    });
  }

  String get _timerLabel {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _toggleMute() {
    _localStream?.getAudioTracks().forEach((t) => t.enabled = !t.enabled);
    setState(() => _isMuted = !_isMuted);
  }

  void _toggleVideo() {
    _localStream?.getVideoTracks().forEach((t) => t.enabled = !t.enabled);
    setState(() => _isVideoOff = !_isVideoOff);
  }

  void _endCall() {
    if (_callId != null) SocketService.emit('call_end', {'call_id': _callId});
    _cleanup();
    Navigator.pop(context);
  }

  void _cleanup() {
    SocketService.off('call_offer_received');
    SocketService.off('call_answered');
    SocketService.off('ice_candidate');
    SocketService.off('call_rejected');
    SocketService.off('call_ended');
    SocketService.off('call_missed');
    _pc?.close();
    _localStream?.dispose();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
  }

  @override
  void dispose() { _cleanup(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final peer = widget.callInfo['caller'] ?? widget.callInfo['peer'] ?? {};
    final peerName = peer['full_name'] ?? l10n.commonUnknown;

    // Incoming call — not yet accepted
    if (widget.isIncoming && !_isActive) {
      return Scaffold(
        backgroundColor: AppTheme.bg,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: AppTheme.heroGlow),
                  child: Avatar(name: peerName, size: 80),
                ),
                const SizedBox(height: 16),
                Text(l10n.callIncoming(_isVideo ? l10n.callVideo : l10n.callAudio),
                    style: const TextStyle(color: AppTheme.textSub)),
                const SizedBox(height: 8),
                Text(peerName, style: const TextStyle(fontSize: 26,
                    fontWeight: FontWeight.bold, color: AppTheme.textMain)),
                const SizedBox(height: 60),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _CallBtn(icon: Icons.call_end_rounded, color: AppTheme.danger,
                        onTap: () { SocketService.emit('call_reject',
                          {'call_id': widget.callInfo['call_id'],
                           'caller_user_id': peer['id']}); Navigator.pop(context); }),
                    _CallBtn(icon: Icons.call_rounded, color: AppTheme.success,
                        onTap: _acceptIncomingCall),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Active / outgoing call
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Remote video (full screen)
          if (_isVideo && _remoteStream != null)
            Positioned.fill(child: RTCVideoView(_remoteRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)),

          // Audio / waiting placeholder
          if (!_isVideo || _remoteStream == null)
            Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Avatar(name: peerName, size: 80),
                const SizedBox(height: 16),
                Text(peerName, style: const TextStyle(fontSize: 22,
                    fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 8),
                Text(_isActive ? _timerLabel : l10n.callCalling,
                    style: const TextStyle(color: Colors.white60)),
              ],
            )),

          // Local video pip
          if (_isVideo && _localStream != null)
            Positioned(bottom: 100, right: 12,
              child: ClipRRect(borderRadius: BorderRadius.circular(12),
                child: SizedBox(width: 100, height: 130,
                  child: RTCVideoView(_localRenderer, mirror: true)))),

          // Timer (video calls)
          if (_isVideo && _isActive)
            Positioned(top: 48, left: 0, right: 0,
              child: Center(child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(20)),
                child: Text(_timerLabel, style: const TextStyle(color: Colors.white, fontFamily: 'monospace'))))),

          // Controls
          Positioned(bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              color: Colors.black45,
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                _CallBtn(icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                    color: _isMuted ? AppTheme.danger : Colors.white24, onTap: _toggleMute),
                _CallBtn(icon: Icons.call_end_rounded, color: AppTheme.danger, size: 64, onTap: _endCall),
                if (_isVideo)
                  _CallBtn(icon: _isVideoOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
                      color: _isVideoOff ? AppTheme.danger : Colors.white24, onTap: _toggleVideo)
                else
                  const SizedBox(width: 56),
              ]),
            )),
        ],
      ),
    );
  }
}

class _CallBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final double size;
  const _CallBtn({required this.icon, required this.color, required this.onTap, this.size = 56});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: size * 0.45),
      ),
    );
  }
}
