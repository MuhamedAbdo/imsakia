#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  bool start_minimized = false;
  for (const auto& arg : command_line_arguments) {
    if (arg == "--autostart" || arg == "--minimized" || arg == "-minimized") {
      start_minimized = true;
      break;
    }
  }

  // Single Instance Protection
  HANDLE mutex = ::CreateMutexW(nullptr, TRUE, kAppSingleInstanceMutex);
  if (::GetLastError() == ERROR_ALREADY_EXISTS) {
    if (!start_minimized) {
      // Find the existing window of the running instance and restore/show it
      HWND existing_hwnd = ::FindWindowW(kAppWindowClassName, nullptr);
      if (existing_hwnd != nullptr) {
        DWORD pid = 0;
        ::GetWindowThreadProcessId(existing_hwnd, &pid);
        if (pid != 0) {
          ::AllowSetForegroundWindow(pid);
        }
        if (::IsIconic(existing_hwnd)) {
          ::ShowWindow(existing_hwnd, SW_RESTORE);
        } else {
          ::ShowWindow(existing_hwnd, SW_SHOW);
        }
        ::SetForegroundWindow(existing_hwnd);
      }

      // Also broadcast the registered show message to ensure the window wakes up
      UINT show_msg = ::RegisterWindowMessageW(kAppShowWindowMessage);
      if (show_msg != 0) {
        ::PostMessageW(HWND_BROADCAST, show_msg, 0, 0);
      }
    }

    if (mutex != nullptr) {
      ::CloseHandle(mutex);
    }
    return EXIT_SUCCESS;
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");
  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project, start_minimized);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"imsakia", origin, size)) {
    if (mutex != nullptr) {
      ::ReleaseMutex(mutex);
      ::CloseHandle(mutex);
    }
    ::CoUninitialize();
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  if (mutex != nullptr) {
    ::ReleaseMutex(mutex);
    ::CloseHandle(mutex);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
