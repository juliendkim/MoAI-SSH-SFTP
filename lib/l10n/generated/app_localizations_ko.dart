// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => 'MoAI SSH/SFTP';

  @override
  String get noHostsConfigured => '설정된 호스트가 없습니다';

  @override
  String get addHost => '호스트 추가';

  @override
  String get deleteHostTitle => '호스트 삭제';

  @override
  String deleteHostContent(String name) {
    return '\"$name\" 호스트를 삭제하시겠습니까?';
  }

  @override
  String get cancel => '취소';

  @override
  String get delete => '삭제';

  @override
  String get ssh => 'SSH';

  @override
  String get sftp => 'SFTP';

  @override
  String get hostName => '이름';

  @override
  String get hostHostname => '호스트명';

  @override
  String get hostPort => '포트';

  @override
  String get hostUsername => '사용자명';

  @override
  String get hostAuthType => '인증 방식';

  @override
  String get hostKeyFile => '키 파일';

  @override
  String get addNewHost => '새 호스트 추가';

  @override
  String get editHost => '호스트 편집';

  @override
  String get labelName => '이름';

  @override
  String get labelHostname => '호스트명/IP';

  @override
  String get labelPort => '포트';

  @override
  String get labelUsername => '사용자명';

  @override
  String get labelPassword => '비밀번호';

  @override
  String get labelKeyFilePath => '키 파일 경로';

  @override
  String get labelOS => '운영체제';

  @override
  String get labelAuthType => '인증 방식';

  @override
  String get validatorName => '이름을 입력하세요';

  @override
  String get validatorHostname => '호스트명을 입력하세요';

  @override
  String get validatorPort => '포트를 입력하세요';

  @override
  String get validatorPortRange => '유효한 포트를 입력하세요 (1-65535)';

  @override
  String get validatorUsername => '사용자명을 입력하세요';

  @override
  String get validatorPassword => '비밀번호를 입력하세요';

  @override
  String get validatorKeyFile => '키 파일을 선택하세요';

  @override
  String get save => '저장';

  @override
  String get reselectKeyFile => '보안을 위해 SSH 키 파일을 다시 선택해주세요';

  @override
  String failedToReadKeyFile(Object error) {
    return '키 파일 읽기 실패: $error';
  }

  @override
  String get hideHiddenFiles => '숨김 파일 숨기기';

  @override
  String get showHiddenFiles => '숨김 파일 보기';

  @override
  String connectingTo(String host) {
    return '$host에 연결 중...';
  }

  @override
  String get connectedSuccessfully => '연결 성공!';

  @override
  String connectionFailed(Object error) {
    return '연결 실패: $error';
  }

  @override
  String get retry => '재시도';

  @override
  String get local => '로컬';

  @override
  String remote(String host) {
    return '원격 - $host';
  }

  @override
  String get newFolder => '새 폴더';

  @override
  String get upload => '업로드';

  @override
  String get download => '다운로드';

  @override
  String get rename => '이름 변경';

  @override
  String get copy => '복사';

  @override
  String get move => '이동';

  @override
  String get folderConflict => '폴더 충돌';

  @override
  String get fileConflict => '파일 충돌';

  @override
  String conflictContent(String type, String name) {
    return '$type \"$name\"이(가) 이미 존재합니다.';
  }

  @override
  String get conflictQuestion => '어떻게 처리하시겠습니까?';

  @override
  String get merge => '병합';

  @override
  String get overwrite => '덮어쓰기';

  @override
  String get skip => '건너뛰기';

  @override
  String transferComplete(String operation) {
    return '$operation 완료';
  }

  @override
  String filesCount(int count) {
    return '파일: $count';
  }

  @override
  String foldersCount(int count) {
    return '폴더: $count';
  }

  @override
  String size(String size) {
    return '크기: $size';
  }

  @override
  String time(String time) {
    return '시간: $time';
  }

  @override
  String downloadFailed(Object error) {
    return '다운로드 실패: $error';
  }

  @override
  String uploadFailed(Object error) {
    return '업로드 실패: $error';
  }

  @override
  String deleted(String name) {
    return '$name 삭제됨';
  }

  @override
  String deleteFailed(Object error) {
    return '삭제 실패: $error';
  }

  @override
  String copiedItems(int count) {
    return '$count개 항목 복사됨';
  }

  @override
  String copyFailed(Object error) {
    return '복사 실패: $error';
  }

  @override
  String get copyTo => '복사';

  @override
  String get moveTo => '이동';

  @override
  String get destinationPath => '대상 경로';

  @override
  String get enterDestinationPath => '대상 디렉토리 경로 입력';

  @override
  String get createFolder => '폴더 생성';

  @override
  String get folderName => '폴더 이름';

  @override
  String get enterFolderName => '새 폴더 이름 입력';

  @override
  String get create => '생성';

  @override
  String get renameTitle => '이름 변경';

  @override
  String get newName => '새 이름';

  @override
  String get enterNewName => '새 이름 입력';

  @override
  String failedToCreateDirectory(Object error) {
    return '디렉토리 생성 실패: $error';
  }

  @override
  String failedToRename(Object error) {
    return '이름 변경 실패: $error';
  }

  @override
  String get folder => '폴더';

  @override
  String get file => '파일';

  @override
  String get uploadFileTitle => '파일 업로드';

  @override
  String uploadFileContent(String name) {
    return '\"$name\" 파일을 원격 디렉토리로 업로드하시겠습니까?';
  }

  @override
  String get downloadFileTitle => '파일 다운로드';

  @override
  String downloadFileContent(String name) {
    return '\"$name\" 파일을 로컬 디렉토리로 다운로드하시겠습니까?';
  }

  @override
  String itemsSelected(int count) {
    return '$count개 항목';
  }

  @override
  String durationMinSec(int minutes, int seconds) {
    return '$minutes분 $seconds초';
  }

  @override
  String durationSec(int seconds) {
    return '$seconds초';
  }

  @override
  String listingFailed(Object error) {
    return '파일 목록 로드 실패: $error';
  }
}
