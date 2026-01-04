import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ko.dart';

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
    Locale('ko'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'MoAI SSH/SFTP'**
  String get appTitle;

  /// No description provided for @noHostsConfigured.
  ///
  /// In en, this message translates to:
  /// **'No hosts configured'**
  String get noHostsConfigured;

  /// No description provided for @addHost.
  ///
  /// In en, this message translates to:
  /// **'Add Host'**
  String get addHost;

  /// No description provided for @deleteHostTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Host'**
  String get deleteHostTitle;

  /// No description provided for @deleteHostContent.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"?'**
  String deleteHostContent(String name);

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @ssh.
  ///
  /// In en, this message translates to:
  /// **'SSH'**
  String get ssh;

  /// No description provided for @sftp.
  ///
  /// In en, this message translates to:
  /// **'SFTP'**
  String get sftp;

  /// No description provided for @hostName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get hostName;

  /// No description provided for @hostHostname.
  ///
  /// In en, this message translates to:
  /// **'Hostname'**
  String get hostHostname;

  /// No description provided for @hostPort.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get hostPort;

  /// No description provided for @hostUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get hostUsername;

  /// No description provided for @hostAuthType.
  ///
  /// In en, this message translates to:
  /// **'Auth Type'**
  String get hostAuthType;

  /// No description provided for @hostKeyFile.
  ///
  /// In en, this message translates to:
  /// **'Key File'**
  String get hostKeyFile;

  /// No description provided for @addNewHost.
  ///
  /// In en, this message translates to:
  /// **'Add New Host'**
  String get addNewHost;

  /// No description provided for @editHost.
  ///
  /// In en, this message translates to:
  /// **'Edit Host'**
  String get editHost;

  /// No description provided for @labelName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get labelName;

  /// No description provided for @labelHostname.
  ///
  /// In en, this message translates to:
  /// **'Hostname/IP'**
  String get labelHostname;

  /// No description provided for @labelPort.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get labelPort;

  /// No description provided for @labelUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get labelUsername;

  /// No description provided for @labelPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get labelPassword;

  /// No description provided for @labelKeyFilePath.
  ///
  /// In en, this message translates to:
  /// **'Key File Path'**
  String get labelKeyFilePath;

  /// No description provided for @labelOS.
  ///
  /// In en, this message translates to:
  /// **'Operating System'**
  String get labelOS;

  /// No description provided for @labelAuthType.
  ///
  /// In en, this message translates to:
  /// **'Authentication Type'**
  String get labelAuthType;

  /// No description provided for @validatorName.
  ///
  /// In en, this message translates to:
  /// **'Please enter a name'**
  String get validatorName;

  /// No description provided for @validatorHostname.
  ///
  /// In en, this message translates to:
  /// **'Please enter a hostname'**
  String get validatorHostname;

  /// No description provided for @validatorPort.
  ///
  /// In en, this message translates to:
  /// **'Please enter a port'**
  String get validatorPort;

  /// No description provided for @validatorPortRange.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid port (1-65535)'**
  String get validatorPortRange;

  /// No description provided for @validatorUsername.
  ///
  /// In en, this message translates to:
  /// **'Please enter a username'**
  String get validatorUsername;

  /// No description provided for @validatorPassword.
  ///
  /// In en, this message translates to:
  /// **'Please enter a password'**
  String get validatorPassword;

  /// No description provided for @validatorKeyFile.
  ///
  /// In en, this message translates to:
  /// **'Please select a key file'**
  String get validatorKeyFile;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @reselectKeyFile.
  ///
  /// In en, this message translates to:
  /// **'Please re-select your SSH key file for security'**
  String get reselectKeyFile;

  /// No description provided for @failedToReadKeyFile.
  ///
  /// In en, this message translates to:
  /// **'Failed to read key file: {error}'**
  String failedToReadKeyFile(Object error);

  /// No description provided for @hideHiddenFiles.
  ///
  /// In en, this message translates to:
  /// **'Hide hidden files'**
  String get hideHiddenFiles;

  /// No description provided for @showHiddenFiles.
  ///
  /// In en, this message translates to:
  /// **'Show hidden files'**
  String get showHiddenFiles;

  /// No description provided for @connectingTo.
  ///
  /// In en, this message translates to:
  /// **'Connecting to {host}...'**
  String connectingTo(String host);

  /// No description provided for @connectedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Connected successfully!'**
  String get connectedSuccessfully;

  /// No description provided for @connectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed: {error}'**
  String connectionFailed(Object error);

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @local.
  ///
  /// In en, this message translates to:
  /// **'Local'**
  String get local;

  /// No description provided for @remote.
  ///
  /// In en, this message translates to:
  /// **'Remote - {host}'**
  String remote(String host);

  /// No description provided for @newFolder.
  ///
  /// In en, this message translates to:
  /// **'New Folder'**
  String get newFolder;

  /// No description provided for @upload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get upload;

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @move.
  ///
  /// In en, this message translates to:
  /// **'Move'**
  String get move;

  /// No description provided for @folderConflict.
  ///
  /// In en, this message translates to:
  /// **'Folder Conflict'**
  String get folderConflict;

  /// No description provided for @fileConflict.
  ///
  /// In en, this message translates to:
  /// **'File Conflict'**
  String get fileConflict;

  /// No description provided for @conflictContent.
  ///
  /// In en, this message translates to:
  /// **'{type} \"{name}\" already exists.'**
  String conflictContent(String type, String name);

  /// No description provided for @conflictQuestion.
  ///
  /// In en, this message translates to:
  /// **'How would you like to proceed?'**
  String get conflictQuestion;

  /// No description provided for @merge.
  ///
  /// In en, this message translates to:
  /// **'Merge'**
  String get merge;

  /// No description provided for @overwrite.
  ///
  /// In en, this message translates to:
  /// **'Overwrite'**
  String get overwrite;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @transferComplete.
  ///
  /// In en, this message translates to:
  /// **'{operation} Complete'**
  String transferComplete(String operation);

  /// No description provided for @filesCount.
  ///
  /// In en, this message translates to:
  /// **'Files: {count}'**
  String filesCount(int count);

  /// No description provided for @foldersCount.
  ///
  /// In en, this message translates to:
  /// **'Folders: {count}'**
  String foldersCount(int count);

  /// No description provided for @size.
  ///
  /// In en, this message translates to:
  /// **'Size: {size}'**
  String size(String size);

  /// No description provided for @time.
  ///
  /// In en, this message translates to:
  /// **'Time: {time}'**
  String time(String time);

  /// No description provided for @downloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed: {error}'**
  String downloadFailed(Object error);

  /// No description provided for @uploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed: {error}'**
  String uploadFailed(Object error);

  /// No description provided for @deleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted {name}'**
  String deleted(String name);

  /// No description provided for @deleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Delete failed: {error}'**
  String deleteFailed(Object error);

  /// No description provided for @copiedItems.
  ///
  /// In en, this message translates to:
  /// **'Copied {count} items'**
  String copiedItems(int count);

  /// No description provided for @copyFailed.
  ///
  /// In en, this message translates to:
  /// **'Copy failed: {error}'**
  String copyFailed(Object error);

  /// No description provided for @copyTo.
  ///
  /// In en, this message translates to:
  /// **'Copy To'**
  String get copyTo;

  /// No description provided for @moveTo.
  ///
  /// In en, this message translates to:
  /// **'Move To'**
  String get moveTo;

  /// No description provided for @destinationPath.
  ///
  /// In en, this message translates to:
  /// **'Destination Path'**
  String get destinationPath;

  /// No description provided for @enterDestinationPath.
  ///
  /// In en, this message translates to:
  /// **'Enter destination directory path'**
  String get enterDestinationPath;

  /// No description provided for @createFolder.
  ///
  /// In en, this message translates to:
  /// **'Create Folder'**
  String get createFolder;

  /// No description provided for @folderName.
  ///
  /// In en, this message translates to:
  /// **'Folder Name'**
  String get folderName;

  /// No description provided for @enterFolderName.
  ///
  /// In en, this message translates to:
  /// **'Enter new folder name'**
  String get enterFolderName;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @renameTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get renameTitle;

  /// No description provided for @newName.
  ///
  /// In en, this message translates to:
  /// **'New Name'**
  String get newName;

  /// No description provided for @enterNewName.
  ///
  /// In en, this message translates to:
  /// **'Enter new name'**
  String get enterNewName;

  /// No description provided for @failedToCreateDirectory.
  ///
  /// In en, this message translates to:
  /// **'Failed to create directory: {error}'**
  String failedToCreateDirectory(Object error);

  /// No description provided for @failedToRename.
  ///
  /// In en, this message translates to:
  /// **'Failed to rename: {error}'**
  String failedToRename(Object error);

  /// No description provided for @folder.
  ///
  /// In en, this message translates to:
  /// **'Folder'**
  String get folder;

  /// No description provided for @file.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get file;

  /// No description provided for @uploadFileTitle.
  ///
  /// In en, this message translates to:
  /// **'Upload File'**
  String get uploadFileTitle;

  /// No description provided for @uploadFileContent.
  ///
  /// In en, this message translates to:
  /// **'Upload \"{name}\" to remote directory?'**
  String uploadFileContent(String name);

  /// No description provided for @downloadFileTitle.
  ///
  /// In en, this message translates to:
  /// **'Download File'**
  String get downloadFileTitle;

  /// No description provided for @downloadFileContent.
  ///
  /// In en, this message translates to:
  /// **'Download \"{name}\" to local directory?'**
  String downloadFileContent(String name);

  /// No description provided for @itemsSelected.
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String itemsSelected(int count);

  /// No description provided for @durationMinSec.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m {seconds}s'**
  String durationMinSec(int minutes, int seconds);

  /// No description provided for @durationSec.
  ///
  /// In en, this message translates to:
  /// **'{seconds}s'**
  String durationSec(int seconds);

  /// No description provided for @listingFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load files: {error}'**
  String listingFailed(Object error);

  /// No description provided for @fileAccessRequired.
  ///
  /// In en, this message translates to:
  /// **'File Access Required'**
  String get fileAccessRequired;

  /// No description provided for @fileAccessRequiredMessage.
  ///
  /// In en, this message translates to:
  /// **'This app needs permission to access your files for local file browsing. Please select a folder to grant access.'**
  String get fileAccessRequiredMessage;

  /// No description provided for @selectFolder.
  ///
  /// In en, this message translates to:
  /// **'Select Folder'**
  String get selectFolder;

  /// No description provided for @selectLocalFolder.
  ///
  /// In en, this message translates to:
  /// **'Select Local Folder'**
  String get selectLocalFolder;

  /// No description provided for @fileAccessDenied.
  ///
  /// In en, this message translates to:
  /// **'File access was denied'**
  String get fileAccessDenied;

  /// No description provided for @noFolderSelected.
  ///
  /// In en, this message translates to:
  /// **'No folder was selected'**
  String get noFolderSelected;
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
      <String>['en', 'ko'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ko':
      return AppLocalizationsKo();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
