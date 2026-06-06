#version 2

-- EXTERNAL CREDITS:
-- - VALVe (Half-Life: 2)
-- - Novena (radial spread code)
-- - Verbatim Man (AR2 ball and crossbow bolt use code loosely based on his pellet launcher's code)

----------------------------------------------------------------------------------------------

GLOBAL_HEADSHOTMULT = 3.0 -- use actual value since guns do less damage in HL2DM

GLOBAL_1DEGREE = 0.00873
GLOBAL_2DEGREES = 0.01745
GLOBAL_3DEGREES = 0.02618
GLOBAL_4DEGREES = 0.03490
GLOBAL_5DEGREES = 0.04362
GLOBAL_6DEGREES = 0.05234
GLOBAL_7DEGREES = 0.06105
GLOBAL_8DEGREES = 0.06976
GLOBAL_9DEGREES = 0.07846
GLOBAL_10DEGREES = 0.08716
GLOBAL_15DEGREES = 0.13053
GLOBAL_20DEGREES = 0.17365

GLOBAL_WEAPONS = {
   "CRBR",
   "STNSTK",

   "SMG1",
   "AR2",
   "PYTH",
   "PIST9MM",
   "SG",

   "M40",

   "FRAG",
   "SLAM",
}

GLOBAL_WEAPONS_AMNT = #GLOBAL_WEAPONS -- only calculate this once

----------------------------------------------------------------------------------------------

#include "script/weapon_smg1.lua"
#include "script/weapon_ar2.lua"
#include "script/weapon_shotgun.lua"
#include "script/weapon_crossbow.lua"
#include "script/weapon_python.lua"
#include "script/weapon_pistol.lua"

-- MELEE
#include "script/melee/weapon_crowbar.lua"
#include "script/melee/weapon_stunstick.lua"

-- SPECIAL
-- NONE

-- ITEMS
#include "script/items/medkit.lua"
#include "script/items/weapon_grenade.lua"
#include "script/items/weapon_slam.lua"

server.weaponTicks = {}
client.weaponTicks = {}
----------------------------------------------------------------------------------------------

-- this file calls all weapon functions. To add your weapon just add it's functions here (make sure to #include it's lua file).

-- to make a mod using this base, choose a weapon to base your weapon off of, then copy it's xml, vox and lua file (or you can make new ones completely)
-- in the .LUA file, replace all instances of the weapons name (suffix on the functions, some variables) and then add it's suffix here in the weapons list above
-- To remove unused/unwanted weapons, remove it's lua file, xml file(s), vox, sounds and then it's name in the weapons list and also its #include from this file

-- Weapon order in the HUD is set by the order they are written in the weapons list

----------------------------------------------------------------------------------------------

-- TO-DO: 
-- - redo 357 model?
-- - grenade rolling

----------------------------------------------------------------------------------------------

-- declare weapons, pickup amounts
function server.init()
   for i = 1, GLOBAL_WEAPONS_AMNT do
      server["init" .. GLOBAL_WEAPONS[i]]()
      table.insert(server.weaponTicks, server["tick" .. GLOBAL_WEAPONS[i]]) 
   end

   -- only on server!
   server.initMED()
end

function server.tick(dt)
   for i = 1, GLOBAL_WEAPONS_AMNT do
      server.weaponTicks[i](dt)
   end
end

-- mostly to load haptics, amongst other things
function client.init()
   for i = 1, GLOBAL_WEAPONS_AMNT do
      client["init" .. GLOBAL_WEAPONS[i]]()
      table.insert(client.weaponTicks, client["tick" .. GLOBAL_WEAPONS[i]]) 
   end
end

function client.tick(dt)
   for i = 1, GLOBAL_WEAPONS_AMNT do
      client.weaponTicks[i](dt)
   end
end

-- Draw the magazine amount hud
-- too lazy to make this automated!!! (also not all weapons need UI)
function client.draw()
	if GetPlayerHealth() <= 0 or GetPlayerVehicle() ~= 0 then return end
   
	client.drawPIST9MM()
	client.drawAR2()
	client.drawSMG1()
	client.drawPYTH()
	client.drawSG()
end