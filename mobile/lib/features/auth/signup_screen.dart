import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import '../../core/api/api_client.dart';
import '../../core/locale/locale_provider.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/language_picker.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});
  @override State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _fullNameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _staffIdCtrl  = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _loading = false;
  bool _done    = false;
  String? _error;

  Future<void> _submit() async {
    setState(() { _loading = true; _error = null; });
    final fallbackMsg = AppLocalizations.of(context)!.authSignupFailed;
    try {
      final locale = context.read<LocaleProvider>().locale.languageCode;
      await ApiClient.signup({
        'full_name': _fullNameCtrl.text.trim(),
        'username':  _usernameCtrl.text.trim(),
        if (_emailCtrl.text.trim().isNotEmpty)   'email': _emailCtrl.text.trim(),
        if (_staffIdCtrl.text.trim().isNotEmpty) 'staff_id': _staffIdCtrl.text.trim(),
        'password':  _passwordCtrl.text,
        'locale': locale,
      });
      setState(() => _done = true);
    } catch (e) {
      String msg = fallbackMsg;
      if (e is DioException && e.response?.data is Map) {
        msg = (e.response!.data as Map)['error']?.toString() ?? msg;
      }
      setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _staffIdCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_done) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(color: AppTheme.success, borderRadius: BorderRadius.circular(20)),
                    child: const Icon(Icons.check_rounded, color: Colors.white, size: 36),
                  ),
                  const SizedBox(height: 20),
                  Text(l10n.authSignupDoneTitle, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
                  const SizedBox(height: 8),
                  Text(l10n.authSignupDoneMessage,
                      textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textSub, fontSize: 13)),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l10n.authSignupBackToSignIn, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.authSignupTitle), actions: const [LanguagePicker(), SizedBox(width: 8)]),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    gradient: AppTheme.brandGradient,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: AppTheme.heroGlow,
                  ),
                  child: const Icon(Icons.person_add_rounded, color: Colors.white, size: 30),
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _fullNameCtrl,
                style: const TextStyle(color: AppTheme.textMain),
                decoration: InputDecoration(labelText: l10n.authSignupFullNameLabel),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _usernameCtrl,
                style: const TextStyle(color: AppTheme.textMain),
                decoration: InputDecoration(labelText: l10n.authSignupUsernameLabel),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(
                  controller: _emailCtrl,
                  style: const TextStyle(color: AppTheme.textMain),
                  decoration: InputDecoration(labelText: l10n.authSignupEmailOptionalLabel),
                  keyboardType: TextInputType.emailAddress,
                )),
                const SizedBox(width: 12),
                Expanded(child: TextField(
                  controller: _staffIdCtrl,
                  style: const TextStyle(color: AppTheme.textMain),
                  decoration: InputDecoration(labelText: l10n.authSignupStaffIdOptionalLabel),
                )),
              ]),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordCtrl,
                style: const TextStyle(color: AppTheme.textMain),
                decoration: InputDecoration(labelText: l10n.authSignupPasswordLabel),
                obscureText: true,
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 16),
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.danger.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.danger.withOpacity(0.4)),
                  ),
                  child: Text(_error!, style: const TextStyle(color: Color(0xFFF87171), fontSize: 13)),
                ),
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(l10n.authSignupCreate, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
