-- just copy the Mp5 instead (also this has modified recoil to make the arm dislocation less noticeable)
#version 2

#include "script/include/player.lua"
#include "script/pwbtoolanimation.lua"
#include "script/util.lua"

-- Per weapon constants
local RELOAD_TIME = 1.5 -- seconds
local RELOAD_SOUND = "MOD/snd/ar2_reload.ogg"
local ALT_FIRESOUND = "MOD/snd/ar2_altfire.ogg"
local ALT_CHARGESOUND = "MOD/snd/ar2_altfirecharge.ogg"
local PRIM_FIRESOUND = "MOD/snd/ar2_fire.ogg"
local CLIP_SIZE = 30
local PICKUP_SIZE = 30
local RECOIL_AMNT = 0.185
local FIRERATE = 0.1
local CAMMOVETIME = (2 * math.pi) * (0.5 / FIRERATE) -- Cam movement sine multiplier, FIRERATE is how long until it's over
local ALTFIRERATE = 1
local CAMALTMOVETIME = (2 * math.pi) * (0.5 / ALTFIRERATE) -- Cam movement sine multiplier, ALTFIRERATE is how long until it's over
local DAMAGE = 0.45
local PLAYERDAMAGE = 0.11
local MAX_RANGE = 100.0
local WPNID = "hl2ar2"
local WPNNAME = "Pulse Rifle"

local BALL_HIT = "MOD/snd/ar2_ball_bounce0.ogg"
local BALL_DIE = "MOD/snd/ar2_ball_explode.ogg"
local BALL_LOOP = "MOD/snd/ar2_ball_fly.ogg"

local BALL_VELOCITY = 30

-- Per weapon data storer
AR2players = {}

-- Stores data for all the BALLS
AR2balls = {}

function createPlayerCLIENTdataAR2()
    return {
		clipamntAR2 = CLIP_SIZE,
		AR2altFireAmmo = 1,
		inAltAttack = false,
		chargedTime = nil,
		inreload = false,
		coolDown = 0.0,
		altCoolDown = 0.0,
		recoil = 0.0,
		toolAnimator = ToolAnimator(),
		camAltMove = false,
		dataReset = true,
	}
end

function createPlayerSERVERdataAR2()
    return {
		firesound = nil,
	}
end

function FindBallSERVERdataOpening()
    local i = 1
    while AR2balls[i] ~= nil do
        i = i + 1
    end
    return i
end

function createBallSERVERdataAR2(p, pos, dir)
    return {
		explTimer = 2, -- since when is it 2 seconds in HL2???
		curDir = dir,
		curPos = pos,
		owner = p,
	}
end

function server.initAR2()
	RegisterTool(WPNID, WPNNAME, "MOD/prefab/m727.xml", 3)
	SetToolAmmoPickupAmount(WPNID, PICKUP_SIZE)
	ballFlyLoop = LoadLoop(BALL_LOOP)
end

function isAttractiveTarget(p, index)
	local data = AR2balls[index]

	if GetPlayerHealth(p) <= 0 				then return false end -- dont target dead players
	if data.owner == p						then return false end -- dont target owner

	-- TO-DO: skip team mates!!!

	local dir = VecNormalize(VecSub(GetPlayerPos(p), data.curPos))

	local _, _, _, foundTarget = QueryShot(data.curPos, dir, 26.01)
	
	if foundTarget == 0 					then return false end -- dont target nonvisible players
	if foundTarget ~= p 					then return false end -- not aiming for you!!

	return true
end

function server.tickAR2(dt)
	for p in PlayersAdded() do
		AR2players[p] = createPlayerSERVERdataAR2()
		SetToolEnabled(WPNID, true, p)
		SetToolAmmo(WPNID, 250, p)
	end

	for p in PlayersRemoved() do
		AR2players[p] = nil
	end

	-- doesn't need server ticking
	--for p in Players() do
		--server.tickPlayerAR2(p, dt)
	--end

	if #AR2balls == 0 then return end -- no AR2 balls
	
	for index, data in pairs(AR2balls) do
		data.explTimer = data.explTimer - dt

		PointLight(data.curPos, 0,0.35,1, 1)

		if data.explTimer <= 0 then
			for i=1,40 do
				ParticleReset()
				ParticleCollide(1)
				ParticleRadius(0.02, 0)
				ParticleGravity(-10)
				ParticleEmissive(5)
				ParticleStretch(5)
				ParticleTile(4)
				ParticleColor(1,1,1)
				SpawnParticle(data.curPos, Vec(math.random(-2,2), math.random(1,4), math.random(-2,2)), 1)
			end

			for i=1,100 do
				ParticleReset()
				ParticleCollide(1)
				ParticleRadius(math.random(1,5)*0.1, 0.5)
				ParticleGravity(0)
				ParticleTile(0)
				ParticleColor(1,1,1, 0,0,0)
				ParticleDrag(math.random(1,10)*0.1)
				ParticleAlpha(0.5,0)
				SpawnParticle(data.curPos, Vec(math.sin(i) * math.random(5,15), math.random(-3,3), math.cos(i) * math.random(5,15)), math.random(1,10)*0.1)
			end

			PlaySound(LoadSound(BALL_DIE), data.curPos, 1)
			
			AR2balls[index] = nil -- Delete this AR2 ball
		else -- simulate physics
			QueryRejectBody(GetToolBody(p))
			QueryInclude("player")
			local hit, dist, normal = QueryRaycast(data.curPos, data.curDir, BALL_VELOCITY * dt)

			local endPoint = VecAdd(data.curPos, VecScale(data.curDir, dist))
			
			if dist == 0 then
				endPoint = VecAdd(data.curPos, VecScale(data.curDir, 10 * dt))
			end
			
			data.curPos = endPoint

			if hit and dist ~= 0 then
				-- do damage
				_, _, ImpactedPlayer = ShootHook(data.curPos, data.curDir, "shotgun", 2, 1, 10, data.owner, WPNID, WPNNAME, 2)
				
				-- Get the best target
				local bestTarget = -1
				if isMP() == true then
					if ImpactedPlayer ~= 0 then -- target next player directly
						local bestDist = 100
						for target in Players() do
							if isAttractiveTarget(target, index) == true and target ~= ImpactedPlayer then
								local distance = VecLength(VecSub(GetPlayerPos(target), data.curPos))
								if distance < bestDist then
									bestTarget = target
									bestDist = distance
								end
							end
						end
					else -- normal targetting -- TO-DO: broken
						local targettablePlayers = {}

						table.insert(targettablePlayers, ImpactedPlayer)

						local dir = VecSub(data.curDir, VecScale(normal, VecDot(normal, data.curDir) * 2))
						local foundTarget = -1

						repeat
							for _, alreadyHit in pairs(targettablePlayers) do
								QueryRejectPlayer(alreadyHit)
							end

							_, _, _, foundTarget = QueryShot(data.curPos, dir, 26.01, 6.5)
							table.insert(targettablePlayers, foundTarget)
						until foundTarget == 0

						if #targettablePlayers ~= 0 then
							local bestDist = 100
							for target in pairs(targettablePlayers) do
								if isAttractiveTarget(target, index) == true then
									local between = VecSub(GetPlayerPos(target), data.curPos)
									local dotprod = VecDot(VecNormalize(between), dir)
									if dotprod > 0.966 then
										local distance = VecLength(between)
										if distance < bestDist then
											bestTarget = target
											bestDist = distance
										end
									end
								end
							end
						end
					end
				end

				-- reflect
				if bestTarget ~= -1 then -- found a good target
					data.curDir = VecNormalize(VecSub(GetPlayerPos(bestTarget), data.curPos))
					Paint(data.curPos, 0.83, "explosion", 0.8) -- bigger (no real reason)
				else
					data.curDir = VecSub(data.curDir, VecScale(normal, VecDot(normal, data.curDir) * 2))
					Paint(data.curPos, 0.66, "explosion", 0.8)
				end

				PlaySound(LoadSound(BALL_HIT), data.curPos, 0.5)
				
				-- spawn fire sometimes
				server.SpawnFireHook(data.curPos, 66)

				-- sparks
				for i=1,20 do
					ParticleReset()
					ParticleCollide(1)
					ParticleRadius(0.02, 0)
					ParticleGravity(-10)
					ParticleEmissive(5)
					ParticleStretch(5)
					ParticleTile(4)
					ParticleColor(1,1,1)
					SpawnParticle(data.curPos, Vec(math.random(-2,2), math.random(1,4), math.random(-2,2)), 1)
				end
			end

			ParticleReset()
			ParticleCollide(1)
			ParticleRadius(0.3, 0)
			ParticleGravity(0)
			ParticleEmissive(5)
			ParticleStretch(5)
			ParticleTile(5)
			local colorRnd = math.random()
			local colorRnd2 = math.random()
			local colorRnd3 = math.random()
			ParticleColor(0,0.35,1, 1,0.35,0)
			SpawnParticle(data.curPos, Vec((colorRnd - 0.5), (colorRnd2 - 0.5), (colorRnd3 - 0.5)), 0.3)
			ParticleTile(4)
			SpawnParticle(data.curPos, Vec((colorRnd - 0.5) * 2, (colorRnd2 - 0.5) * 2, (colorRnd3 - 0.5) * 2), 0.1)

			PlayLoop(ballFlyLoop, data.curPos)
		end
	end
end

function server.tickPlayerAR2(p, dt)
end

function server.primaryFireAR2(p)
	local mt = GetToolLocationWorldTransform("muzzle", p)

	local data = AR2players[p]

	local pos, dir = getAimVector(mt.pos, MAX_RANGE, GLOBAL_3DEGREES, p)
	
	local hit, dist = ShootHook(pos, dir, "bullet", DAMAGE, PLAYERDAMAGE, MAX_RANGE, p, WPNID, WPNNAME)

	-- start fires sometimes (for the funny)
	if hit == true then
		pos = VecAdd(pos, VecScale(dir, dist)) -- recycle old var
		server.SpawnFireHook(VecAdd(pos, VecScale(dir, dist)), 10)

		ParticleReset()
		ParticleCollide(1)
		ParticleRadius(0.3, 0)
		ParticleGravity(0)
		ParticleEmissive(5)
		ParticleStretch(5)
		ParticleTile(5)
		local colorRnd = math.random()
		local colorRnd2 = math.random()
		local colorRnd3 = math.random()
		ParticleColor(0.1,0.35,0.8, 0.5,0.35,0.4)
		SpawnParticle(pos, Vec((colorRnd - 0.5), (colorRnd2 - 0.5), (colorRnd3 - 0.5)), 0.3)
		ParticleTile(4)
		SpawnParticle(pos, Vec((colorRnd - 0.5) * 2, (colorRnd2 - 0.5) * 2, (colorRnd3 - 0.5) * 2), 0.1)
	end

	StopSound(data.firesound)
	data.firesound = PlaySound(LoadSound(PRIM_FIRESOUND), mt.pos, 300)
	
	server.depleteAmmo(p, WPNID)
end

function server.secondaryFireAR2(p)
	local mt = GetToolLocationWorldTransform("muzzle", p)

	local _,pos,_,dir = GetPlayerAimInfo(mt.pos, MAX_RANGE, p)

	pos = VecAdd(pos, VecScale(dir, 0.5))
	
	-- add AR2 ball to sim
	AR2balls[FindBallSERVERdataOpening()] = createBallSERVERdataAR2(p, pos, dir)

	PlaySound(LoadSound(ALT_FIRESOUND), mt.pos, 300)
end

function client.initAR2()
	shootHaptic = LoadHaptic("MOD/haptic/gun_fire.xml")
	local toolHaptic = LoadHaptic("MOD/haptic/background.xml")
	SetToolHaptic(WPNID, toolHaptic)
	spinLoop = LoadLoop(ALT_CHARGESOUND)
end

function client.tickAR2(dt)
	for p in PlayersAdded() do
		AR2players[p] = createPlayerCLIENTdataAR2();
	end

	for p in PlayersRemoved() do
		AR2players[p] = nil
	end

	for p in Players() do
		client.tickPlayerAR2(p, dt)
	end
end

clipamnt = 0
altclipamnt = 0
local camSineTime = nil

function getFullChargeTime()
	return 2.5
end

function client.tickPlayerAR2(p, dt)
	if not IsToolEnabled(WPNID, p) then return end
	
	if GetPlayerHealth(p) <= 0 then
		if AR2players[p].dataReset == false then
			AR2players[p] = createPlayerCLIENTdataAR2()
		end
		return
	end

	if GetPlayerTool(p) ~= WPNID then
		AR2players[p].chargedTime = nil
		if IsPlayerLocal(p) then
			camSineTime = nil
		end
		return
	end

	local pt = GetPlayerTransform(p)
	local mt = GetToolLocationWorldTransform("muzzle", p)

	local ammo = GetToolAmmo(WPNID, p)

	if mt == nil then
		return
	end
	
	local data = AR2players[p]
	
	-- make data reset when reset conditions are met
	data.dataReset = false

	if InputPressed("r", p) and data.inreload == false and data.clipamntAR2 < CLIP_SIZE and ammo > 0.5 and data.clipamntAR2 ~= ammo then
		PlaySound(LoadSound(RELOAD_SOUND), pt.pos)
		data.coolDown = RELOAD_TIME
		data.altCoolDown = RELOAD_TIME
		data.inreload = true
	end
	
	if data.coolDown < 0 and data.inreload == true then	
		data.inreload = false
		data.AR2altFireAmmo = 1
		data.clipamntAR2 = CLIP_SIZE
		if data.clipamntAR2 > ammo then -- make sure the clip cannot be higher than ammo
			data.clipamntAR2 = ammo
		end
	end

	if InputDown("usetool", p) and ammo > 0.5 and GetPlayerCanUseTool(p) == true then
			if data.coolDown < 0 then		
				PointLight(mt.pos, 1, 0.7, 0.5, 3)

				local playervel = GetPlayerVelocity(p)

				if IsPlayerLocal(p) then
					ServerCall("server.primaryFireAR2", p)
					camSineTime = 0
					data.camAltMove = false
					PlayHaptic(shootHaptic, 1)
				end

				-- muzzleflash
				for i=0, 3 do
					ParticleReset()
					ParticleGravity(0)
					ParticleRadius(rnd(0.12, 0.17), 0.33)
					ParticleAlpha(1, 0)
					ParticleTile(5)
					ParticleDrag(0)
					ParticleRotation(rnd(10, -10), 0)
					ParticleSticky(0)
					ParticleEmissive(5, 1)
					ParticleCollide(0)
					ParticleColor(0,0.35,1, 1,0.35,0)
					SpawnParticle(mt.pos, playervel, 0.125)
				end
				
				data.clipamntAR2 = data.clipamntAR2 - 1
				if data.clipamntAR2 > 0 then
					data.coolDown = FIRERATE
				elseif ammo > 1 then
					PlaySound(LoadSound(RELOAD_SOUND), pt.pos)
					data.coolDown = RELOAD_TIME
					data.inreload = true
				end
				
				data.recoil = RECOIL_AMNT
			end
	end

	if InputPressed("grab", p) and GetPlayerCanUseTool(p) == true and data.AR2altFireAmmo > 0 then
		if data.altCoolDown < 0 then
			data.coolDown = 1.0
			data.altCoolDown = 1.5
			data.chargedTime = 0
			data.toolAnimator.forceActionPose = true
		end
	end
	
	if data.chargedTime ~= nil then -- deplete timer and check if ready
		data.chargedTime = data.chargedTime + dt -- increase timer
		local pitch = (data.chargedTime) * (150 / getFullChargeTime()) + 100
		if pitch > 250 then
			pitch = 250
		end
		pitch = pitch / 100

		data.recoil = math.min(0.1, data.recoil + (pitch * 0.5))

		PlayLoop(spinLoop, mt.pos, 1, true)
		
		local playervel = GetPlayerVelocity(p)
		-- muzzleflash
		ParticleReset()
		ParticleGravity(0)
		ParticleRadius(0.1 + (data.chargedTime / 2))
		ParticleAlpha(1, 0)
		ParticleTile(1)
		ParticleDrag(0)
		ParticleRotation(rnd(10, -10), 0)
		ParticleSticky(0)
		ParticleEmissive(5, 1)
		ParticleCollide(0)
		ParticleColor(0,0.35,1, 1,0.35,0)
		SpawnParticle(mt.pos, playervel, 0.125)
	
		if data.chargedTime >= 0.5 then
			SetSoundLoopProgress(spinLoop, 0.0)

			PointLight(mt.pos, 0.063, 0.5, 0.36, 5)

			data.toolAnimator.forceActionPose = false

			if IsPlayerLocal(p) then
				ServerCall("server.secondaryFireAR2", p)
				camSineTime = 0
				PlayHaptic(shootHaptic, 1)
			end

			data.AR2altFireAmmo = data.AR2altFireAmmo - 1

			data.recoil = RECOIL_AMNT
			data.chargedTime = nil
		end
	end

	-- decrease firing cooldown and recoil
	data.coolDown = data.coolDown - dt
	data.altCoolDown = data.altCoolDown - dt
	data.recoil = data.recoil - dt
	
	-- RECOIL
	if data.recoil > -0.5 then
		local recoil = math.max(0, data.recoil / 2)
		local siderecoil = recoil * 0.25
		local recoilvert = math.max(0, data.recoil * 1.5)
		
		local inversesiderecoil = rnd(0, 1)
		if inversesiderecoil > 0.5 then
			siderecoil = siderecoil * -1
		end

		data.toolAnimator.offsetTransform = Transform(Vec(siderecoil,recoil,recoilvert))
	end 
	-- END RECOIL
	
	tickToolAnimator(data.toolAnimator, dt, nil, p)

	
	if IsPlayerLocal(p) then
		-- CAMERA MOVEMENT
		if camSineTime ~= nil then
			local x = camSineTime
			local e = math.exp(1)
			local balance = -15 -- where the peak is (10 for middle, higher to move left also has to be neagtive)
			local amp = 15 -- how intense (y at the peak will not equal this though)
			
			local equation = nil
			if data.camAltMove == true then
				balance = -20
				amp = 800
				equation = amp * ((math.sin(CAMALTMOVETIME * x) * e^(balance * x)) * x)
			else
				equation = amp * ((math.sin(CAMMOVETIME * x) * e^(balance * x)) * x)
			end

			if equation >= 0 then
				local t = 0
				if data.camAltMove == true then
					t = Transform(Vec(), QuatAxisAngle(Vec(1.0, -1.0, 0), equation))
				else
					t = Transform(Vec(), QuatAxisAngle(Vec(-1.0, 0.5, 0), equation))
				end
				SetPlayerCameraOffsetTransform(t)
				camSineTime = camSineTime + dt
			else camSineTime = nil end
		end

		-- UPD AMMO HUD
		if data.inreload == false and ammo > 0.5 then
			clipamnt = data.clipamntAR2
			altclipamnt = data.AR2altFireAmmo
		elseif ammo > 0.5 then
			clipamnt = -8 -- negative 8 means reloading
			altclipamnt = -8
		else
			data.clipamntAR2 = 0
			clipamnt = -16
			altclipamnt = data.AR2altFireAmmo
		end
	end
end

function client.drawAR2()
	if GetPlayerTool() ~= WPNID then -- shouldn't need the player pointer since this runs on client
		return
	end

	client.drawAmmo(clipamnt, CLIP_SIZE)
	client.drawSecAmmo(altclipamnt)
end