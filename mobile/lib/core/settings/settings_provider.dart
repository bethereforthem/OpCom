import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_client.dart';

const _kThemePreference = 'theme_preference';
const _kNotifSoundEnabled = 'notif_sound_enabled';
const _kNotifVibrateEnabled = 'notif_vibrate_enabled';
const _kPrivacyReadReceipts = 'privacy_read_receipts';
const _kPrivacyShowTyping = 'privacy_show_typing';
const _kChatAutoDownloadMedia = 'chat_auto_download_media';
const _kChatMessageTextScale = 'chat_message_text_scale';

// Mirrors LocaleProvider's role but for the rest of the per-user
// preferences: instant local restore on launch (so the UI never flashes
// defaults), then reconciled with the server record once it loads (the
// database is the cross-device source of truth), then optimistic
// local-write + background-sync on every change.
class SettingsProvider extends ChangeNotifier {
  String themePreference = 'dark';
  bool notifSoundEnabled = true;
  bool notifVibrateEnabled = true;
  bool privacyReadReceipts = true;
  bool privacyShowTyping = true;
  bool chatAutoDownloadMedia = false;
  String chatMessageTextScale = 'medium';

  double get messageTextScaleFactor => switch (chatMessageTextScale) {
    'small' => 0.85,
    'large' => 1.2,
    _ => 1.0,
  };

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    themePreference = prefs.getString(_kThemePreference) ?? themePreference;
    notifSoundEnabled = prefs.getBool(_kNotifSoundEnabled) ?? notifSoundEnabled;
    notifVibrateEnabled = prefs.getBool(_kNotifVibrateEnabled) ?? notifVibrateEnabled;
    privacyReadReceipts = prefs.getBool(_kPrivacyReadReceipts) ?? privacyReadReceipts;
    privacyShowTyping = prefs.getBool(_kPrivacyShowTyping) ?? privacyShowTyping;
    chatAutoDownloadMedia = prefs.getBool(_kChatAutoDownloadMedia) ?? chatAutoDownloadMedia;
    chatMessageTextScale = prefs.getString(_kChatMessageTextScale) ?? chatMessageTextScale;
    notifyListeners();
  }

  void hydrateFromUser(Map<String, dynamic>? user) {
    if (user == null) return;
    themePreference = user[_kThemePreference] as String? ?? themePreference;
    notifSoundEnabled = user[_kNotifSoundEnabled] as bool? ?? notifSoundEnabled;
    notifVibrateEnabled = user[_kNotifVibrateEnabled] as bool? ?? notifVibrateEnabled;
    privacyReadReceipts = user[_kPrivacyReadReceipts] as bool? ?? privacyReadReceipts;
    privacyShowTyping = user[_kPrivacyShowTyping] as bool? ?? privacyShowTyping;
    chatAutoDownloadMedia = user[_kChatAutoDownloadMedia] as bool? ?? chatAutoDownloadMedia;
    chatMessageTextScale = user[_kChatMessageTextScale] as String? ?? chatMessageTextScale;
    _persistLocally();
    notifyListeners();
  }

  // Optimistic: apply locally + cache immediately, sync to the backend in
  // the background. If the request fails the local value still stands —
  // the next login's hydrateFromUser reconciles with the server.
  Future<void> update(Map<String, dynamic> patch) async {
    patch.forEach((key, value) {
      switch (key) {
        case _kThemePreference: themePreference = value as String; break;
        case _kNotifSoundEnabled: notifSoundEnabled = value as bool; break;
        case _kNotifVibrateEnabled: notifVibrateEnabled = value as bool; break;
        case _kPrivacyReadReceipts: privacyReadReceipts = value as bool; break;
        case _kPrivacyShowTyping: privacyShowTyping = value as bool; break;
        case _kChatAutoDownloadMedia: chatAutoDownloadMedia = value as bool; break;
        case _kChatMessageTextScale: chatMessageTextScale = value as String; break;
      }
    });
    notifyListeners();
    await _persistLocally();
    try {
      await ApiClient.updateSettings(patch);
    } catch (_) {
      // Local state already reflects the change — fine to retry later.
    }
  }

  Future<void> _persistLocally() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemePreference, themePreference);
    await prefs.setBool(_kNotifSoundEnabled, notifSoundEnabled);
    await prefs.setBool(_kNotifVibrateEnabled, notifVibrateEnabled);
    await prefs.setBool(_kPrivacyReadReceipts, privacyReadReceipts);
    await prefs.setBool(_kPrivacyShowTyping, privacyShowTyping);
    await prefs.setBool(_kChatAutoDownloadMedia, chatAutoDownloadMedia);
    await prefs.setString(_kChatMessageTextScale, chatMessageTextScale);
  }
}
