import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_rw.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
    Locale('rw'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'OpCom'**
  String get appName;

  /// No description provided for @authLoginTagline.
  ///
  /// In en, this message translates to:
  /// **'Secure Internal Communications'**
  String get authLoginTagline;

  /// No description provided for @authLoginIdentifierLabel.
  ///
  /// In en, this message translates to:
  /// **'Username, Email, or Staff ID'**
  String get authLoginIdentifierLabel;

  /// No description provided for @authLoginPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authLoginPasswordLabel;

  /// No description provided for @authLoginSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get authLoginSignIn;

  /// No description provided for @authLoginNeedAccountSignUp.
  ///
  /// In en, this message translates to:
  /// **'Need an account? Sign up'**
  String get authLoginNeedAccountSignUp;

  /// No description provided for @authLoginRestricted.
  ///
  /// In en, this message translates to:
  /// **'Access restricted to authorized personnel only'**
  String get authLoginRestricted;

  /// No description provided for @authLoginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed. Please try again.'**
  String get authLoginFailed;

  /// No description provided for @authSignupTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get authSignupTitle;

  /// No description provided for @authSignupFullNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get authSignupFullNameLabel;

  /// No description provided for @authSignupUsernameLabel.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get authSignupUsernameLabel;

  /// No description provided for @authSignupEmailOptionalLabel.
  ///
  /// In en, this message translates to:
  /// **'Email (optional)'**
  String get authSignupEmailOptionalLabel;

  /// No description provided for @authSignupStaffIdOptionalLabel.
  ///
  /// In en, this message translates to:
  /// **'Staff ID (optional)'**
  String get authSignupStaffIdOptionalLabel;

  /// No description provided for @authSignupPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password (8+ characters)'**
  String get authSignupPasswordLabel;

  /// No description provided for @authSignupCreate.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get authSignupCreate;

  /// No description provided for @authSignupFailed.
  ///
  /// In en, this message translates to:
  /// **'Signup failed. Please try again.'**
  String get authSignupFailed;

  /// No description provided for @authSignupDoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Account created'**
  String get authSignupDoneTitle;

  /// No description provided for @authSignupDoneMessage.
  ///
  /// In en, this message translates to:
  /// **'An administrator must approve your account before you can sign in.'**
  String get authSignupDoneMessage;

  /// No description provided for @authSignupBackToSignIn.
  ///
  /// In en, this message translates to:
  /// **'Back to sign in'**
  String get authSignupBackToSignIn;

  /// No description provided for @authMfaAppBarTitle.
  ///
  /// In en, this message translates to:
  /// **'Verification'**
  String get authMfaAppBarTitle;

  /// No description provided for @authMfaTitle.
  ///
  /// In en, this message translates to:
  /// **'Verification Required'**
  String get authMfaTitle;

  /// No description provided for @authMfaTotpInstructions.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code from your authenticator app.'**
  String get authMfaTotpInstructions;

  /// No description provided for @authMfaEmailInstructions.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code sent to your email.'**
  String get authMfaEmailInstructions;

  /// No description provided for @authMfaCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'6-digit code'**
  String get authMfaCodeLabel;

  /// No description provided for @authMfaVerify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get authMfaVerify;

  /// No description provided for @authMfaInvalidCode.
  ///
  /// In en, this message translates to:
  /// **'Invalid code. Try again.'**
  String get authMfaInvalidCode;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get commonUnknown;

  /// No description provided for @commonGroup.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get commonGroup;

  /// No description provided for @commonMedia.
  ///
  /// In en, this message translates to:
  /// **'Media'**
  String get commonMedia;

  /// No description provided for @commonSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get commonSearch;

  /// No description provided for @commonSearching.
  ///
  /// In en, this message translates to:
  /// **'Searching…'**
  String get commonSearching;

  /// No description provided for @chatEveryoneInGroup.
  ///
  /// In en, this message translates to:
  /// **'Everyone in this group'**
  String get chatEveryoneInGroup;

  /// No description provided for @chatDisappearingRestricted.
  ///
  /// In en, this message translates to:
  /// **'Only group owners/admins can change this'**
  String get chatDisappearingRestricted;

  /// No description provided for @chatDisappearingOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get chatDisappearingOff;

  /// No description provided for @chatDisappearing24h.
  ///
  /// In en, this message translates to:
  /// **'24 hours'**
  String get chatDisappearing24h;

  /// No description provided for @chatDisappearing7d.
  ///
  /// In en, this message translates to:
  /// **'7 days'**
  String get chatDisappearing7d;

  /// No description provided for @chatDisappearing90d.
  ///
  /// In en, this message translates to:
  /// **'90 days'**
  String get chatDisappearing90d;

  /// No description provided for @chatDisappearingMessages.
  ///
  /// In en, this message translates to:
  /// **'Disappearing messages'**
  String get chatDisappearingMessages;

  /// No description provided for @chatPickFutureTime.
  ///
  /// In en, this message translates to:
  /// **'Pick a time in the future'**
  String get chatPickFutureTime;

  /// No description provided for @chatLoadOlder.
  ///
  /// In en, this message translates to:
  /// **'Load older messages'**
  String get chatLoadOlder;

  /// No description provided for @chatEditingMessage.
  ///
  /// In en, this message translates to:
  /// **'Editing message'**
  String get chatEditingMessage;

  /// No description provided for @chatReplyingTo.
  ///
  /// In en, this message translates to:
  /// **'Replying to {name}'**
  String chatReplyingTo(Object name);

  /// No description provided for @chatScheduledCount.
  ///
  /// In en, this message translates to:
  /// **'Scheduled ({count})'**
  String chatScheduledCount(Object count);

  /// No description provided for @chatScheduleMessage.
  ///
  /// In en, this message translates to:
  /// **'Schedule message'**
  String get chatScheduleMessage;

  /// No description provided for @chatTypeMessage.
  ///
  /// In en, this message translates to:
  /// **'Type a message…'**
  String get chatTypeMessage;

  /// No description provided for @chatOriginalDeleted.
  ///
  /// In en, this message translates to:
  /// **'Original message deleted'**
  String get chatOriginalDeleted;

  /// No description provided for @chatPhotoType.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get chatPhotoType;

  /// No description provided for @chatAudioType.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get chatAudioType;

  /// No description provided for @chatVideoType.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get chatVideoType;

  /// No description provided for @chatDocumentType.
  ///
  /// In en, this message translates to:
  /// **'Document'**
  String get chatDocumentType;

  /// No description provided for @chatAudioMessage.
  ///
  /// In en, this message translates to:
  /// **'Audio message'**
  String get chatAudioMessage;

  /// No description provided for @chatFileType.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get chatFileType;

  /// No description provided for @chatTapToLoad.
  ///
  /// In en, this message translates to:
  /// **'Tap to load'**
  String get chatTapToLoad;

  /// No description provided for @chatForwardedFrom.
  ///
  /// In en, this message translates to:
  /// **'Forwarded from {name}'**
  String chatForwardedFrom(Object name);

  /// No description provided for @chatMessageDeleted.
  ///
  /// In en, this message translates to:
  /// **'Message deleted'**
  String get chatMessageDeleted;

  /// No description provided for @chatEdited.
  ///
  /// In en, this message translates to:
  /// **'edited'**
  String get chatEdited;

  /// No description provided for @chatReply.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get chatReply;

  /// No description provided for @chatForward.
  ///
  /// In en, this message translates to:
  /// **'Forward'**
  String get chatForward;

  /// No description provided for @chatEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get chatEdit;

  /// No description provided for @chatDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get chatDelete;

  /// No description provided for @chatConfirmDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete this message? This cannot be undone.'**
  String get chatConfirmDeleteMessage;

  /// No description provided for @chatUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed. Check file type and size.'**
  String get chatUploadFailed;

  /// No description provided for @forwardTitle.
  ///
  /// In en, this message translates to:
  /// **'Forward message'**
  String get forwardTitle;

  /// No description provided for @forwardFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to forward message'**
  String get forwardFailed;

  /// No description provided for @forwardInProgress.
  ///
  /// In en, this message translates to:
  /// **'Forwarding…'**
  String get forwardInProgress;

  /// No description provided for @convUnarchive.
  ///
  /// In en, this message translates to:
  /// **'Unarchive'**
  String get convUnarchive;

  /// No description provided for @convArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get convArchive;

  /// No description provided for @convUnmute.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get convUnmute;

  /// No description provided for @convMute.
  ///
  /// In en, this message translates to:
  /// **'Mute…'**
  String get convMute;

  /// No description provided for @convMute8h.
  ///
  /// In en, this message translates to:
  /// **'Mute for 8 hours'**
  String get convMute8h;

  /// No description provided for @convMute1w.
  ///
  /// In en, this message translates to:
  /// **'Mute for 1 week'**
  String get convMute1w;

  /// No description provided for @convMuteAlways.
  ///
  /// In en, this message translates to:
  /// **'Mute always'**
  String get convMuteAlways;

  /// No description provided for @convTitle.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get convTitle;

  /// No description provided for @convNewConversationTooltip.
  ///
  /// In en, this message translates to:
  /// **'New conversation'**
  String get convNewConversationTooltip;

  /// No description provided for @convNewConversationTitle.
  ///
  /// In en, this message translates to:
  /// **'New Conversation'**
  String get convNewConversationTitle;

  /// No description provided for @convEmpty.
  ///
  /// In en, this message translates to:
  /// **'No conversations yet.\nTap + to start one.'**
  String get convEmpty;

  /// No description provided for @convArchivedCount.
  ///
  /// In en, this message translates to:
  /// **'Archived ({count})'**
  String convArchivedCount(Object count);

  /// No description provided for @convMembersCount.
  ///
  /// In en, this message translates to:
  /// **'{count} members'**
  String convMembersCount(Object count);

  /// No description provided for @convRecipientLabel.
  ///
  /// In en, this message translates to:
  /// **'Username of recipient'**
  String get convRecipientLabel;

  /// No description provided for @convStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get convStart;

  /// No description provided for @convCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'User not found or failed to create conversation'**
  String get convCreateFailed;

  /// No description provided for @callIncoming.
  ///
  /// In en, this message translates to:
  /// **'Incoming {type} call'**
  String callIncoming(Object type);

  /// No description provided for @callAudio.
  ///
  /// In en, this message translates to:
  /// **'audio'**
  String get callAudio;

  /// No description provided for @callVideo.
  ///
  /// In en, this message translates to:
  /// **'video'**
  String get callVideo;

  /// No description provided for @callCalling.
  ///
  /// In en, this message translates to:
  /// **'Calling…'**
  String get callCalling;

  /// No description provided for @callMissedFrom.
  ///
  /// In en, this message translates to:
  /// **'Missed call from {name}'**
  String callMissedFrom(Object name);

  /// No description provided for @callNoAnswerFrom.
  ///
  /// In en, this message translates to:
  /// **'{name} didn\'t answer'**
  String callNoAnswerFrom(Object name);

  /// No description provided for @callHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Calls'**
  String get callHistoryTitle;

  /// No description provided for @callHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No calls yet'**
  String get callHistoryEmpty;

  /// No description provided for @callHistoryMissed.
  ///
  /// In en, this message translates to:
  /// **'Missed'**
  String get callHistoryMissed;

  /// No description provided for @callHistoryDeclined.
  ///
  /// In en, this message translates to:
  /// **'Declined'**
  String get callHistoryDeclined;

  /// No description provided for @callHistoryAnswered.
  ///
  /// In en, this message translates to:
  /// **'Answered'**
  String get callHistoryAnswered;

  /// No description provided for @callHistoryNoAnswer.
  ///
  /// In en, this message translates to:
  /// **'No answer'**
  String get callHistoryNoAnswer;

  /// No description provided for @callHistoryFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get callHistoryFailed;

  /// No description provided for @notifTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifTitle;

  /// No description provided for @notifEmpty.
  ///
  /// In en, this message translates to:
  /// **'No notifications'**
  String get notifEmpty;

  /// No description provided for @searchTitle.
  ///
  /// In en, this message translates to:
  /// **'Search messages'**
  String get searchTitle;

  /// No description provided for @searchTextHint.
  ///
  /// In en, this message translates to:
  /// **'Search text…'**
  String get searchTextHint;

  /// No description provided for @searchSenderHint.
  ///
  /// In en, this message translates to:
  /// **'Sender username'**
  String get searchSenderHint;

  /// No description provided for @searchAnyType.
  ///
  /// In en, this message translates to:
  /// **'Any type'**
  String get searchAnyType;

  /// No description provided for @searchTextType.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get searchTextType;

  /// No description provided for @searchNoUserFound.
  ///
  /// In en, this message translates to:
  /// **'No user found matching \"{username}\"'**
  String searchNoUserFound(Object username);

  /// No description provided for @searchFailed.
  ///
  /// In en, this message translates to:
  /// **'Search failed'**
  String get searchFailed;

  /// No description provided for @searchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get searchNoResults;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsSectionChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get settingsSectionChat;

  /// No description provided for @settingsSectionNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsSectionNotifications;

  /// No description provided for @settingsSectionPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get settingsSectionPrivacy;

  /// No description provided for @settingsSectionAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsSectionAppearance;

  /// No description provided for @settingsSectionLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsSectionLanguage;

  /// No description provided for @settingsAutoDownloadMedia.
  ///
  /// In en, this message translates to:
  /// **'Auto-download media'**
  String get settingsAutoDownloadMedia;

  /// No description provided for @settingsAutoDownloadMediaDesc.
  ///
  /// In en, this message translates to:
  /// **'Automatically load photos, audio, and video'**
  String get settingsAutoDownloadMediaDesc;

  /// No description provided for @settingsMessageTextSize.
  ///
  /// In en, this message translates to:
  /// **'Message text size'**
  String get settingsMessageTextSize;

  /// No description provided for @settingsTextSizeSmall.
  ///
  /// In en, this message translates to:
  /// **'Small'**
  String get settingsTextSizeSmall;

  /// No description provided for @settingsTextSizeMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get settingsTextSizeMedium;

  /// No description provided for @settingsTextSizeLarge.
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get settingsTextSizeLarge;

  /// No description provided for @settingsSound.
  ///
  /// In en, this message translates to:
  /// **'Sound'**
  String get settingsSound;

  /// No description provided for @settingsSoundDesc.
  ///
  /// In en, this message translates to:
  /// **'Play a sound for calls and messages'**
  String get settingsSoundDesc;

  /// No description provided for @settingsVibrate.
  ///
  /// In en, this message translates to:
  /// **'Vibrate'**
  String get settingsVibrate;

  /// No description provided for @settingsVibrateDesc.
  ///
  /// In en, this message translates to:
  /// **'Vibrate for calls and messages'**
  String get settingsVibrateDesc;

  /// No description provided for @settingsReadReceipts.
  ///
  /// In en, this message translates to:
  /// **'Read receipts'**
  String get settingsReadReceipts;

  /// No description provided for @settingsReadReceiptsDesc.
  ///
  /// In en, this message translates to:
  /// **'Let others see when you\'ve read their messages'**
  String get settingsReadReceiptsDesc;

  /// No description provided for @settingsShowTyping.
  ///
  /// In en, this message translates to:
  /// **'Typing indicator'**
  String get settingsShowTyping;

  /// No description provided for @settingsShowTypingDesc.
  ///
  /// In en, this message translates to:
  /// **'Let others see when you\'re typing'**
  String get settingsShowTypingDesc;

  /// No description provided for @settingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// No description provided for @settingsThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// No description provided for @settingsThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsThemeSystem;

  /// No description provided for @settingsThemeComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Light and System themes are saved but not yet rendered — coming soon'**
  String get settingsThemeComingSoon;

  /// No description provided for @settingsSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get settingsSignOut;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @profileFullNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get profileFullNameLabel;

  /// No description provided for @profileUsernameLabel.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get profileUsernameLabel;

  /// No description provided for @profileBioLabel.
  ///
  /// In en, this message translates to:
  /// **'Bio'**
  String get profileBioLabel;

  /// No description provided for @profileBioPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Tell others a bit about yourself'**
  String get profileBioPlaceholder;

  /// No description provided for @profileStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get profileStatusLabel;

  /// No description provided for @profileStatusPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'What\'s on your mind?'**
  String get profileStatusPlaceholder;

  /// No description provided for @profileSave.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get profileSave;

  /// No description provided for @profileSaved.
  ///
  /// In en, this message translates to:
  /// **'Profile updated'**
  String get profileSaved;

  /// No description provided for @profileSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update profile'**
  String get profileSaveFailed;

  /// No description provided for @profileUsernameTaken.
  ///
  /// In en, this message translates to:
  /// **'That username is already taken'**
  String get profileUsernameTaken;

  /// No description provided for @profileChangePhoto.
  ///
  /// In en, this message translates to:
  /// **'Change photo'**
  String get profileChangePhoto;

  /// No description provided for @profilePhotoUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update photo'**
  String get profilePhotoUploadFailed;

  /// No description provided for @profileChangePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get profileChangePassword;

  /// No description provided for @profileCurrentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get profileCurrentPassword;

  /// No description provided for @profileNewPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get profileNewPassword;

  /// No description provided for @profileConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm new password'**
  String get profileConfirmPassword;

  /// No description provided for @profilePasswordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords don\'t match'**
  String get profilePasswordMismatch;

  /// No description provided for @profilePasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters'**
  String get profilePasswordTooShort;

  /// No description provided for @profilePasswordWrongCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current password is incorrect'**
  String get profilePasswordWrongCurrent;

  /// No description provided for @profilePasswordChanged.
  ///
  /// In en, this message translates to:
  /// **'Password changed'**
  String get profilePasswordChanged;

  /// No description provided for @profilePasswordChangeFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to change password'**
  String get profilePasswordChangeFailed;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr', 'rw'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
    case 'rw':
      return AppLocalizationsRw();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
