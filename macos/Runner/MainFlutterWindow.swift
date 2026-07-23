import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var localDirectoryAccessPlugin: LocalDirectoryAccessPlugin?
  private var launchScreenBridge: LaunchScreenBridge?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    self.backgroundColor = LaunchScreenView.backgroundColor
    self.contentMinSize = NSSize(width: 900, height: 600)
    var initialContentSize = NSSize(width: 1120, height: 780)
    if let visibleFrame = (self.screen ?? NSScreen.main)?.visibleFrame {
      initialContentSize.width = min(
        initialContentSize.width,
        max(self.contentMinSize.width, visibleFrame.width - 80))
      initialContentSize.height = min(
        initialContentSize.height,
        max(self.contentMinSize.height, visibleFrame.height - 80))
    }
    self.setContentSize(initialContentSize)
    self.center()
    self.titleVisibility = .hidden
    self.titlebarAppearsTransparent = true
    self.styleMask.insert(.fullSizeContentView)
    self.isMovableByWindowBackground = true

    RegisterGeneratedPlugins(registry: flutterViewController)
    launchScreenBridge = LaunchScreenBridge(
      messenger: flutterViewController.engine.binaryMessenger,
      containerView: flutterViewController.view)
    localDirectoryAccessPlugin = LocalDirectoryAccessPlugin(
      messenger: flutterViewController.engine.binaryMessenger,
      window: self)

    super.awakeFromNib()
  }
}

private final class LaunchScreenBridge {
  private let channel: FlutterMethodChannel
  private weak var launchView: LaunchScreenView?

  init(messenger: FlutterBinaryMessenger, containerView: NSView) {
    channel = FlutterMethodChannel(
      name: "com.kaiting.player/launch_screen",
      binaryMessenger: messenger)

    let launchView = LaunchScreenView(frame: containerView.bounds)
    launchView.translatesAutoresizingMaskIntoConstraints = false
    containerView.addSubview(launchView)
    NSLayoutConstraint.activate([
      launchView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
      launchView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
      launchView.topAnchor.constraint(equalTo: containerView.topAnchor),
      launchView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
    ])
    self.launchView = launchView

    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "hide" else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.hide()
      result(nil)
    }
  }

  private func hide() {
    guard let launchView else { return }
    NSAnimationContext.runAnimationGroup { context in
      context.duration = 0.18
      context.timingFunction = CAMediaTimingFunction(name: .easeOut)
      launchView.animator().alphaValue = 0
    } completionHandler: {
      launchView.removeFromSuperview()
    }
  }
}

private final class LaunchScreenView: NSView {
  static let backgroundColor = NSColor(
    srgbRed: 247 / 255,
    green: 247 / 255,
    blue: 248 / 255,
    alpha: 1)

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    wantsLayer = true
    layer?.backgroundColor = Self.backgroundColor.cgColor

    let imageView = NSImageView()
    imageView.image = NSImage(named: "LaunchImage")
    imageView.imageScaling = .scaleProportionallyUpOrDown
    imageView.translatesAutoresizingMaskIntoConstraints = false

    let title = NSTextField(labelWithString: "开听")
    title.font = .systemFont(ofSize: 24, weight: .semibold)
    title.textColor = NSColor(
      srgbRed: 28 / 255,
      green: 28 / 255,
      blue: 34 / 255,
      alpha: 1)
    title.alignment = .center
    title.translatesAutoresizingMaskIntoConstraints = false

    let tagline = NSTextField(labelWithString: "听自己的音乐")
    tagline.font = .systemFont(ofSize: 13, weight: .regular)
    tagline.textColor = NSColor(
      srgbRed: 112 / 255,
      green: 112 / 255,
      blue: 122 / 255,
      alpha: 1)
    tagline.alignment = .center
    tagline.translatesAutoresizingMaskIntoConstraints = false

    addSubview(imageView)
    addSubview(title)
    addSubview(tagline)
    NSLayoutConstraint.activate([
      imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
      imageView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -50),
      imageView.widthAnchor.constraint(equalToConstant: 144),
      imageView.heightAnchor.constraint(equalToConstant: 144),
      title.centerXAnchor.constraint(equalTo: centerXAnchor),
      title.centerYAnchor.constraint(equalTo: centerYAnchor, constant: 28),
      tagline.centerXAnchor.constraint(equalTo: centerXAnchor),
      tagline.centerYAnchor.constraint(equalTo: centerYAnchor, constant: 58),
    ])
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

private final class LocalDirectoryAccessPlugin {
  private let channel: FlutterMethodChannel
  private weak var window: NSWindow?
  private var activeURLs: [String: URL] = [:]

  init(messenger: FlutterBinaryMessenger, window: NSWindow) {
    channel = FlutterMethodChannel(
      name: "com.kaiting.player/local_directory_access",
      binaryMessenger: messenger)
    self.window = window
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
    let panel = NSOpenPanel()
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = false
    panel.canCreateDirectories = true
    panel.prompt = "选择"

    let completion: (NSApplication.ModalResponse) -> Void = { [weak self] response in
      guard response == .OK, let url = panel.url else {
        result(nil)
        return
      }
      do {
        let bookmark = try url.bookmarkData(
          options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
          includingResourceValuesForKeys: nil,
          relativeTo: nil)
        guard url.startAccessingSecurityScopedResource() else {
          result(self?.grant(
            url: url,
            status: "permissionRequired",
            bookmark: bookmark,
            isStale: false))
          return
        }
        self?.retain(url)
        result(self?.grant(
          url: url,
          status: "available",
          bookmark: bookmark,
          isStale: false))
      } catch {
        result(FlutterError(
          code: "bookmark_creation_failed",
          message: error.localizedDescription,
          details: nil))
      }
    }

    if let window {
      panel.beginSheetModal(for: window, completionHandler: completion)
    } else {
      panel.begin(completionHandler: completion)
    }
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
        options: [.withSecurityScope],
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
            options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
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
