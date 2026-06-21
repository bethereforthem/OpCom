import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
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
      SocketService.emit('edit_message', {'message_id': _editingMessage!['id'], 'content': text});
      setState(() => _editingMessage = null);
      _textCtrl.clear();
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
    final uploadFailedText = AppLocalizations.of(context)!.chatUploadFailed;
    final result = await FilePicker.platform.pickFiles(withData: false, withReadStream: false);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path == null) return;

    setState(() => _uploading = true);
    try {
      final mime = file.extension != null ? _mimeFromExt(file.extension!) : 'application/octet-stream';
      final res  = await ApiClient.uploadMedia(file.path!, mime);
      final mediaId = res.data['media_id'];
      final type = mime.startsWith('image/') ? 'image'
                 : mime.startsWith('audio/') ? 'audio'
                 : mime.startsWith('video/') ? 'video' : 'document';
      SocketService.emit('send_message', {
        'conversation_id': _convId,
        'type': type,
        'media_id': mediaId,
        'reply_to_id': _replyTarget?['id'],
      });
      setState(() => _replyTarget = null);
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(uploadFailedText)));
    } finally {
      setState(() => _uploading = false);
    }
  }

  void _startReply(Map<String, dynamic> message) {
    setState(() {
      _editingMessage = null;
      _replyTarget = message;
    });
  }

  void _startEdit(Map<String, dynamic> message) {
    setState(() {
      _replyTarget = null;
      _editingMessage = message;
      _textCtrl.text = message['content'] ?? '';
    });
  }

  void _cancelComposerExtra() {
    setState(() {
      _replyTarget = null;
      _editingMessage = null;
      _textCtrl.clear();
    });
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
      SocketService.emit('delete_message', {'message_id': message['id']});
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

  String _mimeFromExt(String ext) {
    const map = {
      'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'png': 'image/png',
      'gif': 'image/gif',  'webp': 'image/webp',
      'mp3': 'audio/mpeg', 'ogg': 'audio/ogg', 'wav': 'audio/wav',
      'mp4': 'video/mp4',  'webm': 'video/webm',
      'pdf': 'application/pdf', 'doc': 'application/msword',
      'txt': 'text/plain',
    };
    return map[ext.toLowerCase()] ?? 'application/octet-stream';
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
              ? const Center(child: CircularProgressIndicator())
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
          const LinearProgressIndicator(backgroundColor: AppTheme.border, color: AppTheme.cta),

        if (_replyTarget != null || _editingMessage != null)
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

        if (_mentionCandidates.isNotEmpty)
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

        if (_scheduledMessages.isNotEmpty)
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
                        child: Text(l10n.commonCancel, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                      ),
                    )),
            ]),
          ),

        // Input bar
        Container(
          color: AppTheme.surface,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: SafeArea(
            top: false,
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.attach_file_rounded, color: AppTheme.textSub),
                onPressed: _uploading ? null : _attachFile,
              ),
              IconButton(
                icon: const Icon(Icons.schedule_rounded, color: AppTheme.textSub),
                tooltip: l10n.chatScheduleMessage,
                onPressed: _scheduleMessage,
              ),
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
              IconButton(
                icon: const Icon(Icons.send_rounded, color: Colors.black87),
                style: IconButton.styleFrom(backgroundColor: AppTheme.cta, shape: const CircleBorder()),
                onPressed: _sendText,
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

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

  List<TextSpan> _contentSpans(String content, Color baseColor) {
    // On "mine" bubbles the background is AppTheme.primary itself, so that
    // color would be invisible there — use underline+bold on white instead.
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

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
            decoration: BoxDecoration(
              color: isMine ? AppTheme.primary : AppTheme.surface,
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
                if (message['forwarded_from'] != null) _ForwardedLabel(forwardedFrom: message['forwarded_from']),
                if (message['reply_to'] != null) _ReplyPreview(replyTo: message['reply_to']),
                if (message['type'] != 'text' && message['media_id'] != null)
                  _MediaPreview(mediaId: message['media_id'], type: message['type']),
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
                    Text(_receiptTick(message['message_status']),
                        style: const TextStyle(fontSize: 10, color: Colors.white60)),
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

class _MediaPreview extends StatefulWidget {
  final String mediaId;
  final String type;
  const _MediaPreview({required this.mediaId, required this.type});
  @override State<_MediaPreview> createState() => _MediaPreviewState();
}

class _MediaPreviewState extends State<_MediaPreview> {
  String? _url;

  Future<void> _load() async {
    final res = await ApiClient.getMediaUrl(widget.mediaId);
    setState(() => _url = res.data['url']);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (widget.type == 'image') {
      return GestureDetector(
        onTap: _url == null ? _load : null,
        child: _url != null
            ? ClipRRect(borderRadius: BorderRadius.circular(8),
                child: Image.network(_url!, width: 200, height: 150, fit: BoxFit.cover))
            : Container(width: 160, height: 100, color: Colors.black26,
                child: Center(child: Text(l10n.chatTapToLoad, style: const TextStyle(color: Colors.white54, fontSize: 12)))),
      );
    }
    return GestureDetector(
      onTap: _load,
      child: Row(children: [
        Icon(_iconFor(widget.type), color: Colors.white70, size: 20),
        const SizedBox(width: 8),
        Text(_labelFor(widget.type, l10n), style: const TextStyle(color: Colors.white70, fontSize: 13)),
      ]),
    );
  }

  IconData _iconFor(String t) => switch (t) {
    'audio'    => Icons.audiotrack_rounded,
    'video'    => Icons.play_circle_rounded,
    'document' => Icons.insert_drive_file_rounded,
    _          => Icons.attach_file_rounded,
  };

  String _labelFor(String t, AppLocalizations l10n) => switch (t) {
    'audio'    => l10n.chatAudioMessage,
    'video'    => l10n.chatVideoType,
    'document' => l10n.chatDocumentType,
    _          => l10n.chatFileType,
  };
}
