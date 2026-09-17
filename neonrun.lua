	godotLoadScene("neonrun.tscn")

local inner = "255, 0, 255"       -- White inner
local outer = "0, 0, 0"             -- Black border
local hover = "0, 255, 255"         -- Neon purple hover

local g_tag = "[graffity: " .. inner .. ", " .. outer .. ", " .. hover .. "]"

function on_time_trial()
    print("Time Trial clicked!")
    ageEnableSubMenu("TimeT")
end

function on_time_trial_play()
    print("Time Trial Play clicked!")
end

function on_time_trial_cancel()
    print("Time Trial Canceled")
    ageDisableSubMenu("TimeT")
end


function on_play_ground()
    print("Play Ground clicked!")
    ageEnableSubMenu("PlayG")
end

function on_play_ground_play()
    print("Play Ground Play clicked!")
end

function on_play_ground_cancel()
    print("Play Ground Canceled")
    ageDisableSubMenu("PlayG")
end


function on_settings()
    print("Settings clicked!")
end

function on_about()
    print("About clicked!")
end

function on_arcade()
    print("Arcade clicked!")
end

function on_quit()
    ageEnableSubMenu("Quit")
    -- appQuit() or similar
end

function on_sub_quit()
    print("Quit clicked!")
    appQuit()
end

function on_sub_cancel()
    print("Quit clicked")
    ageDisableSubMenu("Quit")
end

function on_race()
    ageEnableSubMenu("Race")    
    print("Race clicked!")
end

function on_race_play()
    print("Race Play clicked!")
end

function on_race_cancel()
    print("Race Canceled")
    ageDisableSubMenu("Race")
end

-- Create the submenu
ageCreateSubMenu("Quit")
ageBeginSubMenu("Quit")
ageBeginMenu()
-- addBouncer("[ SUBMENU: SETTINGS ]", 400, 100, 0, 0, 0, 0, "font=docallismeonstreet.otf;size=50;color=FFFF00", nil)
addBouncer(g_tag .. "[pos:700, 700][fontsize:1.5][clicked:on_sub_quit][layer:1]Quit")
addBouncer(g_tag .. "[pos:900, 700][fontsize:1.5][clicked:on_sub_cancel][layer:1]Cancel")
ageEndMenu()
ageEndSubMenu("Quit")


ageCreateSubMenu("Race")
ageBeginSubMenu("Race")
addBouncer("[pos:700,400][rect:400,300][hover:255,255,255][clicked:on_race_play][layer:1][layer:1][video:track.ogv]")
ageBeginMenu()
addBouncer(g_tag .. "[pos:600, 800][fontsize:1.5][clicked:on_race_play][layer:1]Play")
addBouncer(g_tag .. "[pos:900, 800][fontsize:1.5][clicked:on_race_cancel][layer:1]Cancel")
ageEndMenu()
ageEndSubMenu("Race")


ageCreateSubMenu("TimeT")
ageBeginSubMenu("TimeT")
addBouncer("[pos:700,400][rect:400,300][hover:255,255,255][clicked:on_time_trial_play][layer:1][layer:1][video:track.ogv]")
ageBeginMenu()
addBouncer(g_tag .. "[pos:600, 800][fontsize:1.5][clicked:on_time_trial_play][layer:1]Play")
addBouncer(g_tag .. "[pos:900, 800][fontsize:1.5][clicked:on_time_trial_cancel][layer:1]Cancel")
ageEndMenu()
ageEndSubMenu("TimeT")

ageCreateSubMenu("PlayG")
ageBeginSubMenu("PlayG")
addBouncer("[pos:700,400][rect:400,300][hover:255,255,255][clicked:on_play_ground_play][layer:1][layer:1][video:area.ogv]")
ageBeginMenu()
addBouncer(g_tag .. "[pos:600, 800][fontsize:1.5][clicked:on_play_ground_play][layer:1]Play")
addBouncer(g_tag .. "[pos:900, 800][fontsize:1.5][clicked:on_play_ground_cancel][layer:1]Cancel")
ageEndMenu()
ageEndSubMenu("PlayG")

ageBeginMenu()
addBouncer(g_tag .. "[pos:100, 400][fontsize:1.5][clicked:on_race][layer:1]Race")
addBouncer(g_tag .. "[pos:100, 500][fontsize:1.5][clicked:on_time_trial][layer:1]Time Trial")
addBouncer(g_tag .. "[pos:100, 600][fontsize:1.5][clicked:on_play_ground][layer:1]Play Ground")
addBouncer(g_tag .. "[pos:100, 700][fontsize:1.5][clicked:on_settings][layer:1]Settings")
addBouncer(g_tag .. "[pos:100, 800][fontsize:1.5][clicked:on_about][layer:1]About")
addBouncer(g_tag .. "[pos:100, 900][fontsize:1.5][clicked:on_arcade][layer:1]Arcade")
addBouncer(g_tag .. "[pos:100, 1000][fontsize:1.5][clicked:on_quit][layer:1]Quit")
ageEndMenu()

while true do
    delay(16)
end
