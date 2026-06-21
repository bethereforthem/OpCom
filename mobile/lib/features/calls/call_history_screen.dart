import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/utils/time.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/avatar.dart';

class CallHistoryScreen extends StatefulWidget {
  final String? myId;
  const CallHistoryScreen({super.key, required this.myId});
  @override State<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends State<CallHistoryScreen> {
  List<Map<String, dynamic>> _calls = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await ApiClient.getCallHistory();
    setState(() {
      _calls = List<Map<String, dynamic>>.from(res.data['calls'] ?? []);
      _loading = false;
    });
  }

  String? _durationLabel(int? seconds) {
    if (seconds == null) return null;
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.callHistoryTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _calls.isEmpty
              ? Center(child: Text(l10n.callHistoryEmpty, style: const TextStyle(color: AppTheme.textSub)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    itemCount: _calls.length,
                    separatorBuilder: (context, index) => const Divider(height: 1, color: AppTheme.border),
                    itemBuilder: (_, i) {
                      final call = _calls[i];
                      final outgoing = call['caller']?['id'] == widget.myId;
                      final other = outgoing ? call['callee'] : call['caller'];
                      final missed = call['status'] == 'missed';
                      final isVideo = call['type'] == 'video';

                      String statusText;
                      switch (call['status']) {
                        case 'missed':
                          statusText = outgoing ? l10n.callHistoryNoAnswer : l10n.callHistoryMissed;
                          break;
                        case 'rejected':
                          statusText = l10n.callHistoryDeclined;
                          break;
                        case 'ended':
                          final dur = _durationLabel(call['duration_seconds'] as int?);
                          statusText = dur != null ? '${l10n.callHistoryAnswered} · $dur' : l10n.callHistoryAnswered;
                          break;
                        case 'failed':
                          statusText = l10n.callHistoryFailed;
                          break;
                        default:
                          statusText = call['status']?.toString() ?? '';
                      }

                      return ListTile(
                        leading: Avatar(name: other?['full_name'] ?? l10n.commonUnknown, imageUrl: other?['avatar_url']),
                        title: Text(other?['full_name'] ?? l10n.commonUnknown,
                            style: const TextStyle(color: AppTheme.textMain)),
                        subtitle: Row(
                          children: [
                            Icon(outgoing ? Icons.call_made_rounded : Icons.call_received_rounded,
                                size: 14, color: missed ? AppTheme.danger : AppTheme.success),
                            const SizedBox(width: 4),
                            Icon(isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                                size: 14, color: AppTheme.textSub),
                            const SizedBox(width: 6),
                            Text(statusText, style: TextStyle(
                                color: missed ? AppTheme.danger : AppTheme.textSub, fontSize: 12)),
                          ],
                        ),
                        trailing: call['started_at'] != null
                            ? Text(formatHm(DateTime.parse(call['started_at']).toLocal()),
                                style: const TextStyle(color: AppTheme.textSub, fontSize: 11))
                            : null,
                      );
                    },
                  ),
                ),
    );
  }
}
