import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    if !flag {
      // 모든 창이 닫혀 있으면 메인 창을 다시 표시
      if let window = mainFlutterWindow {
        window.makeKeyAndOrderFront(self)
      }
    }
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    let controller : FlutterViewController = mainFlutterWindow?.contentViewController as! FlutterViewController
    let channel = FlutterMethodChannel(name: "com.moai.ssh_sftp/file_access",
                                      binaryMessenger: controller.engine.binaryMessenger)

    channel.setMethodCallHandler({
      [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      guard let self = self else { return }

      switch call.method {
      case "requestDirectoryAccess":
        self.requestDirectoryAccess(call: call, result: result)
      case "listDirectory":
        self.listDirectory(call: call, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    })
  }

  // 디렉토리 접근 권한 요청
  private func requestDirectoryAccess(call: FlutterMethodCall, result: @escaping FlutterResult) {
    print("[Swift] requestDirectoryAccess 호출됨")

    // 메인 쓰레드에서 실행
    DispatchQueue.main.async {
      let panel = NSOpenPanel()
      panel.canChooseFiles = false
      panel.canChooseDirectories = true
      panel.allowsMultipleSelection = false
      panel.canCreateDirectories = false
      panel.message = "디렉토리 접근 권한을 허용하려면 선택하세요"
      panel.prompt = "권한 허용"

      if let args = call.arguments as? [String: Any],
         let suggestedPath = args["suggestedPath"] as? String {
        let url = URL(fileURLWithPath: suggestedPath)
        panel.directoryURL = url
        print("[Swift] 제안 경로: \(suggestedPath)")
      }

      print("[Swift] NSOpenPanel 표시 중...")

      panel.begin { response in
        print("[Swift] NSOpenPanel 응답: \(response.rawValue)")

        if response == .OK, let url = panel.url {
          print("[Swift] 선택된 경로: \(url.path)")

          // 보안 스코프 북마크 생성
          do {
            let bookmarkData = try url.bookmarkData(
              options: .withSecurityScope,
              includingResourceValuesForKeys: nil,
              relativeTo: nil
            )

            // 북마크를 UserDefaults에 저장
            let bookmarkKey = "bookmark_\(url.path)"
            UserDefaults.standard.set(bookmarkData, forKey: bookmarkKey)
            print("[Swift] 북마크 저장 성공: \(bookmarkKey)")

            result([
              "success": true,
              "path": url.path,
              "bookmarkKey": bookmarkKey
            ])
          } catch {
            print("[Swift] 북마크 생성 실패: \(error)")
            result(FlutterError(code: "BOOKMARK_ERROR",
                              message: "보안 북마크 생성 실패: \(error.localizedDescription)",
                              details: nil))
          }
        } else {
          print("[Swift] 사용자가 취소함")
          result(["success": false, "cancelled": true])
        }
      }
    }
  }

  // 디렉토리 내용 나열
  private func listDirectory(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let path = args["path"] as? String else {
      print("[Swift] listDirectory: 잘못된 인자")
      result(FlutterError(code: "INVALID_ARGS", message: "경로가 필요합니다", details: nil))
      return
    }

    print("[Swift] listDirectory 호출: \(path)")

    let url = URL(fileURLWithPath: path)
    let fileManager = FileManager.default

    // 북마크 확인
    let bookmarkKey = "bookmark_\(path)"
    var securityScopedURL: URL? = nil
    var didStartAccessing = false

    if let bookmarkData = UserDefaults.standard.data(forKey: bookmarkKey) {
      print("[Swift] 북마크 발견: \(bookmarkKey)")
      do {
        var isStale = false
        securityScopedURL = try URL(
          resolvingBookmarkData: bookmarkData,
          options: .withSecurityScope,
          relativeTo: nil,
          bookmarkDataIsStale: &isStale
        )

        if let secURL = securityScopedURL {
          didStartAccessing = secURL.startAccessingSecurityScopedResource()
          print("[Swift] 보안 스코프 접근 시작: \(didStartAccessing)")
        }
      } catch {
        print("[Swift] 북마크 로드 실패: \(error)")
      }
    } else {
      print("[Swift] 북마크 없음: \(bookmarkKey)")
    }

    defer {
      if didStartAccessing, let secURL = securityScopedURL {
        secURL.stopAccessingSecurityScopedResource()
        print("[Swift] 보안 스코프 접근 종료")
      }
    }

    // 디렉토리 읽기 시도
    do {
      let contents = try fileManager.contentsOfDirectory(
        at: url,
        includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
        options: [.skipsHiddenFiles]
      )

      print("[Swift] 디렉토리 읽기 성공: \(contents.count)개 항목")

      let items = contents.map { itemURL -> [String: Any] in
        var isDirectory: ObjCBool = false
        fileManager.fileExists(atPath: itemURL.path, isDirectory: &isDirectory)

        var size: Int64 = 0
        if let attributes = try? fileManager.attributesOfItem(atPath: itemURL.path),
           let fileSize = attributes[.size] as? Int64 {
          size = fileSize
        }

        return [
          "name": itemURL.lastPathComponent,
          "path": itemURL.path,
          "isDirectory": isDirectory.boolValue,
          "size": size
        ]
      }

      result(["success": true, "items": items])
    } catch let error as NSError {
      print("[Swift] 디렉토리 읽기 실패: \(error)")
      print("[Swift] Error code: \(error.code), domain: \(error.domain)")

      // 권한 오류인 경우 명확히 표시
      if error.code == 257 || error.domain == NSCocoaErrorDomain {
        result(FlutterError(
          code: "PERMISSION_DENIED",
          message: "권한 없음: \(path)",
          details: ["needsPermission": true, "path": path]
        ))
      } else {
        result(FlutterError(
          code: "LIST_ERROR",
          message: "디렉토리 나열 실패: \(error.localizedDescription)",
          details: nil
        ))
      }
    }
  }
}
