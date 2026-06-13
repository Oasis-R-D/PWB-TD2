-- copy this for the most basic tube loaded weapon with alt fire
#version 2

-- Per weapon constants
local RELOAD_TIME = 0.4 -- seconds
local RELOAD_START_TIME = 0.5 -- seconds -- reload start anim is 0.5 secs
local RELOAD_END_TIME = 0.433 -- seconds -- reload end anim is 0.433 secs

local PUMP_TIME = 0.53 -- seconds -- same timing

-- time for firing to finish
local FIRE_TIME = 0.333
local ALTFIRE_TIME = 0.733

local PRIM_FIRESOUND = "MOD/snd/shotgun_fire.ogg"
local ALT_FIRESOUND = "MOD/snd/shotgun_dbl_fire.ogg"
local PUMP_SOUND = "MOD/snd/shotgun_cock.ogg"
local CLIP_SIZE = 6
local PICKUP_SIZE = 6
local RECOIL_AMNT = 0.2
local CAMMOVETIME = (2 * math.pi) * (0.5 / FIRE_TIME) -- Cam movement sine multiplier, FIRERATE is how long until it's over
local CAMALTMOVETIME = (2 * math.pi) * (0.5 / ALTFIRE_TIME) -- Cam movement sine multiplier, ALTFIRERATE is how long until it's over
local DAMAGE = 0.35
local PLAYERDAMAGE = 0.09
local MAX_RANGE = 60.0
local WPNID = "hl2shotgun"
local WPNNAME = "Combine Shotgun"
local CASING_ORG = Vec(0.02, 0.1, 0.075)

-- Per weapon data storer
local playerData = {}
	
function createPlayerCLIENTdataSG()
    return {
		clipamnt = CLIP_SIZE,
		inreload = false,
		coolDown = 0.0,
		recoil = 0.0,
		toolAnimator = ToolAnimator(),
		pumptime = nil, -- time until pump sound is played (and animations if those are ever added)
		shellinserttime = nil,
		shellstoload = 0,
		shellstopump = 0.0,
		camAltMove = false,
		dataReset = true,

		body = nil,
		slide = nil,
		slideTransform = nil,
	}
end

function server.initSG()
	RegisterTool(WPNID, WPNNAME, "MOD/prefab/shotgun.xml", 3)
	SetToolAmmoPickupAmount(WPNID, PICKUP_SIZE)
end

function server.tickSG(dt)
	for p in PlayersAdded() do
		SetToolEnabled(WPNID, true, p)
		SetToolAmmo(WPNID, 125, p)
	end

	-- doesn't need server ticking
	--for p in Players() do
		--server.tickPlayerSG(p, dt)
	--end
end

function server.tickPlayerSG(p, dt)
end

function server.primaryFireSG(p)
	local mt = GetToolLocationWorldTransform("muzzle", p)

	-- first shot is laser accurate
	local pos, dir = getAimVector(GetPlayerEyeTransform(p).pos, MAX_RANGE, 0, p)
	ShootHook(pos, dir, "bullet", DAMAGE, PLAYERDAMAGE, MAX_RANGE, p, WPNID, WPNNAME)

	-- rest aren't
	for i=1, 6 do
		pos, dir = getAimVector(GetPlayerEyeTransform(p).pos, MAX_RANGE, GLOBAL_10DEGREES, p)
		local radius = (i % 2 ~= 0) and 0.33 or 0
		ShootHook(pos, dir, "bullet", DAMAGE, PLAYERDAMAGE, MAX_RANGE, p, WPNID, WPNNAME, 1, radius)
	end
	
	PlaySound(LoadSound(PRIM_FIRESOUND), mt.pos, 300)
	
	server.depleteAmmo(p, WPNID)
end

function server.secondaryFireSG(p)
	local mt = GetToolLocationWorldTransform("muzzle", p)

	for i=1, 12 do
		local pos, dir = getAimVector(GetPlayerEyeTransform(p).pos, MAX_RANGE, GLOBAL_10DEGREES, p)
		local radius = (i % 2 == 0) and 0.33 or 0
		ShootHook(pos, dir, "bullet", DAMAGE, PLAYERDAMAGE, MAX_RANGE, p, WPNID, WPNNAME, 1, radius)
	end
	
	PlaySound(LoadSound(ALT_FIRESOUND), mt.pos, 300)

	server.depleteAmmo(p, WPNID, 2)
end

function client.initSG()
	shootHaptic = LoadHaptic("MOD/haptic/gun_fire.xml")
	local toolHaptic = LoadHaptic("MOD/haptic/background.xml")
	SetToolHaptic(WPNID, toolHaptic);
end

function client.tickSG(dt)
	for p in PlayersAdded() do
		playerData[p] = createPlayerCLIENTdataSG();
	end

	for p in PlayersRemoved() do
		playerData[p] = nil
	end

	for p in Players() do
		client.tickPlayerSG(p, dt)
	end
end

local camSineTime = nil
local camRecoilY = 0
local SlideTime = nil

-- in HL2, using the secondary fire with only enough ammo for the primary will fire primary instead.
-- separated it to it's own function to allow that
function client.primaryFireSG(p)
	local pt = GetPlayerTransform(p)
	local mt = GetToolLocationWorldTransform("muzzle", p)

	local ammo = GetToolAmmo(WPNID, p)

	if mt == nil then
		return
	end
	
	local data = playerData[p]

	PointLight(mt.pos, 1, 0.7, 0.5, 3)
	if IsPlayerLocal(p) then
		ServerCall("server.primaryFireSG", p)
		camSineTime = 0
		camRecoilY = rnd(-0.8, 0.8)
		data.camAltMove = false
		PlayHaptic(shootHaptic, 1)

		-- shell ejection
		data.shellstopump = 1.0
	end

	local toolBody = GetToolBody(p)
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
		
	data.clipamnt = data.clipamnt - 1
	if data.clipamnt > 0 then
		data.coolDown = FIRE_TIME + PUMP_TIME
		data.pumptime = FIRE_TIME
	elseif ammo > 1 then
		local reloadtime = nil
		local shellsneedingloading = CLIP_SIZE - data.clipamnt

		if shellsneedingloading > ammo then
			shellsneedingloading = ammo
		end

		reloadtime = (shellsneedingloading * RELOAD_TIME) + RELOAD_END_TIME
		data.pumptime = reloadtime
		data.shellstoload = shellsneedingloading
		data.coolDown = reloadtime
		data.shellinserttime = RELOAD_START_TIME
		data.inreload = true
	end
	
	data.recoil = RECOIL_AMNT
end

function client.tickPlayerSG(p, dt)
	if not IsToolEnabled(WPNID, p) then return end
	
	if GetPlayerHealth(p) <= 0 then
		if playerData[p].dataReset == false then
			playerData[p] = createPlayerCLIENTdataSG()
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
		local reloadtime = nil
		local shellsneedingloading = math.min(CLIP_SIZE - data.clipamnt, ammo)

		if data.clipamnt > 0 then
			reloadtime = RELOAD_TIME * shellsneedingloading
			data.shellstoload = shellsneedingloading
		else
			reloadtime = (RELOAD_TIME * shellsneedingloading) + RELOAD_END_TIME
			data.pumptime = reloadtime
			data.shellstoload = shellsneedingloading
		end

		data.coolDown = reloadtime
		data.shellinserttime = RELOAD_START_TIME
		data.inreload = true
	-- Finish Reloading
	elseif data.inreload == true and data.coolDown < 0 then -- reload the clip
		data.inreload = false
		data.clipamnt = math.min(CLIP_SIZE, ammo)
	-- Check Fire
	elseif InputDown("usetool", p) and canFire(p, ammo, data.clipamnt) then
		if data.coolDown < 0 then				
			client.primaryFireSG(p)
		end
	-- Check Altfire
	elseif InputDown("grab", p) and canFire(p, ammo-1, data.clipamnt-1) then 
		if data.coolDown < 0 then
			PointLight(mt.pos, 1, 0.7, 0.5, 3)
			if IsPlayerLocal(p) then
				ServerCall("server.secondaryFireSG", p)
				camSineTime = 0
				camRecoilY = 0
				data.camAltMove = true
				PlayHaptic(shootHaptic, 1)

				-- shell ejection
				data.shellstopump = 2
			end

			local toolBody = GetToolBody(p)
			local playervel = GetPlayerVelocity(p)
			
			-- muzzleflash
			for i=0, 4 do
				ParticleReset()
				ParticleGravity(0)
				ParticleRadius(rnd(0.15, 0.2), 0.44)
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

			data.toolAnimator.timeSinceFire = 0.0 -- hold the gun straight
			
			data.clipamnt = data.clipamnt - 2
			if data.clipamnt > 0 then
				data.coolDown = ALTFIRE_TIME + PUMP_TIME
				data.pumptime = ALTFIRE_TIME
			elseif ammo > 1 then
				local reloadtime = 0
				
				local shellsneedingloading = math.min(CLIP_SIZE - data.clipamnt, ammo)

				reloadtime = (shellsneedingloading * RELOAD_TIME) + RELOAD_END_TIME
				data.pumptime = reloadtime
				data.shellstoload = shellsneedingloading
				data.coolDown = reloadtime
				data.shellinserttime = RELOAD_START_TIME
				data.inreload = true
			end
			
			data.recoil = 1.5 * RECOIL_AMNT
		end
	elseif InputDown("grab", p) and canFire(p, ammo, data.clipamnt) then -- has enough ammo to primary but not secondary, so fire primary
		if data.coolDown < 0 then
			client.primaryFireSG(p)
		end
	end
	
	-- decrease firing cooldown and recoil
	data.coolDown = data.coolDown - dt
	data.recoil = data.recoil - dt
	
	-- SHELL LOADING
	if data.shellinserttime ~= nil then
		data.shellinserttime = data.shellinserttime - dt
		
		if data.shellinserttime < 0 and data.shellstoload >= 0.5 then
			PlaySound(LoadSound("MOD/snd/shotgun_reload0.ogg"), pt.pos)
			data.shellinserttime = RELOAD_TIME
			data.shellstoload = data.shellstoload - 1
			data.recoil = 0.1
		end
		
		if data.shellstoload <= 0 then
			data.shellinserttime = nil
		end
	end
	-- END SHELL LOADING
	
	-- PUMPING
	if data.pumptime ~= nil then
		data.pumptime = data.pumptime - dt
	
		-- pump the gun
		if data.pumptime < 0 then
			PlaySound(LoadSound(PUMP_SOUND), pt.pos)
			data.pumptime = nil
			-- SHELL EJECT
			if IsPlayerLocal(p) then
				SlideTime = 0
				local toolBody = GetToolBody(p)
				local transform = GetBodyTransform(toolBody)
				local eject_origin = TransformToParentPoint(transform, Vec(CASING_ORG[1],CASING_ORG[2],CASING_ORG[3]))
				local eject_direction=TransformToParentVec(transform, Vec(1, -0.2, 0))
				local playervel = GetPlayerVelocity(p)
				
				for i=1, data.shellstopump do
					ParticleReset()
					ParticleGravity(rnd(-2, -8))
					ParticleRadius(0.02)
					ParticleAlpha(1)
					ParticleColor(0.8, 0.1, 0)
					ParticleTile(6)
					ParticleDrag(0.125)
					ParticleSticky(0.5)
					ParticleCollide(1)
					SpawnParticle(eject_origin, VecAdd(VecScale(eject_direction,3), playervel), 5)
				end
			end
			-- SHELL EJECT END
		end
	end
	-- END PUMPING
	
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
		data.toolAnimator.offsetTransform = Transform(Vec(siderecoil,recoil,recoilvert), QuatEuler(recoil * 50, 0, 0))
	end 
	-- END RECOIL
	
	tickToolAnimator(data.toolAnimator, dt, nil, p)

	
	if IsPlayerLocal(p) then
		-- CAMERA MOVEMENT
		if camSineTime ~= nil then
			local x = camSineTime
			local balance = -15 -- where the peak is (10 for middle, higher to move left also has to be negative)
			local amp = 200 -- how intense (y at the peak will not equal this though)

			local equation = nil
			if data.camAltMove == true then
				balance = -15
				amp = 1000
				equation = amp * ((math.sin(CAMALTMOVETIME * x) * math.exp(balance * x)) * x)
			else
				equation = amp * ((math.sin(CAMMOVETIME * x) * math.exp(balance * x)) * x)
			end

			if equation >= 0 then
				local t = Transform(Vec(), QuatAxisAngle(Vec(1.0, camRecoilY, 0), equation))
				SetPlayerCameraOffsetTransform(t)
				camSineTime = camSineTime + dt
			else camSineTime = nil end
		end

		--Animate Slide
		local GunBody = GetToolBody(p)
		if data.body ~= GunBody then
			data.body = GunBody
			-- Slide is the forth shape in vox file. Remember original position in attachment frame
			local shapes = GetBodyShapes(GunBody)
			data.slide = shapes[4]
			data.slideTransform = GetShapeLocalTransform(data.slide)
		end
		if data.slide and SlideTime ~= nil then
			SlideTime = SlideTime + dt
		
			local UseValue = SlideTime

			-- don't go over, add a delay between the pump forward!
			if SlideTime >= 0.375 then
				SlideTime = 0.375
			elseif SlideTime > 0.125 and SlideTime < 0.25 then
				UseValue = 0.125 -- lock back for a little
			elseif SlideTime >= 0.25 then
				UseValue = SlideTime - 0.125
			end

			local position = Vec(0, 0, 0.10 * math.sin(4 * math.pi * UseValue))
			local TOffset = Transform(position)
			data.toolAnimator.leftHand.transform.pos = position

			local t = TransformToParentTransform(TOffset, data.slideTransform)
			SetShapeLocalTransform(data.slide, t)

			-- Slide has returned
			if SlideTime >= 0.375 then
				SetShapeLocalTransform(data.slide, data.slideTransform) -- force back just in case
				SlideTime = nil
			end
		end
	end
end

function client.drawSG()
	if GetPlayerTool() ~= WPNID then return end

	local p = GetLocalPlayer()

	local ammoToDraw = playerData[p].inreload and -8 or playerData[p].clipamnt

	client.drawAmmo(ammoToDraw, CLIP_SIZE)
end