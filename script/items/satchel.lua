-- copy this for a "basic" grenade (this is the weapon, thrown object in items/thrown/throwngren.lua)
#version 2

#include "script/include/player.lua"
#include "script/pwbtoolanimation.lua"
#include "script/util.lua"

-- Per weapon constants
local PRIM_FIRESOUND = "MOD/snd/gren.ogg"
local PICKUP_SIZE = 5.0
local RECOIL_AMNT = 0.075
local FIRERATE = 0.5
local WPNID = "hlsatchel"
local WPNNAME = "Satchel Charge"

-- Per weapon data storer
SATCHplayers = {}

function createPlayerCLIENTdataSATCH()
	return {
		coolDown = 0.0,
		altCoolDown = 0.0,
		recoil = 0.0,
		toolAnimator = ToolAnimator(),
		dataReset = true,
	}
end

function createPlayerSERVERdataSATCH()
	return {
		satchelBodies = {},
		dataReset = true,
	}
end

function server.initSATCH()
	RegisterTool(WPNID, WPNNAME, "MOD/prefab/satchel.xml", 4)
	SetToolAmmoPickupAmount(WPNID, PICKUP_SIZE)
end

function server.tickSATCH(dt)
	for p in PlayersAdded() do
		SATCHplayers[p] = createPlayerSERVERdataSATCH()
		SetToolEnabled(WPNID, true, p)
		SetToolAmmo(WPNID, 5, p)
	end

	for p in PlayersRemoved() do
		SATCHplayers[p] = nil
	end

	for p in Players() do
		server.tickPlayerSATCH(p, dt)
	end
end

function server.tickPlayerSATCH(p, dt)
	if not IsToolEnabled(WPNID, p) then return end
	
	if GetPlayerHealth(p) <= 0 then
		if SATCHplayers[p].dataReset == false then
			SATCHplayers[p] = createPlayerSERVERdataSATCH()
		end
		return
	end

	-- make data reset when reset conditions are met
	SATCHplayers[p].dataReset = false

	local ammo = GetToolAmmo(WPNID, p)
	if ammo < 9999 and ammo > 10 then
		SetToolAmmo(WPNID, 10, p)
	end
end

function server.primaryFireSATCH(p)
	local ammo = GetToolAmmo(WPNID, p)
	local data = SATCHplayers[p]

	local _,pos,_,angThrow = GetPlayerAimInfo(GetPlayerEyeTransform(p).pos, MAX_RANGE, p)

	pos = VecAdd(pos, VecScale(angThrow, 0.25))

	local velocity = VecAdd(GetPlayerVelocity(p), TransformToParentVec(GetPlayerEyeTransform(p), Vec(0, 0, -6.9596)))

	local GrenTrans = Transform(pos, QuatLookAt(Vec(), angThrow))
	local xml = "MOD/prefab/gren_satch.xml"
	satch_ent = Spawn(xml, GrenTrans)

	SetTag(satch_ent[2], "grenType", "satchel")
	SetTag(satch_ent[2], "grenStyle", "remote")
	SetTag(satch_ent[2], "playerThrew", p)

	SetBodyVelocity(satch_ent[2], velocity)
	SetBodyAngularVelocity(satch_ent[2], TransformToParentVec(GetPlayerEyeTransform(p), Vec(0, 10.16, 0)))

	table.insert(data.satchelBodies, satch_ent[2])

	--PlaySound(LoadSound(PRIM_FIRESOUND), mt.pos, 300)

	if ammo < 9999 then
		SetToolAmmo(WPNID, ammo-1, p)
	end
end

function server.secondaryFireSATCH(p)
	local ammo = GetToolAmmo(WPNID, p)
	local data = SATCHplayers[p]

	for i = 1, #data.satchelBodies do -- loop through active satchels and explode them
    	local currentBod = data.satchelBodies[i]
		if currentBod ~= nil then SetTag(currentBod, "detonate") end
	end
	data.satchelBodies = {} -- empty active satchels
end

function client.initSATCH()
	shootHaptic = LoadHaptic("MOD/haptic/gun_fire.xml")
	local toolHaptic = LoadHaptic("MOD/haptic/background.xml")
	SetToolHaptic(WPNID, toolHaptic)
end

function client.tickSATCH(dt)
	for p in PlayersAdded() do
		SATCHplayers[p] = createPlayerCLIENTdataSATCH();
	end

	for p in PlayersRemoved() do
		SATCHplayers[p] = nil
	end

	for p in Players() do
		client.tickPlayerSATCH(p, dt)
	end
end

function client.tickPlayerSATCH(p, dt)
	if not IsToolEnabled(WPNID, p) then return end

	if GetPlayerHealth(p) <= 0 then
		if SATCHplayers[p].dataReset == false then
			SATCHplayers[p] = createPlayerCLIENTdataSATCH()
		end
		return
	end
	
	if GetPlayerTool(p) ~= WPNID then
		if SATCHplayers[p].dataReset == false then
			SATCHplayers[p] = createPlayerCLIENTdataSATCH()
		end
		return
	end

	local ammo = GetToolAmmo(WPNID, p)
	
	local data = SATCHplayers[p]

	-- make data reset when reset conditions are met
	data.dataReset = false

	data.toolAnimator.maxActionPoseTime = 0.075

	if InputDown("usetool", p) and ammo > 0.5 and GetPlayerCanUseTool(p) == true then
			if data.coolDown < 0 then
				if IsPlayerLocal(p) then
					ServerCall("server.primaryFireSATCH", p)
				end
				
				data.toolAnimator.timeSinceFire = 0.0

				data.coolDown = FIRERATE
				data.altCoolDown = FIRERATE
				data.recoil = RECOIL_AMNT
			end
	end
	
	if InputPressed("grab", p) and GetPlayerCanUseTool(p) == true  then
			if data.altCoolDown < 0 then
				if IsPlayerLocal(p) then
					ServerCall("server.secondaryFireSATCH", p)
				end
				
				data.toolAnimator.timeSinceFire = 0.0 -- hold the gun straight

				data.coolDown = FIRERATE
				data.altCoolDown = FIRERATE
				data.recoil = RECOIL_AMNT
			end

		if IsPlayerLocal(p) then
			PlayHaptic(shootHaptic, 1)
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