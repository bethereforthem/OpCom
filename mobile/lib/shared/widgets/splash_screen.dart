import 'package:flutter/material.dart';
import '../../l10n/generated/app_localizations.dart';
import '../theme/app_theme.dart';

// Shown while AuthProvider.init() resolves the stored token on app launch.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: SafeArea(
        child: Center(
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
                child: const Icon(Icons.lock_rounded, color: Colors.white, size: 36),
              ),
              const SizedBox(height: 16),
              Text(l10n.appName,
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
              Text(l10n.authLoginTagline,
                  style: const TextStyle(fontSize: 13, color: AppTheme.textSub)),
              const SizedBox(height: 40),
              const SizedBox(
                width: 28, height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: AppTheme.cta),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
