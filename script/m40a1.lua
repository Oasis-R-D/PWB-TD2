-- copy this for the most basic scoped mag loaded weapon with slower empty reloads (INCLUDES SCOPE)
#version 2

#include "script/include/player.lua"
#include "script/pwbtoolanimation.lua"
#include "script/util.lua"

-- Per weapon constants
local RELOAD_TIME = 2.32 -- seconds
local EMPTYRELOAD_TIME = 4.1 -- seconds
local TACRELOAD_SOUND = "MOD/snd/m40r.ogg"
local EMPTRELOAD_SOUND = "MOD/snd/m40rfll.ogg"
local PRIM_FIRESOUND = "MOD/snd/m40FR.ogg"
local ALT_FIRESOUND = "MOD/snd/m40scp.ogg"
local BOLT_CYCLE = "MOD/snd/m40bolt.ogg"
local CLIP_SIZE = 5.0
local PICKUP_SIZE = 15.0
local RECOIL_AMNT = 0.25
local FIRERATE = 2.0
local CAMMOVETIME = (2 * math.pi) * (0.5 / FIRERATE) -- Cam movement sine multiplier, FIRERATE is how long until it's over
local ALTFIRERATE = 0.5
local SCOPEFIREDELAY = 0.1
local DAMAGE = 0.6 -- x5
local PLAYERDAMAGE = 0.75 -- instakills in opfor
local MAX_RANGE = 500.0
local WPNID = "opform40a1"
local WPNNAME = "M40A1"
local CASING_ORG = Vec(0.02, 0.25, -0.2) -- casing origin

-- Per weapon data storer
M40players = {}

function createPlayerCLIENTdataM40()
    return {
		clipamntM40 = CLIP_SIZE,
		inreload = false,
		coolDown = 0.0,
		altCoolDown = 0.0,
		recoil = 0.0,
		toolAnimator = ToolAnimator(),
		scoped = false,
		timetobolt = nil,
		playbolt = true,
		dataReset = true,
	}
end

function server.initM40()
	RegisterTool(WPNID, WPNNAME, "MOD/prefab/m40a1.xml", 6)
	SetToolAmmoPickupAmount(WPNID, PICKUP_SIZE)
end

function server.tickM40(dt)
	for p in PlayersAdded() do
		SetToolEnabled(WPNID, true, p)
		SetToolAmmo(WPNID, 250, p)
	end

	-- doesn't need server ticking
	--for p in Players() do
		--server.tickPlayerM40(p, dt)
	--end
end

function server.tickPlayerM40(p, dt)
end

function server.primaryFireM40(p)
	local mt = GetToolLocationWorldTransform("muzzle", p)

	local ammo = GetToolAmmo(WPNID, p)

	local pos, dir = getAimVector(mt.pos, MAX_RANGE, 0, p)

	ShootHook(pos, dir, "bullet", DAMAGE, PLAYERDAMAGE, MAX_RANGE, p, WPNID, WPNNAME, 2)

	PlaySound(LoadSound(PRIM_FIRESOUND), mt.pos, 300)
	
	if ammo < 9999 then
		SetToolAmmo(WPNID, ammo-1, p)
	end
end

function client.initM40()
	shootHaptic = LoadHaptic("MOD/haptic/gun_fire.xml")
	local toolHaptic = LoadHaptic("MOD/haptic/background.xml")
	SetToolHaptic(WPNID, toolHaptic);
end

function client.tickM40(dt)
	for p in PlayersAdded() do
		M40players[p] = createPlayerCLIENTdataM40();
	end

	for p in PlayersRemoved() do
		M40players[p] = nil
	end

	for p in Players() do
		client.tickPlayerM40(p, dt)
	end
end

scopeddraw = false
clipamnt = 0
local camSineTime = nil

function client.tickPlayerM40(p, dt)
	if not IsToolEnabled(WPNID, p) then return end
	
	if GetPlayerHealth(p) <= 0 then
		if M40players[p].dataReset == false then
			M40players[p] = createPlayerCLIENTdataM40()
		end
		return
	end

	if GetPlayerTool(p) ~= WPNID then
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

	local data = M40players[p]

	-- make data reset when reset conditions are met
	data.dataReset = false

	if InputPressed("r", p) and data.inreload == false and data.clipamntM40 < CLIP_SIZE and ammo > 0.5 and data.clipamntM40 ~= ammo then
		if data.clipamntM40 > 0 then
			data.coolDown = RELOAD_TIME
			PlaySound(LoadSound(TACRELOAD_SOUND), pt.pos)
		else
			data.coolDown = EMPTYRELOAD_TIME
		end
		data.inreload = true
	end
	
	if data.coolDown < 0 and data.inreload == true then	
		data.inreload = false
		data.clipamntM40 = CLIP_SIZE
		if data.clipamntM40 > ammo then -- make sure the clip cannot be higher than ammo
			data.clipamntM40 = ammo
		end
	end

	if InputDown("usetool", p) and ammo > 0.5 and GetPlayerCanUseTool(p) == true then
			if data.coolDown < 0 then
				PointLight(mt.pos, 1, 0.7, 0.5, 3)
				if IsPlayerLocal(p) then
					ServerCall("server.primaryFireM40", p)
					camSineTime = 0
					PlayHaptic(shootHaptic, 1)
				end
				
				local playervel = GetPlayerVelocity(p)

				-- muzzleflash
				for i=0, 3 do
					ParticleReset()
					ParticleGravity(0)
					ParticleRadius(rnd(0.1, 0.15), 0.33)
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
				data.timetobolt = 0.842
				data.clipamntM40 = data.clipamntM40 - 1
				if data.clipamntM40 > 0 then
					data.coolDown = FIRERATE
					data.altCoolDown = SCOPEFIREDELAY
					
				elseif ammo > 1 then
					data.recoil = 0.05
					PlaySound(LoadSound(EMPTRELOAD_SOUND), pt.pos)
					data.coolDown = EMPTYRELOAD_TIME
					data.inreload = true
				end
				
				data.recoil = RECOIL_AMNT
			end
	end

	if InputPressed("grab", p) and GetPlayerCanUseTool(p) == true then
		if data.altCoolDown < 0 then
			if IsPlayerLocal(p) then
				PlaySound(LoadSound(ALT_FIRESOUND), pt.pos)
			end
			data.altCoolDown = ALTFIRERATE
			data.scoped = not data.scoped
		end
	end

	if data.scoped == false or data.clipamntM40 < 0 or ammo <= 0 then
		data.toolAnimator.forceSecondaryActionPose = false

		if IsPlayerLocal(p) then
			scopeddraw = false
		end
	elseif data.scoped == true then
		data.toolAnimator.forceSecondaryActionPose = true

		if IsPlayerLocal(p) then
			scopeddraw = true
			SetCameraFov(18)
		end
	end
		
	-- decrease firing cooldown and recoil
	data.coolDown = data.coolDown - dt
	data.altCoolDown = data.altCoolDown - dt
	data.recoil = data.recoil - dt
	
	if data.timetobolt ~= nil then
		data.timetobolt = data.timetobolt - dt
		if data.timetobolt <= 0 and data.playbolt == true then
			if data.clipamntM40 > 0 then -- already plays bolt sfx in reload
				PlaySound(LoadSound(BOLT_CYCLE), pt.pos)
			end
			data.playbolt = false
			data.recoil = 0.05
		end
		if data.timetobolt <= -0.1 then
			if IsPlayerLocal(p) then
				local toolBody = GetToolBody(p)
				local transform = GetBodyTransform(toolBody)
				local eject_origin = TransformToParentPoint(transform, Vec(CASING_ORG[1],CASING_ORG[2],CASING_ORG[3]))
				local playervel = GetPlayerVelocity(p)
				
				-- shell ejection
				local eject_direction=TransformToParentVec(transform, Vec(1, -0.2, 0))
				ParticleReset()
				ParticleGravity(rnd(-2, -8))
				ParticleRadius(0.02)
				ParticleAlpha(1)
				ParticleColor(0.8, 0.6, 0)
				ParticleTile(6)
				ParticleDrag(0.125)
				ParticleSticky(0.5)
				ParticleCollide(1)
				SpawnParticle(eject_origin, VecAdd(VecScale(eject_direction,3), playervel), 5) -- player velocity isn't functioning how i'd like but whatever
			end

			data.timetobolt = nil
			data.playbolt = true
			data.recoil = 0.025
		end
	end
	-- END SHELL EJECT
	
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
			local balance = -10 -- where the peak is (10 for middle, higher to move left also has to be neagtive)
			local amp = 800 -- how intense (y at the peak will not equal this though)

			local equation = amp * ((math.sin(CAMMOVETIME * x) * e^(balance * x)) * x)

			if equation >= 0 then
				local t = Transform(Vec(), QuatAxisAngle(Vec(1.0, -0.33, 0), equation))
				SetPlayerCameraOffsetTransform(t)
				camSineTime = camSineTime + dt
			else camSineTime = nil end
		end

		-- UPD AMMO HUD
		if data.inreload == false and ammo > 0.5 then
			clipamnt = data.clipamntM40
		elseif ammo > 0.5 then
			clipamnt = -8 -- negative 8 means reloading
		else
			data.clipamntM727 = 0
			clipamnt = -16
		end
	end
end

function client.drawM40()
	if GetPlayerTool() ~= WPNID then -- shouldn't need the player pointer since this runs on client
		return
	end
	if scopeddraw == true then
		UiPush()
			UiTranslate(UiCenter(), UiMiddle())
			UiAlign("center middle")
			UiImage("MOD/scope.png")
		UiPop()
	end
	client.drawAmmo(clipamnt, CLIP_SIZE)
end