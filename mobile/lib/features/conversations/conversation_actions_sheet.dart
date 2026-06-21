import 'package:flutter/material.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/theme/app_theme.dart';

// Long-press action menu for a conversation row: Archive/Unarchive,
// Mute (8h/1 week/Always)/Unmute. Mirrors message_actions_sheet.dart's
// bottom-sheet pattern.
Future<void> showConversationActionsSheet({
  required BuildContext context,
  required bool isArchived,
  required bool isMuted,
  required VoidCallback onArchive,
  required VoidCallback onUnarchive,
  required void Function(String duration) onMute,
  required VoidCallback onUnmute,
}) {
  final l10n = AppLocalizations.of(context)!;
  return showModalBottomSheet(
    context: context,
    backgroundColor: AppTheme.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(isArchived ? Icons.unarchive_rounded : Icons.archive_rounded,
                color: AppTheme.textMain),
            title: Text(isArchived ? l10n.convUnarchive : l10n.convArchive,
                style: const TextStyle(color: AppTheme.textMain)),
            onTap: () {
              Navigator.pop(ctx);
              isArchived ? onUnarchive() : onArchive();
            },
          ),
          if (isMuted)
            ListTile(
              leading: const Icon(Icons.notifications_active_rounded, color: AppTheme.textMain),
              title: Text(l10n.convUnmute, style: const TextStyle(color: AppTheme.textMain)),
              onTap: () {
                Navigator.pop(ctx);
                onUnmute();
              },
            )
          else
            ListTile(
              leading: const Icon(Icons.notifications_off_rounded, color: AppTheme.textMain),
              title: Text(l10n.convMute, style: const TextStyle(color: AppTheme.textMain)),
              onTap: () {
                Navigator.pop(ctx);
                _showMuteDurationSheet(context, onMute);
              },
            ),
        ],
      ),
    ),
  );
}

void _showMuteDurationSheet(BuildContext context, void Function(String duration) onMute) {
  final l10n = AppLocalizations.of(context)!;
  final options = [
    ('8h', l10n.convMute8h),
    ('1w', l10n.convMute1w),
    ('always', l10n.convMuteAlways),
  ];
  showModalBottomSheet(
    context: context,
    backgroundColor: AppTheme.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: options
            .map((opt) => ListTile(
                  title: Text(opt.$2, style: const TextStyle(color: AppTheme.textMain)),
                  onTap: () {
                    Navigator.pop(ctx);
                    onMute(opt.$1);
                  },
                ))
            .toList(),
      ),
    ),
  );
}
