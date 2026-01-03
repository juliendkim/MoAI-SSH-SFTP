import 'dart:io';
import 'package:dartssh2/dartssh2.dart';
import '../models/host.dart';

/// Service class for managing SSH connections.
///
/// Handles establishing connection, authentication (password/key),
/// and maintaining the SSH client state.
class SSHService {
  SSHClient? _client;

  /// Establishes an SSH connection to the specified [host].
  ///
  /// Supports both password and key file authentication.
  /// Returns the connected [SSHClient] instance.
  /// Throws an exception if connection or authentication fails.
  Future<SSHClient> connect(Host host) async {
    try {
      final socket = await SSHSocket.connect(host.hostname, host.port);

      SSHClient client;
      if (host.authType == AuthType.password && host.password != null) {
        client = SSHClient(
          socket,
          username: host.username,
          onPasswordRequest: () => host.password!,
        );
      } else if (host.authType == AuthType.keyFile) {
        String keyContent;
        // Use stored content if available (for macOS sandbox compatibility)
        if (host.keyFileContent != null && host.keyFileContent!.isNotEmpty) {
          keyContent = host.keyFileContent!;
        } else if (host.keyFilePath != null) {
          // Fallback to reading from path (may fail on macOS sandbox)
          try {
            final keyFile = File(host.keyFilePath!);
            keyContent = await keyFile.readAsString();
          } catch (e) {
            throw Exception('Unable to read SSH key file. Please edit the host configuration and re-select your key file.');
          }
        } else {
          throw Exception('No key file content or path available');
        }

        client = SSHClient(
          socket,
          username: host.username,
          identities: [
            ...SSHKeyPair.fromPem(keyContent),
          ],
        );
      } else {
        throw Exception('Invalid authentication configuration');
      }

      _client = client;
      return client;
    } catch (e) {
      rethrow;
    }
  }

  /// Disconnects the current SSH session and releases resources.
  void disconnect() {
    _client?.close();
    _client = null;
  }

  /// Returns the current active [SSHClient], or null if not connected.
  SSHClient? get client => _client;

  /// Returns true if an SSH connection is currently established.
  bool get isConnected => _client != null;
}