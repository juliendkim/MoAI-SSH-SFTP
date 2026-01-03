# macOS 디렉토리 접근 권한 가이드

macOS 샌드박스 환경에서 디렉토리 접근을 위한 권한 처리 가이드입니다.

## 개요

macOS는 보안을 위해 앱 샌드박스를 사용합니다. 샌드박스 환경에서는 사용자가 명시적으로 허용하지 않은 디렉토리에 접근할 수 없습니다. 이 프로젝트는 **보안 스코프 북마크(Security-Scoped Bookmark)**를 사용하여 이 문제를 해결합니다.

## 구성 요소

### 1. Entitlements 설정

**macos/Runner/DebugProfile.entitlements** 및 **Release.entitlements**:

```xml
<key>com.apple.security.files.user-selected.read-write</key>
<true/>
<key>com.apple.security.files.home-directory.read-write</key>
<true/>
<key>com.apple.security.files.downloads.read-write</key>
<true/>
<key>com.apple.security.files.bookmarks.app-scope</key>
<true/>
```

- `user-selected.read-write`: 사용자가 선택한 파일/폴더 접근
- `home-directory.read-write`: 홈 디렉토리 접근
- `downloads.read-write`: 다운로드 폴더 접근
- `bookmarks.app-scope`: 보안 스코프 북마크 사용

### 2. 네이티브 macOS 코드

**macos/Runner/AppDelegate.swift**에 구현된 기능:

- `requestDirectoryAccess`: 디렉토리 선택 다이얼로그 표시 및 북마크 생성
- `checkDirectoryAccess`: 디렉토리 접근 권한 확인
- `listDirectory`: 디렉토리 내용 나열 (북마크 자동 사용)
- `saveBookmark`: 보안 스코프 북마크 저장
- `loadBookmark`: 보안 스코프 북마크 로드

### 3. Dart 서비스

**lib/services/file_access_service.dart**:

```dart
// 디렉토리 권한 요청
final result = await FileAccessService.requestDirectoryAccessMacOS(
  suggestedPath: '/Users/username/Documents',
);

// 권한 확인
bool hasAccess = await FileAccessService.checkDirectoryAccessMacOS(path);

// 디렉토리 나열 (권한 자동 요청)
List<FileSystemEntity> items = await FileAccessService.listDirectoryWithPermission(
  path,
  autoRequestPermission: true,
);
```

## 동작 방식

### 보안 스코프 북마크란?

macOS의 보안 스코프 북마크는 사용자가 한 번 허용한 디렉토리에 대한 접근 권한을 저장하는 메커니즘입니다.

1. 사용자가 NSOpenPanel을 통해 디렉토리 선택
2. 선택된 디렉토리에 대한 북마크 데이터 생성
3. 북마크를 UserDefaults에 저장
4. 이후 해당 디렉토리 접근 시 북마크 로드
5. 북마크로부터 URL 복원 및 보안 스코프 접근 시작

### 권한 자동 요청 흐름

```
디렉토리 접근 시도
    ↓
권한 확인
    ↓
권한 없음? → 사용자에게 선택 다이얼로그 표시
    ↓
사용자가 디렉토리 선택
    ↓
보안 스코프 북마크 생성 및 저장
    ↓
디렉토리 접근 성공
```

## 사용 예제

### 기본 사용법

```dart
import 'package:moai_ssh_sftp_client/services/file_access_service.dart';

// 권한이 필요한 디렉토리 나열
Future<void> listDocuments() async {
  final documentsPath = '/Users/username/Documents';

  // autoRequestPermission이 true면 권한이 없을 때 자동으로 다이얼로그 표시
  final items = await FileAccessService.listDirectoryWithPermission(
    documentsPath,
    autoRequestPermission: true,
  );

  for (var item in items) {
    print('${item.path} - ${item is Directory ? 'DIR' : 'FILE'}');
  }
}
```

### 수동 권한 요청

```dart
Future<void> requestAccessManually() async {
  // 사용자에게 직접 디렉토리 선택 요청
  final result = await FileAccessService.requestDirectoryAccessMacOS(
    suggestedPath: '/Users/username/Desktop',
  );

  if (result != null) {
    print('권한 획득: ${result['path']}');
    print('북마크 키: ${result['bookmarkKey']}');

    // 이후 해당 디렉토리는 자동으로 접근 가능
    final items = await FileAccessService.listDirectoryWithPermission(
      result['path'],
      autoRequestPermission: false,
    );
  }
}
```

### 권한 확인

```dart
Future<void> checkPermission(String path) async {
  final hasAccess = await FileAccessService.checkDirectoryAccessMacOS(path);

  if (hasAccess) {
    print('$path 접근 가능');
  } else {
    print('$path 접근 불가능 - 권한 필요');
  }
}
```

## 주의사항

1. **샌드박스 활성화 필요**: Release.entitlements에서 `com.apple.security.app-sandbox`가 `true`여야 합니다.

2. **사용자 동의 필수**: 모든 디렉토리 접근은 사용자가 명시적으로 선택해야 합니다.

3. **북마크 만료**: 북마크는 시간이 지나면 만료될 수 있습니다. 코드는 자동으로 갱신을 처리합니다.

4. **플랫폼 확인**: macOS에서만 동작합니다. 다른 플랫폼에서는 기존 방식을 사용합니다.

```dart
if (Platform.isMacOS) {
  // macOS 전용 로직
} else {
  // 다른 플랫폼
}
```

5. **앱 재시작**: 북마크는 앱이 종료되어도 유지되므로, 다음 실행 시 다시 권한을 요청할 필요가 없습니다.

## 테스트

예제 위젯을 실행하여 테스트할 수 있습니다:

```dart
import 'package:moai_ssh_sftp_client/widgets/file_access_example.dart';

// 앱에 추가
MaterialApp(
  home: FileAccessExample(),
)
```

위젯에서 다음을 테스트할 수 있습니다:
- 디렉토리 권한 요청
- 시스템 디렉토리 접근 확인
- 디렉토리 내용 나열

## 문제 해결

### PathAccessException이 계속 발생하는 경우

1. Entitlements 파일이 올바르게 설정되었는지 확인
2. 앱을 완전히 재빌드: `flutter clean && flutter build macos`
3. 북마크가 저장되었는지 확인
4. 디버그 모드에서 로그 확인

### 권한 다이얼로그가 표시되지 않는 경우

1. MethodChannel 이름이 일치하는지 확인
2. AppDelegate가 올바르게 초기화되었는지 확인
3. 에러 로그 확인

## 참고 자료

- [Apple - App Sandbox](https://developer.apple.com/documentation/security/app_sandbox)
- [Apple - Security-Scoped Bookmarks](https://developer.apple.com/documentation/foundation/url/2143023-bookmarkdata)
- [Flutter - Platform Channels](https://docs.flutter.dev/platform-integration/platform-channels)
