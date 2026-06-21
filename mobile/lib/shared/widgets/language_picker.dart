import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api/api_client.dart';
import '../../core/locale/locale_provider.dart';
import '../../features/auth/auth_provider.dart';
import '../theme/app_theme.dart';

// Native-script labels — these never change with the active language, so a
// French speaker viewing the English UI by mistake can still find "Français".
const _kLanguages = [
  ('en', 'English'),
  ('fr', 'Français'),
  ('rw', 'Ikinyarwanda'),
];

class LanguagePicker extends StatelessWidget {
  const LanguagePicker({super.key});

  @override
  Widget build(BuildContext context) {
    final localeProvider = context.watch<LocaleProvider>();
    final isLoggedIn = context.watch<AuthProvider>().isLoggedIn;

    return DropdownButton<String>(
      value: localeProvider.locale.languageCode,
      underline: const SizedBox.shrink(),
      dropdownColor: AppTheme.surface,
      style: const TextStyle(color: AppTheme.textMain, fontSize: 13),
      onChanged: (code) {
        if (code == null) return;
        localeProvider.setLocale(code);
        if (isLoggedIn) {
          // Keep AuthProvider's cached user in sync too — main.dart re-syncs
          // LocaleProvider from auth.user['locale'] on every AuthProvider
          // change (e.g. a later profile/avatar save), so leaving this stale
          // would silently revert the just-picked language on the next
          // unrelated update.
          context.read<AuthProvider>().updateUser({'locale': code});
          ApiClient.setLocale(code).then((_) {}, onError: (_) {});
        }
      },
      items: _kLanguages
          .map((l) => DropdownMenuItem(value: l.$1, child: Text(l.$2)))
          .toList(),
    );
  }
}
