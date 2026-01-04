import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/host.dart';
import '../providers/host_provider.dart';
import '../widgets/host_card.dart';
import '../widgets/host_form.dart';
import 'connection_screen.dart';

/// The main screen of the application.
///
/// Displays a grid of configured hosts and allows the user to add, edit, or delete hosts.
/// Serves as the entry point for initiating SSH or SFTP connections.
class HomeScreen extends StatefulWidget {
  /// Creates the [HomeScreen].
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Load hosts when the screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HostProvider>().loadHosts();
    });
  }

  /// Shows a modal bottom sheet to add or edit a host.
  ///
  /// If [host] is provided, the form is pre-filled with the host's details for editing.
  /// Otherwise, a new host creation form is shown.
  void _showHostForm({Host? host}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (modalContext) => SizedBox(
        height: MediaQuery.of(modalContext).size.height * 0.8,
        child: HostForm(
          host: host,
          onSave: (savedHost) async {
            final navigator = Navigator.of(modalContext);
            if (host == null) {
              await modalContext.read<HostProvider>().addHost(savedHost);
            } else {
              await modalContext.read<HostProvider>().updateHost(savedHost);
            }
            navigator.pop();
          },
        ),
      ),
    );
  }

  /// Shows detailed information about a host in a modal bottom sheet.
  ///
  /// Allows the user to edit or delete the host from this view.
  void _showHostDetails(Host host) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            AppBar(
              title: Text(host.name),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () {
                    Navigator.pop(context);
                    _showHostForm(host: host);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () {
                    _deleteHost(host);
                    Navigator.pop(context);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildDetailRow(l10n.hostName, host.name),
                  _buildDetailRow(l10n.hostHostname, host.hostname),
                  _buildDetailRow(l10n.hostPort, host.port.toString()),
                  _buildDetailRow(l10n.hostUsername, host.username),
                  _buildDetailRow(l10n.hostAuthType, host.authType.name),
                  if (host.authType == AuthType.keyFile &&
                      host.keyFilePath != null)
                    _buildDetailRow(l10n.hostKeyFile, host.keyFilePath!),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Helper widget to build a row in the details view.
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  /// Prompts the user for confirmation before deleting a host.
  void _deleteHost(Host host) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.deleteHostTitle),
        content: Text(l10n.deleteHostContent(host.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(dialogContext);
              await dialogContext.read<HostProvider>().deleteHost(host.id);
              navigator.pop();
            },
            child: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  /// Navigates to the [ConnectionScreen] with the SSH tab selected.
  void _connectSSH(Host host) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ConnectionScreen(host: host, initialIndex: 0),
      ),
    );
  }

  /// Navigates to the [ConnectionScreen] with the SFTP tab selected.
  void _connectSFTP(Host host) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ConnectionScreen(host: host, initialIndex: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/app-icon.png',
              width: 32,
              height: 32,
            ),
            const SizedBox(width: 16),
            Text(l10n.appTitle),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showHostForm(),
          ),
        ],
      ),
      body: Consumer<HostProvider>(
        builder: (context, hostProvider, child) {
          if (hostProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (hostProvider.hosts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.dns,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.noHostsConfigured,
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => _showHostForm(),
                    icon: const Icon(Icons.add),
                    label: Text(l10n.addHost),
                  ),
                ],
              ),
            );
          }

          final isMobile = Platform.isAndroid || Platform.isIOS;

          if (isMobile) {
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: hostProvider.hosts.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final host = hostProvider.hosts[index];
                return SizedBox(
                  height: 140, // Fixed height for consistency
                  child: HostCard(
                    host: host,
                    onTap: () => _showHostDetails(host),
                    onDoubleTap: () => _connectSSH(host),
                    onSSHTap: () => _connectSSH(host),
                    onSFTPTap: () => _connectSFTP(host),
                  ),
                );
              },
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 300,
              childAspectRatio: 1.2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: hostProvider.hosts.length,
            itemBuilder: (context, index) {
              final host = hostProvider.hosts[index];
              return HostCard(
                host: host,
                onTap: () => _showHostDetails(host),
                onDoubleTap: () => _connectSSH(host),
                onSSHTap: () => _connectSSH(host),
                onSFTPTap: () => _connectSFTP(host),
              );
            },
          );
        },
      ),
    );
  }
}