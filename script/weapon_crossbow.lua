-- copy this for the most basic scoped mag loaded weapon with slower empty reloads (INCLUDES SCOPE)
#version 2

#include "script/include/player.lua"
#include "script/pwbtoolanimation.lua"
#include "script/util.lua"

-- Per weapon constants
local PRIM_FIRESOUND = "MOD/snd/crossbow_fire.ogg"
local PRIM_FIRESOUND2 = "MOD/snd/crossbow_fire2.ogg"
local BOLT_CYCLE = "MOD/snd/crossbow_load0.ogg"
local PICKUP_SIZE = 3.0
local RECOIL_AMNT = 0.25
local FIRERATE = 2.0
local CAMMOVETIME = (2 * math.pi) * (0.5 / FIRERATE) -- Cam movement sine multiplier, FIRERATE is how long until it's over
local ALTFIRERATE = 0.5
local SCOPEFIREDELAY = 0.1
local DAMAGE = 0.5
local PLAYERDAMAGE = 1.0
local WPNID = "hl2crossbow"
local WPNNAME = "Rebar Crossbow"

local BOLT_IMPACT = "MOD/snd/crossbow_bt_hit.ogg"
local BOLT_PLAYER = "MOD/snd/crossbow_bt_player0.ogg"

local BALL_VELOCITY = 63.5 -- game accurate

-- Per weapon data storer
M40players = {}

-- Stores data for all the BOLTS
CrossbowBolts = {}

function createPlayerCLIENTdataM40()
    return {
		coolDown = 0.0,
		altCoolDown = 0.0,
		recoil = 0.0,
		toolAnimator = ToolAnimator(),
		scoped = false,
		timetobolt = nil,
		playbolt = true,
		dataReset = true,
	}
end

function FindBoltSERVERdataOpening()
    local i = 1
    while CrossbowBolts[i] ~= nil do
        i = i + 1
    end
    return i
end

function createBallSERVERdataCB(p, pos, dir, body)
    return {
		curDir = dir,
		curPos = pos,
		model = body,
		owner = p,
		totalDist = 0.0,
	}
end

function server.initM40()
	RegisterTool(WPNID, WPNNAME, "MOD/prefab/m40a1.xml", 6)
	SetToolAmmoPickupAmount(WPNID, PICKUP_SIZE)
end

function server.tickM40(dt)
	for p in PlayersAdded() do
		SetToolEnabled(WPNID, true, p)
		SetToolAmmo(WPNID, 250, p)
	end

	-- doesn't need server ticking
	--for p in Players() do
		--server.tickPlayerM40(p, dt)
	--end

	if #CrossbowBolts == 0 then return end -- no crossbow bolts
	
	for index, data in pairs(CrossbowBolts) do
		if data.totalDist > 500 then
			Delete(data.model)
			CrossbowBolts[index] = nil -- delete the bolt
		else
			PointLight(data.curPos, 0.66,0.22,0, 0.2)

			QueryRejectBody(data.model)
			local hit, dist, shape, hitPlayer, _, normal = QueryShot(data.curPos, data.curDir, BALL_VELOCITY * dt, 0.0, data.owner)

			data.curPos= VecAdd(data.curPos, VecScale(data.curDir, dist))
			
			data.totalDist = data.totalDist + dist

			SetBodyTransform(data.model, Transform(data.curPos, QuatLookAt(Vec(), data.curDir)))

			if hit and dist ~= 0 then
				-- do damage
				if hitPlayer ~= 0 then
					PlaySound(LoadSound(BOLT_PLAYER), data.curPos, 0.5)

					ApplyPlayerDamage(hitPlayer, PLAYERDAMAGE, WPNNAME, data.owner)
					BloodVFX(VecAdd(data.curPos, VecScale(data.curDir, dist)), data.curDir, PLAYERDAMAGE, hitPlayer)

					Delete(data.model)
					CrossbowBolts[index] = nil -- delete the bolt
				else
					-- get mat type BEFORE we break it
					local matType = GetShapeMaterialAtPosition(shape, data.curPos)

					ShootHook(data.curPos, data.curDir, "bullet", DAMAGE, 0, 10, data.owner, WPNID, WPNNAME)

					Paint(data.curPos, 0.33, "explosion", 0.75)

					-- spawn fire sometimes
					server.SpawnFireHook(data.curPos, 50)

					if matType ~= "glass" then
						-- play sound and VFX here since it spams sounds and VFX otherwise

						-- sparks
						for i=1,10 do
							ParticleReset()
							ParticleCollide(1)
							ParticleRadius(0.02, 0)
							ParticleGravity(-10)
							ParticleEmissive(5)
							ParticleStretch(5)
							ParticleTile(4)
							ParticleColor(1,0.5,0.5, 1,0.25,0)
							SpawnParticle(data.curPos, Vec(math.random(-2,2), math.random(1,4), math.random(-2,2)), 1)
						end

						PlaySound(LoadSound(BOLT_IMPACT), data.curPos, 0.5)

						-- See if we should reflect off this surface
						local hitDot = VecDot(normal, VecScale(data.curDir, -1))
						if hitDot < 0.5 then
							--data.curDir = VecSub(data.curDir, VecScale(normal, VecDot(normal, data.curDir) * 2)) -- TO-DO: only reflect at some angles
							data.curDir = VecAdd(VecScale(normal, 2 * hitDot), data.curDir)
						else
							Delete(data.model)
							CrossbowBolts[index] = nil -- delete the bolt
						end
					end
				end
			end
		end
	end
end

function server.tickPlayerM40(p, dt)
end

function server.primaryFireM40(p)
	local mt = GetToolLocationWorldTransform("muzzle", p)

	local ammo = GetToolAmmo(WPNID, p)

	local pos, dir = getAimVector(mt.pos, MAX_RANGE, 0, p)

	local GrenTrans = Transform(mt.pos, QuatLookAt(Vec(), dir))
	local xml = "MOD/prefab/crossbow_bolt.xml"
	local boltEnt = Spawn(xml, GrenTrans)

	-- add bolt to sim
	CrossbowBolts[FindBoltSERVERdataOpening()] = createBallSERVERdataCB(p, mt.pos, dir, boltEnt[1])

	PlaySound(LoadSound(PRIM_FIRESOUND), mt.pos, 300)
	PlaySound(LoadSound(PRIM_FIRESOUND2), mt.pos, 10)
	if ammo < 9999 then
		SetToolAmmo(WPNID, ammo-1, p)
	end
end

function client.initM40()
	shootHaptic = LoadHaptic("MOD/haptic/gun_fire.xml")
	local toolHaptic = LoadHaptic("MOD/haptic/background.xml")
	SetToolHaptic(WPNID, toolHaptic);
end

function client.tickM40(dt)
	for p in PlayersAdded() do
		M40players[p] = createPlayerCLIENTdataM40();
	end

	for p in PlayersRemoved() do
		M40players[p] = nil
	end

	for p in Players() do
		client.tickPlayerM40(p, dt)
	end
end

clipamnt = 0
local camSineTime = nil

function client.tickPlayerM40(p, dt)
	if not IsToolEnabled(WPNID, p) then return end
	
	if GetPlayerHealth(p) <= 0 then
		if M40players[p].dataReset == false then
			M40players[p] = createPlayerCLIENTdataM40()
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

	local data = M40players[p]

	-- make data reset when reset conditions are met
	data.dataReset = false

	if InputDown("usetool", p) and ammo > 0.5 and GetPlayerCanUseTool(p) == true then
			if data.coolDown < 0 then
				PointLight(mt.pos, 1, 0.7, 0.5, 3)
				if IsPlayerLocal(p) then
					ServerCall("server.primaryFireM40", p)
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
				data.timetobolt = 0.842
				if ammo-1 > 0 then
					data.timetobolt = 0.842
					data.coolDown = FIRERATE
					data.altCoolDown = SCOPEFIREDELAY
				end
				
				data.recoil = RECOIL_AMNT
			end
	end

	if InputPressed("grab", p) and GetPlayerCanUseTool(p) == true then
		if data.altCoolDown < 0 then
			data.altCoolDown = ALTFIRERATE
			data.scoped = not data.scoped
		end
	end

	if data.scoped == false or ammo <= 0 then
		data.toolAnimator.forceSecondaryActionPose = false
	elseif data.scoped == true then
		data.toolAnimator.forceSecondaryActionPose = true

		if IsPlayerLocal(p) then
			SetCameraFov(18)
		end
	end
		
	-- decrease firing cooldown and recoil
	data.coolDown = data.coolDown - dt
	data.altCoolDown = data.altCoolDown - dt
	data.recoil = data.recoil - dt
	
	if data.timetobolt ~= nil then
		data.timetobolt = data.timetobolt - dt
		if data.timetobolt <= 0 and data.playbolt == true then
			if ammo > 0 then -- already plays bolt sfx in reload
				PlaySound(LoadSound(BOLT_CYCLE), pt.pos)
				-- TO-DO: make bolt visible again here
			end
			data.playbolt = false
			data.recoil = 0.05
		end
		if data.timetobolt <= -0.1 then
			data.timetobolt = nil
			data.playbolt = true
			data.recoil = 0.025
		end
	end
	-- END SHELL EJECT
	
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
	
	tickToolAnimator(data.toolAnimator, dt, nil, p)

	
	if IsPlayerLocal(p) then
		-- CAMERA MOVEMENT
		if camSineTime ~= nil then
			local x = camSineTime
			local e = math.exp(1)
			local balance = -10 -- where the peak is (10 for middle, higher to move left also has to be neagtive)
			local amp = 600 -- how intense (y at the peak will not equal this though)

			local equation = amp * ((math.sin(CAMMOVETIME * x) * e^(balance * x)) * x)

			if equation >= 0 then
				local t = Transform(Vec(), QuatAxisAngle(Vec(1.0, -0.1, 0), equation))
				SetPlayerCameraOffsetTransform(t)
				camSineTime = camSineTime + dt
			else camSineTime = nil end
		end
	end
end