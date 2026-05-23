#include "utils.h"

#include <flutter_windows.h>
#include <io.h>
#include <stdio.h>
#include <windows.h>

#include <iostream>

void CreateAndAttachConsole() {
  if (::AllocConsole()) {
    FILE *unused;
    if (freopen_s(&unused, "CONOUT$", "w", stdout)) {
      _dup2(_fileno(stdout), 1);
    }
    if (freopen_s(&unused, "CONOUT$", "w", stderr)) {
      _dup2(_fileno(stdout), 2);
    }
    std::ios::sync_with_stdio();
    FlutterDesktopResyncOutputStreams();
  }
}

std::vector<std::string> GetCommandLineArguments() {
  int argc;
  wchar_t** argv = ::CommandLineToArgvW(::GetCommandLineW(), &argc);
  if (argv == nullptr) {
    return std::vector<std::string>();
  }

  std::vector<std::string> command_line_arguments;

  for (int i = 1; i < argc; i++) {
    std::wstring wide_arg(argv[i]);
    int size_needed = WideCharToMultiByte(CP_UTF8, 0, wide_arg.c_str(), -1,
                                          nullptr, 0, nullptr, nullptr);
    std::string utf8_arg(size_needed - 1, '\0');
    WideCharToMultiByte(CP_UTF8, 0, wide_arg.c_str(), -1, utf8_arg.data(),
                        size_needed, nullptr, nullptr);
    command_line_arguments.push_back(utf8_arg);
  }

  ::LocalFree(argv);

  return command_line_arguments;
}
