-- copy this for a "basic" grenade (this is the weapon, thrown object in items/thrown/throwngren.lua)
#version 2

#include "script/include/player.lua"
#include "script/pwbtoolanimation.lua"
#include "script/util.lua"

-- Per weapon constants
local PICKUP_SIZE = 3.0
local RECOIL_AMNT = 0.075
local FIRERATE = 0.5
local WPNID = "hl2slam"
local WPNNAME = "S.L.A.M"
local THROW_SOUND = "MOD/snd/slam_throw.ogg"
local PLACE_SOUND = "MOD/snd/slam_place.ogg"
-- Per weapon data storer
SLAMplayers = {}

function createPlayerCLIENTdataSLAM()
	return {
		coolDown = 0.0,
		recoil = 0.0,
		toolAnimator = ToolAnimator(),
		dataReset = true,
	}
end

function createPlayerSERVERdataSLAM()
	return {
		satchelBodies = {},
		dataReset = true,
	}
end

function server.initSLAM()
	RegisterTool(WPNID, WPNNAME, "MOD/prefab/slam.xml", 4)
	SetToolAmmoPickupAmount(WPNID, PICKUP_SIZE)
end

function server.tickSLAM(dt)
	for p in PlayersAdded() do
		SLAMplayers[p] = createPlayerSERVERdataSLAM()
		SetToolEnabled(WPNID, true, p)
		SetToolAmmo(WPNID, 5, p)
	end

	for p in PlayersRemoved() do
		SLAMplayers[p] = nil
	end

	for p in Players() do
		server.tickPlayerSLAM(p, dt)
	end
end

function server.tickPlayerSLAM(p, dt)
	if not IsToolEnabled(WPNID, p) then return end
	
	if GetPlayerHealth(p) <= 0 then
		if SLAMplayers[p].dataReset == false then
			SLAMplayers[p] = createPlayerSERVERdataSLAM()
		end
		return
	end

	-- make data reset when reset conditions are met
	SLAMplayers[p].dataReset = false
	
	local ammo = GetToolAmmo(WPNID, p)
	if ammo < 9999 and ammo > 5 then
		SetToolAmmo(WPNID, 5, p)
	end
end

function server.primaryFireSLAM(p)
	local ammo = GetToolAmmo(WPNID, p)

	local _,pos,_,angThrow = GetPlayerAimInfo(GetPlayerEyeTransform(p).pos, 3.0, p)

	local hit, dist, normal = QueryRaycast(pos, TransformToParentVec(GetPlayerEyeTransform(p), Vec(0, 0, -1)), 3.0, 0)

	if hit then -- place tripmine
		local GrenTrans = Transform(VecAdd(pos, VecScale(TransformToParentVec(GetPlayerEyeTransform(p), Vec(0, 0, -1)), dist + 0.1)), QuatLookAt(Vec(), normal))
		local xml = "MOD/prefab/gren_trip.xml"
		satch_ent = Spawn(xml, GrenTrans, false, true)
		
		SetTag(satch_ent[2], "grenType", "mine")
		SetTag(satch_ent[2], "grenStyle", "lasermine")
		SetTag(satch_ent[2], "playerThrew", p)

		PlaySound(LoadSound(PLACE_SOUND), GrenTrans.pos, 0.7)
	else -- throw as satchel
		local mt = GetToolLocationWorldTransform("muzzle", p)
		local data = SLAMplayers[p]

		_,pos,_,angThrow = GetPlayerAimInfo(mt.pos, MAX_RANGE, p)

		pos = VecAdd(pos, VecScale(angThrow, 0.25))

		local velocity = VecAdd(GetPlayerVelocity(p), VecScale(angThrow, 6.9596))

		local GrenTrans = Transform(pos, QuatLookAt(Vec(), TransformToParentVec(GetPlayerEyeTransform(p), Vec(0, 1, 0))))
		local xml = "MOD/prefab/gren_satch.xml"
		satch_ent = Spawn(xml, GrenTrans)

		SetTag(satch_ent[2], "grenType", "satchel")
		SetTag(satch_ent[2], "grenStyle", "remote")
		SetTag(satch_ent[2], "playerThrew", p)

		SetBodyVelocity(satch_ent[2], velocity)
		SetBodyAngularVelocity(satch_ent[2], TransformToParentVec(GetPlayerEyeTransform(p), Vec(0, 10.16, 0)))

		table.insert(data.satchelBodies, satch_ent[2])

		PlaySound(LoadSound(THROW_SOUND), mt.pos, 0.7)
	end

	if ammo < 9999 then
		SetToolAmmo(WPNID, ammo-1, p)
	end
end

function server.secondaryFireSLAM(p) -- detonate satchel placed slams
	local data = SLAMplayers[p]

	for i = 1, #data.satchelBodies do
		SetTag(data.satchelBodies[i], "detonate")
	end

	data.satchelBodies = {} -- empty active satchels
end

function client.initSLAM()
	shootHaptic = LoadHaptic("MOD/haptic/gun_fire.xml")
	local toolHaptic = LoadHaptic("MOD/haptic/background.xml")
	SetToolHaptic(WPNID, toolHaptic)
end

function client.tickSLAM(dt)
	for p in PlayersAdded() do
		SLAMplayers[p] = createPlayerCLIENTdataSLAM();
	end

	for p in PlayersRemoved() do
		SLAMplayers[p] = nil
	end

	for p in Players() do
		client.tickPlayerSLAM(p, dt)
	end
end

function client.tickPlayerSLAM(p, dt)
	if not IsToolEnabled(WPNID, p) then return end
	
	if GetPlayerHealth(p) <= 0 then
		if SLAMplayers[p].dataReset == false then
			SLAMplayers[p] = createPlayerCLIENTdataSLAM()
		end
		return
	end
	
	if GetPlayerTool(p) ~= WPNID then
		if SLAMplayers[p].dataReset == false then
			SLAMplayers[p] = createPlayerCLIENTdataSLAM()
		end
		return
	end

	local ammo = GetToolAmmo(WPNID, p)
	
	local data = SLAMplayers[p]

	-- make data reset when reset conditions are met
	data.dataReset = false
	
	data.toolAnimator.maxActionPoseTime = 0.075
	
	if InputDown("usetool", p) and ammo > 0.5 and GetPlayerCanUseTool(p) == true then
		if data.coolDown < 0 then
			if IsPlayerLocal(p) then
				ServerCall("server.primaryFireSLAM", p)
			end

			data.toolAnimator.timeSinceFire = 0.0

			data.coolDown = FIRERATE
			data.recoil = RECOIL_AMNT
		end
	end

	if InputPressed("grab", p) and GetPlayerCanUseTool(p) == true  then
			if data.coolDown < 0 then
				if IsPlayerLocal(p) then
					ServerCall("server.secondaryFireSLAM", p)
				end
				
				data.toolAnimator.timeSinceFire = 0.0 -- hold the gun straight

				data.coolDown = FIRERATE
				data.recoil = RECOIL_AMNT
			end

		if IsPlayerLocal(p) then
			PlayHaptic(shootHaptic, 1)
		end
	end

	-- decrease firing cooldown and recoil
	data.coolDown = data.coolDown - dt
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
	
	local toolBody = GetToolBody(p)
	local shapes = GetBodyShapes(toolBody)

	if ammo < 0.5 then -- no grenades
		-- hide grenade
		SetTag(shapes[0], "invisible")
	elseif HasTag(shapes[0], "invisible") == true then
		RemoveTag(shapes[0], "invisible")
	end

	tickToolAnimator(data.toolAnimator, dt, nil, p, 3, true)
end