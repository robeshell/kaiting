import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var localDirectoryAccessPlugin: IOSLocalDirectoryAccessPlugin?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    localDirectoryAccessPlugin = IOSLocalDirectoryAccessPlugin(
      messenger: engineBridge.applicationRegistrar.messenger(),
      viewControllerProvider: {
        UIApplication.shared.connectedScenes
          .compactMap { $0 as? UIWindowScene }
          .flatMap(\.windows)
          .first(where: \.isKeyWindow)?
          .rootViewController
      })
  }
}

private final class IOSLocalDirectoryAccessPlugin: NSObject, UIDocumentPickerDelegate {
  private let channel: FlutterMethodChannel
  private let viewControllerProvider: () -> UIViewController?
  private var pendingResult: FlutterResult?
  private var activeURLs: [String: URL] = [:]

  init(
    messenger: FlutterBinaryMessenger,
    viewControllerProvider: @escaping () -> UIViewController?
  ) {
    channel = FlutterMethodChannel(
      name: "com.soundplayer.sound_player/local_directory_access",
      binaryMessenger: messenger)
    self.viewControllerProvider = viewControllerProvider
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  deinit {
    for url in activeURLs.values {
      url.stopAccessingSecurityScopedResource()
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "pickDirectory":
      pickDirectory(result: result)
    case "restoreDirectory":
      restoreDirectory(call.arguments, result: result)
    case "releaseDirectory":
      releaseDirectory(call.arguments)
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func pickDirectory(result: @escaping FlutterResult) {
    guard pendingResult == nil else {
      result(FlutterError(
        code: "directory_picker_active",
        message: "A directory picker is already active.",
        details: nil))
      return
    }
    guard let presenter = viewControllerProvider() else {
      result(FlutterError(
        code: "directory_picker_unavailable",
        message: "No view controller is available to present the directory picker.",
        details: nil))
      return
    }

    pendingResult = result
    let picker = UIDocumentPickerViewController(
      documentTypes: ["public.folder"],
      in: .open)
    picker.allowsMultipleSelection = false
    picker.delegate = self
    presenter.present(picker, animated: true)
  }

  func documentPicker(
    _ controller: UIDocumentPickerViewController,
    didPickDocumentsAt urls: [URL]
  ) {
    guard let result = takePendingResult(), let url = urls.first else {
      return
    }
    guard url.startAccessingSecurityScopedResource() else {
      result(FlutterError(
        code: "directory_access_denied",
        message: "The selected directory could not be accessed.",
        details: nil))
      return
    }

    do {
      let bookmark = try url.bookmarkData(
        options: [],
        includingResourceValuesForKeys: nil,
        relativeTo: nil)
      retain(url)
      result(grant(
        url: url,
        status: "available",
        bookmark: bookmark,
        isStale: false))
    } catch {
      url.stopAccessingSecurityScopedResource()
      result(FlutterError(
        code: "bookmark_creation_failed",
        message: error.localizedDescription,
        details: nil))
    }
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    takePendingResult()?(nil)
  }

  private func restoreDirectory(_ arguments: Any?, result: @escaping FlutterResult) {
    guard
      let arguments = arguments as? [String: Any],
      let rootURI = arguments["rootUri"] as? String,
      let bookmarkData = arguments["permissionToken"] as? FlutterStandardTypedData
    else {
      result(FlutterError(
        code: "invalid_directory_grant",
        message: "A root URI and security-scoped bookmark are required.",
        details: nil))
      return
    }

    do {
      var isStale = false
      let url = try URL(
        resolvingBookmarkData: bookmarkData.data,
        options: [],
        relativeTo: nil,
        bookmarkDataIsStale: &isStale)
      guard url.startAccessingSecurityScopedResource() else {
        result(grant(
          url: url,
          status: "permissionRequired",
          bookmark: bookmarkData.data,
          isStale: isStale))
        return
      }
      retain(url)
      let refreshedBookmark = isStale
          ? try url.bookmarkData(
            options: [],
            includingResourceValuesForKeys: nil,
            relativeTo: nil)
        : bookmarkData.data
      result(grant(
        url: url,
        status: FileManager.default.fileExists(atPath: url.path)
          ? "available"
          : "unavailable",
        bookmark: refreshedBookmark,
        isStale: isStale))
    } catch {
      let fallbackURL = URL(string: rootURI) ?? URL(fileURLWithPath: rootURI)
      result(grant(
        url: fallbackURL,
        status: "permissionRequired",
        bookmark: bookmarkData.data,
        isStale: false))
    }
  }

  private func releaseDirectory(_ arguments: Any?) {
    guard
      let arguments = arguments as? [String: Any],
      let rootURI = arguments["rootUri"] as? String,
      let url = activeURLs.removeValue(forKey: rootURI)
    else {
      return
    }
    url.stopAccessingSecurityScopedResource()
  }

  private func takePendingResult() -> FlutterResult? {
    defer { pendingResult = nil }
    return pendingResult
  }

  private func retain(_ url: URL) {
    let key = url.absoluteString
    if let previous = activeURLs.updateValue(url, forKey: key) {
      previous.stopAccessingSecurityScopedResource()
    }
  }

  private func grant(
    url: URL,
    status: String,
    bookmark: Data,
    isStale: Bool
  ) -> [String: Any] {
    return [
      "rootUri": url.absoluteString,
      "displayName": url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent,
      "status": status,
      "permissionToken": FlutterStandardTypedData(bytes: bookmark),
      "isStale": isStale,
    ]
  }
}
