-- copy this for the most basic mag loaded weapon with alt fire
#version 2

#include "script/include/player.lua"
#include "script/pwbtoolanimation.lua"
#include "script/util.lua"

-- Per weapon constants
local RELOAD_TIME = 1.5 -- seconds
local RELOAD_SOUND = "MOD/snd/smg1_reload.ogg"
local ALT_FIRESOUND = "MOD/snd/smg1_altfire.ogg"
local PRIM_FIRESOUND = "MOD/snd/smg1_fire.ogg"
local CLIP_SIZE = 45
local PICKUP_SIZE = 45
local RECOIL_AMNT = 0.1
local FIRERATE = 0.075
local CAMMOVETIME = (2 * math.pi) * (0.5 / FIRERATE) -- Cam movement sine multiplier, FIRERATE is how long until it's over
local ALTFIRERATE = 1
local CAMALTMOVETIME = (2 * math.pi) * (0.5 / ALTFIRERATE) -- Cam movement sine multiplier, ALTFIRERATE is how long until it's over
local DAMAGE = 0.4
local PLAYERDAMAGE = 0.05
local MAX_RANGE = 100.0
local WPNID = "hl2smg1"
local WPNNAME = "Combine SMG"
local CASING_ORG = Vec(0.02, 0.15, -0.15)	-- casing origin

-- Per weapon data storer
SMG1players = {}

function createPlayerCLIENTdataSMG1()
    return {
		clipamntSMG1 = CLIP_SIZE,
		m203amntSMG1 = 1,
		inreload = false,
		coolDown = 0.0,
		altCoolDown = 0.0,
		recoil = 0.0,
		toolAnimator = ToolAnimator(),
		camAltMove = false,
		dataReset = true,
	}
end

function createPlayerSERVERdataSMG1()
    return {
		firesound = nil,
	}
end

function server.initSMG1()
	RegisterTool(WPNID, WPNNAME, "MOD/prefab/smg1.xml", 3)
	SetToolAmmoPickupAmount(WPNID, PICKUP_SIZE)
end

function server.tickSMG1(dt)
	for p in PlayersAdded() do
		SMG1players[p] = createPlayerCLIENTdataSMG1()
		SetToolEnabled(WPNID, true, p)
		SetToolAmmo(WPNID, 250, p)
	end

	for p in PlayersRemoved() do
		SMG1players[p] = nil
	end

	-- doesn't need server ticking
	--for p in Players() do
		--server.tickPlayerSMG1(p, dt)
	--end
end

function server.tickPlayerSMG1(p, dt)
end

function server.primaryFireSMG1(p)
	local mt = GetToolLocationWorldTransform("muzzle", p)

	local data = SMG1players[p]
	
	local pos, dir = getAimVector(mt.pos, MAX_RANGE, GLOBAL_5DEGREES, p)
	
	ShootHook(pos, dir, "bullet", DAMAGE, PLAYERDAMAGE, MAX_RANGE, p, WPNID, WPNNAME)
	
	StopSound(data.firesound)
	data.firesound = PlaySound(LoadSound(PRIM_FIRESOUND), mt.pos, 300)
	
	server.depleteAmmo(p, WPNID)
end

function server.secondaryFireSMG1(p)
	local mt = GetToolLocationWorldTransform("muzzle", p)

	local _,pos,_,dir = GetPlayerAimInfo(mt.pos, MAX_RANGE, p)

	pos = VecAdd(pos, VecScale(dir, 0.5))
	
	local GrenTrans = Transform(pos, QuatLookAt(Vec(), dir))
	local xml = "MOD/prefab/gren_m203.xml"
	grenade_ent = Spawn(xml, GrenTrans)
	SetTag(grenade_ent[2], "grenType", "m203")
	SetTag(grenade_ent[2], "grenStyle", "impact")
	SetTag(grenade_ent[2], "playerThrew", p)
	SetBodyVelocity(grenade_ent[2], VecScale(dir, 20.32))

	SetBodyAngularVelocity(grenade_ent[2], TransformToParentVec(GetPlayerEyeTransform(p), Vec(rnd(-10.16, 10.16), 0, 0)))

	PlaySound(LoadSound(ALT_FIRESOUND), mt.pos, 300)
end

function client.initSMG1()
	shootHaptic = LoadHaptic("MOD/haptic/gun_fire.xml")
	local toolHaptic = LoadHaptic("MOD/haptic/background.xml")
	SetToolHaptic(WPNID, toolHaptic);
end

function client.tickSMG1(dt)
	for p in PlayersAdded() do
		SMG1players[p] = createPlayerCLIENTdataSMG1();
	end

	for p in PlayersRemoved() do
		SMG1players[p] = nil
	end

	for p in Players() do
		client.tickPlayerSMG1(p, dt)
	end
end

clipamnt = 0
altclipamnt = 0
local camSineTime = nil
local camRecoilY = 0
local camRecoilX = 0

function client.tickPlayerSMG1(p, dt)
	if not IsToolEnabled(WPNID, p) then return end
	
	if GetPlayerHealth(p) <= 0 then
		if SMG1players[p].dataReset == false then
			SMG1players[p] = createPlayerCLIENTdataSMG1()
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

	local data = SMG1players[p]

	-- make data reset when reset conditions are met
	data.dataReset = false

	if InputPressed("r", p) and data.inreload == false and data.clipamntSMG1 < CLIP_SIZE and ammo > 0.5 and data.clipamntSMG1 ~= ammo then
		PlaySound(LoadSound(RELOAD_SOUND), pt.pos)
		data.coolDown = RELOAD_TIME
		data.inreload = true
	end
	
	if data.coolDown < 0 and data.inreload == true then	
		data.inreload = false
		data.m203amntSMG1 = 1
		data.clipamntSMG1 = CLIP_SIZE
		if data.clipamntSMG1 > ammo then -- make sure the clip cannot be higher than ammo
			data.clipamntSMG1 = ammo
		end
	end

	if InputDown("usetool", p) and ammo > 0.5 and GetPlayerCanUseTool(p) == true then
			if data.coolDown < 0 then	
				PointLight(mt.pos, 1, 0.7, 0.5, 3)

				local playervel = GetPlayerVelocity(p)

				if IsPlayerLocal(p) then
					ServerCall("server.primaryFireSMG1", p)
					camSineTime = 0
					camRecoilY = rnd(-1, 1)
					camRecoilX = rnd(-1, 1)
					data.camAltMove = false
					PlayHaptic(shootHaptic, 1)

					-- shell ejection
					local toolBody = GetToolBody(p)
					local transform = GetBodyTransform(toolBody)
					local eject_origin = TransformToParentPoint(transform, Vec(CASING_ORG[1],CASING_ORG[2],CASING_ORG[3]))
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
					SpawnParticle(eject_origin, VecAdd(VecScale(eject_direction,3), playervel), 5)
				end
				
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
					
				data.clipamntSMG1 = data.clipamntSMG1 - 1
				if data.clipamntSMG1 > 0 then
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

	if InputPressed("grab", p) and data.m203amntSMG1 > 0.5 and GetPlayerCanUseTool(p) == true  then
			if data.altCoolDown < 0 then
				PointLight(mt.pos, 1, 0.7, 0.5, 3)
				if IsPlayerLocal(p) then
					ServerCall("server.secondaryFireSMG1", p)
					camSineTime = 0
					camRecoilY = 0
					camRecoilX = 1
					data.camAltMove = true
					PlayHaptic(shootHaptic, 1)
				end
				
				local toolBody = GetToolBody(p)
				local playervel = GetPlayerVelocity(p)
				local vectuh = VecAdd(mt.pos, Vec(0, -0.25, 0))
				
				-- muzzleflash
				for i=0, 4 do
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
					SpawnParticle(vectuh, playervel, 0.125)
				end
				
				data.toolAnimator.timeSinceFire = 0.0 -- hold the gun straight
				
				data.recoil = 1.5 * RECOIL_AMNT
				
				data.coolDown = 0.5
				data.altCoolDown = ALTFIRERATE
				data.m203amntSMG1 = data.m203amntSMG1 - 1
			end
	end
	
	-- decrease firing cooldown and recoil
	data.coolDown = data.coolDown - dt
	data.altCoolDown = data.altCoolDown - dt
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

		-- QUATEULER: (x, y, z) X is tilting barrel upwards, Y tilts it left/right, Z rotates it
		data.toolAnimator.offsetTransform = Transform(Vec(siderecoil,recoil,recoilvert), QuatEuler(recoil * 50, 0, recoil * -15))
	end 
	-- END RECOIL
	
	tickToolAnimator(data.toolAnimator, dt, nil, p)

	
	if IsPlayerLocal(p) then
		-- CAMERA MOVEMENT
		if camSineTime ~= nil then
			local x = camSineTime
			local balance = -10 -- where the peak is (10 for middle, higher to move left also has to be negative)
			local amp = 25 -- how intense (y at the peak will not equal this though)

			local equation = nil
			if data.camAltMove == true then
				balance = -15
				amp = 800
				equation = amp * ((math.sin(CAMALTMOVETIME * x) * math.exp(balance * x)) * x)
			else
				equation = amp * ((math.sin(CAMMOVETIME * x) * math.exp(balance * x)) * x)
			end

			if equation >= 0 then
				local t = Transform(Vec(), QuatAxisAngle(Vec(camRecoilX, camRecoilY, 0), equation))
				SetPlayerCameraOffsetTransform(t)
				camSineTime = camSineTime + dt
			else camSineTime = nil end
		end

		-- UPD AMMO HUD
		if data.inreload == false and ammo > 0.5 then
			clipamnt = data.clipamntSMG1
			altclipamnt = data.m203amntSMG1
		elseif ammo > 0.5 then
			clipamnt = -8 -- negative 8 means reloading
			altclipamnt = -8
		else
			data.clipamntSMG1 = 0
			clipamnt = -16
			altclipamnt = data.m203amntSMG1
		end
	end
end

function client.drawSMG1()
	if GetPlayerTool() ~= WPNID then -- shouldn't need the player pointer since this runs on client
		return
	end

	client.drawAmmo(clipamnt, CLIP_SIZE)
	client.drawSecAmmo(altclipamnt)
end