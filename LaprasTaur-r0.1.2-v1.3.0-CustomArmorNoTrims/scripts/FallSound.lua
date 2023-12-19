-- Config setup
config:name("LaprasTaur")
local fallSound = config:load("FallSoundToggle")
if fallSound == nil then fallSound = true end
local canDry = config:load("FallSoundDry")
if canDry == nil then canDry = true end
local dryTimer = config:load("FallSoundDryTimer") or 400

-- Variables setup
local g     = require("scripts.GroundCheck")
local ticks = require("scripts.WaterTicks")

-- Sound player
local wasInAir = false
function events.TICK()
	if fallSound and wasInAir and g.ground and not player:getVehicle() and not player:isInWater() then
		if models.Pokeball:getScale():length() > 0.5 then
			sounds:playSound("cobblemon:poke_ball.hit", player:getPos(), 0.25)
		else
			local vel    = player:getVelocity().y
			local volume = math.clamp((math.abs(-vel + 1) * (canDry and ((dryTimer + -ticks.wet) / dryTimer) or 1)) / 2, 0, 1)
			if volume ~= 0 then
				sounds:playSound("minecraft:entity.puffer_fish.flop", player:getPos(), volume, math.map(volume, 1, 0, 0.45, 0.65))
			end
		end
	end
	wasInAir = not g.ground
end

-- Sound toggler
local function setToggle(boolean)
	fallSound = boolean
	config:save("FallSoundToggle", fallSound)
	if host:isHost() and player:isLoaded() and fallSound then
		sounds:playSound("minecraft:entity.puffer_fish.flop", player:getPos(), 0.35, 0.6)
	end
end

-- Dry toggler
local function setDry(boolean)
	canDry = boolean
	config:save("FallSoundDry", canDry)
end

-- Set Timer function
local function setDryTimer(x)
	dryTimer = math.clamp(dryTimer + (x * 20), 100, 6000)
	config:save("FallSoundDryTimer", dryTimer)
end

-- Sync variables
local function syncFallSound(a, b, x)
	fallSound = a
	canDry = b
	dryTimer = x
end

-- Setup ping
pings.setFallSoundToggle = setToggle
pings.setFallSoundDry    = setDry
pings.syncFallSound      = syncFallSound

-- Activate action
setToggle(fallSound)
setDry(canDry)

-- Sync on tick
if host:isHost() then
	function events.TICK()
		if world.getTime() % 200 == 0 then
			pings.syncFallSound(fallSound, canDry, dryTimer)
		end
	end
end

-- Table setup
local t = {}

-- Action wheel pages
t.soundPage = action_wheel:newAction("FallSound")
	:title("§9§lToggle Falling Sound\n\n§bToggles floping sound effects when landing on the ground.\nWhen inside your pokeball, a different sound plays.")
	:hoverColor(vectors.hexToRGB("5EB7DD"))
	:toggleColor(vectors.hexToRGB("4078B0"))
	:item("minecraft:bucket")
	:toggleItem("minecraft:water_bucket")
	:onToggle(pings.setFallSoundToggle)
	:toggled(fallSound)

function events.TICK()
	local current = "§3Current drying timer: "..(canDry and ("§b§l"..(dryTimer / 20).." §3Seconds") or "§b∞")
	t.dryTitle = "§9§lToggle Drying/Timer\n\n"..current.."\n\n§bToggles the gradual decrease in volume of the flopping sound,\nunless the player reenters water or rain, which resets the volume.\n\nScrolling up adds time, Scrolling down subtracts time.\nRight click resets timer to 20 seconds."
end

t.dryPage = action_wheel:newAction("FallSoundDrying")
	:title(t.dryTitle)
	:hoverColor(vectors.hexToRGB("5EB7DD"))
	:toggleColor(vectors.hexToRGB("4078B0"))
	:item("minecraft:pufferfish")
	:toggleItem("minecraft:leather")
	:onToggle(pings.setFallSoundDry)
	:onScroll(setDryTimer)
	:onRightClick(function() dryTimer = 400 config:save("FallSoundDryTimer", dryTimer) end)
	:toggled(canDry)

return t