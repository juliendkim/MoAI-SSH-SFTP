import 'package:uuid/uuid.dart';

/// Authentication type for SSH connection.
enum AuthType {
  /// Authenticate using a password.
  password,

  /// Authenticate using a private key file.
  keyFile,
}

/// Operating System type of the remote host.
/// Used to display the appropriate icon for the host.
enum OSType {
  /// Linux operating system.
  linux,

  /// Windows operating system.
  windows,

  /// macOS operating system.
  macos,

  /// Unix or Unix-like operating system (BSD, Solaris, etc.).
  unix,

  /// Unknown or other operating system.
  unknown,
}

/// Represents a remote host configuration.
///
/// Contains all necessary information to establish an SSH or SFTP connection,
/// including hostname, port, authentication credentials, and display preferences.
class Host {
  /// Unique identifier for the host.
  final String id;

  /// Display name of the host (e.g., "My Web Server").
  final String name;

  /// Hostname or IP address of the server.
  final String hostname;

  /// Port number for the SSH connection (default is 22).
  final int port;

  /// Username for authentication.
  final String username;

  /// Type of authentication to use (password or key file).
  final AuthType authType;

  /// Password for password-based authentication.
  /// Null if [authType] is [AuthType.keyFile].
  final String? password;

  /// Path to the private key file for key-based authentication.
  /// Null if [authType] is [AuthType.password].
  final String? keyFilePath;

  /// Actual content of the private key file.
  ///
  /// This is required for macOS sandbox compliance where file paths might
  /// not be accessible directly after the app restarts.
  final String? keyFileContent;

  /// The operating system of the host, used for UI display.
  final OSType osType;

  /// The date and time when this host configuration was created.
  final DateTime createdAt;

  /// The date and time when this host configuration was last updated.
  final DateTime updatedAt;

  /// Creates a new [Host] instance.
  ///
  /// If [id] is not provided, a new UUID v4 will be generated.
  /// [createdAt] and [updatedAt] default to the current time if not provided.
  Host({
    String? id,
    required this.name,
    required this.hostname,
    this.port = 22,
    required this.username,
    this.authType = AuthType.password,
    this.password,
    this.keyFilePath,
    this.keyFileContent,
    this.osType = OSType.linux,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Converts this [Host] instance to a JSON map.
  ///
  /// Used for persisting the host configuration to storage.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'hostname': hostname,
      'port': port,
      'username': username,
      'authType': authType.name,
      'password': password,
      'keyFilePath': keyFilePath,
      'keyFileContent': keyFileContent,
      'osType': osType.name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Creates a [Host] instance from a JSON map.
  ///
  /// Used for retrieving the host configuration from storage.
  factory Host.fromJson(Map<String, dynamic> json) {
    return Host(
      id: json['id'] as String,
      name: json['name'] as String,
      hostname: json['hostname'] as String,
      port: json['port'] as int? ?? 22,
      username: json['username'] as String,
      authType: AuthType.values.firstWhere(
        (e) => e.name == json['authType'],
        orElse: () => AuthType.password,
      ),
      password: json['password'] as String?,
      keyFilePath: json['keyFilePath'] as String?,
      keyFileContent: json['keyFileContent'] as String?,
      osType: OSType.values.firstWhere(
        (e) => e.name == (json['osType'] as String?),
        orElse: () => OSType.linux,
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  /// Creates a copy of this [Host] with the given fields replaced with new values.
  ///
  /// [updatedAt] is automatically set to the current time.
  Host copyWith({
    String? name,
    String? hostname,
    int? port,
    String? username,
    AuthType? authType,
    String? password,
    String? keyFilePath,
    String? keyFileContent,
    OSType? osType,
  }) {
    return Host(
      id: id,
      name: name ?? this.name,
      hostname: hostname ?? this.hostname,
      port: port ?? this.port,
      username: username ?? this.username,
      authType: authType ?? this.authType,
      password: password ?? this.password,
      keyFilePath: keyFilePath ?? this.keyFilePath,
      keyFileContent: keyFileContent ?? this.keyFileContent,
      osType: osType ?? this.osType,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}