#include <godot_cpp/classes/audio_stream_player.hpp>
#include <godot_cpp/classes/audio_stream_wav.hpp>
#include <godot_cpp/classes/input_event_key.hpp>
#include <algorithm>
#include <godot_cpp/classes/rich_text_label.hpp>
#include <godot_cpp/classes/font.hpp>
#include <godot_cpp/classes/font_variation.hpp>
#include <godot_cpp/classes/text_server_manager.hpp>
#include <godot_cpp/classes/text_server.hpp>
#include <godot_cpp/classes/h_box_container.hpp>
#include <godot_cpp/classes/panel_container.hpp>
#include <godot_cpp/classes/style_box_flat.hpp>
#include <godot_cpp/classes/grid_container.hpp>
#include <godot_cpp/classes/os.hpp>
#include <godot_cpp/classes/dir_access.hpp>
#include <algorithm>
#include <godot_cpp/classes/line_edit.hpp>
#include <godot_cpp/classes/v_box_container.hpp>
#include <godot_cpp/classes/viewport.hpp>
#include <godot_cpp/classes/sub_viewport.hpp>
#include <godot_cpp/classes/sub_viewport_container.hpp>
#include <godot_cpp/classes/viewport_texture.hpp>
#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/classes/node3d.hpp>
#include <godot_cpp/classes/display_server.hpp>
#include "lua_manager.h"
#include <filesystem>
#include <godot_cpp/classes/panel_container.hpp>
#include <godot_cpp/classes/style_box_flat.hpp>
#include <godot_cpp/classes/h_box_container.hpp>
#include <godot_cpp/classes/texture2d.hpp>
#include <godot_cpp/classes/image_texture.hpp>
#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/classes/video_stream.hpp>
#include <godot_cpp/classes/resource_loader.hpp>
#include <godot_cpp/classes/scene_tree.hpp>

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/sprite2d.hpp>
#include <godot_cpp/classes/texture2d.hpp>
#include <godot_cpp/classes/image_texture.hpp>
#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/classes/resource_loader.hpp>
#include <godot_cpp/classes/input_event_mouse_motion.hpp>
#include <godot_cpp/classes/input.hpp>
#include <godot_cpp/classes/scene_tree.hpp>
#include <godot_cpp/classes/window.hpp>
#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/input_event_mouse_button.hpp>
#include <godot_cpp/classes/audio_server.hpp>
#include <godot_cpp/classes/video_stream_player.hpp>
#include <godot_cpp/classes/video_stream.hpp>
#include <godot_cpp/classes/script.hpp>
#include <imgui.h>

using namespace godot;

void LuaManager::_play_ui_sound(const String& path) {
    AudioStreamPlayer* player = nullptr;
    if (ui_audio_player_id != 0) {
        Object* obj = ObjectDB::get_instance(ui_audio_player_id);
        if (obj) player = Object::cast_to<AudioStreamPlayer>(obj);
    }
    if (!player) {
        player = memnew(AudioStreamPlayer);
        add_child(player);
        ui_audio_player_id = player->get_instance_id();
    }
    Ref<AudioStream> stream = AudioStreamWAV::load_from_file(path);
    if (stream.is_valid()) {
        player->set_stream(stream);
        player->play();
    }
}

void LuaManager::_set_bouncer_hover(uint64_t control_id, bool is_hovered) {
    if (interactive_bouncers.find(control_id) != interactive_bouncers.end()) {
        InteractiveData& idata = interactive_bouncers[control_id];
        if (idata.is_graffity && idata.label_id != 0) {
            RichTextLabel* rtl = Object::cast_to<RichTextLabel>(ObjectDB::get_instance(idata.label_id));
            if (rtl) {
                rtl->add_theme_color_override("font_outline_color", is_hovered ? idata.graffity_hover : idata.graffity_outer);
            }
        }
        if (idata.has_hover) {
            Node2D* container = Object::cast_to<Node2D>(ObjectDB::get_instance(idata.container_id));
            if (container) {
                container->set_modulate(is_hovered ? idata.hover_color : idata.normal_color);
                std::vector<VideoStreamPlayer*> vps;
                for (int i = 0; i < container->get_child_count(); ++i) {
                    Node* child = container->get_child(i);
                    if (VideoStreamPlayer* vp = Object::cast_to<VideoStreamPlayer>(child)) vps.push_back(vp);
                    for (int j = 0; j < child->get_child_count(); ++j) {
                        Node* child2 = child->get_child(j);
                        if (VideoStreamPlayer* vp = Object::cast_to<VideoStreamPlayer>(child2)) vps.push_back(vp);
                        for (int k = 0; k < child2->get_child_count(); ++k) {
                            Node* child3 = child2->get_child(k);
                            if (VideoStreamPlayer* vp = Object::cast_to<VideoStreamPlayer>(child3)) vps.push_back(vp);
                        }
                    }
                }
                for (VideoStreamPlayer* vp : vps) {
                    if (is_hovered) {
                        vp->set_paused(false);
                        vp->play();
                        vp->set_volume_db(0.0f);
                    } else {
                        vp->set_paused(true);
                        vp->set_volume_db(-80.0f);
                    }
                }
            }
        }
    }
}

void LuaManager::_on_bouncer_mouse_entered(uint64_t control_id) {
    _play_ui_sound("res://menu_click.wav");
    
    bool is_main_menu_item = false;
    if (main_menu_index >= 0 && main_menu_index < (int)menus.size()) {
        MenuData& mm = menus[main_menu_index];
        for (int r = 0; r < mm.rows.size(); r++) {
            for (int c = 0; c < mm.rows[r].items.size(); c++) {
                if (mm.rows[r].items[c] == control_id) {
                    is_main_menu_item = true;
                    if (active_menu_index == main_menu_index) {
                        if (mm.selected_row >= 0 && mm.selected_row < mm.rows.size()) {
                            MenuRow& old_r = mm.rows[mm.selected_row];
                            if (old_r.selected_col >= 0 && old_r.selected_col < old_r.items.size()) {
                                uint64_t old_id = old_r.items[old_r.selected_col];
                                if (old_id != control_id) {
                                    _set_bouncer_hover(old_id, false);
                                }
                            }
                        }
                        mm.selected_row = r;
                        mm.rows[r].selected_col = c;
                    }
                    break;
                }
            }
        }
    }
    
    if (active_menu_index >= 0 && active_menu_index < (int)menus.size()) {
        MenuData& m = menus[active_menu_index];
        for (int r = 0; r < m.rows.size(); r++) {
            for (int c = 0; c < m.rows[r].items.size(); c++) {
                if (m.rows[r].items[c] == control_id) {
                    if (m.selected_row >= 0 && m.selected_row < m.rows.size()) {
                        MenuRow& old_r = m.rows[m.selected_row];
                        if (old_r.selected_col >= 0 && old_r.selected_col < old_r.items.size()) {
                            uint64_t old_id = old_r.items[old_r.selected_col];
                            if (old_id != control_id) {
                                _set_bouncer_hover(old_id, false);
                            }
                        }
                    }
                    m.selected_row = r;
                    m.rows[r].selected_col = c;
                    break;
                }
            }
        }
    }
    
    _set_bouncer_hover(control_id, true);
}

void LuaManager::_on_bouncer_mouse_exited(uint64_t control_id) {
    bool is_selected = false;
    for (int m_idx = 0; m_idx < (int)menus.size(); m_idx++) {
        MenuData& m = menus[m_idx];
        if (m.selected_row >= 0 && m.selected_row < m.rows.size()) {
            MenuRow& r = m.rows[m.selected_row];
            if (r.selected_col >= 0 && r.selected_col < r.items.size()) {
                if (r.items[r.selected_col] == control_id) {
                    is_selected = true;
                    break;
                }
            }
        }
    }
    
    if (!is_selected) {
        _set_bouncer_hover(control_id, false);
    }
}

void LuaManager::_on_bouncer_gui_input(const Ref<InputEvent>& event, uint64_t control_id) {
    if (interactive_bouncers.find(control_id) != interactive_bouncers.end()) {
        InteractiveData& idata = interactive_bouncers[control_id];
        Ref<InputEventMouseButton> mb = event;
        if (mb.is_valid() && mb->is_pressed() && mb->get_button_index() == MouseButton::MOUSE_BUTTON_LEFT) {
            
            bool is_main_menu_item = false;
            if (main_menu_index >= 0 && main_menu_index < (int)menus.size()) {
                MenuData& mm = menus[main_menu_index];
                for (int r = 0; r < mm.rows.size(); r++) {
                    for (int c = 0; c < mm.rows[r].items.size(); c++) {
                        if (mm.rows[r].items[c] == control_id) {
                            is_main_menu_item = true;
                            
                            for (auto& pair : submenus) {
                                if (pair.second.is_active) {
                                    _disable_submenu_deferred(pair.first);
                                }
                            }
                            
                            if (mm.selected_row >= 0 && mm.selected_row < mm.rows.size()) {
                                MenuRow& old_r = mm.rows[mm.selected_row];
                                if (old_r.selected_col >= 0 && old_r.selected_col < old_r.items.size()) {
                                    uint64_t old_id = old_r.items[old_r.selected_col];
                                    if (old_id != control_id) {
                                        _set_bouncer_hover(old_id, false);
                                    }
                                }
                            }
                            
                            mm.selected_row = r;
                            mm.rows[r].selected_col = c;
                            break;
                        }
                    }
                    if (is_main_menu_item) break;
                }
            }

            if (!idata.clicked_script.is_empty()) {
                if (idata.clicked_script.ends_with(".lua")) {
                    call_deferred("_clear_and_run_deferred", idata.clicked_script);
                } else {
                    if (lua_engine) {
                        lua_engine->triggerCallback(idata.clicked_script.utf8().get_data());
                    }
                }
            }
        }
    }
}

String LuaManager::_evaluate_bouncer_text(const String& syntax) {
    String s = syntax;
    String text = "";
    bool has_hover = syntax.find("[hover:") != -1;
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
        } else if (tag.begins_with("color:") || tag.begins_with("rgb:")) {
            if (!has_hover) {
                PackedStringArray rgb = tag.substr(tag.begins_with("color:") ? 6 : 4).split(",");
                if (rgb.size() >= 3) {
                    Color c = Color(rgb[0].to_float() / 255.0f, rgb[1].to_float() / 255.0f, rgb[2].to_float() / 255.0f);
                    text += "[color=#" + c.to_html(false) + "]";
                }
            }
        } else if (tag == "lf") {
            text += "\n";
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

float LuaManager::get_loading_progress() {
    if (!pending_scene_load.is_empty()) {
        Array progress;
        ResourceLoader::ThreadLoadStatus status = ResourceLoader::get_singleton()->load_threaded_get_status(pending_scene_load, progress);
        if ((status == ResourceLoader::THREAD_LOAD_IN_PROGRESS || status == ResourceLoader::THREAD_LOAD_LOADED) && progress.size() > 0) {
            return (float)progress[0];
        }
    }
    return 0.0f;
}

void LuaManager::finish_gdscript_load() {
    if (pending_scene_sd) {
        std::unique_lock<std::mutex> lock(pending_scene_sd->mtx);
        pending_scene_sd->done = true;
        pending_scene_sd->cv.notify_one();
        pending_scene_sd = nullptr;
    }
}

void LuaManager::_bind_methods() {
    ClassDB::bind_method(D_METHOD("_on_bouncer_mouse_entered", "control_id"), &LuaManager::_on_bouncer_mouse_entered);
    ClassDB::bind_method(D_METHOD("_on_bouncer_mouse_exited", "control_id"), &LuaManager::_on_bouncer_mouse_exited);
    ClassDB::bind_method(D_METHOD("_on_bouncer_gui_input", "event", "control_id"), &LuaManager::_on_bouncer_gui_input);
    ClassDB::bind_method(D_METHOD("_on_addhscore_submitted", "text", "score", "level", "bouncer_id"), &LuaManager::_on_addhscore_submitted);
    ClassDB::bind_method(D_METHOD("_begin_menu_deferred", "name", "rows"), &LuaManager::_begin_menu_deferred);
    ClassDB::bind_method(D_METHOD("_begin_row_deferred", "name", "row"), &LuaManager::_begin_row_deferred);
    ClassDB::bind_method(D_METHOD("_end_row_deferred", "name"), &LuaManager::_end_row_deferred);
    ClassDB::bind_method(D_METHOD("_end_menu_deferred"), &LuaManager::_end_menu_deferred);
    ClassDB::bind_method(D_METHOD("_create_submenu_deferred", "handle"), &LuaManager::_create_submenu_deferred);
    ClassDB::bind_method(D_METHOD("_begin_submenu_deferred", "handle"), &LuaManager::_begin_submenu_deferred);
    ClassDB::bind_method(D_METHOD("_end_submenu_deferred", "handle"), &LuaManager::_end_submenu_deferred);
    ClassDB::bind_method(D_METHOD("_enable_submenu_deferred", "handle"), &LuaManager::_enable_submenu_deferred);
    ClassDB::bind_method(D_METHOD("_disable_submenu_deferred", "handle"), &LuaManager::_disable_submenu_deferred);
    ClassDB::bind_method(D_METHOD("_add_bouncer_deferred", "syntax"), &LuaManager::_add_bouncer_deferred);
    ClassDB::bind_method(D_METHOD("_del_bouncer_deferred", "index"), &LuaManager::_del_bouncer_deferred);
    ClassDB::bind_method(D_METHOD("_set_bouncer_param_deferred", "index", "name", "value"), &LuaManager::_set_bouncer_param_deferred);
    ClassDB::bind_method(D_METHOD("_set_bg_deferred", "syntax"), &LuaManager::_set_bg_deferred);
    ClassDB::bind_method(D_METHOD("_clear_and_run_deferred", "filename"), &LuaManager::_clear_and_run_deferred);
    ClassDB::bind_method(D_METHOD("_do_clear_and_run", "filename"), &LuaManager::_do_clear_and_run);
    ClassDB::bind_method(D_METHOD("_play_audio_deferred", "filename"), &LuaManager::_play_audio_deferred);
    ClassDB::bind_method(D_METHOD("_play_audio_dynamic_deferred", "filename"), &LuaManager::_play_audio_dynamic_deferred);
    ClassDB::bind_method(D_METHOD("_set_audio_volume_deferred", "vol"), &LuaManager::_set_audio_volume_deferred);
    ClassDB::bind_method(D_METHOD("_rewind_audio_deferred"), &LuaManager::_rewind_audio_deferred);
    ClassDB::bind_method(D_METHOD("_pause_audio_deferred", "paused"), &LuaManager::_pause_audio_deferred);
    ClassDB::bind_method(D_METHOD("_stop_audio_deferred"), &LuaManager::_stop_audio_deferred);
    ClassDB::bind_method(D_METHOD("_skip_to_playlist_track", "idx"), &LuaManager::_skip_to_playlist_track);
    ClassDB::bind_method(D_METHOD("_play_next_playlist_item"), &LuaManager::_play_next_playlist_item);
    ClassDB::bind_method(D_METHOD("_skip_audio_deferred", "amount"), &LuaManager::_skip_audio_deferred);
    ClassDB::bind_method(D_METHOD("_set_resize_enabled_deferred", "enabled"), &LuaManager::_set_resize_enabled_deferred);
    ClassDB::bind_method(D_METHOD("_maximize_window_deferred"), &LuaManager::_maximize_window_deferred);
    ClassDB::bind_method(D_METHOD("_quit_deferred"), &LuaManager::_quit_deferred);
    ClassDB::bind_method(D_METHOD("_on_dynamic_signal", "func_name"), &LuaManager::_on_dynamic_signal);
    
    ClassDB::bind_method(D_METHOD("run_script", "script_name"), &LuaManager::run_script);
    ClassDB::bind_method(D_METHOD("is_preloading"), &LuaManager::is_preloading);
    ClassDB::bind_method(D_METHOD("is_loading_engine"), &LuaManager::is_loading_engine);
    ClassDB::bind_method(D_METHOD("get_loading_progress"), &LuaManager::get_loading_progress);
    ClassDB::bind_method(D_METHOD("finish_gdscript_load"), &LuaManager::finish_gdscript_load);

    ClassDB::bind_method(D_METHOD("set_global_int", "name", "val"), &LuaManager::set_global_int);
    ClassDB::bind_method(D_METHOD("get_global_int", "name"), &LuaManager::get_global_int);
    ClassDB::bind_method(D_METHOD("set_global_float", "name", "val"), &LuaManager::set_global_float);
    ClassDB::bind_method(D_METHOD("get_global_float", "name"), &LuaManager::get_global_float);
}

void LuaManager::_on_addhscore_submitted(String text, int score, int level, uint64_t bouncer_id) {
    if (text.length() > 3) text = text.substr(0, 3);
    text = text.to_upper();
    
    highscores.push_back({text, score, level});
    std::sort(highscores.begin(), highscores.end(), [](const HighScoreEntry& a, const HighScoreEntry& b) {
        return a.score > b.score;
    });
    if (highscores.size() > 10) highscores.resize(10);
    
    String hs_dir = OS::get_singleton()->get_environment("HOME") + "/.age";
    String hs_path = hs_dir + "/high.score";
    if (!DirAccess::dir_exists_absolute(hs_dir)) {
        DirAccess::make_dir_absolute(hs_dir);
    }
    Ref<FileAccess> file = FileAccess::open(hs_path, FileAccess::WRITE);
    if (file.is_valid()) {
        for (const auto& hs : highscores) {
            file->store_line(hs.name + String(",") + String::num_int64(hs.score) + String(",") + String::num_int64(hs.level));
        }
    }
    
    Object* obj = ObjectDB::get_instance(bouncer_id);
    if (obj) {
        Node* node = Object::cast_to<Node>(obj);
        if (node) node->queue_free();
    }
    
    if (lua_engine) {
        lua_engine->runScript("setGlobalVar('hs_entered', 1)");
    }
    
    this->call_deferred("_clear_and_run_deferred", "loozer.lua");
}

LuaManager::LuaManager() {
}

LuaManager::~LuaManager() {
    if (download_thread && download_thread->joinable()) {
        download_thread->join();
    }
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


void LuaManager::_begin_menu_deferred(String name, int rows) {
    is_building_menu = true;
    MenuData m;
    m.name = name;
    m.rows.resize(rows);
    menus.push_back(m);
    active_menu_index = menus.size() - 1;
    active_building_row = 0; // Default to row 0 for legacy menus
    if (!active_building_submenu.is_empty()) {
        submenus[active_building_submenu].menu_index = active_menu_index;
    } else {
        main_menu_index = active_menu_index;
    }
}

void LuaManager::_begin_row_deferred(String name, int row) {
    if (is_building_menu && active_menu_index >= 0) {
        if (row >= 1 && row <= menus[active_menu_index].rows.size()) {
            active_building_row = row - 1; // 1-based index from Lua
        }
    }
}

void LuaManager::_end_row_deferred(String name) {
    // No-op for now, just logical closure
}

void LuaManager::_create_submenu_deferred(String handle) {
    if (!submenus.count(handle)) {
        SubMenuData sm;
        sm.handle = handle;
        sm.is_active = false;
        submenus[handle] = sm;
    }
}

void LuaManager::_begin_submenu_deferred(String handle) {
    _create_submenu_deferred(handle); // Ensure it exists
    active_building_submenu = handle;
}

void LuaManager::_end_submenu_deferred(String handle) {
    active_building_submenu = "";
}

void LuaManager::_enable_submenu_deferred(String handle) {
    if (submenus.count(handle)) {
        SubMenuData& sm = submenus[handle];
        sm.is_active = true;
        for (uint64_t id : sm.all_bouncers) {
            Node2D* container = Object::cast_to<Node2D>(ObjectDB::get_instance(id));
            if (container) {
                container->show();
                uint64_t ctrl_id = 0;
                for (auto& pair : interactive_bouncers) {
                    if (pair.second.container_id == id) {
                        ctrl_id = pair.first;
                        break;
                    }
                }
                std::vector<VideoStreamPlayer*> vps;
                for (int i = 0; i < container->get_child_count(); ++i) {
                    Node* child = container->get_child(i);
                    if (VideoStreamPlayer* vp = Object::cast_to<VideoStreamPlayer>(child)) vps.push_back(vp);
                    for (int j = 0; j < child->get_child_count(); ++j) {
                        Node* child2 = child->get_child(j);
                        if (VideoStreamPlayer* vp = Object::cast_to<VideoStreamPlayer>(child2)) vps.push_back(vp);
                        for (int k = 0; k < child2->get_child_count(); ++k) {
                            Node* child3 = child2->get_child(k);
                            if (VideoStreamPlayer* vp = Object::cast_to<VideoStreamPlayer>(child3)) vps.push_back(vp);
                        }
                    }
                }
                for (VideoStreamPlayer* vp : vps) {
                    if (ctrl_id == 0 || !interactive_bouncers[ctrl_id].has_hover) {
                        vp->set_paused(false);
                        vp->play();
                        vp->set_volume_db(0.0f);
                    }
                }
            }
        }
        if (sm.menu_index >= 0) {
            active_menu_index = sm.menu_index;
            if (active_menu_index < (int)menus.size() && !menus[active_menu_index].rows.empty()) {
                for (auto& row : menus[active_menu_index].rows) {
                    for (uint64_t id : row.items) {
                        _set_bouncer_hover(id, false);
                    }
                }
                menus[active_menu_index].selected_row = 0;
                if (!menus[active_menu_index].rows[0].items.empty()) {
                    menus[active_menu_index].rows[0].selected_col = 0;
                    _set_bouncer_hover(menus[active_menu_index].rows[0].items[0], true);
                }
            }
        }
    }
}

void LuaManager::_disable_submenu_deferred(String handle) {
    if (submenus.count(handle)) {
        SubMenuData& sm = submenus[handle];
        sm.is_active = false;
        for (uint64_t id : sm.all_bouncers) {
            Node2D* container = Object::cast_to<Node2D>(ObjectDB::get_instance(id));
            if (container) {
                container->hide();
                uint64_t ctrl_id = 0;
                for (auto& pair : interactive_bouncers) {
                    if (pair.second.container_id == id) {
                        ctrl_id = pair.first;
                        break;
                    }
                }
                std::vector<VideoStreamPlayer*> vps;
                for (int i = 0; i < container->get_child_count(); ++i) {
                    Node* child = container->get_child(i);
                    if (VideoStreamPlayer* vp = Object::cast_to<VideoStreamPlayer>(child)) vps.push_back(vp);
                    for (int j = 0; j < child->get_child_count(); ++j) {
                        Node* child2 = child->get_child(j);
                        if (VideoStreamPlayer* vp = Object::cast_to<VideoStreamPlayer>(child2)) vps.push_back(vp);
                        for (int k = 0; k < child2->get_child_count(); ++k) {
                            Node* child3 = child2->get_child(k);
                            if (VideoStreamPlayer* vp = Object::cast_to<VideoStreamPlayer>(child3)) vps.push_back(vp);
                        }
                    }
                }
                for (VideoStreamPlayer* vp : vps) {
                    vp->set_paused(true);
                    vp->set_volume_db(-80.0f);
                }
            }
        }
        if (sm.menu_index >= 0 && active_menu_index == sm.menu_index) {
            active_menu_index = main_menu_index;
            if (active_menu_index >= 0 && active_menu_index < (int)menus.size() && !menus[active_menu_index].rows.empty()) {
                MenuData& m = menus[active_menu_index];
                if (m.selected_row >= 0 && m.selected_row < m.rows.size() && !m.rows[m.selected_row].items.empty()) {
                    _set_bouncer_hover(m.rows[m.selected_row].items[m.rows[m.selected_row].selected_col], true);
                }
            }
        }
    }
}

void LuaManager::_end_menu_deferred() {
    is_building_menu = false;
    if (active_menu_index >= 0 && active_menu_index < menus.size()) {
        MenuData& m = menus[active_menu_index];
        if (!m.rows.empty()) {
            for (auto& row : m.rows) {
                for (uint64_t ctrl_id : row.items) {
                    _set_bouncer_hover(ctrl_id, false);
                }
            }
            m.selected_row = 0;
            if (!m.rows[0].items.empty()) {
                m.rows[0].selected_col = 0;
                _set_bouncer_hover(m.rows[0].items[0], true);
            }
        }
    }
}

void LuaManager::_add_bouncer_deferred(const String& syntax) {
    String s = syntax;
    Vector2 pos(0, 0);
    String image_path = "";
    String video_path = "";
    bool is_selector = false;
    uint64_t current_selector_id = 0;
    String sel_folder;
    String sel_filename;
    String sel_var;
    bool is_stencil = false;
    String scene_path = "";
    String text = "";
    Color color(1, 1, 1, 1);
    Vector2 rect(0, 0);
    int layer_idx = 0;
    float font_size = 1.0;
    int hscore_idx = -1;
    int plasma_idx = -1;
    
    bool is_hscore = false;
    float hscore_font_size = 18.0f;
    
    bool is_addhscore = false;
    float addhscore_font_size = 18.0f;
    int addhscore_score = 0;
    int addhscore_level = 0;
    
    bool has_hover = syntax.find("[hover:") != -1;
    Color hover_color;
    String clicked_script = "";

    bool has_phys = false;
    bool has_linear = false;
    Vector2 phys_pos;
    Vector2 phys_vel;
    Vector2 linear_vel;
    float phys_speed = 1.0f;
    float phys_friction = 1.0f;
    
    bool has_ttl = false;
    float ttl_val = 0.0f;
    
    bool is_graffity = false;
    Color graffity_inner;
    Color graffity_outer;
    Color graffity_hover;

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
            if (p.size() >= 4) {
                has_linear = true;
                linear_vel = Vector2(p[2].to_float(), p[3].to_float());
            }
        } else if (tag.begins_with("image:") || tag.begins_with("stencil:")) {
            int colon = tag.find(":");
            image_path = tag.substr(colon + 1).strip_edges();
            if (tag.begins_with("stencil:")) is_stencil = true;
        } else if (tag.begins_with("video:")) {
            int colon = tag.find(":");
            video_path = tag.substr(colon + 1).strip_edges();
        } else if (tag.begins_with("selector:")) {
            is_selector = true;
            PackedStringArray p = tag.substr(9).split(",");
            if (p.size() >= 1) sel_folder = p[0].strip_edges().replace("\"", "").replace("'", "");
            if (p.size() >= 2) sel_filename = p[1].strip_edges().replace("\"", "").replace("'", "");
            if (p.size() >= 3) sel_var = p[2].strip_edges().replace("\"", "").replace("'", "");
        } else if (tag.begins_with("ttscn:")) {
            scene_path = tag.substr(6).strip_edges();
        } else if (tag.begins_with("rect:")) {
            PackedStringArray r = tag.substr(5).split(",");
            if (r.size() >= 2) rect = Vector2(r[0].to_float(), r[1].to_float());
        } else if (tag.begins_with("fontsize:")) {
            font_size = tag.substr(9).to_float();
        } else if (tag.begins_with("color:") || tag.begins_with("rgb:")) {
            PackedStringArray rgb = tag.substr(tag.begins_with("color:") ? 6 : 4).split(",");
            if (rgb.size() >= 3) {
                Color c = Color(rgb[0].to_float() / 255.0f, rgb[1].to_float() / 255.0f, rgb[2].to_float() / 255.0f);
                if (!has_hover) {
                    text += "[color=#" + c.to_html(false) + "]";
                    color = Color(1, 1, 1, 1);
                } else {
                    color = c;
                }
            }
        } else if (tag.begins_with("layer:")) {
            layer_idx = tag.substr(6).to_int();
        } else if (tag.begins_with("hscore:")) {
            is_hscore = true;
            hscore_font_size = tag.substr(7).to_float();
        } else if (tag.begins_with("addhscore:")) {
            is_addhscore = true;
            PackedStringArray p = tag.substr(10).split(",");
            if (p.size() >= 1) addhscore_font_size = p[0].to_float();
            if (p.size() >= 2) addhscore_score = p[1].to_int();
            if (p.size() >= 3) addhscore_level = p[2].to_int();
        } else if (tag.begins_with("plasma:")) {
            plasma_idx = tag.substr(7).to_int();
        } else if (tag.begins_with("hover:")) {
            PackedStringArray rgb = tag.substr(6).split(",");
            if (rgb.size() >= 3) {
                hover_color = Color(rgb[0].to_float() / 255.0f, rgb[1].to_float() / 255.0f, rgb[2].to_float() / 255.0f);
            }
        } else if (tag.begins_with("graffity:") || tag.begins_with("graffiti:")) {
            PackedStringArray p = tag.substr(9).split(",");
            if (p.size() >= 9) {
                is_graffity = true;
                graffity_inner = Color(p[0].to_float() / 255.0f, p[1].to_float() / 255.0f, p[2].to_float() / 255.0f);
                graffity_outer = Color(p[3].to_float() / 255.0f, p[4].to_float() / 255.0f, p[5].to_float() / 255.0f);
                graffity_hover = Color(p[6].to_float() / 255.0f, p[7].to_float() / 255.0f, p[8].to_float() / 255.0f);
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
        } else if (tag.begins_with("phys:")) {
            PackedStringArray p = tag.substr(5).split(",");
            if (p.size() >= 4) {
                has_phys = true;
                phys_pos = Vector2(p[0].to_float(), p[1].to_float());
                phys_vel = Vector2(p[2].to_float(), p[3].to_float());
                if (p.size() >= 5) phys_speed = p[4].to_float();
                if (p.size() >= 6) phys_friction = p[5].to_float();
            }
        } else if (tag.begins_with("ttl:")) {
            has_ttl = true;
            ttl_val = tag.substr(4).to_float() / 1000.0f;
        } else if (tag == "lf") {
            text += "\n";
        } else {
            text += "[" + tag + "]";
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
    
    Control* interactive_control = nullptr;
    
    if (!scene_path.is_empty()) {
        if (!scene_path.begins_with("res://")) scene_path = "res://" + scene_path;
        Ref<PackedScene> scn = ResourceLoader::get_singleton()->load(scene_path);
        if (scn.is_valid()) {
            Node* inst = scn->instantiate();
            if (Object::cast_to<Node3D>(inst)) {
                SubViewportContainer* svc = memnew(SubViewportContainer);
                SubViewport* vp = memnew(SubViewport);
                vp->set_use_own_world_3d(true);
                vp->set_transparent_background(true);
                if (rect.x > 0 && rect.y > 0) {
                    vp->set_size(rect);
                    svc->set_size(rect);
                } else {
                    vp->set_size(Vector2(512, 512));
                    svc->set_size(Vector2(512, 512));
                }
                vp->add_child(inst);
                svc->add_child(vp);
                container->add_child(svc);
            } else {
                container->add_child(inst);
            }
        }
    }
    
    CanvasItem* visual_item = nullptr;
    
    TextureRect* tex_rect = nullptr;
    if (!image_path.is_empty()) {
        if (!image_path.begins_with("res://") && !image_path.begins_with("user://")) image_path = "res://" + image_path;
        tex_rect = memnew(TextureRect);
        Ref<Texture2D> tex = ResourceLoader::get_singleton()->load(image_path);
        if (tex.is_valid()) {
            tex_rect->set_texture(tex);
            if (rect.x > 0 && rect.y > 0) {
                if (is_stencil) {
                    Vector2 tex_size = tex->get_size();
                    if (tex_size.x > 0 && tex_size.y > 0) {
                        tex_rect->set_scale(Vector2(rect.x / tex_size.x, rect.y / tex_size.y));
                    }
                } else {
                    tex_rect->set_custom_minimum_size(rect);
                    tex_rect->set_size(rect);
                    tex_rect->set_expand_mode(TextureRect::EXPAND_IGNORE_SIZE);
                    tex_rect->set_stretch_mode(TextureRect::STRETCH_KEEP_ASPECT_CENTERED);
                }
            }
        }
    }
    
    VideoStreamPlayer* video_player = nullptr;
    if (!video_path.is_empty()) {
        if (!video_path.begins_with("res://") && !video_path.begins_with("user://")) video_path = "res://" + video_path;
        video_player = memnew(VideoStreamPlayer);
        Ref<VideoStream> vstream = ResourceLoader::get_singleton()->load(video_path);
        if (vstream.is_valid()) {
            video_player->set_stream(vstream);
            video_player->set_expand(true);
            video_player->set_autoplay(true);
            if (has_hover) {
                video_player->set_volume_db(-80.0f);
                videos_to_preload.push_back(video_player->get_instance_id());
            }
            if (rect.x > 0 && rect.y > 0) {
                video_player->set_custom_minimum_size(rect);
                video_player->set_size(rect);
            }
        }
    }
    
    RichTextLabel* label = nullptr;
    if (!text.is_empty() && !is_hscore && !is_addhscore) {
        label = memnew(RichTextLabel);
        label->set_use_bbcode(true);
        label->set_text(text);
        label->add_theme_font_size_override("normal_font_size", MAX(1, (int)(64.0 * font_size)));
        label->set_autowrap_mode(TextServer::AUTOWRAP_OFF);
        label->set_fit_content(true);
        if (is_graffity) {
            Ref<Font> custom_font = ResourceLoader::get_singleton()->load("res://docallismeonstreet.otf");
            if (custom_font.is_valid()) {
                label->add_theme_font_override("normal_font", custom_font);
            }
            // Prepend a transparent period to fool the font into middle-of-word alternates
            text = "[color=#00000000].[/color]" + text;
            label->set_text(text);
            label->add_theme_color_override("default_color", graffity_inner);
            label->add_theme_color_override("font_outline_color", graffity_outer);
            label->add_theme_constant_override("outline_size", 12);
        }
        
        if (syntax.find("[global:") != -1) {
            DynamicLabel dl;
            dl.label_id = label->get_instance_id();
            dl.syntax = syntax;
            dynamic_labels.push_back(dl);
        }
    }
    
    if (label && tex_rect) {
        HBoxContainer* hbox = memnew(HBoxContainer);
        hbox->set_alignment(BoxContainer::ALIGNMENT_CENTER);
        hbox->add_child(label);
        hbox->add_child(tex_rect);
        container->add_child(hbox);
        interactive_control = hbox;
        visual_item = hbox;
    } else if (label) {
        container->add_child(label);
        interactive_control = label;
        visual_item = label;
    } else if (tex_rect) {
        container->add_child(tex_rect);
        interactive_control = tex_rect;
        visual_item = tex_rect;
    } else if (video_player) {
        ColorRect* pc = memnew(ColorRect);
        pc->set_color(Color(0, 0, 0, 0));
        if (rect.x > 0 && rect.y > 0) {
            pc->set_custom_minimum_size(rect);
            pc->set_size(rect);
            video_player->set_custom_minimum_size(rect);
            video_player->set_size(rect);
        }
        video_player->set_mouse_filter(Control::MOUSE_FILTER_IGNORE);
        pc->add_child(video_player);
        container->add_child(pc);
        interactive_control = pc;
        visual_item = pc;
    } else if (is_hscore) {
        PanelContainer* pc = memnew(PanelContainer);
        Ref<StyleBoxFlat> sb = memnew(StyleBoxFlat);
        sb->set_bg_color(Color(0, 0, 0, 0.6));
        sb->set_corner_radius_all(10);
        sb->set_content_margin_all(20);
        pc->add_theme_stylebox_override("panel", sb);
        
        GridContainer* grid = memnew(GridContainer);
        grid->set_columns(4);
        grid->add_theme_constant_override("h_separation", 40);
        
        if (highscores.size() == 0) {
            grid->set_columns(1);
            Label* lbl = memnew(Label);
            lbl->set_text("NO HIGH SCORES");
            lbl->add_theme_font_size_override("font_size", (int)hscore_font_size);
            grid->add_child(lbl);
        } else {
            for (int i = 0; i < highscores.size(); i++) {
                Label* rank = memnew(Label);
                rank->set_text(String::num_int64(i + 1) + ".");
                rank->add_theme_font_size_override("font_size", (int)hscore_font_size);
                
                Label* name = memnew(Label);
                name->set_text(highscores[i].name);
                name->add_theme_font_size_override("font_size", (int)hscore_font_size);
                
                Label* score = memnew(Label);
                score->set_text(String::num_int64(highscores[i].score));
                score->add_theme_font_size_override("font_size", (int)hscore_font_size);
                score->set_horizontal_alignment(HORIZONTAL_ALIGNMENT_RIGHT);
                
                Label* lvl = memnew(Label);
                lvl->set_text("LVL" + String::num_int64(highscores[i].level));
                lvl->add_theme_font_size_override("font_size", (int)hscore_font_size);
                
                grid->add_child(rank);
                grid->add_child(name);
                grid->add_child(score);
                grid->add_child(lvl);
            }
        }
        pc->add_child(grid);
        container->add_child(pc);
        interactive_control = pc;
        visual_item = pc;
    } else if (is_addhscore) {
        VBoxContainer* vbox = memnew(VBoxContainer);
        if (rect.x > 0 && rect.y > 0) {
            vbox->set_custom_minimum_size(rect);
            vbox->set_size(rect);
        }
        
        Label* title = memnew(Label);
        title->set_text("NEW HIGH SCORE!\nEnter 3 letters:");
        title->add_theme_font_size_override("font_size", (int)addhscore_font_size);
        vbox->add_child(title);
        
        LineEdit* le = memnew(LineEdit);
        le->set_max_length(3);
        le->add_theme_font_size_override("font_size", (int)addhscore_font_size);
        vbox->add_child(le);
        
        container->add_child(vbox);
        interactive_control = le;
        visual_item = vbox;
        
        le->connect("text_submitted", Callable(this, "_on_addhscore_submitted").bind(addhscore_score, addhscore_level, container->get_instance_id()));
    } else if (is_selector) {
        UISelector* selector = memnew(UISelector);
        selector->folder = sel_folder;
        selector->filename = sel_filename;
        selector->global_var_name = sel_var;
        
        std::string sys_folder = sel_folder.utf8().get_data();
        if (std::filesystem::exists(sys_folder) && std::filesystem::is_directory(sys_folder)) {
            for (const auto& entry : std::filesystem::directory_iterator(sys_folder)) {
                if (entry.is_directory()) {
                    selector->subfolders.push_back(String(entry.path().filename().string().c_str()));
                }
            }
        }
        
        Ref<StyleBoxFlat> panel_style = memnew(StyleBoxFlat);
        panel_style->set_bg_color(Color(0, 0, 0, 0.7)); // Smoked glass
        panel_style->set_corner_radius_all(30);
        selector->add_theme_stylebox_override("panel", panel_style);
        
        HBoxContainer* hbox = memnew(HBoxContainer);
        hbox->add_theme_constant_override("separation", 0);
        hbox->set_alignment(BoxContainer::ALIGNMENT_CENTER);
        
        // Left Button Style
        Ref<StyleBoxFlat> left_style = memnew(StyleBoxFlat);
        left_style->set_bg_color(Color(0.1, 0.1, 0.1, 0.9));
        left_style->set_corner_radius(godot::CORNER_TOP_LEFT, 30);
        left_style->set_corner_radius(godot::CORNER_BOTTOM_LEFT, 30);
        
        Ref<StyleBoxFlat> left_hover = memnew(StyleBoxFlat);
        left_hover->set_bg_color(Color(0.3, 0.3, 0.3, 0.9));
        left_hover->set_corner_radius(godot::CORNER_TOP_LEFT, 30);
        left_hover->set_corner_radius(godot::CORNER_BOTTOM_LEFT, 30);

        Button* left_btn = memnew(Button);
        left_btn->set_text("<");
        left_btn->set_custom_minimum_size(Vector2(50, 0));
        left_btn->add_theme_stylebox_override("normal", left_style);
        left_btn->add_theme_stylebox_override("hover", left_hover);
        left_btn->add_theme_stylebox_override("pressed", left_style);
        left_btn->connect("pressed", Callable(selector, "_on_left_pressed"));
        
        // Right Button Style
        Ref<StyleBoxFlat> right_style = memnew(StyleBoxFlat);
        right_style->set_bg_color(Color(0.1, 0.1, 0.1, 0.9));
        right_style->set_corner_radius(godot::CORNER_TOP_RIGHT, 30);
        right_style->set_corner_radius(godot::CORNER_BOTTOM_RIGHT, 30);
        
        Ref<StyleBoxFlat> right_hover = memnew(StyleBoxFlat);
        right_hover->set_bg_color(Color(0.3, 0.3, 0.3, 0.9));
        right_hover->set_corner_radius(godot::CORNER_TOP_RIGHT, 30);
        right_hover->set_corner_radius(godot::CORNER_BOTTOM_RIGHT, 30);

        Button* right_btn = memnew(Button);
        right_btn->set_text(">");
        right_btn->set_custom_minimum_size(Vector2(50, 0));
        right_btn->add_theme_stylebox_override("normal", right_style);
        right_btn->add_theme_stylebox_override("hover", right_hover);
        right_btn->add_theme_stylebox_override("pressed", right_style);
        right_btn->connect("pressed", Callable(selector, "_on_right_pressed"));
        
        bool is_video = sel_filename.ends_with(".ogv");
        Vector2 media_size = (rect.x > 0 && rect.y > 0) ? rect : Vector2(640, 360);
        
        if (is_video) {
            VideoStreamPlayer* vp = memnew(VideoStreamPlayer);
            vp->set_custom_minimum_size(media_size);
            vp->set_expand(true);
            selector->media_node = vp;
        } else {
            TextureRect* tr = memnew(TextureRect);
            tr->set_custom_minimum_size(media_size);
            tr->set_expand_mode(TextureRect::EXPAND_IGNORE_SIZE);
            tr->set_stretch_mode(TextureRect::STRETCH_KEEP_ASPECT_CENTERED);
            selector->media_node = tr;
        }
        
        hbox->add_child(left_btn);
        hbox->add_child(selector->media_node);
        hbox->add_child(right_btn);
        
        selector->add_child(hbox);
        selector->update_media();
        current_selector_id = selector->get_instance_id();
        
        interactive_control = selector;
    
        container->add_child(selector);
        visual_item = selector;
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
    
    if (interactive_control && (has_hover || !clicked_script.is_empty() || is_graffity || is_selector)) {
        interactive_control->set_mouse_filter(Control::MOUSE_FILTER_STOP);
        uint64_t ctrl_id = interactive_control->get_instance_id();
        
        InteractiveData idata;
        idata.normal_color = color;
        idata.hover_color = hover_color;
        idata.has_hover = has_hover;
        idata.clicked_script = clicked_script;
        idata.container_id = container->get_instance_id();
        idata.is_graffity = is_graffity;
        idata.graffity_outer = graffity_outer;
        idata.graffity_hover = graffity_hover;
        idata.label_id = label ? label->get_instance_id() : 0;
        idata.is_selector = is_selector;
        idata.selector_id = current_selector_id;
        interactive_bouncers[ctrl_id] = idata;
        
        interactive_control->connect("mouse_entered", Callable(this, "_on_bouncer_mouse_entered").bind(ctrl_id));
        interactive_control->connect("mouse_exited", Callable(this, "_on_bouncer_mouse_exited").bind(ctrl_id));
        interactive_control->connect("gui_input", Callable(this, "_on_bouncer_gui_input").bind(ctrl_id));
        
        if (is_building_menu && active_menu_index >= 0) {
            if (active_building_row < menus[active_menu_index].rows.size()) {
                menus[active_menu_index].rows[active_building_row].items.push_back(ctrl_id);
            }
        }
    }
    
    target_layer->add_child(container);
    if (is_addhscore && interactive_control) {
        interactive_control->grab_focus();
    }
    
    if (!active_building_submenu.is_empty()) {
        submenus[active_building_submenu].all_bouncers.push_back(container->get_instance_id());
        container->hide();
        if (video_player) {
            /* video_player->set_process_mode(Node::PROCESS_MODE_DISABLED); */
            video_player->set_volume_db(-80.0f);
        }
    }
    
    if (has_phys || has_linear || has_ttl) {
        if (has_phys || has_linear) container->set_position(has_phys ? phys_pos : pos);
        BouncerPhysics bp;
        bp.enabled = true;
        if (has_phys) {
            bp.velocity = phys_vel;
            bp.speed = phys_speed;
            bp.friction = phys_friction;
            bp.has_gravity = true;
        } else if (has_linear) {
            bp.velocity = linear_vel;
            bp.speed = 1.0f;
            bp.friction = 1.0f;
            bp.has_gravity = false;
        }
        bp.has_ttl = has_ttl;
        bp.ttl = ttl_val;
        bouncer_physics[container->get_instance_id()] = bp;
    }
    
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
    Node* loading_screen = get_tree()->get_root()->get_node_or_null("LoadingScreen");
    if (loading_screen) {
        loading_screen->call("start_loading", filename);
    } else {
        _do_clear_and_run(filename);
    }
}

void LuaManager::_do_clear_and_run(const String& filename) {
    for (uint64_t id : bouncers) {
        Object* obj = ObjectDB::get_instance(id);
        if (obj) {
            Node* node = Object::cast_to<Node>(obj);
            if (node) node->queue_free();
        }
    }
    bouncers.clear();
    submenus.clear();
    active_building_submenu = "";
    main_menu_index = -1;
    menus.clear();
    active_menu_index = -1;
    
    for (uint64_t id : loaded_nodes) {
        Object* obj = ObjectDB::get_instance(id);
        if (obj) {
            Node* node = Object::cast_to<Node>(obj);
            if (node) node->queue_free();
        }
    }
    loaded_nodes.clear();
    
    for (auto const& [idx, layer_id] : bouncer_layers) {
        Object* obj = ObjectDB::get_instance(layer_id);
        if (obj) {
            Node* node = Object::cast_to<Node>(obj);
            if (node) {
                std::vector<VideoStreamPlayer*> vps;
                for (int i = 0; i < node->get_child_count(); ++i) {
                    Node* child = node->get_child(i);
                    if (VideoStreamPlayer* vp = Object::cast_to<VideoStreamPlayer>(child)) vps.push_back(vp);
                    for (int j = 0; j < child->get_child_count(); ++j) {
                        Node* child2 = child->get_child(j);
                        if (VideoStreamPlayer* vp = Object::cast_to<VideoStreamPlayer>(child2)) vps.push_back(vp);
                        for (int k = 0; k < child2->get_child_count(); ++k) {
                            Node* child3 = child2->get_child(k);
                            if (VideoStreamPlayer* vp = Object::cast_to<VideoStreamPlayer>(child3)) vps.push_back(vp);
                        }
                    }
                }
                for (VideoStreamPlayer* vp : vps) {
                    if (vp) vp->stop();
                }
                node->queue_free();
            }
        }
    }
    bouncer_layers.clear();
    interactive_bouncers.clear();
    videos_to_preload.clear();
    
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
    
    godot::Input::get_singleton()->set_mouse_mode(godot::Input::MOUSE_MODE_VISIBLE);
    run_script(filename);
}

bool LuaManager::_play_audio_deferred(const String& filename) {
    if (filename.begins_with("ytdlp://")) {
        String url = filename.substr(8);
        initial_download_id++;
        int my_id = initial_download_id.load();
        
        std::thread([this, url, my_id]() {
            std::lock_guard<std::mutex> join_lock(this->download_join_mutex);
            if (my_id != initial_download_id.load()) return;
            
            std::shared_ptr<std::thread> old_thread;
            {
                std::lock_guard<std::mutex> lock(audio_mutex);
                old_thread = download_thread;
                download_thread = nullptr;
                is_downloading_next = true;
                playlist_urls.clear();
                playlist_ids.clear();
                failed_downloads.clear(); // Important so _process doesn't trigger
            }
            if (old_thread && old_thread->joinable()) {
                old_thread->join();
            }
            if (my_id != initial_download_id.load()) return;
            {
                std::lock_guard<std::mutex> lock(audio_mutex);
                download_thread = std::make_shared<std::thread>( [this, url, my_id]() { this->_start_initial_download(url, my_id); } );
            }
        }).detach();
        
        return true;
    }
    
    std::lock_guard<std::mutex> lock(audio_mutex);
    playlist_mode = false;
    audio_is_starting = true;
    this->call_deferred("_play_audio_dynamic_deferred", filename);
    return true;
}

void LuaManager::_start_initial_download(const String& url, int my_id) {
    Ref<DirAccess> dir = DirAccess::open("user://");
    if (dir.is_valid()) {
        dir->make_dir("yt_cache");
    }
    if (url.contains("list=")) {
        PackedStringArray flat_args;
        flat_args.push_back("--flat-playlist");
        flat_args.push_back("--print");
        flat_args.push_back("%(playlist_title)s|%(id)s|%(title)s");
        flat_args.push_back("--no-warnings");
        flat_args.push_back(url);
        
        Array out;
        int32_t ret = OS::get_singleton()->execute("yt-dlp", flat_args, out, false, false);
        if (my_id != initial_download_id.load()) return;
        if (ret == 0 && out.size() > 0) {
            String output = out[0];
            PackedStringArray lines = output.split("\n", false);
            {
                std::lock_guard<std::mutex> lock(audio_mutex);
                playlist_urls.clear();
                playlist_ids.clear();
                failed_downloads.clear();
                playlist_titles.clear();
                playlist_name = "Current Queue";
                
                for (int i = 0; i < lines.size(); i++) {
                    String line = lines[i].strip_edges();
                    if (line.length() > 0 && !line.begins_with("WARNING") && !line.begins_with("ERROR")) {
                        PackedStringArray parts = line.split("|");
                        if (parts.size() >= 2) {
                            String p_title = parts[0];
                            if (p_title != "NA" && p_title != "") {
                                playlist_name = p_title;
                            }
                            String id = parts[1];
                            String t_title = id;
                            if (parts.size() >= 3) {
                                t_title = parts[2];
                                for (int j = 3; j < parts.size(); j++) {
                                    t_title += "|" + parts[j];
                                }
                            }
                            playlist_urls.push_back("https://www.youtube.com/watch?v=" + id);
                            playlist_ids.push_back(id);
                            playlist_titles.push_back(t_title);
                        } else if (parts.size() == 1) {
                            playlist_urls.push_back("https://www.youtube.com/watch?v=" + parts[0]);
                            playlist_ids.push_back(parts[0]);
                            playlist_titles.push_back(parts[0]);
                        }
                    }
                }
                playlist_mode = true;
                current_playlist_index = 0;
                playing_playlist_index = 0;
                is_downloading_next = false;
            all_playlist_cached = false;
                all_playlist_cached = false;
            }
        } else {
            std::lock_guard<std::mutex> lock(audio_mutex);
            playlist_urls.clear();
            playlist_ids.clear();
            failed_downloads.clear();
            playlist_titles.clear();
            playlist_urls.push_back(url);
            String yt_id = url;
            if (url.contains("v=")) {
                yt_id = url.get_slice("v=", 1).get_slice("&", 0);
            } else {
                yt_id = String::num_int64(url.hash());
            }
            playlist_ids.push_back(yt_id);
            playlist_titles.push_back("Track 1");
            playlist_name = "Single Track";
            current_playlist_index = 0;
                playing_playlist_index = 0;
            playlist_mode = false;
            is_downloading_next = false;
        }
    } else {
        std::lock_guard<std::mutex> lock(audio_mutex);
        playlist_urls.clear();
                playlist_ids.clear();
                failed_downloads.clear();
        playlist_titles.clear();
        playlist_urls.push_back(url);
        String yt_id = url;
        if (url.contains("v=")) {
            yt_id = url.get_slice("v=", 1).get_slice("&", 0);
        } else {
            yt_id = String::num_int64(url.hash());
        }
        playlist_ids.push_back(yt_id);
        playlist_titles.push_back("Track 1");
        playlist_name = "Single Track";
        current_playlist_index = 0;
                playing_playlist_index = 0;
        playlist_mode = false;
        is_downloading_next = false;
    }
    
    String url_to_download;
    String yt_id;
    int idx;
    {
        std::lock_guard<std::mutex> lock(audio_mutex);
        if (playlist_urls.empty()) return;
        url_to_download = playlist_urls[0];
        yt_id = playlist_ids[0];
        idx = 0;
    }
    
    String cache_file = "user://yt_cache/" + yt_id + ".mp3";
    
    if (FileAccess::file_exists(cache_file)) {
        if (my_id != initial_download_id.load()) return;
        std::lock_guard<std::mutex> lock(audio_mutex);
        if (idx != current_playlist_index) return;
        is_downloading_next = false;
        next_downloaded_file = cache_file;
        this->call_deferred("_play_next_playlist_item");
        return;
    }
    
    String global_path = ProjectSettings::get_singleton()->globalize_path(cache_file);
    
    PackedStringArray args;
    args.push_back("-x");
    args.push_back("--audio-format");
    args.push_back("mp3");
    args.push_back("-o");
    args.push_back(global_path);
    args.push_back("--force-overwrites");
    args.push_back(url_to_download);
    
    Array dl_out;
    int32_t dl_ret = OS::get_singleton()->execute("yt-dlp", args, dl_out, false, true);
    
    {
        std::lock_guard<std::mutex> lock(audio_mutex);
        if (idx != current_playlist_index) {
            // This download was cancelled/superseded by a skip!
            return;
        }
        is_downloading_next = false;
        if (dl_ret == 0) {
            next_downloaded_file = cache_file;
        } else {
            next_downloaded_file = "";
        }
    }
    this->call_deferred("_play_next_playlist_item");
}


void LuaManager::_play_next_playlist_item() {
    std::lock_guard<std::mutex> lock(audio_mutex);
    if (!playlist_mode) return;
    
    if (next_downloaded_file == "" && current_playlist_index < playlist_ids.size()) {
        String cache_path = "user://yt_cache/" + playlist_ids[current_playlist_index] + ".mp3";
        if (FileAccess::file_exists(cache_path)) {
            next_downloaded_file = cache_path;
        }
    }
    
    if (next_downloaded_file != "") {
        audio_is_starting = true;
        this->call_deferred("_play_audio_dynamic_deferred", next_downloaded_file);
        next_downloaded_file = "";
        playing_playlist_index = current_playlist_index;
        current_playlist_index++;
        
        if (current_playlist_index < playlist_urls.size()) {
            is_downloading_next = true;
            skip_counter++;
            int my_skip = skip_counter.load();
            std::thread([this, my_skip]() {
                std::lock_guard<std::mutex> join_lock(this->download_join_mutex);
                if (my_skip != this->skip_counter.load()) return; // Abort if another skip happened while waiting
                
                std::shared_ptr<std::thread> old_thread;
                {
                    std::lock_guard<std::mutex> lock2(audio_mutex);
                    old_thread = download_thread;
                    download_thread = nullptr;
                }
                if (old_thread && old_thread->joinable()) {
                    old_thread->join();
                }
                
                if (my_skip != this->skip_counter.load()) return; // Abort if cancelled during join
                
                std::lock_guard<std::mutex> lock3(audio_mutex);
                current_download_skip_id = my_skip;
                download_thread = std::make_shared<std::thread>(&LuaManager::_download_next_playlist_item, this);
            }).detach();
        }
    } else if (!is_downloading_next && current_playlist_index < playlist_urls.size()) {
        if (!manual_skip) {
            current_playlist_index++;
        } else {
            manual_skip = false;
        }
        
        if (current_playlist_index < playlist_urls.size()) {
            is_downloading_next = true;
            skip_counter++;
            int my_skip = skip_counter.load();
            std::thread([this, my_skip]() {
                std::lock_guard<std::mutex> join_lock(this->download_join_mutex);
                if (my_skip != this->skip_counter.load()) return; // Abort if another skip happened while waiting
                
                std::shared_ptr<std::thread> old_thread;
                {
                    std::lock_guard<std::mutex> lock2(audio_mutex);
                    old_thread = download_thread;
                    download_thread = nullptr;
                }
                if (old_thread && old_thread->joinable()) {
                    old_thread->join();
                }
                
                if (my_skip != this->skip_counter.load()) return; // Abort if cancelled during join
                
                std::lock_guard<std::mutex> lock3(audio_mutex);
                current_download_skip_id = my_skip;
                download_thread = std::make_shared<std::thread>(&LuaManager::_download_next_playlist_item, this);
            }).detach();
        }
    }
}

void LuaManager::_download_next_playlist_item() {
    int my_dl_skip = current_download_skip_id.load();
    
    while (true) {
        String url;
        String yt_id;
        int idx = -1;
        {
            std::lock_guard<std::mutex> lock(audio_mutex);
            if (my_dl_skip != current_download_skip_id.load()) return;
            
            if (current_playlist_index < playlist_urls.size()) {
                String expected_path = "user://yt_cache/" + playlist_ids[current_playlist_index] + ".mp3";
                if (!FileAccess::file_exists(expected_path) && std::find(failed_downloads.begin(), failed_downloads.end(), playlist_ids[current_playlist_index]) == failed_downloads.end()) {
                    idx = current_playlist_index;
                }
            }
            
            if (idx == -1) {
                for (int i = 0; i < playlist_urls.size(); i++) {
                    String expected_path = "user://yt_cache/" + playlist_ids[i] + ".mp3";
                    if (!FileAccess::file_exists(expected_path) && std::find(failed_downloads.begin(), failed_downloads.end(), playlist_ids[i]) == failed_downloads.end()) {
                        idx = i;
                        break;
                    }
                }
            }
            
            if (idx == -1) {
                is_downloading_next = false;
                all_playlist_cached = true;
                return;
            }
            
            url = playlist_urls[idx];
            yt_id = playlist_ids[idx];
        }
        
        String cache_file = "user://yt_cache/" + yt_id + ".mp3";
        String global_path = ProjectSettings::get_singleton()->globalize_path(cache_file);
        
        PackedStringArray args;
        args.push_back("-x");
        args.push_back("--audio-format");
        args.push_back("mp3");
        args.push_back("-o");
        args.push_back(global_path);
        args.push_back("--force-overwrites");
        args.push_back(url);
        
        Array dl_out;
        int32_t dl_ret = OS::get_singleton()->execute("yt-dlp", args, dl_out, false, true);
        
        {
            std::lock_guard<std::mutex> lock(audio_mutex);
            if (my_dl_skip != current_download_skip_id.load()) return;
            
            if (dl_ret != 0) {
                failed_downloads.push_back(yt_id);
            }
            if (idx == current_playlist_index) {
                is_downloading_next = false;
                if (dl_ret == 0) {
                    next_downloaded_file = cache_file;
                } else {
                    next_downloaded_file = "";
                }
                return; // Let _process trigger _play_next_playlist_item to start playing and spawn a new wrapper thread for the rest
            }
        }
    }
}

void LuaManager::_check_audio_finished() {
    AudioStreamPlayer* player = nullptr;
    if (audio_player_id != 0) {
        Object* obj = ObjectDB::get_instance(audio_player_id);
        if (obj) player = Object::cast_to<AudioStreamPlayer>(obj);
    }
    
    if (audio_is_starting) return;
    if (player && !player->is_playing() && !player->get_stream_paused()) {
        _play_next_playlist_item();
    }
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
    } else if (p.ends_with(".ogg")) {
        stream = AudioStreamOggVorbis::load_from_file(p);
    } else if (p.ends_with(".wav")) {
        stream = AudioStreamWAV::load_from_file(p);
    }
    
    if (stream.is_valid()) {
        player->set_stream(stream);
        player->play();
    } else {
        UtilityFunctions::printerr("Failed to load dynamic audio: ", p);
    }
    
    {
        std::lock_guard<std::mutex> lock(audio_mutex);
        audio_is_starting = false;
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

void LuaManager::_pause_audio_deferred(bool paused) {
    if (audio_player_id != 0) {
        if (Object* obj = ObjectDB::get_instance(audio_player_id)) {
            if (AudioStreamPlayer* player = Object::cast_to<AudioStreamPlayer>(obj)) {
                player->set_stream_paused(paused);
            }
        }
    }
}

void LuaManager::_stop_audio_deferred() {
    if (audio_player_id != 0) {
        if (Object* obj = ObjectDB::get_instance(audio_player_id)) {
            if (AudioStreamPlayer* player = Object::cast_to<AudioStreamPlayer>(obj)) {
                player->play(0.0);
                player->set_stream_paused(true);
            }
        }
    }
}

void LuaManager::_skip_to_playlist_track(int idx) {
    {
        std::lock_guard<std::mutex> lock(audio_mutex);
        if (idx >= 0 && idx < playlist_urls.size()) {
            current_playlist_index = idx;
            playing_playlist_index = idx;
            next_downloaded_file = "";
            manual_skip = true;
            is_downloading_next = false;
            all_playlist_cached = false;
        }
    }
    
    if (audio_player_id != 0) {
        if (Object* obj = ObjectDB::get_instance(audio_player_id)) {
            if (AudioStreamPlayer* player = Object::cast_to<AudioStreamPlayer>(obj)) {
                player->set_stream_paused(false); // Make sure it's unpaused so _check_audio_finished triggers!
                player->stop();
            }
        }
    }
}

void LuaManager::_rewind_audio_deferred() {
    int prev_idx = 0;
    {
        std::lock_guard<std::mutex> lock(audio_mutex);
        if (current_playlist_index >= 2) {
            prev_idx = current_playlist_index - 2;
        }
    }
    this->call_deferred("_skip_to_playlist_track", prev_idx);
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
    set_process(true);
    set_process_input(true);
    
    godot::AudioServer* as = godot::AudioServer::get_singleton();
    int master_idx = as->get_bus_index("Master");
    audio_capture.instantiate();
    as->add_bus_effect(master_idx, audio_capture);
    
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
            bool success = this->_play_audio_deferred(String(filename.c_str()));
            if (sd) { 
                std::unique_lock<std::mutex> lock(sd->mtx); 
                sd->b_res = success;
                sd->done = true; 
                sd->cv.notify_one(); 
            }
        },
        // playAudioFunc
        [this]() { this->call_deferred("_pause_audio_deferred", false); },
        // stopAudioFunc
        [this]() { this->call_deferred("_stop_audio_deferred"); },
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
            String hs_path = OS::get_singleton()->get_environment("HOME") + "/.age/high.score";
            Ref<FileAccess> file = FileAccess::open(hs_path, FileAccess::READ);
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
            String hs_dir = OS::get_singleton()->get_environment("HOME") + "/.age";
            String hs_path = hs_dir + "/high.score";
            if (!DirAccess::dir_exists_absolute(hs_dir)) {
                DirAccess::make_dir_absolute(hs_dir);
            }
            Ref<FileAccess> file = FileAccess::open(hs_path, FileAccess::WRITE);
            if (file.is_valid()) {
                for (const auto& hs : this->highscores) {
                    file->store_line(hs.name + String(",") + String::num_int64(hs.score) + String(",") + String::num_int64(hs.level));
                }
            }
        }
    );

    lua_engine->nextAudioFunc = [this]() { 
        std::lock_guard<std::mutex> lock(audio_mutex);
        this->call_deferred("_skip_to_playlist_track", current_playlist_index);
    };
    
    lua_engine->pauseAudioFunc = [this]() { this->call_deferred("_pause_audio_deferred", true); };

    lua_engine->getPlaylistFunc = [this]() -> std::vector<std::string> {
        std::lock_guard<std::mutex> lock(audio_mutex);
        std::vector<std::string> res;
        for (int i = 0; i < playlist_titles.size(); i++) {
            res.push_back(std::string(playlist_titles[i].utf8().get_data()));
        }
        return res;
    };
    
    lua_engine->getPlaylistNameFunc = [this]() -> std::string {
        std::lock_guard<std::mutex> lock(audio_mutex);
        return std::string(playlist_name.utf8().get_data());
    };
    
    lua_engine->getPlaylistIndexFunc = [this]() -> int {
        std::lock_guard<std::mutex> lock(audio_mutex);
        return playing_playlist_index;
    };
    
    lua_engine->playPlaylistTrackFunc = [this](int idx) {
        this->call_deferred("_skip_to_playlist_track", idx);
    };

    lua_engine->setMenuCallbacks(
        [this](const std::string& name, int rows) { call_deferred("_begin_menu_deferred", String(name.c_str()), rows); },
        [this]() { call_deferred("_end_menu_deferred"); },
        [this](const std::string& name, int row) { call_deferred("_begin_row_deferred", String(name.c_str()), row); },
        [this](const std::string& name) { call_deferred("_end_row_deferred", String(name.c_str())); }
    );
    lua_engine->setSubMenuCallbacks(
        [this](const std::string& h) { call_deferred("_create_submenu_deferred", String(h.c_str())); },
        [this](const std::string& h) { call_deferred("_begin_submenu_deferred", String(h.c_str())); },
        [this](const std::string& h) { call_deferred("_end_submenu_deferred", String(h.c_str())); },
        [this](const std::string& h) { call_deferred("_enable_submenu_deferred", String(h.c_str())); },
        [this](const std::string& h) { call_deferred("_disable_submenu_deferred", String(h.c_str())); }
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
    
    InputEventKey* key_event = Object::cast_to<InputEventKey>(event.ptr());
    if (key_event && key_event->is_pressed() && !key_event->is_echo()) {
        Key k = key_event->get_keycode();
        if (k == Key::KEY_ESCAPE) {
            bool closed_submenu = false;
            for (auto& pair : submenus) {
                if (pair.second.is_active) {
                    call_deferred("_disable_submenu_deferred", pair.first);
                    closed_submenu = true;
                }
            }
            if (!closed_submenu) {
                if (main_menu_index >= 0 && main_menu_index < (int)menus.size()) {
                    MenuData& main_menu = menus[main_menu_index];
                    if (!main_menu.rows.empty() && !main_menu.rows.back().items.empty()) {
                        uint64_t quit_id = main_menu.rows.back().items.back();
                        if (interactive_bouncers.find(quit_id) != interactive_bouncers.end()) {
                            String script = interactive_bouncers[quit_id].clicked_script;
                            if (!script.is_empty()) {
                                if (script.ends_with(".lua")) {
                                    call_deferred("_clear_and_run_deferred", script);
                                } else {
                                    if (lua_engine) lua_engine->triggerCallback(script.utf8().get_data());
                                }
                            }
                        }
                    }
                }
            }
            return;
        }

        if (active_menu_index >= 0 && active_menu_index < menus.size()) {
            MenuData& m = menus[active_menu_index];
            if (!m.rows.empty()) {
                Key k = key_event->get_keycode();
                bool handled = false;
                
                int new_row = m.selected_row;
                
                if (k == Key::KEY_UP) { new_row--; handled = true; }
                else if (k == Key::KEY_DOWN) { new_row++; handled = true; }
                
                if (handled) {
                    if (new_row < 0) new_row = m.rows.size() - 1;
                    if (new_row >= (int)m.rows.size()) new_row = 0;
                    
                    // Keep finding a row that actually has items
                    int start_row = new_row;
                    while (m.rows[new_row].items.empty()) {
                        if (k == Key::KEY_UP) new_row--;
                        else new_row++;
                        
                        if (new_row < 0) new_row = m.rows.size() - 1;
                        if (new_row >= (int)m.rows.size()) new_row = 0;
                        if (new_row == start_row) break;
                    }
                    
                    if (!m.rows[new_row].items.empty()) {
                        int current_col = m.rows[new_row].selected_col;
                        _on_bouncer_mouse_entered(m.rows[new_row].items[current_col]);
                    }
                } else if (k == Key::KEY_LEFT || k == Key::KEY_RIGHT) {
                    if (m.selected_row >= 0 && m.selected_row < m.rows.size() && !m.rows[m.selected_row].items.empty()) {
                        MenuRow& r = m.rows[m.selected_row];
                        uint64_t current_id = r.items[r.selected_col];
                        
                        if (interactive_bouncers.count(current_id) && interactive_bouncers[current_id].is_selector) {
                            UISelector* selector = Object::cast_to<UISelector>(ObjectDB::get_instance(interactive_bouncers[current_id].selector_id));
                            if (selector) {
                                if (k == Key::KEY_LEFT) selector->_on_left_pressed();
                                else selector->_on_right_pressed();
                            }
                        } else {
                            int new_col = r.selected_col;
                            if (k == Key::KEY_LEFT) new_col--;
                            else new_col++;
                            
                            if (new_col < 0) new_col = r.items.size() - 1;
                            if (new_col >= (int)r.items.size()) new_col = 0;
                            
                            _on_bouncer_mouse_entered(r.items[new_col]);
                        }
                    }
                } else if (k == Key::KEY_ENTER || k == Key::KEY_SPACE) {
                    if (m.selected_row >= 0 && m.selected_row < m.rows.size() && !m.rows[m.selected_row].items.empty()) {
                        uint64_t current_id = m.rows[m.selected_row].items[m.rows[m.selected_row].selected_col];
                        if (interactive_bouncers.find(current_id) != interactive_bouncers.end()) {
                            String script = interactive_bouncers[current_id].clicked_script;
                            if (!script.is_empty()) {
                                if (script.ends_with(".lua")) {
                                    call_deferred("_clear_and_run_deferred", script);
                                } else {
                                    if (lua_engine) lua_engine->triggerCallback(script.utf8().get_data());
                                }
                            }
                        }
                    }
                }
            }
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
    if (playlist_mode) {
        _check_audio_finished();
    }
    
    // Auto-start next download if idle
    {
        std::lock_guard<std::mutex> lock(audio_mutex);
        if (playlist_mode && !is_downloading_next && !all_playlist_cached && next_downloaded_file == "" && current_playlist_index > 0 && current_playlist_index < playlist_urls.size()) {
            is_downloading_next = true; // Set flag early so _process doesn't trigger again
            skip_counter++;
            int my_skip = skip_counter.load();
            std::thread([this, my_skip]() {
                std::lock_guard<std::mutex> join_lock(this->download_join_mutex);
                std::shared_ptr<std::thread> old_thread;
                {
                    std::lock_guard<std::mutex> lock2(audio_mutex);
                    old_thread = download_thread;
                    download_thread = nullptr;
                }
                if (old_thread && old_thread->joinable()) {
                    old_thread->join();
                }
                std::lock_guard<std::mutex> lock3(audio_mutex);
                current_download_skip_id = my_skip;
                download_thread = std::make_shared<std::thread>(&LuaManager::_download_next_playlist_item, this);
            }).detach();
        }
    }
    for (auto it = videos_to_preload.begin(); it != videos_to_preload.end(); ) {
        Object* obj = ObjectDB::get_instance(*it);
        if (obj) {
            VideoStreamPlayer* vp = Object::cast_to<VideoStreamPlayer>(obj);
            if (vp && vp->is_playing() && !vp->is_paused()) {
                if (vp->get_stream_position() > 0.05) {
                    vp->set_paused(true);
                    it = videos_to_preload.erase(it);
                    continue;
                }
            } else if (!vp) {
                it = videos_to_preload.erase(it);
                continue;
            }
        } else {
            it = videos_to_preload.erase(it);
            continue;
        }
        ++it;
    }

    if (!pending_scene_load.is_empty()) {
        ResourceLoader::ThreadLoadStatus status = ResourceLoader::get_singleton()->load_threaded_get_status(pending_scene_load);
        if (status == ResourceLoader::THREAD_LOAD_IN_PROGRESS) {
            // Still loading, keep waiting
        } else if (status == ResourceLoader::THREAD_LOAD_LOADED) {
            Ref<PackedScene> scn = ResourceLoader::get_singleton()->load_threaded_get(pending_scene_load);
            if (scn.is_valid()) {
                Error err = get_tree()->change_scene_to_packed(scn);
                if (err != OK) {
                    UtilityFunctions::printerr("LuaManager failed to change scene asynchronously. Error code: ", err);
                }
            }
            pending_scene_load = "";
            if (pending_scene_sd) {
                std::unique_lock<std::mutex> lock(pending_scene_sd->mtx);
                pending_scene_sd->done = true;
                pending_scene_sd->cv.notify_one();
                pending_scene_sd = nullptr;
            }
        } else {
            UtilityFunctions::printerr("LuaManager failed to load scene asynchronously: ", pending_scene_load);
            pending_scene_load = "";
            if (pending_scene_sd) {
                std::unique_lock<std::mutex> lock(pending_scene_sd->mtx);
                pending_scene_sd->done = true;
                pending_scene_sd->cv.notify_one();
                pending_scene_sd = nullptr;
            }
        }
    }
    
    if (!pending_scene_load.is_empty()) {
        return; // Pause command execution until the scene finishes loading!
    }

    // Process Godot Command Queue one at a time so we can pause mid-execution
    while (true) {
        GodotCommand cmd;
        {
            std::lock_guard<std::mutex> lock(cmd_mutex);
            if (cmd_queue.empty()) break;
            cmd = cmd_queue.front();
            cmd_queue.erase(cmd_queue.begin());
        }
        
        if (!cmd.sd) continue;
        
        switch (cmd.cmd) {
            case LuaScripting::GCMD_SET_FULLSCREEN: {
                bool fullscreen = (cmd.args[0] > 0.5f);
                if (fullscreen) {
                    get_window()->set_mode(Window::MODE_FULLSCREEN);
                } else {
                    get_window()->set_mode(Window::MODE_WINDOWED);
                }
                break;
            }
            
            case LuaScripting::GCMD_LOAD_SCENE: {                String full_path = "res://" + cmd.name;
                UtilityFunctions::print("LuaManager delegating scene load to GDScript (Gemini Web approach): ", full_path);
                
                Node* ls = get_tree()->get_root()->get_node_or_null("LoadingScreen");
                if (ls) {
                    ls->call("switch_to_level", full_path);
                } else {
                    UtilityFunctions::printerr("LoadingScreen autoload not found!");
                }
                
                // Still need to unblock Lua thread, but we will let GDScript do it when it's done!
                pending_scene_sd = cmd.sd;
                return; // Stop processing further commands until this finishes!
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
                    loaded_nodes.push_back(inst->get_instance_id());
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
        if (godot::DisplayServer::get_singleton()->get_name() != "headless") {
            lua_engine->renderLuaImGui();
        }
        
        if (lua_engine->recorder.isRecording()) {
            if (lua_engine->recorder.canAcceptVideoFrame()) {
                godot::Ref<godot::Image> img = get_viewport()->get_texture()->get_image();
                if (img.is_valid()) {
                    int rw = lua_engine->recorder.getWidth();
                    int rh = lua_engine->recorder.getHeight();
                    if (img->get_width() != rw || img->get_height() != rh) {
                        img->resize(rw, rh);
                    }
                    if (img->get_format() != godot::Image::FORMAT_RGBA8) {
                        img->convert(godot::Image::FORMAT_RGBA8);
                    }
                    lua_engine->recorder.pushVideoFrame(img->get_data().ptr(), img->get_width() * 4);
                }
            }
        } // Audio is handled by pulse_thread in Recorder
    }

    for (auto it = dynamic_labels.begin(); it != dynamic_labels.end(); ) {
        Object* obj = ObjectDB::get_instance(it->label_id);
        if (!obj) {
            it = dynamic_labels.erase(it);
        } else {
            Label* label = Object::cast_to<Label>(obj);
            if (label) {
                label->set_text(_evaluate_bouncer_text(it->syntax));
            } else {
                RichTextLabel* rtl = Object::cast_to<RichTextLabel>(obj);
                if (rtl) {
                    rtl->set_text(_evaluate_bouncer_text(it->syntax));
                }
            }
            ++it;
        }
    }
    
    Rect2 vp_rect = get_viewport()->get_visible_rect();
    for (auto it = bouncer_physics.begin(); it != bouncer_physics.end(); ) {
        uint64_t id = it->first;
        BouncerPhysics& bp = it->second;
        Object* obj = ObjectDB::get_instance(id);
        if (!obj) {
            it = bouncer_physics.erase(it);
            continue;
        }
        
        Node2D* n2d = Object::cast_to<Node2D>(obj);
        if (!n2d) {
            ++it;
            continue;
        }

        if (bp.has_ttl) {
            bp.ttl -= delta;
            if (bp.ttl <= 0) {
                for (auto b_it = bouncers.begin(); b_it != bouncers.end(); ++b_it) {
                    if (*b_it == id) {
                        bouncers.erase(b_it);
                        break;
                    }
                }
                n2d->queue_free();
                it = bouncer_physics.erase(it);
                continue;
            }
        }
        
        if (bp.enabled) {
            Vector2 pos = n2d->get_position();
            
            if (bp.has_gravity) {
                bp.velocity.y += 980.0f * delta;
            }
            
            pos += bp.velocity * bp.speed * delta;
            
            if (bp.friction < 1.0f) {
                bp.velocity *= Math::pow((float)bp.friction, (float)(delta * 60.0));
            }
            
            Vector2 size = Vector2(0, 0);
            if (n2d->get_child_count() > 0) {
                Node* child = n2d->get_child(0);
                if (Control* ctrl = Object::cast_to<Control>(child)) {
                    size = ctrl->get_size() * ctrl->get_scale();
                }
            }
            
            if (pos.x < 0) { pos.x = 0; bp.velocity.x *= -1; }
            if (pos.y < 0) { pos.y = 0; bp.velocity.y *= -1; }
            if (pos.x + size.x > vp_rect.size.x) { pos.x = vp_rect.size.x - size.x; bp.velocity.x *= -1; }
            if (pos.y + size.y > vp_rect.size.y) { pos.y = vp_rect.size.y - size.y; bp.velocity.y *= -1; }
            
            n2d->set_position(pos);
        }
        ++it;
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


void UISelector::_bind_methods() {
    ClassDB::bind_method(D_METHOD("_on_left_pressed"), &UISelector::_on_left_pressed);
    ClassDB::bind_method(D_METHOD("_on_right_pressed"), &UISelector::_on_right_pressed);
}

void UISelector::_on_left_pressed() {
    if (subfolders.empty()) return;
    current_index--;
    if (current_index < 0) current_index = subfolders.size() - 1;
    update_media();
}

void UISelector::_on_right_pressed() {
    if (subfolders.empty()) return;
    current_index++;
    if (current_index >= subfolders.size()) current_index = 0;
    update_media();
}

void UISelector::update_media() {
    if (subfolders.empty() || !media_node) return;
    
    String current_sub = subfolders[current_index];
    String full_path = "res://" + folder + "/" + current_sub + "/" + filename;
    
    if (TextureRect* tr = Object::cast_to<TextureRect>(media_node)) {
        if (ResourceLoader::get_singleton()->exists(full_path)) {
            Ref<Texture2D> tex = ResourceLoader::get_singleton()->load(full_path);
            if (tex.is_valid()) {
                tr->set_texture(tex);
            }
        } else {
            // Try loading it raw from filesystem
            Ref<Image> img = Image::create_empty(1, 1, false, Image::FORMAT_RGBA8);
            if (img->load(full_path) == godot::OK) {
                Ref<ImageTexture> itex = ImageTexture::create_from_image(img);
                if (itex.is_valid()) tr->set_texture(itex);
            }
        }
    } else if (VideoStreamPlayer* vp = Object::cast_to<VideoStreamPlayer>(media_node)) {
        Ref<VideoStream> stream = ResourceLoader::get_singleton()->load(full_path);
        if (stream.is_valid()) {
            vp->set_stream(stream);
            vp->play();
        }
    }
    
    if (!global_var_name.is_empty()) {
        SceneTree* tree = Object::cast_to<SceneTree>(Engine::get_singleton()->get_main_loop());
        if (tree) {
            Node* lua_mgr = tree->get_root()->get_node_or_null(NodePath("LuaManager"));
            if (lua_mgr) {
                lua_mgr->call("set_global_string", global_var_name, current_sub);
            }
        }
    }
}

