// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'MoAI SSH/SFTP';

  @override
  String get noHostsConfigured => 'No hosts configured';

  @override
  String get addHost => 'Add Host';

  @override
  String get deleteHostTitle => 'Delete Host';

  @override
  String deleteHostContent(String name) {
    return 'Are you sure you want to delete \"$name\"?';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get ssh => 'SSH';

  @override
  String get sftp => 'SFTP';

  @override
  String get hostName => 'Name';

  @override
  String get hostHostname => 'Hostname';

  @override
  String get hostPort => 'Port';

  @override
  String get hostUsername => 'Username';

  @override
  String get hostAuthType => 'Auth Type';

  @override
  String get hostKeyFile => 'Key File';

  @override
  String get addNewHost => 'Add New Host';

  @override
  String get editHost => 'Edit Host';

  @override
  String get labelName => 'Name';

  @override
  String get labelHostname => 'Hostname/IP';

  @override
  String get labelPort => 'Port';

  @override
  String get labelUsername => 'Username';

  @override
  String get labelPassword => 'Password';

  @override
  String get labelKeyFilePath => 'Key File Path';

  @override
  String get labelOS => 'Operating System';

  @override
  String get labelAuthType => 'Authentication Type';

  @override
  String get validatorName => 'Please enter a name';

  @override
  String get validatorHostname => 'Please enter a hostname';

  @override
  String get validatorPort => 'Please enter a port';

  @override
  String get validatorPortRange => 'Please enter a valid port (1-65535)';

  @override
  String get validatorUsername => 'Please enter a username';

  @override
  String get validatorPassword => 'Please enter a password';

  @override
  String get validatorKeyFile => 'Please select a key file';

  @override
  String get save => 'Save';

  @override
  String get reselectKeyFile =>
      'Please re-select your SSH key file for security';

  @override
  String failedToReadKeyFile(Object error) {
    return 'Failed to read key file: $error';
  }

  @override
  String get hideHiddenFiles => 'Hide hidden files';

  @override
  String get showHiddenFiles => 'Show hidden files';

  @override
  String connectingTo(String host) {
    return 'Connecting to $host...';
  }

  @override
  String get connectedSuccessfully => 'Connected successfully!';

  @override
  String connectionFailed(Object error) {
    return 'Connection failed: $error';
  }

  @override
  String get retry => 'Retry';

  @override
  String get local => 'Local';

  @override
  String remote(String host) {
    return 'Remote - $host';
  }

  @override
  String get newFolder => 'New Folder';

  @override
  String get upload => 'Upload';

  @override
  String get download => 'Download';

  @override
  String get rename => 'Rename';

  @override
  String get copy => 'Copy';

  @override
  String get move => 'Move';

  @override
  String get folderConflict => 'Folder Conflict';

  @override
  String get fileConflict => 'File Conflict';

  @override
  String conflictContent(String type, String name) {
    return '$type \"$name\" already exists.';
  }

  @override
  String get conflictQuestion => 'How would you like to proceed?';

  @override
  String get merge => 'Merge';

  @override
  String get overwrite => 'Overwrite';

  @override
  String get skip => 'Skip';

  @override
  String transferComplete(String operation) {
    return '$operation Complete';
  }

  @override
  String filesCount(int count) {
    return 'Files: $count';
  }

  @override
  String foldersCount(int count) {
    return 'Folders: $count';
  }

  @override
  String size(String size) {
    return 'Size: $size';
  }

  @override
  String time(String time) {
    return 'Time: $time';
  }

  @override
  String downloadFailed(Object error) {
    return 'Download failed: $error';
  }

  @override
  String uploadFailed(Object error) {
    return 'Upload failed: $error';
  }

  @override
  String deleted(String name) {
    return 'Deleted $name';
  }

  @override
  String deleteFailed(Object error) {
    return 'Delete failed: $error';
  }

  @override
  String copiedItems(int count) {
    return 'Copied $count items';
  }

  @override
  String copyFailed(Object error) {
    return 'Copy failed: $error';
  }

  @override
  String get copyTo => 'Copy To';

  @override
  String get moveTo => 'Move To';

  @override
  String get destinationPath => 'Destination Path';

  @override
  String get enterDestinationPath => 'Enter destination directory path';

  @override
  String get createFolder => 'Create Folder';

  @override
  String get folderName => 'Folder Name';

  @override
  String get enterFolderName => 'Enter new folder name';

  @override
  String get create => 'Create';

  @override
  String get renameTitle => 'Rename';

  @override
  String get newName => 'New Name';

  @override
  String get enterNewName => 'Enter new name';

  @override
  String failedToCreateDirectory(Object error) {
    return 'Failed to create directory: $error';
  }

  @override
  String failedToRename(Object error) {
    return 'Failed to rename: $error';
  }

  @override
  String get folder => 'Folder';

  @override
  String get file => 'File';

  @override
  String get uploadFileTitle => 'Upload File';

  @override
  String uploadFileContent(String name) {
    return 'Upload \"$name\" to remote directory?';
  }

  @override
  String get downloadFileTitle => 'Download File';

  @override
  String downloadFileContent(String name) {
    return 'Download \"$name\" to local directory?';
  }

  @override
  String itemsSelected(int count) {
    return '$count items';
  }

  @override
  String durationMinSec(int minutes, int seconds) {
    return '${minutes}m ${seconds}s';
  }

  @override
  String durationSec(int seconds) {
    return '${seconds}s';
  }

  @override
  String listingFailed(Object error) {
    return 'Failed to load files: $error';
  }
}
