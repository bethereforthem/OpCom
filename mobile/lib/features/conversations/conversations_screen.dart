import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api/api_client.dart';
import '../../core/socket/socket_service.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/avatar.dart';
import '../auth/auth_provider.dart';
import '../calls/call_history_screen.dart';
import '../chat/chat_screen.dart';
import '../notifications/notifications_screen.dart';
import '../profile/profile_settings_screen.dart';
import '../search/search_screen.dart';
import 'conversation_actions_sheet.dart';

bool _isEffectivelyMuted(Map<String, dynamic> conv) {
  if (conv['is_muted'] != true) return false;
  final until = conv['muted_until'];
  if (until == null) return true;
  return DateTime.parse(until).isAfter(DateTime.now());
}

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});
  @override State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  List<Map<String, dynamic>> _conversations = [];
  List<Map<String, dynamic>> _archivedConversations = [];
  bool _showArchived = false;
  bool _loading = true;
  int _unreadNotifications = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _loadUnreadCount();
    SocketService.on('new_message', _onNewMessage);
    SocketService.on('mention_received', (_) => _loadUnreadCount());
  }

  @override
  void dispose() {
    SocketService.off('new_message');
    SocketService.off('mention_received');
    super.dispose();
  }

  Future<void> _load() async {
    final res = await ApiClient.getConversations();
    final archivedRes = await ApiClient.getConversations(archived: true);
    setState(() {
      _conversations = List<Map<String, dynamic>>.from(res.data['conversations'] ?? []);
      _archivedConversations = List<Map<String, dynamic>>.from(archivedRes.data['conversations'] ?? []);
      _loading = false;
    });
  }

  Future<void> _archive(Map<String, dynamic> conv) async {
    await ApiClient.archiveConversation(conv['id']);
    setState(() {
      _conversations.removeWhere((c) => c['id'] == conv['id']);
      _archivedConversations.insert(0, {...conv, 'archived_at': DateTime.now().toIso8601String()});
    });
  }

  Future<void> _unarchive(Map<String, dynamic> conv) async {
    await ApiClient.unarchiveConversation(conv['id']);
    setState(() {
      _archivedConversations.removeWhere((c) => c['id'] == conv['id']);
      _conversations.insert(0, {...conv, 'archived_at': null});
    });
  }

  Future<void> _mute(Map<String, dynamic> conv, String duration) async {
    final res = await ApiClient.muteConversation(conv['id'], duration);
    _patchConv(conv['id'], {'is_muted': true, 'muted_until': res.data['muted_until']});
  }

  Future<void> _unmute(Map<String, dynamic> conv) async {
    await ApiClient.unmuteConversation(conv['id']);
    _patchConv(conv['id'], {'is_muted': false, 'muted_until': null});
  }

  void _patchConv(String id, Map<String, dynamic> patch) {
    setState(() {
      _conversations = _conversations.map((c) => c['id'] == id ? {...c, ...patch} : c).toList();
      _archivedConversations = _archivedConversations.map((c) => c['id'] == id ? {...c, ...patch} : c).toList();
    });
  }

  Future<void> _loadUnreadCount() async {
    final res = await ApiClient.getNotifications();
    final notifications = List<Map<String, dynamic>>.from(res.data['notifications'] ?? []);
    if (mounted) setState(() => _unreadNotifications = notifications.where((n) => n['is_read'] != true).length);
  }

  void _onNewMessage(dynamic data) {
    final msg = data as Map<String, dynamic>;
    setState(() {
      final idx = _conversations.indexWhere((c) => c['id'] == msg['conversation_id']);
      if (idx != -1) {
        final updated = Map<String, dynamic>.from(_conversations[idx]);
        updated['updated_at'] = msg['created_at'];
        _conversations.removeAt(idx);
        _conversations.insert(0, updated);
        return;
      }
      // Backend auto-unarchives on new activity for other members — mirror
      // that here by moving the conversation back into the active list.
      final archivedIdx = _archivedConversations.indexWhere((c) => c['id'] == msg['conversation_id']);
      if (archivedIdx != -1) {
        final reactivated = Map<String, dynamic>.from(_archivedConversations[archivedIdx]);
        reactivated['updated_at'] = msg['created_at'];
        reactivated['archived_at'] = null;
        _archivedConversations.removeAt(archivedIdx);
        _conversations.insert(0, reactivated);
      }
    });
  }

  String _displayName(Map<String, dynamic> conv, String? myId) {
    final l10n = AppLocalizations.of(context)!;
    if (conv['type'] == 'group') return conv['name'] ?? l10n.commonGroup;
    final members = conv['conversation_members'] as List? ?? [];
    final other = members.firstWhere(
      (m) => m['users']?['id'] != myId,
      orElse: () => null,
    );
    return other?['users']?['full_name'] ?? l10n.commonUnknown;
  }

  String? _avatarUrl(Map<String, dynamic> conv, String? myId) {
    if (conv['type'] == 'group') return conv['avatar_url'];
    final members = conv['conversation_members'] as List? ?? [];
    final other = members.firstWhere((m) => m['users']?['id'] != myId, orElse: () => null);
    return other?['users']?['avatar_url'];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final myId = context.read<AuthProvider>().user?['id'];
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.convTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => SearchScreen(myId: myId ?? ''),
            )),
          ),
          IconButton(
            icon: const Icon(Icons.call_rounded),
            onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => CallHistoryScreen(myId: myId),
            )),
          ),
          IconButton(
            icon: Badge(
              label: Text('$_unreadNotifications'),
              isLabelVisible: _unreadNotifications > 0,
              child: const Icon(Icons.notifications_rounded),
            ),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
              _loadUnreadCount();
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_rounded),
            onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => const ProfileSettingsScreen(),
            )),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showNewConvDialog(context, myId),
        tooltip: l10n.convNewConversationTooltip,
        child: const Icon(Icons.add_rounded),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_conversations.isEmpty && _archivedConversations.isEmpty)
              ? Center(child: Text(l10n.convEmpty,
                    textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textSub)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    children: [
                      if (_archivedConversations.isNotEmpty)
                        ListTile(
                          title: Text(l10n.convArchivedCount(_archivedConversations.length),
                              style: const TextStyle(color: AppTheme.textSub)),
                          trailing: Icon(_showArchived ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                              color: AppTheme.textSub),
                          onTap: () => setState(() => _showArchived = !_showArchived),
                        ),
                      if (_showArchived)
                        ..._archivedConversations.map((c) => _buildConvTile(c, myId, isArchived: true)),
                      ..._conversations.map((c) => _buildConvTile(c, myId, isArchived: false)),
                    ],
                  ),
                ),
    );
  }

  Widget _buildConvTile(Map<String, dynamic> conv, String? myId, {required bool isArchived}) {
    final l10n = AppLocalizations.of(context)!;
    final name = _displayName(conv, myId);
    final muted = _isEffectivelyMuted(conv);
    return Column(
      children: [
        ListTile(
          leading: Avatar(name: name, imageUrl: _avatarUrl(conv, myId)),
          title: Row(
            children: [
              Expanded(
                child: Text(name,
                    style: const TextStyle(color: AppTheme.textMain, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis),
              ),
              if (muted)
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(Icons.notifications_off_rounded, size: 14, color: AppTheme.textSub),
                ),
            ],
          ),
          subtitle: Text(
            conv['type'] == 'group'
                ? l10n.convMembersCount((conv['conversation_members'] as List?)?.length ?? 0)
                : '',
            style: const TextStyle(color: AppTheme.textSub, fontSize: 12),
          ),
          onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => ChatScreen(conversation: conv, myId: myId ?? ''),
          )),
          onLongPress: () => showConversationActionsSheet(
            context: context,
            isArchived: isArchived,
            isMuted: muted,
            onArchive: () => _archive(conv),
            onUnarchive: () => _unarchive(conv),
            onMute: (duration) => _mute(conv, duration),
            onUnmute: () => _unmute(conv),
          ),
        ),
        const Divider(height: 1, color: AppTheme.border),
      ],
    );
  }

  void _showNewConvDialog(BuildContext ctx, String? myId) {
    final l10n = AppLocalizations.of(ctx)!;
    final ctrl = TextEditingController();
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(l10n.convNewConversationTitle, style: const TextStyle(color: AppTheme.textMain)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: AppTheme.textMain),
          decoration: InputDecoration(labelText: l10n.convRecipientLabel),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel)),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final lookup = await ApiClient.lookupUser(ctrl.text.trim());
                final targetId = lookup.data['user']['id'] as String;
                final res = await ApiClient.createConversation('private', [targetId]);
                final newConv = res.data['conversation'] as Map<String, dynamic>;
                setState(() => _conversations.insert(0, newConv));
                if (!mounted) return;
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ChatScreen(conversation: newConv, myId: myId ?? ''),
                ));
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(AppLocalizations.of(context)!.convCreateFailed)));
              }
            },
            child: Text(l10n.convStart),
          ),
        ],
      ),
    );
  }
}
