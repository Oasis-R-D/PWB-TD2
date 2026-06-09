#version 2

#include "script/include/player.lua"

function canFire(p, ammo, clip)
	return ammo > 0.5 and clip > 0.5 and GetPlayerCanUseTool(p) == true
end

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

	local size = impactsize/5
	if size > 0.035 then
		size = 0.035
	elseif size <= 0.02 then
		size = 0.02
	end

	local playervel = GetPlayerVelocity(playerhit)

	local blooddir = VecScale(dir, -1)

	local cloudsize = size*10

	local dropsize = damage/3
	if dropsize > 0.4 then dropsize = 0.4 end

	for i=0, 4 do
		ParticleReset()
		ParticleRadius(dropsize)
		ParticleGravity(rnd(-5, -10))
		ParticleAlpha(5, 0, "easein") 
		ParticleTile(5)
		ParticleStretch(10)
		ParticleColor(0.33, 0.01, 0)
		ParticleCollide(0)
		local direct = VecAdd(blooddir, rndVec(0.25))
		SpawnParticle(pos, VecAdd(VecScale(direct, rnd(0.8, 3.0)), playervel), 0.75)

		ParticleReset()
		ParticleRadius(cloudsize, 0.35)
		ParticleAlpha(5, 0, "easein") 
		ParticleTile(1)
		ParticleStretch(10)
		ParticleColor(0.33, 0.01, 0)
		ParticleCollide(0)
		SpawnParticle(pos, VecAdd(VecScale(direct, math.random()*1.5), playervel), 0.75)
	end

	for i=0, (impactsize * 40) do
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
	elseif damage > 0.8 then
		noise = 0.6;
		count = 18;
	else
		noise = 0.35;
		count = 12;
	end

	-- Impact for animators
	PaintRGBA(pos, rnd(0.166, 0.3), rnd(0.2, 0.3), 0.0, 0.0, 1.0, 0.9)

	for i=0, count do 
		local newPos = VecAdd(pos, rndVec(0.2))
		local newdir = VecNormalize(VecAdd(VecAdd(dir, rndVec(noise)), VecScale(GetGravity(), 0.025)))

		if ignore ~= nil then QueryRejectAnimator(ignore) end
		local bloodhit, blooddist = QueryRaycast(pos, newdir, 5.5)

		if bloodhit ~= 0 and blooddist > 0.33 then
			local splatDist = blooddist
			if splatDist > 1 then splatDist = 1 end
			local chance = rnd(0.75, 1.0) * 1/splatDist * splatDist / 2
			PaintRGBA(VecAdd(pos, VecScale(newdir, blooddist)), rnd(0.166, 0.3), rnd(0.166, 0.2), 0.0, 0.0, 1.0, chance)
		end
	end
	
	local newestdir = VecNormalize(VecAdd(dir, VecScale(GetGravity(), 0.025)))
	if ignore ~= nil then QueryRejectAnimator(ignore) end
	local bigbloodhit, bigblooddist = QueryRaycast(pos, newestdir, 4)

	if bigbloodhit ~= 0 then
		local splatDist = bigblooddist
		if splatDist > 1 then splatDist = 1 end
		local chance = splatDist/1
		PaintRGBA(VecAdd(pos, VecScale(dir, bigblooddist)), 0.5, rnd(0.166, 0.2), 0.0, 0.0, 1.0, chance)
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
function ShootHook(pos, dir, shoottype, damage, playerdamage, range, player, weaponid, weaponname, impulseMult, radius)
	impulseMult = impulseMult or 1
	playerdamage = playerdamage or 0
	radius = radius or 0

	-- destroy ropes (only runs once!!)
	local ropeHit, ropeDist, ropeJoint = QueryRaycastRope(pos, dir, range)
	if ropeHit then
		local breakPoint = VecAdd(pos, VecScale(dir, ropeDist))
		BreakRope(ropeJoint, breakPoint)
	end
	
	-- figure out whether we need to run player or world hit code
	local bHit, pdist, pShape, playerhit = QueryShot(pos, dir, range, 0, player)

	if radius > 0 then
		QueryRequire("player")
		HULLbHit, HULLpdist, HULLpShape, HULLplayerhit, _, normal = QueryShot(pos, dir, range, radius, player)

		if HULLplayerhit ~= 0 then
			local hitPoint = VecAdd(pos, VecAdd(VecScale(dir, HULLpdist), VecScale(normal, -radius)))
			pdist = HULLpdist
			dir = VecNormalize(VecSub(hitPoint, pos))
			playerhit = HULLplayerhit
			bHit = true
		end
	end

	-- knock back objects some more
	if bHit then
		ApplyBodyImpulse(GetShapeBody(pShape), VecAdd(pos, VecScale(dir, pdist)), VecScale(dir, 800 * impulseMult))
	end

	local hitAnimator = GetBodyAnimator(GetShapeBody(pShape))

	if playerhit == 0 and hitAnimator == 0 then
		-- use normal shooting for world
		Shoot(pos, dir, shoottype, damage, range, player, weaponid)
	elseif playerdamage > 0 then
		-- play player impact SFX
		local SoundPoint = VecAdd(pos, VecScale(dir, pdist))
		PlaySound(LoadSound("MOD/snd/bullet_hit0.ogg"), SoundPoint, 2)

		-- don't actually hit the player so we can do our own damage and vfx
		local newrange = pdist - 0.5
		if newrange > 0 then Shoot(pos, dir, shoottype, 0.0, newrange, player, weaponid) end

		if playerhit ~= 0 then
			-- apply hitgroups
			QueryRequire("player")
			QueryInclude("player")
			QueryRejectPlayer(player)
			local _, _, _, bodyPart = QueryRaycast(pos, dir, pdist + 0.25)

			
			local hitPart = GetTagValue(GetShapeBody(bodyPart), "bone")
			if hitPart == "head" or hitPart == "neck" then
				playerdamage = playerdamage * GLOBAL_HEADSHOTMULT
			end

			-- Deal damage
			ApplyPlayerDamage(playerhit, playerdamage, weaponname, player)

			-- Blood VFX
			BloodVFX(SoundPoint, dir, playerdamage, playerhit)
		else
			-- Blood VFX
			BloodVFX(SoundPoint, dir, playerdamage, nil, hitAnimator)
		end
	end

	return bHit, pdist, playerhit
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