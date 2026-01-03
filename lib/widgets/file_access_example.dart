import 'package:flutter/material.dart';
import '../services/file_access_service.dart';

/// macOS 디렉토리 접근 예제 위젯
class FileAccessExample extends StatefulWidget {
  const FileAccessExample({super.key});

  @override
  State<FileAccessExample> createState() => _FileAccessExampleState();
}

class _FileAccessExampleState extends State<FileAccessExample> {
  String _statusMessage = '준비됨';
  Map<String, String> _systemDirectories = {};

  @override
  void initState() {
    super.initState();
    _loadSystemDirectories();
  }

  Future<void> _loadSystemDirectories() async {
    final directories = await FileAccessService.getSystemDirectories();
    setState(() {
      _systemDirectories = directories;
      _statusMessage = '시스템 디렉토리 로드 완료';
    });
  }

  Future<void> _pickDirectory() async {
    final path = await FileAccessService.pickDirectory();
    setState(() {
      if (path != null) {
        _statusMessage = '선택된 디렉토리: $path';
      } else {
        _statusMessage = '디렉토리 선택 취소됨';
      }
    });
  }

  Future<void> _pickFile() async {
    final path = await FileAccessService.pickSingleFile();
    setState(() {
      if (path != null) {
        _statusMessage = '선택된 파일: $path';
      } else {
        _statusMessage = '파일 선택 취소됨';
      }
    });
  }

  Future<void> _pickMultipleFiles() async {
    final paths = await FileAccessService.pickFiles();
    setState(() {
      if (paths != null && paths.isNotEmpty) {
        _statusMessage = '선택된 파일 ${paths.length}개:\n${paths.join('\n')}';
      } else {
        _statusMessage = '파일 선택 취소됨';
      }
    });
  }

  Future<void> _checkAccess(String path) async {
    setState(() {
      _statusMessage = '$path 접근 시도 중...';
    });

    // 권한 자동 요청하며 디렉토리 나열
    final entities = await FileAccessService.listDirectoryWithPermission(
      path,
      autoRequestPermission: true,
    );

    setState(() {
      if (entities.isNotEmpty) {
        _statusMessage = '$path 접근 성공!\n${entities.length}개 항목 발견';
      } else {
        _statusMessage = '$path 빈 디렉토리 또는 접근 실패';
      }
    });
  }

  Future<void> _requestDirectoryAccess() async {
    final result = await FileAccessService.requestDirectoryAccessMacOS();

    setState(() {
      if (result != null) {
        _statusMessage = '권한 획득 성공!\n경로: ${result['path']}\n북마크: ${result['bookmarkKey']}';
      } else {
        _statusMessage = '권한 요청 취소됨';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('macOS 디렉토리 접근 예제'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 상태 메시지
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  _statusMessage,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 버튼들
            ElevatedButton.icon(
              onPressed: _requestDirectoryAccess,
              icon: const Icon(Icons.security),
              label: const Text('디렉토리 권한 요청 (macOS)'),
            ),
            const SizedBox(height: 8),

            ElevatedButton.icon(
              onPressed: _pickDirectory,
              icon: const Icon(Icons.folder_open),
              label: const Text('디렉토리 선택'),
            ),
            const SizedBox(height: 8),

            ElevatedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.insert_drive_file),
              label: const Text('파일 선택'),
            ),
            const SizedBox(height: 8),

            ElevatedButton.icon(
              onPressed: _pickMultipleFiles,
              icon: const Icon(Icons.file_copy),
              label: const Text('여러 파일 선택'),
            ),
            const SizedBox(height: 16),

            // 시스템 디렉토리 목록
            const Text(
              '시스템 디렉토리:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: ListView.builder(
                itemCount: _systemDirectories.length,
                itemBuilder: (context, index) {
                  final entry = _systemDirectories.entries.elementAt(index);
                  return Card(
                    child: ListTile(
                      title: Text(entry.key),
                      subtitle: Text(
                        entry.value,
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.check_circle_outline),
                        onPressed: () => _checkAccess(entry.value),
                        tooltip: '접근 권한 확인',
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
