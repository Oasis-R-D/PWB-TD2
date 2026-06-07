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

local BALL_VELOCITY = 128 -- 63.5 is game accurate, 128 is cooler for MP

-- Per weapon data storer
CROSSplayers = {}

-- Stores data for all the BOLTS
CrossbowBolts = {}

function createPlayerCLIENTdataCROSS()
    return {
		coolDown = 0.0,
		altCoolDown = 0.0,
		recoil = 0.0,
		toolAnimator = ToolAnimator(),
		scoped = false,
		timetobolt = nil,
		hasBolt = true,
		dataReset = true,
		shapesNeedsUpd = true,
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

function server.initCROSS()
	RegisterTool(WPNID, WPNNAME, "MOD/prefab/crossbow.xml", 6)
	SetToolAmmoPickupAmount(WPNID, PICKUP_SIZE)
end

function server.tickCROSS(dt)
	for p in PlayersAdded() do
		SetToolEnabled(WPNID, true, p)
		SetToolAmmo(WPNID, 250, p)
	end

	-- doesn't need server ticking
	--for p in Players() do
		--server.tickPlayerCROSS(p, dt)
	--end

	if #CrossbowBolts == 0 then return end -- no crossbow bolts
	
	for index = 1, #CrossbowBolts do
		local data = CrossbowBolts[index]

		if data.totalDist > 1000 then -- make 500 if using HL2 speed
			Delete(data.model)
			table.remove(CrossbowBolts, index)
		else
			PointLight(data.curPos, 0.66,0.22,0, 0.2)

			QueryRequire("large visible physical")
			QueryRejectBody(data.model)
			local hit, dist, shape, hitPlayer, _, normal = QueryShot(data.curPos, data.curDir, BALL_VELOCITY * dt, 0.0, data.owner)

			data.curPos= VecAdd(data.curPos, VecScale(data.curDir, dist))
			
			data.totalDist = data.totalDist + dist

			SetBodyTransform(data.model, Transform(data.curPos, QuatLookAt(Vec(), data.curDir)))

			-- damage, vfx
			if hit then
				if hitPlayer ~= 0 then
					PlaySound(LoadSound(BOLT_PLAYER), data.curPos, 0.5)

					ApplyPlayerDamage(hitPlayer, PLAYERDAMAGE, WPNNAME, data.owner)
					BloodVFX(data.curPos, data.curDir, PLAYERDAMAGE, hitPlayer)

					Delete(data.model)
					table.remove(CrossbowBolts, index)
				else
					-- See if we should reflect off this surface
					local hitDot = VecDot(normal, VecScale(data.curDir, -1))
					if hitDot < 0.5 and dist ~= 0 then
						ShootHook(data.curPos, data.curDir, "bullet", DAMAGE/2, 0, 10, data.owner, WPNID, WPNNAME)
						Paint(data.curPos, 0.16, "explosion", 0.75)

						data.curDir = VecAdd(VecScale(normal, 2 * hitDot), data.curDir)
						data.curPos = VecAdd(data.curPos, VecScale(data.curDir, 0.01))

						PlaySound(LoadSound(BOLT_IMPACT), data.curPos, 0.25)
					else
						-- sparks
						for i=1,10 do
							ParticleReset()
							ParticleCollide(1)
							ParticleRadius(0.02, 0)
							ParticleGravity(-10)
							ParticleEmissive(5)
							ParticleStretch(5)
							ParticleTile(4)
							ParticleColor(1,0.5,0.4, 1,0.25,0)
							SpawnParticle(data.curPos, Vec(math.random(-2,2), math.random(1,4), math.random(-2,2)), 1)
						end

						-- get mat type BEFORE we break it
						local matType = GetShapeMaterialAtPosition(shape, data.curPos)

						ShootHook(data.curPos, data.curDir, "bullet", DAMAGE, 0, 10, data.owner, WPNID, WPNNAME)

						server.SpawnFireHook(data.curPos, 75)
						Paint(data.curPos, 0.33, "explosion", 0.75)

						if matType ~= "glass" or HasTag(GetShapeBody(shape), "unbreakable") == true then
							PlaySound(LoadSound(BOLT_IMPACT), data.curPos, 0.5)

							Delete(data.model)
							table.remove(CrossbowBolts, index)
						end
					end
				end
			end
		end
	end
end

function server.tickPlayerCROSS(p, dt)
end

function server.primaryFireCROSS(p)
	local mt = GetToolLocationWorldTransform("muzzle", p)

	local ammo = GetToolAmmo(WPNID, p)

	if ammo <= 0 then return end
	
	local pos, dir = getAimVector(GetPlayerEyeTransform(p).pos, MAX_RANGE, 0, p)

	local GrenTrans = Transform(Vec(0, -1000, 0))
	local xml = "MOD/prefab/crossbow_bolt.xml"
	local boltEnt = Spawn(xml, GrenTrans)

	-- add bolt to sim
	CrossbowBolts[FindBoltSERVERdataOpening()] = createBallSERVERdataCB(p, pos, dir, boltEnt[1])

	PlaySound(LoadSound(PRIM_FIRESOUND), pos, 300)
	PlaySound(LoadSound(PRIM_FIRESOUND2), pos, 10)
	if ammo < 9999 then
		SetToolAmmo(WPNID, ammo-1, p)
	end
end

function client.initCROSS()
	shootHaptic = LoadHaptic("MOD/haptic/gun_fire.xml")
	local toolHaptic = LoadHaptic("MOD/haptic/background.xml")
	SetToolHaptic(WPNID, toolHaptic);
end

function client.tickCROSS(dt)
	for p in PlayersAdded() do
		CROSSplayers[p] = createPlayerCLIENTdataCROSS();
	end

	for p in PlayersRemoved() do
		CROSSplayers[p] = nil
	end

	for p in Players() do
		client.tickPlayerCROSS(p, dt)
	end
end

clipamnt = 0
local camSineTime = nil

-- stolen from glock, used to hide/show bolt
function client.suppress(p, suppressed)
	local toolBody = GetToolBody(p)
	local shapes = GetBodyShapes(toolBody)
	if suppressed == false then
		SetTag(shapes[6], "invisible")
	else
		RemoveTag(shapes[6], "invisible")
	end
end

function client.tickPlayerCROSS(p, dt)
	if not IsToolEnabled(WPNID, p) then return end
	
	if GetPlayerHealth(p) <= 0 then
		if CROSSplayers[p].dataReset == false then
			CROSSplayers[p] = createPlayerCLIENTdataCROSS()
		end
		return
	end

	if GetPlayerTool(p) ~= WPNID then
		CROSSplayers[p].shapesNeedsUpd = true
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

	local data = CROSSplayers[p]

	-- tell gun to restore bolt state
	if data.shapesNeedsUpd == true then
		data.shapesNeedsUpd = false
		data.hasBolt = false
		data.timetobolt = 0.842
		data.toolAnimator.timeSinceFire = 0.0
	end

	-- make data reset when reset conditions are met
	data.dataReset = false

	-- Check Fire
	if InputDown("usetool", p) and canFire(p, ammo, ammo) and data.hasBolt == true then -- not a good idea to use hasbolt here, only way to prevent THE BUG
		if data.coolDown < 0 then
			PointLight(mt.pos, 1, 0.7, 0.5, 3)
			if IsPlayerLocal(p) then
				ServerCall("server.primaryFireCROSS", p)
				camSineTime = 0
				PlayHaptic(shootHaptic, 1)
			end
			
			local playervel = GetPlayerVelocity(p)

			data.hasBolt = false
			client.suppress(p, data.hasBolt)

			if ammo-1 > 0 then data.timetobolt = 0.842 end

			data.coolDown = FIRERATE
			data.altCoolDown = SCOPEFIREDELAY

			data.recoil = RECOIL_AMNT
		end
	-- Check Altfire
	elseif InputPressed("grab", p) and GetPlayerCanUseTool(p) == true then
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
		if data.timetobolt <= 0 then
			data.hasBolt = true -- shouldn't matter since you can't switch out of and back with 0 ammo
			if ammo > 0 then -- already plays bolt sfx in reload
				client.suppress(p, data.hasBolt)
				PlaySound(LoadSound(BOLT_CYCLE), pt.pos)
				data.toolAnimator.timeSinceFire = 0.0
			end

			data.timetobolt = nil
			data.recoil = 0.05
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
			local balance = -10 -- where the peak is (10 for middle, higher to move left also has to be negative)
			local amp = 1000 -- how intense (y at the peak will not equal this though)

			local equation = amp * ((math.sin(CAMMOVETIME * x) * math.exp(balance * x)) * x)

			if equation >= 0 then
				local t = Transform(Vec(), QuatAxisAngle(Vec(1.0, -0.1, 0), equation))
				SetPlayerCameraOffsetTransform(t)
				camSineTime = camSineTime + dt
			else camSineTime = nil end
		end
	end
end