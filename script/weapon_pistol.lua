-- copy this for a basic pistol with separate sounds when not fired by the client
-- also includes separated
#version 2

-- HALF-LIFE: 2 CONSTANTS
local PISTOL_FASTEST_REFIRE_TIME			= 0.1 -- spam clicking firerate
local PISTOL_ACCURACY_SHOT_PENALTY_TIME		= 0.2	-- Applied amount of time each shot adds to the time we must recover from
local PISTOL_ACCURACY_MAXIMUM_PENALTY_TIME	= 1.5	-- Maximum penalty to deal out

-- Per weapon constants
local RELOAD_TIME = 1.433 -- seconds
local RELOAD_SOUND = "MOD/snd/pistol_reload.ogg"
local PRIM_FIRESOUND = "MOD/snd/pistol_fire.ogg"
local NONCLIENTPRIM_FIRESOUND = "MOD/snd/pistol_fireNC.ogg" -- glock has diff sounds when shot by NPCs (in this case, other players)
local CLIP_SIZE = 18.0
local PICKUP_SIZE = 18.0
local RECOIL_AMNT = 0.17
local FIRERATE = 0.5 -- held down fire rate
local CAMMOVETIME = (2 * math.pi) * (0.5 / FIRERATE) -- Cam movement sine multiplier, PISTOL_ACCURACY_SHOT_PENALTY_TIME is how long until it's over
local ALTFIRERATE = 0.2
local DAMAGE = 0.4
local PLAYERDAMAGE = 0.08
local MAX_RANGE = 125.0
local WPNID = "hl2pistol"
local WPNNAME = "9mm Pistol"
local CASING_ORG = Vec(0.02, 0.3, 0.05)

-- Per weapon data storer
local playerData = {}

function createPlayerCLIENTdataPIST9MM()
    return {
		clipamnt = CLIP_SIZE,
		inreload = false,
		coolDown = 0.0,
		recoil = 0.0,
		toolAnimator = ToolAnimator(),
		firesound = nil,
		dataReset = true,
		SoonestPrimaryAttack = GetTime(),
		AccuracyPenalty = 0.0,
		NextPrimaryAttack = 0.0,
	}
end

function createPlayerSERVERdataPIST9MM()
    return {
		dataReset = true,
		coolDown = 0.0,
		AccuracyPenalty = 0.0,
	}
end

function server.initPIST9MM()
	RegisterTool(WPNID, WPNNAME, "MOD/prefab/usp.xml", 3)
	SetToolAmmoPickupAmount(WPNID, PICKUP_SIZE)
end

function server.tickPIST9MM(dt)
	for p in PlayersAdded() do
		SetToolEnabled(WPNID, true, p)
		SetToolAmmo(WPNID, 250, p)
		playerData[p] = createPlayerSERVERdataPIST9MM();
	end

	for p in PlayersRemoved() do
		playerData[p] = nil
	end

	for p in Players() do
		server.tickPlayerPIST9MM(p, dt)
	end
end

function server.tickPlayerPIST9MM(p, dt)
	if not IsToolEnabled(WPNID, p) then 
		return 
	end
	
	if GetPlayerHealth(p) <= 0 then
		if playerData[p].dataReset == false then
			playerData[p] = createPlayerSERVERdataPIST9MM()
		end
		return
	end
	
	if GetPlayerTool(p) ~= WPNID then
		return
	end

	local data = playerData[p]
	
	-- make data reset when reset conditions are met
	data.dataReset = false
	
	-- Check our penalty time decay
	-- NOTE: no idea who's idea it was to make spread not decay when holding
	if InputDown("usetool", p) == false and data.coolDown < 0 then
		data.AccuracyPenalty = data.AccuracyPenalty - dt
		data.AccuracyPenalty = clamp(data.AccuracyPenalty, 0.0, PISTOL_ACCURACY_MAXIMUM_PENALTY_TIME)
	end

	data.coolDown = data.coolDown - dt -- after because above was ran in **PRE**think
end

function AimLerp(src1, src2, t)
	return src1 + (src2 - src1) * t
end

function RemapValClamped(val, A, B, C, D)
	if ( A == B ) then
		if val >= B then return D else return C end
	end

	local cVal = (val - A) / (B - A)
	cVal = clamp(cVal, 0.0, 1.0)

	return C + (D - C) * cVal
end

function server.getPlayerSpread(data)
	local ramp = RemapValClamped(	data.AccuracyPenalty, 
									0.0, 
									PISTOL_ACCURACY_MAXIMUM_PENALTY_TIME, 
									0.0, 
									1.0 )

	-- We lerp from very accurate to inaccurate over time
	return AimLerp(GLOBAL_1DEGREE, GLOBAL_6DEGREES, ramp)
end

function server.primaryFirePIST9MM(p)
	local data = playerData[p]

	local pos, dir = getAimVector(GetPlayerEyeTransform(p).pos, MAX_RANGE, server.getPlayerSpread(data), p)
	ShootHook(pos, dir, "bullet", DAMAGE, PLAYERDAMAGE, MAX_RANGE, p, WPNID, WPNNAME, 2)
	
	data.AccuracyPenalty = data.AccuracyPenalty + PISTOL_ACCURACY_SHOT_PENALTY_TIME

	data.coolDown = PISTOL_FASTEST_REFIRE_TIME -- we don't care about reloading here (too lazy to code also)!!!

	server.depleteAmmo(p, WPNID)
end

function client.initPIST9MM()
	shootHaptic = LoadHaptic("MOD/haptic/gun_fire.xml")
	local toolHaptic = LoadHaptic("MOD/haptic/background.xml")
	SetToolHaptic(WPNID, toolHaptic);
end

function client.tickPIST9MM(dt)
	for p in PlayersAdded() do
		playerData[p] = createPlayerCLIENTdataPIST9MM();
	end

	for p in PlayersRemoved() do
		playerData[p] = nil
	end

	for p in Players() do
		client.tickPlayerPIST9MM(p, dt)
	end
end

local camSineTime = nil
local camRecoilY = 0

function client.tickPlayerPIST9MM(p, dt)
	if not IsToolEnabled(WPNID, p) then 
		return 
	end
	
	if GetPlayerHealth(p) <= 0 then
		if playerData[p].dataReset == false then
			playerData[p] = createPlayerCLIENTdataPIST9MM()
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
	
	local data = playerData[p]

	-- make data reset when reset conditions are met
	data.dataReset = false

	-- Start Reload
	if InputPressed("r", p) and data.inreload == false and data.clipamnt < CLIP_SIZE and ammo > 0.5 and data.clipamnt ~= ammo then
		PlaySound(LoadSound(RELOAD_SOUND), pt.pos)
		if data.clipamnt > 0 then
			data.NextPrimaryAttack = GetTime() + RELOAD_TIME
		end
		data.inreload = true
	-- Finish Reload
	elseif data.inreload == true and data.NextPrimaryAttack < GetTime() then	
		data.inreload = false
		data.clipamnt = math.min(CLIP_SIZE, ammo)
	-- Check Fire
	elseif InputDown("usetool", p) and canFire(p, ammo, data.clipamnt) then
		if data.NextPrimaryAttack < GetTime() then
			StopSound(data.firesound)

			local toolBody = GetToolBody(p)
			local playervel = GetPlayerVelocity(p)

			PointLight(mt.pos, 1, 0.7, 0.5, 3)
			if IsPlayerLocal(p) then
				data.firesound = PlaySound(LoadSound(PRIM_FIRESOUND), mt.pos, 300)
				ServerCall("server.primaryFirePIST9MM", p)
				camSineTime = 0
				camRecoilY = rnd(-1, 1)
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
			
			-- muzzleflash
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
				
			data.clipamnt = data.clipamnt - 1
			
			if data.clipamnt > 0 then
				data.NextPrimaryAttack = GetTime() + FIRERATE
			elseif ammo > 1 then
				PlaySound(LoadSound(RELOAD_SOUND), pt.pos)
				data.NextPrimaryAttack = GetTime() + RELOAD_TIME
				data.inreload = true
			else
				data.NextPrimaryAttack = GetTime() + FIRERATE
			end

			data.SoonestPrimaryAttack = GetTime() + PISTOL_FASTEST_REFIRE_TIME
			
			data.recoil = RECOIL_AMNT
		end
	end
	
	-- Allow a refire as fast as the player can click
	if ( InputDown("usetool", p) == false ) and ( data.SoonestPrimaryAttack < GetTime() ) and data.inreload == false then data.NextPrimaryAttack = GetTime() - 0.1 end

	-- decrease recoil
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
		data.toolAnimator.offsetTransform = Transform(Vec(siderecoil,recoil,recoilvert), QuatEuler(recoil * 66, recoil * -5, recoil * -5))
	end
	-- END RECOIL
	
	tickToolAnimator(data.toolAnimator, dt, nil, p)

	if IsPlayerLocal(p) then
		-- CAMERA MOVEMENT
		if camSineTime ~= nil then
			local x = camSineTime
			local balance = -10 -- where the peak is (10 for middle, higher to move left also has to be negative)
			local amp = 30 -- how intense (y at the peak will not equal this though)

			local equation = amp * ((math.sin(CAMMOVETIME * x) * math.exp(balance * x)) * x)

			if equation >= 0 then
				local t = Transform(Vec(), QuatAxisAngle(Vec(-1.0, camRecoilY, 0), equation))
				SetPlayerCameraOffsetTransform(t)
				camSineTime = camSineTime + dt
			else camSineTime = nil end
		end
	end
end

function client.drawPIST9MM()
	if GetPlayerTool() ~= WPNID then return end

	local p = GetLocalPlayer()

	local ammoToDraw = playerData[p].inreload and -8 or playerData[p].clipamnt

	client.drawAmmo(ammoToDraw, CLIP_SIZE)
end