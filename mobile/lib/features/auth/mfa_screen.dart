import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api/api_client.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/theme/app_theme.dart';
import 'auth_provider.dart';

class MfaScreen extends StatefulWidget {
  final String preAuthToken;
  final String mfaMethod;
  const MfaScreen({super.key, required this.preAuthToken, required this.mfaMethod});
  @override State<MfaScreen> createState() => _MfaScreenState();
}

class _MfaScreenState extends State<MfaScreen> {
  final _codeCtrl = TextEditingController();
  bool _loading   = false;
  String? _error;

  Future<void> _submit() async {
    if (_codeCtrl.text.trim().length != 6) return;
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiClient.mfaVerify(widget.preAuthToken, _codeCtrl.text.trim());
      if (!mounted) return;
      await context.read<AuthProvider>().completeLogin(res.data['token']);
      Navigator.popUntil(context, (route) => route.isFirst);
    } catch (_) {
      setState(() { _error = AppLocalizations.of(context)!.authMfaInvalidCode; _codeCtrl.clear(); });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isTotp = widget.mfaMethod == 'totp';
    return Scaffold(
      appBar: AppBar(title: Text(l10n.authMfaAppBarTitle)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    gradient: AppTheme.brandGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: AppTheme.heroGlow,
                  ),
                  child: const Icon(Icons.shield_rounded, color: Colors.white, size: 36),
                ),
                const SizedBox(height: 20),
                Text(l10n.authMfaTitle,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
                const SizedBox(height: 8),
                Text(
                  isTotp ? l10n.authMfaTotpInstructions : l10n.authMfaEmailInstructions,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textSub, fontSize: 13),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _codeCtrl,
                  style: const TextStyle(color: AppTheme.textMain, fontSize: 24,
                      letterSpacing: 12, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(labelText: l10n.authMfaCodeLabel),
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 16),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_error!, style: const TextStyle(color: Color(0xFFF87171), fontSize: 13)),
                  ),
                ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(l10n.authMfaVerify, style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
