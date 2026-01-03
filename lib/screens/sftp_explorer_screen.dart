import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:moai_ssh_sftp_client/l10n/generated/app_localizations.dart';
import '../models/host.dart';
import '../services/ssh_service.dart';
import '../services/sftp_service.dart';

/// A screen that provides a dual-pane file explorer for SFTP.
///
/// Allows users to browse local and remote file systems, transfer files/directories
/// (upload/download), and perform basic file operations (delete, rename, etc.).
class SFTPExplorerScreen extends StatefulWidget {
  /// The host to connect to.
  final Host host;

  /// Whether to show the AppBar.
  /// Typically false when embedded in [ConnectionScreen].
  final bool showAppBar;

  /// Whether to show hidden files (starting with '.') in the file lists.
  final bool showHiddenFiles;

  /// Creates an [SFTPExplorerScreen].
  const SFTPExplorerScreen({
    super.key,
    required this.host,
    this.showAppBar = true,
    this.showHiddenFiles = false,
  });

  @override
  State<SFTPExplorerScreen> createState() => SFTPExplorerScreenState();
}

class SFTPExplorerScreenState extends State<SFTPExplorerScreen> {
  final SSHService _sshService = SSHService();
  final SFTPService _sftpService = SFTPService();

  bool _isConnecting = true;
  String? _errorMessage;

  String _localPath = '';
  String _remotePath = '';
  List<FileSystemEntity> _localFiles = [];
  List<SftpFileInfo> _remoteFiles = [];
  String _localRootPath = '';

  final Set<String> _selectedLocalFiles = {};
  final Set<String> _selectedRemoteFiles = {};
  bool _isShiftPressed = false;
  bool _isControlPressed = false;
  int? _lastSelectedLocalIndex;
  int? _lastSelectedRemoteIndex;

  // Scroll controllers for path display
  final ScrollController _localPathScrollController = ScrollController();
  final ScrollController _remotePathScrollController = ScrollController();

  // Transfer progress tracking (download/upload)
  bool _isTransferring = false;
  bool _isUploading = false;
  String _currentTransferFile = '';
  int _transferProgress = 0;
  int _transferTotal = 0;
  int _remainingFilesCount = 0;
  int _totalFilesCount = 0;
  int _lastProgressBytes = 0;
  DateTime _lastProgressTime = DateTime.now();
  double _transferRate = 0; // bytes per second

  // Transfer statistics
  DateTime? _transferStartTime;
  int _transferredFilesCount = 0;
  int _transferredFoldersCount = 0;
  int _transferredTotalBytes = 0;
  bool _showTransferStats = false;
  String _transferOperation = '';
  Duration _transferElapsed = Duration.zero;

  // File conflict resolution
  String? _conflictResolutionChoice; // 'overwrite', 'rename', 'skip', or null for ask every time

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialize();
    });
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    _localPathScrollController.dispose();
    _remotePathScrollController.dispose();
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _sftpService.close();
    _sshService.disconnect();
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event.logicalKey == LogicalKeyboardKey.shiftLeft ||
        event.logicalKey == LogicalKeyboardKey.shiftRight) {
      setState(() {
        _isShiftPressed = event is KeyDownEvent || event is KeyRepeatEvent;
      });
    } else if (event.logicalKey == LogicalKeyboardKey.controlLeft ||
        event.logicalKey == LogicalKeyboardKey.controlRight ||
        event.logicalKey == LogicalKeyboardKey.metaLeft ||
        event.logicalKey == LogicalKeyboardKey.metaRight) {
      setState(() {
        _isControlPressed = event is KeyDownEvent || event is KeyRepeatEvent;
      });
    }
    return false;
  }

  /// Initializes the SSH and SFTP connections.
  ///
  /// Establishes the SSH connection, creates the SFTP session, determines the
  /// initial local and remote directories, and loads the file lists.
  Future<void> _initialize() async {
    // Clean up previous connections if retrying
    _sftpService.close();
    _sshService.disconnect();

    if (!mounted) return;

    final l10n = AppLocalizations.of(context)!;

    setState(() {
      _isConnecting = true;
      _errorMessage = null;
    });

    try {
      final client = await _sshService.connect(widget.host);

      if (!mounted) {
        _sshService.disconnect();
        return;
      }

      await _sftpService.initialize(client);

      if (!mounted) {
        _sftpService.close();
        _sshService.disconnect();
        return;
      }

      // Set local path
      String initialLocalPath;
      if (Platform.isIOS) {
        // iOS: Use Documents directory as it's the reliable sandbox root
        final documentsDir = await getApplicationDocumentsDirectory();
        _localRootPath = documentsDir.path;
        initialLocalPath = _localRootPath;
      } else if (Platform.isAndroid) {
        // Android: Try Downloads first, fallback to Documents
        final downloads = await getDownloadsDirectory();
        _localRootPath = downloads?.path ?? (await getApplicationDocumentsDirectory()).path;
        initialLocalPath = _localRootPath;
      } else {
        // Desktop
        initialLocalPath = Platform.environment['HOME'] ??
                        Platform.environment['USERPROFILE'] ??
                        '';
        _localRootPath = initialLocalPath;
      }
      _localPath = initialLocalPath;

      // Get actual remote home directory path
      final remoteHome = await _sftpService.getHomeDirectory(client);
      _remotePath = remoteHome.isNotEmpty ? remoteHome : '';

      await _loadLocalFiles();
      await _loadRemoteFiles();

      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _errorMessage = l10n.connectionFailed(e);
        });
      }
    }
  }

  /// Loads the list of files and directories in the current local directory.
  ///
  /// Displays an error message if the listing fails.
  Future<void> _loadLocalFiles() async {
    try {
      // Ensure local path is set to home directory if empty
      if (_localPath.isEmpty) {
        final homeDir = Platform.environment['HOME'] ??
                        Platform.environment['USERPROFILE'] ??
                        '';
        _localPath = homeDir;
      }

      final dir = Directory(_localPath);
      final entities = await dir.list().toList();

      if (mounted) {
        setState(() {
          _localFiles = entities;
        });
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.listingFailed(e))),
        );
      }
    }
  }

  /// Loads the list of files and directories in the current remote directory.
  ///
  /// Displays an error message if the listing fails.
  Future<void> _loadRemoteFiles() async {
    try {
      final files = await _sftpService.listDirectory(_remotePath);

      if (mounted) {
        setState(() {
          _remoteFiles = files;
        });
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.listingFailed(e))),
        );
      }
    }
  }

  /// Navigates to a specific local directory.
  ///
  /// On Android and iOS, prevents navigation above the root path for security.
  /// Clears any file selections and auto-scrolls the breadcrumb to show the end of the path.
  Future<void> _navigateLocal(String path) async {
    if (!mounted) return;

    if (Platform.isAndroid || Platform.isIOS) {
      // Prevent navigating above the root path
      if (!path.startsWith(_localRootPath)) {
        return;
      }
    }

    setState(() {
      _localPath = path;
      _selectedLocalFiles.clear();
      _lastSelectedLocalIndex = null;
    });
    _loadLocalFiles();

    // Auto-scroll to show the end of the path
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_localPathScrollController.hasClients) {
        _localPathScrollController.animateTo(
          _localPathScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _navigateRemote(String path) {
    navigateRemote(path);
  }

  /// Navigates the remote view to the specified [path].
  ///
  /// This public method can be called from parent widgets (e.g., [ConnectionScreen])
  /// to programmaticall change the current directory.
  void navigateRemote(String path) {
    if (!mounted) return;

    setState(() {
      _remotePath = path;
      _selectedRemoteFiles.clear();
      _lastSelectedRemoteIndex = null;
    });
    _loadRemoteFiles();

    // Auto-scroll to show the end of the path
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_remotePathScrollController.hasClients) {
        _remotePathScrollController.animateTo(
          _remotePathScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Shows a confirmation dialog before downloading a file from the remote server.
  ///
  /// If confirmed, initiates the download process.
  Future<void> _confirmDownloadFile(SftpFileInfo file) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.downloadFileTitle),
        content: Text(l10n.downloadFileContent(file.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.download),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _downloadFile(file);
    }
  }

  /// Downloads a single file from the remote server to the local current directory.
  ///
  /// Handles file conflicts (overwrite, rename, skip) and updates the transfer progress UI.
  Future<void> _downloadFile(SftpFileInfo file) async {
    try {
      // Check if file already exists
      String localFilePath = '$_localPath/${file.name}';
      String fileName = file.name;

      if (File(localFilePath).existsSync()) {
        final action = await _handleConflict(file.name, false, true);

        if (action == 'skip') {
          return; // Skip this file
        } else if (action == 'rename') {
          fileName = _getUniqueFileName(_localPath, file.name);
          localFilePath = '$_localPath/$fileName';
        }
        // If 'overwrite' or 'merge' (merge doesn't apply to files), use the original localFilePath
      }

      setState(() {
        _isTransferring = true;
        _isUploading = false;
        _currentTransferFile = fileName;
        _transferProgress = 0;
        _transferTotal = file.size;
        _remainingFilesCount = 1;
        _totalFilesCount = 1;
        _lastProgressBytes = 0;
        _lastProgressTime = DateTime.now();
        _transferRate = 0;
        _transferStartTime = DateTime.now();
        _transferredFilesCount = 0;
        _transferredFoldersCount = 0;
        _transferredTotalBytes = 0;
        _conflictResolutionChoice = null; // Reset for single file transfer
      });

      await _sftpService.downloadFile(
        file.path,
        localFilePath,
        onProgress: (received, total) {
          if (mounted) {
            final now = DateTime.now();
            final timeDiff = now.difference(_lastProgressTime).inMilliseconds;

            if (timeDiff > 100) { // Update rate every 100ms
              final bytesDiff = received - _lastProgressBytes;
              final rate = (bytesDiff * 1000) / timeDiff; // bytes per second

              setState(() {
                _transferProgress = received;
                _transferTotal = total;
                _transferRate = rate;
                _lastProgressBytes = received;
                _lastProgressTime = now;
              });
            }
          }
        },
      );

      if (mounted) {
        setState(() {
          _remainingFilesCount--;
          _transferredFilesCount++;
          _transferredTotalBytes += file.size;
        });
      }

      await _loadLocalFiles();

      if (mounted) {
        final elapsed = DateTime.now().difference(_transferStartTime!);
        setState(() {
          _isTransferring = false;
        });
        _showTransferStatistics('Download', elapsed);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTransferring = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    }
  }

  /// Recursively downloads a remote directory to the local current directory.
  ///
  /// Checks for conflicts with the destination folder and initiates a queued download
  /// for all contents.
  Future<void> _downloadDirectory(SftpFileInfo directory) async {
    try {
      String localDirPath = '$_localPath/${directory.name}';
      String dirName = directory.name;
      final localDir = Directory(localDirPath);

      // Check if directory already exists
      if (await localDir.exists()) {
        final action = await _handleConflict(directory.name, true, true);

        if (action == 'skip') {
          return; // Skip this directory
        } else if (action == 'rename') {
          dirName = _getUniqueFileName(_localPath, directory.name);
          localDirPath = '$_localPath/$dirName';
        } else if (action == 'overwrite') {
          // Delete existing directory
          await localDir.delete(recursive: true);
        }
        // If 'merge', continue with existing directory
      }

      // Create directory if it doesn't exist (or was deleted for overwrite)
      if (!await Directory(localDirPath).exists()) {
        await Directory(localDirPath).create(recursive: true);
      }

      if (mounted) {
        setState(() {
          _isTransferring = true;
          _isUploading = false;
          _remainingFilesCount = 0;
          _totalFilesCount = 0;
          _transferStartTime = DateTime.now();
          _transferredFilesCount = 0;
          _transferredFoldersCount = 0;
          _transferredTotalBytes = 0;
          _conflictResolutionChoice = null; // Reset for batch transfer
        });
      }

      await _downloadWithQueue(directory.path, localDirPath);
      await _loadLocalFiles();

      if (mounted) {
        final elapsed = DateTime.now().difference(_transferStartTime!);
        setState(() {
          _isTransferring = false;
        });
        _showTransferStatistics('Download', elapsed);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTransferring = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to download directory: $e')),
        );
      }
    }
  }

  /// Downloads multiple selected files and directories from the remote server.
  ///
  /// Handles conflicts and tracks transfer progress across all selected items.
  Future<void> _downloadMultipleFiles(List<SftpFileInfo> files) async {
    try {
      setState(() {
        _isTransferring = true;
        _isUploading = false;
        _remainingFilesCount = 0;
        _totalFilesCount = 0;
        _transferStartTime = DateTime.now();
        _transferredFilesCount = 0;
        _transferredFoldersCount = 0;
        _transferredTotalBytes = 0;
        _conflictResolutionChoice = null; // Reset for batch transfer
      });

      for (final file in files) {
        if (file.isDirectory) {
          String localDirPath = '$_localPath/${file.name}';
          String dirName = file.name;
          final localDir = Directory(localDirPath);

          // Check if directory already exists
          if (await localDir.exists()) {
            final action = await _handleConflict(file.name, true, true);

            if (action == 'skip') {
              continue; // Skip this directory
            } else if (action == 'rename') {
              dirName = _getUniqueFileName(_localPath, file.name);
              localDirPath = '$_localPath/$dirName';
            } else if (action == 'overwrite') {
              // Delete existing directory
              await localDir.delete(recursive: true);
            }
            // If 'merge', continue with existing directory
          }

          // Create directory if needed
          if (!await Directory(localDirPath).exists()) {
            await Directory(localDirPath).create(recursive: true);
          }
          _transferredFoldersCount++;
          await _downloadWithQueue(file.path, localDirPath);
        } else {
          // File found - increase total and remaining count
          if (mounted) {
            setState(() {
              _totalFilesCount++;
              _remainingFilesCount++;
            });
          }

          if (mounted) {
            setState(() {
              _currentTransferFile = file.name;
              _transferProgress = 0;
              _transferTotal = file.size;
              _lastProgressBytes = 0;
              _lastProgressTime = DateTime.now();
            });
          }

          final localFilePath = '$_localPath/${file.name}';
          await _sftpService.downloadFile(
            file.path,
            localFilePath,
            onProgress: (received, total) {
              if (mounted) {
                final now = DateTime.now();
                final timeDiff = now.difference(_lastProgressTime).inMilliseconds;

                if (timeDiff > 100) {
                  final bytesDiff = received - _lastProgressBytes;
                  final rate = (bytesDiff * 1000) / timeDiff;

                  setState(() {
                    _transferProgress = received;
                    _transferTotal = total;
                    _transferRate = rate;
                    _lastProgressBytes = received;
                    _lastProgressTime = now;
                  });
                }
              }
            },
          );

          // File download complete - decrease remaining count
          if (mounted) {
            setState(() {
              _remainingFilesCount--;
              _transferredFilesCount++;
              _transferredTotalBytes += file.size;
            });
          }
        }
      }

      await _loadLocalFiles();

      if (mounted) {
        final elapsed = DateTime.now().difference(_transferStartTime!);
        setState(() {
          _isTransferring = false;
        });
        _showTransferStatistics('Download', elapsed);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTransferring = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    }
  }

  /// Downloads contents of a directory using a queue to avoid recursion depth issues.
  ///
  /// Processes directories breadth-first to prevent stack overflow on deep directory structures.
  Future<void> _downloadWithQueue(String remotePath, String localPath) async {
    final queue = <Map<String, String>>[];
    queue.add({'remote': remotePath, 'local': localPath});

    while (queue.isNotEmpty) {
      final item = queue.removeAt(0);
      final currentRemotePath = item['remote']!;
      final currentLocalPath = item['local']!;

      final files = await _sftpService.listDirectory(currentRemotePath);

      for (final file in files) {
        if (file.isDirectory) {
          final localDirPath = '$currentLocalPath/${file.name}';
          final localDir = Directory(localDirPath);
          if (!await localDir.exists()) {
            await localDir.create(recursive: true);
          }
          if (mounted) {
            setState(() {
              _transferredFoldersCount++;
            });
          }
          queue.add({'remote': file.path, 'local': localDirPath});
        } else {
          // Check if file already exists
          String localFilePath = '$currentLocalPath/${file.name}';
          String fileName = file.name;

          if (File(localFilePath).existsSync()) {
            final action = await _handleConflict(file.name, false, true);

            if (action == 'skip') {
              continue; // Skip this file
            } else if (action == 'rename') {
              fileName = _getUniqueFileName(currentLocalPath, file.name);
              localFilePath = '$currentLocalPath/$fileName';
            }
            // If 'overwrite' or 'merge', use the original localFilePath
          }

          // File found - increase total and remaining count
          if (mounted) {
            setState(() {
              _totalFilesCount++;
              _remainingFilesCount++;
            });
          }

          // Download started
          if (mounted) {
            setState(() {
              _currentTransferFile = fileName;
              _transferProgress = 0;
              _transferTotal = file.size;
              _lastProgressBytes = 0;
              _lastProgressTime = DateTime.now();
            });
          }

          await _sftpService.downloadFile(
            file.path,
            localFilePath,
            onProgress: (received, total) {
              if (mounted) {
                final now = DateTime.now();
                final timeDiff = now.difference(_lastProgressTime).inMilliseconds;

                if (timeDiff > 100) { // Update rate every 100ms
                  final bytesDiff = received - _lastProgressBytes;
                  final rate = (bytesDiff * 1000) / timeDiff; // bytes per second

                  setState(() {
                    _transferProgress = received;
                    _transferTotal = total;
                    _transferRate = rate;
                    _lastProgressBytes = received;
                    _lastProgressTime = now;
                  });
                }
              }
            },
          );

          // File download complete - decrease remaining count
          if (mounted) {
            setState(() {
              _remainingFilesCount--;
              _transferredFilesCount++;
              _transferredTotalBytes += file.size;
            });
          }
        }
      }
    }
  }

  /// Shows a confirmation dialog before uploading a file to the remote server.
  ///
  /// If confirmed, initiates the upload process.
  Future<void> _confirmUploadFile(FileSystemEntity file) async {
    final l10n = AppLocalizations.of(context)!;
    final fileName = file.path.split('/').last;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.uploadFileTitle),
        content: Text(l10n.uploadFileContent(fileName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.upload),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _uploadFile(file);
    }
  }

  /// Uploads a single local file to the remote current directory.
  ///
  /// Handles file conflicts on the remote server and updates the transfer progress UI.
  /// [showStats] determines whether to show the transfer completion statistics panel.
  Future<void> _uploadFile(FileSystemEntity file, {bool showStats = true}) async {
    try {
      String fileName = file.path.split('/').last;
      final fileSize = await File(file.path).length();

      // Check if file already exists on remote
      final remoteFiles = await _sftpService.listDirectory(_remotePath);
      final fileExists = remoteFiles.any((f) => f.name == fileName);

      if (fileExists) {
        final action = await _handleConflict(fileName, false, false);

        if (action == 'skip') {
          return; // Skip this file
        } else if (action == 'rename') {
          fileName = (await _getUniqueRemoteFileName(_remotePath, fileName))!;
        }
        // If 'overwrite' or 'merge', use the original fileName
      }

      if (showStats && mounted) {
        setState(() {
          _isTransferring = true;
          _isUploading = true;
          _currentTransferFile = fileName;
          _transferProgress = 0;
          _transferTotal = fileSize;
          _remainingFilesCount = 1;
          _totalFilesCount = 1;
          _lastProgressBytes = 0;
          _lastProgressTime = DateTime.now();
          _transferRate = 0;
          _transferStartTime = DateTime.now();
          _transferredFilesCount = 0;
          _transferredFoldersCount = 0;
          _transferredTotalBytes = 0;
          _conflictResolutionChoice = null; // Reset for single file transfer
        });
      }

      final remotePath = _remotePath.endsWith('/')
          ? '$_remotePath$fileName'
          : _remotePath.isEmpty
              ? fileName
              : '$_remotePath/$fileName';

      await _sftpService.uploadFile(
        file.path,
        remotePath,
        onProgress: (sent, total) {
          if (mounted) {
            final now = DateTime.now();
            final timeDiff = now.difference(_lastProgressTime).inMilliseconds;

            if (timeDiff > 100) {
              final bytesDiff = sent - _lastProgressBytes;
              final rate = (bytesDiff * 1000) / timeDiff;

              setState(() {
                _transferProgress = sent;
                _transferTotal = total;
                _transferRate = rate;
                _lastProgressBytes = sent;
                _lastProgressTime = now;
              });
            }
          }
        },
      );

      if (mounted) {
        setState(() {
          if (showStats) {
            _remainingFilesCount--;
            _transferredFilesCount++;
            _transferredTotalBytes += fileSize;
          }
        });
      }

      await _loadRemoteFiles();

      if (mounted && showStats) {
        final elapsed = DateTime.now().difference(_transferStartTime!);
        setState(() {
          _isTransferring = false;
        });
        _showTransferStatistics('Upload', elapsed);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTransferring = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    }
  }

  /// Recursively uploads a local directory to the remote current directory.
  ///
  /// Checks for conflicts on the remote server and initiates a recursive upload.
  Future<void> _uploadDirectory(Directory directory, {bool showStats = true}) async {
    try {
      if (showStats && mounted) {
        setState(() {
          _isTransferring = true;
          _isUploading = true;
          _transferStartTime = DateTime.now();
          _transferredFilesCount = 0;
          _transferredFoldersCount = 0;
          _transferredTotalBytes = 0;
          _remainingFilesCount = 0;
          _totalFilesCount = 0;
          _conflictResolutionChoice = null; // Reset for batch transfer
        });
      }

      String dirName = directory.path.split('/').last;
      String remoteDirPath = _remotePath.endsWith('/')
          ? '$_remotePath$dirName'
          : _remotePath.isEmpty
              ? dirName
              : '$_remotePath/$dirName';

      // Check if directory already exists on remote
      final remoteFiles = await _sftpService.listDirectory(_remotePath);
      final dirExists = remoteFiles.any((f) => f.name == dirName && f.isDirectory);
      bool shouldCreateDir = !dirExists;

      if (dirExists) {
        final action = await _handleConflict(dirName, true, false);

        if (action == 'skip') {
          if (showStats && mounted) {
            setState(() {
              _isTransferring = false;
            });
          }
          return; // Skip this directory
        } else if (action == 'rename') {
          dirName = (await _getUniqueRemoteFileName(_remotePath, dirName))!;
          remoteDirPath = _remotePath.endsWith('/')
              ? '$_remotePath$dirName'
              : _remotePath.isEmpty
                  ? dirName
                  : '$_remotePath/$dirName';
          shouldCreateDir = true;
        } else if (action == 'overwrite') {
          // Delete existing directory
          await _sftpService.deleteDirectory(remoteDirPath);
          shouldCreateDir = true;
        }
        // If 'merge', shouldCreateDir stays false
      }

      // Create directory if needed
      if (shouldCreateDir) {
        await _sftpService.createDirectory(remoteDirPath);
        if (mounted) {
          setState(() {
            _transferredFoldersCount++;
          });
        }
      }

      await _uploadDirectoryRecursive(directory.path, remoteDirPath);
      await _loadRemoteFiles();

      if (mounted && showStats) {
        final elapsed = DateTime.now().difference(_transferStartTime!);
        setState(() {
          _isTransferring = false;
        });
        _showTransferStatistics('Upload', elapsed);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTransferring = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload directory: $e')),
        );
      }
    }
  }

  /// Recursively uploads a local directory and all its contents to the remote server.
  ///
  /// Creates remote directories as needed and uploads all files with progress tracking.
  Future<void> _uploadDirectoryRecursive(String localPath, String remotePath) async{
    final dir = Directory(localPath);
    final entities = await dir.list().toList();

    for (final entity in entities) {
      String name = entity.path.split('/').last;
      if (entity is Directory) {
        final remoteDirPath = '$remotePath/$name';
        await _sftpService.createDirectory(remoteDirPath);
        if (mounted) {
          setState(() {
            _transferredFoldersCount++;
          });
        }
        await _uploadDirectoryRecursive(entity.path, remoteDirPath);
      } else if (entity is File) {
        // Check if file already exists on remote
        final remoteFiles = await _sftpService.listDirectory(remotePath);
        final fileExists = remoteFiles.any((f) => f.name == name);

        if (fileExists) {
          final action = await _handleConflict(name, false, false);

          if (action == 'skip') {
            continue; // Skip this file
          } else if (action == 'rename') {
            name = (await _getUniqueRemoteFileName(remotePath, name))!;
          }
          // If 'overwrite' or 'merge', use the original name
        }

        final remoteFilePath = '$remotePath/$name';
        final fileSize = await entity.length();

        if (mounted) {
          setState(() {
            _currentTransferFile = name;
            _transferProgress = 0;
            _transferTotal = fileSize;
            _lastProgressBytes = 0;
            _lastProgressTime = DateTime.now();
          });
        }

        await _sftpService.uploadFile(
          entity.path,
          remoteFilePath,
          onProgress: (sent, total) {
            if (mounted) {
              final now = DateTime.now();
              final timeDiff = now.difference(_lastProgressTime).inMilliseconds;

              if (timeDiff > 100) {
                final bytesDiff = sent - _lastProgressBytes;
                final rate = (bytesDiff * 1000) / timeDiff;

                setState(() {
                  _transferProgress = sent;
                  _transferTotal = total;
                  _transferRate = rate;
                  _lastProgressBytes = sent;
                  _lastProgressTime = now;
                });
              }
            }
          },
        );

        if (mounted) {
          setState(() {
            _transferredFilesCount++;
            _transferredTotalBytes += fileSize;
          });
        }
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = _isConnecting
        ? const Center(child: CircularProgressIndicator())
        : _errorMessage != null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _initialize,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              )
            : Stack(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildLocalPane(),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(
                        child: _buildRemotePane(),
                      ),
                    ],
                  ),
                  if (_isTransferring)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 8,
                              offset: const Offset(0, -2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isUploading ? Icons.upload : Icons.download,
                              size: 18,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: Text(
                                _currentTransferFile,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 3,
                              child: LinearProgressIndicator(
                                value: _transferTotal > 0 ? _transferProgress / _transferTotal : 0,
                                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                                valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatTransferRate(_transferRate),
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '$_remainingFilesCount/$_totalFilesCount',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_showTransferStats)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.tertiaryContainer,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 8,
                              offset: const Offset(0, -2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 18,
                              color: theme.colorScheme.tertiary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '$_transferOperation Complete',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onTertiaryContainer,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              'Files: $_transferredFilesCount',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onTertiaryContainer,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Folders: $_transferredFoldersCount',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onTertiaryContainer,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Size: ${_formatFileSize(_transferredTotalBytes)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onTertiaryContainer,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Time: ${_formatDuration(_transferElapsed)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onTertiaryContainer,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: Icon(Icons.close, size: 16),
                              color: theme.colorScheme.onTertiaryContainer,
                              onPressed: () {
                                setState(() {
                                  _showTransferStats = false;
                                });
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );

    if (!widget.showAppBar) {
      return body;
    }

    IconData getOSIcon() {
      switch (widget.host.osType) {
        case OSType.linux:
          return Icons.dns;
        case OSType.windows:
          return Icons.window;
        case OSType.macos:
          return Icons.laptop_mac;
        case OSType.unix:
          return Icons.storage;
        case OSType.unknown:
          return Icons.computer;
      }
    }

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Row(
          children: [
            Icon(getOSIcon(), size: 24),
            const SizedBox(width: 8),
            Text('${widget.host.name}'),
          ],
        ),
      ),
      body: body,
    );
  }

  Widget _buildLocalPane() {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final filteredLocalFiles = _localFiles.where((file) {
      final name = file.path.split('/').last;
      if (!widget.showHiddenFiles && name.startsWith('.')) {
        return false;
      }
      return true;
    }).toList()
      ..sort((a, b) {
        final aIsDir = a is Directory;
        final bIsDir = b is Directory;

        if (aIsDir && !bIsDir) return -1;
        if (!aIsDir && bIsDir) return 1;

        final aName = a.path.split('/').last.toLowerCase();
        final bName = b.path.split('/').last.toLowerCase();
        return aName.compareTo(bName);
      });

    final hasSelection = _selectedLocalFiles.isNotEmpty;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          color: theme.colorScheme.primaryContainer,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final showAllButtons = constraints.maxWidth > 600;

              return Row(
                children: [
                  Icon(Icons.computer, size: 20, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    l10n.local,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 8),
                  if (showAllButtons) ...[
                    IconButton(
                      icon: Icon(Icons.create_new_folder, size: 18),
                      color: theme.colorScheme.primary,
                      onPressed: () => _createLocalDirectory(),
                      tooltip: l10n.newFolder,
                    ),
                    IconButton(
                      icon: Icon(Icons.upload, size: 18),
                      color: hasSelection ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                      onPressed: hasSelection ? () => _uploadSelectedFiles() : null,
                      tooltip: l10n.upload,
                    ),
                    IconButton(
                      icon: Icon(Icons.drive_file_rename_outline, size: 18),
                      color: _selectedLocalFiles.length == 1 ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                      onPressed: _selectedLocalFiles.length == 1 ? () => _renameLocalFile() : null,
                      tooltip: l10n.rename,
                    ),
                    IconButton(
                      icon: Icon(Icons.copy, size: 18),
                      color: hasSelection ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                      onPressed: hasSelection ? () => _copyLocalFiles() : null,
                      tooltip: l10n.copy,
                    ),
                    IconButton(
                      icon: Icon(Icons.drive_file_move, size: 18),
                      color: hasSelection ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                      onPressed: hasSelection ? () => _moveLocalFiles() : null,
                      tooltip: l10n.move,
                    ),
                    IconButton(
                      icon: Icon(Icons.delete, size: 18),
                      color: hasSelection ? Colors.red : theme.colorScheme.onSurfaceVariant,
                      onPressed: hasSelection ? () => _deleteLocalFiles() : null,
                      tooltip: l10n.delete,
                    ),
                  ] else
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, size: 20, color: theme.colorScheme.primary),
                      onSelected: (value) {
                        switch (value) {
                          case 'new_folder':
                            _createLocalDirectory();
                            break;
                          case 'upload':
                            if (hasSelection) _uploadSelectedFiles();
                            break;
                          case 'rename':
                            if (_selectedLocalFiles.length == 1) _renameLocalFile();
                            break;
                          case 'copy':
                            if (hasSelection) _copyLocalFiles();
                            break;
                          case 'move':
                            if (hasSelection) _moveLocalFiles();
                            break;
                          case 'delete':
                            if (hasSelection) _deleteLocalFiles();
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(value: 'new_folder', child: Text(l10n.newFolder)),
                        PopupMenuItem(
                          value: 'upload',
                          enabled: hasSelection,
                          child: Text(l10n.upload),
                        ),
                        PopupMenuItem(
                          value: 'rename',
                          enabled: _selectedLocalFiles.length == 1,
                          child: Text(l10n.rename),
                        ),
                        PopupMenuItem(
                          value: 'copy',
                          enabled: hasSelection,
                          child: Text(l10n.copy),
                        ),
                        PopupMenuItem(
                          value: 'move',
                          enabled: hasSelection,
                          child: Text(l10n.move),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          enabled: hasSelection,
                          child: Text(l10n.delete),
                        ),
                      ],
                    ),
                  IconButton(
                    icon: Icon(Icons.arrow_upward, size: 20, color: theme.colorScheme.primary),
                    onPressed: () {
                      if (_localPath.isNotEmpty) {
                        final parent = Directory(_localPath).parent;
                        _navigateLocal(parent.path);
                      }
                    },
                  ),
                ],
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: theme.colorScheme.surfaceContainerHighest,
          width: double.infinity,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: _buildLocalBreadcrumb(),
          ),
        ),
        Expanded(
          child: DragTarget<List<SftpFileInfo>>(
            onAcceptWithDetails: (details) {
              final remoteFiles = details.data;
              if (remoteFiles.length == 1) {
                final remoteFile = remoteFiles.first;
                if (!remoteFile.isDirectory) {
                  _downloadFile(remoteFile);
                } else {
                  _downloadDirectory(remoteFile);
                }
              } else {
                _downloadMultipleFiles(remoteFiles);
              }
            },
            builder: (context, candidateData, rejectedData) {
              return Container(
                color: candidateData.isNotEmpty
                    ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
                    : null,
                child: ListView.builder(
                  itemCount: filteredLocalFiles.length,
                  itemBuilder: (context, index) {
                    final file = filteredLocalFiles[index];
                    final isDirectory = file is Directory;
                    final name = file.path.split('/').last;

                    final isSelected = _selectedLocalFiles.contains(file.path);
                    final selectedFiles = _selectedLocalFiles.isNotEmpty
                        ? filteredLocalFiles.where((f) => _selectedLocalFiles.contains(f.path)).toList()
                        : [file];

                    return LongPressDraggable<List<FileSystemEntity>>(
                      data: selectedFiles,
                      delay: const Duration(milliseconds: 500),
                      feedback: Material(
                        elevation: 4,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          color: theme.colorScheme.primaryContainer,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isDirectory ? Icons.folder : Icons.insert_drive_file,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(selectedFiles.length > 1 ? '${selectedFiles.length} items' : name),
                            ],
                          ),
                        ),
                      ),
                      childWhenDragging: Opacity(
                        opacity: 0.5,
                        child: ListTile(
                          selected: isSelected,
                          selectedTileColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                          leading: Icon(
                            isDirectory ? Icons.folder : Icons.insert_drive_file,
                            color: isDirectory ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                          ),
                          title: Text(name),
                        ),
                      ),
                      child: GestureDetector(
                        onDoubleTap: () {
                          if (isDirectory) {
                            _navigateLocal(file.path);
                          } else {
                            _confirmUploadFile(file);
                          }
                        },
                        onLongPressStart: (details) {
                          // Select the item if not already selected
                          if (!isSelected) {
                            setState(() {
                              _selectedLocalFiles.clear();
                              _selectedLocalFiles.add(file.path);
                              _lastSelectedLocalIndex = index;
                            });
                          }
                          _showLocalContextMenu(details.globalPosition, file);
                        },
                        onSecondaryTapDown: (details) {
                          // Select the item if not already selected
                          if (!isSelected) {
                            setState(() {
                              _selectedLocalFiles.clear();
                              _selectedLocalFiles.add(file.path);
                              _lastSelectedLocalIndex = index;
                            });
                          }
                          _showLocalContextMenu(details.globalPosition, file);
                        },
                        child: ListTile(
                          selected: isSelected,
                          selectedTileColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                          leading: Icon(
                            isDirectory ? Icons.folder : Icons.insert_drive_file,
                            color: isDirectory ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                          ),
                          title: Text(name),
                          onTap: () {
                            setState(() {
                                                              if (_isShiftPressed && _lastSelectedLocalIndex != null) {
                                                                // Shift+Click: Range selection
                                                                final start = _lastSelectedLocalIndex! < index ? _lastSelectedLocalIndex! : index;
                                                                final end = _lastSelectedLocalIndex! < index ? index : _lastSelectedLocalIndex!;
                              
                                                                for (int i = start; i <= end; i++) {
                                                                  _selectedLocalFiles.add(filteredLocalFiles[i].path);
                                                                }
                                                                _lastSelectedLocalIndex = index;
                                                              } else if (_isControlPressed) {
                                                                // Ctrl+Click: Toggle selection
                                                                if (isSelected) {
                                                                  _selectedLocalFiles.remove(file.path);
                                                                } else {
                                                                  _selectedLocalFiles.add(file.path);
                                                                }
                                                                _lastSelectedLocalIndex = index;
                                                              } else {
                                                                // Regular Click: Single selection
                                                                _selectedLocalFiles.clear();
                                                                _selectedLocalFiles.add(file.path);
                                                                _lastSelectedLocalIndex = index;
                                                              }                            });
                          },
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRemotePane() {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final filteredRemoteFiles = _remoteFiles.where((file) {
      if (!widget.showHiddenFiles && file.name.startsWith('.')) {
        return false;
      }
      return true;
    }).toList()
      ..sort((a, b) {
        if (a.isDirectory && !b.isDirectory) return -1;
        if (!a.isDirectory && b.isDirectory) return 1;

        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    final hasSelection = _selectedRemoteFiles.isNotEmpty;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          color: theme.colorScheme.secondaryContainer,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final showAllButtons = constraints.maxWidth > 600;

              return Row(
                children: [
                  Icon(Icons.cloud, size: 20, color: theme.colorScheme.secondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Text(
                        l10n.remote(widget.host.name),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (showAllButtons) ...[
                    IconButton(
                      icon: Icon(Icons.create_new_folder, size: 18),
                      color: theme.colorScheme.secondary,
                      onPressed: () => _createRemoteDirectory(),
                      tooltip: l10n.newFolder,
                    ),
                    IconButton(
                      icon: Icon(Icons.download, size: 18),
                      color: hasSelection ? theme.colorScheme.secondary : theme.colorScheme.onSurfaceVariant,
                      onPressed: hasSelection ? () => _downloadSelectedFiles() : null,
                      tooltip: l10n.download,
                    ),
                    IconButton(
                      icon: Icon(Icons.drive_file_rename_outline, size: 18),
                      color: _selectedRemoteFiles.length == 1 ? theme.colorScheme.secondary : theme.colorScheme.onSurfaceVariant,
                      onPressed: _selectedRemoteFiles.length == 1 ? () => _renameRemoteFile() : null,
                      tooltip: l10n.rename,
                    ),
                    IconButton(
                      icon: Icon(Icons.copy, size: 18),
                      color: hasSelection ? theme.colorScheme.secondary : theme.colorScheme.onSurfaceVariant,
                      onPressed: hasSelection ? () => _copyRemoteFiles() : null,
                      tooltip: l10n.copy,
                    ),
                    IconButton(
                      icon: Icon(Icons.drive_file_move, size: 18),
                      color: hasSelection ? theme.colorScheme.secondary : theme.colorScheme.onSurfaceVariant,
                      onPressed: hasSelection ? () => _moveRemoteFiles() : null,
                      tooltip: l10n.move,
                    ),
                    IconButton(
                      icon: Icon(Icons.delete, size: 18),
                      color: hasSelection ? Colors.red : theme.colorScheme.onSurfaceVariant,
                      onPressed: hasSelection ? () => _deleteRemoteFiles() : null,
                      tooltip: l10n.delete,
                    ),
                  ] else
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, size: 20, color: theme.colorScheme.secondary),
                      onSelected: (value) {
                        switch (value) {
                          case 'new_folder':
                            _createRemoteDirectory();
                            break;
                          case 'download':
                            if (hasSelection) _downloadSelectedFiles();
                            break;
                          case 'rename':
                            if (_selectedRemoteFiles.length == 1) _renameRemoteFile();
                            break;
                          case 'copy':
                            if (hasSelection) _copyRemoteFiles();
                            break;
                          case 'move':
                            if (hasSelection) _moveRemoteFiles();
                            break;
                          case 'delete':
                            if (hasSelection) _deleteRemoteFiles();
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(value: 'new_folder', child: Text(l10n.newFolder)),
                        PopupMenuItem(
                          value: 'download',
                          enabled: hasSelection,
                          child: Text(l10n.download),
                        ),
                        PopupMenuItem(
                          value: 'rename',
                          enabled: _selectedRemoteFiles.length == 1,
                          child: Text(l10n.rename),
                        ),
                        PopupMenuItem(
                          value: 'copy',
                          enabled: hasSelection,
                          child: Text(l10n.copy),
                        ),
                        PopupMenuItem(
                          value: 'move',
                          enabled: hasSelection,
                          child: Text(l10n.move),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          enabled: hasSelection,
                          child: Text(l10n.delete),
                        ),
                      ],
                    ),
                  IconButton(
                    icon: Icon(Icons.arrow_upward, size: 20, color: theme.colorScheme.secondary),
                    onPressed: () {
                      if (_remotePath.isEmpty) {
                        return;
                      }
                      if (_remotePath == '/') {
                        return;
                      }

                      final parts = _remotePath.split('/').where((p) => p.isNotEmpty).toList();
                      if (parts.isEmpty) {
                        _navigateRemote('/');
                      } else {
                        parts.removeLast();
                        final parent = parts.isEmpty ? '/' : '/${parts.join('/')}';
                        _navigateRemote(parent);
                      }
                    },
                  ),
                ],
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: theme.colorScheme.surfaceContainerHighest,
          width: double.infinity,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: _buildRemoteBreadcrumb(),
          ),
        ),
        Expanded(
          child: DragTarget<List<FileSystemEntity>>(
            onAcceptWithDetails: (details) {
              final localFiles = details.data;
              for (final localFile in localFiles) {
                if (localFile is File) {
                  _uploadFile(localFile);
                } else if (localFile is Directory) {
                  _uploadDirectory(localFile);
                }
              }
            },
            builder: (context, candidateData, rejectedData) {
              return Container(
                color: candidateData.isNotEmpty
                    ? theme.colorScheme.secondaryContainer.withValues(alpha: 0.3)
                    : null,
                child: ListView.builder(
                  itemCount: filteredRemoteFiles.length,
                  itemBuilder: (context, index) {
                    final file = filteredRemoteFiles[index];

                    // Determine icon based on type
                    IconData iconData;
                    Color iconColor;

                    if (file.isSymlink) {
                      iconData = Icons.link;
                      iconColor = file.isDirectory ? theme.colorScheme.secondary : theme.colorScheme.tertiary;
                    } else if (file.isDirectory) {
                      iconData = Icons.folder;
                      iconColor = theme.colorScheme.secondary;
                    } else {
                      iconData = Icons.insert_drive_file;
                      iconColor = theme.colorScheme.onSurfaceVariant;
                    }

                    final isSelected = _selectedRemoteFiles.contains(file.path);
                    final selectedFiles = _selectedRemoteFiles.isNotEmpty
                        ? filteredRemoteFiles.where((f) => _selectedRemoteFiles.contains(f.path)).toList()
                        : [file];

                    return LongPressDraggable<List<SftpFileInfo>>(
                      data: selectedFiles,
                      delay: const Duration(milliseconds: 500),
                      feedback: Material(
                        elevation: 4,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          color: theme.colorScheme.secondaryContainer,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(iconData, color: theme.colorScheme.secondary),
                              const SizedBox(width: 8),
                              Text(selectedFiles.length > 1 ? '${selectedFiles.length} items' : file.name),
                            ],
                          ),
                        ),
                      ),
                      childWhenDragging: Opacity(
                        opacity: 0.5,
                        child: ListTile(
                          selected: isSelected,
                          selectedTileColor: theme.colorScheme.secondaryContainer.withValues(alpha: 0.3),
                          leading: Icon(iconData, color: iconColor),
                          title: Text(file.name),
                        ),
                      ),
                      child: GestureDetector(
                        onDoubleTap: () {
                          if (file.isDirectory) {
                            _navigateRemote(file.path);
                          } else {
                            _confirmDownloadFile(file);
                          }
                        },
                        onLongPressStart: (details) {
                          // Select the item if not already selected
                          if (!isSelected) {
                            setState(() {
                              _selectedRemoteFiles.clear();
                              _selectedRemoteFiles.add(file.path);
                              _lastSelectedRemoteIndex = index;
                            });
                          }
                          _showRemoteContextMenu(details.globalPosition, file);
                        },
                        onSecondaryTapDown: (details) {
                          // Select the item if not already selected
                          if (!isSelected) {
                            setState(() {
                              _selectedRemoteFiles.clear();
                              _selectedRemoteFiles.add(file.path);
                              _lastSelectedRemoteIndex = index;
                            });
                          }
                          _showRemoteContextMenu(details.globalPosition, file);
                        },
                        child: ListTile(
                          selected: isSelected,
                          selectedTileColor: theme.colorScheme.secondaryContainer.withValues(alpha: 0.3),
                          leading: Icon(iconData, color: iconColor),
                          title: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  file.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (file.isSymlink)
                                Padding(
                                  padding: const EdgeInsets.only(left: 4),
                                  child: Icon(
                                    Icons.arrow_forward,
                                    size: 12,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                          subtitle: !file.isDirectory
                              ? Text(_formatFileSize(file.size))
                              : null,
                          onTap: () {
                            setState(() {
                                                              if (_isShiftPressed && _lastSelectedRemoteIndex != null) {
                                                                // Shift+Click: Range selection
                                                                final start = _lastSelectedRemoteIndex! < index ? _lastSelectedRemoteIndex! : index;
                                                                final end = _lastSelectedRemoteIndex! < index ? index : _lastSelectedRemoteIndex!;
                              
                                                                for (int i = start; i <= end; i++) {
                                                                  _selectedRemoteFiles.add(filteredRemoteFiles[i].path);
                                                                }
                                                                _lastSelectedRemoteIndex = index;
                                                              } else if (_isControlPressed) {
                                                                // Ctrl+Click: Toggle selection
                                                                if (isSelected) {
                                                                  _selectedRemoteFiles.remove(file.path);
                                                                } else {
                                                                  _selectedRemoteFiles.add(file.path);
                                                                }
                                                                _lastSelectedRemoteIndex = index;
                                                              } else {
                                                                // Regular Click: Single selection
                                                                _selectedRemoteFiles.clear();
                                                                _selectedRemoteFiles.add(file.path);
                                                                _lastSelectedRemoteIndex = index;
                                                              }                            });
                          },
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Formats a byte count into a human-readable file size string.
  ///
  /// Returns sizes in B, KB, MB, or GB depending on the magnitude.
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Formats a transfer rate in bytes per second into a human-readable string.
  ///
  /// Returns rates in B/s, KB/s, or MB/s depending on the magnitude.
  String _formatTransferRate(double bytesPerSecond) {
    if (bytesPerSecond < 1024) {
      return '${bytesPerSecond.toStringAsFixed(0)} B/s';
    } else if (bytesPerSecond < 1024 * 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    } else {
      return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    }
  }

  /// Uploads all currently selected local files and directories to the remote server.
  ///
  /// Handles both individual files and directories with their contents.
  Future<void> _uploadSelectedFiles() async {
    final selectedFiles = _localFiles
        .where((f) => _selectedLocalFiles.contains(f.path))
        .toList();

    if (selectedFiles.isEmpty) return;

    setState(() {
      _isTransferring = true;
      _isUploading = true;
      _transferStartTime = DateTime.now();
      _transferredFilesCount = 0;
      _transferredFoldersCount = 0;
      _transferredTotalBytes = 0;
      _remainingFilesCount = 0;
      _totalFilesCount = 0;
      _conflictResolutionChoice = null; // Reset for batch transfer
    });

    try {
      for (final file in selectedFiles) {
        if (file is Directory) {
          await _uploadDirectory(file, showStats: false);
        } else {
          await _uploadFile(file, showStats: false);
        }
      }

      await _loadRemoteFiles();

      if (mounted) {
        final elapsed = DateTime.now().difference(_transferStartTime!);
        setState(() {
          _isTransferring = false;
          _selectedLocalFiles.clear();
          _lastSelectedLocalIndex = null;
        });
        _showTransferStatistics('Upload', elapsed);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTransferring = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    }
  }

  Future<void> _copyLocalFiles() async {
    final controller = TextEditingController(text: _localPath);
    final destinationPath = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Copy To'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Destination Path',
            hintText: 'Enter destination directory path',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Copy'),
          ),
        ],
      ),
    );

    if (destinationPath != null && destinationPath.trim().isNotEmpty && mounted) {
      try {
        final selectedFiles = _localFiles
            .where((f) => _selectedLocalFiles.contains(f.path))
            .toList();

        for (final file in selectedFiles) {
          final fileName = file.path.split('/').last;
          final destPath = '${destinationPath.trim()}/$fileName';

          if (file is Directory) {
            await _copyDirectoryRecursive(file.path, destPath);
          } else {
            await File(file.path).copy(destPath);
          }
        }

        await _loadLocalFiles();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Copied ${selectedFiles.length} items')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Copy failed: $e')),
          );
        }
      }
    }
  }

  Future<void> _copyDirectoryRecursive(String sourcePath, String destPath) async {
    final sourceDir = Directory(sourcePath);
    final destDir = Directory(destPath);

    if (!await destDir.exists()) {
      await destDir.create(recursive: true);
    }

    final entities = await sourceDir.list().toList();
    for (final entity in entities) {
      final fileName = entity.path.split('/').last;
      final newDestPath = '$destPath/$fileName';

      if (entity is Directory) {
        await _copyDirectoryRecursive(entity.path, newDestPath);
      } else if (entity is File) {
        await entity.copy(newDestPath);
      }
    }
  }

  Future<void> _moveLocalFiles() async {
    final controller = TextEditingController(text: _localPath);
    final destinationPath = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move To'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Destination Path',
            hintText: 'Enter destination directory path',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Move'),
          ),
        ],
      ),
    );

    if (destinationPath != null && destinationPath.trim().isNotEmpty && mounted) {
      try {
        final selectedFiles = _localFiles
            .where((f) => _selectedLocalFiles.contains(f.path))
            .toList();

        for (final file in selectedFiles) {
          final fileName = file.path.split('/').last;
          final destPath = '${destinationPath.trim()}/$fileName';

          if (file is Directory) {
            await Directory(file.path).rename(destPath);
          } else {
            await File(file.path).rename(destPath);
          }
        }

        setState(() {
          _selectedLocalFiles.clear();
          _lastSelectedLocalIndex = null;
        });

        await _loadLocalFiles();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Moved ${selectedFiles.length} items')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Move failed: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteLocalFiles() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Files'),
        content: Text('Delete ${_selectedLocalFiles.length} selected items?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final selectedFiles = _localFiles
            .where((f) => _selectedLocalFiles.contains(f.path))
            .toList();

        for (final file in selectedFiles) {
          if (file is Directory) {
            await file.delete(recursive: true);
          } else {
            await File(file.path).delete();
          }
        }

        setState(() {
          _selectedLocalFiles.clear();
          _lastSelectedLocalIndex = null;
        });

        await _loadLocalFiles();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Deleted ${selectedFiles.length} items')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Delete failed: $e')),
          );
        }
      }
    }
  }

  Future<void> _createLocalDirectory() async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final folderName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.newFolder),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: l10n.folderName,
            hintText: l10n.enterFolderName,
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(l10n.create),
          ),
        ],
      ),
    );

    if (folderName != null && folderName.trim().isNotEmpty && mounted) {
      try {
        final newDirPath = '$_localPath/${folderName.trim()}';
        await Directory(newDirPath).create();
        await _loadLocalFiles();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Created folder: ${folderName.trim()}')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.failedToCreateDirectory(e))),
          );
        }
      }
    }
  }

  Future<void> _renameLocalFile() async {
    final l10n = AppLocalizations.of(context)!;
    if (_selectedLocalFiles.length != 1) return;

    final selectedPath = _selectedLocalFiles.first;
    final selectedFile = _localFiles.firstWhere((f) => f.path == selectedPath);
    final oldName = selectedFile.path.split('/').last;
    final isDirectory = selectedFile is Directory;

    final controller = TextEditingController(text: oldName);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${l10n.renameTitle} ${isDirectory ? l10n.folder : l10n.file}'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: l10n.newName,
            hintText: l10n.enterNewName,
          ),
          autofocus: true,
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(l10n.rename),
          ),
        ],
      ),
    );

    if (newName != null && newName.trim().isNotEmpty && newName != oldName && mounted) {
      try {
        final parentPath = Directory(selectedPath).parent.path;
        final newPath = '$parentPath/${newName.trim()}';

        if (isDirectory) {
          await Directory(selectedPath).rename(newPath);
        } else {
          await File(selectedPath).rename(newPath);
        }

        setState(() {
          _selectedLocalFiles.clear();
          _lastSelectedLocalIndex = null;
        });

        await _loadLocalFiles();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Renamed to: ${newName.trim()}')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.failedToRename(e))),
          );
        }
      }
    }
  }

  void _showLocalContextMenu(Offset position, FileSystemEntity file) async {
    final l10n = AppLocalizations.of(context)!;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final isDirectory = file is Directory;

    await showMenu(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem(
          child: Row(
            children: [
              const Icon(Icons.upload, size: 18),
              const SizedBox(width: 8),
              Text(l10n.upload),
            ],
          ),
          onTap: () {
            Future.delayed(Duration.zero, () {
              if (isDirectory) {
                _uploadDirectory(file as Directory);
              } else {
                _confirmUploadFile(file);
              }
            });
          },
        ),
        if (_selectedLocalFiles.length == 1)
          PopupMenuItem(
            child: Row(
              children: [
                const Icon(Icons.drive_file_rename_outline, size: 18),
                const SizedBox(width: 8),
                Text(l10n.rename),
              ],
            ),
            onTap: () {
              Future.delayed(Duration.zero, () => _renameLocalFile());
            },
          ),
        PopupMenuItem(
          child: Row(
            children: [
              const Icon(Icons.copy, size: 18),
              const SizedBox(width: 8),
              Text(l10n.copy),
            ],
          ),
          onTap: () {
            Future.delayed(Duration.zero, () => _copyLocalFiles());
          },
        ),
        PopupMenuItem(
          child: Row(
            children: [
              const Icon(Icons.drive_file_move, size: 18),
              const SizedBox(width: 8),
              Text(l10n.move),
            ],
          ),
          onTap: () {
            Future.delayed(Duration.zero, () => _moveLocalFiles());
          },
        ),
        PopupMenuItem(
          child: Row(
            children: [
              const Icon(Icons.delete, size: 18, color: Colors.red),
              const SizedBox(width: 8),
              Text(l10n.delete, style: const TextStyle(color: Colors.red)),
            ],
          ),
          onTap: () {
            Future.delayed(Duration.zero, () => _deleteLocalFiles());
          },
        ),
      ],
    );
  }

  // Remote file actions
  Future<void> _downloadSelectedFiles() async {
    final selectedFiles = _remoteFiles
        .where((f) => _selectedRemoteFiles.contains(f.path))
        .toList();

    if (selectedFiles.length == 1) {
      final file = selectedFiles.first;
      if (file.isDirectory) {
        await _downloadDirectory(file);
      } else {
        await _downloadFile(file);
      }
    } else {
      await _downloadMultipleFiles(selectedFiles);
    }

    setState(() {
      _selectedRemoteFiles.clear();
      _lastSelectedRemoteIndex = null;
    });
  }

  Future<void> _copyRemoteFiles() async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: _remotePath);
    final destinationPath = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.copyTo),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: l10n.destinationPath,
            hintText: l10n.enterDestinationPath,
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(l10n.copy),
          ),
        ],
      ),
    );

    if (destinationPath != null && destinationPath.trim().isNotEmpty && mounted) {
      try {
        final selectedFiles = _remoteFiles
            .where((f) => _selectedRemoteFiles.contains(f.path))
            .toList();

        for (final file in selectedFiles) {
          final destPath = destinationPath.trim().endsWith('/')
              ? '${destinationPath.trim()}${file.name}'
              : '${destinationPath.trim()}/${file.name}';

          if (file.isDirectory) {
            await _sftpService.copyDirectoryRecursive(file.path, destPath);
          } else {
            await _sftpService.copyFile(file.path, destPath);
          }
        }

        await _loadRemoteFiles();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.copiedItems(selectedFiles.length))),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.copyFailed(e))),
          );
        }
      }
    }
  }

  Future<void> _moveRemoteFiles() async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: _remotePath);
    final destinationPath = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.moveTo),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: l10n.destinationPath,
            hintText: l10n.enterDestinationPath,
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(l10n.move),
          ),
        ],
      ),
    );

    if (destinationPath != null && destinationPath.trim().isNotEmpty && mounted) {
      try {
        final selectedFiles = _remoteFiles
            .where((f) => _selectedRemoteFiles.contains(f.path))
            .toList();

        for (final file in selectedFiles) {
          final destPath = destinationPath.trim().endsWith('/')
              ? '${destinationPath.trim()}${file.name}'
              : '${destinationPath.trim()}/${file.name}';

          await _sftpService.renameFile(file.path, destPath);
        }

        setState(() {
          _selectedRemoteFiles.clear();
          _lastSelectedRemoteIndex = null;
        });

        await _loadRemoteFiles();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Moved ${selectedFiles.length} items')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Move failed: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteRemoteFiles() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteHostTitle), // Using generic delete title
        content: Text('Delete ${_selectedRemoteFiles.length} selected items?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final selectedFiles = _remoteFiles
            .where((f) => _selectedRemoteFiles.contains(f.path))
            .toList();

        for (final file in selectedFiles) {
          if (file.isDirectory) {
            await _sftpService.deleteDirectory(file.path);
          } else {
            await _sftpService.deleteFile(file.path);
          }
        }

        setState(() {
          _selectedRemoteFiles.clear();
          _lastSelectedRemoteIndex = null;
        });

        await _loadRemoteFiles();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.deleted('${selectedFiles.length} items'))),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.deleteFailed(e))),
          );
        }
      }
    }
  }

  Future<void> _createRemoteDirectory() async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final folderName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.newFolder),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: l10n.folderName,
            hintText: l10n.enterFolderName,
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(l10n.create),
          ),
        ],
      ),
    );

    if (folderName != null && folderName.trim().isNotEmpty && mounted) {
      try {
        final newDirPath = _remotePath.endsWith('/')
            ? '$_remotePath${folderName.trim()}'
            : _remotePath.isEmpty
                ? folderName.trim()
                : '$_remotePath/${folderName.trim()}';

        await _sftpService.createDirectory(newDirPath);
        await _loadRemoteFiles();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Created folder: ${folderName.trim()}')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.failedToCreateDirectory(e))),
          );
        }
      }
    }
  }

  Future<void> _renameRemoteFile() async {
    final l10n = AppLocalizations.of(context)!;
    if (_selectedRemoteFiles.length != 1) return;

    final selectedPath = _selectedRemoteFiles.first;
    final selectedFile = _remoteFiles.firstWhere((f) => f.path == selectedPath);
    final oldName = selectedFile.name;
    final isDirectory = selectedFile.isDirectory;

    final controller = TextEditingController(text: oldName);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${l10n.renameTitle} ${isDirectory ? l10n.folder : l10n.file}'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: l10n.newName,
            hintText: l10n.enterNewName,
          ),
          autofocus: true,
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(l10n.rename),
          ),
        ],
      ),
    );

    if (newName != null && newName.trim().isNotEmpty && newName != oldName && mounted) {
      try {
        final newPath = _remotePath.endsWith('/')
            ? '$_remotePath${newName.trim()}'
            : _remotePath.isEmpty
                ? newName.trim()
                : '$_remotePath/${newName.trim()}';

        await _sftpService.renameFile(selectedPath, newPath);

        setState(() {
          _selectedRemoteFiles.clear();
          _lastSelectedRemoteIndex = null;
        });

        await _loadRemoteFiles();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Renamed to: ${newName.trim()}')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.failedToRename(e))),
          );
        }
      }
    }
  }

  void _showRemoteContextMenu(Offset position, SftpFileInfo file) async {
    final l10n = AppLocalizations.of(context)!;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final isDirectory = file.isDirectory;

    await showMenu(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem(
          child: Row(
            children: [
              const Icon(Icons.download, size: 18),
              const SizedBox(width: 8),
              Text(l10n.download),
            ],
          ),
          onTap: () {
            Future.delayed(Duration.zero, () {
              if (isDirectory) {
                _downloadDirectory(file);
              } else {
                _downloadFile(file);
              }
            });
          },
        ),
        if (_selectedRemoteFiles.length == 1)
          PopupMenuItem(
            child: Row(
              children: [
                const Icon(Icons.drive_file_rename_outline, size: 18),
                const SizedBox(width: 8),
                Text(l10n.rename),
              ],
            ),
            onTap: () {
              Future.delayed(Duration.zero, () => _renameRemoteFile());
            },
          ),
        PopupMenuItem(
          child: Row(
            children: [
              const Icon(Icons.copy, size: 18),
              const SizedBox(width: 8),
              Text(l10n.copy),
            ],
          ),
          onTap: () {
            Future.delayed(Duration.zero, () => _copyRemoteFiles());
          },
        ),
        PopupMenuItem(
          child: Row(
            children: [
              const Icon(Icons.drive_file_move, size: 18),
              const SizedBox(width: 8),
              Text(l10n.move),
            ],
          ),
          onTap: () {
            Future.delayed(Duration.zero, () => _moveRemoteFiles());
          },
        ),
        PopupMenuItem(
          child: Row(
            children: [
              const Icon(Icons.delete, size: 18, color: Colors.red),
              const SizedBox(width: 8),
              Text(l10n.delete, style: const TextStyle(color: Colors.red)),
            ],
          ),
          onTap: () {
            Future.delayed(Duration.zero, () => _deleteRemoteFiles());
          },
        ),
      ],
    );
  }

  /// Handles file or directory naming conflicts during transfer operations.
  ///
  /// Shows a dialog with options: merge (directories only), overwrite, rename, or skip.
  /// Returns the user's choice as a string, or applies a previously chosen "apply to all" option.
  Future<String?> _handleConflict(String itemName, bool isDirectory, bool isDownload) async {
    // If user already chose an option for all items, apply it
    if (_conflictResolutionChoice != null) {
      return _conflictResolutionChoice;
    }

    final l10n = AppLocalizations.of(context)!;
    final itemType = isDirectory ? l10n.folder : l10n.file;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(isDirectory ? l10n.folderConflict : l10n.fileConflict),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.conflictContent(itemType, itemName)),
            const SizedBox(height: 16),
            Text(l10n.conflictQuestion),
          ],
        ),
        actions: [
          if (isDirectory)
            TextButton(
              onPressed: () => Navigator.pop(context, {'action': 'merge', 'applyToAll': false}),
              child: Text(l10n.merge),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context, {'action': 'overwrite', 'applyToAll': false}),
            child: Text(l10n.overwrite),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, {'action': 'rename', 'applyToAll': false}),
            child: Text(l10n.rename),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, {'action': 'skip', 'applyToAll': false}),
            child: Text(l10n.skip),
          ),
        ],
      ),
    );

    if (result != null) {
      if (result['applyToAll'] == true) {
        _conflictResolutionChoice = result['action'];
      }
      return result['action'];
    }

    return 'skip'; // Default to skip if dialog is dismissed
  }

  /// Generates a unique filename by appending a number if the file already exists locally.
  ///
  /// For example, "file.txt" becomes "file (1).txt", "file (2).txt", etc.
  String _getUniqueFileName(String basePath, String fileName) {
    final lastDot = fileName.lastIndexOf('.');
    String nameWithoutExt;
    String ext;

    if (lastDot > 0) {
      nameWithoutExt = fileName.substring(0, lastDot);
      ext = fileName.substring(lastDot);
    } else {
      nameWithoutExt = fileName;
      ext = '';
    }

    int counter = 1;
    String newFileName = fileName;
    String newPath = '$basePath/$newFileName';

    while (File(newPath).existsSync() || Directory(newPath).existsSync()) {
      newFileName = '$nameWithoutExt ($counter)$ext';
      newPath = '$basePath/$newFileName';
      counter++;
    }

    return newFileName;
  }

  /// Generates a unique filename by appending a number if the file already exists on the remote server.
  ///
  /// For example, "file.txt" becomes "file (1).txt", "file (2).txt", etc.
  /// Returns the original filename if remote listing fails.
  Future<String?> _getUniqueRemoteFileName(String basePath, String fileName) async {
    final lastDot = fileName.lastIndexOf('.');
    String nameWithoutExt;
    String ext;

    if (lastDot > 0) {
      nameWithoutExt = fileName.substring(0, lastDot);
      ext = fileName.substring(lastDot);
    } else {
      nameWithoutExt = fileName;
      ext = '';
    }

    int counter = 1;
    String newFileName = fileName;

    try {
      final files = await _sftpService.listDirectory(basePath);
      while (files.any((f) => f.name == newFileName)) {
        newFileName = '$nameWithoutExt ($counter)$ext';
        counter++;
      }
      return newFileName;
    } catch (e) {
      return fileName;
    }
  }

  /// Displays a summary panel showing transfer statistics after an upload or download completes.
  ///
  /// Shows the number of files/folders transferred, total size, and elapsed time.
  /// Auto-hides after 5 seconds.
  void _showTransferStatistics(String operation, Duration elapsed) {
    setState(() {
      _transferOperation = operation;
      _transferElapsed = elapsed;
      _showTransferStats = true;
    });

    // Auto-hide after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _showTransferStats) {
        setState(() {
          _showTransferStats = false;
        });
      }
    });
  }

  /// Formats a duration into a human-readable string.
  ///
  /// Returns a localized string with minutes and seconds, or just seconds if less than a minute.
  String _formatDuration(Duration duration) {
    final l10n = AppLocalizations.of(context)!;
    final seconds = duration.inSeconds;
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;

    if (minutes > 0) {
      return l10n.durationMinSec(minutes, remainingSeconds);
    } else {
      return l10n.durationSec(remainingSeconds);
    }
  }

  /// Builds the breadcrumb navigation widget for the local file system.
  ///
  /// Shows the current path as a series of clickable segments, allowing quick navigation
  /// to parent directories. Supports both mobile and desktop layouts.
  Widget _buildLocalBreadcrumb() {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isMobile = Platform.isAndroid || Platform.isIOS;
    List<Widget> breadcrumbs = [];

    if (_localPath.isNotEmpty) {
      if (isMobile) {
        // Show only current directory name on mobile
        String name = _localPath.split('/').last;
        
        // On iOS root (Documents), show app title for better UX
        if (Platform.isIOS && _localPath == _localRootPath) {
          name = l10n.appTitle;
        }
        
        breadcrumbs.add(
          Text(
            name.isEmpty ? '/' : name,
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      } else {
        // Always show absolute path on desktop
        final parts = _localPath.split('/').where((p) => p.isNotEmpty).toList();

        // Add leading slash
        breadcrumbs.add(
          Text(
            '/',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        );

        for (int i = 0; i < parts.length; i++) {
          if (i > 0) {
            breadcrumbs.add(
              Text(
                ' / ',
                style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
              ),
            );
          }

          final pathUpToHere = '/${parts.sublist(0, i + 1).join('/')}'.replaceAll(RegExp(r'/+'), '/');
          breadcrumbs.add(
            GestureDetector(
              onTap: () => _navigateLocal(pathUpToHere),
              child: Text(
                parts[i],
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        }
      }
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: breadcrumbs,
    );
  }

  /// Builds the breadcrumb navigation widget for the remote file system.
  ///
  /// Shows the current remote path as a series of clickable segments, allowing quick navigation
  /// to parent directories on the remote server.
  Widget _buildRemoteBreadcrumb() {
    final theme = Theme.of(context);
    List<Widget> breadcrumbs = [];

    if (_remotePath.isEmpty) {
      breadcrumbs.add(
        GestureDetector(
          onTap: () => _navigateRemote(''),
          child: Text(
            '~',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    } else {
      final parts = _remotePath.split('/').where((p) => p.isNotEmpty).toList();

      // Add leading slash
      breadcrumbs.add(
        Text(
          '/',
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      );

      for (int i = 0; i < parts.length; i++) {
        if (i > 0) {
          breadcrumbs.add(
            Text(
              ' / ',
              style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
            ),
          );
        }

        final pathUpToHere = '/${parts.sublist(0, i + 1).join('/')}'.replaceAll(RegExp(r'/+'), '/');
        breadcrumbs.add(
          GestureDetector(
            onTap: () => _navigateRemote(pathUpToHere),
            child: Text(
              parts[i],
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        );
      }
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: breadcrumbs,
    );
  }
}
