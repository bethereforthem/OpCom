import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/theme/app_theme.dart';

class ForwardScreen extends StatefulWidget {
  final Map<String, dynamic> message;
  final String myId;
  final Future<void> Function(String messageId, List<String> conversationIds) onForward;
  const ForwardScreen({super.key, required this.message, required this.myId, required this.onForward});

  @override State<ForwardScreen> createState() => _ForwardScreenState();
}

class _ForwardScreenState extends State<ForwardScreen> {
  List<Map<String, dynamic>> _conversations = [];
  final Set<String> _selected = {};
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await ApiClient.getConversations();
    setState(() {
      _conversations = List<Map<String, dynamic>>.from(res.data['conversations'] ?? []);
      _loading = false;
    });
  }

  String _name(Map<String, dynamic> conv) {
    final l10n = AppLocalizations.of(context)!;
    if (conv['type'] == 'group') return conv['name'] ?? l10n.commonGroup;
    final members = conv['conversation_members'] as List? ?? [];
    final other = members.firstWhere((m) => m['users']?['id'] != widget.myId, orElse: () => null);
    return other?['users']?['full_name'] ?? l10n.commonUnknown;
  }

  Future<void> _send() async {
    if (_selected.isEmpty) return;
    setState(() => _sending = true);
    try {
      await widget.onForward(widget.message['id'], _selected.toList());
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.forwardFailed)));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.forwardTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _conversations.length,
              itemBuilder: (_, i) {
                final conv = _conversations[i];
                final id = conv['id'] as String;
                final selected = _selected.contains(id);
                return CheckboxListTile(
                  value: selected,
                  onChanged: (_) => setState(() => selected ? _selected.remove(id) : _selected.add(id)),
                  title: Text(_name(conv), style: const TextStyle(color: AppTheme.textMain)),
                  activeColor: AppTheme.primary,
                );
              },
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: ElevatedButton(
            onPressed: _selected.isEmpty || _sending ? null : _send,
            child: Text(_sending
                ? l10n.forwardInProgress
                : '${l10n.chatForward}${_selected.isEmpty ? '' : ' (${_selected.length})'}'),
          ),
        ),
      ),
    );
  }
}
