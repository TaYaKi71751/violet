#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <string>

#include "app_links/app_links_plugin_c_api.h"
#include "flutter_window.h"
#include "utils.h"

namespace {

constexpr wchar_t kWindowTitle[] = L"violet";
constexpr wchar_t kUrlScheme[] = L"violet";

bool SetRegistryString(HKEY root, const std::wstring& key,
                       const std::wstring& value_name,
                       const std::wstring& value) {
  HKEY handle;
  const auto create_result =
      ::RegCreateKeyExW(root, key.c_str(), 0, nullptr, 0, KEY_SET_VALUE,
                        nullptr, &handle, nullptr);
  if (create_result != ERROR_SUCCESS) {
    return false;
  }

  const auto set_result = ::RegSetValueExW(
      handle, value_name.empty() ? nullptr : value_name.c_str(), 0, REG_SZ,
      reinterpret_cast<const BYTE*>(value.c_str()),
      static_cast<DWORD>((value.size() + 1) * sizeof(wchar_t)));
  ::RegCloseKey(handle);

  return set_result == ERROR_SUCCESS;
}

void RegisterUrlProtocol() {
  wchar_t executable_path[MAX_PATH];
  const auto length =
      ::GetModuleFileNameW(nullptr, executable_path, MAX_PATH);
  if (length == 0 || length == MAX_PATH) {
    return;
  }

  const std::wstring prefix =
      std::wstring(L"Software\\Classes\\") + kUrlScheme;
  const std::wstring command =
      L"\"" + std::wstring(executable_path) + L"\" \"%1\"";

  SetRegistryString(HKEY_CURRENT_USER, prefix, L"", L"URL:Violet");
  SetRegistryString(HKEY_CURRENT_USER, prefix, L"URL Protocol", L"");
  SetRegistryString(HKEY_CURRENT_USER, prefix + L"\\shell\\open\\command",
                    L"", command);
}

bool SendAppLinkToInstance(const std::wstring& title) {
  HWND hwnd = ::FindWindow(L"FLUTTER_RUNNER_WIN32_WINDOW", title.c_str());

  if (!hwnd) {
    return false;
  }

  SendAppLink(hwnd);

  WINDOWPLACEMENT place = {sizeof(WINDOWPLACEMENT)};
  GetWindowPlacement(hwnd, &place);

  switch (place.showCmd) {
    case SW_SHOWMAXIMIZED:
      ShowWindow(hwnd, SW_SHOWMAXIMIZED);
      break;
    case SW_SHOWMINIMIZED:
      ShowWindow(hwnd, SW_RESTORE);
      break;
    default:
      ShowWindow(hwnd, SW_NORMAL);
      break;
  }

  SetWindowPos(0, HWND_TOP, 0, 0, 0, 0,
               SWP_SHOWWINDOW | SWP_NOSIZE | SWP_NOMOVE);
  SetForegroundWindow(hwnd);

  return true;
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  RegisterUrlProtocol();

  if (SendAppLinkToInstance(kWindowTitle)) {
    return EXIT_SUCCESS;
  }

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.CreateAndShow(kWindowTitle, origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
