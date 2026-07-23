-- copy this for the most basic mag loaded weapon with alt fire
#version 2

-- Per weapon constants
local RELOAD_TIME = 1.5 -- seconds
local RELOAD_SOUND = "MOD/snd/smg1_reload.ogg"
local ALT_FIRESOUND = "MOD/snd/smg1_altfire.ogg"
local PRIM_FIRESOUND = "MOD/snd/smg1_fire.ogg"
local CLIP_SIZE = 45
local PICKUP_SIZE = 45
local RECOIL_AMNT = 0.1
local FIRERATE = 0.075
local ALTFIRERATE = 1
local DAMAGE = 0.4
local PLAYERDAMAGE = 0.05
local MAX_RANGE = 100.0
local WPNID = "hl2smg1"
local WPNNAME = "Combine SMG"
local CASING_ORG = Vec(0.02, 0.15, -0.15)

-- Per weapon data storer
local playerData = {}

local function createPlayerCLIENTdata()
    return {
		clipamnt = CLIP_SIZE,
		m203amnt = 1,
		inreload = false,
		coolDown = 0.0,
		altCoolDown = 0.0,
		recoil = 0.0,
		toolAnimator = ToolAnimator(),
		timeFiring = 0.0,
		dataReset = true,
	}
end

local function createPlayerSERVERdata()
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
		playerData[p] = createPlayerCLIENTdata()
		SetToolEnabled(WPNID, true, p)
		SetToolAmmo(WPNID, 250, p)
	end

	for p in PlayersRemoved() do
		playerData[p] = nil
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

	local data = playerData[p]
	
	local pos, dir = getAimVector(GetPlayerEyeTransform(p).pos, MAX_RANGE, GLOBAL_5DEGREES, p)
	
	server.ShootHook(pos, dir, "bullet", DAMAGE, PLAYERDAMAGE, MAX_RANGE, p, WPNID, WPNNAME)
	
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

	SetBodyAngularVelocity(grenade_ent[2], TransformToParentVec(mt, Vec(rnd(-10.16, 10.16), 0, 0)))

	PlaySound(LoadSound(ALT_FIRESOUND), mt.pos, 300)
end

function client.initSMG1()
	shootHaptic = LoadHaptic("MOD/haptic/gun_fire.xml")
	local toolHaptic = LoadHaptic("MOD/haptic/background.xml")
	SetToolHaptic(WPNID, toolHaptic)
end

function client.tickSMG1(dt)
	for p in PlayersAdded() do
		playerData[p] = createPlayerCLIENTdata()
	end

	for p in PlayersRemoved() do
		playerData[p] = nil
	end

	for p in Players() do
		client.tickPlayerSMG1(p, dt)
	end
end

function client.tickPlayerSMG1(p, dt)
	if not IsToolEnabled(WPNID, p) then return end
	
	if GetPlayerHealth(p) <= 0 then
		if playerData[p].dataReset == false then
			playerData[p] = createPlayerCLIENTdata()
		end
		return
	end

	if GetPlayerTool(p) ~= WPNID then
		return
	end

	local mt = GetToolLocationWorldTransform("muzzle", p)
	if mt == nil then
		return
	end

	local ammo = GetToolAmmo(WPNID, p)

	local data = playerData[p]

	-- make data reset when reset conditions are met
	data.dataReset = false

	-- Start Reload
	if InputPressed("r", p) and data.inreload == false and data.clipamnt < CLIP_SIZE and ammo > 0.5 and data.clipamnt ~= ammo then
		PlaySound(LoadSound(RELOAD_SOUND), mt.pos)
		data.coolDown = RELOAD_TIME
		data.inreload = true
	-- Finish Reload
	elseif data.coolDown < 0 and data.inreload == true then	
		data.inreload = false
		if data.clipamnt <= 0 then data.m203amnt = 1 end
		data.clipamnt = math.min(CLIP_SIZE, ammo)
	-- Check Fire
	elseif InputDown("usetool", p) and canFire(p, ammo, data.clipamnt, data.coolDown) then
		PointLight(mt.pos, 1, 0.7, 0.5, 3)

		local playervel = GetPlayerVelocity(p)

		if IsPlayerLocal(p) then
			ServerCall("server.primaryFireSMG1", p)

			client.DoMachineGunKick(1, data.timeFiring, 2)

			PlayHaptic(shootHaptic, 1)

			-- shell ejection
			ejectBrass(p, CASING_ORG, Vec(1, -0.2, 0), "MOD/prefab/casing_9mm.xml", FSFX_BRASS)
		end
		
		muzzleFlash(mt.pos, 2)
			
		data.clipamnt = data.clipamnt - 1
		if data.clipamnt > 0 then
			data.coolDown = FIRERATE
			data.altCoolDown = FIRERATE
		elseif ammo > 1 then
			PlaySound(LoadSound(RELOAD_SOUND), mt.pos)
			data.coolDown = RELOAD_TIME
			data.altCoolDown = RELOAD_TIME
			data.inreload = true
		end

		data.recoil = RECOIL_AMNT
	-- Check Altfire
	elseif InputPressed("grab", p) and canFire(p, data.m203amnt, data.m203amnt, data.altCoolDown) then
		PointLight(mt.pos, 1, 0.7, 0.5, 3)
		if IsPlayerLocal(p) then
			ServerCall("server.secondaryFireSMG1", p)

			PlayHaptic(shootHaptic, 1)
		end
		
		local toolBody = GetToolBody(p)
		local playervel = GetPlayerVelocity(p)
		local ubglPos = VecAdd(mt.pos, Vec(0, -0.03, 0))
		

		muzzleFlash(ubglPos, 5)

		data.toolAnimator.timeSinceFire = 0.0 -- hold the gun straight
		
		data.recoil = 1.5 * RECOIL_AMNT
		
		data.coolDown = 0.5
		data.altCoolDown = ALTFIRERATE
		data.m203amnt = data.m203amnt - 1
	end
	
	if InputDown("usetool", p) and data.inreload == false and ammo > 0 then
		data.timeFiring = data.timeFiring + dt
	else
		data.timeFiring = 0
	end

	-- decrease firing cooldown and recoil
	data.coolDown = data.coolDown - dt
	data.altCoolDown = data.altCoolDown - dt
	data.recoil = data.recoil - dt
	
	-- RECOIL
	if data.recoil > -0.5 then
		local recoil = 0.33 * math.max(0, data.recoil)
		local siderecoil = recoil * 0.25
		local recoilvert = math.max(0, data.recoil)
		
		local inversesiderecoil = rnd(0, 1)
		if inversesiderecoil > 0.5 then
			siderecoil = siderecoil * -1
		end

		-- QUATEULER: (x, y, z) X is tilting barrel upwards, Y tilts it left/right, Z rotates it
		data.toolAnimator.offsetTransform = Transform(Vec(siderecoil,recoil,recoilvert*2), QuatEuler(recoilvert * 50, 0, recoilvert * -15))
	end 
	-- END RECOIL
	
	tickToolAnimator(data.toolAnimator, dt, nil, p)
end

function client.drawSMG1()
	if GetPlayerTool() ~= WPNID then return end

	local p = GetLocalPlayer()

	local ammoToDraw = playerData[p].inreload and -8 or playerData[p].clipamnt

	client.drawAmmo(ammoToDraw, CLIP_SIZE)
	client.drawSecAmmo(playerData[p].m203amnt)
end