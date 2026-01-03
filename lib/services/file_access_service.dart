import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// macOS 디렉토리 접근을 위한 서비스
class FileAccessService {
  static const MethodChannel _channel = MethodChannel('com.moai.ssh_sftp/file_access');

  /// 디렉토리 내용 나열 (macOS 권한 자동 처리)
  static Future<List<FileSystemEntity>> listDirectoryWithPermission(
    String path, {
    bool autoRequestPermission = true,
  }) async {
    print('[Dart] listDirectoryWithPermission 호출: $path');

    if (!Platform.isMacOS) {
      print('[Dart] macOS 아님 - 일반 방식 사용');
      try {
        final directory = Directory(path);
        if (!await directory.exists()) {
          return [];
        }
        return await directory.list().toList();
      } catch (e) {
        print('[Dart] 디렉토리 나열 실패: $e');
        return [];
      }
    }

    // macOS: 네이티브 메서드 호출
    try {
      print('[Dart] 네이티브 listDirectory 호출 중...');
      final result = await _channel.invokeMethod('listDirectory', {
        'path': path,
      });

      print('[Dart] 네이티브 응답: $result');

      if (result is Map && result['success'] == true) {
        final items = result['items'] as List;
        print('[Dart] 성공: ${items.length}개 항목');
        return items.map((item) {
          final isDir = item['isDirectory'] as bool;
          final itemPath = item['path'] as String;
          return isDir ? Directory(itemPath) : File(itemPath);
        }).toList();
      }

      print('[Dart] 성공 플래그 없음');
      return [];
    } on PlatformException catch (e) {
      print('[Dart] PlatformException 발생: ${e.code} - ${e.message}');

      // PERMISSION_DENIED 에러인 경우 권한 요청
      if (e.code == 'PERMISSION_DENIED' && autoRequestPermission) {
        print('[Dart] 권한 없음 - 권한 요청 다이얼로그 표시');

        final accessResult = await requestDirectoryAccessMacOS(suggestedPath: path);

        if (accessResult != null) {
          print('[Dart] 권한 획득 성공 - 재시도');
          // 재시도 (무한 재귀 방지)
          return await listDirectoryWithPermission(path, autoRequestPermission: false);
        } else {
          print('[Dart] 권한 요청 취소됨');
          return [];
        }
      }

      print('[Dart] 다른 에러 또는 자동 요청 비활성화');
      return [];
    } catch (e) {
      print('[Dart] 예상치 못한 에러: $e');

      // 혹시 모를 권한 오류
      if (autoRequestPermission && e.toString().toLowerCase().contains('permission')) {
        print('[Dart] 권한 관련 에러 감지 - 권한 요청');

        final accessResult = await requestDirectoryAccessMacOS(suggestedPath: path);

        if (accessResult != null) {
          print('[Dart] 권한 획득 성공 - 재시도');
          return await listDirectoryWithPermission(path, autoRequestPermission: false);
        }
      }

      return [];
    }
  }

  /// 디렉토리 접근 권한 요청 (macOS 전용)
  static Future<Map<String, dynamic>?> requestDirectoryAccessMacOS({String? suggestedPath}) async {
    if (!Platform.isMacOS) {
      return null;
    }

    print('[Dart] requestDirectoryAccessMacOS 호출: $suggestedPath');

    try {
      final result = await _channel.invokeMethod('requestDirectoryAccess', {
        'suggestedPath': suggestedPath,
      });

      print('[Dart] requestDirectoryAccess 응답: $result');

      if (result is Map && result['success'] == true) {
        final path = result['path'] as String;
        final bookmarkKey = result['bookmarkKey'] as String;

        // SharedPreferences에 저장
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('bookmark_key_$path', bookmarkKey);

        print('[Dart] 권한 획득 및 북마크 저장 완료');

        return {
          'path': path,
          'bookmarkKey': bookmarkKey,
        };
      }

      print('[Dart] 권한 요청 취소됨');
      return null;
    } catch (e) {
      print('[Dart] requestDirectoryAccessMacOS 에러: $e');
      return null;
    }
  }

  /// 사용자에게 디렉토리 선택을 요청하고 경로를 반환
  static Future<String?> pickDirectory() async {
    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory != null) {
        print('선택된 디렉토리: $selectedDirectory');
      }
      return selectedDirectory;
    } catch (e) {
      print('디렉토리 선택 중 오류 발생: $e');
      return null;
    }
  }

  /// 여러 파일을 선택하고 경로 목록을 반환
  static Future<List<String>?> pickFiles({List<String>? allowedExtensions}) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: allowedExtensions != null ? FileType.custom : FileType.any,
        allowedExtensions: allowedExtensions,
      );

      if (result != null) {
        List<String> paths = result.paths.whereType<String>().toList();
        print('선택된 파일 개수: ${paths.length}');
        return paths;
      }

      return null;
    } catch (e) {
      print('파일 선택 중 오류 발생: $e');
      return null;
    }
  }

  /// 단일 파일을 선택하고 경로를 반환
  static Future<String?> pickSingleFile({List<String>? allowedExtensions}) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: allowedExtensions != null ? FileType.custom : FileType.any,
        allowedExtensions: allowedExtensions,
      );

      if (result != null && result.files.single.path != null) {
        String path = result.files.single.path!;
        print('선택된 파일: $path');
        return path;
      }

      return null;
    } catch (e) {
      print('파일 선택 중 오류 발생: $e');
      return null;
    }
  }

  /// 시스템 디렉토리 경로들을 반환
  static Future<Map<String, String>> getSystemDirectories() async {
    Map<String, String> directories = {};

    try {
      String home = Platform.environment['HOME'] ?? '';
      if (home.isNotEmpty) {
        directories['home'] = home;
        directories['desktop'] = '$home/Desktop';
        directories['documents'] = '$home/Documents';
        directories['downloads'] = '$home/Downloads';
        directories['pictures'] = '$home/Pictures';
        directories['music'] = '$home/Music';
        directories['movies'] = '$home/Movies';
      }

      final tempDir = await getTemporaryDirectory();
      directories['temp'] = tempDir.path;

      final appSupportDir = await getApplicationSupportDirectory();
      directories['appSupport'] = appSupportDir.path;

      if (Platform.isMacOS) {
        final downloadDir = await getDownloadsDirectory();
        if (downloadDir != null) {
          directories['downloadsPath'] = downloadDir.path;
        }
      }
    } catch (e) {
      print('시스템 디렉토리 경로 가져오기 오류: $e');
    }

    return directories;
  }

  /// 파일이나 디렉토리를 저장할 위치를 선택
  static Future<String?> pickSaveLocation({String? suggestedFileName}) async {
    try {
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: '저장 위치 선택',
        fileName: suggestedFileName,
      );

      if (outputFile != null) {
        print('저장 경로: $outputFile');
      }

      return outputFile;
    } catch (e) {
      print('저장 위치 선택 중 오류 발생: $e');
      return null;
    }
  }
}
