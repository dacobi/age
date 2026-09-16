godotLoadScene("neonrun.tscn")

local inner = "255, 0, 255"       -- White inner
local outer = "0, 0, 0"             -- Black border
local hover = "0, 255, 255"         -- Neon purple hover

local g_tag = "[graffity: " .. inner .. ", " .. outer .. ", " .. hover .. "]"

addBouncer(g_tag .. "[pos:100, 400][fontsize:1.5][clicked:time_trial.lua][layer:1]Race")
addBouncer(g_tag .. "[pos:100, 500][fontsize:1.5][clicked:time_trial.lua][layer:1]Time Trial")
addBouncer(g_tag .. "[pos:100, 600][fontsize:1.5][clicked:play_ground.lua][layer:1]Play Ground")
addBouncer(g_tag .. "[pos:100, 700][fontsize:1.5][clicked:settings.lua][layer:1]Settings")
addBouncer(g_tag .. "[pos:100, 800][fontsize:1.5][clicked:about.lua][layer:1]About")
addBouncer(g_tag .. "[pos:100, 900][fontsize:1.5][clicked:arcade.lua][layer:1]Arcade")
addBouncer(g_tag .. "[pos:100, 1000][fontsize:1.5][clicked:arcade.lua][layer:1]Quit")
