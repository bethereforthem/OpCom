import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api/api_client.dart';
import '../../core/settings/settings_provider.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/avatar.dart';
import '../../shared/widgets/language_picker.dart';
import '../auth/auth_provider.dart';

const Map<String, String> _kImageMimeFromExt = {
  'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'png': 'image/png',
  'gif': 'image/gif', 'webp': 'image/webp',
};

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});
  @override State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  late final TextEditingController _fullNameCtrl;
  late final TextEditingController _usernameCtrl;
  late final TextEditingController _bioCtrl;
  late final TextEditingController _statusCtrl;
  final _currentPwCtrl = TextEditingController();
  final _newPwCtrl = TextEditingController();
  final _confirmPwCtrl = TextEditingController();

  bool _avatarUploading = false;
  bool _profileSaving = false;
  bool _pwSaving = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _fullNameCtrl = TextEditingController(text: user?['full_name'] as String? ?? '');
    _usernameCtrl = TextEditingController(text: user?['username'] as String? ?? '');
    _bioCtrl = TextEditingController(text: user?['bio'] as String? ?? '');
    _statusCtrl = TextEditingController(text: user?['status_message'] as String? ?? '');
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _usernameCtrl.dispose();
    _bioCtrl.dispose();
    _statusCtrl.dispose();
    _currentPwCtrl.dispose();
    _newPwCtrl.dispose();
    _confirmPwCtrl.dispose();
    super.dispose();
  }

  String? _serverError(Object e) {
    if (e is DioException && e.response?.data is Map) {
      return (e.response!.data as Map)['error']?.toString();
    }
    return null;
  }

  Future<void> _pickAvatar() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: false);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path == null) return;

    setState(() => _avatarUploading = true);
    try {
      final mime = _kImageMimeFromExt[file.extension?.toLowerCase()] ?? 'image/jpeg';
      final uploadRes = await ApiClient.uploadMedia(file.path!, mime);
      final avatarRes = await ApiClient.updateAvatar(uploadRes.data['media_id']);
      if (!mounted) return;
      // avatar_url is a deliberately stable path (same string every upload,
      // so it never expires) — but that means NetworkImage's cache key never
      // changes either, so the old photo would keep showing after a re-pick.
      // Appending a cache-busting query param (the backend route ignores its
      // query string) forces Image widgets to fetch fresh.
      final freshUrl = '${avatarRes.data['avatar_url']}?t=${DateTime.now().millisecondsSinceEpoch}';
      context.read<AuthProvider>().updateUser({'avatar_url': freshUrl});
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.profilePhotoUploadFailed)));
    } finally {
      if (mounted) setState(() => _avatarUploading = false);
    }
  }

  Future<void> _saveProfile() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    setState(() => _profileSaving = true);
    try {
      final res = await ApiClient.updateProfile({
        'full_name': _fullNameCtrl.text.trim(),
        'username': _usernameCtrl.text.trim(),
        'bio': _bioCtrl.text.trim(),
        'status_message': _statusCtrl.text.trim(),
      });
      if (!mounted) return;
      context.read<AuthProvider>().updateUser(Map<String, dynamic>.from(res.data['user']));
      messenger.showSnackBar(SnackBar(content: Text(l10n.profileSaved)));
    } catch (e) {
      final serverMsg = _serverError(e);
      final msg = (serverMsg?.contains('already taken') ?? false) ? l10n.profileUsernameTaken : l10n.profileSaveFailed;
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _profileSaving = false);
    }
  }

  Future<void> _changePassword() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    if (_newPwCtrl.text != _confirmPwCtrl.text) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.profilePasswordMismatch)));
      return;
    }
    if (_newPwCtrl.text.length < 8) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.profilePasswordTooShort)));
      return;
    }
    setState(() => _pwSaving = true);
    try {
      await ApiClient.changePassword(_currentPwCtrl.text, _newPwCtrl.text);
      _currentPwCtrl.clear();
      _newPwCtrl.clear();
      _confirmPwCtrl.clear();
      messenger.showSnackBar(SnackBar(content: Text(l10n.profilePasswordChanged)));
    } catch (e) {
      final isWrongCurrent = (e is DioException && e.response?.statusCode == 401);
      messenger.showSnackBar(SnackBar(
          content: Text(isWrongCurrent ? l10n.profilePasswordWrongCurrent : l10n.profilePasswordChangeFailed)));
    } finally {
      if (mounted) setState(() => _pwSaving = false);
    }
  }

  Future<void> _signOut() async {
    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final user = context.watch<AuthProvider>().user;
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionCard(title: l10n.profileTitle, children: [
            Center(
              child: GestureDetector(
                onTap: _avatarUploading ? null : _pickAvatar,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Avatar(name: (user?['full_name'] ?? user?['username'] ?? '?') as String,
                        imageUrl: user?['avatar_url'] as String?, size: 84),
                    if (_avatarUploading)
                      Container(
                        width: 84, height: 84,
                        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                        child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                      ),
                  ],
                ),
              ),
            ),
            Center(
              child: TextButton(
                onPressed: _avatarUploading ? null : _pickAvatar,
                child: Text(l10n.profileChangePhoto),
              ),
            ),
            const SizedBox(height: 8),
            TextField(controller: _fullNameCtrl, decoration: InputDecoration(labelText: l10n.profileFullNameLabel)),
            const SizedBox(height: 12),
            TextField(controller: _usernameCtrl, decoration: InputDecoration(labelText: l10n.profileUsernameLabel)),
            const SizedBox(height: 12),
            TextField(controller: _bioCtrl, maxLines: 2,
                decoration: InputDecoration(labelText: l10n.profileBioLabel, hintText: l10n.profileBioPlaceholder)),
            const SizedBox(height: 12),
            TextField(controller: _statusCtrl,
                decoration: InputDecoration(labelText: l10n.profileStatusLabel, hintText: l10n.profileStatusPlaceholder)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _profileSaving ? null : _saveProfile,
              child: _profileSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black87))
                  : Text(l10n.profileSave),
            ),
          ]),

          const SizedBox(height: 16),
          _SectionCard(title: l10n.profileChangePassword, children: [
            TextField(controller: _currentPwCtrl, obscureText: true,
                decoration: InputDecoration(labelText: l10n.profileCurrentPassword)),
            const SizedBox(height: 12),
            TextField(controller: _newPwCtrl, obscureText: true,
                decoration: InputDecoration(labelText: l10n.profileNewPassword)),
            const SizedBox(height: 12),
            TextField(controller: _confirmPwCtrl, obscureText: true,
                decoration: InputDecoration(labelText: l10n.profileConfirmPassword)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _pwSaving ? null : _changePassword,
              child: _pwSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black87))
                  : Text(l10n.profileChangePassword),
            ),
          ]),

          const SizedBox(height: 16),
          _SectionCard(title: l10n.settingsSectionAppearance, children: [
            Text(l10n.settingsTheme, style: const TextStyle(color: AppTheme.textSub, fontSize: 13)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'dark', label: Text(l10n.settingsThemeDark)),
                ButtonSegment(value: 'light', label: Text(l10n.settingsThemeLight)),
                ButtonSegment(value: 'system', label: Text(l10n.settingsThemeSystem)),
              ],
              selected: {settings.themePreference},
              onSelectionChanged: (sel) => settings.update({'theme_preference': sel.first}),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(l10n.settingsThemeComingSoon, style: const TextStyle(color: AppTheme.textSub, fontSize: 12)),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.settingsSectionLanguage, style: const TextStyle(color: AppTheme.textMain)),
                const LanguagePicker(),
              ],
            ),
          ]),

          const SizedBox(height: 16),
          _SectionCard(title: l10n.settingsSectionNotifications, children: [
            _SettingSwitch(
              title: l10n.settingsSound, subtitle: l10n.settingsSoundDesc,
              value: settings.notifSoundEnabled,
              onChanged: (v) => settings.update({'notif_sound_enabled': v}),
            ),
            _SettingSwitch(
              title: l10n.settingsVibrate, subtitle: l10n.settingsVibrateDesc,
              value: settings.notifVibrateEnabled,
              onChanged: (v) => settings.update({'notif_vibrate_enabled': v}),
            ),
          ]),

          const SizedBox(height: 16),
          _SectionCard(title: l10n.settingsSectionPrivacy, children: [
            _SettingSwitch(
              title: l10n.settingsReadReceipts, subtitle: l10n.settingsReadReceiptsDesc,
              value: settings.privacyReadReceipts,
              onChanged: (v) => settings.update({'privacy_read_receipts': v}),
            ),
            _SettingSwitch(
              title: l10n.settingsShowTyping, subtitle: l10n.settingsShowTypingDesc,
              value: settings.privacyShowTyping,
              onChanged: (v) => settings.update({'privacy_show_typing': v}),
            ),
          ]),

          const SizedBox(height: 16),
          _SectionCard(title: l10n.settingsSectionChat, children: [
            _SettingSwitch(
              title: l10n.settingsAutoDownloadMedia, subtitle: l10n.settingsAutoDownloadMediaDesc,
              value: settings.chatAutoDownloadMedia,
              onChanged: (v) => settings.update({'chat_auto_download_media': v}),
            ),
            const SizedBox(height: 8),
            Text(l10n.settingsMessageTextSize, style: const TextStyle(color: AppTheme.textSub, fontSize: 13)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'small', label: Text(l10n.settingsTextSizeSmall)),
                ButtonSegment(value: 'medium', label: Text(l10n.settingsTextSizeMedium)),
                ButtonSegment(value: 'large', label: Text(l10n.settingsTextSizeLarge)),
              ],
              selected: {settings.chatMessageTextScale},
              onSelectionChanged: (sel) => settings.update({'chat_message_text_scale': sel.first}),
            ),
          ]),

          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: _signOut,
            style: OutlinedButton.styleFrom(foregroundColor: AppTheme.danger, side: const BorderSide(color: AppTheme.danger)),
            child: Text(l10n.settingsSignOut),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AppTheme.textMain, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _SettingSwitch extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SettingSwitch({required this.title, required this.subtitle, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      activeThumbColor: AppTheme.primary,
      title: Text(title, style: const TextStyle(color: AppTheme.textMain)),
      subtitle: Text(subtitle, style: const TextStyle(color: AppTheme.textSub, fontSize: 12)),
      value: value,
      onChanged: onChanged,
    );
  }
}
