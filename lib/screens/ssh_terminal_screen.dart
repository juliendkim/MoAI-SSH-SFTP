import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';
import 'package:dartssh2/dartssh2.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/host.dart';
import '../services/ssh_service.dart';

/// A screen that displays a fully functional SSH terminal.
///
/// Uses [xterm] for the terminal emulation and [SSHService] for the connection.
class SSHTerminalScreen extends StatefulWidget {
  /// The host to connect to.
  final Host host;

  /// Whether to show the AppBar.
  /// Typically false when embedded in [ConnectionScreen].
  final bool showAppBar;

  /// Creates an [SSHTerminalScreen].
  const SSHTerminalScreen({
    super.key,
    required this.host,
    this.showAppBar = true,
  });

  @override
  State<SSHTerminalScreen> createState() => SSHTerminalScreenState();
}

class SSHTerminalScreenState extends State<SSHTerminalScreen> {
  final SSHService _sshService = SSHService();
  late Terminal _terminal;
  SSHSession? _session;
  StreamSubscription<List<int>>? _stdoutSubscription;
  StreamSubscription<List<int>>? _stderrSubscription;
  bool _isConnecting = true;
  String? _errorMessage;
  final FocusNode _focusNode = FocusNode();

  /// Requests focus for the terminal widget to enable keyboard input.
  void requestTerminalFocus() {
    if (mounted) {
      FocusScope.of(context).requestFocus(_focusNode);
    }
  }

  @override
  void initState() {
    super.initState();
    _terminal = Terminal(
      maxLines: 10000,
    );
    _connectToHost();
  }

  /// Initiates the SSH connection to the host.
  ///
  /// Sets up the terminal session and binds the input/output streams.
  Future<void> _connectToHost() async {
    await _cleanupConnection();

    if (!mounted) return;

    final l10n = AppLocalizations.of(context)!;

    setState(() {
      _isConnecting = true;
      _errorMessage = null;
    });

    try {
      _terminal.write('${l10n.connectingTo(widget.host.hostname)}\r\n');

      final client = await _sshService.connect(widget.host);

      if (!mounted) {
        _sshService.disconnect();
        return;
      }

      _terminal.write('${l10n.connectedSuccessfully}\r\n');

      final session = await client.shell(
        pty: SSHPtyConfig(
          width: _terminal.viewWidth,
          height: _terminal.viewHeight,
        ),
      );

      if (!mounted) {
        session.close();
        _sshService.disconnect();
        return;
      }

      _session = session;

      _terminal.buffer.clear();
      _terminal.buffer.setCursor(0, 0);

      _terminal.onOutput = (data) {
        session.write(utf8.encode(data));
      };

      _terminal.onResize = (width, height, pixelWidth, pixelHeight) {
        session.resizeTerminal(width, height);
      };

      _stdoutSubscription = session.stdout.listen(
        (data) {
          if (mounted) {
            _terminal.write(utf8.decode(data));
          }
        },
        onError: (error) {
          if (mounted) {
            _terminal.write('\r\nStream error: $error\r\n');
          }
        },
        onDone: () {
          if (mounted) {
            _terminal.write('\r\nConnection closed by remote host\r\n');
          }
        },
      );

      _stderrSubscription = session.stderr.listen(
        (data) {
          if (mounted) {
            _terminal.write(utf8.decode(data));
          }
        },
        onError: (error) {
          if (mounted) {
            _terminal.write('\r\nError stream error: $error\r\n');
          }
        },
      );

      if (mounted) {
        setState(() {
          _isConnecting = false;
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          requestTerminalFocus();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _errorMessage = l10n.connectionFailed(e);
        });
        _terminal.write('\r\n${l10n.connectionFailed(e)}\r\n');
      }
    }
  }

  /// Cleans up any existing connection resources.
  Future<void> _cleanupConnection() async {
    // Cancel stream subscriptions
    await _stdoutSubscription?.cancel();
    await _stderrSubscription?.cancel();
    _stdoutSubscription = null;
    _stderrSubscription = null;

    // Close session
    _session?.close();
    _session = null;
  }

  @override
  void dispose() {
    // Clean up all resources
    _stdoutSubscription?.cancel();
    _stderrSubscription?.cancel();
    _session?.close();
    _sshService.disconnect();
    _terminal.onOutput = null;
    _terminal.onResize = null;
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final body = _errorMessage != null && _isConnecting == false
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _connectToHost,
                  icon: const Icon(Icons.refresh),
                  label: Text(l10n.retry),
                ),
              ],
            ),
          )
        : GestureDetector(
            onTap: requestTerminalFocus,
            child: Focus(
              focusNode: _focusNode,
              child: TerminalView(
                _terminal,
                textStyle: TerminalStyle(
                  fontSize: 14,
                  fontFamily: 'RobotoMono', // Optional: Ensure a monospaced font
                ),
                theme: isDark
                    ? TerminalThemes.defaultTheme
                    : const TerminalTheme(
                        cursor: Colors.black,
                        selection: Color(0x40000000),
                        foreground: Colors.black,
                        background: Colors.white,
                        black: Colors.black,
                        red: Colors.red,
                        green: Colors.green,
                        yellow: Color(0xFFC4A000),
                        blue: Colors.blue,
                        magenta: Colors.purple,
                        cyan: Colors.teal,
                        white: Color(0xFF555753),
                        brightBlack: Color(0xFF2E3436),
                        brightRed: Color(0xFFEF2929),
                        brightGreen: Color(0xFF8AE234),
                        brightYellow: Color(0xFFFCE94F),
                        brightBlue: Color(0xFF729FCF),
                        brightMagenta: Color(0xFFAD7FA8),
                        brightCyan: Color(0xFF34E2E2),
                        brightWhite: Colors.white,
                        searchHitBackground: Color(0xFFFFFF00),
                        searchHitBackgroundCurrent: Color(0xFFFFA500),
                        searchHitForeground: Colors.black,
                      ),
              ),
            ),
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
            Text(widget.host.name),
          ],
        ),
        actions: [
          if (_isConnecting)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          if (!_isConnecting && _errorMessage != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _connectToHost,
            ),
        ],
      ),
      body: body,
    );
  }
}