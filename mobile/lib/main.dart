import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/api/api_client.dart';
import 'core/locale/locale_provider.dart';
import 'core/locale/rw_fallback_localizations.dart';
import 'core/settings/settings_provider.dart';
import 'features/auth/auth_provider.dart';
import 'features/auth/login_screen.dart';
import 'features/conversations/conversations_screen.dart';
import 'l10n/generated/app_localizations.dart';
import 'shared/theme/app_theme.dart';
import 'shared/widgets/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiClient.init();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..init()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()..init()),
      ],
      child: const OpComApp(),
    ),
  );
}

class OpComApp extends StatelessWidget {
  const OpComApp({super.key});

  @override
  Widget build(BuildContext context) {
    final localeProvider = context.watch<LocaleProvider>();
    return MaterialApp(
      title: 'OpCom',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      locale: localeProvider.locale,
      localizationsDelegates: const [
        ...AppLocalizations.localizationsDelegates,
        // flutter_localizations has no built-in Material/Cupertino strings
        // for Kinyarwanda — these report 'rw' as supported and fall back to
        // English for Flutter's own widgets, avoiding a debug-mode crash.
        // See core/locale/rw_fallback_localizations.dart.
        RwMaterialLocalizationsDelegate(),
        RwCupertinoLocalizationsDelegate(),
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Consumer<AuthProvider>(
        builder: (_, auth, __) {
          if (auth.loading) {
            return const SplashScreen();
          }
          // Sync the active locale from the logged-in user's stored
          // preference; setLocale no-ops once already in sync.
          if (auth.user != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              context.read<LocaleProvider>().setLocale(auth.user?['locale']);
              context.read<SettingsProvider>().hydrateFromUser(auth.user);
            });
          }
          return auth.isLoggedIn
              ? const ConversationsScreen()
              : const LoginScreen();
        },
      ),
    );
  }
}
