print("Starting automated car video generation...")

local base_path = "./assets/cars/"
local dirs = getSubDirs(base_path)

for i, dir in ipairs(dirs) do
    local folder_path = base_path .. dir
    local files = getDirContent(folder_path)
    
    -- Check if this folder has a view.tscn
    local has_view = false
    for j, f in ipairs(files) do
        if f.name == "view.tscn" then
            has_view = true
            break
        end
    end
    
    if has_view then
        local scene_path = folder_path .. "/view.tscn"
        local ogv_path = folder_path .. "/car.ogv"
        
        print("Loading scene: " .. scene_path)
        godotLoadScene(scene_path)
        
        -- Wait 3 seconds for the scene to load, the CSG to compile, and the car to drop/settle
        delay(3000)
        
        print("Recording 30s video to: " .. ogv_path)
        setRecordMax(30)
        startRecord(ogv_path)
        
        -- Wait 31 seconds to ensure the recorder naturally stops at the 30s max limit
        delay(31000)
        print("Finished recording: " .. dir)
    else
        print("Skipping " .. dir .. " (no view.tscn found)")
    end
end

print("All car videos generated successfully!")
appQuit()
