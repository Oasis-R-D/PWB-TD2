-- copy this for a basic pistol with separate sounds when not fired by the client
#version 2

#include "script/include/player.lua"
#include "script/pwbtoolanimation.lua"
#include "script/util.lua"

-- Per weapon constants
local RELOAD_TIME = 1.5 -- seconds
local RELOAD_SOUND = "MOD/snd/glockR.ogg"
local PRIM_FIRESOUND = "MOD/snd/pistol_fire.ogg"
local NONCLIENTPRIM_FIRESOUND = "MOD/snd/pistol_fireNC.ogg" -- glock has diff sounds when shot by NPCs (in this case, other players)
local SUPPRIM_FIRESOUND = "MOD/snd/supglockFR.ogg"
local SUPNONCLIENTPRIM_FIRESOUND = "MOD/snd/supglockFRnc.ogg" -- glock has diff sounds when shot by NPCs (in this case, other players)
local CLIP_SIZE = 17.0
local PICKUP_SIZE = 17.0
local RECOIL_AMNT = 0.17
local FIRERATE = 0.3
local CAMMOVETIME = (2 * math.pi) * (0.5 / FIRERATE) -- Cam movement sine multiplier, FIRERATE is how long until it's over
local ALTFIRERATE = 0.2
local DAMAGE = 0.4
local PLAYERDAMAGE = 0.08
local MAX_RANGE = 125.0
local WPNID = "hl2pistol"
local WPNNAME = "9mm Pistol"
local CASING_ORG = Vec(0.02, 0.25, 0.0)

-- Per weapon data storer
PIST9MMplayers = {}

function createPlayerCLIENTdataPIST9MM()
    return {
		clipamntPIST9MM = CLIP_SIZE,
		inreload = false,
		coolDown = 0.0,
		altCoolDown = 0.0,
		tertiaryCoolDown = 0.0,
		recoil = 0.0,
		toolAnimator = ToolAnimator(),
		firesound = nil,
		suppressed = false,
		dataReset = true,
		firstDraw = true,
	}
end

function server.initPIST9MM()
	RegisterTool(WPNID, WPNNAME, "MOD/prefab/glock.xml", 3)
	SetToolAmmoPickupAmount(WPNID, PICKUP_SIZE)
end

function server.tickPIST9MM(dt)
	for p in PlayersAdded() do
		SetToolEnabled(WPNID, true, p)
		SetToolAmmo(WPNID, 250, p)
	end

	-- doesn't need server ticking
	--for p in Players() do
		--server.tickPlayerPIST9MM(p, dt)
	--end
end

function server.tickPlayerPIST9MM(p, dt)
end

function server.primaryFirePIST9MM(p, silenced)
	local mt = GetToolLocationWorldTransform("muzzle", p)

	if silenced == true then mt = GetToolLocationWorldTransform("supend", p) end

	local ammo = GetToolAmmo(WPNID, p)

	local pos, dir = getAimVector(mt.pos, MAX_RANGE, 0.01, p)

	ShootHook(pos, dir, "bullet", DAMAGE, PLAYERDAMAGE, MAX_RANGE, p, WPNID, WPNNAME, 2)
	
	if ammo < 9999 then
		SetToolAmmo(WPNID, ammo-1, p)
	end
end

function server.secondaryFirePIST9MM(p, silenced) -- separated for easy modability
	local mt = GetToolLocationWorldTransform("muzzle", p)
	
	if silenced == true then mt = GetToolLocationWorldTransform("supend", p) end

	local ammo = GetToolAmmo(WPNID, p)

	local pos, dir = getAimVector(mt.pos, MAX_RANGE, 0.1, p)

	ShootHook(pos, dir, "bullet", DAMAGE, PLAYERDAMAGE, MAX_RANGE, p, WPNID, WPNNAME, 2)
	
	if ammo < 9999 then
		SetToolAmmo(WPNID, ammo-1, p)
	end
end

function client.initPIST9MM()
	shootHaptic = LoadHaptic("MOD/haptic/gun_fire.xml")
	local toolHaptic = LoadHaptic("MOD/haptic/background.xml")
	SetToolHaptic(WPNID, toolHaptic);
end

function client.tickPIST9MM(dt)
	for p in PlayersAdded() do
		PIST9MMplayers[p] = createPlayerCLIENTdataPIST9MM();
	end

	for p in PlayersRemoved() do
		PIST9MMplayers[p] = nil
	end

	for p in Players() do
		client.tickPlayerPIST9MM(p, dt)
	end
end

clipamnt = 0
local camSineTime = nil

function client.suppress(p, suppressed)
	local toolBody = GetToolBody(p)
	local shapes = GetBodyShapes(toolBody)
	if suppressed == false then
		SetTag(shapes[5], "invisible")
	else
		RemoveTag(shapes[5], "invisible")
	end
end

function client.tickPlayerPIST9MM(p, dt)
	if not IsToolEnabled(WPNID, p) then 
		return 
	end
	
	if GetPlayerHealth(p) <= 0 then
		if PIST9MMplayers[p].dataReset == false then
			PIST9MMplayers[p] = createPlayerCLIENTdataPIST9MM()
		end
		return
	end
	
	if GetPlayerTool(p) ~= WPNID then
		PIST9MMplayers[p].firstDraw = true
		if IsPlayerLocal(p) then
			camSineTime = nil
		end
		return
	end

	local pt = GetPlayerTransform(p)
	local mt = GetToolLocationWorldTransform("muzzle", p)

	if PIST9MMplayers[p].suppressed == true then mt = GetToolLocationWorldTransform("supend", p) end

	local ammo = GetToolAmmo(WPNID, p)

	if mt == nil then
		return
	end
	
	local data = PIST9MMplayers[p]

	-- restore suppresor state visually
	if data.firstDraw == true then
		if HasTag(GetBodyShapes(GetToolBody(p))[5], "invisible") == true then
			client.suppress(p, data.suppressed)
			data.firstDraw = false
		end
	end

	-- make data reset when reset conditions are met
	data.dataReset = false

	if InputPressed("r", p) and data.inreload == false and data.clipamntPIST9MM < CLIP_SIZE and ammo > 0.5 and data.clipamntPIST9MM ~= ammo then
		PlaySound(LoadSound(RELOAD_SOUND), pt.pos)
		if data.clipamntPIST9MM > 0 then
			data.coolDown = RELOAD_TIME
			data.altCoolDown = RELOAD_TIME
		end
		data.inreload = true
	end
	
	if data.coolDown < 0 and data.inreload == true then	
		data.inreload = false
		data.clipamntPIST9MM = CLIP_SIZE
		if data.clipamntPIST9MM > ammo then -- make sure the clip cannot be higher than ammo
			data.clipamntPIST9MM = ammo
		end
	end

	if InputDown("usetool", p) and ammo > 0.5 and GetPlayerCanUseTool(p) == true then
		if data.coolDown < 0 then
			StopSound(data.firesound)
			
			local toolBody = GetToolBody(p)
			local playervel = GetPlayerVelocity(p)

			if data.suppressed == false then
				PointLight(mt.pos, 1, 0.7, 0.5, 3)
				if IsPlayerLocal(p) then
					data.firesound = PlaySound(LoadSound(PRIM_FIRESOUND), mt.pos, 300)
					ServerCall("server.primaryFirePIST9MM", p, data.suppressed)
					camSineTime = 0
					PlayHaptic(shootHaptic, 1)

					-- shell ejection
					local transform = GetBodyTransform(toolBody)
					local eject_origin = TransformToParentPoint(transform, Vec(CASING_ORG[1],CASING_ORG[2],CASING_ORG[3]))
					local eject_direction=TransformToParentVec(transform, Vec(1, 0.2, 0))
					ParticleReset()
					ParticleGravity(rnd(-2, -8))
					ParticleRadius(0.02)
					ParticleAlpha(1)
					ParticleColor(0.8, 0.6, 0)
					ParticleTile(6)
					ParticleDrag(0.125)
					ParticleSticky(0.5)
					ParticleCollide(1)
					SpawnParticle(eject_origin, VecAdd(VecScale(eject_direction,3), playervel), 5)
				else
					data.firesound = PlaySound(LoadSound(NONCLIENTPRIM_FIRESOUND), mt.pos, 300)
				end
			else
				if IsPlayerLocal(p) then
					data.firesound = PlaySound(LoadSound(SUPPRIM_FIRESOUND), mt.pos, 20)
					ServerCall("server.primaryFirePIST9MM", p, data.suppressed)
					camSineTime = 0
					PlayHaptic(shootHaptic, 1)

					-- shell ejection
					local transform = GetBodyTransform(toolBody)
					local eject_origin = TransformToParentPoint(transform, Vec(CASING_ORG[1],CASING_ORG[2],CASING_ORG[3]))
					local eject_direction=TransformToParentVec(transform, Vec(1, 0.2, 0))
					ParticleReset()
					ParticleGravity(rnd(-2, -8))
					ParticleRadius(0.02)
					ParticleAlpha(1)
					ParticleColor(0.8, 0.6, 0)
					ParticleTile(6)
					ParticleDrag(0.125)
					ParticleSticky(0.5)
					ParticleCollide(1)
					SpawnParticle(eject_origin, VecAdd(VecScale(eject_direction,3), playervel), 5)
				else
					data.firesound = PlaySound(LoadSound(SUPNONCLIENTPRIM_FIRESOUND), mt.pos, 20)
				end
			end
			
			-- muzzleflash
			if data.suppressed == false then
				for i=0, 2 do
					ParticleReset()
					ParticleGravity(0)
					ParticleRadius(rnd(0.08, 0.13), 0.3)
					ParticleAlpha(1, 0)
					ParticleTile(5)
					ParticleDrag(0)
					ParticleRotation(rnd(10, -10), 0)
					ParticleSticky(0)
					ParticleEmissive(5, 1)
					ParticleCollide(0)
					ParticleColor(1,0.35,0, 1,0,0)
					SpawnParticle(mt.pos, playervel, 0.125)
				end
			else
				for i=0, 2 do
					ParticleReset()
					ParticleGravity(0)
					ParticleRadius(rnd(0.08, 0.12), 0.2)
					ParticleAlpha(0.75, 0)
					ParticleTile(5)
					ParticleDrag(0)
					ParticleRotation(rnd(10, -10), 0)
					ParticleSticky(0)
					ParticleCollide(0)
					ParticleColor(0.5,0.5,0.5, 0.25,0.25,0.25)
					SpawnParticle(mt.pos, playervel, 0.125)
				end
			end
				
			data.clipamntPIST9MM = data.clipamntPIST9MM - 1
			if data.clipamntPIST9MM > 0 then
				data.coolDown = FIRERATE
				data.altCoolDown = FIRERATE
			elseif ammo > 1 then
				PlaySound(LoadSound(RELOAD_SOUND), pt.pos)
				data.coolDown = RELOAD_TIME
				data.altCoolDown = RELOAD_TIME
				data.inreload = true
			end
			
			data.recoil = RECOIL_AMNT
		end
	end

	if InputDown("grab", p) and ammo > 0.5 and GetPlayerCanUseTool(p) == true then
		if data.altCoolDown < 0 then
			StopSound(data.firesound)

			local playervel = GetPlayerVelocity(p)

			if data.suppressed == false then
				PointLight(mt.pos, 1, 0.7, 0.5, 3)
				if IsPlayerLocal(p) then
					data.firesound = PlaySound(LoadSound(PRIM_FIRESOUND), mt.pos, 300)
					ServerCall("server.secondaryFirePIST9MM", p, data.suppressed)
					camSineTime = 0
					PlayHaptic(shootHaptic, 1)

					-- shell ejection
					local toolBody = GetToolBody(p)
					local transform = GetBodyTransform(toolBody)
					local eject_origin = TransformToParentPoint(transform, Vec(CASING_ORG[1],CASING_ORG[2],CASING_ORG[3]))
					local eject_direction=TransformToParentVec(transform, Vec(1, 0.2, 0))
					ParticleReset()
					ParticleGravity(rnd(-2, -8))
					ParticleRadius(0.02)
					ParticleAlpha(1)
					ParticleColor(0.8, 0.6, 0)
					ParticleTile(6)
					ParticleDrag(0.125)
					ParticleSticky(0.5)
					ParticleCollide(1)
					SpawnParticle(eject_origin, VecAdd(VecScale(eject_direction,3), playervel), 5)

				else
					data.firesound = PlaySound(LoadSound(NONCLIENTPRIM_FIRESOUND), mt.pos, 300)
				end
			else
				if IsPlayerLocal(p) then
					data.firesound = PlaySound(LoadSound(SUPPRIM_FIRESOUND), mt.pos, 20)
					ServerCall("server.secondaryFirePIST9MM", p, data.suppressed)
					camSineTime = 0
					PlayHaptic(shootHaptic, 1)

					-- shell ejection
					local toolBody = GetToolBody(p)
					local transform = GetBodyTransform(toolBody)
					local eject_origin = TransformToParentPoint(transform, Vec(CASING_ORG[1],CASING_ORG[2],CASING_ORG[3]))
					local eject_direction=TransformToParentVec(transform, Vec(1, 0.2, 0))
					ParticleReset()
					ParticleGravity(rnd(-2, -8))
					ParticleRadius(0.02)
					ParticleAlpha(1)
					ParticleColor(0.8, 0.6, 0)
					ParticleTile(6)
					ParticleDrag(0.125)
					ParticleSticky(0.5)
					ParticleCollide(1)
					SpawnParticle(eject_origin, VecAdd(VecScale(eject_direction,3), playervel), 5)
				else
					data.firesound = PlaySound(LoadSound(SUPNONCLIENTPRIM_FIRESOUND), mt.pos, 20)
				end
			end
			
			-- muzzleflash
			if data.suppressed == false then
				for i=0, 2 do
					ParticleReset()
					ParticleGravity(0)
					ParticleRadius(rnd(0.08, 0.13), 0.3)
					ParticleAlpha(1, 0)
					ParticleTile(5)
					ParticleDrag(0)
					ParticleRotation(rnd(10, -10), 0)
					ParticleSticky(0)
					ParticleEmissive(5, 1)
					ParticleCollide(0)
					ParticleColor(1,0.35,0, 1,0,0)
					SpawnParticle(mt.pos, playervel, 0.125)
				end
			else
				for i=0, 2 do
					ParticleReset()
					ParticleGravity(0)
					ParticleRadius(rnd(0.08, 0.12), 0.2)
					ParticleAlpha(0.75, 0)
					ParticleTile(5)
					ParticleDrag(0)
					ParticleRotation(rnd(10, -10), 0)
					ParticleSticky(0)
					ParticleCollide(0)
					ParticleColor(0.5,0.5,0.5, 0.25,0.25,0.25)
					SpawnParticle(mt.pos, playervel, 0.125)
				end
			end
			
			data.toolAnimator.timeSinceFire = 0.0 -- hold the gun straight
			
			data.clipamntPIST9MM = data.clipamntPIST9MM - 1
			if data.clipamntPIST9MM > 0 then
				data.coolDown = ALTFIRERATE
				data.altCoolDown = ALTFIRERATE
			elseif ammo > 1 then
				PlaySound(LoadSound(RELOAD_SOUND), pt.pos)
				data.coolDown = RELOAD_TIME
				data.altCoolDown = RELOAD_TIME
				data.inreload = true
			end
			
			data.recoil = RECOIL_AMNT
		end
	end
	
	if InputPressed("mmb", p) and GetPlayerCanUseTool(p) == true then
		if data.tertiaryCoolDown < 0 then
			data.tertiaryCoolDown = 0.5
			data.suppressed = not data.suppressed
			client.suppress(p, data.suppressed)
		end
	end
	
	-- decrease firing cooldown and recoil
	data.coolDown = data.coolDown - dt
	data.altCoolDown = data.altCoolDown - dt
	data.tertiaryCoolDown = data.tertiaryCoolDown - dt
	data.recoil = data.recoil - dt
	
	-- RECOIL
	if data.recoil > -0.5 then
		local recoil = math.max(0, data.recoil)
		local siderecoil = recoil * 0.25
		local recoilvert = math.max(0, data.recoil)
		
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

			local equation = amp * ((math.sin(CAMMOVETIME * x) * e^(balance * x)) * x)

			if equation >= 0 then
				local t = Transform(Vec(), QuatAxisAngle(Vec(1.0, -1.0, 0), equation))
				SetPlayerCameraOffsetTransform(t)
				camSineTime = camSineTime + dt
			else camSineTime = nil end
		end

		-- UPD AMMO HUD
		if data.inreload == false and ammo > 0.5 then
			clipamnt = data.clipamntPIST9MM
		elseif ammo > 0.5 then
			clipamnt = -8 -- negative 8 means reloading
		else
			data.clipamntM727 = 0
			clipamnt = -16
		end
	end
end

function client.drawPIST9MM()
	if GetPlayerTool() ~= WPNID then -- shouldn't need the player pointer since this runs on client
		return
	end

	client.drawAmmo(clipamnt, CLIP_SIZE)
end