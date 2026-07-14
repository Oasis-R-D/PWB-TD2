-- copy this for the most basic melee
#version 2

-- Per weapon constants
local RECOIL_AMNT = 0.3
local DAMAGE = 0.2
local MAX_RANGE = 2 -- less range in HL2
local WPNID = "hl2stunstick"
local WPNNAME = "Stunstick"
local COOLDOWN = 0.8

-- Per weapon data storer
local playerData = {}

local function createPlayerCLIENTdata()
    return {
		coolDown = 0.0,
		recoil = 0.0,
		recoildelay = 0.0,
		toolAnimator = ToolAnimator(),
		firesound = nil,
		dataReset = true,
	}
end

local function createPlayerSERVERdata()
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
		playerData[p] = createPlayerSERVERdata()
		SetToolEnabled(WPNID, true, p)
		SetToolAmmo(WPNID, 99999, p)
	end

	for p in PlayersRemoved() do
		playerData[p] = nil
	end

	for p in Players() do
		server.tickPlayerSTNSTK(p, dt)
	end
end

function server.swingSTNSTK(m_pPlayer, dt) -- HL1 uses m_pPlayer (use it here for familiarity or whatever)
	local data = playerData[m_pPlayer]
	
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
		
		local hitAnimator = GetBodyAnimator(GetShapeBody(pHitWorld))

		-- PLAYER DAMAGE
		local SoundPoint = VecAdd(pos, VecAdd(VecScale(dir, pDist), VecScale(pNorm, -0.33)))
		if pHitPlayer ~= 0 then
			ApplyPlayerDamage(pHitPlayer, DAMAGE, WPNNAME, m_pPlayer)
			BloodVFX(SoundPoint, dir, DAMAGE, pHitPlayer)
		elseif hitAnimator ~= 0 then
			pHitPlayer = 1
			BloodVFX(SoundPoint, dir, DAMAGE, nil, hitAnimator)

			ApplyBodyImpulse(GetShapeBody(pHitWorld), SoundPoint, VecScale(dir, 800 * 3))
		else
			PlayImpactSFX(pHitWorld, SoundPoint, pNorm, "s")

			ApplyBodyImpulse(GetShapeBody(pHitWorld), SoundPoint, VecScale(dir, 800 * 3))
			MakeHole(SoundPoint, 0.4, 0.0, 0.0) -- stronger than sledge
		end
		-- PLAYER DAMAGE END

		data.coolDown = COOLDOWN
		
		ClientCall(0, "client.swingSTNSTK", m_pPlayer, dt, fDidHit, SoundPoint, pHitPlayer, pHitWorld)
	end
end

function client.swingSTNSTK(m_pPlayer, dt, hit, pos, pHitPlayer, pHitWorld)
	local data = playerData[m_pPlayer]
	local vecSrc = GetPlayerEyeTransform(m_pPlayer)
	data.toolAnimator.timeSinceFire = 0.0

	data.coolDown = COOLDOWN

	if IsPlayerLocal(m_pPlayer) then
		client.SRC_PunchAxis(1, rnd(-1, -2))
		client.SRC_PunchAxis(2, rnd(2, 1))
	end

	if hit == false then
		-- Miss
		PlaySound(LoadSound("MOD/snd/stunstick_swing0.ogg"), vecSrc.pos, 0.5)

		data.toolAnimator.maxActionPoseTime = 0.1 -- stop midswing but further in
	else
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
	
	if GetPlayerHealth(p) <= 0 and playerData[p].dataReset == false then
		if playerData[p].dataReset == false then
			playerData[p] = createPlayerSERVERdata()
		end
		return
	end

	if GetPlayerTool(p) ~= WPNID and playerData[p].dataReset == false then
		if playerData[p].dataReset == false then
			playerData[p] = createPlayerSERVERdata()
		end
		return
	end
	
	local data = playerData[p]

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
	SetToolHaptic(WPNID, toolHaptic)
end

function client.tickSTNSTK(dt)
	for p in PlayersAdded() do
		playerData[p] = createPlayerCLIENTdata()
	end

	for p in PlayersRemoved() do
		playerData[p] = nil
	end

	for p in Players() do
		client.tickPlayerSTNSTK(p, dt)
	end
end

function client.tickPlayerSTNSTK(p, dt)
	if not IsToolEnabled(WPNID, p) then return end
	
	if GetPlayerHealth(p) <= 0 then
		if playerData[p].dataReset == false then
			playerData[p] = createPlayerCLIENTdata()
		end
		return
	end

	if GetPlayerTool(p) ~= WPNID then
		if playerData[p].dataReset == false then
			playerData[p] = createPlayerCLIENTdata()
		end
		return
	end

	local data = playerData[p]

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

	tickToolAnimator(data.toolAnimator, dt, nil, p, 6, true)
end