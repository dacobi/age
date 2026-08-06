#ifndef LUA_MANAGER_H
#define LUA_MANAGER_H

#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/classes/input_event.hpp>
#include <godot_cpp/classes/node2d.hpp>
#include <godot_cpp/classes/control.hpp>
#include <godot_cpp/classes/node3d.hpp>
#include "luascripting.h"
#include <vector>
#include <map>
#include <godot_cpp/classes/audio_effect_capture.hpp>

namespace godot {

class LuaManager : public Node {
    GDCLASS(LuaManager, Node)

private:
    LuaScripting* lua_engine = nullptr;
    
    void _on_dynamic_signal(String func_name);

    struct GodotCommand {
        int cmd; // Cast from LuaScripting::GodotCmd
        String name;
        float args[3];
        uint64_t object_id;
        std::shared_ptr<LuaSyncData> sd;
    };
    
    std::mutex cmd_mutex;
    std::vector<GodotCommand> cmd_queue;

    std::vector<uint64_t> bouncers;
    std::vector<uint64_t> loaded_nodes;
    std::vector<uint64_t> videos_to_preload;
    std::map<int, uint64_t> bouncer_layers;
    uint64_t bg_layer_id = 0;
    uint64_t bg_rect_id = 0;
    
    struct HighScoreEntry {
        String name;
        int score;
        int level;
    };
    std::vector<HighScoreEntry> highscores;
    
    uint64_t audio_player_id = 0;
    godot::Ref<godot::AudioEffectCapture> audio_capture;

    struct DynamicLabel {
        uint64_t label_id = 0;
        String syntax;
    };
    std::vector<DynamicLabel> dynamic_labels;
    String _evaluate_bouncer_text(const String& syntax);

    struct InteractiveData {
        Color normal_color;
        Color hover_color;
        bool has_hover = false;
        String clicked_script;
        uint64_t container_id = 0;
    };
    struct BouncerPhysics {
        bool enabled = false;
        Vector2 velocity;
        float speed = 1.0f;
        float friction = 1.0f;
        bool has_gravity = false;
        
        bool has_ttl = false;
        float ttl = 0.0f;
    };
    std::map<uint64_t, BouncerPhysics> bouncer_physics;

    std::map<uint64_t, InteractiveData> interactive_bouncers;

    void _add_bouncer_deferred(const String& syntax);
    void _del_bouncer_deferred(int index);
    void _set_bouncer_param_deferred(int index, String name, double value);
    void _set_bg_deferred(const String& syntax);
    void _clear_and_run_deferred(const String& filename);
    bool _play_audio_deferred(const String& filename);
    void _play_audio_dynamic_deferred(const String& filename);
    void _set_audio_volume_deferred(int vol);
    void _rewind_audio_deferred();
    void _skip_audio_deferred(int amount);
    void _set_resize_enabled_deferred(bool enabled);
    void _maximize_window_deferred();
    void _quit_deferred();

    void _on_bouncer_mouse_entered(uint64_t control_id);
    void _on_bouncer_mouse_exited(uint64_t control_id);
    void _on_bouncer_gui_input(const Ref<InputEvent>& event, uint64_t control_id);
    void _on_addhscore_submitted(String text, int score, int level, uint64_t bouncer_id);

protected:
    static void _bind_methods();

public:
    LuaManager();
    ~LuaManager();

    void _ready() override;
    void _process(double delta) override;
    void _input(const Ref<InputEvent>& event) override;
    
    void run_script(const String& filename);

    void set_global_int(const String& name, int val);
    int get_global_int(const String& name);
    void set_global_float(const String& name, float val);
    float get_global_float(const String& name);
};

}

#endif // LUA_MANAGER_H
