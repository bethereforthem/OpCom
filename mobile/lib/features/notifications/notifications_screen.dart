import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/utils/time.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/theme/app_theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await ApiClient.getNotifications();
    setState(() {
      _notifications = List<Map<String, dynamic>>.from(res.data['notifications'] ?? []);
      _loading = false;
    });
  }

  Future<void> _open(Map<String, dynamic> n) async {
    if (n['is_read'] != true) {
      await ApiClient.markNotificationRead(n['id']);
      setState(() => n['is_read'] = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.notifTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? Center(child: Text(l10n.notifEmpty, style: const TextStyle(color: AppTheme.textSub)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    itemCount: _notifications.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.border),
                    itemBuilder: (_, i) {
                      final n = _notifications[i];
                      final isRead = n['is_read'] == true;
                      return ListTile(
                        tileColor: isRead ? null : AppTheme.primary.withValues(alpha: 0.08),
                        title: Text(n['title'] ?? '', style: const TextStyle(color: AppTheme.textMain)),
                        subtitle: Text(n['body'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppTheme.textSub, fontSize: 12)),
                        trailing: n['created_at'] != null
                            ? Text(formatHm(DateTime.parse(n['created_at']).toLocal()),
                                style: const TextStyle(color: AppTheme.textSub, fontSize: 11))
                            : null,
                        onTap: () => _open(n),
                      );
                    },
                  ),
                ),
    );
  }
}
