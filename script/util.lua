#version 2

#include "script/include/player.lua"

--Return a random vector of desired length
function rndVec(length)
	local v = VecNormalize(Vec(math.random(-100,100), math.random(-100,100), math.random(-100,100)))
	return VecScale(v, length)	
end

function rnd(mi, ma)
	return math.random(1000)/1000*(ma-mi) + mi
end

-- Returns true if the server is MP
-- use this for balancing or recreating features in weapons that are only in MP (or optimizations)
function isMP()
	return GetMaxPlayers() > 1
end

function client.drawAmmo(curclip, maxclip)
	if curclip == -16 then -- gun is empty
		return
	end
	
	UiPush()
		UiFont("bold.ttf", 32)
		UiAlign("center middle")
		UiTranslate(UiCenter(), UiMiddle() + (UiMiddle() * 0.833))
		if curclip == -8 then
			UiText("RELOADING...")
		else
			UiText(curclip .. "/" .. maxclip)
		end
	UiPop()
end

function client.drawSecAmmo(curclip)
	if curclip == 0 then -- gun is empty
		return
	end
	
	UiPush()
		UiFont("bold.ttf", 32)
		UiAlign("center middle")
		UiTranslate(UiCenter(), UiMiddle() + (UiMiddle() * 0.766))
		if curclip ~= -8 then
			UiText(curclip)
		end
	UiPop()
end

function client.BloodParticles(pos, dir, damage, playerhit)
	local impactsize = damage
	if impactsize > 0.3 then
		impactsize = 0.3
	end

	local playervel = GetPlayerVelocity(playerhit)

	for i=0, 3 do
		ParticleReset()
		ParticleType("smoke")
		ParticleRadius(impactsize)
		ParticleAlpha(10, 0)
		ParticleColor(0.5, 0.0, 0)
		ParticleCollide(0)
		SpawnParticle(pos, playervel, 0.5)
	end
	
	for i=0, (impactsize * 40) do
		local size = impactsize/5
		if size > 0.035 then
			size = 0.035
		elseif size <= 0.02 then
			size = 0.02
		end

		size = size + rnd(-0.01, 0.005)
		newPos = VecAdd(pos, rndVec(0.25))
		ParticleReset()
		ParticleGravity(rnd(-20, -25))
		ParticleRadius(size)
		ParticleAlpha(1, 0, "easein") 
		ParticleColor(0.33, 0.01, 0)
		ParticleTile(6)
		ParticleDrag(0.0625)
		ParticleSticky(0.5)
		ParticleCollide(0, 1, "easeout")
		ParticleRotation(0.2, 0)
		ParticleStretch(1, 0, "easein")
		SpawnParticle(newPos, VecAdd(VecScale(GetRandomDirection(), rnd(2, 6)), playervel), 3)
	end
end

function BloodVFX(pos, dir, damage, playerhit, ignore)
	ClientCall(0, "client.BloodParticles", pos, dir, damage, playerhit)

	local count = 1
	local noise = 0.1
	if damage < 0.1 then
		noise = 0.2;
		count = 3;
	elseif damage < 0.25 then
		noise = 0.35;
		count = 6;
	else
		noise = 0.45;
		count = 12;
	end

	for i=0, count do 
		local newPos = VecAdd(pos, rndVec(0.2))

		local newdir = VecNormalize(VecAdd(VecAdd(dir, rndVec(noise)), VecScale(GetGravity(), 0.025)))
		if ignore ~= nil then QueryRejectBody(ignore) end
		QueryRejectPlayer(playerhit)
		local bloodhit, blooddist = QueryRaycast(pos, newdir, 5.5)

		if bloodhit ~= 0 then
			PaintRGBA(VecAdd(pos, VecScale(newdir, blooddist)), rnd(0.166, 0.3), rnd(0.166, 0.2), 0.0, 0.0, 1.0, rnd(0.75, 1.0))
		end
	end
	
	local newestdir = VecNormalize(VecAdd(dir, VecScale(GetGravity(), 0.025)))
	if ignore ~= nil then QueryRejectBody(ignore) end
	QueryRejectPlayer(playerhit)
	local bigbloodhit, bigblooddist = QueryRaycast(pos, newestdir, 4)

	if bigbloodhit ~= 0 then
		PaintRGBA(VecAdd(pos, VecScale(dir, bigblooddist)), 0.5, rnd(0.166, 0.2), 0.0, 0.0, 1.0, 1.0)
	end
end

function getAimVector(pos, range, spreadRad, p, spreadRadVert)
	spreadRadVert = spreadRadVert or spreadRad

	local _,newPos,_,dir = GetPlayerAimInfo(pos, range, p)

	if spreadRad <= 0 then
		return newPos, dir
	end
	
	-- BEGIN BORROWED CODE (Thanks Novena)
	local cosAngle = math.cos(spreadRad)
	local z = 1 - math.random()*(1 - cosAngle)
	local phi = math.random()*math.pi*2
	local r = math.sqrt(1 - z*z)
	local x = r * math.cos(phi)
	local y = r * math.sin(phi)
	local vec = Vec(x, y, z)

	if dir[3] > 0.9999 then
		return newPos, vec
	elseif dir[3] < -0.9999 then
		return newPos, VecScale(vec,-1)
	end

	local quat = QuatLookAt(Vec(0,0,0),VecScale(dir,-1))
	local newDir = TransformToParentVec(Transform(Vec(0,0,0),quat),vec)
	-- END BORROWED CODE

	return newPos, newDir
end

-- hook the Shoot func to add new stuff
function ShootHook(pos, dir, shoottype, damage, playerdamage, range, player, weaponid, weaponname, impulseMult)
	impulseMult = impulseMult or 1
	playerdamage = playerdamage or 0

	-- destroy ropes (only runs once!!)
	local ropeHit, ropeDist, ropeJoint = QueryRaycastRope(pos, dir, range)
	if ropeHit then
		local breakPoint = VecAdd(pos, VecScale(dir, ropeDist))
		BreakRope(ropeJoint, breakPoint)
	end
	
	-- figure out whether we need to run player or world hit code
	local bHit, pdist, pShape, playerhit = QueryShot(pos, dir, range, 0, player)

	-- knock back objects some more
	if bHit then
		ApplyBodyImpulse(GetShapeBody(pShape), VecAdd(pos, VecScale(dir, pdist)), VecScale(dir, 800 * impulseMult))
	end

	if playerhit == 0 then
		-- use normal shooting for world
		Shoot(pos, dir, shoottype, damage, range, player, weaponid)
	else
		-- play player impact SFX
		local SoundPoint = VecAdd(pos, VecScale(dir, pdist))
		PlaySound(LoadSound("MOD/snd/bullet_hit0.ogg"), SoundPoint, 2)

		-- don't actually hit the player so we can do our own damage and vfx
		local newrange = pdist - 0.125
		if newrange > 0 then Shoot(pos, dir, shoottype, damage, newrange, player, weaponid) end

		-- check what bodypart was hit
		QueryRequire("player")
		QueryInclude("player")
		local _, _, _, bodyPart = QueryRaycast(pos, dir, range + 0.125, 0.1)

		-- per bodypart damage
		local hitPart = GetTagValue(GetShapeBody(bodyPart), "bone")
		if hitPart == "head" then
			playerdamage = playerdamage * GLOBAL_HEADSHOTMULT
		elseif hitPart == "neck" then
			playerdamage = playerdamage * (GLOBAL_HEADSHOTMULT/2)
		end

		-- deal damage, do blood VFX
		ApplyPlayerDamage(playerhit, playerdamage, weaponname, player)
		BloodVFX(SoundPoint, dir, playerdamage, playerhit)
	end

	return bHit, pdist
end

function server.SpawnFireHook(pos, chance)
	if math.random(0, 100) <= chance then
		SpawnFire(pos)
	end
end

function server.depleteAmmo(p, id, amount)
	amount = amount or 1
	local ammo = GetToolAmmo(id, p)
	if ammo < 9999 then
		SetToolAmmo(id, ammo-amount, p)
	end
end