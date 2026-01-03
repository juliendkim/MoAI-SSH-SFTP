import 'package:flutter/material.dart';
import 'package:moai_ssh_sftp_client/l10n/generated/app_localizations.dart';
import '../models/host.dart';

/// A card widget that displays a summary of a host configuration.
///
/// Shows the host's operating system icon, name, username, hostname, and port.
/// Provides quick access buttons for connecting via SSH or SFTP.
class HostCard extends StatelessWidget {
  /// The host configuration to display.
  final Host host;

  /// Callback function when the card is tapped (e.g., to view details).
  final VoidCallback onTap;

  /// Callback function when the card is double-tapped (e.g., to quick connect).
  final VoidCallback onDoubleTap;

  /// Callback function when the SSH button is tapped.
  final VoidCallback onSSHTap;

  /// Callback function when the SFTP button is tapped.
  final VoidCallback onSFTPTap;

  /// Creates a [HostCard].
  const HostCard({
    super.key,
    required this.host,
    required this.onTap,
    required this.onDoubleTap,
    required this.onSSHTap,
    required this.onSFTPTap,
  });

  /// Returns the appropriate icon based on the host's operating system.
  IconData _getOSIcon() {
    switch (host.osType) {
      case OSType.linux:
        return Icons.dns; // Linux server icon
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
    final isMobile = MediaQuery.of(context).size.width < 600;

    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      child: Card(
        elevation: 4,
        child: isMobile ? _buildMobileLayout(context, l10n) : _buildDesktopLayout(context, l10n),
      ),
    );
  }

  /// Builds the mobile layout with buttons on the right side (vertical).
  Widget _buildMobileLayout(BuildContext context, AppLocalizations l10n) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left side: Server Info
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            child: _buildServerInfo(context, l10n),
          ),
        ),
        // Vertical Divider
        Container(
          width: 1,
          color: Colors.grey[300],
        ),
        // Right side: Action Buttons (Vertical)
        SizedBox(
          width: 80,
          child: Column(
            children: [
              Expanded(
                child: InkWell(
                  onTap: onSSHTap,
                  child: Container(
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.terminal, size: 20),
                        const SizedBox(height: 4),
                        Text(l10n.ssh, style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                height: 1,
                color: Colors.grey[300],
              ),
              Expanded(
                child: InkWell(
                  onTap: onSFTPTap,
                  child: Container(
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.folder, size: 20),
                        const SizedBox(height: 4),
                        Text(l10n.sftp, style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Builds the desktop layout with buttons on the bottom (horizontal).
  Widget _buildDesktopLayout(BuildContext context, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top side: Server Info
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            child: _buildServerInfo(context, l10n),
          ),
        ),
        // Horizontal Divider
        Container(
          height: 1,
          color: Colors.grey[300],
        ),
        // Bottom side: Action Buttons (Horizontal)
        SizedBox(
          height: 60,
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: onSSHTap,
                  child: Container(
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.terminal, size: 20),
                        const SizedBox(width: 8),
                        Text(l10n.ssh, style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                width: 1,
                color: Colors.grey[300],
              ),
              Expanded(
                child: InkWell(
                  onTap: onSFTPTap,
                  child: Container(
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.folder, size: 20),
                        const SizedBox(width: 8),
                        Text(l10n.sftp, style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Builds the server information section (shared between layouts).
  Widget _buildServerInfo(BuildContext context, AppLocalizations l10n) {
    return Row(
      children: [
        // OS Icon
        Icon(
          _getOSIcon(),
          size: 45,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 16),
        // Server Text Info (Scrollable)
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  host.name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${host.username}@${host.hostname}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${l10n.hostPort}: ${host.port}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[500],
                      ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}