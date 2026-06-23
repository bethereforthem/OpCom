import 'dart:async';
import 'dart:typed_data';
import 'package:dio/dio.dart' as dio_pkg;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart';
import 'voice_recorder_native.dart' if (dart.library.html) 'voice_recorder_web.dart';
import '../../core/api/api_client.dart';
import '../../core/socket/socket_service.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/avatar.dart';
import '../calls/call_screen.dart';
import 'forward_screen.dart';
import 'message_actions_sheet.dart';

const Map<String, int> kDisappearingSeconds = {'24h': 86400, '7d': 604800, '90d': 7776000};

class ChatScreen extends StatefulWidget {
  final Map<String, dynamic> conversation;
  final String myId;
  const ChatScreen({super.key, required this.conversation, required this.myId});
  @override State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messages   = <Map<String, dynamic>>[];
  final _textCtrl   = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _loading     = true;
  bool _hasMore     = false;
  bool _uploading   = false;
  Map<String, dynamic>? _replyTarget;
  Map<String, dynamic>? _editingMessage;
  String? _mentionQuery;
  final _scheduledMessages = <Map<String, dynamic>>[];
  bool _showScheduled = false;
  int? _disappearingSeconds;

  // Voice recording — platform-selected at compile time
  final _recorder = VoiceRecorder();
  bool _isRecording = false;
  int  _recordSeconds = 0;
  int  _recordDuration = 0;        // frozen when recording stops
  Uint8List? _pendingVoiceBytes;   // bytes ready to send (stopped, not yet sent)
  Timer? _recordTimer;

  String get _convId => widget.conversation['id'];
  bool get _isGroup => widget.conversation['type'] == 'group';
  bool get _canToggleDisappearing =>
      !_isGroup || ['owner', 'admin'].contains(widget.conversation['my_role']);

  List<Map<String, dynamic>> get _members {
    final members = widget.conversation['conversation_members'] as List? ?? [];
    return members
        .where((m) => m['users']?['id'] != widget.myId)
        .map((m) => Map<String, dynamic>.from(m['users'] ?? {}))
        .toList();
  }

  List<Map<String, dynamic>> get _mentionCandidates {
    if (_mentionQuery == null) return [];
    final q = _mentionQuery!.toLowerCase();
    final result = <Map<String, dynamic>>[];
    if (_isGroup && 'all'.startsWith(q)) {
      result.add({'username': 'all', 'full_name': AppLocalizations.of(context)!.chatEveryoneInGroup});
    }
    result.addAll(_members.where((m) =>
        (m['username'] as String? ?? '').toLowerCase().startsWith(q)));
    return result;
  }

  @override
  void initState() {
    super.initState();
    _disappearingSeconds = widget.conversation['disappearing_duration_seconds'];
    _loadMessages();
    _loadScheduled();
    SocketService.on('new_message',      _onNewMessage);
    SocketService.on('message_deleted',  _onDeleted);
    SocketService.on('message_edited',   _onEdited);
    SocketService.on('message_reaction_updated', _onReaction);
    SocketService.on('incoming_call',    _onIncomingCall);
    SocketService.on('disappearing_settings_updated', _onDisappearingUpdated);
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    SocketService.off('new_message');
    SocketService.off('message_deleted');
    SocketService.off('message_edited');
    SocketService.off('message_reaction_updated');
    SocketService.off('incoming_call');
    SocketService.off('disappearing_settings_updated');
    _scrollCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  // ── Voice recording ──────────────────────────────────────────

  Future<void> _startVoiceRecording() async {
    // On native, explicitly request mic permission before starting.
    // On web, the browser shows its own permission dialog inside getUserMedia.
    if (!kIsWeb) {
      final status = await Permission.microphone.request();
      if (!mounted) return;
      if (status != PermissionStatus.granted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(status == PermissionStatus.permanentlyDenied
              ? 'Microphone access is blocked. Enable it in device Settings.'
              : 'Microphone permission denied.'),
          action: status == PermissionStatus.permanentlyDenied
              ? SnackBarAction(label: 'Settings', onPressed: openAppSettings)
              : null,
        ));
        return;
      }
    }
    try {
      await _recorder.start();
      setState(() { _isRecording = true; _recordSeconds = 0; });
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() => _recordSeconds++);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not start recording: $e')),
      );
    }
  }

  // Step 1: stop the mic (but don't send yet).
  Future<void> _stopRecording() async {
    _recordTimer?.cancel();
    final duration = _recordSeconds;
    setState(() { _isRecording = false; _recordDuration = duration; _recordSeconds = 0; _uploading = true; });
    try {
      final bytes = await _recorder.stop();
      if (bytes == null || bytes.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recording was empty — nothing to send.')),
        );
        setState(() { _recordDuration = 0; });
        return;
      }
      setState(() => _pendingVoiceBytes = bytes);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to stop recording: $e')),
      );
      setState(() { _recordDuration = 0; });
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  // Step 2: upload and send the stopped recording.
  Future<void> _sendPendingVoiceNote() async {
    final bytes = _pendingVoiceBytes;
    if (bytes == null || bytes.isEmpty) return;
    setState(() { _pendingVoiceBytes = null; _recordDuration = 0; _uploading = true; });
    try {
      final res = await ApiClient.uploadMediaBytes(
          bytes, _recorder.fileName, _recorder.mimeType);
      final mediaId = res.data['media_id'];
      SocketService.emit('send_message', {
        'conversation_id': _convId,
        'type': 'audio',
        'media_id': mediaId,
        'reply_to_id': _replyTarget?['id'],
      });
      setState(() => _replyTarget = null);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send voice note: $e')),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _cancelVoiceRecording() async {
    _recordTimer?.cancel();
    if (_isRecording) await _recorder.cancel();
    setState(() {
      _isRecording = false;
      _recordSeconds = 0;
      _recordDuration = 0;
      _pendingVoiceBytes = null;
    });
  }

  String _formatRecordDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ── Scheduled / disappearing ─────────────────────────────────

  Future<void> _loadScheduled() async {
    final res = await ApiClient.getScheduledMessages(_convId);
    final list = List<Map<String, dynamic>>.from(res.data['scheduled_messages'] ?? []);
    setState(() {
      _scheduledMessages.clear();
      _scheduledMessages.addAll(list);
    });
  }

  Future<void> _cancelScheduled(String id) async {
    await ApiClient.cancelScheduledMessage(_convId, id);
    setState(() => _scheduledMessages.removeWhere((sm) => sm['id'] == id));
  }

  void _onDisappearingUpdated(dynamic data) {
    final map = data as Map;
    if (map['conversation_id'] != _convId) return;
    setState(() => _disappearingSeconds = map['disappearing_duration_seconds']);
  }

  Future<void> _setDisappearing(String? duration) async {
    await ApiClient.setDisappearing(_convId, duration);
  }

  void _showDisappearingSheet() {
    final l10n = AppLocalizations.of(context)!;
    if (!_canToggleDisappearing) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.chatDisappearingRestricted)));
      return;
    }
    final labels = {
      '24h': l10n.chatDisappearing24h,
      '7d': l10n.chatDisappearing7d,
      '90d': l10n.chatDisappearing90d,
    };
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _disappearingOption(ctx, null, l10n.chatDisappearingOff),
          ...kDisappearingSeconds.entries.map((e) => _disappearingOption(ctx, e.key, labels[e.key]!)),
        ]),
      ),
    );
  }

  ListTile _disappearingOption(BuildContext ctx, String? value, String label) {
    final isCurrent = value == null ? _disappearingSeconds == null : kDisappearingSeconds[value] == _disappearingSeconds;
    return ListTile(
      title: Text(label, style: const TextStyle(color: AppTheme.textMain)),
      trailing: isCurrent ? const Icon(Icons.check, color: AppTheme.primary) : null,
      onTap: () {
        Navigator.pop(ctx);
        _setDisappearing(value);
      },
    );
  }

  Future<void> _scheduleMessage() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;

    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(minutes: 5)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return;
    if (!mounted) return;

    final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (time == null) return;

    final sendAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (sendAt.isBefore(DateTime.now())) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.chatPickFutureTime)));
      return;
    }

    final res = await ApiClient.scheduleMessage(_convId, {
      'type': 'text',
      'content': text,
      'send_at': sendAt.toIso8601String(),
      'reply_to_id': _replyTarget?['id'],
    });
    setState(() {
      _scheduledMessages.add(res.data['scheduled_message']);
      _scheduledMessages.sort((a, b) =>
          DateTime.parse(a['send_at']).compareTo(DateTime.parse(b['send_at'])));
      _replyTarget = null;
    });
    _textCtrl.clear();
  }

  // ── Messages ─────────────────────────────────────────────────

  Future<void> _loadMessages({String? before}) async {
    final res = await ApiClient.getMessages(_convId, before: before);
    final data = res.data as Map<String, dynamic>;
    final msgs = List<Map<String, dynamic>>.from(data['messages'] ?? []);
    setState(() {
      if (before != null) {
        _messages.insertAll(0, msgs);
      } else {
        _messages.clear();
        _messages.addAll(msgs);
      }
      _hasMore = data['has_more'] == true;
      _loading = false;
    });
    if (before == null) _scrollToBottom();
  }

  void _onNewMessage(dynamic data) {
    final msg = data as Map<String, dynamic>;
    if (msg['conversation_id'] != _convId) return;
    setState(() => _messages.add(msg));
    SocketService.emit('message_read', {'message_id': msg['id']});
    _scrollToBottom();
  }

  void _onDeleted(dynamic data) {
    final id = (data as Map)['message_id'];
    setState(() {
      final idx = _messages.indexWhere((m) => m['id'] == id);
      if (idx != -1) _messages[idx] = {..._messages[idx], 'is_deleted': true, 'content': null};
    });
  }

  void _onEdited(dynamic data) {
    final map = data as Map;
    final id = map['message_id'];
    setState(() {
      final idx = _messages.indexWhere((m) => m['id'] == id);
      if (idx != -1) {
        _messages[idx] = {..._messages[idx], 'content': map['content'], 'edited_at': map['edited_at']};
      }
    });
  }

  void _onReaction(dynamic data) {
    final map = data as Map;
    final id = map['message_id'];
    final userId = map['user_id'];
    final emoji = map['emoji'];
    setState(() {
      final idx = _messages.indexWhere((m) => m['id'] == id);
      if (idx == -1) return;
      final reactions = List<Map<String, dynamic>>.from(_messages[idx]['message_reactions'] ?? []);
      reactions.removeWhere((r) => r['user_id'] == userId);
      if (emoji != null) reactions.add({'user_id': userId, 'emoji': emoji});
      _messages[idx] = {..._messages[idx], 'message_reactions': reactions};
    });
  }

  void _onIncomingCall(dynamic data) {
    final call = data as Map<String, dynamic>;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => CallScreen(callInfo: call, isIncoming: true),
    ));
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  void _sendText() {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;

    if (_editingMessage != null) {
      final msgId = _editingMessage!['id'];
      setState(() => _editingMessage = null);
      _textCtrl.clear();
      SocketService.emit('edit_message', {'message_id': msgId, 'content': text}, (ack) {
        if (ack is Map && ack['error'] != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not edit message: ${ack['error']}')),
          );
        }
      });
      return;
    }

    SocketService.emit('send_message', {
      'conversation_id': _convId,
      'type': 'text',
      'content': text,
      'reply_to_id': _replyTarget?['id'],
    });
    _textCtrl.clear();
    setState(() => _replyTarget = null);
  }

  void _onTextChanged(String value) {
    final cursor = _textCtrl.selection.baseOffset;
    final upToCursor = cursor >= 0 ? value.substring(0, cursor) : value;
    final match = RegExp(r'@(\w*)$').firstMatch(upToCursor);
    setState(() => _mentionQuery = match?.group(1));
  }

  void _pickMention(String username) {
    final cursor = _textCtrl.selection.baseOffset;
    final text = _textCtrl.text;
    final upToCursor = cursor >= 0 ? text.substring(0, cursor) : text;
    final replaced = upToCursor.replaceFirst(RegExp(r'@(\w*)$'), '@$username ');
    final newText = replaced + text.substring(cursor >= 0 ? cursor : text.length);
    _textCtrl.text = newText;
    _textCtrl.selection = TextSelection.collapsed(offset: replaced.length);
    setState(() => _mentionQuery = null);
  }

  Future<void> _attachFile() async {
    final messenger = ScaffoldMessenger.of(context);
    // withData: true loads bytes into memory — this avoids content:// URI issues
    // on Android where MultipartFile.fromFile cannot read scoped-storage paths.
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      allowMultiple: false,
      type: FileType.any,
    );
    if (result == null || result.files.isEmpty) return;
    final file  = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Could not read file')));
      return;
    }

    setState(() => _uploading = true);
    try {
      final mime    = _mimeFromExt(file.extension ?? '');
      final res     = await ApiClient.uploadMediaBytes(bytes, file.name, mime);
      final mediaId = res.data['media_id'];
      final msgType = _msgTypeFromMime(mime);
      SocketService.emit('send_message', {
        'conversation_id': _convId,
        'type': msgType,
        'media_id': mediaId,
        'reply_to_id': _replyTarget?['id'],
      });
      setState(() => _replyTarget = null);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      setState(() => _uploading = false);
    }
  }

  String _mimeFromExt(String ext) {
    const map = {
      // Images
      'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'png': 'image/png',
      'gif': 'image/gif',  'webp': 'image/webp', 'bmp': 'image/bmp',
      'svg': 'image/svg+xml', 'heic': 'image/heic', 'heif': 'image/heif',
      // Audio
      'mp3': 'audio/mpeg', 'ogg': 'audio/ogg', 'wav': 'audio/wav',
      'm4a': 'audio/mp4',  'aac': 'audio/aac', 'flac': 'audio/flac',
      // Video
      'mp4': 'video/mp4',  'webm': 'video/webm', 'mov': 'video/quicktime',
      'avi': 'video/x-msvideo', 'mkv': 'video/x-matroska',
      // Documents
      'pdf': 'application/pdf',
      'doc': 'application/msword',
      'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls': 'application/vnd.ms-excel',
      'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'ppt': 'application/vnd.ms-powerpoint',
      'pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'txt': 'text/plain', 'csv': 'text/csv', 'json': 'application/json',
      'xml': 'application/xml', 'html': 'text/html', 'md': 'text/markdown',
      // Archives
      'zip': 'application/zip', 'rar': 'application/vnd.rar',
      '7z': 'application/x-7z-compressed', 'tar': 'application/x-tar',
      'gz': 'application/gzip',
      // APK
      'apk': 'application/vnd.android.package-archive',
    };
    return map[ext.toLowerCase()] ?? 'application/octet-stream';
  }

  String _msgTypeFromMime(String mime) {
    if (mime.startsWith('image/')) return 'image';
    if (mime.startsWith('audio/')) return 'audio';
    if (mime.startsWith('video/')) return 'video';
    return 'document';
  }

  void _startReply(Map<String, dynamic> message) {
    setState(() { _editingMessage = null; _replyTarget = message; });
  }

  void _startEdit(Map<String, dynamic> message) {
    setState(() { _replyTarget = null; _editingMessage = message; _textCtrl.text = message['content'] ?? ''; });
  }

  void _cancelComposerExtra() {
    setState(() { _replyTarget = null; _editingMessage = null; _textCtrl.clear(); });
  }

  void _reactToMessage(Map<String, dynamic> message, String emoji) {
    SocketService.emit('react_to_message', {'message_id': message['id'], 'emoji': emoji});
  }

  void _removeReaction(Map<String, dynamic> message) {
    SocketService.emit('remove_reaction', {'message_id': message['id']});
  }

  Future<void> _confirmDeleteMessage(Map<String, dynamic> message) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(l10n.chatDelete, style: const TextStyle(color: AppTheme.textMain)),
        content: Text(l10n.chatConfirmDeleteMessage, style: const TextStyle(color: AppTheme.textSub)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.commonCancel)),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.chatDelete, style: const TextStyle(color: AppTheme.danger))),
        ],
      ),
    );
    if (confirmed == true) {
      SocketService.emit('delete_message', {'message_id': message['id']}, (ack) {
        if (ack is Map && ack['error'] != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not delete message: ${ack['error']}')),
          );
        }
      });
    }
  }

  Future<void> _forwardMessage(String messageId, List<String> conversationIds) {
    final completer = Completer<void>();
    SocketService.emit('forward_message', {'message_id': messageId, 'conversation_ids': conversationIds}, (ack) {
      if (ack is Map && ack['ok'] == true) {
        completer.complete();
      } else {
        completer.completeError(ack is Map ? ack['error'] : 'Failed to forward');
      }
    });
    return completer.future;
  }

  void _openForwardScreen(Map<String, dynamic> message) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ForwardScreen(message: message, myId: widget.myId, onForward: _forwardMessage),
    ));
  }

  void _showActionsFor(Map<String, dynamic> message, bool isMine) {
    showMessageActionsSheet(
      context: context,
      message: message,
      isMine: isMine,
      onReply: () => _startReply(message),
      onEdit: isMine ? () => _startEdit(message) : null,
      onReact: (emoji) => _reactToMessage(message, emoji),
      onForward: () => _openForwardScreen(message),
      onDelete: isMine ? () => _confirmDeleteMessage(message) : null,
    );
  }

  String _displayName() {
    final l10n = AppLocalizations.of(context)!;
    if (widget.conversation['type'] == 'group') return widget.conversation['name'] ?? l10n.commonGroup;
    final members = widget.conversation['conversation_members'] as List? ?? [];
    final other = members.firstWhere((m) => m['users']?['id'] != widget.myId, orElse: () => null);
    return other?['users']?['full_name'] ?? l10n.commonUnknown;
  }

  Map<String, dynamic>? _otherMember() {
    if (widget.conversation['type'] == 'group') return null;
    final members = widget.conversation['conversation_members'] as List? ?? [];
    return members.firstWhere((m) => m['users']?['id'] != widget.myId, orElse: () => null)?['users'];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final other = _otherMember();
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Avatar(name: _displayName(), size: 32),
          const SizedBox(width: 10),
          Text(_displayName(), style: const TextStyle(fontWeight: FontWeight.w600)),
        ]),
        actions: [
          IconButton(
            icon: Icon(Icons.timer_outlined, color: _disappearingSeconds != null ? AppTheme.cta : null),
            tooltip: l10n.chatDisappearingMessages,
            onPressed: _showDisappearingSheet,
          ),
          if (other != null) ...[
            IconButton(icon: const Icon(Icons.call_rounded),
                onPressed: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => CallScreen(callInfo: {'target_user_id': other['id'], 'type': 'audio', 'peer': other}, isIncoming: false)))),
            IconButton(icon: const Icon(Icons.videocam_rounded),
                onPressed: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => CallScreen(callInfo: {'target_user_id': other['id'], 'type': 'video', 'peer': other}, isIncoming: false)))),
          ],
        ],
      ),
      body: Column(children: [
        // Messages
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
              : ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.all(12),
                  itemCount: _messages.length + (_hasMore ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i == 0 && _hasMore) {
                      return TextButton(
                          onPressed: () => _loadMessages(before: _messages.first['created_at']),
                          child: Text(l10n.chatLoadOlder));
                    }
                    final msg = _messages[_hasMore ? i - 1 : i];
                    if (msg['type'] == 'system') {
                      return Center(
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(12)),
                          child: Text(msg['content'] ?? '', style: const TextStyle(color: AppTheme.textSub, fontSize: 12)),
                        ),
                      );
                    }
                    final isMine = msg['users']?['id'] == widget.myId || msg['sender_id'] == widget.myId;
                    return GestureDetector(
                      onLongPress: () => _showActionsFor(msg, isMine),
                      child: _MessageBubble(
                        message: msg,
                        isMine: isMine,
                        myId: widget.myId,
                        memberUsernames: _members.map((m) => (m['username'] as String? ?? '').toLowerCase()).toSet(),
                        onToggleReaction: (emoji, mine) =>
                            mine ? _removeReaction(msg) : _reactToMessage(msg, emoji),
                      ),
                    );
                  },
                ),
        ),

        if (_uploading)
          const LinearProgressIndicator(backgroundColor: AppTheme.border, color: AppTheme.primary),

        // Reply / edit preview
        if (!_isRecording && _pendingVoiceBytes == null && (_replyTarget != null || _editingMessage != null))
          Container(
            color: AppTheme.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _editingMessage != null
                          ? l10n.chatEditingMessage
                          : l10n.chatReplyingTo(_replyTarget?['users']?['full_name'] ?? l10n.commonUnknown),
                      style: const TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      (_editingMessage ?? _replyTarget)?['content'] ?? l10n.commonMedia,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppTheme.textSub, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: AppTheme.textSub, size: 18),
                onPressed: _cancelComposerExtra,
              ),
            ]),
          ),

        // Mention autocomplete
        if (!_isRecording && _pendingVoiceBytes == null && _mentionCandidates.isNotEmpty)
          Container(
            color: AppTheme.surface,
            constraints: const BoxConstraints(maxHeight: 160),
            child: ListView(
              shrinkWrap: true,
              children: _mentionCandidates.map((m) => ListTile(
                dense: true,
                title: Text('@${m['username']}', style: const TextStyle(color: AppTheme.primary)),
                subtitle: m['full_name'] != null
                    ? Text(m['full_name'], style: const TextStyle(color: AppTheme.textSub, fontSize: 12))
                    : null,
                onTap: () => _pickMention(m['username']),
              )).toList(),
            ),
          ),

        // Scheduled messages
        if (!_isRecording && _pendingVoiceBytes == null && _scheduledMessages.isNotEmpty)
          Container(
            color: AppTheme.surface,
            child: Column(children: [
              ListTile(
                dense: true,
                title: Text(l10n.chatScheduledCount(_scheduledMessages.length),
                    style: const TextStyle(color: AppTheme.textSub, fontSize: 13)),
                trailing: Icon(_showScheduled ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    color: AppTheme.textSub),
                onTap: () => setState(() => _showScheduled = !_showScheduled),
              ),
              if (_showScheduled)
                ..._scheduledMessages.map((sm) => ListTile(
                      dense: true,
                      title: Text(sm['content'] ?? l10n.commonMedia,
                          style: const TextStyle(color: AppTheme.textMain, fontSize: 13),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                          DateTime.parse(sm['send_at']).toLocal().toString(),
                          style: const TextStyle(color: AppTheme.textSub, fontSize: 11)),
                      trailing: TextButton(
                        onPressed: () => _cancelScheduled(sm['id']),
                        child: Text(l10n.commonCancel,
                            style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                      ),
                    )),
            ]),
          ),

        // ── Input bar ────────────────────────────────────────────
        (_isRecording || _pendingVoiceBytes != null) ? _buildRecordingBar() : _buildInputBar(l10n),
      ]),
    );
  }

  Widget _buildRecordingBar() {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SafeArea(
        top: false,
        child: Row(children: [
          // Discard / cancel
          GestureDetector(
            onTap: _cancelVoiceRecording,
            child: const Icon(Icons.delete_rounded, color: AppTheme.danger, size: 28),
          ),
          const SizedBox(width: 12),

          if (_isRecording) ...[
            // Live: pulsing red dot + elapsed timer
            Expanded(
              child: Row(children: [
                Container(
                  width: 10, height: 10,
                  decoration: const BoxDecoration(color: AppTheme.danger, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatRecordDuration(_recordSeconds),
                  style: const TextStyle(color: AppTheme.textMain, fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Recording…', style: TextStyle(color: AppTheme.textSub, fontSize: 13)),
                ),
              ]),
            ),
            // Stop button — stops mic, enters preview state
            GestureDetector(
              onTap: _stopRecording,
              child: Container(
                width: 44, height: 44,
                decoration: const BoxDecoration(color: AppTheme.danger, shape: BoxShape.circle),
                child: const Icon(Icons.stop_rounded, color: Colors.white, size: 24),
              ),
            ),
          ] else ...[
            // Preview: mic icon + total duration
            Expanded(
              child: Row(children: [
                const Icon(Icons.mic_rounded, color: AppTheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  _formatRecordDuration(_recordDuration),
                  style: const TextStyle(color: AppTheme.textMain, fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Ready to send', style: TextStyle(color: AppTheme.textSub, fontSize: 13)),
                ),
              ]),
            ),
            // Send button
            GestureDetector(
              onTap: _sendPendingVoiceNote,
              child: Container(
                width: 44, height: 44,
                decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
                child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _buildInputBar(AppLocalizations l10n) {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: SafeArea(
        top: false,
        child: Row(children: [
          // Attach file
          IconButton(
            icon: const Icon(Icons.attach_file_rounded, color: AppTheme.textSub),
            onPressed: _uploading ? null : _attachFile,
          ),
          // Schedule
          IconButton(
            icon: const Icon(Icons.schedule_rounded, color: AppTheme.textSub),
            tooltip: l10n.chatScheduleMessage,
            onPressed: _scheduleMessage,
          ),
          // Text field
          Expanded(
            child: TextField(
              controller: _textCtrl,
              onChanged: _onTextChanged,
              style: const TextStyle(color: AppTheme.textMain),
              decoration: InputDecoration(
                hintText: l10n.chatTypeMessage,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                filled: true, fillColor: AppTheme.bg,
              ),
              maxLines: null,
              textInputAction: TextInputAction.newline,
            ),
          ),
          const SizedBox(width: 8),

          // Mic (when empty) OR Send (when has text)
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _textCtrl,
            builder: (_, value, __) {
              final hasText = value.text.trim().isNotEmpty;
              return GestureDetector(
                onTap: hasText ? _sendText : _startVoiceRecording,
                child: Container(
                  width: 44, height: 44,
                  decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
                  child: Icon(
                    hasText ? Icons.send_rounded : Icons.mic_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              );
            },
          ),
        ]),
      ),
    );
  }
}

// ── Reply preview inside bubble ───────────────────────────────

class _ReplyPreview extends StatelessWidget {
  final Map<String, dynamic> replyTo;
  const _ReplyPreview({required this.replyTo});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final label = replyTo['is_deleted'] == true
        ? l10n.chatOriginalDeleted
        : replyTo['type'] != 'text'
            ? ({'image': l10n.chatPhotoType, 'audio': l10n.chatAudioType, 'video': l10n.chatVideoType, 'document': l10n.chatDocumentType}[replyTo['type']] ?? l10n.commonMedia)
            : (replyTo['content'] ?? '');

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.only(left: 8),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: AppTheme.primary, width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(replyTo['users']?['full_name'] ?? l10n.commonUnknown,
              style: const TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.w600)),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppTheme.textSub, fontSize: 11)),
        ],
      ),
    );
  }
}

// ── Forwarded label ───────────────────────────────────────────

class _ForwardedLabel extends StatelessWidget {
  final Map<String, dynamic> forwardedFrom;
  const _ForwardedLabel({required this.forwardedFrom});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        l10n.chatForwardedFrom(forwardedFrom['users']?['full_name'] ?? l10n.commonUnknown),
        style: const TextStyle(color: AppTheme.textSub, fontSize: 11, fontStyle: FontStyle.italic),
      ),
    );
  }
}

// ── Reaction bar ──────────────────────────────────────────────

class _ReactionBar extends StatelessWidget {
  final List<dynamic> reactions;
  final String myId;
  final void Function(String emoji, bool mine) onToggle;
  const _ReactionBar({required this.reactions, required this.myId, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty) return const SizedBox.shrink();
    final grouped = <String, List<String>>{};
    for (final r in reactions) {
      grouped.putIfAbsent(r['emoji'], () => []).add(r['user_id']);
    }
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 4,
        children: grouped.entries.map((e) {
          final mine = e.value.contains(myId);
          return GestureDetector(
            onTap: () => onToggle(e.key, mine),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: mine ? AppTheme.primary.withValues(alpha: 0.25) : AppTheme.bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: mine ? AppTheme.primary : AppTheme.border),
              ),
              child: Text('${e.key} ${e.value.length}',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textMain)),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Message bubble ────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMine;
  final String myId;
  final Set<String> memberUsernames;
  final void Function(String emoji, bool mine) onToggleReaction;
  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.myId,
    required this.memberUsernames,
    required this.onToggleReaction,
  });

  String _receiptTick(dynamic messageStatus) {
    final statuses = List<Map<String, dynamic>>.from(messageStatus ?? []);
    final delivered = statuses.any((s) => s['read_at'] != null || s['delivered_at'] != null);
    return delivered ? '✓✓' : '✓';
  }

  bool _isRead(dynamic messageStatus) {
    final statuses = List<Map<String, dynamic>>.from(messageStatus ?? []);
    return statuses.any((s) => s['read_at'] != null);
  }

  List<TextSpan> _contentSpans(String content, Color baseColor) {
    final mentionStyle = isMine
        ? const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, decoration: TextDecoration.underline)
        : const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700);
    final parts = content.split(RegExp(r'(@\w+)'));
    return parts.map((part) {
      if (part.startsWith('@')) {
        final uname = part.substring(1).toLowerCase();
        if (uname == 'all' || uname == 'everyone' || memberUsernames.contains(uname)) {
          return TextSpan(text: part, style: mentionStyle);
        }
      }
      return TextSpan(text: part, style: TextStyle(color: baseColor));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (message['is_deleted'] == true) {
      return Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
          child: Text(l10n.chatMessageDeleted,
              style: const TextStyle(color: AppTheme.textSub, fontStyle: FontStyle.italic, fontSize: 12)),
        ),
      );
    }

    final time = message['created_at'] != null
        ? TimeOfDay.fromDateTime(DateTime.parse(message['created_at']).toLocal()).format(context)
        : '';
    final reactions = List<Map<String, dynamic>>.from(message['message_reactions'] ?? []);
    final hasMedia = message['type'] != 'text' && message['media_id'] != null;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
            padding: EdgeInsets.symmetric(
              horizontal: hasMedia && message['type'] == 'audio' ? 8 : 14,
              vertical: 10,
            ),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
            decoration: BoxDecoration(
              color: isMine ? AppTheme.sentBubble : AppTheme.receivedBubble,
              borderRadius: BorderRadius.only(
                topLeft:     const Radius.circular(18),
                topRight:    const Radius.circular(18),
                bottomLeft:  Radius.circular(isMine ? 18 : 4),
                bottomRight: Radius.circular(isMine ? 4 : 18),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message['forwarded_from'] != null)
                  _ForwardedLabel(forwardedFrom: message['forwarded_from']),
                if (message['reply_to'] != null)
                  _ReplyPreview(replyTo: message['reply_to']),
                if (hasMedia)
                  _MediaRouter(mediaId: message['media_id'], type: message['type'], isMine: isMine),
                if (message['content'] != null)
                  RichText(text: TextSpan(
                    children: _contentSpans(message['content'], isMine ? Colors.white : AppTheme.textMain),
                  )),
                const SizedBox(height: 4),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  if (message['edited_at'] != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text(l10n.chatEdited, style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic,
                          color: isMine ? Colors.white60 : AppTheme.textSub)),
                    ),
                  Text(time, style: TextStyle(fontSize: 10,
                      color: isMine ? Colors.white60 : AppTheme.textSub)),
                  if (isMine) ...[
                    const SizedBox(width: 3),
                    Text(
                      _receiptTick(message['message_status']),
                      style: TextStyle(
                        fontSize: 10,
                        color: _isRead(message['message_status'])
                            ? AppTheme.readTick
                            : Colors.white60,
                      ),
                    ),
                  ],
                ]),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: _ReactionBar(reactions: reactions, myId: myId, onToggle: onToggleReaction),
          ),
        ],
      ),
    );
  }
}

// ── Media router — picks the right widget per type ────────────

class _MediaRouter extends StatelessWidget {
  final String mediaId;
  final String type;
  final bool isMine;
  const _MediaRouter({required this.mediaId, required this.type, required this.isMine});

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case 'image':    return _ImageMessage(mediaId: mediaId);
      case 'audio':    return _AudioMessage(mediaId: mediaId, isMine: isMine);
      case 'video':    return _VideoMessage(mediaId: mediaId);
      case 'document': return _DocumentMessage(mediaId: mediaId, isMine: isMine);
      default:         return _DocumentMessage(mediaId: mediaId, isMine: isMine);
    }
  }
}

// ── Image message ─────────────────────────────────────────────

class _ImageMessage extends StatefulWidget {
  final String mediaId;
  const _ImageMessage({required this.mediaId});
  @override State<_ImageMessage> createState() => _ImageMessageState();
}
class _ImageMessageState extends State<_ImageMessage> {
  String? _url;
  Future<void> _load() async {
    final res = await ApiClient.getMediaUrl(widget.mediaId);
    setState(() => _url = res.data['url']);
  }
  @override
  Widget build(BuildContext context) {
    if (_url != null) {
      return GestureDetector(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(_url!, width: 200, height: 150, fit: BoxFit.cover),
        ),
      );
    }
    return GestureDetector(
      onTap: _load,
      child: Container(
        width: 160, height: 100, color: Colors.black26,
        child: const Center(child: Text('Tap to load', style: TextStyle(color: Colors.white54, fontSize: 12))),
      ),
    );
  }
}

// ── Audio / voice note message ────────────────────────────────

class _AudioMessage extends StatefulWidget {
  final String mediaId;
  final bool isMine;
  const _AudioMessage({required this.mediaId, required this.isMine});
  @override State<_AudioMessage> createState() => _AudioMessageState();
}

class _AudioMessageState extends State<_AudioMessage> {
  final _player = AudioPlayer();
  String? _url;
  bool _fetchingUrl = false;
  bool _playing = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  final _subs = <StreamSubscription>[];

  @override
  void initState() {
    super.initState();
    _subs.add(_player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _playing = s == PlayerState.playing);
    }));
    _subs.add(_player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    }));
    // Duration becomes available as soon as the stream header is read —
    // no need to download the full file first.
    _subs.add(_player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    }));
    _subs.add(_player.onPlayerComplete.listen((_) {
      if (mounted) setState(() { _playing = false; _position = Duration.zero; });
    }));
  }

  @override
  void dispose() {
    for (final s in _subs) s.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlayPause() async {
    // Pause immediately — no network call needed.
    if (_playing) {
      await _player.pause();
      return;
    }

    // Fetch the signed URL once and cache it.
    if (_url == null) {
      setState(() => _fetchingUrl = true);
      try {
        final res = await ApiClient.getMediaUrl(widget.mediaId);
        _url = res.data['url'];
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not load audio: $e')),
          );
        }
        return;
      } finally {
        if (mounted) setState(() => _fetchingUrl = false);
      }
    }

    // UrlSource streams from the remote URL — playback starts as soon as
    // a few seconds of audio have buffered, not after the full download.
    if (mounted) await _player.play(UrlSource(_url!));
  }

  Future<void> _seek(double milliseconds) async {
    await _player.seek(Duration(milliseconds: milliseconds.toInt()));
    // If paused, resume so the seek position is audible immediately.
    if (!_playing && _url != null) await _player.resume();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final subColor  = widget.isMine ? Colors.white60 : AppTheme.textSub;
    final iconColor = widget.isMine ? Colors.white   : AppTheme.primary;
    final trackColor = widget.isMine ? Colors.white  : AppTheme.primary;
    final hasDuration = _duration > Duration.zero;
    final max = _duration.inMilliseconds.toDouble().clamp(1.0, double.infinity);
    final val = _position.inMilliseconds.toDouble().clamp(0.0, max);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        // Play / pause / loading button
        GestureDetector(
          onTap: _fetchingUrl ? null : _togglePlayPause,
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: widget.isMine
                  ? Colors.white24
                  : AppTheme.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: _fetchingUrl
                ? Padding(
                    padding: const EdgeInsets.all(8),
                    child: CircularProgressIndicator(strokeWidth: 2, color: iconColor),
                  )
                : Icon(
                    _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: iconColor,
                    size: 22,
                  ),
          ),
        ),
        const SizedBox(width: 8),

        // Progress track + timestamps
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SliderTheme(
                data: SliderThemeData(
                  trackHeight: 2,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  activeTrackColor: trackColor,
                  inactiveTrackColor: subColor,
                  thumbColor: trackColor,
                  overlayShape: SliderComponentShape.noOverlay,
                ),
                child: Slider(
                  value: val,
                  min: 0,
                  max: max,
                  // Disable scrubbing until the stream header has been read
                  // and we know the actual duration.
                  onChanged: hasDuration ? _seek : null,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Elapsed time — ticks forward while playing
                  Text(_fmt(_position), style: TextStyle(fontSize: 10, color: subColor)),
                  // Total duration — available as soon as stream header is read
                  if (hasDuration)
                    Text(_fmt(_duration), style: TextStyle(fontSize: 10, color: subColor)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        const Icon(Icons.mic_rounded, size: 14, color: AppTheme.textSub),
      ]),
    );
  }
}

// ── Video message ─────────────────────────────────────────────

class _VideoMessage extends StatefulWidget {
  final String mediaId;
  const _VideoMessage({required this.mediaId});
  @override State<_VideoMessage> createState() => _VideoMessageState();
}
class _VideoMessageState extends State<_VideoMessage> {
  String? _url;
  Future<void> _load() async {
    final res = await ApiClient.getMediaUrl(widget.mediaId);
    setState(() => _url = res.data['url']);
  }
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _url == null ? _load : () async {
        if (_url != null) await OpenFilex.open(_url!);
      },
      child: Container(
        width: 160, height: 90, color: Colors.black45,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.play_circle_rounded, color: Colors.white.withValues(alpha: 0.85), size: 40),
          const SizedBox(height: 4),
          Text(_url == null ? 'Tap to load video' : 'Tap to open',
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ]),
      ),
    );
  }
}

// ── Document / file message ───────────────────────────────────

class _DocumentMessage extends StatefulWidget {
  final String mediaId;
  final bool isMine;
  const _DocumentMessage({required this.mediaId, required this.isMine});
  @override State<_DocumentMessage> createState() => _DocumentMessageState();
}

class _DocumentMessageState extends State<_DocumentMessage> {
  String? _url;
  String  _fileName = 'File';
  String  _mimeType = '';
  bool    _loadingMeta    = false;
  bool    _downloading    = false;
  double? _downloadProgress;
  String? _localPath;

  Future<void> _loadMeta() async {
    if (_url != null || _loadingMeta) return;
    setState(() => _loadingMeta = true);
    try {
      final res = await ApiClient.getMediaUrl(widget.mediaId);
      setState(() {
        _url      = res.data['url'];
        _fileName = res.data['file_name'] ?? 'File';
        _mimeType = res.data['mime_type'] ?? '';
      });
    } finally {
      if (mounted) setState(() => _loadingMeta = false);
    }
  }

  Future<void> _download() async {
    if (_url == null) {
      await _loadMeta();
      if (_url == null) return;
    }
    if (_localPath != null) {
      await OpenFilex.open(_localPath!);
      return;
    }
    setState(() { _downloading = true; _downloadProgress = 0; });
    try {
      final dir  = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/$_fileName';
      await dio_pkg.Dio().download(
        _url!,
        path,
        onReceiveProgress: (received, total) {
          if (total > 0 && mounted) {
            setState(() => _downloadProgress = received / total);
          }
        },
      );
      setState(() { _localPath = path; _downloading = false; _downloadProgress = null; });
      await OpenFilex.open(path);
    } catch (_) {
      if (mounted) {
        setState(() { _downloading = false; _downloadProgress = null; });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Download failed')),
        );
      }
    }
  }

  IconData _iconFor(String mime) {
    if (mime.contains('pdf'))        return Icons.picture_as_pdf_rounded;
    if (mime.contains('word') || mime.contains('document')) return Icons.description_rounded;
    if (mime.contains('excel') || mime.contains('spreadsheet') || mime.contains('csv'))
                                     return Icons.table_chart_rounded;
    if (mime.contains('powerpoint') || mime.contains('presentation'))
                                     return Icons.slideshow_rounded;
    if (mime.contains('image'))      return Icons.image_rounded;
    if (mime.contains('audio'))      return Icons.audiotrack_rounded;
    if (mime.contains('video'))      return Icons.videocam_rounded;
    if (mime.contains('zip') || mime.contains('rar') || mime.contains('7z') || mime.contains('tar'))
                                     return Icons.folder_zip_rounded;
    if (mime.contains('apk'))        return Icons.android_rounded;
    return Icons.insert_drive_file_rounded;
  }

  @override
  void initState() {
    super.initState();
    _loadMeta();
  }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isMine ? Colors.white : AppTheme.textMain;
    final subColor  = widget.isMine ? Colors.white60 : AppTheme.textSub;
    final iconBg    = widget.isMine
        ? Colors.white.withValues(alpha: 0.15)
        : AppTheme.primary.withValues(alpha: 0.12);
    final iconColor = widget.isMine ? Colors.white : AppTheme.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(8)),
              child: _loadingMeta
                  ? Padding(
                      padding: const EdgeInsets.all(10),
                      child: CircularProgressIndicator(strokeWidth: 2, color: iconColor),
                    )
                  : Icon(_iconFor(_mimeType), color: iconColor, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _fileName,
                    style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w500),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_mimeType.isNotEmpty)
                    Text(_mimeType.split('/').last.toUpperCase(),
                        style: TextStyle(color: subColor, fontSize: 10)),
                ],
              ),
            ),
          ]),

          // Download progress
          if (_downloading && _downloadProgress != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _downloadProgress,
                  backgroundColor: subColor.withValues(alpha: 0.3),
                  color: widget.isMine ? Colors.white : AppTheme.primary,
                  minHeight: 3,
                ),
              ),
            ),

          // Action buttons
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(children: [
              // Download / Open button
              GestureDetector(
                onTap: _downloading ? null : _download,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: widget.isMine
                        ? Colors.white.withValues(alpha: 0.2)
                        : AppTheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: widget.isMine ? Colors.white38 : AppTheme.primary.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(
                      _localPath != null ? Icons.open_in_new_rounded : Icons.download_rounded,
                      size: 14,
                      color: iconColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _localPath != null ? 'Open' : (_downloading ? 'Downloading...' : 'Download'),
                      style: TextStyle(color: iconColor, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ]),
                ),
              ),

              // Open in browser (always available once URL is loaded)
              if (_url != null && _localPath == null) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () async {
                    if (_url != null) await OpenFilex.open(_url!);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: subColor.withValues(alpha: 0.4)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.visibility_rounded, size: 14, color: subColor),
                      const SizedBox(width: 4),
                      Text('Preview', style: TextStyle(color: subColor, fontSize: 12)),
                    ]),
                  ),
                ),
              ],
            ]),
          ),
        ],
      ),
    );
  }
}
