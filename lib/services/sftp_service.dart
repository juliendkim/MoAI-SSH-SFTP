import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';

/// Represents a file or directory on the remote SFTP server.
class SftpFileInfo {
  /// Name of the file or directory.
  final String name;

  /// Full path to the file or directory on the remote server.
  final String path;

  /// True if this item is a directory.
  final bool isDirectory;

  /// True if this item is a symbolic link.
  final bool isSymlink;

  /// Size of the file in bytes.
  final int size;

  /// Last modification time of the file.
  final DateTime? modifiedTime;

  /// Creates a new [SftpFileInfo] instance.
  SftpFileInfo({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.isSymlink = false,
    required this.size,
    this.modifiedTime,
  });
}

/// Service class for managing SFTP operations.
///
/// Handles file system operations on the remote server via SFTP,
/// including listing, uploading, downloading, and manipulating files.
class SFTPService {
  SftpClient? _sftp;

  /// Recommended maximum file size for safe transfer (100MB).
  /// Larger files may cause memory issues with the current implementation.
  static const int maxRecommendedFileSize = 100 * 1024 * 1024;

  /// Initializes the SFTP session using an existing [SSHClient].
  Future<void> initialize(SSHClient sshClient) async {
    try {
      _sftp = await sshClient.sftp();
    } catch (e) {
      rethrow;
    }
  }

  /// Retrieves the absolute path of the remote user's home directory.
  Future<String> getHomeDirectory(SSHClient sshClient) async {
    try {
      final result = await sshClient.run('pwd');
      final homeDir = utf8.decode(result).trim();
      return homeDir;
    } catch (e) {
      return '';
    }
  }

  /// Lists the contents of a directory at the specified [path].
  ///
  /// Returns a list of [SftpFileInfo] objects representing files and directories.
  /// Handles symbolic links by resolving their target attributes.
  Future<List<SftpFileInfo>> listDirectory(String path) async {
    if (_sftp == null) {
      throw Exception('SFTP client not initialized');
    }

    try {
      // Use '.' for empty path (home directory)
      final targetPath = path.isEmpty ? '.' : path;
      final items = await _sftp!.listdir(targetPath);
      final fileInfos = <SftpFileInfo>[];

      for (final item in items) {
        if (item.filename == '.' || item.filename == '..') {
          continue;
        }

        final fullPath = path.isEmpty
            ? item.filename
            : path.endsWith('/')
                ? '$path${item.filename}'
                : '$path/${item.filename}';

        // Use longname to detect symlinks (format: "lrwxrwxrwx...")
        // Symlinks start with 'l' in the long listing format
        final isSymlink = item.longname.startsWith('l');

        bool isDirectory = item.attr.isDirectory;
        int size = item.attr.size ?? 0;

        // If it's a symlink, resolve the target to determine actual type
        if (isSymlink) {
          try {
            final stat = await _sftp!.stat(fullPath);
            isDirectory = stat.isDirectory;
            size = stat.size ?? 0;
          } catch (e) {
            // If stat fails (broken link), treat as a regular file
            isDirectory = false;
          }
        }

        fileInfos.add(SftpFileInfo(
          name: item.filename,
          path: fullPath,
          isDirectory: isDirectory,
          isSymlink: isSymlink,
          size: size,
          modifiedTime: item.attr.modifyTime != null
              ? DateTime.fromMillisecondsSinceEpoch(
                  item.attr.modifyTime! * 1000)
              : null,
        ));
      }

      return fileInfos;
    } catch (e) {
      rethrow;
    }
  }

  /// Downloads a file from [remotePath] to [localPath].
  ///
  /// [onProgress] callback reports the number of bytes received and total size.
  Future<void> downloadFile(
    String remotePath,
    String localPath, {
    void Function(int received, int total)? onProgress,
  }) async {
    if (_sftp == null) {
      throw Exception('SFTP client not initialized');
    }

    SftpFile? remoteFile;

    try {
      remoteFile = await _sftp!.open(remotePath);
      final stat = await _sftp!.stat(remotePath);
      final fileSize = stat.size ?? 0;

      final localFile = File(localPath);
      final sink = localFile.openWrite();

      int totalReceived = 0;

      try {
        await for (final chunk in remoteFile.read()) {
          sink.add(chunk);
          totalReceived += chunk.length;

          onProgress?.call(totalReceived, fileSize);
        }
      } finally {
        await sink.close();
      }
    } catch (e) {
      rethrow;
    } finally {
      await remoteFile?.close();
    }
  }

  /// Uploads a file from [localPath] to [remotePath].
  ///
  /// [onProgress] callback reports the number of bytes sent and total size.
  Future<void> uploadFile(
    String localPath,
    String remotePath, {
    void Function(int sent, int total)? onProgress,
  }) async {
    if (_sftp == null) {
      throw Exception('SFTP client not initialized');
    }

    SftpFile? remoteFile;

    try {
      final localFile = File(localPath);
      final fileSize = await localFile.length();

      remoteFile = await _sftp!.open(
        remotePath,
        mode: SftpFileOpenMode.create |
            SftpFileOpenMode.write |
            SftpFileOpenMode.truncate,
      );

      // Create stream from file and write
      final stream = localFile.openRead();
      int totalSent = 0;

      await remoteFile.write(stream.map((chunk) {
        totalSent += chunk.length;
        onProgress?.call(totalSent, fileSize);
        return Uint8List.fromList(chunk);
      }));
    } catch (e) {
      rethrow;
    } finally {
      // Ensure file handle is closed even if an error occurs
      await remoteFile?.close();
    }
  }

  /// Deletes a file at the specified [path] on the remote server.
  Future<void> deleteFile(String path) async {
    if (_sftp == null) {
      throw Exception('SFTP client not initialized');
    }

    try {
      await _sftp!.remove(path);
    } catch (e) {
      rethrow;
    }
  }

  /// Creates a new directory at the specified [path] on the remote server.
  Future<void> createDirectory(String path) async {
    if (_sftp == null) {
      throw Exception('SFTP client not initialized');
    }

    try {
      await _sftp!.mkdir(path);
    } catch (e) {
      rethrow;
    }
  }

  /// Deletes a directory at the specified [path] on the remote server.
  ///
  /// The directory must be empty.
  Future<void> deleteDirectory(String path) async {
    if (_sftp == null) {
      throw Exception('SFTP client not initialized');
    }

    try {
      await _sftp!.rmdir(path);
    } catch (e) {
      rethrow;
    }
  }

  /// Renames a file or directory from [oldPath] to [newPath].
  Future<void> renameFile(String oldPath, String newPath) async {
    if (_sftp == null) {
      throw Exception('SFTP client not initialized');
    }

    try {
      await _sftp!.rename(oldPath, newPath);
    } catch (e) {
      rethrow;
    }
  }

  /// Copies a file from [sourcePath] to [destPath] on the remote server.
  ///
  /// This operation is performed by reading the source file and writing to the destination.
  Future<void> copyFile(String sourcePath, String destPath) async {
    if (_sftp == null) {
      throw Exception('SFTP client not initialized');
    }

    SftpFile? sourceFile;
    SftpFile? destFile;

    try {
      sourceFile = await _sftp!.open(sourcePath);
      destFile = await _sftp!.open(
        destPath,
        mode: SftpFileOpenMode.create |
            SftpFileOpenMode.write |
            SftpFileOpenMode.truncate,
      );

      await for (final chunk in sourceFile.read()) {
        await destFile.writeBytes(chunk);
      }
    } catch (e) {
      rethrow;
    } finally {
      await sourceFile?.close();
      await destFile?.close();
    }
  }

  /// Recursively copies a directory from [sourcePath] to [destPath] on the remote server.
  Future<void> copyDirectoryRecursive(String sourcePath, String destPath) async {
    if (_sftp == null) {
      throw Exception('SFTP client not initialized');
    }

    try {
      // Create destination directory
      await createDirectory(destPath);

      // List contents of source directory
      final items = await listDirectory(sourcePath);

      for (final item in items) {
        final newDestPath = destPath.endsWith('/')
            ? '$destPath${item.name}'
            : '$destPath/${item.name}';

        if (item.isDirectory) {
          await copyDirectoryRecursive(item.path, newDestPath);
        } else {
          await copyFile(item.path, newDestPath);
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Closes the SFTP session.
  void close() {
    _sftp?.close();
    _sftp = null;
  }

  /// Returns true if the SFTP session is initialized.
  bool get isInitialized => _sftp != null;
}