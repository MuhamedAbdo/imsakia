#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <flutter/encodable_value.h>
#include <shellapi.h>

#include <memory>
#include <string>

#include "win32_window.h"

// A window that hosts a Flutter view and manages System Tray and desktop lifecycle.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project, bool start_minimized = false);
  virtual ~FlutterWindow();

  void ForceExitApp();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  void CreateTrayIcon();
  void RemoveTrayIcon();

  // The project to run.
  flutter::DartProject project_;

  bool start_minimized_ = false;
  bool tray_icon_created_ = false;
  bool force_exit_ = false;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  // Method channel for desktop communication
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> desktop_channel_;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
