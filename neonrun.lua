godotLoadScene("neonrun.tscn")

local inner = "255, 0, 255"       -- White inner
local outer = "0, 0, 0"             -- Black border
local hover = "0, 255, 255"         -- Neon purple hover

local g_tag = "[graffity: " .. inner .. ", " .. outer .. ", " .. hover .. "]"

function on_race()
    print("Race clicked!")
end

function on_time_trial()
    print("Time Trial clicked!")
end

function on_play_ground()
    print("Play Ground clicked!")
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
    print("Quit clicked!")
    -- appQuit() or similar
end

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
