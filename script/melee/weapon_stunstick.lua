-- copy this for the most basic melee
#version 2

#include "script/include/player.lua"
#include "script/pwbtoolanimation.lua"
#include "script/util.lua"


-- Per weapon constants
local RECOIL_AMNT = 0.3
local DAMAGE = 0.2
local MAX_RANGE = 2 -- less range in HL2
local WPNID = "hl2stunstick"
local WPNNAME = "Stunstick"
local COOLDOWN = 0.8
local CAMMOVETIME = (2 * math.pi) * (0.5 / COOLDOWN) -- Cam movement sine multiplier, COOLDOWN is how long until it's over

-- Per weapon data storer
STNSTKplayers = {}

function createPlayerCLIENTdataSTNSTK()
    return {
		coolDown = 0.0,
		recoil = 0.0,
		recoildelay = 0.0,
		toolAnimator = ToolAnimator(),
		firesound = nil,
		dataReset = true,
	}
end

function createPlayerSERVERdataSTNSTK()
    return {
		coolDown = 0.0,
		dataReset = true,
	}
end

function server.initSTNSTK()
	RegisterTool(WPNID, WPNNAME, "MOD/prefab/stunstick.xml", 1)
	SetToolAmmoPickupAmount(WPNID, 99999)
end

function server.tickSTNSTK(dt)
	for p in PlayersAdded() do
		STNSTKplayers[p] = createPlayerSERVERdataSTNSTK()
		SetToolEnabled(WPNID, true, p)
		SetToolAmmo(WPNID, 99999, p)
	end

	for p in PlayersRemoved() do
		STNSTKplayers[p] = nil
	end

	for p in Players() do
		server.tickPlayerSTNSTK(p, dt)
	end
end

function server.swingSTNSTK(m_pPlayer, dt) -- HL1 uses m_pPlayer (use it here for familiarity or whatever)
	local data = STNSTKplayers[m_pPlayer]
	
	local fDidHit = false
	
	local vecSrc = GetPlayerEyeTransform(m_pPlayer)
	local _,pos,_,dir = GetPlayerAimInfo(vecSrc.pos, MAX_RANGE, m_pPlayer)
	
	local pHit, pDist, pHitWorld, pHitPlayer, _, pNorm = QueryShot(pos, dir, MAX_RANGE, 0.33, m_pPlayer)
	
	if pHit == false then
		-- Miss
		ClientCall(0, "client.swingSTNSTK", m_pPlayer, dt, fDidHit, SoundPoint, false, false)
		data.coolDown = COOLDOWN
	else
		-- Hit
		fDidHit = true
		
		-- PLAYER DAMAGE
		local SoundPoint = VecAdd(pos, VecScale(dir, pDist))
		if pHitPlayer ~= 0 then
			ApplyPlayerDamage(pHitPlayer, DAMAGE, WPNNAME, m_pPlayer)
			BloodVFX(SoundPoint, dir, DAMAGE, pHitPlayer)
		else
			ShootHook(SoundPoint, VecScale(pNorm, -1), "bullet", 0.1, 0.1, MAX_RANGE, m_pPlayer, WPNID, WPNNAME, 3) -- push objects, "dent" metal
			MakeHole(SoundPoint, 0.6, 0.10, 0.0) -- stronger than sledge
		end
		-- PLAYER DAMAGE END

		data.coolDown = COOLDOWN
		
		ClientCall(0, "client.swingSTNSTK", m_pPlayer, dt, fDidHit, SoundPoint, pHitPlayer, pHitWorld)
	end
end

local camSineTime = nil
local camRecoilY = 0
local camRecoilX = 0

function client.swingSTNSTK(m_pPlayer, dt, hit, pos, pHitPlayer, pHitWorld)
	local data = STNSTKplayers[m_pPlayer]
	local vecSrc = GetPlayerEyeTransform(m_pPlayer)
	data.toolAnimator.timeSinceFire = 0.0

	data.coolDown = COOLDOWN

	if hit == false then
		-- Miss
		PlaySound(LoadSound("MOD/snd/stunstick_swing0.ogg"), vecSrc.pos, 0.5)

		data.toolAnimator.maxActionPoseTime = 0.1 -- stop midswing but further in
		if IsPlayerLocal(m_pPlayer) then
			camSineTime = 0
			camRecoilX = rnd( -0.125, -0.25)
			camRecoilY = rnd(  0.125,  0.25)
		end
	else
		if IsPlayerLocal(m_pPlayer) then
			camSineTime = 0
			camRecoilX = rnd( 0.5,  1)
			camRecoilY = rnd( 0.5, 1)
		end

		if pHitPlayer ~= 0 then
			PlaySound(LoadSound("MOD/snd/stunstick_fleshhit0.ogg"), pos, 0.5)
		else
			PlaySound(LoadSound("MOD/snd/stunstick_impact0.ogg"), pos, 0.5)
		end
		
		data.recoildelay = 0.1 -- more hit feedback and randomness
		
		data.toolAnimator.maxActionPoseTime = 0.05 -- stop midswing
	end
end

function server.tickPlayerSTNSTK(p, dt)
	if not IsToolEnabled(WPNID, p) then return end
	
	if GetPlayerHealth(p) <= 0 and STNSTKplayers[p].dataReset == false then
		if STNSTKplayers[p].dataReset == false then
			STNSTKplayers[p] = createPlayerSERVERdataSTNSTK()
		end
		return
	end

	if GetPlayerTool(p) ~= WPNID and STNSTKplayers[p].dataReset == false then
		if STNSTKplayers[p].dataReset == false then
			STNSTKplayers[p] = createPlayerSERVERdataSTNSTK()
		end
		return
	end
	
	local data = STNSTKplayers[p]

	data.dataReset = false

	-- Check Fire
	if InputDown("usetool", p) and GetPlayerCanUseTool(p) == true then
		if data.coolDown < 0 then
			server.swingSTNSTK(p, dt)
		end
	end
	
	data.coolDown = data.coolDown - dt
end

function client.initSTNSTK()
	shootHaptic = LoadHaptic("MOD/haptic/gun_fire.xml")
	local toolHaptic = LoadHaptic("MOD/haptic/background.xml")
	SetToolHaptic(WPNID, toolHaptic);
end

function client.tickSTNSTK(dt)
	for p in PlayersAdded() do
		STNSTKplayers[p] = createPlayerCLIENTdataSTNSTK();
	end

	for p in PlayersRemoved() do
		STNSTKplayers[p] = nil
	end

	for p in Players() do
		client.tickPlayerSTNSTK(p, dt)
	end
end

function client.tickPlayerSTNSTK(p, dt)
	if not IsToolEnabled(WPNID, p) then return end
	
	if GetPlayerHealth(p) <= 0 then
		if STNSTKplayers[p].dataReset == false then
			STNSTKplayers[p] = createPlayerCLIENTdataSTNSTK()
		end
		return
	end

	if GetPlayerTool(p) ~= WPNID then
		if IsPlayerLocal(p) then
			camSineTime = nil
		end
		if STNSTKplayers[p].dataReset == false then
			STNSTKplayers[p] = createPlayerCLIENTdataSTNSTK()
		end
		return
	end

	local pt = GetPlayerTransform(p)

	local data = STNSTKplayers[p]

	data.dataReset = false

	-- Check Fire
	if InputDown("usetool", p) and GetPlayerCanUseTool(p) == true then
		if data.coolDown < 0 then
			data.recoildelay = 0.0 -- make the melee move up a little first
			data.toolAnimator.timeSinceFire = 0.0
		end
	end
	
	-- Simulate coolDown as the server does
	data.coolDown = data.coolDown - dt
	data.recoil = data.recoil - dt

	-- RECOIL
	if data.recoildelay ~= nil then 
		data.recoildelay = data.recoildelay - dt
		if data.recoildelay < 0 then
			data.recoil = 0.1
			data.recoildelay = nil
		end
	end

	if data.recoil > -0.5 then
		local recoil = math.max(0, data.recoil)
		local siderecoil = recoil * 0.25
		local recoilvert = math.max(0, data.recoil * 1.2)
		
		local inversesiderecoil = rnd(0, 1)
		if inversesiderecoil > 0.5 then
			siderecoil = siderecoil * -1
		end

		data.toolAnimator.offsetTransform = Transform(Vec(siderecoil,recoil,recoilvert))
	end 
	-- END RECOIL
	
	if IsPlayerLocal(p) then
		-- CAMERA MOVEMENT
		if camSineTime ~= nil then
			local x = camSineTime
			local balance = -10 -- where the peak is (10 for middle, higher to move left also has to be negative)
			local amp = 80 -- how intense (y at the peak will not equal this though)

			local equation = amp * ((math.sin(CAMMOVETIME * x) * math.exp(balance * x)) * x)

			if equation >= 0 then
				local t = Transform(Vec(), QuatAxisAngle(Vec(camRecoilX, camRecoilY, 0), equation))
				SetPlayerCameraOffsetTransform(t)
				camSineTime = camSineTime + dt
			else camSineTime = nil end
		end
	end

	tickToolAnimator(data.toolAnimator, dt, nil, p, 6, true)
end