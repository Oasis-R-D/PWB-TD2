-- copy this for the most basic revolver
#version 2

#include "script/include/player.lua"
#include "script/pwbtoolanimation.lua"
#include "script/util.lua"


-- Per weapon constants
local RELOAD_TIME = 3.6666 -- seconds
local RELOAD_SOUND = "MOD/snd/357R.ogg"
local PRIM_FIRESOUND = "MOD/snd/357FR0.ogg"
local CLIP_SIZE = 6.0
local PICKUP_SIZE = 12.0
local RECOIL_AMNT = 0.3
local FIRERATE = 0.75
local CAMMOVETIME = (2 * math.pi) * (0.5 / FIRERATE) -- Cam movement sine multiplier, FIRERATE is how long until it's over
local ALTFIRERATE = 0.5
local DAMAGE = 0.5
local PLAYERDAMAGE = 0.75
local MAX_RANGE = 150.0
local WPNID = "hl2python"
local WPNNAME = "Colt Python"
local CASING_ORG = Vec(-0.1, 0.25, 0.15)
local ADSFOV = 40

-- Per weapon data storer
PYTHplayers = {}

function createPlayerCLIENTdataPYTH()
    return {
		clipamntPYTH = CLIP_SIZE,
		inreload = false,
		coolDown = 0.0,
		altCoolDown = 0.0,
		recoil = 0.0,
		timeuntileject = nil,
		toolAnimator = ToolAnimator(),
		scoped = false,
		dataReset = true,
	}
end

function createPlayerSERVERdataPYTH()
    return {
		firesound = nil,
	}
end

function server.initPYTH()
	RegisterTool(WPNID, WPNNAME, "MOD/prefab/python.xml", 3)
	SetToolAmmoPickupAmount(WPNID, PICKUP_SIZE)
end

function server.tickPYTH(dt)
	for p in PlayersAdded() do
		PYTHplayers[p] = createPlayerSERVERdataPYTH()
		SetToolEnabled(WPNID, true, p)
		SetToolAmmo(WPNID, 250, p)
	end

	for p in PlayersRemoved() do
		PYTHplayers[p] = nil
	end

	--for p in Players() do
		--server.tickPlayerPYTH(p, dt)
	--end
end

function server.tickPlayerPYTH(p, dt)
end

function server.primaryFirePYTH(p)
	local mt = GetToolLocationWorldTransform("muzzle", p)
	local data = PYTHplayers[p]

	local pos, dir = getAimVector(mt.pos, MAX_RANGE, 0, p)

	ShootHook(pos, dir, "bullet", DAMAGE, PLAYERDAMAGE, MAX_RANGE, p, WPNID, WPNNAME, 1.5)

	StopSound(data.firesound)
	data.firesound = PlaySound(LoadSound(PRIM_FIRESOUND), mt.pos, 300)

	server.depleteAmmo(p, WPNID)
end

function client.initPYTH()
	shootHaptic = LoadHaptic("MOD/haptic/gun_fire.xml")
	local toolHaptic = LoadHaptic("MOD/haptic/background.xml")
	SetToolHaptic(WPNID, toolHaptic);
end

function client.tickPYTH(dt)
	for p in PlayersAdded() do
		PYTHplayers[p] = createPlayerCLIENTdataPYTH();
	end

	for p in PlayersRemoved() do
		PYTHplayers[p] = nil
	end

	for p in Players() do
		client.tickPlayerPYTH(p, dt)
	end
end

clipamnt = 0
local camSineTime = nil

function client.tickPlayerPYTH(p, dt)
	if not IsToolEnabled(WPNID, p) then return end
	
	if GetPlayerHealth(p) <= 0 then
		if PYTHplayers[p].dataReset == false then
			PYTHplayers[p] = createPlayerCLIENTdataPYTH()
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

	local data = PYTHplayers[p]

	-- make data reset when reset conditions are met
	data.dataReset = false
	
	if InputPressed("r", p) and data.inreload == false and data.clipamntPYTH < CLIP_SIZE and ammo > 0.5 and data.clipamntPYTH ~= ammo then
		PlaySound(LoadSound(RELOAD_SOUND), pt.pos)
		if data.clipamntPYTH > 0 then
			data.coolDown = RELOAD_TIME
			data.timeuntileject = 1.35
		end
		data.inreload = true
	end
	
	if data.coolDown < 0 and data.inreload == true then	
		data.inreload = false
		data.clipamntPYTH = CLIP_SIZE
		if data.clipamntPYTH > ammo then -- make sure the clip cannot be higher than ammo
			data.clipamntPYTH = ammo
		end
	end

	if InputDown("usetool", p) and ammo > 0.5 and GetPlayerCanUseTool(p) == true then
			if data.coolDown < 0 then	
				PointLight(mt.pos, 1, 0.7, 0.5, 3)
				if IsPlayerLocal(p) then
					ServerCall("server.primaryFirePYTH", p)
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
					
				data.clipamntPYTH = data.clipamntPYTH - 1
				if data.clipamntPYTH > 0 then
					data.coolDown = FIRERATE
				elseif ammo > 1 then
					PlaySound(LoadSound(RELOAD_SOUND), pt.pos)
					data.coolDown = RELOAD_TIME
					data.timeuntileject = 1.35
					data.inreload = true
				end
				
				data.recoil = RECOIL_AMNT
			end
	end
	
	if InputPressed("grab", p) and GetPlayerCanUseTool(p) == true then
		if data.altCoolDown < 0 then
			if IsPlayerLocal(p) then
				--PlaySound(LoadSound(ALT_FIRESOUND), pt.pos)
			end
			data.altCoolDown = ALTFIRERATE
			data.scoped = not data.scoped
		end
	end

	if data.scoped == false or data.clipamntPYTH < 0 or ammo <= 0 then
		data.toolAnimator.forceSecondaryActionPose = false
	elseif data.scoped == true then
		data.toolAnimator.timeSinceFire = 1.5 -- make unscoping take ~0.5
		data.toolAnimator.forceSecondaryActionPose = true

		if IsPlayerLocal(p) then
			local fov = 40
			SetCameraFov(fov)
		end
	end

	-- decrease firing cooldown and recoil
	data.coolDown = data.coolDown - dt
	data.altCoolDown = data.altCoolDown - dt
	data.recoil = data.recoil - dt
	
	-- RECOIL
	if data.recoil > -0.5 then
		local recoil = math.max(0, data.recoil)
		local siderecoil = recoil * 0.125
		local recoilvert = math.max(0, data.recoil * 1.2)
		
		local inversesiderecoil = rnd(0, 1)
		if inversesiderecoil > 0.5 then
			siderecoil = siderecoil * -1
		end

		data.toolAnimator.offsetTransform = Transform(Vec(siderecoil,recoil,recoilvert), QuatEuler(recoil * 100, 0, 0))
	end 
	-- END RECOIL
	
	tickToolAnimator(data.toolAnimator, dt, nil, p)

	
	if IsPlayerLocal(p) then
		-- CAMERA MOVEMENT
		if camSineTime ~= nil then
			local x = camSineTime
			local e = math.exp(1)
			local balance = -10 -- where the peak is (10 for middle, higher to move left also has to be neagtive)
			local amp = 200 -- how intense (y at the peak will not equal this though)

			local equation = amp * ((math.sin(CAMMOVETIME * x) * e^(balance * x)) * x)

			if equation >= 0 then
				local t = Transform(Vec(), QuatAxisAngle(Vec(1.0, 0.0, 0), equation))
				SetPlayerCameraOffsetTransform(t)
				camSineTime = camSineTime + dt
			else camSineTime = nil end
		end

		-- UPD AMMO HUD
		if data.inreload == false and ammo > 0.5 then
			clipamnt = data.clipamntPYTH
		elseif ammo > 0.5 then
			clipamnt = -8 -- negative 8 means reloading
		else
			data.clipamntM727 = 0
			clipamnt = -16
		end

		-- SHELL EJECT
		if data.timeuntileject ~= nil then
			data.timeuntileject = data.timeuntileject - dt
			
			if data.timeuntileject <= 0 then
				local toolBody = GetToolBody(p)
				local transform = GetBodyTransform(toolBody)
				local eject_origin = TransformToParentPoint(transform, Vec(CASING_ORG[1],CASING_ORG[2],CASING_ORG[3]))
				local playervel = GetPlayerVelocity(p)
				
				-- shell ejection
				for i=0, 5 do
					local eject_direction=TransformToParentVec(transform, Vec(rnd(-0.025, 0.025), -0.2, rnd(-0.025, 0.025)))
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
				data.recoil = 0.1
				data.timeuntileject = nil
			end
		end
	end
end

function client.drawPYTH()
	if GetPlayerTool() ~= WPNID then -- shouldn't need the player pointer since this runs on client
		return
	end

	client.drawAmmo(clipamnt, CLIP_SIZE)
end