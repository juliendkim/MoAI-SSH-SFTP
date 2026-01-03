import 'package:flutter/material.dart';
import '../services/file_access_service.dart';

/// Example widget demonstrating macOS directory access functionality.
///
/// Provides UI for testing file/directory picking, permission requests,
/// and listing system directories.
class FileAccessExample extends StatefulWidget {
  /// Creates a [FileAccessExample] widget.
  const FileAccessExample({super.key});

  @override
  State<FileAccessExample> createState() => _FileAccessExampleState();
}

class _FileAccessExampleState extends State<FileAccessExample> {
  String _statusMessage = 'Ready';
  Map<String, String> _systemDirectories = {};

  @override
  void initState() {
    super.initState();
    _loadSystemDirectories();
  }

  /// Loads the system directories and updates the status.
  Future<void> _loadSystemDirectories() async {
    final directories = await FileAccessService.getSystemDirectories();
    setState(() {
      _systemDirectories = directories;
      _statusMessage = 'System directories loaded';
    });
  }

  /// Prompts the user to pick a directory and displays the result.
  Future<void> _pickDirectory() async {
    final path = await FileAccessService.pickDirectory();
    setState(() {
      if (path != null) {
        _statusMessage = 'Selected directory: $path';
      } else {
        _statusMessage = 'Directory selection cancelled';
      }
    });
  }

  /// Prompts the user to pick a file and displays the result.
  Future<void> _pickFile() async {
    final path = await FileAccessService.pickSingleFile();
    setState(() {
      if (path != null) {
        _statusMessage = 'Selected file: $path';
      } else {
        _statusMessage = 'File selection cancelled';
      }
    });
  }

  /// Prompts the user to pick multiple files and displays the result.
  Future<void> _pickMultipleFiles() async {
    final paths = await FileAccessService.pickFiles();
    setState(() {
      if (paths != null && paths.isNotEmpty) {
        _statusMessage = 'Selected ${paths.length} files:\n${paths.join('\n')}';
      } else {
        _statusMessage = 'File selection cancelled';
      }
    });
  }

  /// Checks access to a directory and displays the result.
  Future<void> _checkAccess(String path) async {
    setState(() {
      _statusMessage = 'Attempting to access $path...';
    });

    // List directory with automatic permission request
    final entities = await FileAccessService.listDirectoryWithPermission(
      path,
      autoRequestPermission: true,
    );

    setState(() {
      if (entities.isNotEmpty) {
        _statusMessage = 'Access successful to $path!\nFound ${entities.length} items';
      } else {
        _statusMessage = '$path is empty or access failed';
      }
    });
  }

  /// Requests directory access permission and displays the result.
  Future<void> _requestDirectoryAccess() async {
    final result = await FileAccessService.requestDirectoryAccessMacOS();

    setState(() {
      if (result != null) {
        _statusMessage = 'Permission granted!\nPath: ${result['path']}\nBookmark: ${result['bookmarkKey']}';
      } else {
        _statusMessage = 'Permission request cancelled';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('macOS Directory Access Example'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status message
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  _statusMessage,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Action buttons
            ElevatedButton.icon(
              onPressed: _requestDirectoryAccess,
              icon: const Icon(Icons.security),
              label: const Text('Request Directory Permission (macOS)'),
            ),
            const SizedBox(height: 8),

            ElevatedButton.icon(
              onPressed: _pickDirectory,
              icon: const Icon(Icons.folder_open),
              label: const Text('Select Directory'),
            ),
            const SizedBox(height: 8),

            ElevatedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.insert_drive_file),
              label: const Text('Select File'),
            ),
            const SizedBox(height: 8),

            ElevatedButton.icon(
              onPressed: _pickMultipleFiles,
              icon: const Icon(Icons.file_copy),
              label: const Text('Select Multiple Files'),
            ),
            const SizedBox(height: 16),

            // System directories list
            const Text(
              'System Directories:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: ListView.builder(
                itemCount: _systemDirectories.length,
                itemBuilder: (context, index) {
                  final entry = _systemDirectories.entries.elementAt(index);
                  return Card(
                    child: ListTile(
                      title: Text(entry.key),
                      subtitle: Text(
                        entry.value,
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.check_circle_outline),
                        onPressed: () => _checkAccess(entry.value),
                        tooltip: 'Check access permission',
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
