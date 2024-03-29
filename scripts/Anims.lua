-- Required scripts
require("lib.GSAnimBlend")
local model      = require("scripts.ModelParts")
local waterTicks = require("scripts.WaterTicks")
local pose       = require("scripts.Posing")
local ground     = require("lib.GroundCheck")

-- Animations setup
local anims = animations.LaprasTaur

-- Calculate parent's rotations
local function calculateParentRot(m)
	
	local parent = m:getParent()
	if not parent then
		return m:getTrueRot()
	end
	return calculateParentRot(parent) + m:getTrueRot()
	
end

-- Animation variables
local breatheTime = {
	prev = 0,
	time = 0,
	next = 0
}

local pos = {
	current    = 0,
	nextTick   = 0,
	target     = 0,
	currentPos = 0
}

function events.TICK()
	
	-- Player variables
	local vel = player:getVelocity()
	
	-- Animation variables
	local walking    = vel.xz:length() ~= 0
	local inWater    = waterTicks.water < 20
	local underwater = waterTicks.under < 20
	local onGround   = ground()
	
	-- Store animation variables
	breatheTime.prev = breatheTime.next
	
	-- Animation control
	breatheTime.next = breatheTime.next + math.clamp((vel:length() * 15 + 1) * 0.05, 0, 0.4)
	
	-- Pos state table
	local statePos = {
		{ state = pose.climb,   pos = vec(0, 0, 25)  },
		{ state = pose.elytra,  pos = vec(0, 0, 15)  },
		{ state = pose.spin,    pos = vec(0, 0, 16)  },
		{ state = pose.swim,    pos = vec(0, 20, 15) },
		{ state = pose.crawl,   pos = vec(0, 19, 24) },
	}
	
	-- Base position check
	for _, case in ipairs(statePos) do
		if case.state then
			pos.target = case.pos
			break
		else
			pos.target = 0
		end
	end
	
	-- Tick lerps
	pos.current  = pos.nextTick
	pos.nextTick = math.lerp(pos.nextTick, pos.target, 0.25)
	
	-- Animation states
	local groundIdle     = not walking and (not (inWater or player:getVehicle()) or onGround) and not ((pose.swim and inWater) or pose.elytra) or pose.spin or (pose.climb and vel:length() == 0)
	local groundWalk     =     walking and (not (inWater or player:getVehicle()) or onGround) and not ((pose.swim and inWater) or pose.elytra or pose.spin) or (pose.climb and vel:length() ~= 0)
	local waterIdle      = not walking and ((inWater or player:getVehicle()) and not onGround) and not pose.elytra and not underwater
	local waterSwim      =     walking and ((inWater or player:getVehicle()) and not onGround) and not pose.elytra and not underwater
	local underwaterIdle = vel:length() == 0 and underwater and (not onGround or pose.swim) and not pose.elytra
	local underwaterSwim = vel:length() ~= 0 and underwater and (not onGround or pose.swim) and not pose.elytra
	local elytra         = pose.elytra
	local sleep          = pose.sleep
	
	-- Animations
	anims.groundIdle:playing(groundIdle)
	anims.groundWalk:playing(groundWalk)
	anims.waterIdle:playing(waterIdle)
	anims.waterSwim:playing(waterSwim)
	anims.underwaterIdle:playing(underwaterIdle)
	anims.underwaterSwim:playing(underwaterSwim)
	anims.elytra:playing(elytra)
	anims.sleep:playing(sleep)
	
end

function events.RENDER(delta, context)
	
	-- Player variables
	local vel = player:getVelocity()
	local dir = player:getLookDir()
	
	-- Directional velocity
	local fbVel = player:getVelocity():dot((dir.x_z):normalize())
	local lrVel = player:getVelocity():cross(dir.x_z:normalize()).y
	local udVel = player:getVelocity().y
	
	-- Animation speeds
	local moveSpeed = math.clamp((fbVel < -0.1 and math.min(fbVel, math.abs(lrVel)) or math.max(fbVel, math.abs(lrVel))) * 15, -2, 2)
	anims.groundWalk:speed(moveSpeed)
	anims.waterSwim:speed(moveSpeed)
	anims.underwaterSwim:speed(moveSpeed)
	
	-- Render lerps
	breatheTime.time = math.lerp(breatheTime.prev, breatheTime.next, delta)
	pos.currentPos   = math.lerp(pos.current, pos.nextTick, delta)
	
	-- Apply
	local scale = math.sin(breatheTime.time) * 0.0125 + 1.0125
	model.front:scale(scale)
	
	local animPos = model.root:getAnimPos()
	model.root:pos(pos.currentPos + ((pose.swim or pose.climb or pose.crawl) and vec(0, animPos.z - animPos.y, animPos.y - animPos.z) or 0))
	
	-- Parrot rot offset
	for _, parrot in pairs(model.parrots) do
		parrot:rot(-calculateParentRot(parrot:getParent()))
	end
	
	-- Scales models to fit GUIs better
	if context == "FIGURA_GUI" or context == "MINECRAFT_GUI" or context == "PAPERDOLL" then
		model.root:scale(0.75)
		model.ball:scale(0.75)
	end
	
end

function events.POST_RENDER(delta, context)
	
	-- After scaling models to fit GUIs, immediately scale back
	model.root:scale(1)
	model.ball:scale(1)
	
end

-- GS Blending Setup
local blendAnims = {
	{ anim = anims.groundIdle,     ticks = 7 },
	{ anim = anims.groundWalk,     ticks = 7 },
	{ anim = anims.waterIdle,      ticks = 7 },
	{ anim = anims.waterSwim,      ticks = 7 },
	{ anim = anims.underwaterIdle, ticks = 7 },
	{ anim = anims.underwaterSwim, ticks = 7 },
	{ anim = anims.elytra,         ticks = 7 }
}
	
for _, blend in ipairs(blendAnims) do
	blend.anim:blendTime(blend.ticks):onBlend("easeOutQuad")
end

-- Fixing spyglass jank
function events.RENDER(delta, context)
	
	local rot = vanilla_model.HEAD:getOriginRot()
	rot.x = math.clamp(rot.x, -90, 30)
	model.upper.Spyglass:rot(rot)
		:pos(pose.crouch and vec(0, -4, 0) or nil)
	
end