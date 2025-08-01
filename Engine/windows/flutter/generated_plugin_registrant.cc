//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <hotkey_system/hotkey_system_plugin.h>
#include <screen_retriever_windows/screen_retriever_windows_plugin_c_api.h>
#include <window_manager/window_manager_plugin.h>

void RegisterPlugins(flutter::PluginRegistry* registry) {
  HotkeySystemPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("HotkeySystemPlugin"));
  ScreenRetrieverWindowsPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("ScreenRetrieverWindowsPluginCApi"));
  WindowManagerPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("WindowManagerPlugin"));
}
