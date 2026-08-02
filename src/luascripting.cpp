#include "luascripting.h"
#include "imgui.h"
#include <iostream>
#include <chrono>
#include <algorithm>
#include <fstream>
#include <filesystem>
#include <cmath>
#include <godot_cpp/variant/utility_functions.hpp>

static std::mutex global_lua_mutex;

LuaScripting* LuaScripting::instance = nullptr;

LuaScripting::LuaScripting(AddBouncerFunc addFunc, DelBouncerFunc delFunc, SetBGFunc bgFunc, SelectFunc selectFunc, SetParamFunc setParamFunc, SetBouncerParamFunc setBouncerParamFunc, RandomizeFunc randomizeFunc, SetAudioFunc audioFunc, 
    PlayAudioFunc playAudioFunc, StopAudioFunc stopAudioFunc, RewindAudioFunc rewindAudioFunc, SkipAudioFunc skipAudioFunc, SetAudioVolumeFunc setAudioVolumeFunc,
    RecordFunc recordFunc, IsRecordingFunc isRecFunc,
#ifdef USE_USD
    SelectUSDFunc selectUSDFunc, SetUSDParamFunc setUSDParamFunc,
#endif
    SelectGodotFunc selectGodotFunc, GodotCmdFunc godotFunc, QuitFunc quitFunc, SetImGuiVisibleFunc setImGuiVisibleFunc, ClearAndRunFunc clearAndRunFunc, SetMouseCaptureFunc setMouseCaptureFunc, SetResizeEnabledFunc setResizeEnabledFunc, MaximizeWindowFunc maximizeWindowFunc, CheckHighScoreFunc checkHSFunc, AddHighScoreFunc addHSFunc, LoadHighScoreFunc loadHSFunc, SaveHighScoreFunc saveHSFunc)
    : addBouncerFunc(addFunc), delBouncerFunc(delFunc), setBGFunc(bgFunc), selectFunc(selectFunc), setParamFunc(setParamFunc), setBouncerParamFunc(setBouncerParamFunc), randomizeFunc(randomizeFunc), setAudioFunc(audioFunc), 
    playAudioFunc(playAudioFunc), stopAudioFunc(stopAudioFunc), rewindAudioFunc(rewindAudioFunc), skipAudioFunc(skipAudioFunc), setAudioVolumeFunc(setAudioVolumeFunc),
    recordFunc(recordFunc), isRecFunc(isRecFunc),
 
#ifdef USE_USD
    selectUSDFunc(selectUSDFunc), setUSDParamFunc(setUSDParamFunc), 
#endif
    selectGodotFunc(selectGodotFunc), godotCmdFunc(godotFunc), quitFunc(quitFunc), setImGuiVisibleFunc(setImGuiVisibleFunc), clearAndRunFunc(clearAndRunFunc), setMouseCaptureFunc(setMouseCaptureFunc), setResizeEnabledFunc(setResizeEnabledFunc), maximizeWindowFunc(maximizeWindowFunc), checkHighScoreFunc(checkHSFunc), addHighScoreFunc(addHSFunc), loadHighScoreFunc(loadHSFunc), saveHighScoreFunc(saveHSFunc) {
    instance = this;
    systemRunning = true;
}

LuaScripting::~LuaScripting() {
    stop();
    if (instance == this) instance = nullptr;
}

void LuaScripting::setGlobalInt(const std::string& name, int val) {
    std::lock_guard<std::mutex> lock(globals_mutex);
    global_ints[name] = val;
}

int LuaScripting::getGlobalInt(const std::string& name) {
    std::lock_guard<std::mutex> lock(globals_mutex);
    auto it = global_ints.find(name);
    if (it != global_ints.end()) return it->second;
    return 0;
}

void LuaScripting::regGlobalInt(const std::string& name, int val) {
    std::lock_guard<std::mutex> lock(globals_mutex);
    global_ints.insert({name, val});
}

void LuaScripting::unregGlobalInt(const std::string& name) {
    std::lock_guard<std::mutex> lock(globals_mutex);
    global_ints.erase(name);
}

void LuaScripting::setGlobalFloat(const std::string& name, float val) {
    std::lock_guard<std::mutex> lock(globals_mutex);
    global_floats[name] = val;
}

float LuaScripting::getGlobalFloat(const std::string& name) {
    std::lock_guard<std::mutex> lock(globals_mutex);
    auto it = global_floats.find(name);
    if (it != global_floats.end()) return it->second;
    return 0.0f;
}

void LuaScripting::regGlobalFloat(const std::string& name, float val) {
    std::lock_guard<std::mutex> lock(globals_mutex);
    global_floats.insert({name, val});
}

void LuaScripting::unregGlobalFloat(const std::string& name) {
    std::lock_guard<std::mutex> lock(globals_mutex);
    global_floats.erase(name);
}

bool LuaScripting::runScript(const std::string& filename) {
    if (primaryRunning) {
        godot::UtilityFunctions::printerr("LuaScripting: Script already running");
        return false;
    }
    if (scriptThread.joinable()) {
        scriptThread.join();
    }
    systemRunning = true;
    primaryRunning = true;
    scriptThread = std::thread(&LuaScripting::scriptThreadFunc, this, filename);
    return true;
}

void LuaScripting::stop() {
    systemRunning = false;
    if (scriptThread.joinable()) {
        scriptThread.join();
    }
    
    std::lock_guard<std::mutex> lock(threadsMutex);
    for (auto& t : detachedThreads) {
        if (t.joinable()) t.join();
    }
    detachedThreads.clear();
    primaryRunning = false;

    {
        std::lock_guard<std::mutex> lock(imgui_mutex);
        lua_imgui_windows.clear();
        active_window_title = "";
    }
}

void LuaScripting::scriptThreadFunc(std::string filename) {
    L = luaL_newstate();
    luaL_openlibs(L);

    // Store 'this' in registry for the hook
    lua_pushlightuserdata(L, this);
    lua_setfield(L, LUA_REGISTRYINDEX, "LuaScriptingInstance");

    registerFunctions(L);

    // Set a hook to abort execution if stop() is called
    lua_sethook(L, lua_hook, LUA_MASKCOUNT, 100);

    if (luaL_dofile(L, filename.c_str()) != LUA_OK) {
        std::string err = lua_tostring(L, -1);
        if (err != "Script terminated" && err != "Script aborted") {
            godot::UtilityFunctions::printerr("Lua Error: ", err.c_str());
        }
    }

    lua_close(L);
    L = nullptr;
    primaryRunning = false;
}

void LuaScripting::runOneShotScript(const std::string& filename) {
    pruneThreads();
    std::lock_guard<std::mutex> lock(threadsMutex);
    detachedThreads.emplace_back([this, filename]() {
        lua_State* L_one = luaL_newstate();
        luaL_openlibs(L_one);

        // Store 'this' in registry for the hook
        lua_pushlightuserdata(L_one, this);
        lua_setfield(L_one, LUA_REGISTRYINDEX, "LuaScriptingInstance");

        registerFunctions(L_one);
        lua_sethook(L_one, lua_hook, LUA_MASKCOUNT, 100);
        if (luaL_dofile(L_one, filename.c_str()) != LUA_OK) {
            std::string err = lua_tostring(L_one, -1);
            if (err != "Script terminated" && err != "Script aborted") {
                godot::UtilityFunctions::printerr("Lua One-Shot Error: ", err.c_str());
            }
        }
        lua_close(L_one);
    });
}

void LuaScripting::pruneThreads() {
    std::lock_guard<std::mutex> lock(threadsMutex);
}

void LuaScripting::triggerCallback(const std::string& name) {
    std::lock_guard<std::mutex> lock(callbackMutex);
    pendingCallbacks.push(name);
}

void LuaScripting::registerFunctions(lua_State* L_reg) {
    auto reg = [L_reg, this](const char* name, lua_CFunction func) {
        lua_pushlightuserdata(L_reg, this);
        lua_pushcclosure(L_reg, func, 1);
        lua_setglobal(L_reg, name);
    };

    reg("addBouncer", lua_addBouncer);
    reg("delBouncer", lua_delBouncer);
    reg("setParam", lua_setParam);
    reg("setBG", lua_setBG);
    reg("godotLoadScene", lua_godotLoadScene);
    reg("godotInputGetAxis", lua_godotInputGetAxis);
    reg("godotInputIsActionPressed", lua_godotInputIsActionPressed);
    reg("selectPlasma", lua_selectPlasma);
    reg("selectFractal", lua_selectFractal);
#ifdef USE_USD
    reg("selectUSD", lua_selectUSD);
#endif
    reg("selectGodot", lua_selectGodot);
    reg("setPlasmaParam", lua_setPlasmaParam);
    reg("setFractalParam", lua_setFractalParam);
#ifdef USE_USD
    reg("setUSDParam", lua_setUSDParam);
#endif
    reg("randomizePlasmaPalette", lua_randomizePlasmaPalette);
    reg("randomizePlasmaXY", lua_randomizePlasmaXY);
    reg("randomizeFractalPalette", lua_randomizeFractalPalette);
    reg("setAudio", lua_setAudio);
    reg("playAudio", lua_playAudio);
    reg("stopAudio", lua_stopAudio);
    reg("rewindAudio", lua_rewindAudio);
    reg("skipAudio", lua_skipAudio);
    reg("setAudioVolume", lua_setAudioVolume);
    reg("startRecord", lua_startRecord);
    reg("stopRecord", lua_stopRecord);
    reg("setRecordMax", lua_setRecordMax);
    reg("delay", lua_delay);
    reg("delayKb", lua_delayKb);
    reg("appQuit", lua_appQuit);
    reg("luaClearAndRun", lua_luaClearAndRun);
    reg("imGuiHide", lua_imGuiHide);
    reg("imGuiShow", lua_imGuiShow);
    reg("ioResizeEnabled", lua_ioResizeEnabled);
    reg("ioMaximizeWindow", lua_ioMaximizeWindow);
    reg("ioMouseCapture", lua_ioMouseCapture);
    reg("ioMouseRelease", lua_ioMouseRelease);

    reg("luaCreateMutex", lua_luaCreateMutex);
    reg("luaGetMutex", lua_luaGetMutex);
    reg("luaTryMutex", lua_luaTryMutex);
    reg("luaCheckMutex", lua_luaCheckMutex);
    reg("luaReleaseMutex", lua_luaReleaseMutex);

    // Input Framework
    reg("ioKBClicked", lua_ioKBClicked);
    reg("ioKBDown", lua_ioKBDown);
    reg("ioKBUp", lua_ioKBUp);
    reg("ioMousePos", lua_ioMousePos);
    reg("ioMouseMoved", lua_ioMouseMoved);
    reg("ioMouseGetMotion", lua_ioMouseGetMotion);
    reg("ioMouseWheelMotion", lua_ioMouseWheelMotion);
    reg("ioMouseBTNClicked", lua_ioMouseBTNClicked);
    reg("ioMouseBTNDown", lua_ioMouseBTNDown);
    reg("ioMouseBTNUp", lua_ioMouseBTNUp);

    reg("ioJoystickOpen", lua_ioJoystickOpen);
    reg("ioJoystickClose", lua_ioJoystickClose);
    reg("ioJoystickGetAxis", lua_ioJoystickGetAxis);
    reg("ioJoystickGetButtonDown", lua_ioJoystickGetButtonDown);
    reg("ioJoystickGetButtonHit", lua_ioJoystickGetButtonHit);
    reg("ioJoystickGetButtonUp", lua_ioJoystickGetButtonUp);
    reg("ioJoystickGetHat", lua_ioJoystickGetHat);
    reg("ioJoystickGetNumAxes", lua_ioJoystickGetNumAxes);
    reg("ioJoystickGetNumButtons", lua_ioJoystickGetNumButtons);
    reg("ioJoystickGetNumHats", lua_ioJoystickGetNumHats);

    // Godot Manipulation
    reg("godotGetNodePointer", lua_godotGetNodePointer);
    reg("godotSelectRoot", lua_godotSelectRoot);
    reg("godotSelectNode", lua_godotSelectNode);
    reg("godotSearchNode", lua_godotSearchNode);
    reg("godotGetNodeType", lua_godotGetNodeType);
    reg("godotGetName", lua_godotGetName);
    reg("godotGetChildCount", lua_godotGetChildCount);
    reg("godotPrintHierarchy", lua_godotPrintHierarchy);
    reg("godotRenameNode", lua_godotRenameNode);
    reg("godotSetCamera", lua_godotSetCamera);
    reg("godotGetPos", lua_godotGetPos);
    reg("godotSetPos", lua_godotSetPos);
    reg("godotSetVisible", lua_godotSetVisible);
    reg("godotGetScale", lua_godotGetScale);
    reg("godotSetScale", lua_godotSetScale);
    reg("godotMoveX", lua_godotMoveX);
    reg("godotMoveY", lua_godotMoveY);
    reg("godotMoveZ", lua_godotMoveZ);
    reg("godotMoveAndCollide", lua_godotMoveAndCollide);
    reg("godotGetOverlappingAreas", lua_godotGetOverlappingAreas);
    reg("godotCreateNode", lua_godotCreateNode);
    reg("godotLoadNode", lua_godotLoadNode);
    reg("godotDeleteNode", lua_godotDeleteNode);
    reg("godotAttachScript", lua_godotAttachScript);
    reg("godotSetProperty", lua_godotSetProperty);
    reg("godotRegisterImpulseProperty", lua_godotRegisterImpulseProperty);
    reg("godotGetProperty", lua_godotGetProperty);
    reg("godotWatchProperty", lua_godotWatchProperty);
    reg("godotWatchSignal", lua_godotWatchSignal);
    reg("godotIsHighScore", lua_godotIsHighScore);
    reg("godotAddHighScore", lua_godotAddHighScore);
    reg("godotLoadHighScore", lua_godotLoadHighScore);
    reg("godotSaveHighScore", lua_godotSaveHighScore);
    reg("godotLoadCarSettings", lua_godotLoadCarSettings);
    reg("godotSaveCarSettings", lua_godotSaveCarSettings);

    // ImGui bindings
    reg("imguiBegin", lua_imguiBegin);
    reg("imguiEnd", lua_imguiEnd);
    reg("imguiRemoveWindow", lua_imguiRemoveWindow);
    reg("imguiText", lua_imguiText);
    reg("imguiSeparator", lua_imguiSeparator);
    reg("imguiCheckbox", lua_imguiCheckbox);
    reg("imguiSliderFloat", lua_imguiSliderFloat);
    reg("imguiButton", lua_imguiButton);
    reg("imguiProgressBar", lua_imguiProgressBar);
    reg("imguiSameLine", lua_imguiSameLine);

    reg("regGlobalVar", lua_regGlobalVar);
    reg("unregGlobalVar", lua_unregGlobalVar);
    reg("setGlobalVar", lua_setGlobalVar);
    reg("getGlobalVar", lua_getGlobalVar);
    reg("regGlobalFloat", lua_regGlobalFloat);
    reg("unregGlobalFloat", lua_unregGlobalFloat);
    reg("setGlobalFloat", lua_setGlobalFloat);
    reg("getGlobalFloat", lua_getGlobalFloat);
}

void LuaScripting::lua_hook(lua_State* L, lua_Debug* ar) {
    lua_getfield(L, LUA_REGISTRYINDEX, "LuaScriptingInstance");
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, -1);
    lua_pop(L, 1);

    if (self && !self->systemRunning) {
        luaL_error(L, "Script aborted");
    }

    // Process pending callbacks
    if (self) {
        std::string callback;
        {
            std::lock_guard<std::mutex> lock(self->callbackMutex);
            if (!self->pendingCallbacks.empty()) {
                callback = self->pendingCallbacks.front();
                self->pendingCallbacks.pop();
            }
        }
        
        if (!callback.empty()) {
            lua_getglobal(L, callback.c_str());
            if (lua_isfunction(L, -1)) {
                if (lua_pcall(L, 0, 0, 0) != LUA_OK) {
                    std::printf("Error in Lua callback '%s': %s\n", callback.c_str(), lua_tostring(L, -1));
                }
            } else {
                lua_pop(L, 1);
            }
        }
    }
}

int LuaScripting::lua_godotWatchSignal(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (lua_isstring(L, 1) && lua_isstring(L, 2) && self && self->godotCmdFunc) {
        std::string signal = lua_tostring(L, 1);
        std::string file = lua_tostring(L, 2);

        std::string combined = signal + "|" + file;
        auto sd = std::make_shared<LuaSyncData>();
        float fargs[3] = {0,0,0};

        if (lua_isinteger(L, 3)) {
            sd->object_id_arg = (uint64_t)lua_tointeger(L, 3);
        }

        self->godotCmdFunc(GCMD_WATCH_SIGNAL, combined, fargs, sd, L, self);
        std::unique_lock<std::mutex> lock(sd->mtx);
        while (!sd->done && self && self->systemRunning) {
            sd->cv.wait_for(lock, std::chrono::milliseconds(10));
        }
        lua_pushboolean(L, sd->b_res);
        return 1;
    }
    return 0;
}
int LuaScripting::lua_godotIsHighScore(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (lua_isnumber(L, 1) && self && self->checkHighScoreFunc) {
        bool res = self->checkHighScoreFunc((int)lua_tonumber(L, 1));
        lua_pushboolean(L, res);
        return 1;
    }
    return 0;
}

int LuaScripting::lua_godotAddHighScore(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (lua_isstring(L, 1) && lua_isnumber(L, 2) && lua_isnumber(L, 3) && self && self->addHighScoreFunc) {
        self->addHighScoreFunc(lua_tostring(L, 1), (int)lua_tonumber(L, 2), (int)lua_tonumber(L, 3));
    }
    return 0;
}

int LuaScripting::lua_godotLoadHighScore(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (self && self->loadHighScoreFunc) {
        self->loadHighScoreFunc();
    }
    return 0;
}

int LuaScripting::lua_godotSaveHighScore(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (self && self->saveHighScoreFunc) {
        self->saveHighScoreFunc();
    }
    return 0;
}

void LuaScripting::loadCarSettings() {
    const char* home = std::getenv("HOME");
    std::string filename = home ? std::string(home) + "/.age/car.ini" : "car.ini";
    std::ifstream f(filename);
    if (f.is_open()) {
        std::string line;
        while (std::getline(f, line)) {
            size_t sep = line.find('=');
            if (sep != std::string::npos) {
                std::string key = line.substr(0, sep);
                std::string val_str = line.substr(sep + 1);
                try {
                    float val = std::stof(val_str);
                    setGlobalFloat(key, val);
                } catch (...) {}
            }
        }
    }
}

void LuaScripting::saveCarSettings() {
    const char* home = std::getenv("HOME");
    std::string dir = home ? std::string(home) + "/.age" : ".age";
    std::error_code ec;
    std::filesystem::create_directories(dir, ec);
    std::string filename = dir + "/car.ini";
    std::ofstream f(filename);
    if (f.is_open()) {
        std::vector<std::string> keys = {
            "engine_force_value", "brake_force_value", "max_steer", "wheel_friction_slip",
            "suspension_travel", "suspension_stiffness", "suspension_max_force",
            "damping_compression", "damping_relaxation", "downforce_multiplier",
            "car_mass", "center_of_mass_y", "center_of_mass_z", "max_speed", "over_extend", "z_traction",
            "radius_front", "radius_rear", "use_shapecast", "drivetrain_mode", "tire_turn_speed",
            "esp_max_yaw_damping", "aero_drag_coeff", "steer_speed_limit_max_speed", "steer_speed_limit_min_mult"
        };
        for (const auto& key : keys) {
            f << key << "=" << getGlobalFloat(key) << "\n";
        }
    }
}

int LuaScripting::lua_godotLoadCarSettings(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (self) {
        self->loadCarSettings();
    }
    return 0;
}

int LuaScripting::lua_godotSaveCarSettings(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (self) {
        self->saveCarSettings();
    }
    return 0;
}

int LuaScripting::lua_regGlobalVar(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (lua_isstring(L, 1) && lua_isnumber(L, 2) && self) {
        self->regGlobalInt(lua_tostring(L, 1), (int)lua_tonumber(L, 2));
    }
    return 0;
}

int LuaScripting::lua_unregGlobalVar(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (lua_isstring(L, 1) && self) {
        self->unregGlobalInt(lua_tostring(L, 1));
    }
    return 0;
}

int LuaScripting::lua_setGlobalVar(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (lua_isstring(L, 1) && lua_isnumber(L, 2) && self) {
        self->setGlobalInt(lua_tostring(L, 1), (int)lua_tonumber(L, 2));
    }
    return 0;
}

int LuaScripting::lua_getGlobalVar(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (lua_isstring(L, 1) && self) {
        int val = self->getGlobalInt(lua_tostring(L, 1));
        lua_pushinteger(L, val);
        return 1;
    }
    return 0;
}

int LuaScripting::lua_regGlobalFloat(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (lua_isstring(L, 1) && lua_isnumber(L, 2) && self) {
        self->regGlobalFloat(lua_tostring(L, 1), (float)lua_tonumber(L, 2));
    }
    return 0;
}

int LuaScripting::lua_unregGlobalFloat(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (lua_isstring(L, 1) && self) {
        self->unregGlobalFloat(lua_tostring(L, 1));
    }
    return 0;
}

int LuaScripting::lua_setGlobalFloat(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (lua_isstring(L, 1) && lua_isnumber(L, 2) && self) {
        self->setGlobalFloat(lua_tostring(L, 1), (float)lua_tonumber(L, 2));
    }
    return 0;
}

int LuaScripting::lua_getGlobalFloat(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (lua_isstring(L, 1) && self) {
        float val = self->getGlobalFloat(lua_tostring(L, 1));
        lua_pushnumber(L, val);
        return 1;
    }
    return 0;
}

int LuaScripting::lua_addBouncer(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (lua_isstring(L, 1)) {
        std::string syntax = lua_tostring(L, 1);
        if (self && self->addBouncerFunc) {
            self->addBouncerFunc(syntax);
        }
    }
    return 0;
}

int LuaScripting::lua_delBouncer(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (lua_isinteger(L, 1)) {
        int index = (int)lua_tointeger(L, 1);
        if (self && self->delBouncerFunc) {
            self->delBouncerFunc(index);
        }
    }
    return 0;
}

int LuaScripting::lua_setParam(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (lua_isinteger(L, 1) && lua_isstring(L, 2) && lua_isnumber(L, 3)) {
        int index = (int)lua_tointeger(L, 1);
        std::string name = lua_tostring(L, 2);
        double val = lua_tonumber(L, 3);
        if (self && self->setBouncerParamFunc) {
            self->setBouncerParamFunc(index, name, val);
        }
    }
    return 0;
}

int LuaScripting::lua_setBG(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (lua_isstring(L, 1)) {
        std::string bg = lua_tostring(L, 1);
        if (self && self->setBGFunc) {
            self->setBGFunc(bg);
        }
    }
    return 0;
}

int LuaScripting::lua_selectPlasma(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (lua_isinteger(L, 1)) {
        int index = (int)lua_tointeger(L, 1);
        if (self && self->selectFunc) {
            auto sd = std::make_shared<LuaSyncData>();
            self->selectFunc(true, index, sd);
            std::unique_lock<std::mutex> lock(sd->mtx);
            while (!sd->done && self && self->systemRunning) {
                sd->cv.wait_for(lock, std::chrono::milliseconds(10));
            }
        }
    }
    return 0;
}

int LuaScripting::lua_selectFractal(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (lua_isinteger(L, 1)) {
        int index = (int)lua_tointeger(L, 1);
        if (self && self->selectFunc) {
            auto sd = std::make_shared<LuaSyncData>();
            self->selectFunc(false, index, sd);
            std::unique_lock<std::mutex> lock(sd->mtx);
            while (!sd->done && self && self->systemRunning) {
                sd->cv.wait_for(lock, std::chrono::milliseconds(10));
            }
        }
    }
    return 0;
}

#ifdef USE_USD
int LuaScripting::lua_selectUSD(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (lua_isinteger(L, 1)) {
        int index = (int)lua_tointeger(L, 1);
        if (self && self->selectUSDFunc) {
            auto sd = std::make_shared<LuaSyncData>();
            self->selectUSDFunc(index, sd);
            std::unique_lock<std::mutex> lock(sd->mtx);
            while (!sd->done && self && self->systemRunning) {
                sd->cv.wait_for(lock, std::chrono::milliseconds(10));
            }
        }
    }
    return 0;
}
#endif

int LuaScripting::lua_selectGodot(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (lua_isinteger(L, 1)) {
        int index = (int)lua_tointeger(L, 1);
        if (self && self->selectGodotFunc) {
            auto sd = std::make_shared<LuaSyncData>();
            self->selectGodotFunc(index, sd, L, self);
            std::unique_lock<std::mutex> lock(sd->mtx);
            while (!sd->done && self && self->systemRunning) {
                sd->cv.wait_for(lock, std::chrono::milliseconds(10));
            }
        }
    }
    return 0;
}

int LuaScripting::lua_godotLoadScene(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (lua_isstring(L, 1)) {
        std::string filename = lua_tostring(L, 1);
        if (self && self->godotCmdFunc) {
            auto sd = std::make_shared<LuaSyncData>();
            float fargs[3] = {0,0,0};
            self->godotCmdFunc(GCMD_LOAD_SCENE, filename, fargs, sd, nullptr, self);
            
            // Wait for Godot main thread to finish loading scene
            std::unique_lock<std::mutex> lock(sd->mtx);
            while (!sd->done && self && self->systemRunning) {
                sd->cv.wait_for(lock, std::chrono::milliseconds(10));
            }
        }
    }
    return 0;
}

int LuaScripting::lua_setPlasmaParam(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (lua_isstring(L, 1) && lua_isnumber(L, 2)) {
        std::string name = lua_tostring(L, 1);
        double val = lua_tonumber(L, 2);
        if (self && self->setParamFunc) {
            self->setParamFunc(true, name, val);
        }
    }
    return 0;
}

int LuaScripting::lua_setFractalParam(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (lua_isstring(L, 1) && lua_isnumber(L, 2)) {
        std::string name = lua_tostring(L, 1);
        double val = lua_tonumber(L, 2);
        if (self && self->setParamFunc) {
            self->setParamFunc(false, name, val);
        }
    }
    return 0;
}

#ifdef USE_USD
int LuaScripting::lua_setUSDParam(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (lua_isstring(L, 1) && lua_isnumber(L, 2)) {
        std::string name = lua_tostring(L, 1);
        double val = lua_tonumber(L, 2);
        if (self && self->setUSDParamFunc) {
            self->setUSDParamFunc(name, val);
        }
    }
    return 0;
}
#endif

int LuaScripting::lua_randomizePlasmaPalette(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (self && self->randomizeFunc) self->randomizeFunc(true, false);
    return 0;
}

int LuaScripting::lua_randomizePlasmaXY(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (self && self->randomizeFunc) self->randomizeFunc(true, true);
    return 0;
}

int LuaScripting::lua_randomizeFractalPalette(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (self && self->randomizeFunc) self->randomizeFunc(false, false);
    return 0;
}

int LuaScripting::lua_setAudio(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (lua_isstring(L, 1)) {
        std::string path = lua_tostring(L, 1);
        if (self && self->setAudioFunc) {
            auto sync_data = std::make_shared<LuaSyncData>();
            self->setAudioFunc(path, sync_data);
            std::unique_lock<std::mutex> lock(sync_data->mtx);
            sync_data->cv.wait(lock, [sync_data, self]{ 
                return sync_data->done || !self->systemRunning; 
            });
            lua_pushboolean(L, sync_data->b_res);
            return 1;
        }
    }
    lua_pushboolean(L, false);
    return 1;
}

int LuaScripting::lua_playAudio(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (self && self->playAudioFunc) self->playAudioFunc();
    return 0;
}

int LuaScripting::lua_stopAudio(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (self && self->stopAudioFunc) self->stopAudioFunc();
    return 0;
}

int LuaScripting::lua_rewindAudio(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (self && self->rewindAudioFunc) self->rewindAudioFunc();
    return 0;
}

int LuaScripting::lua_skipAudio(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (lua_isnumber(L, 1)) {
        int seconds = (int)lua_tonumber(L, 1);
        if (self && self->skipAudioFunc) self->skipAudioFunc(seconds);
    }
    return 0;
}

int LuaScripting::lua_setAudioVolume(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (lua_isnumber(L, 1)) {
        int vol = (int)lua_tonumber(L, 1);
        if (self && self->setAudioVolumeFunc) self->setAudioVolumeFunc(vol);
    }
    return 0;
}

int LuaScripting::lua_startRecord(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (lua_isstring(L, 1)) {
        std::string path = lua_tostring(L, 1);
        if (self && self->recordFunc) self->recordFunc(0, path, 0);
    }
    return 0;
}

int LuaScripting::lua_stopRecord(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    int wait = 0;
    if (lua_isinteger(L, 1)) wait = (int)lua_tointeger(L, 1);
    if (self && self->recordFunc) self->recordFunc(1, "", wait);
    return 0;
}

int LuaScripting::lua_setRecordMax(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (lua_isinteger(L, 1)) {
        int max = (int)lua_tointeger(L, 1);
        if (self && self->recordFunc) self->recordFunc(2, "", max);
    }
    return 0;
}

int LuaScripting::lua_delay(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (lua_isinteger(L, 1)) {
        int ms = (int)lua_tointeger(L, 1);
        int remaining = ms;
        while (remaining > 0 && self && self->systemRunning) {
            // Process callbacks while waiting
            lua_Debug ar;
            lua_hook(L, &ar);

            int chunk = std::min(remaining, 16);
            std::this_thread::sleep_for(std::chrono::milliseconds(chunk));
            remaining -= chunk;
        }
    }
    return 0;
}

int LuaScripting::lua_delayKb(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (lua_isinteger(L, 1)) {
        int ms = (int)lua_tointeger(L, 1);
        int remaining = ms;
        while (remaining > 0 && self && self->systemRunning) {
            // Process callbacks while waiting
            lua_Debug ar;
            lua_hook(L, &ar);

            // if (!InputManager::getInstance().isTextInputActive()) {
            //     if (InputManager::getInstance().lua_hasAnyKeyHit()) {
            //         break;
            //     }
            // }

            int chunk = std::min(remaining, 16);
            std::this_thread::sleep_for(std::chrono::milliseconds(chunk));
            remaining -= chunk;
        }
    }
    return 0;
}

int LuaScripting::lua_appQuit(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (self && self->quitFunc) {
        self->quitFunc(nullptr); // Non-blocking
    }
    return 0;
}

int LuaScripting::lua_luaCreateMutex(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (self) {
        std::lock_guard<std::mutex> lock(self->globals_mutex);
        int handle = self->next_mutex_id++;
        self->dynamic_mutexes[handle] = std::make_unique<std::recursive_mutex>();
        lua_pushinteger(L, handle);
        return 1;
    }
    return 0;
}

int LuaScripting::lua_luaGetMutex(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (lua_isnumber(L, 1) && self) {
        int handle = (int)lua_tonumber(L, 1);
        std::recursive_mutex* target_mutex = nullptr;
        {
            std::lock_guard<std::mutex> lock(self->globals_mutex);
            auto it = self->dynamic_mutexes.find(handle);
            if (it != self->dynamic_mutexes.end()) {
                target_mutex = it->second.get();
            }
        }
        if (target_mutex) {
            target_mutex->lock();
            return 0; // successfully locked
        }
    }
    return 0;
}

int LuaScripting::lua_luaTryMutex(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (lua_isnumber(L, 1) && self) {
        int handle = (int)lua_tonumber(L, 1);
        std::recursive_mutex* target_mutex = nullptr;
        {
            std::lock_guard<std::mutex> lock(self->globals_mutex);
            auto it = self->dynamic_mutexes.find(handle);
            if (it != self->dynamic_mutexes.end()) {
                target_mutex = it->second.get();
            }
        }
        if (target_mutex) {
            bool locked_successfully = target_mutex->try_lock();
            lua_pushboolean(L, locked_successfully);
            return 1;
        }
    }
    lua_pushboolean(L, false); // invalid mutex fails to lock
    return 1;
}

int LuaScripting::lua_luaCheckMutex(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (lua_isnumber(L, 1) && self) {
        int handle = (int)lua_tonumber(L, 1);
        std::recursive_mutex* target_mutex = nullptr;
        {
            std::lock_guard<std::mutex> lock(self->globals_mutex);
            auto it = self->dynamic_mutexes.find(handle);
            if (it != self->dynamic_mutexes.end()) {
                target_mutex = it->second.get();
            }
        }
        if (target_mutex) {
            bool locked = !target_mutex->try_lock();
            if (!locked) {
                target_mutex->unlock(); // wasn't locked, so unlock it
            }
            lua_pushboolean(L, locked);
            return 1;
        }
    }
    lua_pushboolean(L, false); // invalid mutex is not locked
    return 1;
}

int LuaScripting::lua_luaReleaseMutex(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (lua_isnumber(L, 1) && self) {
        int handle = (int)lua_tonumber(L, 1);
        std::recursive_mutex* target_mutex = nullptr;
        {
            std::lock_guard<std::mutex> lock(self->globals_mutex);
            auto it = self->dynamic_mutexes.find(handle);
            if (it != self->dynamic_mutexes.end()) {
                target_mutex = it->second.get();
            }
        }
        if (target_mutex) {
            target_mutex->unlock();
        }
    }
    return 0;
}

int LuaScripting::lua_luaClearAndRun(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (lua_isstring(L, 1) && self && self->clearAndRunFunc) {
        {
            std::lock_guard<std::mutex> lock(self->globals_mutex);
            self->dynamic_mutexes.clear();
        }
        self->clearAndRunFunc(lua_tostring(L, 1), nullptr); // Non-blocking
    }
    return 0;
}

int LuaScripting::lua_imGuiHide(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (self && self->setImGuiVisibleFunc) {
        self->setImGuiVisibleFunc(false);
    }
    return 0;
}

int LuaScripting::lua_imGuiShow(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (self && self->setImGuiVisibleFunc) {
        self->setImGuiVisibleFunc(true);
    }
    return 0;
}

int LuaScripting::lua_ioResizeEnabled(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (lua_isboolean(L, 1)) {
        bool enabled = lua_toboolean(L, 1);
        if (self && self->setResizeEnabledFunc) {
            self->setResizeEnabledFunc(enabled);
        }
    }
    return 0;
}

int LuaScripting::lua_ioMaximizeWindow(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (self && self->maximizeWindowFunc) {
        self->maximizeWindowFunc();
    }
    return 0;
}

int LuaScripting::lua_ioMouseCapture(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (self && self->setMouseCaptureFunc) {
        self->setMouseCaptureFunc(true);
    }
    return 0;
}

int LuaScripting::lua_ioMouseRelease(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (self && self->setMouseCaptureFunc) {
        self->setMouseCaptureFunc(false);
    }
    return 0;
}

#include <godot_cpp/classes/input.hpp>
#include <godot_cpp/classes/global_constants.hpp>

void LuaScripting::setMouseMotion(float dx, float dy) {
    std::lock_guard<std::mutex> lock(mouse_mutex);
    mouse_dx += dx;
    mouse_dy += dy;
}

static godot::Key string_to_key(const std::string& str) {
    if (str == "w" || str == "W" || str == "SDLK_w") return godot::KEY_W;
    if (str == "a" || str == "A" || str == "SDLK_a") return godot::KEY_A;
    if (str == "s" || str == "S" || str == "SDLK_s") return godot::KEY_S;
    if (str == "d" || str == "D" || str == "SDLK_d") return godot::KEY_D;
    if (str == "q" || str == "Q" || str == "SDLK_q") return godot::KEY_Q;
    if (str == "e" || str == "E" || str == "SDLK_e") return godot::KEY_E;
    if (str == "n" || str == "N" || str == "SDLK_n") return godot::KEY_N;
    if (str == "c" || str == "C" || str == "SDLK_c") return godot::KEY_C;
    if (str == "Up" || str == "SDLK_UP") return godot::KEY_UP;
    if (str == "Down" || str == "SDLK_DOWN") return godot::KEY_DOWN;
    if (str == "Left" || str == "SDLK_LEFT") return godot::KEY_LEFT;
    if (str == "Right" || str == "SDLK_RIGHT") return godot::KEY_RIGHT;
    if (str == "Space" || str == "SDLK_SPACE") return godot::KEY_SPACE;
    if (str == "Escape" || str == "SDLK_ESCAPE") return godot::KEY_ESCAPE;
    if (str == "F1" || str == "SDLK_F1") return godot::KEY_F1;
    return godot::KEY_NONE;
}

int LuaScripting::lua_ioKBClicked(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (!self || !lua_isstring(L, 1)) {
        lua_pushboolean(L, false);
        return 1;
    }
    
    std::string key_str = lua_tostring(L, 1);
    godot::Key key = string_to_key(key_str);
    
    bool is_pressed = false;
    if (key != godot::KEY_NONE) {
        is_pressed = godot::Input::get_singleton()->is_physical_key_pressed(key);
    }
    
    bool was_pressed = self->kb_click_state[key_str];
    self->kb_click_state[key_str] = is_pressed;
    
    lua_pushboolean(L, is_pressed && !was_pressed);
    return 1;
}

int LuaScripting::lua_ioKBDown(lua_State* L) {
    if (!lua_isstring(L, 1)) {
        lua_pushboolean(L, false);
        return 1;
    }
    
    std::string key_str = lua_tostring(L, 1);
    godot::Key key = string_to_key(key_str);
    
    bool is_pressed = false;
    if (key != godot::KEY_NONE) {
        is_pressed = godot::Input::get_singleton()->is_key_pressed(key);
    }
    
    lua_pushboolean(L, is_pressed);
    return 1;
}

int LuaScripting::lua_ioKBUp(lua_State* L) {
    lua_pushboolean(L, false);
    return 1;
}

int LuaScripting::lua_ioMousePos(lua_State* L) {
    lua_pushinteger(L, 0);
    lua_pushinteger(L, 0);
    return 2;
}

int LuaScripting::lua_ioMouseMoved(lua_State* L) {
    lua_pushboolean(L, false);
    return 1;
}

int LuaScripting::lua_ioMouseGetMotion(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (self) {
        std::lock_guard<std::mutex> lock(self->mouse_mutex);
        lua_pushnumber(L, self->mouse_dx);
        lua_pushnumber(L, self->mouse_dy);
        self->mouse_dx = 0.0f;
        self->mouse_dy = 0.0f;
        return 2;
    }
    lua_pushnumber(L, 0.0f);
    lua_pushnumber(L, 0.0f);
    return 2;
}

int LuaScripting::lua_ioMouseWheelMotion(lua_State* L) {
    lua_pushinteger(L, 0);
    return 1;
}

int LuaScripting::lua_ioMouseBTNClicked(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (!self || !lua_isnumber(L, 1)) {
        lua_pushboolean(L, false);
        return 1;
    }
    int btn = (int)lua_tonumber(L, 1);
    bool is_pressed = godot::Input::get_singleton()->is_mouse_button_pressed((godot::MouseButton)btn);
    bool was_pressed = self->mouse_click_state[btn];
    self->mouse_click_state[btn] = is_pressed;
    lua_pushboolean(L, is_pressed && !was_pressed);
    return 1;
}

int LuaScripting::lua_ioMouseBTNDown(lua_State* L) {
    if (!lua_isnumber(L, 1)) {
        lua_pushboolean(L, false);
        return 1;
    }
    int btn = (int)lua_tonumber(L, 1);
    bool is_pressed = godot::Input::get_singleton()->is_mouse_button_pressed((godot::MouseButton)btn);
    lua_pushboolean(L, is_pressed);
    return 1;
}

int LuaScripting::lua_ioMouseBTNUp(lua_State* L) {
    if (!lua_isnumber(L, 1)) {
        lua_pushboolean(L, false);
        return 1;
    }
    int btn = (int)lua_tonumber(L, 1);
    bool is_pressed = godot::Input::get_singleton()->is_mouse_button_pressed((godot::MouseButton)btn);
    lua_pushboolean(L, !is_pressed);
    return 1;
}

int LuaScripting::lua_ioJoystickOpen(lua_State* L) {
    if (!lua_isnumber(L, 1)) {
        lua_pushinteger(L, -1);
        return 1;
    }
    int device = (int)lua_tonumber(L, 1);
    godot::TypedArray<int> joypads = godot::Input::get_singleton()->get_connected_joypads();
    if (joypads.has(device)) {
        lua_pushinteger(L, device);
        return 1;
    }
    lua_pushinteger(L, -1);
    return 1;
}

int LuaScripting::lua_ioJoystickClose(lua_State* L) {
    return 0;
}

int LuaScripting::lua_ioJoystickGetAxis(lua_State* L) {
    if (!lua_isnumber(L, 1) || !lua_isnumber(L, 2)) {
        lua_pushnumber(L, 0.0);
        return 1;
    }
    int device = (int)lua_tonumber(L, 1);
    int axis = (int)lua_tonumber(L, 2);
    
    // SDL and Godot axis enums match mostly 1:1 for main axes
    float val = godot::Input::get_singleton()->get_joy_axis(device, (godot::JoyAxis)axis);
    
    // Legacy scaling: SDL uses -32768 to 32767, Godot uses -1.0 to 1.0
    // But car_common.lua expects -1.0 to 1.0! 
    lua_pushnumber(L, val);
    return 1;
}

int LuaScripting::lua_ioJoystickGetButtonDown(lua_State* L) {
    if (!lua_isnumber(L, 1) || !lua_isnumber(L, 2)) {
        lua_pushboolean(L, false);
        return 1;
    }
    int device = (int)lua_tonumber(L, 1);
    int button = (int)lua_tonumber(L, 2);
    
    bool pressed = godot::Input::get_singleton()->is_joy_button_pressed(device, (godot::JoyButton)button);
    lua_pushboolean(L, pressed);
    return 1;
}

int LuaScripting::lua_ioJoystickGetButtonHit(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (!self || !lua_isnumber(L, 1) || !lua_isnumber(L, 2)) {
        lua_pushboolean(L, false);
        return 1;
    }
    int device = (int)lua_tonumber(L, 1);
    int button = (int)lua_tonumber(L, 2);
    
    bool is_pressed = godot::Input::get_singleton()->is_joy_button_pressed(device, (godot::JoyButton)button);
    
    int key = (device << 16) | button;
    bool was_pressed = self->joy_button_click_state[key];
    self->joy_button_click_state[key] = is_pressed;
    
    lua_pushboolean(L, is_pressed && !was_pressed);
    return 1;
}

int LuaScripting::lua_ioJoystickGetButtonUp(lua_State* L) {
    lua_pushboolean(L, false);
    return 1;
}

int LuaScripting::lua_ioJoystickGetHat(lua_State* L) {
    if (!lua_isnumber(L, 1) || !lua_isnumber(L, 2)) {
        lua_pushinteger(L, 0);
        return 1;
    }
    int device = (int)lua_tonumber(L, 1);
    
    int hat = 0;
    if (godot::Input::get_singleton()->is_joy_button_pressed(device, godot::JOY_BUTTON_DPAD_UP)) hat |= 1;
    if (godot::Input::get_singleton()->is_joy_button_pressed(device, godot::JOY_BUTTON_DPAD_RIGHT)) hat |= 2;
    if (godot::Input::get_singleton()->is_joy_button_pressed(device, godot::JOY_BUTTON_DPAD_DOWN)) hat |= 4;
    if (godot::Input::get_singleton()->is_joy_button_pressed(device, godot::JOY_BUTTON_DPAD_LEFT)) hat |= 8;
    
    lua_pushinteger(L, hat);
    return 1;
}

int LuaScripting::lua_ioJoystickGetNumAxes(lua_State* L) {
    lua_pushinteger(L, godot::JOY_AXIS_MAX);
    return 1;
}

int LuaScripting::lua_ioJoystickGetNumButtons(lua_State* L) {
    lua_pushinteger(L, godot::JOY_BUTTON_MAX);
    return 1;
}

int LuaScripting::lua_ioJoystickGetNumHats(lua_State* L) {
    lua_pushinteger(L, 1);
    return 1;
}

int LuaScripting::lua_godotGetNodePointer(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (lua_isstring(L, 1) && self && self->godotCmdFunc) {
        auto sd = std::make_shared<LuaSyncData>();
        float fargs[3] = {0,0,0};
        self->godotCmdFunc(GCMD_GET_NODE_POINTER, lua_tostring(L, 1), fargs, sd, L, self);
        std::unique_lock<std::mutex> lock(sd->mtx);
        while (!sd->done && self && self->systemRunning) {
            sd->cv.wait_for(lock, std::chrono::milliseconds(10));
        }
        if (sd->object_id_res) {
            lua_pushinteger(L, sd->object_id_res);
        } else {
            lua_pushnil(L);
        }
        return 1;
    }
    return 0;
}

int LuaScripting::lua_godotInputGetAxis(lua_State* L) {
    if (lua_isstring(L, 1) && lua_isstring(L, 2)) {
        float val = godot::Input::get_singleton()->get_axis(lua_tostring(L, 1), lua_tostring(L, 2));
        lua_pushnumber(L, val);
        return 1;
    }
    return 0;
}

int LuaScripting::lua_godotInputIsActionPressed(lua_State* L) {
    if (lua_isstring(L, 1)) {
        bool val = godot::Input::get_singleton()->is_action_pressed(lua_tostring(L, 1));
        lua_pushboolean(L, val);
        return 1;
    }
    return 0;
}

int LuaScripting::lua_godotSelectRoot(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (self && self->godotCmdFunc) {
        auto sd = std::make_shared<LuaSyncData>();
        float fargs[3] = {0,0,0};
        self->godotCmdFunc(GCMD_SELECT_ROOT, "", fargs, sd, L, self);
        std::unique_lock<std::mutex> lock(sd->mtx);
        while (!sd->done && self && self->systemRunning) {
            sd->cv.wait_for(lock, std::chrono::milliseconds(10));
        }
    }
    return 0;
}

int LuaScripting::lua_godotSelectNode(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (lua_isstring(L, 1) && self && self->godotCmdFunc) {
        auto sd = std::make_shared<LuaSyncData>();
        float fargs[3] = {0,0,0};
        self->godotCmdFunc(GCMD_SELECT_NODE, lua_tostring(L, 1), fargs, sd, L, self);
        std::unique_lock<std::mutex> lock(sd->mtx);
        while (!sd->done && self && self->systemRunning) {
            sd->cv.wait_for(lock, std::chrono::milliseconds(10));
        }
        lua_pushboolean(L, sd->b_res);
        return 1;
    }
    return 0;
}

int LuaScripting::lua_godotSearchNode(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (lua_isstring(L, 1) && self && self->godotCmdFunc) {
        auto sd = std::make_shared<LuaSyncData>();
        float fargs[3] = {0,0,0};
        self->godotCmdFunc(GCMD_SEARCH_NODE, lua_tostring(L, 1), fargs, sd, L, self);
        std::unique_lock<std::mutex> lock(sd->mtx);
        while (!sd->done && self && self->systemRunning) {
            sd->cv.wait_for(lock, std::chrono::milliseconds(10));
        }
        lua_pushboolean(L, sd->b_res);
        return 1;
    }
    return 0;
}

int LuaScripting::lua_godotGetNodeType(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (self && self->godotCmdFunc) {
        auto sd = std::make_shared<LuaSyncData>();
        float fargs[3] = {0,0,0};
        if (lua_isinteger(L, 1)) {
            sd->object_id_arg = (uint64_t)lua_tointeger(L, 1);
        }
        self->godotCmdFunc(GCMD_GET_NODE_TYPE, "", fargs, sd, L, self);
        std::unique_lock<std::mutex> lock(sd->mtx);
        while (!sd->done && self && self->systemRunning) {
            sd->cv.wait_for(lock, std::chrono::milliseconds(10));
        }
        lua_pushstring(L, sd->s_res.c_str());
        return 1;
    }
    return 0;
}

int LuaScripting::lua_godotGetName(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (self && self->godotCmdFunc) {
        auto sd = std::make_shared<LuaSyncData>();
        float fargs[3] = {0,0,0};
        if (lua_isinteger(L, 1)) {
            sd->object_id_arg = (uint64_t)lua_tointeger(L, 1);
        }
        self->godotCmdFunc(GCMD_GET_NAME, "", fargs, sd, L, self);
        std::unique_lock<std::mutex> lock(sd->mtx);
        while (!sd->done && self && self->systemRunning) {
            sd->cv.wait_for(lock, std::chrono::milliseconds(10));
        }
        lua_pushstring(L, sd->s_res.c_str());
        return 1;
    }
    return 0;
}

int LuaScripting::lua_godotGetChildCount(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (self && self->godotCmdFunc) {
        auto sd = std::make_shared<LuaSyncData>();
        float fargs[3] = {0,0,0};
        if (lua_isinteger(L, 1)) {
            sd->object_id_arg = (uint64_t)lua_tointeger(L, 1);
        }
        self->godotCmdFunc(GCMD_GET_CHILD_COUNT, "", fargs, sd, L, self);
        std::unique_lock<std::mutex> lock(sd->mtx);
        while (!sd->done && self && self->systemRunning) {
            sd->cv.wait_for(lock, std::chrono::milliseconds(10));
        }
        lua_pushinteger(L, (lua_Integer)sd->d_res);
        return 1;
    }
    return 0;
}

int LuaScripting::lua_godotPrintHierarchy(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (self && self->godotCmdFunc) {
        auto sd = std::make_shared<LuaSyncData>();
        float fargs[3] = {0,0,0};
        self->godotCmdFunc(GCMD_PRINT_HIERARCHY, "", fargs, sd, L, self);
        std::unique_lock<std::mutex> lock(sd->mtx);
        while (!sd->done && self && self->systemRunning) {
            sd->cv.wait_for(lock, std::chrono::milliseconds(10));
        }
    }
    return 0;
}

int LuaScripting::lua_godotRenameNode(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (lua_isstring(L, 1) && self && self->godotCmdFunc) {
        auto sd = std::make_shared<LuaSyncData>();
        float fargs[3] = {0,0,0};
        if (lua_isinteger(L, 2)) {
            sd->object_id_arg = (uint64_t)lua_tointeger(L, 2);
        }
        self->godotCmdFunc(GCMD_RENAME_NODE, lua_tostring(L, 1), fargs, sd, L, self);
        std::unique_lock<std::mutex> lock(sd->mtx);
        while (!sd->done && self && self->systemRunning) {
            sd->cv.wait_for(lock, std::chrono::milliseconds(10));
        }
    }
    return 0;
}

int LuaScripting::lua_godotSetCamera(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (self && self->godotCmdFunc) {
        auto sd = std::make_shared<LuaSyncData>();
        float fargs[3] = {0,0,0};
        self->godotCmdFunc(GCMD_SET_CAMERA, "", fargs, sd, L, self);
        std::unique_lock<std::mutex> lock(sd->mtx);
        while (!sd->done && self && self->systemRunning) {
            sd->cv.wait_for(lock, std::chrono::milliseconds(10));
        }
        lua_pushboolean(L, sd->b_res);
        return 1;
    }
    return 0;
}

int LuaScripting::lua_godotGetPos(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (self && self->godotCmdFunc) {
        auto sd = std::make_shared<LuaSyncData>();
        float fargs[3] = {0,0,0};
        if (lua_isinteger(L, 1)) {
            sd->object_id_arg = (uint64_t)lua_tointeger(L, 1);
        }
        self->godotCmdFunc(GCMD_GET_POS, "", fargs, sd, L, self);
        std::unique_lock<std::mutex> lock(sd->mtx);
        while (!sd->done && self && self->systemRunning) {
            sd->cv.wait_for(lock, std::chrono::milliseconds(10));
        }
        lua_pushnumber(L, sd->f_res[0]);
        lua_pushnumber(L, sd->f_res[1]);
        lua_pushnumber(L, sd->f_res[2]);
        return 3;
    }
    return 0;
}

int LuaScripting::lua_godotSetPos(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (lua_isnumber(L, 1) && lua_isnumber(L, 2) && lua_isnumber(L, 3) && self && self->godotCmdFunc) {
        auto sd = std::make_shared<LuaSyncData>();
        float fargs[3] = {(float)lua_tonumber(L, 1), (float)lua_tonumber(L, 2), (float)lua_tonumber(L, 3)};
        if (lua_isinteger(L, 4)) {
            sd->object_id_arg = (uint64_t)lua_tointeger(L, 4);
        }
        self->godotCmdFunc(GCMD_SET_POS, "", fargs, sd, L, self);
        std::unique_lock<std::mutex> lock(sd->mtx);
        while (!sd->done && self && self->systemRunning) {
            sd->cv.wait_for(lock, std::chrono::milliseconds(10));
        }
    }
    return 0;
}

int LuaScripting::lua_godotSetVisible(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (lua_isboolean(L, 1) && self && self->godotCmdFunc) {
        auto sd = std::make_shared<LuaSyncData>();
        float fargs[3] = {lua_toboolean(L, 1) ? 1.0f : 0.0f, 0, 0};
        if (lua_isinteger(L, 2)) {
            sd->object_id_arg = (uint64_t)lua_tointeger(L, 2);
        }
        self->godotCmdFunc(GCMD_SET_VISIBLE, "", fargs, sd, L, self);
        std::unique_lock<std::mutex> lock(sd->mtx);
        while (!sd->done && self && self->systemRunning) {
            sd->cv.wait_for(lock, std::chrono::milliseconds(10));
        }
    }
    return 0;
}

int LuaScripting::lua_godotGetScale(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (self && self->godotCmdFunc) {
        auto sd = std::make_shared<LuaSyncData>();
        float fargs[3] = {0,0,0};
        if (lua_isinteger(L, 1)) {
            sd->object_id_arg = (uint64_t)lua_tointeger(L, 1);
        }
        self->godotCmdFunc(GCMD_GET_SCALE, "", fargs, sd, L, self);
        std::unique_lock<std::mutex> lock(sd->mtx);
        while (!sd->done && self && self->systemRunning) {
            sd->cv.wait_for(lock, std::chrono::milliseconds(10));
        }
        lua_pushnumber(L, sd->f_res[0]);
        lua_pushnumber(L, sd->f_res[1]);
        lua_pushnumber(L, sd->f_res[2]);
        return 3;
    }
    return 0;
}

int LuaScripting::lua_godotSetScale(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (lua_isnumber(L, 1) && lua_isnumber(L, 2) && lua_isnumber(L, 3) && self && self->godotCmdFunc) {
        auto sd = std::make_shared<LuaSyncData>();
        float fargs[3] = {(float)lua_tonumber(L, 1), (float)lua_tonumber(L, 2), (float)lua_tonumber(L, 3)};
        if (lua_isinteger(L, 4)) {
            sd->object_id_arg = (uint64_t)lua_tointeger(L, 4);
        }
        self->godotCmdFunc(GCMD_SET_SCALE, "", fargs, sd, L, self);
        std::unique_lock<std::mutex> lock(sd->mtx);
        while (!sd->done && self && self->systemRunning) {
            sd->cv.wait_for(lock, std::chrono::milliseconds(10));
        }
    }
    return 0;
}

int LuaScripting::lua_godotMoveX(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (lua_isnumber(L, 1) && self && self->godotCmdFunc) {
        auto sd = std::make_shared<LuaSyncData>();
        float fargs[3] = {(float)lua_tonumber(L, 1), 0, 0};
        if (lua_isinteger(L, 2)) {
            sd->object_id_arg = (uint64_t)lua_tointeger(L, 2);
        }
        self->godotCmdFunc(GCMD_MOVE_X, "", fargs, sd, L, self);
        std::unique_lock<std::mutex> lock(sd->mtx);
        while (!sd->done && self && self->systemRunning) {
            sd->cv.wait_for(lock, std::chrono::milliseconds(10));
        }
    }
    return 0;
}

int LuaScripting::lua_godotMoveY(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (lua_isnumber(L, 1) && self && self->godotCmdFunc) {
        auto sd = std::make_shared<LuaSyncData>();
        float fargs[3] = {0, (float)lua_tonumber(L, 1), 0};
        if (lua_isinteger(L, 2)) {
            sd->object_id_arg = (uint64_t)lua_tointeger(L, 2);
        }
        self->godotCmdFunc(GCMD_MOVE_Y, "", fargs, sd, L, self);
        std::unique_lock<std::mutex> lock(sd->mtx);
        while (!sd->done && self && self->systemRunning) {
            sd->cv.wait_for(lock, std::chrono::milliseconds(10));
        }
    }
    return 0;
}

int LuaScripting::lua_godotMoveZ(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (lua_isnumber(L, 1) && self && self->godotCmdFunc) {
        auto sd = std::make_shared<LuaSyncData>();
        float fargs[3] = {0, 0, (float)lua_tonumber(L, 1)};
        if (lua_isinteger(L, 2)) {
            sd->object_id_arg = (uint64_t)lua_tointeger(L, 2);
        }
        self->godotCmdFunc(GCMD_MOVE_Z, "", fargs, sd, L, self);
        std::unique_lock<std::mutex> lock(sd->mtx);
        while (!sd->done && self && self->systemRunning) {
            sd->cv.wait_for(lock, std::chrono::milliseconds(10));
        }
    }
    return 0;
}

int LuaScripting::lua_godotMoveAndCollide(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (lua_isnumber(L, 1) && lua_isnumber(L, 2) && lua_isnumber(L, 3) && self && self->godotCmdFunc) {
        auto sd = std::make_shared<LuaSyncData>();
        float fargs[3] = {(float)lua_tonumber(L, 1), (float)lua_tonumber(L, 2), (float)lua_tonumber(L, 3)};
        if (lua_isinteger(L, 4)) {
            sd->object_id_arg = (uint64_t)lua_tointeger(L, 4);
        }
        self->godotCmdFunc(GCMD_MOVE_AND_COLLIDE, "", fargs, sd, L, self);
        std::unique_lock<std::mutex> lock(sd->mtx);
        while (!sd->done && self && self->systemRunning) {
            sd->cv.wait_for(lock, std::chrono::milliseconds(10));
        }
        lua_pushboolean(L, sd->b_res);
        return 1;
    }
    return 0;
}

int LuaScripting::lua_godotGetOverlappingAreas(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (self && self->godotCmdFunc) {
        auto sd = std::make_shared<LuaSyncData>();
        float fargs[3] = {0,0,0};
        if (lua_isinteger(L, 1)) {
            sd->object_id_arg = (uint64_t)lua_tointeger(L, 1);
        }
        self->godotCmdFunc(GCMD_GET_OVERLAPPING_AREAS, "", fargs, sd, L, self);
        std::unique_lock<std::mutex> lock(sd->mtx);
        while (!sd->done && self && self->systemRunning) {
            sd->cv.wait_for(lock, std::chrono::milliseconds(10));
        }
        lua_newtable(L);
        for (size_t i = 0; i < sd->vs_res.size(); ++i) {
            lua_pushinteger(L, (lua_Integer)i + 1);
            lua_pushstring(L, sd->vs_res[i].c_str());
            lua_settable(L, -3);
        }
        return 1;
    }
    return 0;
}

int LuaScripting::lua_godotCreateNode(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (lua_isstring(L, 1) && self && self->godotCmdFunc) {
        auto sd = std::make_shared<LuaSyncData>();
        float fargs[3] = {0,0,0};
        self->godotCmdFunc(GCMD_CREATE_NODE, lua_tostring(L, 1), fargs, sd, L, self);
        std::unique_lock<std::mutex> lock(sd->mtx);
        while (!sd->done && self && self->systemRunning) {
            sd->cv.wait_for(lock, std::chrono::milliseconds(10));
        }
        lua_pushboolean(L, sd->b_res);
        return 1;
    }
    return 0;
}

int LuaScripting::lua_godotLoadNode(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (lua_isstring(L, 1) && self && self->godotCmdFunc) {
        auto sd = std::make_shared<LuaSyncData>();
        float fargs[3] = {0,0,0};
        int use_pos = 0;
        if (lua_gettop(L) >= 4 && lua_isnumber(L, 2) && lua_isnumber(L, 3) && lua_isnumber(L, 4)) {
            fargs[0] = (float)lua_tonumber(L, 2);
            fargs[1] = (float)lua_tonumber(L, 3);
            fargs[2] = (float)lua_tonumber(L, 4);
            use_pos = 1;
        }

        if (lua_isinteger(L, 5)) {
            sd->object_id_arg = (uint64_t)lua_tointeger(L, 5);
        }

        std::string path = lua_tostring(L, 1);
        sd->b_res = (use_pos == 1);

        self->godotCmdFunc(GCMD_LOAD_NODE, path, fargs, sd, L, self);
        std::unique_lock<std::mutex> lock(sd->mtx);
        while (!sd->done && self && self->systemRunning) {
            sd->cv.wait_for(lock, std::chrono::milliseconds(10));
        }
        lua_pushboolean(L, sd->b_res);
        return 1;
    }
    return 0;
}
int LuaScripting::lua_godotDeleteNode(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (self && self->godotCmdFunc) {
        auto sd = std::make_shared<LuaSyncData>();
        float fargs[3] = {0,0,0};
        if (lua_isinteger(L, 1)) {
            sd->object_id_arg = (uint64_t)lua_tointeger(L, 1);
        }
        self->godotCmdFunc(GCMD_DELETE_NODE, "", fargs, sd, L, self);
        std::unique_lock<std::mutex> lock(sd->mtx);
        while (!sd->done && self && self->systemRunning) {
            sd->cv.wait_for(lock, std::chrono::milliseconds(10));
        }
    }
    return 0;
}

int LuaScripting::lua_godotAttachScript(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (lua_isstring(L, 1) && self && self->godotCmdFunc) {
        auto sd = std::make_shared<LuaSyncData>();
        float fargs[3] = {0,0,0};
        self->godotCmdFunc(GCMD_ATTACH_SCRIPT, lua_tostring(L, 1), fargs, sd, L, self);
        std::unique_lock<std::mutex> lock(sd->mtx);
        while (!sd->done && self && self->systemRunning) {
            sd->cv.wait_for(lock, std::chrono::milliseconds(10));
        }
        lua_pushboolean(L, sd->b_res);
        return 1;
    }
    return 0;
}

int LuaScripting::lua_godotRegisterImpulseProperty(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (lua_isstring(L, 1) && self) {
        std::string name = lua_tostring(L, 1);
        std::lock_guard<std::mutex> lock(self->threadsMutex);
        self->impulse_properties.insert(name);
    }
    return 0;
}

int LuaScripting::lua_godotSetProperty(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (lua_isstring(L, 1) && self && self->godotCmdFunc) {
        std::string name = lua_tostring(L, 1);
        uint64_t target = lua_isinteger(L, 3) ? (uint64_t)lua_tointeger(L, 3) : 0;
        
        bool is_impulse = false;
        {
            std::lock_guard<std::mutex> lock(self->threadsMutex);
            is_impulse = (self->impulse_properties.find(name) != self->impulse_properties.end());
        }
        
        if (lua_isnumber(L, 2)) {
            float val = (float)lua_tonumber(L, 2);
            if (!is_impulse) {
                auto key = std::make_pair(target, name);
                auto it = self->last_float_sets.find(key);
                if (it != self->last_float_sets.end() && it->second == val) {
                    return 0; // Skip redundant set
                }
                self->last_float_sets[key] = val;
            }
            
            auto sd = std::make_shared<LuaSyncData>();
            sd->object_id_arg = target;
            float fargs[3] = {val, 0.0f, 0.0f}; // 0 = Number
            self->godotCmdFunc(GCMD_SET_PROPERTY, name, fargs, sd, L, self);
            std::unique_lock<std::mutex> lock(sd->mtx);
            while (!sd->done && self && self->systemRunning) {
                sd->cv.wait_for(lock, std::chrono::milliseconds(10));
            }
        } else if (lua_isstring(L, 2)) {
            std::string val = lua_tostring(L, 2);
            if (!is_impulse) {
                auto key = std::make_pair(target, name);
                auto it = self->last_string_sets.find(key);
                if (it != self->last_string_sets.end() && it->second == val) {
                    return 0; // Skip redundant set
                }
                self->last_string_sets[key] = val;
            }
            
            auto sd = std::make_shared<LuaSyncData>();
            sd->object_id_arg = target;
            float fargs[3] = {0.0f, 1.0f, 0.0f}; // 1 = String
            std::string combined = name + "|" + val;
            self->godotCmdFunc(GCMD_SET_PROPERTY, combined, fargs, sd, L, self);
            std::unique_lock<std::mutex> lock(sd->mtx);
            while (!sd->done && self && self->systemRunning) {
                sd->cv.wait_for(lock, std::chrono::milliseconds(10));
            }
        } else if (lua_isboolean(L, 2)) {
            bool val = lua_toboolean(L, 2);
            if (!is_impulse) {
                auto key = std::make_pair(target, name);
                auto it = self->last_bool_sets.find(key);
                if (it != self->last_bool_sets.end() && it->second == val) {
                    return 0; // Skip redundant set
                }
                self->last_bool_sets[key] = val;
            }
            
            auto sd = std::make_shared<LuaSyncData>();
            sd->object_id_arg = target;
            float fargs[3] = {val ? 1.0f : 0.0f, 2.0f, 0.0f}; // 2 = Bool
            self->godotCmdFunc(GCMD_SET_PROPERTY, name, fargs, sd, L, self);
            std::unique_lock<std::mutex> lock(sd->mtx);
            while (!sd->done && self && self->systemRunning) {
                sd->cv.wait_for(lock, std::chrono::milliseconds(10));
            }
        }
    }
    return 0;
}

int LuaScripting::lua_godotGetProperty(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (lua_isstring(L, 1) && self && self->godotCmdFunc) {
        auto sd = std::make_shared<LuaSyncData>();
        float fargs[3] = {0,0,0};
        if (lua_isinteger(L, 2)) {
            sd->object_id_arg = (uint64_t)lua_tointeger(L, 2);
        }
        self->godotCmdFunc(GCMD_GET_PROPERTY, lua_tostring(L, 1), fargs, sd, L, self);
        std::unique_lock<std::mutex> lock(sd->mtx);
        while (!sd->done && self && self->systemRunning) {
            sd->cv.wait_for(lock, std::chrono::milliseconds(10));
        }
        if (sd->res_type == 1) { 
            lua_pushnumber(L, sd->d_res);
        } else if (sd->res_type == 2) {
            lua_pushboolean(L, sd->b_res);
        } else if (sd->res_type == 3) {
            lua_pushstring(L, sd->s_res.c_str());
        } else {
            lua_pushnil(L);
        }
        return 1;
    }
    return 0;
}

int LuaScripting::lua_godotWatchProperty(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (lua_isstring(L, 1) && lua_isstring(L, 2) && lua_isstring(L, 4) && self && self->godotCmdFunc) {
        std::string node = lua_tostring(L, 1);
        std::string prop = lua_tostring(L, 2);
        std::string file = lua_tostring(L, 4);
        int mode = 0;
        if (lua_isinteger(L, 5)) mode = (int)lua_tointeger(L, 5);

        float fargs[3] = {0,0,0};
        std::string combined = node + "|" + prop + "|" + file + "|";

        if (lua_isnumber(L, 3)) {
            fargs[0] = (float)lua_tonumber(L, 3);
            fargs[1] = 0; // Number
        } else if (lua_isstring(L, 3)) {
            combined += lua_tostring(L, 3);
            fargs[1] = 1; // String
        } else if (lua_isboolean(L, 3)) {
            fargs[0] = lua_toboolean(L, 3) ? 1.0f : 0.0f;
            fargs[1] = 2; // Bool
        } else {
            return 0;
        }
        
        fargs[2] = (float)mode;
        self->godotCmdFunc(GCMD_WATCH_PROPERTY, combined, fargs, nullptr, L, self);
    }
    return 0;
}

void LuaScripting::renderLuaImGui() {
    std::lock_guard<std::mutex> lock(imgui_mutex);
    for (auto& win : lua_imgui_windows) {
        ImGui::Begin(win.title.c_str());
        for (auto& widget : win.widgets) {
            switch (widget.type) {
                case ImGuiWidget::TEXT:
                    ImGui::Text("%s", widget.label.c_str());
                    break;
                case ImGuiWidget::SEPARATOR:
                    ImGui::Separator();
                    break;
                case ImGuiWidget::CHECKBOX: {
                    bool val = getGlobalFloat(widget.var_name) > 0.5f;
                    if (ImGui::Checkbox(widget.label.c_str(), &val)) {
                        setGlobalFloat(widget.var_name, val ? 1.0f : 0.0f);
                    }
                    break;
                }
                case ImGuiWidget::SLIDER_FLOAT: {
                    float val = getGlobalFloat(widget.var_name);
                    if (ImGui::SliderFloat(widget.label.c_str(), &val, widget.min_val, widget.max_val)) {
                        setGlobalFloat(widget.var_name, val);
                    }
                    break;
                }
                case ImGuiWidget::BUTTON: {
                    if (ImGui::Button(widget.label.c_str())) {
                        setGlobalFloat(widget.var_name, 1.0f);
                    }
                    break;
                }
                case ImGuiWidget::PROGRESS_BAR: {
                    float fraction = getGlobalFloat(widget.var_name);
                    ImGui::ProgressBar(fraction, ImVec2(0.0f, 0.0f), widget.label.c_str());
                    break;
                }
                case ImGuiWidget::SAME_LINE:
                    ImGui::SameLine();
                    break;
            }
        }
        ImGui::End();
    }
    
    static bool show_gamepad_diagnostic = false;
    static bool f3_was_pressed = false;
    bool f3_is_pressed = godot::Input::get_singleton()->is_key_pressed(godot::KEY_F3);
    if (f3_is_pressed && !f3_was_pressed) {
        show_gamepad_diagnostic = !show_gamepad_diagnostic;
    }
    f3_was_pressed = f3_is_pressed;
    
    if (show_gamepad_diagnostic) {
        static int device_id = 0;
        
        ImGui::Begin("Gamepad Diagnostic Panel", &show_gamepad_diagnostic);
        ImGui::SliderInt("Device ID", &device_id, 0, 8);
        
        ImDrawList* draw_list = ImGui::GetWindowDrawList();
        ImVec2 p = ImGui::GetCursorScreenPos();
        ImVec2 center = ImVec2(p.x + 200, p.y + 120);
        
        draw_list->AddRectFilled(ImVec2(center.x - 150, center.y - 80), ImVec2(center.x + 150, center.y + 80), IM_COL32(50, 50, 50, 255), 40.0f);
        
        godot::Input* input = godot::Input::get_singleton();
        
        float lx = input->get_joy_axis(device_id, godot::JOY_AXIS_LEFT_X);
        float ly = input->get_joy_axis(device_id, godot::JOY_AXIS_LEFT_Y);
        bool l3 = input->is_joy_button_pressed(device_id, godot::JOY_BUTTON_LEFT_STICK);
        ImVec2 lstick(center.x - 60, center.y + 40);
        draw_list->AddCircleFilled(lstick, 30.0f, IM_COL32(30, 30, 30, 255));
        draw_list->AddCircleFilled(ImVec2(lstick.x + lx * 20, lstick.y + ly * 20), 15.0f, l3 ? IM_COL32(255, 100, 100, 255) : IM_COL32(100, 100, 255, 255));

        float rx = input->get_joy_axis(device_id, godot::JOY_AXIS_RIGHT_X);
        float ry = input->get_joy_axis(device_id, godot::JOY_AXIS_RIGHT_Y);
        bool r3 = input->is_joy_button_pressed(device_id, godot::JOY_BUTTON_RIGHT_STICK);
        ImVec2 rstick(center.x + 60, center.y + 40);
        draw_list->AddCircleFilled(rstick, 30.0f, IM_COL32(30, 30, 30, 255));
        draw_list->AddCircleFilled(ImVec2(rstick.x + rx * 20, rstick.y + ry * 20), 15.0f, r3 ? IM_COL32(255, 100, 100, 255) : IM_COL32(100, 100, 255, 255));

        int hat = 0;
        if (input->is_joy_button_pressed(device_id, godot::JOY_BUTTON_DPAD_UP)) hat |= 1;
        if (input->is_joy_button_pressed(device_id, godot::JOY_BUTTON_DPAD_RIGHT)) hat |= 2;
        if (input->is_joy_button_pressed(device_id, godot::JOY_BUTTON_DPAD_DOWN)) hat |= 4;
        if (input->is_joy_button_pressed(device_id, godot::JOY_BUTTON_DPAD_LEFT)) hat |= 8;
        
        ImVec2 dpad(center.x - 100, center.y - 30);
        draw_list->AddRectFilled(ImVec2(dpad.x - 10, dpad.y - 30), ImVec2(dpad.x + 10, dpad.y + 30), IM_COL32(70, 70, 70, 255), 5.0f);
        draw_list->AddRectFilled(ImVec2(dpad.x - 30, dpad.y - 10), ImVec2(dpad.x + 30, dpad.y + 10), IM_COL32(70, 70, 70, 255), 5.0f);
        if (hat & 1) draw_list->AddRectFilled(ImVec2(dpad.x - 10, dpad.y - 30), ImVec2(dpad.x + 10, dpad.y), IM_COL32(100, 255, 100, 255), 5.0f);
        if (hat & 2) draw_list->AddRectFilled(ImVec2(dpad.x, dpad.y - 10), ImVec2(dpad.x + 30, dpad.y + 10), IM_COL32(100, 255, 100, 255), 5.0f);
        if (hat & 4) draw_list->AddRectFilled(ImVec2(dpad.x - 10, dpad.y), ImVec2(dpad.x + 10, dpad.y + 30), IM_COL32(100, 255, 100, 255), 5.0f);
        if (hat & 8) draw_list->AddRectFilled(ImVec2(dpad.x - 30, dpad.y - 10), ImVec2(dpad.x, dpad.y + 10), IM_COL32(100, 255, 100, 255), 5.0f);

        ImVec2 face(center.x + 100, center.y - 30);
        bool bCross = input->is_joy_button_pressed(device_id, godot::JOY_BUTTON_A);
        bool bCircle = input->is_joy_button_pressed(device_id, godot::JOY_BUTTON_B);
        bool bSquare = input->is_joy_button_pressed(device_id, godot::JOY_BUTTON_X);
        bool bTri = input->is_joy_button_pressed(device_id, godot::JOY_BUTTON_Y);
        
        draw_list->AddCircleFilled(ImVec2(face.x, face.y + 20), 10.0f, bCross ? IM_COL32(100, 100, 255, 255) : IM_COL32(70, 70, 70, 255));
        draw_list->AddCircleFilled(ImVec2(face.x + 20, face.y), 10.0f, bCircle ? IM_COL32(255, 100, 100, 255) : IM_COL32(70, 70, 70, 255));
        draw_list->AddCircleFilled(ImVec2(face.x - 20, face.y), 10.0f, bSquare ? IM_COL32(255, 100, 255, 255) : IM_COL32(70, 70, 70, 255));
        draw_list->AddCircleFilled(ImVec2(face.x, face.y - 20), 10.0f, bTri ? IM_COL32(100, 255, 100, 255) : IM_COL32(70, 70, 70, 255));

        bool l1 = input->is_joy_button_pressed(device_id, godot::JOY_BUTTON_LEFT_SHOULDER);
        bool r1 = input->is_joy_button_pressed(device_id, godot::JOY_BUTTON_RIGHT_SHOULDER);
        float l2 = input->get_joy_axis(device_id, godot::JOY_AXIS_TRIGGER_LEFT);
        float r2 = input->get_joy_axis(device_id, godot::JOY_AXIS_TRIGGER_RIGHT);
        
        draw_list->AddRectFilled(ImVec2(center.x - 120, center.y - 95), ImVec2(center.x - 80, center.y - 80), l1 ? IM_COL32(255,255,255,255) : IM_COL32(70,70,70,255), 5.0f);
        draw_list->AddRectFilled(ImVec2(center.x + 80, center.y - 95), ImVec2(center.x + 120, center.y - 80), r1 ? IM_COL32(255,255,255,255) : IM_COL32(70,70,70,255), 5.0f);
        
        // Godot's trigger axes are 0.0 to 1.0, not -1.0 to 1.0 like SDL
        float l2_val = l2;
        float r2_val = r2;
        draw_list->AddRectFilled(ImVec2(center.x - 120, center.y - 120), ImVec2(center.x - 80, center.y - 100), IM_COL32(50,50,50,255), 2.0f);
        draw_list->AddRectFilled(ImVec2(center.x - 120, center.y - 120 + 20 * (1 - l2_val)), ImVec2(center.x - 80, center.y - 100), IM_COL32(255,200,100,255), 2.0f);
        
        draw_list->AddRectFilled(ImVec2(center.x + 80, center.y - 120), ImVec2(center.x + 120, center.y - 100), IM_COL32(50,50,50,255), 2.0f);
        draw_list->AddRectFilled(ImVec2(center.x + 80, center.y - 120 + 20 * (1 - r2_val)), ImVec2(center.x + 120, center.y - 100), IM_COL32(255,200,100,255), 2.0f);

        // Touchpad button if supported
        bool touch = input->is_joy_button_pressed(device_id, (godot::JoyButton)15);
        draw_list->AddRectFilled(ImVec2(center.x - 40, center.y - 60), ImVec2(center.x + 40, center.y), touch ? IM_COL32(150,150,150,255) : IM_COL32(30,30,30,255), 10.0f);

        bool share = input->is_joy_button_pressed(device_id, godot::JOY_BUTTON_BACK);
        bool ps = input->is_joy_button_pressed(device_id, godot::JOY_BUTTON_GUIDE);
        bool options = input->is_joy_button_pressed(device_id, godot::JOY_BUTTON_START);
        
        draw_list->AddRectFilled(ImVec2(center.x - 60, center.y - 45), ImVec2(center.x - 45, center.y - 25), share ? IM_COL32(200,200,255,255) : IM_COL32(40,40,40,255), 2.0f);
        draw_list->AddCircleFilled(ImVec2(center.x, center.y + 25), 8.0f, ps ? IM_COL32(255,255,255,255) : IM_COL32(20,20,20,255));
        draw_list->AddRectFilled(ImVec2(center.x + 45, center.y - 45), ImVec2(center.x + 60, center.y - 25), options ? IM_COL32(200,200,255,255) : IM_COL32(40,40,40,255), 2.0f);

        ImGui::Dummy(ImVec2(400, 250));
        
        godot::Array connected_pads = input->get_connected_joypads();
        ImGui::Separator();
        ImGui::Text("Diagnostic Device ID: %d", device_id);
        ImGui::Text("Connected Gamepads: %d", (int)connected_pads.size());
        
        ImGui::End();
    }
}

int LuaScripting::lua_imguiBegin(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (lua_isstring(L, 1) && self) {
        std::string title = lua_tostring(L, 1);
        std::lock_guard<std::mutex> lock(self->imgui_mutex);
        
        auto it = std::find_if(self->lua_imgui_windows.begin(), self->lua_imgui_windows.end(), [&](const ImGuiWindowDef& w) {
            return w.title == title;
        });
        if (it != self->lua_imgui_windows.end()) {
            it->widgets.clear();
        } else {
            ImGuiWindowDef w;
            w.title = title;
            self->lua_imgui_windows.push_back(w);
        }
        self->active_window_title = title;
    }
    return 0;
}

int LuaScripting::lua_imguiRemoveWindow(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (lua_isstring(L, 1) && self) {
        std::string title = lua_tostring(L, 1);
        std::lock_guard<std::mutex> lock(self->imgui_mutex);
        auto it = std::find_if(self->lua_imgui_windows.begin(), self->lua_imgui_windows.end(), [&](const ImGuiWindowDef& w) {
            return w.title == title;
        });
        if (it != self->lua_imgui_windows.end()) {
            self->lua_imgui_windows.erase(it);
        }
    }
    return 0;
}

int LuaScripting::lua_imguiEnd(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (self) {
        std::lock_guard<std::mutex> lock(self->imgui_mutex);
        self->active_window_title = "";
    }
    return 0;
}

int LuaScripting::lua_imguiText(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (lua_isstring(L, 1) && self) {
        std::string text = lua_tostring(L, 1);
        std::lock_guard<std::mutex> lock(self->imgui_mutex);
        auto it = std::find_if(self->lua_imgui_windows.begin(), self->lua_imgui_windows.end(), [&](const ImGuiWindowDef& w) {
            return w.title == self->active_window_title;
        });
        if (it != self->lua_imgui_windows.end()) {
            ImGuiWidget w;
            w.type = ImGuiWidget::TEXT;
            w.label = text;
            it->widgets.push_back(w);
        }
    }
    return 0;
}

int LuaScripting::lua_imguiSeparator(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (self) {
        std::lock_guard<std::mutex> lock(self->imgui_mutex);
        auto it = std::find_if(self->lua_imgui_windows.begin(), self->lua_imgui_windows.end(), [&](const ImGuiWindowDef& w) {
            return w.title == self->active_window_title;
        });
        if (it != self->lua_imgui_windows.end()) {
            ImGuiWidget w;
            w.type = ImGuiWidget::SEPARATOR;
            it->widgets.push_back(w);
        }
    }
    return 0;
}

int LuaScripting::lua_imguiCheckbox(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (lua_isstring(L, 1) && lua_isstring(L, 2) && self) {
        std::string label = lua_tostring(L, 1);
        std::string var_name = lua_tostring(L, 2);
        std::lock_guard<std::mutex> lock(self->imgui_mutex);
        auto it = std::find_if(self->lua_imgui_windows.begin(), self->lua_imgui_windows.end(), [&](const ImGuiWindowDef& w) {
            return w.title == self->active_window_title;
        });
        if (it != self->lua_imgui_windows.end()) {
            ImGuiWidget w;
            w.type = ImGuiWidget::CHECKBOX;
            w.label = label;
            w.var_name = var_name;
            it->widgets.push_back(w);
        }
    }
    return 0;
}

int LuaScripting::lua_imguiSliderFloat(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (lua_isstring(L, 1) && lua_isstring(L, 2) && lua_isnumber(L, 3) && lua_isnumber(L, 4) && self) {
        std::string label = lua_tostring(L, 1);
        std::string var_name = lua_tostring(L, 2);
        float min_val = (float)lua_tonumber(L, 3);
        float max_val = (float)lua_tonumber(L, 4);
        std::lock_guard<std::mutex> lock(self->imgui_mutex);
        auto it = std::find_if(self->lua_imgui_windows.begin(), self->lua_imgui_windows.end(), [&](const ImGuiWindowDef& w) {
            return w.title == self->active_window_title;
        });
        if (it != self->lua_imgui_windows.end()) {
            ImGuiWidget w;
            w.type = ImGuiWidget::SLIDER_FLOAT;
            w.label = label;
            w.var_name = var_name;
            w.min_val = min_val;
            w.max_val = max_val;
            it->widgets.push_back(w);
        }
    }
    return 0;
}

int LuaScripting::lua_imguiButton(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (lua_isstring(L, 1) && lua_isstring(L, 2) && self) {
        std::string label = lua_tostring(L, 1);
        std::string var_name = lua_tostring(L, 2);
        std::lock_guard<std::mutex> lock(self->imgui_mutex);
        auto it = std::find_if(self->lua_imgui_windows.begin(), self->lua_imgui_windows.end(), [&](const ImGuiWindowDef& w) {
            return w.title == self->active_window_title;
        });
        if (it != self->lua_imgui_windows.end()) {
            ImGuiWidget w;
            w.type = ImGuiWidget::BUTTON;
            w.label = label;
            w.var_name = var_name;
            it->widgets.push_back(w);
        }
    }
    return 0;
}

int LuaScripting::lua_imguiProgressBar(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (lua_isstring(L, 1) && lua_isstring(L, 2) && self) {
        std::string overlay_text = lua_tostring(L, 1);
        std::string var_name = lua_tostring(L, 2);
        std::lock_guard<std::mutex> lock(self->imgui_mutex);
        auto it = std::find_if(self->lua_imgui_windows.begin(), self->lua_imgui_windows.end(), [&](const ImGuiWindowDef& w) {
            return w.title == self->active_window_title;
        });
        if (it != self->lua_imgui_windows.end()) {
            ImGuiWidget w;
            w.type = ImGuiWidget::PROGRESS_BAR;
            w.label = overlay_text;
            w.var_name = var_name;
            it->widgets.push_back(w);
        }
    }
    return 0;
}

int LuaScripting::lua_imguiSameLine(lua_State* L) {
    LuaScripting* self = (LuaScripting*)lua_touserdata(L, lua_upvalueindex(1));
    if (self) {
        std::lock_guard<std::mutex> lock(self->imgui_mutex);
        auto it = std::find_if(self->lua_imgui_windows.begin(), self->lua_imgui_windows.end(), [&](const ImGuiWindowDef& w) {
            return w.title == self->active_window_title;
        });
        if (it != self->lua_imgui_windows.end()) {
            ImGuiWidget w;
            w.type = ImGuiWidget::SAME_LINE;
            it->widgets.push_back(w);
        }
    }
    return 0;
}

