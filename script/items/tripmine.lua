-- copy this for a "basic" grenade (this is the weapon, thrown object in items/thrown/throwngren.lua)
#version 2

#include "script/include/player.lua"
#include "script/pwbtoolanimation.lua"
#include "script/util.lua"

-- Per weapon constants
local PICKUP_SIZE = 3.0
local RECOIL_AMNT = 0.075
local FIRERATE = 0.5
local WPNID = "hltripmine"
local WPNNAME = "Trip Mine"

-- Per weapon data storer
TRIPplayers = {}

function createPlayerCLIENTdataTRIP()
	return {
		coolDown = 0.0,
		recoil = 0.0,
		toolAnimator = ToolAnimator(),
		dataReset = true,
	}
end

function server.initTRIP()
	RegisterTool(WPNID, WPNNAME, "MOD/prefab/tripmine.xml", 4)
	SetToolAmmoPickupAmount(WPNID, PICKUP_SIZE)
end

function server.tickTRIP(dt)
	for p in PlayersAdded() do
		SetToolEnabled(WPNID, true, p)
		SetToolAmmo(WPNID, 5, p)
	end

	for p in Players() do
		server.tickPlayerTRIP(p, dt)
	end
end

function server.tickPlayerTRIP(p, dt)
	if not IsToolEnabled(WPNID, p) then return end
	
	if GetPlayerHealth(p) <= 0 then return end
	
	local ammo = GetToolAmmo(WPNID, p)
	if ammo < 9999 and ammo > 9 then
		SetToolAmmo(WPNID, 9, p)
	end
end

function server.primaryFireTRIP(p)
	local ammo = GetToolAmmo(WPNID, p)

	local _,pos,_,angThrow = GetPlayerAimInfo(GetPlayerEyeTransform(p).pos, 2.5, p)

	local hit, dist, normal = QueryRaycast(pos, TransformToParentVec(GetPlayerEyeTransform(p), Vec(0, 0, -1)), 2.5, 0)

	if hit then
		local GrenTrans = Transform(VecAdd(pos, VecScale(angThrow, dist + 0.1)), QuatLookAt(Vec(), normal))
		local xml = "MOD/prefab/gren_trip.xml"
		satch_ent = Spawn(xml, GrenTrans, false, true)
		
		SetTag(satch_ent[2], "grenType", "mine")
		SetTag(satch_ent[2], "grenStyle", "lasermine")
		SetTag(satch_ent[2], "playerThrew", p)

		if ammo < 9999 then
			SetToolAmmo(WPNID, ammo-1, p)
		end
	end
end

function client.initTRIP()
	TMW_ON = LoadSound("MOD/snd/mine_charge.ogg")
	TMW_ON2 = LoadSound("MOD/snd/mine_deploy.ogg")

	shootHaptic = LoadHaptic("MOD/haptic/gun_fire.xml")
	local toolHaptic = LoadHaptic("MOD/haptic/background.xml")
	SetToolHaptic(WPNID, toolHaptic)
end

function client.tickTRIP(dt)
	for p in PlayersAdded() do
		TRIPplayers[p] = createPlayerCLIENTdataTRIP();
	end

	for p in PlayersRemoved() do
		TRIPplayers[p] = nil
	end

	for p in Players() do
		client.tickPlayerTRIP(p, dt)
	end
end

function client.tickPlayerTRIP(p, dt)
	if not IsToolEnabled(WPNID, p) then return end
	
	if GetPlayerHealth(p) <= 0 then
		if TRIPplayers[p].dataReset == false then
			TRIPplayers[p] = createPlayerCLIENTdataTRIP()
		end
		return
	end
	
	if GetPlayerTool(p) ~= WPNID then
		if TRIPplayers[p].dataReset == false then
			TRIPplayers[p] = createPlayerCLIENTdataTRIP()
		end
		return
	end

	local ammo = GetToolAmmo(WPNID, p)
	
	local data = TRIPplayers[p]

	-- make data reset when reset conditions are met
	data.dataReset = false
	
	data.toolAnimator.maxActionPoseTime = 0.075
	
	if InputDown("usetool", p) and ammo > 0.5 and GetPlayerCanUseTool(p) == true then
		if data.coolDown < 0 then
			local _,pos,_,angThrow = GetPlayerAimInfo(GetPlayerEyeTransform(p).pos, 2.5, p)

			local dir = TransformToParentVec(GetPlayerEyeTransform(p), Vec(0, 0, -1))
			local hit, dist, normal = QueryRaycast(pos, dir, 2.5, 0)

			if hit then
				local pt = GetPlayerTransform(p)
				if IsPlayerLocal(p) then
					ServerCall("server.primaryFireTRIP", p)
				end

				PlaySound(TMW_ON, VecAdd(pos, VecScale(dir, dist)), 1)
				PlaySound(TMW_ON2, VecAdd(pos, VecScale(dir, dist)), 10)

				data.toolAnimator.timeSinceFire = 0.0

				data.coolDown = FIRERATE
				data.recoil = RECOIL_AMNT
			else
				data.coolDown = 0.05 -- prevent spamming raycasts
			end
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