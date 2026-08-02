print("***************************")
print("*        GAME OVER        *")
print("***************************")

setBG("[plasma: 3]")

local score = getGlobalVar("score")
local level = getGlobalVar("level")

setAudioVolume(100)

local hs_entered = getGlobalVar("hs_entered") or 0

if godotIsHighScore(score) and hs_entered == 0 then
    addBouncer("[layer:1][rect: 270,350][pos: 380,200][addhscore:18," .. score .. "," .. level .. "]")
    addBouncer("[layer:2][ttl:10000][phys: 250,250,50,50,1,1][fontsize: 0.6][rgb:255,122,255]You Got[lf][rgb:251,222,155]High Score[rgb:255,255,255][image:geekt.png]")
    
    -- Wait for input or timeout
    delayKb(10000)
    rewindAudio()
    luaClearAndRun("startspace.lua")
else
    if hs_entered == 1 then
        addBouncer("[layer:1][rect: 270,350][pos: 380,200][hscore: 18]")
        delayKb(10000)
        setGlobalVar("hs_entered", 0)
    else
        addBouncer("[layer:2][phys: 150,500,200,100,1,1][rgb: 255,255,0]You Snooze")
        addBouncer("[layer:2][phys: 150,500,200,400,1,1][rgb: 0,255,255]You Looze")
        addBouncer("[layer:2][phys: 600,600,300,400,1,1][image:kitt.png]")
        addBouncer("[layer:1][rect: 270,350][pos: 380,200][hscore: 18]")
        delayKb(5000)
    end
    rewindAudio()
    luaClearAndRun("startspace.lua")
end
