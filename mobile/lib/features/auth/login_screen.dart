import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import '../../core/api/api_client.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/language_picker.dart';
import 'auth_provider.dart';
import 'mfa_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _identifierCtrl = TextEditingController();
  final _passwordCtrl   = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiClient.login(_identifierCtrl.text.trim(), _passwordCtrl.text);
      final data = res.data as Map<String, dynamic>;

      if (data['mfa_required'] == true) {
        if (!mounted) return;
        Navigator.push(context, MaterialPageRoute(builder: (_) => MfaScreen(
          preAuthToken: data['pre_auth_token'],
          mfaMethod:    data['mfa_method'],
        )));
      } else {
        if (!mounted) return;
        await context.read<AuthProvider>().completeLogin(data['token']);
      }
    } catch (e) {
      setState(() => _error = _parseError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _parseError(dynamic e) {
    final fallback = AppLocalizations.of(context)!.authLoginFailed;
    if (e is DioException && e.response?.data is Map) {
      return (e.response!.data as Map)['error']?.toString() ?? fallback;
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Align(alignment: Alignment.topRight, child: LanguagePicker()),
                // Logo
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    gradient: AppTheme.brandGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: AppTheme.heroGlow,
                  ),
                  child: const Icon(Icons.lock_rounded, color: Colors.white, size: 36),
                ),
                const SizedBox(height: 16),
                Text(l10n.appName, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
                Text(l10n.authLoginTagline,
                    style: const TextStyle(fontSize: 13, color: AppTheme.textSub)),
                const SizedBox(height: 40),

                // Fields
                TextField(
                  controller: _identifierCtrl,
                  style: const TextStyle(color: AppTheme.textMain),
                  decoration: InputDecoration(labelText: l10n.authLoginIdentifierLabel),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordCtrl,
                  style: const TextStyle(color: AppTheme.textMain),
                  decoration: InputDecoration(labelText: l10n.authLoginPasswordLabel),
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
                      : Text(l10n.authLoginSignIn, style: const TextStyle(fontWeight: FontWeight.bold)),
                ),

                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignUpScreen())),
                  child: Text(l10n.authLoginNeedAccountSignUp, style: const TextStyle(color: AppTheme.primary, fontSize: 13)),
                ),
                const SizedBox(height: 8),
                Text(l10n.authLoginRestricted,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF4B5563))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
