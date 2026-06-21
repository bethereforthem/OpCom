import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// flutter_localizations ships no Material/Cupertino translations for
// Kinyarwanda ('rw') — confirmed via a widget test that selecting it throws
// "this application's locale is not supported by all of its localization
// delegates" in debug builds (a crash, not just missing text). These two
// delegates claim 'rw' support and hand back the English Material/Cupertino
// strings as a fallback for Flutter's own built-in widgets (e.g. the text
// field selection toolbar's Cut/Copy/Paste) — our own AppLocalizations
// delegate is untouched and still renders full Kinyarwanda everywhere else.
class RwMaterialLocalizationsDelegate extends LocalizationsDelegate<MaterialLocalizations> {
  const RwMaterialLocalizationsDelegate();
  @override
  bool isSupported(Locale locale) => locale.languageCode == 'rw';
  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      GlobalMaterialLocalizations.delegate.load(const Locale('en'));
  @override
  bool shouldReload(RwMaterialLocalizationsDelegate old) => false;
}

class RwCupertinoLocalizationsDelegate extends LocalizationsDelegate<CupertinoLocalizations> {
  const RwCupertinoLocalizationsDelegate();
  @override
  bool isSupported(Locale locale) => locale.languageCode == 'rw';
  @override
  Future<CupertinoLocalizations> load(Locale locale) =>
      GlobalCupertinoLocalizations.delegate.load(const Locale('en'));
  @override
  bool shouldReload(RwCupertinoLocalizationsDelegate old) => false;
}
