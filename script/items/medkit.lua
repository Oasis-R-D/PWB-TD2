-- basic as[h] health pickup for gamemodes
#version 2


-- Per weapon constants
local WPNID = "hlmedkit"
local WPNNAME = "Medkit"
local HEAL_AMNT = 0.33

-- Per weapon data storer
MEDplayers = {}

function createPlayerSERVERdataMED()
    return {
		oldTool = "wrench",
	}
end

function server.initMED()
	medSound = LoadSound("MOD/snd/medkit.ogg")
	RegisterTool(WPNID, WPNNAME, "MOD/prefab/medkit.xml", 6)
	SetToolAmmoPickupAmount(WPNID, 1)
end

function server.tickMED(dt)
	for p in PlayersAdded() do
		MEDplayers[p] = createPlayerSERVERdataMED()
		SetToolEnabled(WPNID, false, p)
		SetToolAmmo(WPNID, 0, p)
	end

	for p in PlayersRemoved() do
		MEDplayers[p] = nil
	end

	for p in Players() do
		server.tickPlayerMED(p)
	end
end

function server.tickPlayerMED(p)
	local data = MEDplayers[p]

	if GetPlayerTool(p) ~= WPNID then
		data.oldTool = GetPlayerTool(p)
	end

	local ammo = GetToolAmmo(WPNID, p)

	if ammo >= 9999 then
		SetToolEnabled(WPNID, false, p)
		return
	end

	if ammo > 0 and GetPlayerHealth(p) < 1 then
		SetPlayerHealth(GetPlayerHealth(p) + HEAL_AMNT, p)
		SetToolEnabled(WPNID, true, p)
		SetToolAmmo(WPNID, ammo-1, p)
		PlaySound(medSound, GetPlayerPos(p), 0.75)
		if data.oldTool ~= nil then
			SetPlayerTool(data.oldTool, p)
		end
	elseif ammo == 0 then
		if data.oldTool ~= nil then
			SetPlayerTool(data.oldTool, p)
		end
		SetToolEnabled(WPNID, false, p)
	elseif ammo > 0 and GetPlayerHealth(p) >= 1 then
		SetToolAmmo(WPNID, 0, p)
		SetToolEnabled(WPNID, false, p)
		if data.oldTool ~= nil then
			SetPlayerTool(data.oldTool, p)
		end
	end
end