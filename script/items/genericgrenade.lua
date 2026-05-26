#version 2
-- GENERIC GRENADE, INCLUDES IMPACT GRENADE CODE AND TIMER GRENADE CODE
#include "script/include/player.lua"

-- Per weapon constants
local COOKTIME = 3
local BODYTAG = "hlgrenade"
local EXPLSIZE = 1.0
local THINKTIME = 0.1 -- replicates Half-Life's thinking behavior
local AIRRESISTMULT = 0.99

function getBodyCenter(body)
	local bmi, bma = GetBodyBounds(body)
	local bc = VecLerp(bmi, bma, 0.5)
	return bc
end

function server.initTags()
	server.tagsRecieved = true

	server.playerThrew = tonumber(GetTagValue(grenBody, "playerThrew"))

	server.grenType = GetTagValue(grenBody, "grenType") -- specific properties
	server.grenStyle = GetTagValue(grenBody, "grenStyle") -- general properties

	if server.grenType == "frag" or server.grenType == "m203" or server.grenType == "satchel" then
		server.gravMult = 0.51 -- half-life 1's gravity is 800 (HU?) which is around 20MS, TD's is 10 so 1/2 20 = 10
	else
		server.gravMult = 1.0
	end

	if server.grenStyle == "timed" then
		SetProperty(grenBody, "restitution", 0.66)
		local timer = tonumber(GetTagValue(grenBody, "timer"))
		server.explTimer = timer
	end

	if server.grenStyle == "lasermine" then
		server.laserDist = nil
		server.laserMineOn = false
	end
end

function server.init()
	grenBody = FindBody(BODYTAG)

	server.thinkTime = THINKTIME

	server.shouldExplode = false
	server.exploded = false
	server.tagsRecieved = false

	server.runTime = 0.0
	
	TM_ON = LoadSound("MOD/snd/mine_activate.ogg")
end

function server.explode(pos)
	if server.grenType == "frag" then
		Explosion(pos, 1.5)
	elseif server.grenType == "m203" then
		Explosion(pos, 1.0)
	elseif server.grenType == "satchel" then
		Explosion(pos, 2.0)
	elseif server.grenType == "mine" then
		Explosion(pos, 1.75)
	end
end

function client.init()
	LaserSPR = LoadSprite("gfx/laser.png")

	client.vecSrc = nil
	client.vecDir = nil
	client.raycastDist = nil
end

function client.updateLaser(vecSrc, vecDir, raycastDist)
	client.vecSrc = vecSrc
	client.vecDir = vecDir
	client.raycastDist = raycastDist
end

function client.tick(dt)
	if client.raycastDist ~= nil then
		local t = Transform(VecLerp(client.vecSrc, VecAdd(client.vecSrc, VecScale(client.vecDir, client.raycastDist)), 0.5))

		local xAxis = VecNormalize(VecSub(VecAdd(client.vecSrc, VecScale(client.vecDir, client.raycastDist)), client.vecSrc))
		local zAxis = VecNormalize(VecSub(client.vecSrc, GetCameraTransform().pos))

		t.rot = QuatAlignXZ(xAxis, zAxis)

		DrawSprite(LaserSPR, t, client.raycastDist, 0.1, 0.0, 0.83, 0.77, 0.25, true, true)
		DrawLine(client.vecSrc, VecAdd(client.vecSrc, VecScale(client.vecDir,  client.raycastDist)), 0.0, 0.83, 0.77, 0.25)
	end
end

function server.think()
	local grenPos = getBodyCenter(grenBody)

	local grenVel = GetBodyVelocity(grenBody)

	if server.shouldExplode == true then
		if server.grenStyle == "lasermine" then
			ClientCall(0, "client.updateLaser", nil, nil, nil)
		end
		server.explode(grenPos)
		server.exploded = true
		return
	end

	server.thinkTime = THINKTIME
	
	--SetBodyVelocity(grenBody, VecScale(grenVel, AIRRESISTMULT))
	--server.gravMult = server.gravMult * 1.011
end

function server.tick(dt)
	server.runTime = server.runTime + dt
	
	if server.exploded == true then
		Delete(grenBody)
		return
	end

	if server.tagsRecieved == false then
		if HasTag(grenBody, "grenStyle") then
			server.initTags()
		end

		return
	end
	
	local grenPos = getBodyCenter(grenBody)
	
	if IsBodyBroken(grenBody) then
		if server.grenStyle == "lasermine" then
			ClientCall(0, "client.updateLaser", nil, nil, nil)
		end
		server.explode(grenPos)
		server.exploded = true
		Delete(grenBody)
		return
	end

	local grenVel = GetBodyVelocity(grenBody)

	-- BEGIN DETONATION CHECKS
	if server.grenStyle == "timed" then -- decrease timer
		server.explTimer = server.explTimer - dt
		if server.explTimer < 0 then
			server.shouldExplode = true
		end

	elseif server.grenStyle == "impact" then -- check if impacting
		local grenspeed = VecLength(grenVel)
		QueryRejectBody(grenBody)
		QueryRejectPlayer(server.playerThrew)
		QueryInclude("player")
		local pHit = QueryRaycast(grenPos, VecNormalize(grenVel), grenspeed * dt + 0.2, 0.1) -- 0.1 instead of 1/3 since HL2 grenade is smaller
		if pHit or grenspeed <= 0.01 then
			server.shouldExplode = true
		end

	elseif server.grenStyle == "remote" then -- check if owner has given it the explode tag
		if HasTag(grenBody, "detonate") then
			server.shouldExplode = true
		elseif (GetPlayerHealth(server.playerThrew) == nil or GetPlayerHealth(server.playerThrew) <= 0.0) and not HasTag(grenBody, "detonate") then
			 -- owner died or left, that doesn't matter if it is already exploding though (does weird things if it has the detonate tag here)
			Delete(grenBody)
			return
		end

	elseif server.grenStyle == "lasermine" then -- check if the mine is tripped and draw laser
		if server.runTime >= 2.5 and server.laserMineOn ~= true then
			server.laserMineOn = true 
			PlaySound(TM_ON, GetBodyTransform(grenBody).pos, 10)

			local laserStartTrans = TransformToParentTransform(GetBodyTransform(grenBody), Transform(Vec(0.02, -0.02, -0.18), GetBodyTransform(grenBody).rot))
			local laserStartVec = laserStartTrans.pos
			local direction = TransformToParentVec(GetBodyTransform(grenBody), Vec(0, 0, -1))

			QueryRejectBody(grenBody)
			QueryInclude("player")
			local pHit, pDist = QueryRaycast(laserStartVec, direction, 48, 0.0, true)

			-- draw
			ClientCall(0, "client.updateLaser", laserStartVec, direction, pDist)

		elseif server.laserMineOn == true then
			local laserStartTrans = TransformToParentTransform(GetBodyTransform(grenBody), Transform(Vec(0.02, -0.02, -0.18), GetBodyTransform(grenBody).rot))
			local laserStartVec = laserStartTrans.pos
			local direction = TransformToParentVec(GetBodyTransform(grenBody), Vec(0, 0, -1))

			QueryRejectBody(grenBody)
			QueryInclude("player")
			local pHit, pDist = QueryRaycast(laserStartVec, direction, 48, 0.0, true)
			
			if server.laserDist == nil then
				server.laserDist = pDist
			elseif math.abs(server.laserDist - pDist) >= 0.0625 then 
				server.shouldExplode = true
				server.laserDist = pDist
				server.think() -- think now so you don't notice that the laser doesn't upd
				return
			end
		end
	end
	-- END DETONATION CHECKS

	-- think (check explode, apply air resist, friction etc etc)
	server.thinkTime = server.thinkTime - dt
	if server.thinkTime <= 0 then
		server.think()
	end

	-- remove engine's gravity
	local pvel = GetBodyVelocity(grenBody)
	local gravity = GetGravity()
	local newVel = VecAdd(pvel, VecScale(gravity, -dt))
	SetBodyVelocity(grenBody, newVel)

	-- add faked gravity
	local newgravity = VecScale(GetGravity(), server.gravMult)
	local finalVel = VecAdd(newVel, VecScale(newgravity, dt))
	SetBodyVelocity(grenBody, finalVel)
end

