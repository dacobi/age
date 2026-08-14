godotLoadScene("race_track.tscn")

delay(200)

print("\n=== AI Racing Mode ===")
print("You are racing against the AI that you trained.")
print("The camera will follow your car.")
print("Press ESC to exit.\n")

setAudioVolume(50)

-- Get the supercar node pointer
godotSelectRoot()
local supercar = godotGetNodePointer("SuperCar")

-- Include shared car physics and controls
dofile("car_common.lua")
initCarPhysicsDefaults()

local joy_handle = ioJoystickOpen(0)
if joy_handle >= 0 then
	print("Joystick 0 connected for driving!")
end

local is_paused = false
local orbit_yaw = 0.0
local orbit_pitch = 0.5
local orbit_dist = 12.0

local frame_count = 0

while true do
	-- Draw Car Physics dialog if show_car_physics_ui is enabled
	renderCarPhysicsUI()

	-- Handle Q to quit
	if ioKBClicked("SDLK_q") then
		print("Exiting game logic...")
		break
	end

	local track = godotGetNodePointer("MegaRacerScene")
	
	if ioKBClicked("SDLK_ESCAPE") then
		is_paused = not is_paused
		
		godotSetProperty("is_paused", is_paused, track)
		
		if is_paused then
			if supercar then godotSetProperty("process_mode", 4, supercar) end
			ioMouseCapture()
		else
			if supercar then godotSetProperty("process_mode", 0, supercar) end
			ioMouseRelease()
		end
	end

	if supercar then
		if is_paused then
			local dx, dy = ioMouseGetMotion()
			orbit_yaw = orbit_yaw - dx * 0.005
			orbit_pitch = orbit_pitch + dy * 0.005
			
			if orbit_pitch > 1.5 then orbit_pitch = 1.5 end
			if orbit_pitch < -1.5 then orbit_pitch = -1.5 end
			
			local wheel = ioMouseWheelMotion()
			if wheel then
				orbit_dist = orbit_dist - wheel * 2.0
			end
			
			if ioKBDown("w") then orbit_dist = orbit_dist - 0.5 end
			if ioKBDown("s") then orbit_dist = orbit_dist + 0.5 end
			
			if orbit_dist < 3.0 then orbit_dist = 3.0 end
			if orbit_dist > 50.0 then orbit_dist = 50.0 end
			
			godotSetProperty("orbit_yaw", orbit_yaw, track)
			godotSetProperty("orbit_pitch", orbit_pitch, track)
			godotSetProperty("orbit_dist", orbit_dist, track)
		else
			updateCarControlsAndPhysics(supercar, joy_handle, track, "reset_game")
			frame_count = frame_count + 1
			updateCarTelemetry(supercar, frame_count)
		end
	end

	delay(1)
end

appQuit()
