#include "flutter_window.h"

#include <optional>
#include <windows.h>
#include <shellapi.h>

#include "flutter/generated_plugin_registrant.h"
#include "resource.h"

#define WM_TRAY_ICON (WM_APP + 101)
#define ID_TRAY_OPEN 1001
#define ID_TRAY_EXIT 1002

namespace {

bool SetAutoStart(bool enable) {
  HKEY hKey;
  LONG res = RegOpenKeyExW(HKEY_CURRENT_USER,
                           L"Software\\Microsoft\\Windows\\CurrentVersion\\Run",
                           0, KEY_SET_VALUE | KEY_QUERY_VALUE, &hKey);
  if (res != ERROR_SUCCESS) {
    return false;
  }
  if (enable) {
    wchar_t exePath[MAX_PATH];
    GetModuleFileNameW(nullptr, exePath, MAX_PATH);
    std::wstring cmd = L"\"" + std::wstring(exePath) + L"\" --autostart";
    res = RegSetValueExW(hKey, L"Zaad", 0, REG_SZ,
                         reinterpret_cast<const BYTE*>(cmd.c_str()),
                         static_cast<DWORD>((cmd.length() + 1) * sizeof(wchar_t)));
  } else {
    res = RegDeleteValueW(hKey, L"Zaad");
  }
  RegCloseKey(hKey);
  return (res == ERROR_SUCCESS || res == ERROR_FILE_NOT_FOUND);
}

bool IsAutoStartEnabled() {
  HKEY hKey;
  LONG res = RegOpenKeyExW(HKEY_CURRENT_USER,
                           L"Software\\Microsoft\\Windows\\CurrentVersion\\Run",
                           0, KEY_QUERY_VALUE, &hKey);
  if (res != ERROR_SUCCESS) {
    return false;
  }
  wchar_t buffer[MAX_PATH];
  DWORD bufferSize = sizeof(buffer);
  DWORD type = REG_SZ;
  res = RegQueryValueExW(hKey, L"Zaad", nullptr, &type,
                         reinterpret_cast<LPBYTE>(buffer), &bufferSize);
  RegCloseKey(hKey);
  return (res == ERROR_SUCCESS);
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project, bool start_minimized)
    : project_(project), start_minimized_(start_minimized) {}

FlutterWindow::~FlutterWindow() {}

void FlutterWindow::CreateTrayIcon() {
  if (tray_icon_created_) return;
  NOTIFYICONDATAW nid = {};
  nid.cbSize = sizeof(NOTIFYICONDATAW);
  nid.hWnd = GetHandle();
  nid.uID = 1;
  nid.uFlags = NIF_ICON | NIF_MESSAGE | NIF_TIP;
  nid.uCallbackMessage = WM_TRAY_ICON;
  nid.hIcon = LoadIcon(GetModuleHandle(nullptr), MAKEINTRESOURCE(IDI_APP_ICON));
  wcscpy_s(nid.szTip, L"\x0632\x0627\x062F - \x0627\x0644\x0645\x0648\x0627\x0642\x064A\x062A \x0648\x0627\x0644\x0642\x0631\x0622\x0646 \x0627\x0644\x0643\x0631\x064A\x0645");
  Shell_NotifyIconW(NIM_ADD, &nid);
  tray_icon_created_ = true;
}

void FlutterWindow::RemoveTrayIcon() {
  if (tray_icon_created_) {
    NOTIFYICONDATAW nid = {};
    nid.cbSize = sizeof(NOTIFYICONDATAW);
    nid.hWnd = GetHandle();
    nid.uID = 1;
    Shell_NotifyIconW(NIM_DELETE, &nid);
    tray_icon_created_ = false;
  }
}

void FlutterWindow::ForceExitApp() {
  force_exit_ = true;
  RemoveTrayIcon();
  HWND hwnd = GetHandle();
  if (hwnd) {
    DestroyWindow(hwnd);
  }
  PostQuitMessage(0);
}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  // Setup desktop MethodChannel for tray, auto-start, and lifecycle control
  desktop_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "imsakia/desktop",
          &flutter::StandardMethodCodec::GetInstance());

  desktop_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "isAutoStartEnabled") {
          result->Success(flutter::EncodableValue(IsAutoStartEnabled()));
        } else if (call.method_name() == "setAutoStartEnabled") {
          bool enabled = true;
          const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
          if (args) {
            auto it = args->find(flutter::EncodableValue("enabled"));
            if (it != args->end()) {
              enabled = std::get<bool>(it->second);
            }
          }
          result->Success(flutter::EncodableValue(SetAutoStart(enabled)));
        } else if (call.method_name() == "showWindow") {
          HWND hwnd = GetHandle();
          if (hwnd) {
            ShowWindow(hwnd, SW_SHOW);
            ShowWindow(hwnd, SW_RESTORE);
            SetForegroundWindow(hwnd);
          }
          result->Success();
        } else if (call.method_name() == "hideWindow") {
          HWND hwnd = GetHandle();
          if (hwnd) {
            ShowWindow(hwnd, SW_HIDE);
          }
          result->Success();
        } else if (call.method_name() == "exitApp") {
          result->Success();
          ForceExitApp();
        } else {
          result->NotImplemented();
        }
      });

  // Create System Tray icon immediately
  CreateTrayIcon();

  // If launching minimized (auto-start with Windows), do not show window on first frame
  flutter_controller_->engine()->SetNextFrameCallback([this]() {
    if (!start_minimized_) {
      this->Show();
    }
  });

  // Force first frame redraw so Flutter engine warms up and runs services
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  RemoveTrayIcon();
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }
  Win32Window::OnDestroy();
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
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;

    case WM_CLOSE: {
      // Requirement 3: Closing the main window using X button must hide it instead of terminating
      if (!force_exit_) {
        ShowWindow(hwnd, SW_HIDE);
        return 0;
      }
      break;
    }

    case WM_TRAY_ICON: {
      if (lparam == WM_LBUTTONUP || lparam == WM_LBUTTONDBLCLK) {
        ShowWindow(hwnd, SW_SHOW);
        ShowWindow(hwnd, SW_RESTORE);
        SetForegroundWindow(hwnd);
        if (desktop_channel_) {
          desktop_channel_->InvokeMethod("onWindowShown", nullptr);
        }
        return 0;
      } else if (lparam == WM_RBUTTONUP) {
        POINT pt;
        GetCursorPos(&pt);
        HMENU hMenu = CreatePopupMenu();
        InsertMenuW(hMenu, 0, MF_BYPOSITION | MF_STRING, ID_TRAY_OPEN, L"\x0641\x062A\x062D \x0632\x0627\x062F");
        InsertMenuW(hMenu, 1, MF_BYPOSITION | MF_SEPARATOR, 0, nullptr);
        InsertMenuW(hMenu, 2, MF_BYPOSITION | MF_STRING, ID_TRAY_EXIT, L"\x062E\x0631\x0648\x062C \x0645\x0646 \x0632\x0627\x062F");
        SetForegroundWindow(hwnd);
        int cmd = TrackPopupMenu(hMenu, TPM_RETURNCMD | TPM_RIGHTBUTTON, pt.x, pt.y, 0, hwnd, nullptr);
        DestroyMenu(hMenu);

        if (cmd == ID_TRAY_OPEN) {
          ShowWindow(hwnd, SW_SHOW);
          ShowWindow(hwnd, SW_RESTORE);
          SetForegroundWindow(hwnd);
          if (desktop_channel_) {
            desktop_channel_->InvokeMethod("onWindowShown", nullptr);
          }
        } else if (cmd == ID_TRAY_EXIT) {
          // Requirement 3: True Exit Behavior
          if (desktop_channel_) {
            desktop_channel_->InvokeMethod("onExitRequested", nullptr);
            // Safety timeout: if Flutter does not finish cleanup within 1000ms, force exit
            SetTimer(hwnd, 9998, 1000, [](HWND h, UINT, UINT_PTR id, DWORD) {
              KillTimer(h, id);
              PostQuitMessage(0);
            });
          } else {
            ForceExitApp();
          }
        }
        return 0;
      }
      break;
    }

    case WM_POWERBROADCAST: {
      if (wparam == PBT_APMRESUMEAUTOMATIC || wparam == PBT_APMRESUMESUSPEND) {
        if (desktop_channel_) {
          desktop_channel_->InvokeMethod("onSystemResumeOrTimeChange", nullptr);
        }
      }
      break;
    }

    case WM_TIMECHANGE: {
      if (desktop_channel_) {
        desktop_channel_->InvokeMethod("onSystemResumeOrTimeChange", nullptr);
      }
      break;
    }
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
