import 'package:flutter/material.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/theme/app_theme.dart';

const kFixedReactions = ['👍', '❤️', '😂', '😢', '😠'];

// Long-press action menu for a message bubble: a quick-reaction row plus
// Reply/Edit/Forward actions.
Future<void> showMessageActionsSheet({
  required BuildContext context,
  required Map<String, dynamic> message,
  required bool isMine,
  required VoidCallback onReply,
  required void Function(String emoji) onReact,
  VoidCallback? onEdit,
  VoidCallback? onForward,
  VoidCallback? onDelete,
}) {
  final l10n = AppLocalizations.of(context)!;
  final canEdit = isMine &&
      message['type'] == 'text' &&
      message['is_deleted'] != true &&
      onEdit != null;
  final canDelete = isMine && message['is_deleted'] != true && onDelete != null;
  final canActOn = message['is_deleted'] != true;

  return showModalBottomSheet(
    context: context,
    backgroundColor: AppTheme.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (canActOn)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ...kFixedReactions.map((emoji) => GestureDetector(
                        onTap: () {
                          Navigator.pop(ctx);
                          onReact(emoji);
                        },
                        child: Text(emoji, style: const TextStyle(fontSize: 26)),
                      )),
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      _showFullEmojiPicker(context, onReact);
                    },
                    child: const CircleAvatar(
                      radius: 16,
                      backgroundColor: AppTheme.bg,
                      child: Icon(Icons.add, color: AppTheme.textSub, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          if (canActOn)
            ListTile(
              leading: const Icon(Icons.reply_rounded, color: AppTheme.textMain),
              title: Text(l10n.chatReply, style: const TextStyle(color: AppTheme.textMain)),
              onTap: () {
                Navigator.pop(ctx);
                onReply();
              },
            ),
          if (canActOn && onForward != null)
            ListTile(
              leading: const Icon(Icons.forward_rounded, color: AppTheme.textMain),
              title: Text(l10n.chatForward, style: const TextStyle(color: AppTheme.textMain)),
              onTap: () {
                Navigator.pop(ctx);
                onForward();
              },
            ),
          if (canEdit)
            ListTile(
              leading: const Icon(Icons.edit_rounded, color: AppTheme.textMain),
              title: Text(l10n.chatEdit, style: const TextStyle(color: AppTheme.textMain)),
              onTap: () {
                Navigator.pop(ctx);
                onEdit();
              },
            ),
          if (canDelete)
            ListTile(
              leading: const Icon(Icons.delete_rounded, color: AppTheme.danger),
              title: Text(l10n.chatDelete, style: const TextStyle(color: AppTheme.danger)),
              onTap: () {
                Navigator.pop(ctx);
                onDelete();
              },
            ),
        ],
      ),
    ),
  );
}

void _showFullEmojiPicker(BuildContext context, void Function(String emoji) onReact) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppTheme.surface,
    builder: (_) => SizedBox(
      height: 300,
      child: EmojiPicker(
        onEmojiSelected: (category, emoji) {
          Navigator.pop(context);
          onReact(emoji.emoji);
        },
      ),
    ),
  );
}
