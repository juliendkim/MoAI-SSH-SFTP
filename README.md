# <img src="./README/app-icon.svg" width="24" height="24"> MoAI SSH・SFTP

[한국어](README_ko.md) | English

A cross-platform SSH and SFTP client

## Overview

- A versatile application that provides seamless SSH terminal access and SFTP file management across multiple platforms
- Simplifies remote server management for developers and system administrators with an intuitive interface and robust functionality

### Screenshot - Desktop
<div align="left">
  <img src="./README/mac2.png" alt="macos" style="width:48%; height:auto;">
  <img src="./README/mac3.png" alt="macos" style="width:48%; height:auto;">
</div>

### Screenshot - Mobile
<div align="left">
  <img src="./README/ios1.png" alt="ios" style="width:24%; height:auto;">
  <img src="./README/android.png" alt="android" style="width:24%; height:auto;">
  <img src="./README/ios2.jpg" alt="ios" style="width:24%; height:auto;">
  <img src="./README/ios3.jpg" alt="ios" style="width:24%; height:auto;">
<div>

## Features

### Host Management
- **Comprehensive Host Configuration**: Store and manage SSH connection details including hostname, port, username, authentication method (password/key file)
- **CRUD Operations**: Create, read, update, and delete host configurations with ease
- **Operating System Recognition**: Automatic OS type detection and icon display (Linux, Windows, macOS, Unix)
- **Quick Access**: Grid/list view of all configured hosts with single-click details and double-click connection

### User Interface
- **Responsive Design**:
  - Mobile: Vertical action buttons on card right side
  - Desktop: Horizontal action buttons on card bottom
- **Dark/Light Theme**: Automatic theme support following system preferences
- **Internationalization**: Built-in support for English and Korean languages. Additional languages can be added

## Supported Platforms

- ✅ **macOS**
- ✅ **Windows**
- ✅ **Linux**
- ✅ **iOS**
- ✅ **Android**

## Prerequisites

Before building the project, ensure you have the following installed:

- **Flutter SDK**: Version 3.10.4 or higher
  ```bash
  flutter --version
  ```
- **Dart SDK**: Version 3.10.4 or higher (included with Flutter)
- **Platform-specific requirements**:
  - **macOS**: Xcode
  - **Windows**: Visual Studio 2022 with C++ desktop development tools
  - **Linux**: Standard development tools (`build-essential`, `libgtk-3-dev`, etc.)
  - **iOS**: Xcode, CocoaPods
  - **Android**: Android Studio, Android SDK

## Installation

### 1. Clone the Repository

```bash
git clone git@github.com:juliendkim/MoAI-SSH-SFTP.git
cd MoAI-SSH-SFTP
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Generate Localization Files

```bash
flutter gen-l10n
```

## Build Instructions

### macOS

```bash
flutter build macos --release
```

The app will be located at: `build/macos/Build/Products/Release/MoAI SSH・SFTP.app`

### Windows

```bash
flutter build windows --release
```

The app will be located at: `build/windows/x64/runner/Release/`

### Linux

```bash
flutter build linux --release
```

The app will be located at: `build/linux/x64/release/bundle/`

### iOS

```bash
flutter build ios --release
```

Open the Xcode project for signing:
```bash
open ios/Runner.xcworkspace
```

### Android

```bash
flutter build apk --release
```

The APK will be located at: `build/app/outputs/flutter-apk/app-release.apk`

## Running in Development Mode

### Run on Desktop (macOS/Windows/Linux)

```bash
flutter run -d macos    # macOS
flutter run -d windows  # Windows
flutter run -d linux    # Linux
```

### Run on Mobile

```bash
flutter devices              # List available devices
flutter run -d <device-id>   # Run on specific device
```

## Usage

### Adding a Host

1. Click the **+** button on the home screen
2. Fill in the host configuration:
   - **Name**: Friendly name for the host
   - **OS Type**: Select the operating system
   - **Hostname**: IP address or domain name
   - **Port**: SSH port (default: 22)
   - **Username**: SSH username
   - **Authentication**: Choose password or key file
3. **Save**

### Connecting via SSH

- **Double-click** a host card for quick SSH connection
- Or click the **SSH** button on the host card
- A new terminal tab will open with an active SSH session

### Connecting via SFTP

- Click the **SFTP** button on the host card
- The SFTP explorer will open with dual-pane file browsers
- Navigate directories and transfer files between local and remote systems

## Project Structure

```
lib/
├── l10n/                          # Localization files
│   ├── app_en.arb                # English translations
│   ├── app_ko.arb                # Korean translations
│   └── generated/                # Auto-generated localization code
├── models/                        # Data models
│   └── host.dart                 # Host configuration model
├── providers/                     # State management
│   └── host_provider.dart        # Host data provider
├── screens/                       # UI screens
│   ├── home_screen.dart          # Main host list screen
│   ├── connection_screen.dart    # SSH/SFTP tab container
│   ├── ssh_terminal_screen.dart  # SSH terminal UI
│   └── sftp_explorer_screen.dart # SFTP file browser UI
├── services/                      # Business logic
│   ├── host_storage_service.dart # Local storage for hosts
│   ├── ssh_service.dart          # SSH connection handling
│   └── sftp_service.dart         # SFTP operations
├── widgets/                       # Reusable widgets
│   ├── host_card.dart            # Host display card
│   └── host_form.dart            # Host configuration form
└── main.dart                      # Application entry point
```

## Troubleshooting

### Build Failures

- **Clean the build cache**:
  ```bash
  flutter clean
  flutter pub get
  ```

- **Update Flutter**:
  ```bash
  flutter upgrade
  ```

---

**Version**: 1.0.0+1
**Built with**: Flutter 3.10.4+
**Last Updated**: January 2026

## License

MIT License - see the [LICENSE](LICENSE) file for details
