#include "register_types.h"

#include <gdextension_interface.h>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>

#include "lua_manager.h"
#include <imgui.h>
#include "car_brain.hpp"

using namespace godot;

void initialize_aga_module(ModuleInitializationLevel p_level) {
    if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
        return;
    }

    ClassDB::register_class<LuaManager>();
    ClassDB::register_class<CarBrain>();
}

void uninitialize_aga_module(ModuleInitializationLevel p_level) {
    if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
        return;
    }
}

extern "C" {
GDE_EXPORT void imgui_godot_module_init(uint32_t version, ImGuiContext* ctx, ImGuiMemAllocFunc afunc, ImGuiMemFreeFunc ffunc) {
    ImGui::SetCurrentContext(ctx);
    ImGui::SetAllocatorFunctions(afunc, ffunc);
}

GDExtensionBool GDE_EXPORT aga_library_init(GDExtensionInterfaceGetProcAddress p_get_proc_address, const GDExtensionClassLibraryPtr p_library, GDExtensionInitialization *r_initialization) {
    godot::GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);

    init_obj.register_initializer(initialize_aga_module);
    init_obj.register_terminator(uninitialize_aga_module);
    init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);

    return init_obj.init();
}
}
