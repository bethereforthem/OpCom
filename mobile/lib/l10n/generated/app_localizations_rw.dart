// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Kinyarwanda (`rw`).
class AppLocalizationsRw extends AppLocalizations {
  AppLocalizationsRw([String locale = 'rw']) : super(locale);

  @override
  String get appName => 'OpCom';

  @override
  String get authLoginTagline => 'Itumanaho ryizewe ry\'imbere mu kigo';

  @override
  String get authLoginIdentifierLabel =>
      'Izina ry\'ukoresha, Imeyili, cyangwa Nomero y\'umukozi';

  @override
  String get authLoginPasswordLabel => 'Ijambo ry\'ibanga';

  @override
  String get authLoginSignIn => 'Injira';

  @override
  String get authLoginNeedAccountSignUp => 'Ntufite konti? Iyandikishe';

  @override
  String get authLoginRestricted => 'Ifashishwa gusa n\'abemerewe';

  @override
  String get authLoginFailed => 'Kwinjira ntibyakunze. Ongera ugerageze.';

  @override
  String get authSignupTitle => 'Fungura Konti';

  @override
  String get authSignupFullNameLabel => 'Amazina yuzuye';

  @override
  String get authSignupUsernameLabel => 'Izina ry\'ukoresha';

  @override
  String get authSignupEmailOptionalLabel => 'Imeyili (Bitari ngombwa)';

  @override
  String get authSignupStaffIdOptionalLabel =>
      'Nomero y\'umukozi (Bitari ngombwa)';

  @override
  String get authSignupPasswordLabel => 'Ijambo ry\'ibanga (nibura inyuguti 8)';

  @override
  String get authSignupCreate => 'Fungura Konti';

  @override
  String get authSignupFailed => 'Kwiyandikisha ntibyakunze. Ongera ugerageze.';

  @override
  String get authSignupDoneTitle => 'Konti yafunguwe';

  @override
  String get authSignupDoneMessage =>
      'Umuyobozi agomba kwemeza konti yawe mbere y\'uko winjira.';

  @override
  String get authSignupBackToSignIn => 'Subira ku kwinjira';

  @override
  String get authMfaAppBarTitle => 'Kwemeza';

  @override
  String get authMfaTitle => 'Kwemeza Birasabwa';

  @override
  String get authMfaTotpInstructions =>
      'Andika kode y\'imibare 6 iboneka kuri porogaramu yawe yo kwemeza.';

  @override
  String get authMfaEmailInstructions =>
      'Andika kode y\'imibare 6 yoherejwe kuri imeyili yawe.';

  @override
  String get authMfaCodeLabel => 'Kode y\'imibare 6';

  @override
  String get authMfaVerify => 'Emeza';

  @override
  String get authMfaInvalidCode => 'Kode siyo. Ongera ugerageze.';

  @override
  String get commonCancel => 'Hagarika';

  @override
  String get commonUnknown => 'Ntiwamenyekanye';

  @override
  String get commonGroup => 'Itsinda';

  @override
  String get commonMedia => 'Itangazamakuru';

  @override
  String get commonSearch => 'Shakisha';

  @override
  String get commonSearching => 'Birimo gushakisha…';

  @override
  String get chatEveryoneInGroup => 'Bose muri iri tsinda';

  @override
  String get chatDisappearingRestricted =>
      'Abafite uburenganzira bwo kuyobora itsinda gusa ni bo bahindura iki';

  @override
  String get chatDisappearingOff => 'Bidakora';

  @override
  String get chatDisappearing24h => 'Amasaha 24';

  @override
  String get chatDisappearing7d => 'Iminsi 7';

  @override
  String get chatDisappearing90d => 'Iminsi 90';

  @override
  String get chatDisappearingMessages => 'Ubutumwa bubura';

  @override
  String get chatPickFutureTime => 'Hitamo igihe kizaza';

  @override
  String get chatLoadOlder => 'Reba ubutumwa bwa kera';

  @override
  String get chatEditingMessage => 'Guhindura ubutumwa';

  @override
  String chatReplyingTo(Object name) {
    return 'Usubiza $name';
  }

  @override
  String chatScheduledCount(Object count) {
    return 'Byateguwe ($count)';
  }

  @override
  String get chatScheduleMessage => 'Tegura igihe cyo kohereza';

  @override
  String get chatTypeMessage => 'Andika ubutumwa…';

  @override
  String get chatOriginalDeleted => 'Ubutumwa nyabwo bwasibwe';

  @override
  String get chatPhotoType => 'Ifoto';

  @override
  String get chatAudioType => 'Ijwi';

  @override
  String get chatVideoType => 'Videwo';

  @override
  String get chatDocumentType => 'Inyandiko';

  @override
  String get chatAudioMessage => 'Ubutumwa bw\'ijwi';

  @override
  String get chatFileType => 'Dosiye';

  @override
  String get chatTapToLoad => 'Kanda kugira ngo igaragare';

  @override
  String chatForwardedFrom(Object name) {
    return 'Bwoherejwe na $name';
  }

  @override
  String get chatMessageDeleted => 'Ubutumwa bwasibwe';

  @override
  String get chatEdited => 'byahinduwe';

  @override
  String get chatReply => 'Subiza';

  @override
  String get chatForward => 'Ohereza';

  @override
  String get chatEdit => 'Hindura';

  @override
  String get chatDelete => 'Siba';

  @override
  String get chatConfirmDeleteMessage =>
      'Siba ubu butumwa? Ibi ntibishobora gusubizwamo.';

  @override
  String get chatUploadFailed =>
      'Kohereza ntibyakunze. Reba ubwoko n\'ingano ya dosiye.';

  @override
  String get forwardTitle => 'Ohereza ubutumwa';

  @override
  String get forwardFailed => 'Kohereza ubutumwa ntibyakunze';

  @override
  String get forwardInProgress => 'Birimo kohereza…';

  @override
  String get convUnarchive => 'Garura';

  @override
  String get convArchive => 'Bika';

  @override
  String get convUnmute => 'Garura ijwi';

  @override
  String get convMute => 'Hagarika ijwi…';

  @override
  String get convMute8h => 'Hagarika ijwi amasaha 8';

  @override
  String get convMute1w => 'Hagarika ijwi icyumweru 1';

  @override
  String get convMuteAlways => 'Hagarika ijwi burundu';

  @override
  String get convTitle => 'Ubutumwa';

  @override
  String get homeTabChats => 'Ibiganiro';

  @override
  String get homeTabPeople => 'Abantu';

  @override
  String get peopleSearchHint => 'Shakisha abantu';

  @override
  String get peopleEmpty => 'Nta wundi muntu uhari kugeza ubu.';

  @override
  String get peopleNoResults => 'Nta gisubizo cyabonetse';

  @override
  String get convNewConversationTooltip => 'Ikiganiro gishya';

  @override
  String get convNewConversationTitle => 'Ikiganiro Gishya';

  @override
  String get convEmpty =>
      'Nta kiganiro urafite.\nKanda + kugira ngo utangire ikimwe.';

  @override
  String convArchivedCount(Object count) {
    return 'Byabikwe ($count)';
  }

  @override
  String convMembersCount(Object count) {
    return 'abanyamuryango $count';
  }

  @override
  String get convRecipientLabel => 'Izina ry\'ukoresha uwakira';

  @override
  String get convStart => 'Tangira';

  @override
  String get convCreateFailed =>
      'Ukoresha ntiyabonetse cyangwa kurema ikiganiro ntibyakunze';

  @override
  String callIncoming(Object type) {
    return 'Hari uhamagara mu $type';
  }

  @override
  String get callAudio => 'ijwi';

  @override
  String get callVideo => 'videwo';

  @override
  String get callCalling => 'Birimo guhamagara…';

  @override
  String callMissedFrom(Object name) {
    return 'Wahamagawe na $name ntiwasubije';
  }

  @override
  String callNoAnswerFrom(Object name) {
    return '$name ntiyasubije';
  }

  @override
  String get callHistoryTitle => 'Amahamagara';

  @override
  String get callHistoryEmpty => 'Nta hamagara rihari';

  @override
  String get callHistoryMissed => 'Ntiwasubijwe';

  @override
  String get callHistoryDeclined => 'Yanzwe';

  @override
  String get callHistoryAnswered => 'Byasubijwe';

  @override
  String get callHistoryNoAnswer => 'Nta gisubizo';

  @override
  String get callHistoryFailed => 'Ntibyakunze';

  @override
  String get notifTitle => 'Imenyesha';

  @override
  String get notifEmpty => 'Nta menyesha rihari';

  @override
  String get searchTitle => 'Shakisha ubutumwa';

  @override
  String get searchTextHint => 'Shakisha amagambo…';

  @override
  String get searchSenderHint => 'Izina ry\'ukoresha woherereje';

  @override
  String get searchAnyType => 'Ubwoko bwose';

  @override
  String get searchTextType => 'Inyandiko';

  @override
  String searchNoUserFound(Object username) {
    return 'Nta ukoresha wabonetse uhuye na \"$username\"';
  }

  @override
  String get searchFailed => 'Gushakisha ntibyakunze';

  @override
  String get searchNoResults => 'Nta gisubizo';

  @override
  String get settingsTitle => 'Igenamiterere';

  @override
  String get settingsSectionChat => 'Ikiganiro';

  @override
  String get settingsSectionNotifications => 'Imenyesha';

  @override
  String get settingsSectionPrivacy => 'Ibanga';

  @override
  String get settingsSectionAppearance => 'Imigaragarire';

  @override
  String get settingsSectionLanguage => 'Ururimi';

  @override
  String get settingsAutoDownloadMedia => 'Kuramo itangazamakuru byikoresha';

  @override
  String get settingsAutoDownloadMediaDesc =>
      'Pakira amafoto, ijwi, na videwo byikoresha';

  @override
  String get settingsMessageTextSize => 'Ingano y\'inyandiko z\'ubutumwa';

  @override
  String get settingsTextSizeSmall => 'Nto';

  @override
  String get settingsTextSizeMedium => 'Hagati';

  @override
  String get settingsTextSizeLarge => 'Nini';

  @override
  String get settingsSound => 'Ijwi';

  @override
  String get settingsSoundDesc => 'Kuvuza ijwi ku guhamagara n\'ubutumwa';

  @override
  String get settingsVibrate => 'Kunyeganyega';

  @override
  String get settingsVibrateDesc => 'Kunyeganyega ku guhamagara n\'ubutumwa';

  @override
  String get settingsReadReceipts => 'Kwemeza ko byasomwe';

  @override
  String get settingsReadReceiptsDesc =>
      'Reka abandi babone igihe wasomye ubutumwa bwabo';

  @override
  String get settingsShowTyping => 'Ikimenyetso cy\'uko wandika';

  @override
  String get settingsShowTypingDesc => 'Reka abandi babone igihe wandika';

  @override
  String get settingsTheme => 'Insanganyamatsiko';

  @override
  String get settingsThemeDark => 'Umwijima';

  @override
  String get settingsThemeLight => 'Urumuri';

  @override
  String get settingsThemeSystem => 'Sisitemu';

  @override
  String get settingsThemeComingSoon =>
      'Insanganyamatsiko z\'Urumuri na Sisitemu zarabitswe ariko ntizirakora — biraza vuba';

  @override
  String get settingsSignOut => 'Sohoka';

  @override
  String get profileTitle => 'Umwirondoro';

  @override
  String get profileFullNameLabel => 'Amazina yuzuye';

  @override
  String get profileUsernameLabel => 'Izina ry\'ukoresha';

  @override
  String get profileBioLabel => 'Umwirondoro ngufi';

  @override
  String get profileBioPlaceholder => 'Bwira abandi bake kuri wowe';

  @override
  String get profileStatusLabel => 'Uko umeze';

  @override
  String get profileStatusPlaceholder => 'Witekereza iki?';

  @override
  String get profileSave => 'Bika impinduka';

  @override
  String get profileSaved => 'Umwirondoro wahinduwe';

  @override
  String get profileSaveFailed => 'Kuvugurura umwirondoro ntibyakunze';

  @override
  String get profileUsernameTaken => 'Iri zina ry\'ukoresha ryarafashwe';

  @override
  String get profileChangePhoto => 'Hindura ifoto';

  @override
  String get profilePhotoUploadFailed => 'Kuvugurura ifoto ntibyakunze';

  @override
  String get profileChangePassword => 'Hindura ijambo ry\'ibanga';

  @override
  String get profileCurrentPassword => 'Ijambo ry\'ibanga risanzwe';

  @override
  String get profileNewPassword => 'Ijambo ry\'ibanga rishya';

  @override
  String get profileConfirmPassword => 'Emeza ijambo ry\'ibanga rishya';

  @override
  String get profilePasswordMismatch => 'Amagambo y\'ibanga ntahuye';

  @override
  String get profilePasswordTooShort =>
      'Ijambo ry\'ibanga rigomba kuba nibura inyuguti 8';

  @override
  String get profilePasswordWrongCurrent => 'Ijambo ry\'ibanga risanzwe si ryo';

  @override
  String get profilePasswordChanged => 'Ijambo ry\'ibanga ryahinduwe';

  @override
  String get profilePasswordChangeFailed =>
      'Guhindura ijambo ry\'ibanga ntibyakunze';
}
