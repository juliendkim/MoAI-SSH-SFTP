import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for macOS directory access with security-scoped bookmarks.
///
/// Provides methods for requesting directory permissions, listing files,
/// and picking files/directories while handling macOS sandbox restrictions.
class FileAccessService {
  static const MethodChannel _channel = MethodChannel('com.moai.ssh_sftp/file_access');

  /// Lists directory contents with automatic permission handling for macOS.
  ///
  /// On macOS, requests directory access permissions automatically if needed.
  /// On other platforms, performs standard directory listing.
  ///
  /// [path] The directory path to list.
  /// [autoRequestPermission] If true, automatically shows permission dialog on access denied.
  ///
  /// Returns a list of [FileSystemEntity] objects representing files and directories.
  static Future<List<FileSystemEntity>> listDirectoryWithPermission(
    String path, {
    bool autoRequestPermission = true,
  }) async {
    print('[Dart] listDirectoryWithPermission called: $path');

    if (!Platform.isMacOS) {
      print('[Dart] Not macOS - using standard approach');
      try {
        final directory = Directory(path);
        if (!await directory.exists()) {
          return [];
        }
        return await directory.list().toList();
      } catch (e) {
        print('[Dart] Directory listing failed: $e');
        return [];
      }
    }

    // macOS: Call native method
    try {
      print('[Dart] Calling native listDirectory...');
      final result = await _channel.invokeMethod('listDirectory', {
        'path': path,
      });

      print('[Dart] Native response: $result');

      if (result is Map && result['success'] == true) {
        final items = result['items'] as List;
        print('[Dart] Success: ${items.length} items');
        return items.map((item) {
          final isDir = item['isDirectory'] as bool;
          final itemPath = item['path'] as String;
          return isDir ? Directory(itemPath) : File(itemPath);
        }).toList();
      }

      print('[Dart] No success flag');
      return [];
    } on PlatformException catch (e) {
      print('[Dart] PlatformException occurred: ${e.code} - ${e.message}');

      // Request permission if PERMISSION_DENIED error
      if (e.code == 'PERMISSION_DENIED' && autoRequestPermission) {
        print('[Dart] Permission denied - showing permission dialog');

        final accessResult = await requestDirectoryAccessMacOS(suggestedPath: path);

        if (accessResult != null) {
          print('[Dart] Permission granted - retrying');
          // Retry (prevent infinite recursion)
          return await listDirectoryWithPermission(path, autoRequestPermission: false);
        } else {
          print('[Dart] Permission request cancelled');
          return [];
        }
      }

      print('[Dart] Other error or auto request disabled');
      return [];
    } catch (e) {
      print('[Dart] Unexpected error: $e');

      // Handle potential permission error
      if (autoRequestPermission && e.toString().toLowerCase().contains('permission')) {
        print('[Dart] Permission-related error detected - requesting permission');

        final accessResult = await requestDirectoryAccessMacOS(suggestedPath: path);

        if (accessResult != null) {
          print('[Dart] Permission granted - retrying');
          return await listDirectoryWithPermission(path, autoRequestPermission: false);
        }
      }

      return [];
    }
  }

  /// Requests directory access permission (macOS only).
  ///
  /// Shows a directory picker dialog to the user and stores a security-scoped
  /// bookmark for future access.
  ///
  /// [suggestedPath] An optional path to suggest to the user in the picker dialog.
  ///
  /// Returns a map containing 'path' and 'bookmarkKey' on success, or null if cancelled.
  static Future<Map<String, dynamic>?> requestDirectoryAccessMacOS({String? suggestedPath}) async {
    if (!Platform.isMacOS) {
      return null;
    }

    print('[Dart] requestDirectoryAccessMacOS called: $suggestedPath');

    try {
      final result = await _channel.invokeMethod('requestDirectoryAccess', {
        'suggestedPath': suggestedPath,
      });

      print('[Dart] requestDirectoryAccess response: $result');

      if (result is Map && result['success'] == true) {
        final path = result['path'] as String;
        final bookmarkKey = result['bookmarkKey'] as String;

        // Save to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('bookmark_key_$path', bookmarkKey);

        print('[Dart] Permission granted and bookmark saved');

        return {
          'path': path,
          'bookmarkKey': bookmarkKey,
        };
      }

      print('[Dart] Permission request cancelled');
      return null;
    } catch (e) {
      print('[Dart] requestDirectoryAccessMacOS error: $e');
      return null;
    }
  }

  /// Prompts the user to select a directory and returns the path.
  ///
  /// Returns the selected directory path, or null if cancelled.
  static Future<String?> pickDirectory() async {
    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory != null) {
        print('Selected directory: $selectedDirectory');
      }
      return selectedDirectory;
    } catch (e) {
      print('Error selecting directory: $e');
      return null;
    }
  }

  /// Prompts the user to select multiple files and returns their paths.
  ///
  /// [allowedExtensions] Optional list of file extensions to filter (e.g., ['pdf', 'txt']).
  ///
  /// Returns a list of selected file paths, or null if cancelled.
  static Future<List<String>?> pickFiles({List<String>? allowedExtensions}) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: allowedExtensions != null ? FileType.custom : FileType.any,
        allowedExtensions: allowedExtensions,
      );

      if (result != null) {
        List<String> paths = result.paths.whereType<String>().toList();
        print('Selected file count: ${paths.length}');
        return paths;
      }

      return null;
    } catch (e) {
      print('Error selecting files: $e');
      return null;
    }
  }

  /// Prompts the user to select a single file and returns its path.
  ///
  /// [allowedExtensions] Optional list of file extensions to filter (e.g., ['pdf', 'txt']).
  ///
  /// Returns the selected file path, or null if cancelled.
  static Future<String?> pickSingleFile({List<String>? allowedExtensions}) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: allowedExtensions != null ? FileType.custom : FileType.any,
        allowedExtensions: allowedExtensions,
      );

      if (result != null && result.files.single.path != null) {
        String path = result.files.single.path!;
        print('Selected file: $path');
        return path;
      }

      return null;
    } catch (e) {
      print('Error selecting file: $e');
      return null;
    }
  }

  /// Returns paths to common system directories.
  ///
  /// Includes home, desktop, documents, downloads, pictures, music, movies,
  /// temp, and application support directories.
  ///
  /// Returns a map with directory names as keys and paths as values.
  static Future<Map<String, String>> getSystemDirectories() async {
    Map<String, String> directories = {};

    try {
      String home = Platform.environment['HOME'] ?? '';
      if (home.isNotEmpty) {
        directories['home'] = home;
        directories['desktop'] = '$home/Desktop';
        directories['documents'] = '$home/Documents';
        directories['downloads'] = '$home/Downloads';
        directories['pictures'] = '$home/Pictures';
        directories['music'] = '$home/Music';
        directories['movies'] = '$home/Movies';
      }

      final tempDir = await getTemporaryDirectory();
      directories['temp'] = tempDir.path;

      final appSupportDir = await getApplicationSupportDirectory();
      directories['appSupport'] = appSupportDir.path;

      if (Platform.isMacOS) {
        final downloadDir = await getDownloadsDirectory();
        if (downloadDir != null) {
          directories['downloadsPath'] = downloadDir.path;
        }
      }
    } catch (e) {
      print('Error getting system directory paths: $e');
    }

    return directories;
  }

  /// Prompts the user to select a save location for a file or directory.
  ///
  /// [suggestedFileName] Optional filename to suggest in the save dialog.
  ///
  /// Returns the selected save path, or null if cancelled.
  static Future<String?> pickSaveLocation({String? suggestedFileName}) async {
    try {
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Select save location',
        fileName: suggestedFileName,
      );

      if (outputFile != null) {
        print('Save path: $outputFile');
      }

      return outputFile;
    } catch (e) {
      print('Error selecting save location: $e');
      return null;
    }
  }
}
