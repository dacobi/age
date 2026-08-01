#include <godot_cpp/classes/display_server.hpp>
#include "lua_manager.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/sprite2d.hpp>
#include <godot_cpp/classes/texture2d.hpp>
#include <godot_cpp/classes/resource_loader.hpp>
#include <godot_cpp/classes/input_event_mouse_motion.hpp>
#include <godot_cpp/classes/input.hpp>
#include <godot_cpp/classes/scene_tree.hpp>
#include <godot_cpp/classes/window.hpp>
#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/input_event_mouse_button.hpp>
#include <imgui.h>

using namespace godot;

void LuaManager::_on_bouncer_mouse_entered(uint64_t control_id) {
    if (interactive_bouncers.find(control_id) != interactive_bouncers.end()) {
        InteractiveData& idata = interactive_bouncers[control_id];
        if (idata.has_hover) {
            Node2D* container = Object::cast_to<Node2D>(ObjectDB::get_instance(idata.container_id));
            if (container) {
                container->set_modulate(idata.hover_color);
            }
        }
    }
}

void LuaManager::_on_bouncer_mouse_exited(uint64_t control_id) {
    if (interactive_bouncers.find(control_id) != interactive_bouncers.end()) {
        InteractiveData& idata = interactive_bouncers[control_id];
        if (idata.has_hover) {
            Node2D* container = Object::cast_to<Node2D>(ObjectDB::get_instance(idata.container_id));
            if (container) {
                container->set_modulate(idata.normal_color);
            }
        }
    }
}

void LuaManager::_on_bouncer_gui_input(const Ref<InputEvent>& event, uint64_t control_id) {
    if (interactive_bouncers.find(control_id) != interactive_bouncers.end()) {
        InteractiveData& idata = interactive_bouncers[control_id];
        Ref<InputEventMouseButton> mb = event;
        if (mb.is_valid() && mb->is_pressed() && mb->get_button_index() == MouseButton::MOUSE_BUTTON_LEFT) {
            if (!idata.clicked_script.is_empty()) {
                if (lua_engine) {
                    lua_engine->runScript(idata.clicked_script.utf8().get_data());
                }
            }
        }
    }
}

String LuaManager::_evaluate_bouncer_text(const String& syntax) {
    String s = syntax;
    String text = "";
    int current_idx = 0;
    while (current_idx < s.length()) {
        int start = s.find("[", current_idx);
        if (start == -1) {
            text += s.substr(current_idx, s.length() - current_idx);
            break;
        }
        text += s.substr(current_idx, start - current_idx);
        int end = s.find("]", start);
        if (end == -1) {
            text += s.substr(start, s.length() - start);
            break;
        }
        String tag = s.substr(start + 1, end - start - 1);
        if (tag.begins_with("global:")) {
            String gname = tag.substr(7).strip_edges();
            if (lua_engine) {
                if (lua_engine->global_ints.count(gname.utf8().get_data())) {
                    text += String::num_int64(lua_engine->getGlobalInt(gname.utf8().get_data()));
                } else if (lua_engine->global_floats.count(gname.utf8().get_data())) {
                    text += String::num(lua_engine->getGlobalFloat(gname.utf8().get_data()));
                }
            }
        }
        current_idx = end + 1;
    }
    return text.strip_edges();
}

void LuaManager::_on_dynamic_signal(String func_name) {
    if (lua_engine) {
        lua_engine->triggerCallback(func_name.utf8().get_data());
    }
}

void LuaManager::_quit_deferred() {
    get_tree()->quit();
}

void LuaManager::_bind_methods() {
    ClassDB::bind_method(D_METHOD("_on_bouncer_mouse_entered", "control_id"), &LuaManager::_on_bouncer_mouse_entered);
    ClassDB::bind_method(D_METHOD("_on_bouncer_mouse_exited", "control_id"), &LuaManager::_on_bouncer_mouse_exited);
    ClassDB::bind_method(D_METHOD("_on_bouncer_gui_input", "event", "control_id"), &LuaManager::_on_bouncer_gui_input);
    ClassDB::bind_method(D_METHOD("_add_bouncer_deferred", "syntax"), &LuaManager::_add_bouncer_deferred);
    ClassDB::bind_method(D_METHOD("_del_bouncer_deferred", "index"), &LuaManager::_del_bouncer_deferred);
    ClassDB::bind_method(D_METHOD("_set_bouncer_param_deferred", "index", "name", "value"), &LuaManager::_set_bouncer_param_deferred);
    ClassDB::bind_method(D_METHOD("_set_bg_deferred", "syntax"), &LuaManager::_set_bg_deferred);
    ClassDB::bind_method(D_METHOD("_clear_and_run_deferred", "filename"), &LuaManager::_clear_and_run_deferred);
    ClassDB::bind_method(D_METHOD("_play_audio_deferred", "filename"), &LuaManager::_play_audio_deferred);
    ClassDB::bind_method(D_METHOD("_play_audio_dynamic_deferred", "filename"), &LuaManager::_play_audio_dynamic_deferred);
    ClassDB::bind_method(D_METHOD("_set_audio_volume_deferred", "vol"), &LuaManager::_set_audio_volume_deferred);
    ClassDB::bind_method(D_METHOD("_rewind_audio_deferred"), &LuaManager::_rewind_audio_deferred);
    ClassDB::bind_method(D_METHOD("_skip_audio_deferred", "amount"), &LuaManager::_skip_audio_deferred);
    ClassDB::bind_method(D_METHOD("_set_resize_enabled_deferred", "enabled"), &LuaManager::_set_resize_enabled_deferred);
    ClassDB::bind_method(D_METHOD("_maximize_window_deferred"), &LuaManager::_maximize_window_deferred);
    ClassDB::bind_method(D_METHOD("_quit_deferred"), &LuaManager::_quit_deferred);
    ClassDB::bind_method(D_METHOD("_on_dynamic_signal", "func_name"), &LuaManager::_on_dynamic_signal);
    ClassDB::bind_method(D_METHOD("run_script", "filename"), &LuaManager::run_script);
    ClassDB::bind_method(D_METHOD("set_global_int", "name", "val"), &LuaManager::set_global_int);
    ClassDB::bind_method(D_METHOD("get_global_int", "name"), &LuaManager::get_global_int);
    ClassDB::bind_method(D_METHOD("set_global_float", "name", "val"), &LuaManager::set_global_float);
    ClassDB::bind_method(D_METHOD("get_global_float", "name"), &LuaManager::get_global_float);
}

LuaManager::LuaManager() {
}

LuaManager::~LuaManager() {
    if (lua_engine) {
        lua_engine->stop();
        delete lua_engine;
        lua_engine = nullptr;
    }
}

#include <godot_cpp/classes/label.hpp>
#include <godot_cpp/classes/canvas_layer.hpp>
#include <godot_cpp/classes/texture_rect.hpp>
#include <godot_cpp/classes/window.hpp>
#include <godot_cpp/classes/audio_stream_player.hpp>
#include <godot_cpp/classes/audio_stream.hpp>
#include <godot_cpp/classes/audio_stream_mp3.hpp>
#include <godot_cpp/classes/audio_stream_wav.hpp>
#include <godot_cpp/classes/audio_stream_ogg_vorbis.hpp>
#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/os.hpp>
#include <godot_cpp/classes/project_settings.hpp>
#include <godot_cpp/classes/packed_scene.hpp>
#include <godot_cpp/classes/node2d.hpp>
#include <godot_cpp/classes/texture_rect.hpp>
#include <godot_cpp/classes/shader_material.hpp>
#include <godot_cpp/classes/shader.hpp>
#include <godot_cpp/classes/color_rect.hpp>
#include <algorithm>
#include <thread>

void LuaManager::_add_bouncer_deferred(const String& syntax) {
    String s = syntax;
    Vector2 pos(0, 0);
    String image_path = "";
    String scene_path = "";
    String text = "";
    Color color(1, 1, 1, 1);
    Vector2 rect(0, 0);
    int layer_idx = 0;
    float font_size = 1.0;
    int hscore_idx = -1;
    int plasma_idx = -1;
    
    bool has_hover = false;
    Color hover_color;
    String clicked_script = "";

    int current_idx = 0;
    while (current_idx < s.length()) {
        int start = s.find("[", current_idx);
        if (start == -1) {
            text += s.substr(current_idx, s.length() - current_idx);
            break;
        }
        
        if (start > current_idx) {
            text += s.substr(current_idx, start - current_idx);
        }
        
        int end = s.find("]", start);
        if (end == -1) {
            text += s.substr(start, s.length() - start);
            break;
        }
        
        String tag = s.substr(start + 1, end - start - 1);
        
        if (tag.begins_with("pos:")) {
            PackedStringArray p = tag.substr(4).split(",");
            if (p.size() >= 2) pos = Vector2(p[0].to_float(), p[1].to_float());
        } else if (tag.begins_with("image:") || tag.begins_with("stencil:")) {
            int colon = tag.find(":");
            image_path = tag.substr(colon + 1).strip_edges();
        } else if (tag.begins_with("ttscn:")) {
            scene_path = tag.substr(6).strip_edges();
        } else if (tag.begins_with("rect:")) {
            PackedStringArray r = tag.substr(5).split(",");
            if (r.size() >= 2) rect = Vector2(r[0].to_float(), r[1].to_float());
        } else if (tag.begins_with("fontsize:")) {
            font_size = tag.substr(9).to_float();
        } else if (tag.begins_with("color:") || tag.begins_with("rgb:")) {
            PackedStringArray rgb = tag.substr(tag.begins_with("color:") ? 6 : 4).split(",");
            if (rgb.size() >= 3) color = Color(rgb[0].to_float() / 255.0f, rgb[1].to_float() / 255.0f, rgb[2].to_float() / 255.0f);
        } else if (tag.begins_with("layer:")) {
            layer_idx = tag.substr(6).to_int();
        } else if (tag.begins_with("hscore:")) {
            hscore_idx = tag.substr(7).to_int();
        } else if (tag.begins_with("plasma:")) {
            plasma_idx = tag.substr(7).to_int();
        } else if (tag.begins_with("hover:")) {
            PackedStringArray rgb = tag.substr(6).split(",");
            if (rgb.size() >= 3) {
                hover_color = Color(rgb[0].to_float() / 255.0f, rgb[1].to_float() / 255.0f, rgb[2].to_float() / 255.0f);
                has_hover = true;
            }
        } else if (tag.begins_with("clicked:")) {
            clicked_script = tag.substr(8);
        } else if (tag.begins_with("global:")) {
            String gname = tag.substr(7).strip_edges();
            if (lua_engine) {
                if (lua_engine->global_ints.count(gname.utf8().get_data())) {
                    text += String::num_int64(lua_engine->getGlobalInt(gname.utf8().get_data()));
                } else if (lua_engine->global_floats.count(gname.utf8().get_data())) {
                    text += String::num(lua_engine->getGlobalFloat(gname.utf8().get_data()));
                }
            }
        }
        
        current_idx = end + 1;
    }
    
    text = text.strip_edges();
    
    CanvasLayer* target_layer = nullptr;
    if (bouncer_layers.find(layer_idx) != bouncer_layers.end()) {
        uint64_t layer_id = bouncer_layers[layer_idx];
        Object* obj = ObjectDB::get_instance(layer_id);
        if (obj) {
            target_layer = Object::cast_to<CanvasLayer>(obj);
        }
    }
    
    if (!target_layer) {
        target_layer = memnew(CanvasLayer);
        target_layer->set_layer(layer_idx);
        add_child(target_layer);
        bouncer_layers[layer_idx] = target_layer->get_instance_id();
    }
    
    Node2D* container = memnew(Node2D);
    container->set_position(pos);
    container->set_modulate(color);
    
    if (hscore_idx >= 0 && hscore_idx < highscores.size()) {
        text = highscores[hscore_idx].name + " " + String::num_int64(highscores[hscore_idx].score);
    }
    
    Control* interactive_control = nullptr;
    
    if (!scene_path.is_empty()) {
        if (!scene_path.begins_with("res://")) scene_path = "res://" + scene_path;
        Ref<PackedScene> scn = ResourceLoader::get_singleton()->load(scene_path);
        if (scn.is_valid()) {
            Node* inst = scn->instantiate();
            container->add_child(inst);
        }
    }
    
    CanvasItem* visual_item = nullptr;
    
    if (!image_path.is_empty()) {
        if (!image_path.begins_with("res://") && !image_path.begins_with("user://")) image_path = "res://" + image_path;
        TextureRect* tex_rect = memnew(TextureRect);
        Ref<Texture2D> tex = ResourceLoader::get_singleton()->load(image_path);
        if (tex.is_valid()) {
            tex_rect->set_texture(tex);
            if (rect.x > 0 && rect.y > 0) {
                Vector2 tex_size = tex->get_size();
                if (tex_size.x > 0 && tex_size.y > 0) {
                    tex_rect->set_scale(Vector2(rect.x / tex_size.x, rect.y / tex_size.y));
                }
            }
        }
        container->add_child(tex_rect);
        interactive_control = tex_rect;
        visual_item = tex_rect;
    } else if (!text.is_empty()) {
        Label* label = memnew(Label);
        label->set_text(text);
        label->add_theme_font_size_override("font_size", MAX(1, (int)(64.0 * font_size)));
        container->add_child(label);
        interactive_control = label;
        visual_item = label;
        
        if (syntax.find("[global:") != -1) {
            DynamicLabel dl;
            dl.label_id = label->get_instance_id();
            dl.syntax = syntax;
            dynamic_labels.push_back(dl);
        }
    } else if (plasma_idx >= 0) {
        ColorRect* cr = memnew(ColorRect);
        if (rect.x > 0 && rect.y > 0) {
            cr->set_custom_minimum_size(rect);
            cr->set_size(rect);
        } else {
            cr->set_custom_minimum_size(Vector2(200, 200));
            cr->set_size(Vector2(200, 200));
        }
        container->add_child(cr);
        interactive_control = cr;
        visual_item = cr;
    }
    
    if (visual_item && plasma_idx >= 0) {
        Ref<Shader> shader = ResourceLoader::get_singleton()->load("res://plasma.gdshader");
        if (shader.is_valid()) {
            Ref<ShaderMaterial> mat;
            mat.instantiate();
            mat->set_shader(shader);
            mat->set_shader_parameter("idx", plasma_idx);
            visual_item->set_material(mat);
        }
    }
    
    if (interactive_control && (has_hover || !clicked_script.is_empty())) {
        interactive_control->set_mouse_filter(Control::MOUSE_FILTER_STOP);
        uint64_t ctrl_id = interactive_control->get_instance_id();
        
        InteractiveData idata;
        idata.normal_color = color;
        idata.hover_color = hover_color;
        idata.has_hover = has_hover;
        idata.clicked_script = clicked_script;
        idata.container_id = container->get_instance_id();
        interactive_bouncers[ctrl_id] = idata;
        
        interactive_control->connect("mouse_entered", Callable(this, "_on_bouncer_mouse_entered").bind(ctrl_id));
        interactive_control->connect("mouse_exited", Callable(this, "_on_bouncer_mouse_exited").bind(ctrl_id));
        interactive_control->connect("gui_input", Callable(this, "_on_bouncer_gui_input").bind(ctrl_id));
    }
    
    target_layer->add_child(container);
    bouncers.push_back(container->get_instance_id());
}

void LuaManager::_del_bouncer_deferred(int index) {
    if (index >= 0 && index < bouncers.size()) {
        uint64_t id = bouncers[index];
        Object* obj = ObjectDB::get_instance(id);
        if (obj) {
            Node* node = Object::cast_to<Node>(obj);
            if (node) {
                node->queue_free();
            }
        }
        bouncers.erase(bouncers.begin() + index);
    }
}

void LuaManager::_set_bouncer_param_deferred(int index, String name, double value) {
    if (index >= 0 && index < bouncers.size()) {
        uint64_t id = bouncers[index];
        Object* obj = ObjectDB::get_instance(id);
        if (obj) {
            Node2D* n2d = Object::cast_to<Node2D>(obj);
            Control* ctrl = Object::cast_to<Control>(obj);
            
            if (n2d) {
                if (name == "x") {
                    Vector2 pos = n2d->get_position();
                    pos.x = value;
                    n2d->set_position(pos);
                } else if (name == "y") {
                    Vector2 pos = n2d->get_position();
                    pos.y = value;
                    n2d->set_position(pos);
                } else if (name == "scale") {
                    n2d->set_scale(Vector2(value, value));
                } else if (name == "alpha") {
                    Color c = n2d->get_modulate();
                    c.a = value;
                    n2d->set_modulate(c);
                } else if (name == "rotation") {
                    n2d->set_rotation(value);
                }
            } else if (ctrl) {
                if (name == "x") {
                    Vector2 pos = ctrl->get_position();
                    pos.x = value;
                    ctrl->set_position(pos);
                } else if (name == "y") {
                    Vector2 pos = ctrl->get_position();
                    pos.y = value;
                    ctrl->set_position(pos);
                } else if (name == "scale") {
                    ctrl->set_scale(Vector2(value, value));
                } else if (name == "alpha") {
                    Color c = ctrl->get_modulate();
                    c.a = value;
                    ctrl->set_modulate(c);
                } else if (name == "rotation") {
                    ctrl->set_rotation(value);
                }
            }
        }
    }
}

void LuaManager::_set_bg_deferred(const String& syntax) {
    if (syntax.begins_with("[tscn:")) {
        int end = syntax.find("]");
        if (end != -1) {
            String scene_path = syntax.substr(6, end - 6);
            String full_path = "res://" + scene_path;
            UtilityFunctions::print("LuaManager loading scene: ", full_path);
            Error err = get_tree()->change_scene_to_file(full_path);
            if (err != OK) {
                UtilityFunctions::printerr("LuaManager failed to load scene: ", full_path, " Error code: ", err);
            }
        }
    } else if (syntax.ends_with(".png") || syntax.ends_with(".jpg")) {
        CanvasLayer* bg_layer = nullptr;
        if (bg_layer_id != 0) {
            Object* obj = ObjectDB::get_instance(bg_layer_id);
            if (obj) bg_layer = Object::cast_to<CanvasLayer>(obj);
        }
        
        if (!bg_layer) {
            bg_layer = memnew(CanvasLayer);
            bg_layer->set_layer(-100);
            add_child(bg_layer);
            bg_layer_id = bg_layer->get_instance_id();
        }
        
        TextureRect* bg_rect = nullptr;
        if (bg_rect_id != 0) {
            Object* obj = ObjectDB::get_instance(bg_rect_id);
            if (obj) bg_rect = Object::cast_to<TextureRect>(obj);
        }
        
        if (!bg_rect) {
            if (bg_rect_id != 0) {
                Object* obj = ObjectDB::get_instance(bg_rect_id);
                if (obj) Object::cast_to<Node>(obj)->queue_free();
            }
            bg_rect = memnew(TextureRect);
            bg_rect->set_anchors_preset(Control::PRESET_FULL_RECT);
            bg_rect->set_expand_mode(TextureRect::EXPAND_IGNORE_SIZE);
            bg_rect->set_stretch_mode(TextureRect::STRETCH_KEEP_ASPECT_COVERED);
            bg_layer->add_child(bg_rect);
            bg_rect_id = bg_rect->get_instance_id();
        }
        
        Ref<Texture2D> tex = ResourceLoader::get_singleton()->load("res://" + syntax);
        if (tex.is_valid()) {
            bg_rect->set_texture(tex);
            bg_rect->set_material(Ref<Material>());
        } else {
            UtilityFunctions::printerr("Failed to load background image: res://", syntax);
        }
    } else if (syntax.begins_with("[plasma:")) {
        int end = syntax.find("]");
        if (end != -1) {
            int plasma_idx = syntax.substr(8, end - 8).to_int();
            
            CanvasLayer* bg_layer = nullptr;
            if (bg_layer_id != 0) {
                Object* obj = ObjectDB::get_instance(bg_layer_id);
                if (obj) bg_layer = Object::cast_to<CanvasLayer>(obj);
            }
            if (!bg_layer) {
                bg_layer = memnew(CanvasLayer);
                bg_layer->set_layer(-100);
                add_child(bg_layer);
                bg_layer_id = bg_layer->get_instance_id();
            }
            
            ColorRect* bg_rect = nullptr;
            if (bg_rect_id != 0) {
                Object* obj = ObjectDB::get_instance(bg_rect_id);
                if (obj) bg_rect = Object::cast_to<ColorRect>(obj);
            }
            
            if (!bg_rect) {
                if (bg_rect_id != 0) {
                    Object* obj = ObjectDB::get_instance(bg_rect_id);
                    if (obj) Object::cast_to<Node>(obj)->queue_free();
                }
                bg_rect = memnew(ColorRect);
                bg_rect->set_anchors_preset(Control::PRESET_FULL_RECT);
                bg_layer->add_child(bg_rect);
                bg_rect_id = bg_rect->get_instance_id();
            }
            
            if (plasma_idx >= 0) {
                Ref<Shader> shader = ResourceLoader::get_singleton()->load("res://plasma.gdshader");
                if (shader.is_valid()) {
                    Ref<ShaderMaterial> mat;
                    mat.instantiate();
                    mat->set_shader(shader);
                    mat->set_shader_parameter("idx", plasma_idx);
                    bg_rect->set_material(mat);
                }
            } else {
                bg_rect->set_material(Ref<Material>());
            }
        }
    }
}

void LuaManager::_clear_and_run_deferred(const String& filename) {
    for (uint64_t id : bouncers) {
        Object* obj = ObjectDB::get_instance(id);
        if (obj) {
            Node* node = Object::cast_to<Node>(obj);
            if (node) node->queue_free();
        }
    }
    bouncers.clear();
    
    for (auto const& [idx, layer_id] : bouncer_layers) {
        Object* obj = ObjectDB::get_instance(layer_id);
        if (obj) {
            Node* node = Object::cast_to<Node>(obj);
            if (node) node->queue_free();
        }
    }
    bouncer_layers.clear();
    interactive_bouncers.clear();
    
    if (bg_layer_id != 0) {
        Object* obj = ObjectDB::get_instance(bg_layer_id);
        if (obj) {
            Node* node = Object::cast_to<Node>(obj);
            if (node) node->queue_free();
        }
        bg_layer_id = 0;
        bg_rect_id = 0;
    }
    
    if (lua_engine) {
        lua_engine->stop();
    }
    
    run_script(filename);
}

void LuaManager::_play_audio_deferred(const String& filename) {
    if (filename.begins_with("ytdlp://")) {
        String url = filename.substr(8);
        String temp_file = "user://yt_temp.mp3";
        String global_path = ProjectSettings::get_singleton()->globalize_path(temp_file);
        
        UtilityFunctions::print("Starting ytdlp download for: ", url);
        
        PackedStringArray args;
        args.push_back("-x");
        args.push_back("--audio-format");
        args.push_back("mp3");
        args.push_back("-o");
        args.push_back(global_path);
        args.push_back("--force-overwrites");
        args.push_back(url);
        
        Array out;
        int32_t ret = OS::get_singleton()->execute("yt-dlp", args, out, false, true);
        if (ret == 0) {
            this->call_deferred("_play_audio_dynamic_deferred", temp_file);
        } else {
            UtilityFunctions::printerr("ytdlp failed for url: ", url, " code: ", ret);
        }
        return;
    }
    
    _play_audio_dynamic_deferred(filename);
}

void LuaManager::_play_audio_dynamic_deferred(const String& filename) {
    AudioStreamPlayer* player = nullptr;
    if (audio_player_id != 0) {
        Object* obj = ObjectDB::get_instance(audio_player_id);
        if (obj) player = Object::cast_to<AudioStreamPlayer>(obj);
    }
    
    if (!player) {
        player = memnew(AudioStreamPlayer);
        add_child(player);
        audio_player_id = player->get_instance_id();
    }
    
    Ref<AudioStream> stream;
    String p = filename;
    if (!p.begins_with("res://") && !p.begins_with("user://")) {
        p = "res://" + p;
    }
    
    if (p.ends_with(".mp3")) {
        stream = AudioStreamMP3::load_from_file(p);
    } else if (p.ends_with(".wav")) {
        stream = AudioStreamWAV::load_from_file(p);
    } else if (p.ends_with(".ogg")) {
        stream = AudioStreamOggVorbis::load_from_file(p);
    } else {
        stream = ResourceLoader::get_singleton()->load(p);
    }
    
    if (stream.is_valid()) {
        player->set_stream(stream);
        player->play();
    } else {
        UtilityFunctions::printerr("Failed to load dynamic audio: ", p);
    }
}

void LuaManager::_set_audio_volume_deferred(int vol) {
    if (audio_player_id != 0) {
        if (Object* obj = ObjectDB::get_instance(audio_player_id)) {
            if (AudioStreamPlayer* player = Object::cast_to<AudioStreamPlayer>(obj)) {
                float linear = (float)vol / 100.0f;
                player->set_volume_db(Math::linear_to_db(linear));
            }
        }
    }
}

void LuaManager::_rewind_audio_deferred() {
    if (audio_player_id != 0) {
        if (Object* obj = ObjectDB::get_instance(audio_player_id)) {
            if (AudioStreamPlayer* player = Object::cast_to<AudioStreamPlayer>(obj)) {
                player->seek(0.0);
            }
        }
    }
}

void LuaManager::_skip_audio_deferred(int amount) {
    if (audio_player_id != 0) {
        if (Object* obj = ObjectDB::get_instance(audio_player_id)) {
            if (AudioStreamPlayer* player = Object::cast_to<AudioStreamPlayer>(obj)) {
                float pos = player->get_playback_position();
                player->seek(pos + (float)amount);
            }
        }
    }
}

void LuaManager::_set_resize_enabled_deferred(bool enabled) {
    DisplayServer::get_singleton()->window_set_flag(DisplayServer::WINDOW_FLAG_RESIZE_DISABLED, !enabled);
}

void LuaManager::_maximize_window_deferred() {
    DisplayServer::get_singleton()->window_set_mode(DisplayServer::WINDOW_MODE_MAXIMIZED);
}

void LuaManager::_ready() {
    UtilityFunctions::print("LuaManager is ready!");
    
    // Sync ImGui context from imgui-godot GDExtension
    godot::Object* imgui_gd = godot::Engine::get_singleton()->get_singleton("ImGuiGD");
    if (imgui_gd) {
        godot::PackedInt64Array ptrs = imgui_gd->call("GetImGuiPtrs", ImGui::GetVersion(), (int)sizeof(ImGuiIO), (int)sizeof(ImDrawVert), (int)sizeof(ImDrawIdx), (int)sizeof(ImWchar));
        if (ptrs.size() >= 3) {
            ImGui::SetCurrentContext((ImGuiContext*)ptrs[0]);
            ImGui::SetAllocatorFunctions((ImGuiMemAllocFunc)ptrs[1], (ImGuiMemFreeFunc)ptrs[2]);
            godot::UtilityFunctions::print("LuaManager successfully synced ImGui context!");
        } else {
            godot::UtilityFunctions::printerr("LuaManager failed to sync ImGui context: GetImGuiPtrs returned invalid array");
        }
    } else {
        godot::UtilityFunctions::printerr("LuaManager failed to sync ImGui context: ImGuiGD singleton not found");
    }

    // Initialize LuaScripting with stubs
    lua_engine = new LuaScripting(
        // addFunc
        [this](const std::string& syntax) {
            this->call_deferred("_add_bouncer_deferred", String(syntax.c_str()));
        },
        // delFunc
        [this](int index) {
            this->call_deferred("_del_bouncer_deferred", index);
        },
        // setBGFunc
        [this](const std::string& syntax) {
            this->call_deferred("_set_bg_deferred", String(syntax.c_str()));
        },
        // selectFunc
        [](bool, int, std::shared_ptr<LuaSyncData> sd) {
            UtilityFunctions::print("Stub: selectFunc");
            if (sd) { std::unique_lock<std::mutex> lock(sd->mtx); sd->done = true; sd->cv.notify_one(); }
        },
        // setParamFunc
        [](bool, const std::string&, double) { UtilityFunctions::print("Stub: setParamFunc"); },
        // setBouncerParamFunc
        [this](int index, const std::string& name, double val) {
            this->call_deferred("_set_bouncer_param_deferred", index, String(name.c_str()), val);
        },
        // randomizeFunc
        [](bool, bool) { UtilityFunctions::print("Stub: randomizeFunc"); },
        // setAudioFunc
        [this](const std::string& filename, std::shared_ptr<LuaSyncData> sd) {
            this->_play_audio_deferred(String(filename.c_str()));
            if (sd) { std::unique_lock<std::mutex> lock(sd->mtx); sd->done = true; sd->cv.notify_one(); }
        },
        // playAudioFunc
        []() { UtilityFunctions::print("Stub: playAudioFunc"); },
        // stopAudioFunc
        []() { UtilityFunctions::print("Stub: stopAudioFunc"); },
        // rewindAudioFunc
        [this]() { this->call_deferred("_rewind_audio_deferred"); },
        // skipAudioFunc
        [this](int amount) { this->call_deferred("_skip_audio_deferred", amount); },
        // setAudioVolumeFunc
        [this](int vol) { this->call_deferred("_set_audio_volume_deferred", vol); },
        // recordFunc
        [](int, const std::string&, int) { UtilityFunctions::print("Stub: recordFunc"); },
        // isRecFunc
        []() { return false; },
#ifdef USE_USD
        // selectUSDFunc
        [](int, std::shared_ptr<LuaSyncData> sd) {
            UtilityFunctions::print("Stub: selectUSDFunc");
            if (sd) { std::unique_lock<std::mutex> lock(sd->mtx); sd->done = true; sd->cv.notify_one(); }
        },
        // setUSDParamFunc
        [](const std::string&, double) { UtilityFunctions::print("Stub: setUSDParamFunc"); },
#endif
        // selectGodotFunc
        [this](int, std::shared_ptr<LuaSyncData> sd, void* target, LuaScripting*) {
            if (sd) {
                std::lock_guard<std::mutex> lock(this->cmd_mutex);
                GodotCommand cmd;
                cmd.cmd = LuaScripting::GCMD_SELECT_ROOT; // Assuming selectGodotFunc wants root
                cmd.sd = sd;
                this->cmd_queue.push_back(cmd);
            }
        },
        // godotCmdFunc
        [this](LuaScripting::GodotCmd cmd, const std::string& name, float args[3], std::shared_ptr<LuaSyncData> sd, void* thread, LuaScripting*) {
            if (sd) {
                std::lock_guard<std::mutex> lock(this->cmd_mutex);
                GodotCommand gcmd;
                gcmd.cmd = cmd;
                gcmd.name = String(name.c_str());
                gcmd.args[0] = args[0]; gcmd.args[1] = args[1]; gcmd.args[2] = args[2];
                gcmd.object_id = sd->object_id_arg;
                gcmd.sd = sd;
                this->cmd_queue.push_back(gcmd);
            }
        },
        // quitFunc
        [this](std::shared_ptr<LuaSyncData> sd) {
            this->call_deferred("_quit_deferred");
            if (sd) { std::unique_lock<std::mutex> lock(sd->mtx); sd->done = true; sd->cv.notify_one(); }
        },
        // setImGuiVisibleFunc
        [](bool) { UtilityFunctions::print("Stub: setImGuiVisibleFunc"); },
        // clearAndRunFunc
        [this](const std::string& filename, std::shared_ptr<LuaSyncData> sd) {
            this->call_deferred("_clear_and_run_deferred", String(filename.c_str()));
            if (sd) { std::unique_lock<std::mutex> lock(sd->mtx); sd->done = true; sd->cv.notify_one(); }
        },
        // setMouseCaptureFunc
        [](bool capture) {
            if (capture) {
                godot::Input::get_singleton()->set_mouse_mode(godot::Input::MOUSE_MODE_CAPTURED);
            } else {
                godot::Input::get_singleton()->set_mouse_mode(godot::Input::MOUSE_MODE_VISIBLE);
            }
        },
        // setResizeEnabledFunc
        [this](bool enabled) { this->call_deferred("_set_resize_enabled_deferred", enabled); },
        // maximizeWindowFunc
        [this]() { this->call_deferred("_maximize_window_deferred"); },
        // checkHSFunc
        [this](int score) {
            if (this->highscores.size() < 10) return true;
            return score > this->highscores.back().score;
        },
        // addHSFunc
        [this](const std::string& name, int score, int level) {
            this->highscores.push_back({String(name.c_str()), score, level});
            std::sort(this->highscores.begin(), this->highscores.end(), [](const HighScoreEntry& a, const HighScoreEntry& b) {
                return a.score > b.score;
            });
            if (this->highscores.size() > 10) {
                this->highscores.resize(10);
            }
        },
        // loadHSFunc
        [this]() {
            Ref<FileAccess> file = FileAccess::open("user://highscore.dat", FileAccess::READ);
            if (file.is_valid()) {
                this->highscores.clear();
                while (!file->eof_reached()) {
                    String line = file->get_line();
                    if (!line.is_empty()) {
                        PackedStringArray parts = line.split(",");
                        if (parts.size() >= 3) {
                            this->highscores.push_back({parts[0], (int)parts[1].to_int(), (int)parts[2].to_int()});
                        }
                    }
                }
            }
        },
        // saveHSFunc
        [this]() {
            Ref<FileAccess> file = FileAccess::open("user://highscore.dat", FileAccess::WRITE);
            if (file.is_valid()) {
                for (const auto& hs : this->highscores) {
                    file->store_line(hs.name + String(",") + String::num_int64(hs.score) + String(",") + String::num_int64(hs.level));
                }
            }
        }
    );
    
    // Start script if init.lua exists
    if (godot::FileAccess::file_exists("res://init.lua")) {
        lua_engine->runScript("init.lua");
    }
}

void LuaManager::_input(const Ref<InputEvent>& event) {
    if (lua_engine) {
        InputEventMouseMotion* motion = Object::cast_to<InputEventMouseMotion>(event.ptr());
        if (motion) {
            Vector2 rel = motion->get_relative();
            lua_engine->setMouseMotion(rel.x, rel.y);
        }
    }
}

void LuaManager::run_script(const String& filename) {
    if (lua_engine) {
        std::string cpp_filename = filename.utf8().get_data();
        lua_engine->runScript(cpp_filename);
    } else {
        UtilityFunctions::printerr("LuaManager: Cannot run script, lua_engine is not initialized.");
    }
}

void LuaManager::_process(double delta) {
    // Process Godot Command Queue
    std::vector<GodotCommand> current_queue;
    {
        std::lock_guard<std::mutex> lock(cmd_mutex);
        current_queue = cmd_queue;
        cmd_queue.clear();
    }
    
    for (const auto& cmd : current_queue) {
        if (!cmd.sd) continue;
        
        switch (cmd.cmd) {
            case LuaScripting::GCMD_LOAD_SCENE: {
                String full_path = "res://" + cmd.name;
                UtilityFunctions::print("LuaManager loading scene natively: ", full_path);
                Error err = get_tree()->change_scene_to_file(full_path);
                if (err != OK) {
                    UtilityFunctions::printerr("LuaManager failed to load scene: ", full_path, " Error code: ", err);
                }
                break;
            }
            case LuaScripting::GCMD_SELECT_ROOT: {
                cmd.sd->object_id_res = get_tree()->get_root()->get_instance_id();
                break;
            }
            case LuaScripting::GCMD_GET_NODE_POINTER: {
                Node* root = get_tree()->get_root();
                Node* found = root->find_child(cmd.name, true, false);
                if (found) {
                    cmd.sd->object_id_res = found->get_instance_id();
                } else {
                    cmd.sd->object_id_res = 0;
                }
                break;
            }
            case LuaScripting::GCMD_GET_CHILD_COUNT: {
                if (cmd.object_id != 0) {
                    Object* obj = ObjectDB::get_instance(cmd.object_id);
                    if (Node* node = Object::cast_to<Node>(obj)) {
                        cmd.sd->d_res = (double)node->get_child_count();
                        cmd.sd->res_type = 1;
                    }
                }
                break;
            }
            case LuaScripting::GCMD_LOAD_NODE: {
                String path = cmd.name;
                if (!path.begins_with("res://")) path = "res://" + path;
                Ref<PackedScene> scn = ResourceLoader::get_singleton()->load(path);
                if (scn.is_valid()) {
                    Node* inst = scn->instantiate();
                    if (cmd.object_id != 0) {
                        Object* parent_obj = ObjectDB::get_instance(cmd.object_id);
                        if (Node* parent_node = Object::cast_to<Node>(parent_obj)) {
                            parent_node->add_child(inst);
                        } else {
                            get_tree()->get_root()->add_child(inst);
                        }
                    } else {
                        get_tree()->get_root()->add_child(inst);
                    }
                    if (cmd.sd->b_res) {
                        if (Node2D* n2d = Object::cast_to<Node2D>(inst)) {
                            n2d->set_position(Vector2(cmd.args[0], cmd.args[1]));
                        } else if (Node3D* n3d = Object::cast_to<Node3D>(inst)) {
                            n3d->set_position(Vector3(cmd.args[0], cmd.args[1], cmd.args[2]));
                        }
                    }
                    cmd.sd->object_id_res = inst->get_instance_id();
                    cmd.sd->b_res = true;
                } else {
                    cmd.sd->b_res = false;
                }
                break;
            }
            case LuaScripting::GCMD_SET_PROPERTY: {
                Object* target = ObjectDB::get_instance(cmd.object_id);
                if (target) {
                    target->set(cmd.name, cmd.args[0]);
                }
                break;
            }
            case LuaScripting::GCMD_GET_PROPERTY: {
                Object* target = ObjectDB::get_instance(cmd.object_id);
                if (target) {
                    Variant val = target->get(cmd.name);
                    if (val.get_type() == Variant::FLOAT || val.get_type() == Variant::INT) {
                        cmd.sd->d_res = (double)val;
                        cmd.sd->res_type = 1;
                    } else if (val.get_type() == Variant::BOOL) {
                        cmd.sd->b_res = (bool)val;
                        cmd.sd->res_type = 2;
                    } else if (val.get_type() == Variant::STRING) {
                        String s = val;
                        cmd.sd->s_res = s.utf8().get_data();
                        cmd.sd->res_type = 3;
                    }
                }
                break;
            }
            case LuaScripting::GCMD_GET_POS: {
                if (cmd.object_id != 0) {
                    Object* obj = ObjectDB::get_instance(cmd.object_id);
                    if (Node2D* n2d = Object::cast_to<Node2D>(obj)) {
                        Vector2 pos = n2d->get_position();
                        cmd.sd->f_res[0] = pos.x; cmd.sd->f_res[1] = pos.y; cmd.sd->f_res[2] = 0;
                    } else if (Control* ctrl = Object::cast_to<Control>(obj)) {
                        Vector2 pos = ctrl->get_position();
                        cmd.sd->f_res[0] = pos.x; cmd.sd->f_res[1] = pos.y; cmd.sd->f_res[2] = 0;
                    } else if (Node3D* n3d = Object::cast_to<Node3D>(obj)) {
                        Vector3 pos = n3d->get_position();
                        cmd.sd->f_res[0] = pos.x; cmd.sd->f_res[1] = pos.y; cmd.sd->f_res[2] = pos.z;
                    } else {
                        cmd.sd->f_res[0] = 0; cmd.sd->f_res[1] = 0; cmd.sd->f_res[2] = 0;
                    }
                } else {
                    cmd.sd->f_res[0] = 0; cmd.sd->f_res[1] = 0; cmd.sd->f_res[2] = 0;
                }
                break;
            }
            case LuaScripting::GCMD_SET_POS: {
                if (cmd.object_id != 0) {
                    Object* obj = ObjectDB::get_instance(cmd.object_id);
                    if (Node2D* n2d = Object::cast_to<Node2D>(obj)) {
                        n2d->set_position(Vector2(cmd.args[0], cmd.args[1]));
                    } else if (Control* ctrl = Object::cast_to<Control>(obj)) {
                        ctrl->set_position(Vector2(cmd.args[0], cmd.args[1]));
                    } else if (Node3D* n3d = Object::cast_to<Node3D>(obj)) {
                        n3d->set_position(Vector3(cmd.args[0], cmd.args[1], cmd.args[2]));
                    }
                }
                break;
            }
            case LuaScripting::GCMD_WATCH_SIGNAL: {
                if (cmd.object_id != 0) {
                    Object* obj = ObjectDB::get_instance(cmd.object_id);
                    if (obj) {
                        String signal_name = cmd.name.get_slice("|", 0);
                        String func_name = cmd.name.get_slice("|", 1);
                        obj->connect(signal_name, Callable(this, "_on_dynamic_signal").bind(func_name));
                    }
                }
                break;
            }
            default:
                UtilityFunctions::print("Warning: Unimplemented Godot command: ", cmd.cmd);
                break;
        }
        
        // Signal Lua thread that command is done
        {
            std::unique_lock<std::mutex> lock(cmd.sd->mtx);
            cmd.sd->done = true;
            cmd.sd->cv.notify_one();
        }
    }

    if (!ImGui::GetCurrentContext()) return;
    
    if (lua_engine) {
        lua_engine->renderLuaImGui();
    }

    for (auto it = dynamic_labels.begin(); it != dynamic_labels.end(); ) {
        Object* obj = ObjectDB::get_instance(it->label_id);
        if (!obj) {
            it = dynamic_labels.erase(it);
        } else {
            Label* label = Object::cast_to<Label>(obj);
            if (label) {
                label->set_text(_evaluate_bouncer_text(it->syntax));
            }
            ++it;
        }
    }
}

void LuaManager::set_global_int(const String& name, int val) {
    if (lua_engine) {
        lua_engine->setGlobalInt(name.utf8().get_data(), val);
    }
}

int LuaManager::get_global_int(const String& name) {
    if (lua_engine) {
        return lua_engine->getGlobalInt(name.utf8().get_data());
    }
    return 0;
}

void LuaManager::set_global_float(const String& name, float val) {
    if (lua_engine) {
        lua_engine->setGlobalFloat(name.utf8().get_data(), val);
    }
}

float LuaManager::get_global_float(const String& name) {
    if (lua_engine) {
        return lua_engine->getGlobalFloat(name.utf8().get_data());
    }
    return 0.0f;
}
