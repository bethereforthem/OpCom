import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opcom_mobile/core/locale/rw_fallback_localizations.dart';

// Regression test: flutter_localizations has no built-in Material/Cupertino
// translations for Kinyarwanda, which throws "this application's locale is
// not supported by all of its localization delegates" in debug builds
// whenever the app locale resolves to 'rw'. RwMaterialLocalizationsDelegate
// and RwCupertinoLocalizationsDelegate (wired into main.dart) fix this by
// reporting 'rw' as supported and falling back to English for Flutter's own
// strings. This guards against the fix being dropped in a future refactor
// or a Flutter SDK upgrade changing the underlying behavior.
void main() {
  for (final code in ['en', 'fr', 'rw']) {
    testWidgets('Material/Cupertino localizations load for $code', (tester) async {
      await tester.pumpWidget(MaterialApp(
        locale: Locale(code),
        supportedLocales: const [Locale('en'), Locale('fr'), Locale('rw')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          RwMaterialLocalizationsDelegate(),
          RwCupertinoLocalizationsDelegate(),
        ],
        home: const Scaffold(body: Text('probe')),
      ));
      await tester.pumpAndSettle();
    });
  }
}
