import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/avatar.dart';
import '../chat/chat_screen.dart';

// "People" column of the home screen — a browsable directory of org
// members, mirroring WhatsApp/Telegram's contacts list. Tapping someone
// opens an existing private conversation or creates one (the backend
// dedupes), so users don't need to know a username up front.
class PeopleTab extends StatefulWidget {
  final String myId;
  const PeopleTab({super.key, required this.myId});
  @override State<PeopleTab> createState() => _PeopleTabState();
}

class _PeopleTabState extends State<PeopleTab> {
  List<Map<String, dynamic>> _people = [];
  bool _loading = true;
  String _query = '';
  String? _startingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await ApiClient.getUsers();
    if (!mounted) return;
    setState(() {
      _people = List<Map<String, dynamic>>.from(res.data['users'] ?? []);
      _loading = false;
    });
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _people;
    return _people.where((p) {
      final name = (p['full_name'] ?? '').toString().toLowerCase();
      final username = (p['username'] ?? '').toString().toLowerCase();
      return name.contains(q) || username.contains(q);
    }).toList();
  }

  Future<void> _startConversation(Map<String, dynamic> person) async {
    setState(() => _startingId = person['id']);
    try {
      final res = await ApiClient.createConversation('private', [person['id']]);
      final conv = res.data['conversation'] as Map<String, dynamic>;
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(
        builder: (_) => ChatScreen(conversation: conv, myId: widget.myId),
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.convCreateFailed)));
    } finally {
      if (mounted) setState(() => _startingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textSub),
              hintText: l10n.peopleSearchHint,
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _filtered.isEmpty
                  ? Center(
                      child: Text(
                        _people.isEmpty ? l10n.peopleEmpty : l10n.peopleNoResults,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppTheme.textSub),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.border),
                        itemBuilder: (_, i) => _buildPersonTile(_filtered[i], l10n),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildPersonTile(Map<String, dynamic> person, AppLocalizations l10n) {
    final name = person['full_name'] ?? l10n.commonUnknown;
    final status = (person['status_message'] as String?)?.trim();
    final subtitle = (status != null && status.isNotEmpty) ? status : '@${person['username']}';
    final isStarting = _startingId == person['id'];
    return ListTile(
      leading: Avatar(name: name, imageUrl: person['avatar_url']),
      title: Text(name, style: const TextStyle(color: AppTheme.textMain, fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppTheme.textSub, fontSize: 12)),
      trailing: isStarting
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : null,
      onTap: isStarting ? null : () => _startConversation(person),
    );
  }
}
