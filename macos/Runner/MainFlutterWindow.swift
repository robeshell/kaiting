import Cocoa
import CoreImage
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  /// Brand `layoutMetrics.desktopWindow` — keep side rail (medium min / wide default).
  private let minContentSize = NSSize(width: 1024, height: 700)
  private let defaultContentSize = NSSize(width: 1280, height: 800)
  private let sidebarMaterialWidth: CGFloat = 236

  private var localDirectoryAccessPlugin: LocalDirectoryAccessPlugin?
  private var launchScreenBridge: LaunchScreenBridge?
  private var closeBehaviorBridge: CloseBehaviorBridge?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let containerViewController = NSViewController()
    let containerView = NSView()
    let sidebarVibrancy = PassThroughVisualEffectView()

    containerView.wantsLayer = true
    containerView.layer?.backgroundColor = NSColor.clear.cgColor
    // Codex's light sidebar keeps a bright milky base even over dark windows.
    // Force the light sidebar appearance, then let Flutter add the final veil.
    sidebarVibrancy.material = .sidebar
    sidebarVibrancy.appearance = NSAppearance(named: .vibrantLight)
    sidebarVibrancy.blendingMode = .behindWindow
    // Keep the blur/color response stable when another application is focused.
    sidebarVibrancy.state = .active
    sidebarVibrancy.wantsLayer = true
    if let colorControls = CIFilter(name: "CIColorControls") {
      // Keep neutral backdrops neutral while allowing saturated windows to
      // tint the milky veil, matching the color bleed in the Codex reference.
      colorControls.setValue(1.8, forKey: kCIInputSaturationKey)
      sidebarVibrancy.layer?.filters = [colorControls]
    }
    sidebarVibrancy.translatesAutoresizingMaskIntoConstraints = false
    flutterViewController.backgroundColor = .clear
    flutterViewController.view.translatesAutoresizingMaskIntoConstraints = false

    containerView.addSubview(sidebarVibrancy)
    containerView.addSubview(flutterViewController.view)
    containerViewController.view = containerView
    containerViewController.addChild(flutterViewController)
    NSLayoutConstraint.activate([
      sidebarVibrancy.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
      sidebarVibrancy.topAnchor.constraint(equalTo: containerView.topAnchor),
      sidebarVibrancy.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
      sidebarVibrancy.widthAnchor.constraint(equalToConstant: sidebarMaterialWidth),
      flutterViewController.view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
      flutterViewController.view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
      flutterViewController.view.topAnchor.constraint(equalTo: containerView.topAnchor),
      flutterViewController.view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
    ])

    self.contentViewController = containerViewController
    self.isOpaque = false
    self.backgroundColor = .clear
    self.contentMinSize = minContentSize
    self.minSize = self.frameRect(
      forContentRect: NSRect(origin: .zero, size: minContentSize)
    ).size
    var initialContentSize = defaultContentSize
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
      containerView: containerView)
    closeBehaviorBridge = CloseBehaviorBridge(
      messenger: flutterViewController.engine.binaryMessenger,
      onChange: { value in
        (NSApp.delegate as? AppDelegate)?.setCloseToBackground(value)
      })
    localDirectoryAccessPlugin = LocalDirectoryAccessPlugin(
      messenger: flutterViewController.engine.binaryMessenger,
      window: self)

    super.awakeFromNib()
    (NSApp.delegate as? AppDelegate)?.attach(mainWindow: self)
  }
}

/// The vibrancy layer only paints the backdrop. Flutter owns all interaction.
private final class PassThroughVisualEffectView: NSVisualEffectView {
  override func hitTest(_ point: NSPoint) -> NSView? { nil }
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

private final class CloseBehaviorBridge {
  private let channel: FlutterMethodChannel

  init(messenger: FlutterBinaryMessenger, onChange: @escaping (Bool) -> Void) {
    channel = FlutterMethodChannel(
      name: "com.kaiting.player/window",
      binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "setCloseToBackground" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let value = call.arguments as? Bool else {
        result(FlutterError(
          code: "invalid_arguments",
          message: "Expected a boolean",
          details: nil))
        return
      }
      onChange(value)
      result(nil)
    }
  }
}

private final class LaunchScreenView: NSView {
  static let backgroundColor = NSColor(
    srgbRed: 1,
    green: 1,
    blue: 1,
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
