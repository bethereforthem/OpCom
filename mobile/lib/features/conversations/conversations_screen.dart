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
import '../people/people_tab.dart';
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
  int _bottomNavIndex = 0;
  String _filterMode = 'all'; // 'all', 'unread', 'groups'

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
        updated['last_message'] = msg;
        _conversations.removeAt(idx);
        _conversations.insert(0, updated);
        return;
      }
      final archivedIdx = _archivedConversations.indexWhere((c) => c['id'] == msg['conversation_id']);
      if (archivedIdx != -1) {
        final reactivated = Map<String, dynamic>.from(_archivedConversations[archivedIdx]);
        reactivated['updated_at'] = msg['created_at'];
        reactivated['archived_at'] = null;
        reactivated['last_message'] = msg;
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

  String _formatConvTime(String? isoTime) {
    if (isoTime == null) return '';
    final dt = DateTime.parse(isoTime).toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(dt.year, dt.month, dt.day);
    if (msgDay == today) {
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }
    if (today.difference(msgDay).inDays == 1) return 'Yesterday';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  String _lastMessagePreview(Map<String, dynamic> conv, AppLocalizations l10n) {
    final last = conv['last_message'];
    if (last == null) {
      if (conv['type'] == 'group') {
        final count = (conv['conversation_members'] as List?)?.length ?? 0;
        return l10n.convMembersCount(count);
      }
      return '';
    }
    if (last['is_deleted'] == true) return l10n.chatMessageDeleted;
    switch (last['type']) {
      case 'image':    return '📷 ${l10n.chatPhotoType}';
      case 'audio':    return '🎵 ${l10n.chatAudioType}';
      case 'video':    return '🎬 ${l10n.chatVideoType}';
      case 'document': return '📄 ${l10n.chatDocumentType}';
      default:         return last['content'] ?? '';
    }
  }

  List<Map<String, dynamic>> get _filteredConversations {
    switch (_filterMode) {
      case 'unread':
        return _conversations.where((c) => (c['unread_count'] ?? 0) > 0).toList();
      case 'groups':
        return _conversations.where((c) => c['type'] == 'group').toList();
      default:
        return _conversations;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final myId = context.read<AuthProvider>().user?['id'];

    Widget body;
    switch (_bottomNavIndex) {
      case 1:
        body = const NotificationsPlaceholder();
        break;
      case 2:
        body = PeopleTab(myId: myId ?? '');
        break;
      case 3:
        body = CallHistoryPlaceholder(myId: myId);
        break;
      default:
        body = _buildChatsTab(l10n, myId);
    }

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: Text(
          l10n.convTitle,
          style: const TextStyle(
            color: AppTheme.textMain,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt_outlined, color: AppTheme.textMain),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.search_rounded, color: AppTheme.textMain),
            onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => SearchScreen(myId: myId ?? ''),
            )),
          ),
          IconButton(
            icon: Badge(
              label: Text('$_unreadNotifications'),
              isLabelVisible: _unreadNotifications > 0,
              backgroundColor: AppTheme.primary,
              child: const Icon(Icons.more_vert_rounded, color: AppTheme.textMain),
            ),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
              _loadUnreadCount();
            },
          ),
        ],
      ),
      body: body,
      floatingActionButton: _bottomNavIndex == 0
          ? FloatingActionButton(
              onPressed: () => _showNewConvDialog(context, myId),
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              tooltip: l10n.convNewConversationTooltip,
              child: const Icon(Icons.edit_rounded),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _bottomNavIndex,
        onTap: (i) {
          if (i == 3) {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => CallHistoryScreen(myId: myId),
            ));
            return;
          }
          setState(() => _bottomNavIndex = i);
        },
        backgroundColor: AppTheme.surface,
        selectedItemColor: AppTheme.primary,
        unselectedItemColor: AppTheme.textSub,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_rounded), label: 'Chats'),
          BottomNavigationBarItem(icon: Icon(Icons.circle_notifications_rounded), label: 'Updates'),
          BottomNavigationBarItem(icon: Icon(Icons.people_alt_rounded), label: 'Communities'),
          BottomNavigationBarItem(icon: Icon(Icons.call_rounded), label: 'Calls'),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = [
      ('all', 'All'),
      ('unread', 'Unread'),
      ('groups', 'Groups'),
    ];
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: filters.map((f) {
          final selected = _filterMode == f.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _filterMode = f.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: selected ? AppTheme.primary.withValues(alpha: 0.2) : AppTheme.surfaceAlt,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected ? AppTheme.primary : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Text(
                  f.$2,
                  style: TextStyle(
                    color: selected ? AppTheme.primary : AppTheme.textSub,
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildChatsTab(AppLocalizations l10n, String? myId) {
    return Column(
      children: [
        _buildFilterChips(),
        const Divider(height: 1, color: AppTheme.border),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
              : (_filteredConversations.isEmpty && _archivedConversations.isEmpty)
                  ? Center(
                      child: Text(
                        l10n.convEmpty,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppTheme.textSub),
                      ),
                    )
                  : RefreshIndicator(
                      color: AppTheme.primary,
                      onRefresh: _load,
                      child: ListView(
                        children: [
                          if (_archivedConversations.isNotEmpty)
                            _buildArchivedRow(l10n, myId),
                          ..._filteredConversations.map((c) => _buildConvTile(c, myId, isArchived: false)),
                        ],
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildArchivedRow(AppLocalizations l10n, String? myId) {
    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _showArchived = !_showArchived),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceAlt,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.archive_rounded, color: AppTheme.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.convArchivedCount(_archivedConversations.length),
                    style: const TextStyle(color: AppTheme.textMain, fontWeight: FontWeight.w500, fontSize: 16),
                  ),
                ),
                Icon(
                  _showArchived ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  color: AppTheme.textSub,
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1, color: AppTheme.border, indent: 72),
        if (_showArchived)
          ..._archivedConversations.map((c) => _buildConvTile(c, myId, isArchived: true)),
      ],
    );
  }

  Widget _buildConvTile(Map<String, dynamic> conv, String? myId, {required bool isArchived}) {
    final l10n = AppLocalizations.of(context)!;
    final name = _displayName(conv, myId);
    final muted = _isEffectivelyMuted(conv);
    final time = _formatConvTime(conv['updated_at']);
    final preview = _lastMessagePreview(conv, l10n);
    final unreadCount = (conv['unread_count'] ?? 0) as int;

    return Column(
      children: [
        InkWell(
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Avatar(name: name, imageUrl: _avatarUrl(conv, myId), size: 50),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(
                                color: AppTheme.textMain,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (time.isNotEmpty)
                            Text(
                              time,
                              style: TextStyle(
                                color: unreadCount > 0 ? AppTheme.primary : AppTheme.textSub,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                if (muted)
                                  const Padding(
                                    padding: EdgeInsets.only(right: 4),
                                    child: Icon(Icons.volume_off_rounded, size: 14, color: AppTheme.textSub),
                                  ),
                                Expanded(
                                  child: Text(
                                    preview,
                                    style: const TextStyle(color: AppTheme.textSub, fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (unreadCount > 0)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: const BoxDecoration(
                                color: AppTheme.primary,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '$unreadCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1, color: AppTheme.border, indent: 74),
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

// Inline placeholders so bottom nav tabs render without full screen push
class NotificationsPlaceholder extends StatelessWidget {
  const NotificationsPlaceholder({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle_notifications_outlined, size: 64, color: AppTheme.textSub),
          SizedBox(height: 12),
          Text('Updates', style: TextStyle(color: AppTheme.textSub, fontSize: 16)),
        ],
      ),
    );
  }
}

class CallHistoryPlaceholder extends StatelessWidget {
  final String? myId;
  const CallHistoryPlaceholder({super.key, this.myId});
  @override
  Widget build(BuildContext context) {
    return CallHistoryScreen(myId: myId);
  }
}
