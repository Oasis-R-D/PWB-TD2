-- copy this for a "basic" grenade (this is the weapon, thrown object in items/thrown/throwngren.lua)
#version 2

#include "script/include/player.lua"
#include "script/pwbtoolanimation.lua"
#include "script/util.lua"

-- Per weapon constants
local PICKUP_SIZE = 5.0
local RECOIL_AMNT = 0.075
local FIRERATE = 0.5
local FUZESTART = 3.0
local WPNID = "hlgrenade"
local WPNNAME = "Mk2 Frag"

-- Per weapon data storer
FRAGplayers = {}

function createPlayerCLIENTdataFRAG()
	return {
		inAttack = false,
		chargedTime = nil,
		coolDown = 0.0,
		recoil = 0.0,
		toolAnimator = ToolAnimator(),
		dataReset = true,
	}
end

function server.initFRAG()
	RegisterTool(WPNID, WPNNAME, "MOD/prefab/grenade.xml", 4)
	SetToolAmmoPickupAmount(WPNID, PICKUP_SIZE)
end

function server.tickFRAG(dt)
	for p in PlayersAdded() do
		SetToolEnabled(WPNID, true, p)
		SetToolAmmo(WPNID, 10, p)
	end

	for p in Players() do
		server.tickPlayerFRAG(p, dt)
	end
end

function server.tickPlayerFRAG(p, dt)
	if not IsToolEnabled(WPNID, p) then return end
	
	if GetPlayerHealth(p) <= 0 then return end

	local ammo = GetToolAmmo(WPNID, p)
	if ammo < 9999 and ammo > 15 then
		SetToolAmmo(WPNID, 15, p)
	end
end

function server.primaryFireFRAG(p, cookedTime)
	cookedTime = cookedTime or 0
	local mt = GetToolLocationWorldTransform("muzzle", p)

	local ammo = GetToolAmmo(WPNID, p)

	local _,pos,_,angThrow = GetPlayerAimInfo(GetPlayerEyeTransform(p).pos, MAX_RANGE, p)
	
	pos = VecAdd(pos, VecScale(angThrow, 0.25))
	
	if angThrow[1] < 0 then
		angThrow[1] = -0.254 + angThrow[1] * ((2.286 - 0.254) / 2.286)
	else
		angThrow[1] = -0.254 + angThrow[1] * ((2.286 + 0.254) / 2.286)
	end

	local flVel = (2.286 - angThrow[1]) * 6.5
	if flVel > 25.4 then
		flVel = 25.4
	end

	local velocity = VecAdd(GetPlayerVelocity(p), TransformToParentVec(GetPlayerEyeTransform(p), Vec(0, 0, -flVel)))

	local GrenTrans = Transform(pos, QuatLookAt(Vec(), angThrow))
	local xml = "MOD/prefab/gren_frag.xml"
	grenade_ent = Spawn(xml, GrenTrans)

	SetTag(grenade_ent[2], "grenType", "frag")
	SetTag(grenade_ent[2], "grenStyle", "timed")
	SetTag(grenade_ent[2], "timer", FUZESTART - cookedTime)
	SetTag(grenade_ent[2], "playerThrew", p)

	SetBodyVelocity(grenade_ent[2], velocity)

	if ammo < 9999 then
		SetToolAmmo(WPNID, ammo-1, p)
	end
end

function client.initFRAG()
	shootHaptic = LoadHaptic("MOD/haptic/gun_fire.xml")
	local toolHaptic = LoadHaptic("MOD/haptic/background.xml")
	SetToolHaptic(WPNID, toolHaptic)
end

function client.tickFRAG(dt)
	for p in PlayersAdded() do
		FRAGplayers[p] = createPlayerCLIENTdataFRAG();
	end

	for p in PlayersRemoved() do
		FRAGplayers[p] = nil
	end

	for p in Players() do
		client.tickPlayerFRAG(p, dt)
	end
end

function client.tickPlayerFRAG(p, dt)
	if not IsToolEnabled(WPNID, p) then return end
	
	if GetPlayerHealth(p) <= 0 then
		if FRAGplayers[p].dataReset == false then
			FRAGplayers[p] = createPlayerCLIENTdataFRAG()
		end
		return
	end
	
	if GetPlayerTool(p) ~= WPNID then
		if FRAGplayers[p].dataReset == false then
			FRAGplayers[p] = createPlayerCLIENTdataFRAG()
		end
		return
	end

	local ammo = GetToolAmmo(WPNID, p)
	
	local data = FRAGplayers[p]

	-- make data reset when reset conditions are met
	data.dataReset = false
	
	data.toolAnimator.maxActionPoseTime = 0.075

	if InputDown("usetool", p) and ammo > 0.5 and GetPlayerCanUseTool(p) == true then
		if data.coolDown < 0 then
			data.inAttack = true
		end
	end

	if data.chargedTime ~= nil and data.inAttack == true then -- deplete timer and check if ready
		data.chargedTime = data.chargedTime + dt -- cook the grenade

		local pitch = (data.chargedTime) * (150 / FUZESTART) + 100
		if pitch > 250 then
			pitch = 250
		end
		pitch = pitch / 100

		if data.recoil < 0 then data.recoil = 0 end
		data.recoil = math.min(0.025, data.recoil + (pitch * 0.01))

		if (data.chargedTime > 0.5 and not InputDown("usetool", p)) then -- swing start animation done (in opfor)
			data.toolAnimator.forceSecondaryActionPose = false

			if IsPlayerLocal(p) then
				ServerCall("server.primaryFireFRAG", p, data.chargedTime)
			end

			data.coolDown = FIRERATE

			data.recoil = RECOIL_AMNT
			data.chargedTime = nil
			data.inAttack = false
		end
	elseif data.inAttack == true then -- start timer
		data.chargedTime = 0
		data.toolAnimator.forceSecondaryActionPose = true
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