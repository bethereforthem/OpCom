import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/utils/time.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/theme/app_theme.dart';
import '../chat/chat_screen.dart';

class SearchScreen extends StatefulWidget {
  final String myId;
  const SearchScreen({super.key, required this.myId});
  @override State<SearchScreen> createState() => _SearchScreenState();
}

const _mediaTypes = ['', 'text', 'image', 'video', 'audio', 'document'];

class _SearchScreenState extends State<SearchScreen> {
  final _queryCtrl  = TextEditingController();
  final _senderCtrl = TextEditingController();
  String _mediaType = '';
  List<Map<String, dynamic>>? _results;
  bool _loading = false;
  String? _error;

  String _snippet(Map<String, dynamic> m) {
    final l10n = AppLocalizations.of(context)!;
    if (m['type'] == 'text') return m['content'] ?? '';
    return {'image': l10n.chatPhotoType, 'audio': l10n.chatAudioType, 'video': l10n.chatVideoType, 'document': l10n.chatDocumentType}[m['type']] ?? l10n.commonMedia;
  }

  Future<void> _search() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() { _loading = true; _error = null; });
    try {
      String? senderId;
      if (_senderCtrl.text.trim().isNotEmpty) {
        try {
          final lookup = await ApiClient.lookupUser(_senderCtrl.text.trim());
          senderId = lookup.data['user']['id'] as String;
        } catch (_) {
          setState(() { _results = []; _error = l10n.searchNoUserFound(_senderCtrl.text.trim()); _loading = false; });
          return;
        }
      }

      final res = await ApiClient.searchMessages({
        if (_queryCtrl.text.trim().isNotEmpty) 'q': _queryCtrl.text.trim(),
        if (senderId != null) 'sender_id': senderId,
        if (_mediaType.isNotEmpty) 'media_type': _mediaType,
      });
      setState(() => _results = List<Map<String, dynamic>>.from(res.data['messages'] ?? []));
    } catch (_) {
      setState(() => _error = l10n.searchFailed);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _openResult(Map<String, dynamic> m) async {
    final conversationId = m['conversation_id'];
    final res = await ApiClient.getConversations();
    final conversations = List<Map<String, dynamic>>.from(res.data['conversations'] ?? []);
    final conv = conversations.firstWhere((c) => c['id'] == conversationId, orElse: () => {});
    if (conv.isEmpty || !mounted) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ChatScreen(conversation: conv, myId: widget.myId),
    ));
  }

  @override
  void dispose() {
    _queryCtrl.dispose();
    _senderCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.searchTitle)),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            TextField(
              controller: _queryCtrl,
              decoration: InputDecoration(hintText: l10n.searchTextHint),
              onSubmitted: (_) => _search(),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(
                controller: _senderCtrl,
                decoration: InputDecoration(hintText: l10n.searchSenderHint),
              )),
              const SizedBox(width: 8),
              Expanded(child: DropdownButtonFormField<String>(
                initialValue: _mediaType,
                items: _mediaTypes.map((t) => DropdownMenuItem(
                  value: t,
                  child: Text(_mediaTypeLabel(t, l10n), style: const TextStyle(color: AppTheme.textMain)),
                )).toList(),
                onChanged: (v) => setState(() => _mediaType = v ?? ''),
              )),
            ]),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _search,
                child: Text(_loading ? l10n.commonSearching : l10n.commonSearch),
              ),
            ),
          ]),
        ),
        if (_error != null) Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(_error!, style: const TextStyle(color: AppTheme.danger)),
        ),
        Expanded(
          child: _results == null
              ? const SizedBox.shrink()
              : _results!.isEmpty
                  ? Center(child: Text(l10n.searchNoResults, style: const TextStyle(color: AppTheme.textSub)))
                  : ListView.builder(
                      itemCount: _results!.length,
                      itemBuilder: (_, i) {
                        final m = _results![i];
                        return ListTile(
                          title: Text(m['users']?['full_name'] ?? l10n.commonUnknown, style: const TextStyle(color: AppTheme.textMain)),
                          subtitle: Text(_snippet(m), maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppTheme.textSub)),
                          trailing: m['created_at'] != null
                              ? Text(formatHm(DateTime.parse(m['created_at']).toLocal()),
                                  style: const TextStyle(color: AppTheme.textSub, fontSize: 11))
                              : null,
                          onTap: () => _openResult(m),
                        );
                      },
                    ),
        ),
      ]),
    );
  }

  String _mediaTypeLabel(String t, AppLocalizations l10n) => switch (t) {
    ''         => l10n.searchAnyType,
    'text'     => l10n.searchTextType,
    'image'    => l10n.chatPhotoType,
    'video'    => l10n.chatVideoType,
    'audio'    => l10n.chatAudioType,
    'document' => l10n.chatDocumentType,
    _          => t,
  };
}
