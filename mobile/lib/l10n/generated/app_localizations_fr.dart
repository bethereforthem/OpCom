// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appName => 'OpCom';

  @override
  String get authLoginTagline => 'Communications internes sécurisées';

  @override
  String get authLoginIdentifierLabel =>
      'Nom d\'utilisateur, e-mail ou ID employé';

  @override
  String get authLoginPasswordLabel => 'Mot de passe';

  @override
  String get authLoginSignIn => 'Se connecter';

  @override
  String get authLoginNeedAccountSignUp => 'Besoin d\'un compte ? S\'inscrire';

  @override
  String get authLoginRestricted => 'Accès réservé au personnel autorisé';

  @override
  String get authLoginFailed => 'Échec de la connexion. Veuillez réessayer.';

  @override
  String get authSignupTitle => 'Créer un compte';

  @override
  String get authSignupFullNameLabel => 'Nom complet';

  @override
  String get authSignupUsernameLabel => 'Nom d\'utilisateur';

  @override
  String get authSignupEmailOptionalLabel => 'E-mail (optionnel)';

  @override
  String get authSignupStaffIdOptionalLabel => 'ID employé (optionnel)';

  @override
  String get authSignupPasswordLabel => 'Mot de passe (8 caractères min.)';

  @override
  String get authSignupCreate => 'Créer un compte';

  @override
  String get authSignupFailed => 'Échec de l\'inscription. Veuillez réessayer.';

  @override
  String get authSignupDoneTitle => 'Compte créé';

  @override
  String get authSignupDoneMessage =>
      'Un administrateur doit approuver votre compte avant que vous puissiez vous connecter.';

  @override
  String get authSignupBackToSignIn => 'Retour à la connexion';

  @override
  String get authMfaAppBarTitle => 'Vérification';

  @override
  String get authMfaTitle => 'Vérification requise';

  @override
  String get authMfaTotpInstructions =>
      'Entrez le code à 6 chiffres de votre application d\'authentification.';

  @override
  String get authMfaEmailInstructions =>
      'Entrez le code à 6 chiffres envoyé à votre e-mail.';

  @override
  String get authMfaCodeLabel => 'Code à 6 chiffres';

  @override
  String get authMfaVerify => 'Vérifier';

  @override
  String get authMfaInvalidCode => 'Code invalide. Réessayez.';

  @override
  String get commonCancel => 'Annuler';

  @override
  String get commonUnknown => 'Inconnu';

  @override
  String get commonGroup => 'Groupe';

  @override
  String get commonMedia => 'Média';

  @override
  String get commonSearch => 'Rechercher';

  @override
  String get commonSearching => 'Recherche…';

  @override
  String get chatEveryoneInGroup => 'Tout le monde dans ce groupe';

  @override
  String get chatDisappearingRestricted =>
      'Seuls les propriétaires/administrateurs du groupe peuvent modifier ceci';

  @override
  String get chatDisappearingOff => 'Désactivé';

  @override
  String get chatDisappearing24h => '24 heures';

  @override
  String get chatDisappearing7d => '7 jours';

  @override
  String get chatDisappearing90d => '90 jours';

  @override
  String get chatDisappearingMessages => 'Messages éphémères';

  @override
  String get chatPickFutureTime => 'Choisissez une heure future';

  @override
  String get chatLoadOlder => 'Charger les messages plus anciens';

  @override
  String get chatEditingMessage => 'Modification du message';

  @override
  String chatReplyingTo(Object name) {
    return 'Réponse à $name';
  }

  @override
  String chatScheduledCount(Object count) {
    return 'Programmés ($count)';
  }

  @override
  String get chatScheduleMessage => 'Programmer le message';

  @override
  String get chatTypeMessage => 'Tapez un message…';

  @override
  String get chatOriginalDeleted => 'Message d\'origine supprimé';

  @override
  String get chatPhotoType => 'Photo';

  @override
  String get chatAudioType => 'Audio';

  @override
  String get chatVideoType => 'Vidéo';

  @override
  String get chatDocumentType => 'Document';

  @override
  String get chatAudioMessage => 'Message audio';

  @override
  String get chatFileType => 'Fichier';

  @override
  String get chatTapToLoad => 'Appuyez pour charger';

  @override
  String chatForwardedFrom(Object name) {
    return 'Transféré de $name';
  }

  @override
  String get chatMessageDeleted => 'Message supprimé';

  @override
  String get chatEdited => 'modifié';

  @override
  String get chatReply => 'Répondre';

  @override
  String get chatForward => 'Transférer';

  @override
  String get chatEdit => 'Modifier';

  @override
  String get chatDelete => 'Supprimer';

  @override
  String get chatConfirmDeleteMessage =>
      'Supprimer ce message ? Cette action est irréversible.';

  @override
  String get chatUploadFailed =>
      'Échec du téléchargement. Vérifiez le type et la taille du fichier.';

  @override
  String get forwardTitle => 'Transférer le message';

  @override
  String get forwardFailed => 'Échec du transfert du message';

  @override
  String get forwardInProgress => 'Transfert…';

  @override
  String get convUnarchive => 'Désarchiver';

  @override
  String get convArchive => 'Archiver';

  @override
  String get convUnmute => 'Réactiver le son';

  @override
  String get convMute => 'Mettre en sourdine…';

  @override
  String get convMute8h => 'Sourdine pendant 8 heures';

  @override
  String get convMute1w => 'Sourdine pendant 1 semaine';

  @override
  String get convMuteAlways => 'Sourdine permanente';

  @override
  String get convTitle => 'Messages';

  @override
  String get convNewConversationTooltip => 'Nouvelle conversation';

  @override
  String get convNewConversationTitle => 'Nouvelle conversation';

  @override
  String get convEmpty =>
      'Aucune conversation pour le moment.\nAppuyez sur + pour en démarrer une.';

  @override
  String convArchivedCount(Object count) {
    return 'Archivées ($count)';
  }

  @override
  String convMembersCount(Object count) {
    return '$count membres';
  }

  @override
  String get convRecipientLabel => 'Nom d\'utilisateur du destinataire';

  @override
  String get convStart => 'Démarrer';

  @override
  String get convCreateFailed =>
      'Utilisateur introuvable ou échec de la création de la conversation';

  @override
  String callIncoming(Object type) {
    return 'Appel $type entrant';
  }

  @override
  String get callAudio => 'audio';

  @override
  String get callVideo => 'vidéo';

  @override
  String get callCalling => 'Appel en cours…';

  @override
  String callMissedFrom(Object name) {
    return 'Appel manqué de $name';
  }

  @override
  String callNoAnswerFrom(Object name) {
    return '$name n\'a pas répondu';
  }

  @override
  String get callHistoryTitle => 'Appels';

  @override
  String get callHistoryEmpty => 'Aucun appel pour le moment';

  @override
  String get callHistoryMissed => 'Manqué';

  @override
  String get callHistoryDeclined => 'Refusé';

  @override
  String get callHistoryAnswered => 'Répondu';

  @override
  String get callHistoryNoAnswer => 'Sans réponse';

  @override
  String get callHistoryFailed => 'Échoué';

  @override
  String get notifTitle => 'Notifications';

  @override
  String get notifEmpty => 'Aucune notification';

  @override
  String get searchTitle => 'Rechercher des messages';

  @override
  String get searchTextHint => 'Rechercher du texte…';

  @override
  String get searchSenderHint => 'Nom d\'utilisateur de l\'expéditeur';

  @override
  String get searchAnyType => 'Tout type';

  @override
  String get searchTextType => 'Texte';

  @override
  String searchNoUserFound(Object username) {
    return 'Aucun utilisateur trouvé correspondant à « $username »';
  }

  @override
  String get searchFailed => 'La recherche a échoué';

  @override
  String get searchNoResults => 'Aucun résultat';

  @override
  String get settingsTitle => 'Paramètres';

  @override
  String get settingsSectionChat => 'Discussion';

  @override
  String get settingsSectionNotifications => 'Notifications';

  @override
  String get settingsSectionPrivacy => 'Confidentialité';

  @override
  String get settingsSectionAppearance => 'Apparence';

  @override
  String get settingsSectionLanguage => 'Langue';

  @override
  String get settingsAutoDownloadMedia =>
      'Téléchargement automatique des médias';

  @override
  String get settingsAutoDownloadMediaDesc =>
      'Charger automatiquement les photos, l\'audio et la vidéo';

  @override
  String get settingsMessageTextSize => 'Taille du texte des messages';

  @override
  String get settingsTextSizeSmall => 'Petite';

  @override
  String get settingsTextSizeMedium => 'Moyenne';

  @override
  String get settingsTextSizeLarge => 'Grande';

  @override
  String get settingsSound => 'Son';

  @override
  String get settingsSoundDesc =>
      'Jouer un son pour les appels et les messages';

  @override
  String get settingsVibrate => 'Vibration';

  @override
  String get settingsVibrateDesc => 'Vibrer pour les appels et les messages';

  @override
  String get settingsReadReceipts => 'Accusés de lecture';

  @override
  String get settingsReadReceiptsDesc =>
      'Permettre aux autres de voir quand vous avez lu leurs messages';

  @override
  String get settingsShowTyping => 'Indicateur de frappe';

  @override
  String get settingsShowTypingDesc =>
      'Permettre aux autres de voir quand vous écrivez';

  @override
  String get settingsTheme => 'Thème';

  @override
  String get settingsThemeDark => 'Sombre';

  @override
  String get settingsThemeLight => 'Clair';

  @override
  String get settingsThemeSystem => 'Système';

  @override
  String get settingsThemeComingSoon =>
      'Les thèmes Clair et Système sont enregistrés mais pas encore appliqués — bientôt disponible';

  @override
  String get settingsSignOut => 'Se déconnecter';

  @override
  String get profileTitle => 'Profil';

  @override
  String get profileFullNameLabel => 'Nom complet';

  @override
  String get profileUsernameLabel => 'Nom d\'utilisateur';

  @override
  String get profileBioLabel => 'Bio';

  @override
  String get profileBioPlaceholder => 'Parlez un peu de vous aux autres';

  @override
  String get profileStatusLabel => 'Statut';

  @override
  String get profileStatusPlaceholder => 'À quoi pensez-vous ?';

  @override
  String get profileSave => 'Enregistrer les modifications';

  @override
  String get profileSaved => 'Profil mis à jour';

  @override
  String get profileSaveFailed => 'Échec de la mise à jour du profil';

  @override
  String get profileUsernameTaken => 'Ce nom d\'utilisateur est déjà pris';

  @override
  String get profileChangePhoto => 'Changer la photo';

  @override
  String get profilePhotoUploadFailed => 'Échec de la mise à jour de la photo';

  @override
  String get profileChangePassword => 'Changer le mot de passe';

  @override
  String get profileCurrentPassword => 'Mot de passe actuel';

  @override
  String get profileNewPassword => 'Nouveau mot de passe';

  @override
  String get profileConfirmPassword => 'Confirmer le nouveau mot de passe';

  @override
  String get profilePasswordMismatch =>
      'Les mots de passe ne correspondent pas';

  @override
  String get profilePasswordTooShort =>
      'Le mot de passe doit contenir au moins 8 caractères';

  @override
  String get profilePasswordWrongCurrent =>
      'Le mot de passe actuel est incorrect';

  @override
  String get profilePasswordChanged => 'Mot de passe modifié';

  @override
  String get profilePasswordChangeFailed =>
      'Échec du changement de mot de passe';
}
