// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'OpCom';

  @override
  String get authLoginTagline => 'Secure Internal Communications';

  @override
  String get authLoginIdentifierLabel => 'Username, Email, or Staff ID';

  @override
  String get authLoginPasswordLabel => 'Password';

  @override
  String get authLoginSignIn => 'Sign In';

  @override
  String get authLoginNeedAccountSignUp => 'Need an account? Sign up';

  @override
  String get authLoginRestricted =>
      'Access restricted to authorized personnel only';

  @override
  String get authLoginFailed => 'Login failed. Please try again.';

  @override
  String get authSignupTitle => 'Create Account';

  @override
  String get authSignupFullNameLabel => 'Full name';

  @override
  String get authSignupUsernameLabel => 'Username';

  @override
  String get authSignupEmailOptionalLabel => 'Email (optional)';

  @override
  String get authSignupStaffIdOptionalLabel => 'Staff ID (optional)';

  @override
  String get authSignupPasswordLabel => 'Password (8+ characters)';

  @override
  String get authSignupCreate => 'Create Account';

  @override
  String get authSignupFailed => 'Signup failed. Please try again.';

  @override
  String get authSignupDoneTitle => 'Account created';

  @override
  String get authSignupDoneMessage =>
      'An administrator must approve your account before you can sign in.';

  @override
  String get authSignupBackToSignIn => 'Back to sign in';

  @override
  String get authMfaAppBarTitle => 'Verification';

  @override
  String get authMfaTitle => 'Verification Required';

  @override
  String get authMfaTotpInstructions =>
      'Enter the 6-digit code from your authenticator app.';

  @override
  String get authMfaEmailInstructions =>
      'Enter the 6-digit code sent to your email.';

  @override
  String get authMfaCodeLabel => '6-digit code';

  @override
  String get authMfaVerify => 'Verify';

  @override
  String get authMfaInvalidCode => 'Invalid code. Try again.';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonUnknown => 'Unknown';

  @override
  String get commonGroup => 'Group';

  @override
  String get commonMedia => 'Media';

  @override
  String get commonSearch => 'Search';

  @override
  String get commonSearching => 'Searching…';

  @override
  String get chatEveryoneInGroup => 'Everyone in this group';

  @override
  String get chatDisappearingRestricted =>
      'Only group owners/admins can change this';

  @override
  String get chatDisappearingOff => 'Off';

  @override
  String get chatDisappearing24h => '24 hours';

  @override
  String get chatDisappearing7d => '7 days';

  @override
  String get chatDisappearing90d => '90 days';

  @override
  String get chatDisappearingMessages => 'Disappearing messages';

  @override
  String get chatPickFutureTime => 'Pick a time in the future';

  @override
  String get chatLoadOlder => 'Load older messages';

  @override
  String get chatEditingMessage => 'Editing message';

  @override
  String chatReplyingTo(Object name) {
    return 'Replying to $name';
  }

  @override
  String chatScheduledCount(Object count) {
    return 'Scheduled ($count)';
  }

  @override
  String get chatScheduleMessage => 'Schedule message';

  @override
  String get chatTypeMessage => 'Type a message…';

  @override
  String get chatOriginalDeleted => 'Original message deleted';

  @override
  String get chatPhotoType => 'Photo';

  @override
  String get chatAudioType => 'Audio';

  @override
  String get chatVideoType => 'Video';

  @override
  String get chatDocumentType => 'Document';

  @override
  String get chatAudioMessage => 'Audio message';

  @override
  String get chatFileType => 'File';

  @override
  String get chatTapToLoad => 'Tap to load';

  @override
  String chatForwardedFrom(Object name) {
    return 'Forwarded from $name';
  }

  @override
  String get chatMessageDeleted => 'Message deleted';

  @override
  String get chatEdited => 'edited';

  @override
  String get chatReply => 'Reply';

  @override
  String get chatForward => 'Forward';

  @override
  String get chatEdit => 'Edit';

  @override
  String get chatDelete => 'Delete';

  @override
  String get chatConfirmDeleteMessage =>
      'Delete this message? This cannot be undone.';

  @override
  String get chatUploadFailed => 'Upload failed. Check file type and size.';

  @override
  String get forwardTitle => 'Forward message';

  @override
  String get forwardFailed => 'Failed to forward message';

  @override
  String get forwardInProgress => 'Forwarding…';

  @override
  String get convUnarchive => 'Unarchive';

  @override
  String get convArchive => 'Archive';

  @override
  String get convUnmute => 'Unmute';

  @override
  String get convMute => 'Mute…';

  @override
  String get convMute8h => 'Mute for 8 hours';

  @override
  String get convMute1w => 'Mute for 1 week';

  @override
  String get convMuteAlways => 'Mute always';

  @override
  String get convTitle => 'Messages';

  @override
  String get homeTabChats => 'Chats';

  @override
  String get homeTabPeople => 'People';

  @override
  String get peopleSearchHint => 'Search people';

  @override
  String get peopleEmpty => 'No one else here yet.';

  @override
  String get peopleNoResults => 'No matches found';

  @override
  String get convNewConversationTooltip => 'New conversation';

  @override
  String get convNewConversationTitle => 'New Conversation';

  @override
  String get convEmpty => 'No conversations yet.\nTap + to start one.';

  @override
  String convArchivedCount(Object count) {
    return 'Archived ($count)';
  }

  @override
  String convMembersCount(Object count) {
    return '$count members';
  }

  @override
  String get convRecipientLabel => 'Username of recipient';

  @override
  String get convStart => 'Start';

  @override
  String get convCreateFailed =>
      'User not found or failed to create conversation';

  @override
  String callIncoming(Object type) {
    return 'Incoming $type call';
  }

  @override
  String get callAudio => 'audio';

  @override
  String get callVideo => 'video';

  @override
  String get callCalling => 'Calling…';

  @override
  String callMissedFrom(Object name) {
    return 'Missed call from $name';
  }

  @override
  String callNoAnswerFrom(Object name) {
    return '$name didn\'t answer';
  }

  @override
  String get callHistoryTitle => 'Calls';

  @override
  String get callHistoryEmpty => 'No calls yet';

  @override
  String get callHistoryMissed => 'Missed';

  @override
  String get callHistoryDeclined => 'Declined';

  @override
  String get callHistoryAnswered => 'Answered';

  @override
  String get callHistoryNoAnswer => 'No answer';

  @override
  String get callHistoryFailed => 'Failed';

  @override
  String get notifTitle => 'Notifications';

  @override
  String get notifEmpty => 'No notifications';

  @override
  String get searchTitle => 'Search messages';

  @override
  String get searchTextHint => 'Search text…';

  @override
  String get searchSenderHint => 'Sender username';

  @override
  String get searchAnyType => 'Any type';

  @override
  String get searchTextType => 'Text';

  @override
  String searchNoUserFound(Object username) {
    return 'No user found matching \"$username\"';
  }

  @override
  String get searchFailed => 'Search failed';

  @override
  String get searchNoResults => 'No results';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSectionChat => 'Chat';

  @override
  String get settingsSectionNotifications => 'Notifications';

  @override
  String get settingsSectionPrivacy => 'Privacy';

  @override
  String get settingsSectionAppearance => 'Appearance';

  @override
  String get settingsSectionLanguage => 'Language';

  @override
  String get settingsAutoDownloadMedia => 'Auto-download media';

  @override
  String get settingsAutoDownloadMediaDesc =>
      'Automatically load photos, audio, and video';

  @override
  String get settingsMessageTextSize => 'Message text size';

  @override
  String get settingsTextSizeSmall => 'Small';

  @override
  String get settingsTextSizeMedium => 'Medium';

  @override
  String get settingsTextSizeLarge => 'Large';

  @override
  String get settingsSound => 'Sound';

  @override
  String get settingsSoundDesc => 'Play a sound for calls and messages';

  @override
  String get settingsVibrate => 'Vibrate';

  @override
  String get settingsVibrateDesc => 'Vibrate for calls and messages';

  @override
  String get settingsReadReceipts => 'Read receipts';

  @override
  String get settingsReadReceiptsDesc =>
      'Let others see when you\'ve read their messages';

  @override
  String get settingsShowTyping => 'Typing indicator';

  @override
  String get settingsShowTypingDesc => 'Let others see when you\'re typing';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsThemeComingSoon =>
      'Light and System themes are saved but not yet rendered — coming soon';

  @override
  String get settingsSignOut => 'Sign out';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileFullNameLabel => 'Full name';

  @override
  String get profileUsernameLabel => 'Username';

  @override
  String get profileBioLabel => 'Bio';

  @override
  String get profileBioPlaceholder => 'Tell others a bit about yourself';

  @override
  String get profileStatusLabel => 'Status';

  @override
  String get profileStatusPlaceholder => 'What\'s on your mind?';

  @override
  String get profileSave => 'Save changes';

  @override
  String get profileSaved => 'Profile updated';

  @override
  String get profileSaveFailed => 'Failed to update profile';

  @override
  String get profileUsernameTaken => 'That username is already taken';

  @override
  String get profileChangePhoto => 'Change photo';

  @override
  String get profilePhotoUploadFailed => 'Failed to update photo';

  @override
  String get profileChangePassword => 'Change password';

  @override
  String get profileCurrentPassword => 'Current password';

  @override
  String get profileNewPassword => 'New password';

  @override
  String get profileConfirmPassword => 'Confirm new password';

  @override
  String get profilePasswordMismatch => 'Passwords don\'t match';

  @override
  String get profilePasswordTooShort =>
      'Password must be at least 8 characters';

  @override
  String get profilePasswordWrongCurrent => 'Current password is incorrect';

  @override
  String get profilePasswordChanged => 'Password changed';

  @override
  String get profilePasswordChangeFailed => 'Failed to change password';
}
