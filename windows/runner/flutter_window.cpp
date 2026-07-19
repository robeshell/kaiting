#include "flutter_window.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <flutter_windows.h>

#include <optional>

#include "flutter/generated_plugin_registrant.h"

namespace {

/// Method channel name matching the Dart-side constant.
constexpr char kWindowChannelName[] = "com.soundplayer.sound_player/window";

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  // Register the window-control method channel so Flutter can request
  // minimize / maximize / restore / close and window-drag operations, and
  // receive maximize-state change events.
  window_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), kWindowChannelName,
          &flutter::StandardMethodCodec::GetInstance());
  window_channel_->SetMethodCallHandler(
      [window_handle = GetHandle()](
          const flutter::MethodCall<flutter::EncodableValue>& call,
          std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
              result) {
        const auto& method = call.method_name();
        if (method == "minimize") {
          ShowWindow(window_handle, SW_MINIMIZE);
          result->Success();
        } else if (method == "maximize") {
          ShowWindow(window_handle, SW_MAXIMIZE);
          result->Success();
        } else if (method == "restore") {
          ShowWindow(window_handle, SW_RESTORE);
          result->Success();
        } else if (method == "close") {
          PostMessage(window_handle, WM_CLOSE, 0, 0);
          result->Success();
        } else if (method == "isMaximized") {
          BOOL maximized = IsZoomed(window_handle);
          result->Success(flutter::EncodableValue(maximized != FALSE));
        } else if (method == "startDrag") {
          // Release any active mouse capture and initiate a window-move
          // drag — the standard pattern for Flutter custom title bars.
          ReleaseCapture();
          SendMessage(window_handle, WM_NCLBUTTONDOWN, HTCAPTION, 0);
          result->Success();
        } else {
          result->NotImplemented();
        }
      });

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  window_channel_ = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

void FlutterWindow::NotifyMaximizedChanged() {
  if (!window_channel_) {
    return;
  }
  const bool maximized = IsZoomed(GetHandle()) != FALSE;
  if (has_reported_maximized_ && maximized == last_reported_maximized_) {
    return;
  }
  has_reported_maximized_ = true;
  last_reported_maximized_ = maximized;
  window_channel_->InvokeMethod(
      "maximizedChanged",
      std::make_unique<flutter::EncodableValue>(maximized));
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_GETMINMAXINFO: {
      auto* min_max_info = reinterpret_cast<MINMAXINFO*>(lparam);
      const HMONITOR monitor =
          MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
      const UINT dpi = FlutterDesktopGetDpiForMonitor(monitor);
      min_max_info->ptMinTrackSize.x = MulDiv(900, dpi, USER_DEFAULT_SCREEN_DPI);
      min_max_info->ptMinTrackSize.y = MulDiv(600, dpi, USER_DEFAULT_SCREEN_DPI);
      return 0;
    }
    case WM_SIZE: {
      // Keep Flutter chrome (maximize / restore icon) in sync with system
      // actions: Win+Up, snap layouts, caption double-click, etc.
      if (wparam == SIZE_MAXIMIZED || wparam == SIZE_RESTORED ||
          wparam == SIZE_MINIMIZED) {
        NotifyMaximizedChanged();
      }
      break;
    }
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
