#version 2

-- EXTERNAL CREDITS:
-- - VALVe (Half-Life: 1)
-- - GearBox Software (Half-Life: Opposing Force)
-- - Novena (radial spread code)

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

----------------------------------------------------------------------------------------------

#include "script/weapon_smg1.lua"
#include "script/weapon_ar2.lua"
#include "script/weapon_shotgun.lua"
#include "script/m40a1.lua"
#include "script/weapon_python.lua"
#include "script/weapon_pistol.lua"

-- MELEE
#include "script/melee/crowber.lua"

-- SPECIAL
-- NONE

-- ITEMS
#include "script/items/medkit.lua"
#include "script/items/grenade.lua"
#include "script/items/satchel.lua"
#include "script/items/tripmine.lua"

----------------------------------------------------------------------------------------------

-- this file calls all weapon functions. To add your weapon just add it's functions here (make sure to #include it's lua file).

-- to make a mod using this base, choose a weapon below to copy, then copy it's xml, vox and lua file (or you can make new ones completely)
-- in the .LUA file, replace all instances of the weapons name (suffix on the functions, some variables) and then add it's functions here
-- To remove unused/unwanted weapons, remove it's lua file, xml file(s), vox, sounds and then it's function calls and #include from this file

-- Weapon order in the HUD is set by the order they are called in the server.init()

----------------------------------------------------------------------------------------------

-- TO-DO: 
-- - Gluon gun circular beam
-- - Finish gluon gun and displacer model
-- - Displacer prongs
-- - displacer ball and other billboard sprites doesn't angle correctly when in vehicle camera
-- - make separate player data for server to reduce memory usage

----------------------------------------------------------------------------------------------

-- declare weapons, pickup amounts
function server.init()
   -- MELEE (SLOT 1)
   server.initCRBR()

   -- SLOT 3
   server.initMp5()
   server.initM727()
   server.initPYTH()
   server.initPIST9MM()
   server.initSG()

   -- SLOT 6
   server.initM40()

   -- SPECIALS (SLOT 6)

   -- ITEMS (SLOT 5/NONE)
   server.initMED()
   server.initFRAG()
   server.initSATCH()
   server.initTRIP()
end

function server.tick(dt)
   -- MELEE
   server.tickCRBR(dt)

   server.tickMp5(dt)
   server.tickM727(dt)
   server.tickM40(dt)
   server.tickPYTH(dt)
   server.tickPIST9MM(dt)
   server.tickSG(dt)

   -- SPECIALS

   -- ITEMS
   server.tickMED(dt)
   server.tickFRAG(dt)
   server.tickSATCH(dt)
   server.tickTRIP(dt)
end

-- load haptics 
function client.init()
   -- MELEE
   client.initCRBR()

   client.initMp5()
   client.initM727()
   client.initM40()
   client.initPYTH()
   client.initPIST9MM()
   client.initSG()

   -- SPECIALS

   -- ITEMS
   client.initFRAG()
   client.initSATCH()
   client.initTRIP()
end

function client.tick(dt)
   -- MELEE
   client.tickCRBR(dt)

   client.tickMp5(dt)
   client.tickM727(dt)
   client.tickM40(dt)
   client.tickPYTH(dt)
   client.tickPIST9MM(dt)
   client.tickSG(dt)

   -- SPECIALS

   -- ITEMS
   client.tickFRAG(dt)
   client.tickSATCH(dt)
   client.tickTRIP(dt)
end

-- Draw the magazine amount hud
function client.draw()
	if GetPlayerHealth() <= 0 or GetPlayerVehicle() ~= 0 then return end
   
	client.drawM40()
	client.drawPIST9MM()
	client.drawM727()
	client.drawMp5()
	client.drawPYTH()
	client.drawSG()
end