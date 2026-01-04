import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/host.dart';

/// A form widget for creating or editing a host configuration.
///
/// Provides fields for host name, hostname/IP, port, username,
/// authentication method (password or key file), and OS type.
class HostForm extends StatefulWidget {
  /// The host to edit. If null, the form is in "create" mode.
  final Host? host;

  /// Callback function invoked when the save button is pressed.
  /// Passes the created or updated [Host] object.
  final Function(Host) onSave;

  /// Creates a [HostForm].
  const HostForm({
    super.key,
    this.host,
    required this.onSave,
  });

  @override
  State<HostForm> createState() => _HostFormState();
}

class _HostFormState extends State<HostForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _hostnameController;
  late TextEditingController _portController;
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;
  late TextEditingController _keyFileController;
  late AuthType _authType;
  late OSType _osType;
  String? _keyFileContent; // Store the actual key file content

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.host?.name ?? '');
    _hostnameController =
        TextEditingController(text: widget.host?.hostname ?? '');
    _portController =
        TextEditingController(text: widget.host?.port.toString() ?? '22');
    _usernameController =
        TextEditingController(text: widget.host?.username ?? '');
    _passwordController =
        TextEditingController(text: widget.host?.password ?? '');
    _keyFileController =
        TextEditingController(text: widget.host?.keyFilePath ?? '');
    _authType = widget.host?.authType ?? AuthType.password;
    _osType = widget.host?.osType ?? OSType.linux;
    _keyFileContent = widget.host?.keyFileContent;

    // Show warning if key file path exists but content is missing
    if (widget.host != null &&
        widget.host!.authType == AuthType.keyFile &&
        widget.host!.keyFilePath != null &&
        (widget.host!.keyFileContent == null || widget.host!.keyFileContent!.isEmpty)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.reselectKeyFile),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      });
      // Clear the path so user must reselect
      _keyFileController.text = '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hostnameController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _keyFileController.dispose();
    super.dispose();
  }

  /// Opens a file picker to select a private key file.
  ///
  /// Reads the file content immediately to store it securely,
  /// ensuring access persists across app restarts (especially on macOS).
  Future<void> _pickKeyFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;

      try {
        // Read the file content immediately while we have access
        final file = File(path);
        final content = await file.readAsString();

        setState(() {
          _keyFileController.text = path;
          _keyFileContent = content;
        });
      } catch (e) {
        if (mounted) {
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.failedToReadKeyFile(e))),
          );
        }
      }
    }
  }

  /// Validates the form and invokes the [widget.onSave] callback with the new host data.
  void _save() {
    if (_formKey.currentState!.validate()) {
      final host = Host(
        id: widget.host?.id,
        name: _nameController.text,
        hostname: _hostnameController.text,
        port: int.parse(_portController.text),
        username: _usernameController.text,
        authType: _authType,
        password:
            _authType == AuthType.password ? _passwordController.text : null,
        keyFilePath:
            _authType == AuthType.keyFile ? _keyFileController.text : null,
        keyFileContent:
            _authType == AuthType.keyFile ? _keyFileContent : null,
        osType: _osType,
        createdAt: widget.host?.createdAt,
      );
      widget.onSave(host);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            widget.host == null ? l10n.addNewHost : l10n.editHost,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: l10n.labelName,
              border: const OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return l10n.validatorName;
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _hostnameController,
            decoration: InputDecoration(
              labelText: l10n.labelHostname,
              border: const OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return l10n.validatorHostname;
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _portController,
            decoration: InputDecoration(
              labelText: l10n.labelPort,
              border: const OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return l10n.validatorPort;
              }
              final port = int.tryParse(value);
              if (port == null || port < 1 || port > 65535) {
                return l10n.validatorPortRange;
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _usernameController,
            decoration: InputDecoration(
              labelText: l10n.labelUsername,
              border: const OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return l10n.validatorUsername;
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<OSType>(
            value: _osType,
            decoration: InputDecoration(
              labelText: l10n.labelOS,
              border: const OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: OSType.linux,
                child: Row(
                  children: [
                    Icon(Icons.dns, size: 20),
                    SizedBox(width: 8),
                    Text('Linux'),
                  ],
                ),
              ),
              DropdownMenuItem(
                value: OSType.windows,
                child: Row(
                  children: [
                    Icon(Icons.window, size: 20),
                    SizedBox(width: 8),
                    Text('Windows'),
                  ],
                ),
              ),
              DropdownMenuItem(
                value: OSType.macos,
                child: Row(
                  children: [
                    Icon(Icons.laptop_mac, size: 20),
                    SizedBox(width: 8),
                    Text('macOS'),
                  ],
                ),
              ),
              DropdownMenuItem(
                value: OSType.unix,
                child: Row(
                  children: [
                    Icon(Icons.storage, size: 20),
                    SizedBox(width: 8),
                    Text('Unix'),
                  ],
                ),
              ),
              DropdownMenuItem(
                value: OSType.unknown,
                child: Row(
                  children: [
                    Icon(Icons.computer, size: 20),
                    SizedBox(width: 8),
                    Text('Unknown'),
                  ],
                ),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _osType = value;
                });
              }
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<AuthType>(
            value: _authType,
            decoration: InputDecoration(
              labelText: l10n.labelAuthType,
              border: const OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: AuthType.password,
                child: Text('Password'),
              ),
              DropdownMenuItem(
                value: AuthType.keyFile,
                child: Text('Key File'),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _authType = value;
                });
              }
            },
          ),
          const SizedBox(height: 16),
          if (_authType == AuthType.password)
            TextFormField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: l10n.labelPassword,
                border: const OutlineInputBorder(),
              ),
              obscureText: true,
              validator: (value) {
                if (_authType == AuthType.password &&
                    (value == null || value.isEmpty)) {
                  return l10n.validatorPassword;
                }
                return null;
              },
            ),
          if (_authType == AuthType.keyFile)
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _keyFileController,
                    decoration: InputDecoration(
                      labelText: l10n.labelKeyFilePath,
                      border: const OutlineInputBorder(),
                    ),
                    readOnly: true,
                    validator: (value) {
                      if (_authType == AuthType.keyFile &&
                          (value == null || value.isEmpty)) {
                        return l10n.validatorKeyFile;
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.folder_open),
                  onPressed: _pickKeyFile,
                ),
              ],
            ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.cancel),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _save,
                child: Text(l10n.save),
              ),
            ],
          ),
        ],
      ),
    );
  }
}