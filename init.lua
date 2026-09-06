for i=1, 56 do
    regGlobalFloat("ce_vert_"..i.."_x", 0.0)
    regGlobalFloat("ce_vert_"..i.."_y", 0.0)
end
regGlobalFloat("ce_spine_px", 0.0); regGlobalFloat("ce_spine_py", 0.0); regGlobalFloat("ce_spine_pz", 0.0)
regGlobalFloat("ce_spine_inx", 0.0); regGlobalFloat("ce_spine_iny", 0.0); regGlobalFloat("ce_spine_inz", 0.0)
regGlobalFloat("ce_spine_outx", 0.0); regGlobalFloat("ce_spine_outy", 0.0); regGlobalFloat("ce_spine_outz", 0.0)
regGlobalFloat("ce_kf_t", 0.0)
regGlobalFloat("ce_prim_px", 0.0); regGlobalFloat("ce_prim_py", 0.0); regGlobalFloat("ce_prim_pz", 0.0)
regGlobalFloat("ce_prim_rx", 0.0); regGlobalFloat("ce_prim_ry", 0.0); regGlobalFloat("ce_prim_rz", 0.0)
regGlobalFloat("ce_prim_sx", 1.0); regGlobalFloat("ce_prim_sy", 1.0); regGlobalFloat("ce_prim_sz", 1.0)
regGlobalVar("ce_prim_op", 0)

regGlobalFloat("ce_cmd_add_spine", 0.0)
regGlobalFloat("ce_cmd_del_spine", 0.0)
regGlobalFloat("ce_cmd_add_kf", 0.0)
regGlobalFloat("ce_cmd_del_kf", 0.0)
regGlobalFloat("ce_cmd_add_box", 0.0)
regGlobalFloat("ce_cmd_add_cyl", 0.0)
regGlobalFloat("ce_cmd_add_sph", 0.0)
regGlobalFloat("ce_cmd_del_prim", 0.0)

regGlobalFloat("ce_cmd_undo", 0.0)
regGlobalFloat("ce_cmd_redo", 0.0)

regGlobalFloat("ce_spine_count", 0.0)
regGlobalFloat("ce_kf_count", 0.0)
regGlobalFloat("ce_prim_count", 0.0)


regGlobalFloat("ce_file_loaded", 0.0)
regGlobalFloat("ce_trigger_open", 0.0)
regGlobalFloat("ce_trigger_save", 0.0)
regGlobalFloat("ce_trigger_save_as", 0.0)
regGlobalFloat("ce_trigger_new_car", 0.0)
regGlobalFloat("ce_new_car_verts", 56.0)
regGlobalFloat("ce_new_car_shape", 0.0)
regGlobalFloat("ce_trigger_copy_kf", 0.0)
regGlobalFloat("ce_trigger_scale_kf", 0.0)
regGlobalFloat("ce_kf_scale_x", 1.0)
regGlobalFloat("ce_kf_scale_y", 1.0)

regGlobalFloat("ce_selected_mode", 1.0) -- 1=Spine, 2=KF, 3=Prim
regGlobalFloat("ce_selected_spine", 1.0)
regGlobalFloat("ce_selected_kf", 1.0)
regGlobalFloat("ce_selected_vert", 1.0)
regGlobalFloat("ce_sel_v_x", 0.0)
regGlobalFloat("ce_sel_v_y", 1.0)
regGlobalFloat("ce_selected_prim", 1.0)

local show_verts = false

godotLoadScene("car_editor.tscn")

regGlobalFloat("ce_btn_mode_1", 0.0)
regGlobalFloat("ce_btn_mode_2", 0.0)
regGlobalFloat("ce_btn_mode_3", 0.0)
regGlobalFloat("ce_btn_prev", 0.0)
regGlobalFloat("ce_btn_next", 0.0)
regGlobalFloat("ce_btn_show_verts", 0.0)
regGlobalVar("ce_tmp_verts", 56)

while true do
    imguiBegin("Car Editor")
    
    local ui_mode = math.floor(getGlobalFloat("ce_selected_mode"))
    local spine_count = math.floor(getGlobalFloat("ce_spine_count"))
    local kf_count = math.floor(getGlobalFloat("ce_kf_count"))
    local prim_count = math.floor(getGlobalFloat("ce_prim_count"))
    
    local sel_spine = math.floor(getGlobalFloat("ce_selected_spine"))
    local sel_kf = math.floor(getGlobalFloat("ce_selected_kf"))
    local sel_prim = math.floor(getGlobalFloat("ce_selected_prim"))
    
    imguiButton("Spine Mode", "ce_btn_mode_1")
    if getGlobalFloat("ce_btn_mode_1") > 0.5 then setGlobalFloat("ce_btn_mode_1", 0.0); setGlobalFloat("ce_selected_mode", 1.0) end
    imguiSameLine()
    imguiButton("Keyframes Mode", "ce_btn_mode_2")
    if getGlobalFloat("ce_btn_mode_2") > 0.5 then setGlobalFloat("ce_btn_mode_2", 0.0); setGlobalFloat("ce_selected_mode", 2.0) end
    imguiSameLine()
    imguiButton("Primitives Mode", "ce_btn_mode_3")
    if getGlobalFloat("ce_btn_mode_3") > 0.5 then setGlobalFloat("ce_btn_mode_3", 0.0); setGlobalFloat("ce_selected_mode", 3.0) end
    
    imguiSameLine()
    imguiButton("Undo", "ce_cmd_undo")
    if getGlobalFloat("ce_cmd_undo") > 0.5 then setGlobalFloat("ce_cmd_undo", 1.0) end
    imguiSameLine()
    imguiButton("Redo", "ce_cmd_redo")
    if getGlobalFloat("ce_cmd_redo") > 0.5 then setGlobalFloat("ce_cmd_redo", 1.0) end
    
    imguiSeparator()
    
    if ui_mode == 1 then
        imguiText("--- Spine Editor ---")
        imguiText("Editing Spine Point: Index " .. sel_spine .. " (Total: " .. spine_count .. ")")
        
        imguiButton("Prev Pt", "ce_btn_prev")
        if getGlobalFloat("ce_btn_prev") > 0.5 then
            setGlobalFloat("ce_btn_prev", 0.0)
            if sel_spine > 1 then setGlobalFloat("ce_selected_spine", sel_spine - 1) end
        end
        imguiSameLine()
        imguiButton("Next Pt", "ce_btn_next")
        if getGlobalFloat("ce_btn_next") > 0.5 then
            setGlobalFloat("ce_btn_next", 0.0)
            if sel_spine < spine_count then setGlobalFloat("ce_selected_spine", sel_spine + 1) end
        end
        imguiSameLine()
        imguiButton("Add Spine Point", "ce_cmd_add_spine")
        if getGlobalFloat("ce_cmd_add_spine") > 0.5 then setGlobalFloat("ce_cmd_add_spine", 1.0) end
        imguiButton("Delete Spine Point", "ce_cmd_del_spine")
        if getGlobalFloat("ce_cmd_del_spine") > 0.5 then setGlobalFloat("ce_cmd_del_spine", 1.0) end
        
        imguiButton(show_verts and "Hide Position Sliders" or "Show Position Sliders", "ce_btn_show_verts")
        if getGlobalFloat("ce_btn_show_verts") > 0.5 then
            setGlobalFloat("ce_btn_show_verts", 0.0)
            show_verts = not show_verts
        end
        if show_verts then
            imguiSliderFloat("Pos X", "ce_spine_px", -10.0, 10.0)
            imguiSliderFloat("Pos Y", "ce_spine_py", -10.0, 10.0)
            imguiSliderFloat("Pos Z", "ce_spine_pz", -10.0, 10.0)
            imguiSliderFloat("In X", "ce_spine_inx", -5.0, 5.0)
            imguiSliderFloat("In Y", "ce_spine_iny", -5.0, 5.0)
            imguiSliderFloat("In Z", "ce_spine_inz", -5.0, 5.0)
            imguiSliderFloat("Out X", "ce_spine_outx", -5.0, 5.0)
            imguiSliderFloat("Out Y", "ce_spine_outy", -5.0, 5.0)
            imguiSliderFloat("Out Z", "ce_spine_outz", -5.0, 5.0)
        end
        
    elseif ui_mode == 2 then
        imguiText("--- Keyframes Editor ---")
        
        imguiText("Selected KF: " .. sel_kf .. " / " .. kf_count)
        imguiButton("Prev KF", "ce_btn_prev")
        if getGlobalFloat("ce_btn_prev") > 0.5 then
            setGlobalFloat("ce_btn_prev", 0.0)
            if sel_kf > 1 then setGlobalFloat("ce_selected_kf", sel_kf - 1) end
        end
        imguiSameLine()
        imguiButton("Next KF", "ce_btn_next")
        if getGlobalFloat("ce_btn_next") > 0.5 then
            setGlobalFloat("ce_btn_next", 0.0)
            if sel_kf < kf_count then setGlobalFloat("ce_selected_kf", sel_kf + 1) end
        end
        imguiSameLine()
        imguiButton("Add Keyframe", "ce_cmd_add_kf")
        if getGlobalFloat("ce_cmd_add_kf") > 0.5 then setGlobalFloat("ce_cmd_add_kf", 1.0) end
        imguiButton("Delete Keyframe", "ce_cmd_del_kf")
        if getGlobalFloat("ce_cmd_del_kf") > 0.5 then setGlobalFloat("ce_cmd_del_kf", 1.0) end
        
        imguiSliderFloat("T (Offset)", "ce_kf_t", 0.0, 1.0)
        
        imguiButton(show_verts and "Hide Vertex Positions" or "Show Vertex Positions", "ce_btn_show_verts")
        if getGlobalFloat("ce_btn_show_verts") > 0.5 then
            setGlobalFloat("ce_btn_show_verts", 0.0)
            show_verts = not show_verts
        end
        
        if show_verts then
            local sel_vert = math.floor(getGlobalFloat("ce_selected_vert"))
            imguiText("Selected Vertex: " .. sel_vert)
            
            if imguiButton("Prev Vert") then
                if sel_vert > 1 then setGlobalFloat("ce_selected_vert", sel_vert - 1) end
            end
            imguiSameLine()
            if imguiButton("Next Vert") then
                if sel_vert < 56 then setGlobalFloat("ce_selected_vert", sel_vert + 1) end
            end

            imguiSliderFloat("Vert X", "ce_sel_v_x", 0.0, 10.0)
            imguiSliderFloat("Vert Y", "ce_sel_v_y", -10.0, 10.0)
        end
        
    elseif ui_mode == 3 then
        imguiText("--- CSG Primitives ---")
        imguiText("Selected Prim: " .. sel_prim .. " / " .. prim_count)
        
        imguiButton("Prev Prim", "ce_btn_prev")
        if getGlobalFloat("ce_btn_prev") > 0.5 then
            setGlobalFloat("ce_btn_prev", 0.0)
            if sel_prim > 1 then setGlobalFloat("ce_selected_prim", sel_prim - 1) end
        end
        imguiSameLine()
        imguiButton("Next Prim", "ce_btn_next")
        if getGlobalFloat("ce_btn_next") > 0.5 then
            setGlobalFloat("ce_btn_next", 0.0)
            if sel_prim < prim_count then setGlobalFloat("ce_selected_prim", sel_prim + 1) end
        end
        
        imguiButton("Add Box", "ce_cmd_add_box")
        if getGlobalFloat("ce_cmd_add_box") > 0.5 then setGlobalFloat("ce_cmd_add_box", 1.0) end
        imguiSameLine()
        imguiButton("Add Cylinder", "ce_cmd_add_cyl")
        if getGlobalFloat("ce_cmd_add_cyl") > 0.5 then setGlobalFloat("ce_cmd_add_cyl", 1.0) end
        imguiSameLine()
        imguiButton("Add Sphere", "ce_cmd_add_sph")
        if getGlobalFloat("ce_cmd_add_sph") > 0.5 then setGlobalFloat("ce_cmd_add_sph", 1.0) end
        
        if prim_count > 0 then
            imguiSliderInt("Operation (0=U, 1=S, 2=I)", "ce_prim_op", 0, 2)
            imguiSliderFloat("Pos X", "ce_prim_px", -10.0, 10.0)
            imguiSliderFloat("Pos Y", "ce_prim_py", -10.0, 10.0)
            imguiSliderFloat("Pos Z", "ce_prim_pz", -10.0, 10.0)
            imguiSliderFloat("Rot X", "ce_prim_rx", -180.0, 180.0)
            imguiSliderFloat("Rot Y", "ce_prim_ry", -180.0, 180.0)
            imguiSliderFloat("Rot Z", "ce_prim_rz", -180.0, 180.0)
            imguiSliderFloat("Size/Rad", "ce_prim_sx", 0.1, 10.0)
            imguiSliderFloat("Size/Height", "ce_prim_sy", 0.1, 10.0)
            imguiSliderFloat("Size Z", "ce_prim_sz", 0.1, 10.0)
            
            imguiButton("Delete Prim", "ce_cmd_del_prim")
            if getGlobalFloat("ce_cmd_del_prim") > 0.5 then setGlobalFloat("ce_cmd_del_prim", 1.0) end
        end
    end
    
    imguiEnd()
    delay(1)
end
