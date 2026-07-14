-- copy this for a "basic" grenade (this is the weapon, thrown object in items/thrown/throwngren.lua)
#version 2

-- Per weapon constants
local PICKUP_SIZE = 5.0
local RECOIL_AMNT = 0.075
local FIRERATE = 0.5
local FUZESTART = 2.5
local WPNID = "hl2grenade"
local WPNNAME = "MK3A2 Frag" -- MK3A2 is a concussion grenade, weapon is called a frag and acts like one though
local THROW_SOUND = "MOD/snd/slam_throw.ogg"

-- Per weapon data storer
local playerData = {}

local function createPlayerCLIENTdata()
	return {
		inAttack = false,
		inAltAttack = false,
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

function server.primaryFireFRAG(p)
	local mt = GetToolLocationWorldTransform("muzzle", p)

	local ammo = GetToolAmmo(WPNID, p)

	local _,pos,_,angThrow = GetPlayerAimInfo(mt.pos, MAX_RANGE, p)
	
	pos = VecAdd(pos, VecScale(angThrow, 0.25))
	
	local throwVel = VecAdd(VecScale(angThrow, 17.78), Vec(0, 1.27, 0)) -- angthrow should be multiplied by 8.89, but that doesn't seem right in game
	local velocity = VecAdd(GetPlayerVelocity(p), throwVel)

	local GrenTrans = Transform(pos, QuatLookAt(Vec(), angThrow))
	local xml = "MOD/prefab/gren_frag.xml"
	grenade_ent = Spawn(xml, GrenTrans)

	SetTag(grenade_ent[2], "grenType", "frag")
	SetTag(grenade_ent[2], "grenStyle", "timed")
	SetTag(grenade_ent[2], "timer", FUZESTART)
	SetTag(grenade_ent[2], "playerThrew", p)

	SetBodyVelocity(grenade_ent[2], velocity)
	SetBodyAngularVelocity(grenade_ent[2], Vec(5.08,0,rnd(-15.24,15.24)))

	PlaySound(LoadSound(THROW_SOUND), mt.pos, 0.7)
	
	if ammo < 9999 then
		SetToolAmmo(WPNID, ammo-1, p)
	end
end

function server.secondaryFireFRAG(p)
	local mt = GetToolLocationWorldTransform("muzzle", p)

	local ammo = GetToolAmmo(WPNID, p)

	local _,pos,_,angThrow = GetPlayerAimInfo(mt.pos, MAX_RANGE, p)
	
	angThrow[2] = 0

	QueryRequire("large visible physical")
	local hit, dist, normal = QueryRaycast(pos, Vec(0, -1, 0), 0.4064)
	if hit then
		local tan = VecCross(angThrow, 	normal)
		angThrow  = VecCross(normal, 	tan)
	end

	pos = VecAdd(pos, VecScale(angThrow, 0.4572))
	local down = TransformToParentVec(mt, Vec(0, -1, 0))
	pos = VecAdd(pos, VecScale(down, 0.2))

	local throwVel = VecScale(angThrow, 17.78)
	local velocity = VecAdd(GetPlayerVelocity(p), throwVel)

	local GrenTrans = Transform(pos, QuatLookAt(Vec(), angThrow))
	GrenTrans.rot = QuatRotateQuat(GrenTrans.rot, QuatEuler(0, 0, -90))

	local xml = "MOD/prefab/gren_frag.xml"
	grenade_ent = Spawn(xml, GrenTrans)

	SetTag(grenade_ent[2], "grenType", "frag")
	SetTag(grenade_ent[2], "grenStyle", "timed")
	SetTag(grenade_ent[2], "timer", FUZESTART)
	SetTag(grenade_ent[2], "playerThrew", p)

	SetBodyVelocity(grenade_ent[2], velocity)

	SetBodyAngularVelocity(grenade_ent[2], TransformToParentVec(GrenTrans, Vec(0,18.288,0)))

	PlaySound(LoadSound(THROW_SOUND), mt.pos, 0.7)
	
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
		playerData[p] = createPlayerCLIENTdata()
	end

	for p in PlayersRemoved() do
		playerData[p] = nil
	end

	for p in Players() do
		client.tickPlayerFRAG(p, dt)
	end
end

function client.tickPlayerFRAG(p, dt)
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

	local ammo = GetToolAmmo(WPNID, p)
	
	local data = playerData[p]

	-- make data reset when reset conditions are met
	data.dataReset = false
	
	data.toolAnimator.maxActionPoseTime = 0.075

	-- Check Fire
	if InputDown("usetool", p) and ammo > 0.5 and GetPlayerCanUseTool(p) == true and data.inAttack == false then
		if data.coolDown < 0 then
			data.inAttack = true
		end
	end

	if InputDown("grab", p) and ammo > 0.5 and GetPlayerCanUseTool(p) == true and data.inAttack == false then
		if data.coolDown < 0 then
			data.inAttack = true
			data.inAltAttack = true
		end
	end

	if data.chargedTime ~= nil and data.inAttack == true then -- deplete timer and check if ready
		data.chargedTime = data.chargedTime + dt -- cook the grenade

		local pitch = (data.chargedTime) * (150 / FUZESTART) + 100
		if pitch > 250 then
			pitch = 250
		end
		pitch = pitch / 100

		data.recoil = math.min(0.025, data.recoil + (pitch * 0.01))

		if (data.chargedTime > 0.25 and not InputDown("usetool", p)) then -- swing start animation done (in opfor)
			data.toolAnimator.forceSecondaryActionPose = false

			if IsPlayerLocal(p) then
				if data.inAltAttack == false then
					ServerCall("server.primaryFireFRAG", p)
				else
					ServerCall("server.secondaryFireFRAG", p)
				end
				PlayHaptic(shootHaptic, 1)
			end

			data.coolDown = FIRERATE

			data.recoil = RECOIL_AMNT
			data.chargedTime = nil
			data.inAttack = false
			data.inAltAttack = false
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