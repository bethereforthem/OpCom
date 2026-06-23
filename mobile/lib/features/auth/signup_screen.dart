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
  final _fullNameCtrl    = TextEditingController();
  final _usernameCtrl    = TextEditingController();
  final _emailCtrl       = TextEditingController();
  final _phoneCtrl       = TextEditingController();
  final _staffIdCtrl     = TextEditingController();
  final _passwordCtrl    = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  bool _loading        = false;
  bool _done           = false;
  bool _showPassword   = false;
  String? _error;

  Future<void> _submit() async {
    // Client-side validation
    if (_fullNameCtrl.text.trim().isEmpty ||
        _usernameCtrl.text.trim().isEmpty ||
        _passwordCtrl.text.isEmpty) {
      setState(() => _error = 'Full name, username and password are required.');
      return;
    }
    if (_passwordCtrl.text != _confirmPassCtrl.text) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    if (_passwordCtrl.text.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters.');
      return;
    }

    setState(() { _loading = true; _error = null; });
    final fallbackMsg = AppLocalizations.of(context)!.authSignupFailed;
    try {
      final locale = context.read<LocaleProvider>().locale.languageCode;
      await ApiClient.signup({
        'full_name': _fullNameCtrl.text.trim(),
        'username':  _usernameCtrl.text.trim(),
        if (_emailCtrl.text.trim().isNotEmpty)   'email':        _emailCtrl.text.trim(),
        if (_phoneCtrl.text.trim().isNotEmpty)   'phone_number': _phoneCtrl.text.trim(),
        if (_staffIdCtrl.text.trim().isNotEmpty) 'staff_id':     _staffIdCtrl.text.trim(),
        'password': _passwordCtrl.text,
        'locale':   locale,
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
    _phoneCtrl.dispose();
    _staffIdCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPassCtrl.dispose();
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
                    decoration: BoxDecoration(
                      color: AppTheme.success,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.check_rounded, color: Colors.white, size: 36),
                  ),
                  const SizedBox(height: 20),
                  Text(l10n.authSignupDoneTitle,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
                  const SizedBox(height: 8),
                  Text(l10n.authSignupDoneMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.textSub, fontSize: 13)),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l10n.authSignupBackToSignIn,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.authSignupTitle),
        actions: const [LanguagePicker(), SizedBox(width: 8)],
      ),
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

              // ── Full Name ──────────────────────────────────────
              TextField(
                controller: _fullNameCtrl,
                style: const TextStyle(color: AppTheme.textMain),
                decoration: InputDecoration(
                  labelText: l10n.authSignupFullNameLabel,
                  prefixIcon: const Icon(Icons.person_outline_rounded, color: AppTheme.textSub),
                ),
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),

              // ── Username ───────────────────────────────────────
              TextField(
                controller: _usernameCtrl,
                style: const TextStyle(color: AppTheme.textMain),
                decoration: InputDecoration(
                  labelText: l10n.authSignupUsernameLabel,
                  prefixIcon: const Icon(Icons.alternate_email_rounded, color: AppTheme.textSub),
                ),
                textInputAction: TextInputAction.next,
                keyboardType: TextInputType.name,
              ),
              const SizedBox(height: 12),

              // ── Email ──────────────────────────────────────────
              TextField(
                controller: _emailCtrl,
                style: const TextStyle(color: AppTheme.textMain),
                decoration: InputDecoration(
                  labelText: l10n.authSignupEmailOptionalLabel,
                  prefixIcon: const Icon(Icons.email_outlined, color: AppTheme.textSub),
                ),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),

              // ── Phone Number ───────────────────────────────────
              TextField(
                controller: _phoneCtrl,
                style: const TextStyle(color: AppTheme.textMain),
                decoration: const InputDecoration(
                  labelText: 'Phone Number (optional)',
                  prefixIcon: Icon(Icons.phone_outlined, color: AppTheme.textSub),
                  hintText: '+250 7XX XXX XXX',
                ),
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),

              // ── Staff ID (optional) ────────────────────────────
              TextField(
                controller: _staffIdCtrl,
                style: const TextStyle(color: AppTheme.textMain),
                decoration: InputDecoration(
                  labelText: l10n.authSignupStaffIdOptionalLabel,
                  prefixIcon: const Icon(Icons.badge_outlined, color: AppTheme.textSub),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),

              // ── Password ───────────────────────────────────────
              TextField(
                controller: _passwordCtrl,
                style: const TextStyle(color: AppTheme.textMain),
                decoration: InputDecoration(
                  labelText: l10n.authSignupPasswordLabel,
                  prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppTheme.textSub),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                      color: AppTheme.textSub,
                    ),
                    onPressed: () => setState(() => _showPassword = !_showPassword),
                  ),
                ),
                obscureText: !_showPassword,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),

              // ── Confirm Password ───────────────────────────────
              TextField(
                controller: _confirmPassCtrl,
                style: const TextStyle(color: AppTheme.textMain),
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppTheme.textSub),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                      color: AppTheme.textSub,
                    ),
                    onPressed: () => setState(() => _showPassword = !_showPassword),
                  ),
                ),
                obscureText: !_showPassword,
                onSubmitted: (_) => _submit(),
              ),

              const SizedBox(height: 16),

              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.danger.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.danger.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Color(0xFFF87171), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_error!,
                            style: const TextStyle(color: Color(0xFFF87171), fontSize: 13)),
                      ),
                    ],
                  ),
                ),

              ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(l10n.authSignupCreate,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
