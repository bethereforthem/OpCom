import 'dart:ui' as ui;
import 'package:flutter/material.dart';

const List<String> kSupportedLocales = ['en', 'fr', 'rw'];

class LocaleProvider extends ChangeNotifier {
  Locale _locale = _detectDefault();
  Locale get locale => _locale;

  static Locale _detectDefault() {
    final deviceCode = ui.PlatformDispatcher.instance.locale.languageCode;
    return Locale(kSupportedLocales.contains(deviceCode) ? deviceCode : 'en');
  }

  void setLocale(String? code) {
    if (code == null || !kSupportedLocales.contains(code)) return;
    if (_locale.languageCode == code) return;
    _locale = Locale(code);
    notifyListeners();
  }
}
