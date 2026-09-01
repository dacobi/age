regGlobalFloat("editor_param_5", 80.0) -- End Width
regGlobalFloat("editor_param_6", 45.0)  -- Ramp Angle
regGlobalFloat("editor_param_gap_length", 50.0) -- Gap Length
regGlobalFloat("editor_param_ramp_size", 20.0) -- Ramp Size
regGlobalFloat("editor_action", 0.0)

regGlobalFloat("editor_param_length", 90.0)
regGlobalFloat("editor_param_angle", 90.0)
regGlobalFloat("editor_param_2", 80.0)  -- Width
regGlobalFloat("editor_param_3", 100.0) -- Radius (for curves)
regGlobalFloat("editor_param_incline", 0.0)
regGlobalFloat("editor_swap_angle", 0.0)
regGlobalFloat("editor_swap_incline", 0.0)
regGlobalFloat("editor_param_drop", 0.0)

regGlobalFloat("editor_clear", 0.0)
regGlobalFloat("editor_show_final", 0.0)

print("Starting Track Editor UI...")
godotLoadScene("track_editor.tscn")

function renderEditorUI()
    imguiBegin("Track Editor")
    
    imguiText("Procedural Track Builder")
    imguiSeparator()
    
    imguiText("Element Parameters:")
    imguiSliderFloat("Length", "editor_param_length", 1.0, 500.0)
    imguiSliderFloat("Angle", "editor_param_angle", -180.0, 180.0)
    imguiSameLine()
    imguiButton("Swap Angle", "editor_swap_angle")
    
    imguiSliderFloat("Width (Start)", "editor_param_2", 10.0, 200.0)
    imguiSliderFloat("Width (End)", "editor_param_5", 10.0, 200.0)
    imguiSliderFloat("Radius (Curve)", "editor_param_3", 10.0, 500.0)
    
    imguiSliderFloat("Incline", "editor_param_incline", -90.0, 90.0)
    imguiSameLine()
    imguiButton("Swap Incline", "editor_swap_incline")
    imguiSliderFloat("Drop", "editor_param_drop", -100.0, 0.0)
    
    imguiSliderFloat("Ramp Angle", "editor_param_6", 0.0, 60.0)
    imguiSliderFloat("Gap Length", "editor_param_gap_length", 10.0, 300.0)
    imguiSliderFloat("Ramp Size", "editor_param_ramp_size", 5.0, 100.0)
    
    imguiSeparator()
    imguiText("Add Elements:")
    
    imguiButton("Add Straight", "editor_action_straight")
    
    imguiSameLine()
    
    imguiButton("Add Curve", "editor_action_curve")
    
    imguiButton("Right Angle Left", "editor_action_ral")
    imguiSameLine()
    imguiButton("Right Angle Right", "editor_action_rar")
    
    imguiSameLine()
    imguiButton("Add Drop", "editor_action_drop")
    
    
    imguiButton("Add Transition", "editor_action_trans")
    imguiSameLine()
    imguiButton("Bank Trans", "editor_action_bank_trans")
    
    
    imguiSameLine()
    imguiButton("Add Gate", "editor_action_gate")
    imguiSameLine()
    imguiButton("Flip Gate", "editor_action_flip_gate")
    imguiSameLine()
    imguiButton("Add Gap", "editor_action_gap")
    
    imguiSameLine()
    imguiButton("Close Loop", "editor_action_close")
        
    imguiSeparator()
    imguiSeparator()
    imguiSeparator()
    imguiText("Hole Mode Controls:")
    imguiCheckbox("Select Undo Mode", "editor_select_undo_mode")
    imguiSameLine()
    imguiButton("Flip Build Dir", "editor_action_flip_dir")
    imguiButton("Close Hole", "editor_action_spline_trans")
    imguiSeparator()
    imguiButton("Save JSON", "editor_action_save")
    imguiSameLine()
    imguiButton("Load JSON", "editor_action_load")
    
    
    imguiButton("Clear Track", "editor_clear")
    imguiSameLine()
    imguiButton("Undo", "editor_action_undo")
    imguiSameLine()
    imguiButton("Redo", "editor_action_redo")
    
    imguiSeparator()
    imguiCheckbox("Show Final", "editor_show_final")
    
    imguiEnd()
end

while true do
    renderEditorUI()


    local btn_flip = getGlobalFloat("editor_action_flip_dir")
    if btn_flip > 0.5 then
        setGlobalFloat("editor_action", 15.0)
        setGlobalFloat("editor_action_flip_dir", 0.0)
    end

    local btn_spline = getGlobalFloat("editor_action_spline_trans")
    if btn_spline > 0.5 then
        setGlobalFloat("editor_action", 16.0)
        setGlobalFloat("editor_action_spline_trans", 0.0)
    end

    local btn_straight = getGlobalFloat("editor_action_straight")
    if btn_straight > 0.5 then
        setGlobalFloat("editor_action", 1.0)
        setGlobalFloat("editor_action_straight", 0.0)
    end

    local swap_a = getGlobalFloat("editor_swap_angle")
    if swap_a > 0.5 then
        setGlobalFloat("editor_param_angle", -getGlobalFloat("editor_param_angle"))
        setGlobalFloat("editor_swap_angle", 0.0)
    end

    local swap_i = getGlobalFloat("editor_swap_incline")
    if swap_i > 0.5 then
        setGlobalFloat("editor_param_incline", -getGlobalFloat("editor_param_incline"))
        setGlobalFloat("editor_swap_incline", 0.0)
    end

    local btn_curve = getGlobalFloat("editor_action_curve")
    if btn_curve > 0.5 then
        setGlobalFloat("editor_action", 2.0)
        setGlobalFloat("editor_action_curve", 0.0)
    end   

    local btn_drop = getGlobalFloat("editor_action_drop")
    if btn_drop > 0.5 then
        setGlobalFloat("editor_action", 3.0)
        setGlobalFloat("editor_action_drop", 0.0)
    end

    local btn_trans = getGlobalFloat("editor_action_trans")
    if btn_trans > 0.5 then
        setGlobalFloat("editor_action", 4.0)
        setGlobalFloat("editor_action_trans", 0.0)
    end

    local btn_bank = getGlobalFloat("editor_action_bank_trans")
    if btn_bank > 0.5 then
        setGlobalFloat("editor_action", 9.0)
        setGlobalFloat("editor_action_bank_trans", 0.0)
    end

    local btn_gap = getGlobalFloat("editor_action_gap")
    if btn_gap > 0.5 then
        setGlobalFloat("editor_action", 6.0)
        setGlobalFloat("editor_action_gap", 0.0)
    end

    local btn_close = getGlobalFloat("editor_action_close")
    if btn_close > 0.5 then
        setGlobalFloat("editor_action", 7.0)
        setGlobalFloat("editor_action_close", 0.0)
    end

    local btn_gate = getGlobalFloat("editor_action_gate")
    if btn_gate > 0.5 then
        setGlobalFloat("editor_action", 5.0)
        setGlobalFloat("editor_action_gate", 0.0)
    end

    if getGlobalFloat("editor_action_flip_gate") > 0.5 then
        setGlobalFloat("editor_action", 15.0)
        setGlobalFloat("editor_action_flip_gate", 0.0)
    end

    if getGlobalFloat("editor_action_save") > 0.5 then
        setGlobalFloat("editor_action", 10.0)
        setGlobalFloat("editor_action_save", 0.0)
    end
    if getGlobalFloat("editor_action_load") > 0.5 then
        setGlobalFloat("editor_action", 11.0)
        setGlobalFloat("editor_action_load", 0.0)
    end
    if getGlobalFloat("editor_action_undo") > 0.5 then
        setGlobalFloat("editor_action", 12.0)
        setGlobalFloat("editor_action_undo", 0.0)
    end
    if getGlobalFloat("editor_action_redo") > 0.5 then
        setGlobalFloat("editor_action", 17.0)
        setGlobalFloat("editor_action_redo", 0.0)
    end

    if getGlobalFloat("editor_action_ral") > 0.5 then
        setGlobalFloat("editor_action", 13.0)
        setGlobalFloat("editor_action_ral", 0.0)
    end

    if getGlobalFloat("editor_action_rar") > 0.5 then
        setGlobalFloat("editor_action", 14.0)
        setGlobalFloat("editor_action_rar", 0.0)
    end

    delay(1)
end
