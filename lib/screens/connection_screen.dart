import 'package:flutter/material.dart';
import 'package:moai_ssh_sftp_client/l10n/generated/app_localizations.dart';
import '../models/host.dart';
import 'ssh_terminal_screen.dart';
import 'sftp_explorer_screen.dart';

/// A screen that manages the active connection to a host.
///
/// It provides a tabbed interface to switch between the SSH terminal and the SFTP file explorer.
class ConnectionScreen extends StatefulWidget {
  /// The host to connect to.
  final Host host;

  /// The initial tab index to display (0 for SSH, 1 for SFTP).
  final int initialIndex;

  /// Creates a [ConnectionScreen].
  const ConnectionScreen({
    super.key,
    required this.host,
    this.initialIndex = 0,
  });

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  late int _currentIndex;
  bool _showHiddenFiles = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  /// Toggles between SSH and SFTP views.
  void _handleToggle() {
    setState(() {
      _currentIndex = _currentIndex == 0 ? 1 : 0;
    });
  }

  /// Toggles the visibility of hidden files in the SFTP view.
  void _toggleHiddenFiles() {
    setState(() {
      _showHiddenFiles = !_showHiddenFiles;
    });
  }

  /// Returns the OS icon based on the host's OS type.
  IconData _getOSIcon(OSType osType) {
    switch (osType) {
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(_getOSIcon(widget.host.osType), size: 24),
            const SizedBox(width: 8),
            Text(widget.host.name),
          ],
        ),
        actions: [
          if (_currentIndex == 1)
            IconButton(
              icon: Icon(
                _showHiddenFiles ? Icons.visibility : Icons.visibility_off,
                size: 20,
              ),
              onPressed: _toggleHiddenFiles,
              tooltip: _showHiddenFiles ? l10n.hideHiddenFiles : l10n.showHiddenFiles,
            ),
          IconButton(
            icon: Icon(
              _currentIndex == 0 ? Icons.terminal : Icons.terminal_outlined,
              color: _currentIndex == 0 ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
            ),
            onPressed: () => setState(() => _currentIndex = 0),
            tooltip: l10n.ssh,
          ),
          IconButton(
            icon: Icon(
              _currentIndex == 1 ? Icons.folder : Icons.folder_outlined,
              color: _currentIndex == 1 ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
            ),
            onPressed: () => setState(() => _currentIndex = 1),
            tooltip: l10n.sftp,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          SSHTerminalScreen(host: widget.host, showAppBar: false),
          SFTPExplorerScreen(
            host: widget.host,
            showAppBar: false,
            showHiddenFiles: _showHiddenFiles,
          ),
        ],
      ),
    );
  }
}