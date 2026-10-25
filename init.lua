-- Copyright (C) 2026 Hari Prasadh
-- License: GPL-3.0-or-later (see LICENSE)

-- nv_relight: standalone cave ambient light for Luanti / Mineclonia.
-- 1) Gives every registered node a minimum light_source (setting nv_relight.level).
-- 2) Relights map blocks generated before the setting changed (the engine does not do this itself).
-- 3) /nvdiag prints what the server sees around you.
-- It changes light data only. It never touches nodes, items or inventories.
-- Do NOT run it together with k_ambient_light.

local S = core.settings
local storage = core.get_mod_storage()

local function clamp_level(v)
	return math.floor(math.max(0, math.min(tonumber(v) or 0, 14)))
end
local LEVEL = clamp_level(S:get("nv_relight.level") or 8)
local SPAWN_SAFE = S:get_bool("nv_relight.spawn_safe", true)

if core.get_modpath("k_ambient_light") then
	core.log("warning", "[nv_relight] k_ambient_light is also enabled. Disable it; nv_relight does the same job.")
end

-- 1) Ambient glow ---------------------------------------------------------
local protected = {air = true, ignore = true, unknown = true} -- keep sky/sunlight intact
local originals = {} -- node name -> light_source it had before this mod touched it
local current = 0    -- level currently applied to the node definitions

local function apply_level(level)
	for name, def in pairs(core.registered_nodes) do
		if name:match(".+:.+") and not protected[name] then
			if originals[name] == nil then originals[name] = def.light_source or 0 end
			local want = math.max(originals[name], level)
			if (def.light_source or 0) ~= want then
				core.override_item(name, {light_source = want})
			end
		end
	end
	current = level
end

core.register_on_mods_loaded(function()
	if LEVEL > 0 then apply_level(LEVEL) end
end)

-- 1b) Spawn-safe light ----------------------------------------------------
-- Games such as Mineclonia only let hostile mobs spawn where artificial light is 0
-- (they call core.get_artificial_light). The ambient glow would block all of that.
-- Air next to a surface gets at most LEVEL-1 from the glow, so we report any
-- artificial light value up to LEVEL-1 as 0 to game logic. The screen still shows
-- the real stored light. Real light sources (torches etc.) stay above that and
-- still count, but protect a smaller radius: 15 - LEVEL nodes for a level-14 source.
local orig_get_artificial_light = core.get_artificial_light
local spawn_safe_active = false
if SPAWN_SAFE and orig_get_artificial_light then
	core.get_artificial_light = function(param1)
		local l = orig_get_artificial_light(param1)
		if l and current > 0 and l <= current - 1 then return 0 end
		return l
	end
	spawn_safe_active = true
end

-- 2) Relight once per area, again whenever the level changes ----------------
if storage:get_string("sig") ~= tostring(LEVEL) then
	storage:from_table({fields = {sig = tostring(LEVEL)}})
end

local function block_of(pos)
	local p = vector.round(pos)
	return {x = math.floor(p.x / 16), y = math.floor(p.y / 16), z = math.floor(p.z / 16)}
end
local function key_of(b) return "b" .. core.hash_node_position(b) end

local function relight_around(pos)
	local b = block_of(pos)
	if storage:get_string(key_of(b)) ~= "" then return false end
	local minp = vector.multiply(vector.subtract(b, 1), 16)
	local maxp = vector.add(vector.multiply(vector.add(b, 2), 16), -1)
	core.fix_light(minp, maxp)
	for dx = -1, 1 do for dy = -1, 1 do for dz = -1, 1 do
		storage:set_string(key_of(vector.add(b, {x = dx, y = dy, z = dz})), "1")
	end end end
	return true
end

local timer = 0
core.register_globalstep(function(dtime)
	timer = timer + dtime
	if timer < 1 then return end
	timer = 0
	for _, player in ipairs(core.get_connected_players()) do
		if relight_around(player:get_pos()) then return end -- max one relight per second
	end
end)

-- 3) Diagnostics ------------------------------------------------------------
local function diag(pos)
	local p = vector.round(pos)
	local function nl(q) return tostring(core.get_node_light(q, 0)) end
	local below = core.get_node({x = p.x, y = p.y - 1, z = p.z}).name
	local def = core.registered_nodes[below]
	local here = core.get_node(p)
	local raw = orig_get_artificial_light and orig_get_artificial_light(here.param1)
	local seen = core.get_artificial_light and core.get_artificial_light(here.param1)
	return {
		"Luanti " .. core.get_version().string,
		"nv_relight.level (active): " .. LEVEL,
		"spawn-safe light active: " .. tostring(spawn_safe_active),
		"artificial light at feet: real=" .. tostring(raw) .. ", seen by game logic=" .. tostring(seen),
		"k_ambient_light also loaded: " .. tostring(core.get_modpath("k_ambient_light") ~= nil),
		"node below you: " .. below .. " light_source=" .. tostring(def and def.light_source),
		"stored light (no sunlight) at feet/above/N/S/E/W: " .. table.concat({
			nl(p), nl({x = p.x, y = p.y + 1, z = p.z}),
			nl({x = p.x, y = p.y, z = p.z + 1}), nl({x = p.x, y = p.y, z = p.z - 1}),
			nl({x = p.x + 1, y = p.y, z = p.z}), nl({x = p.x - 1, y = p.y, z = p.z}),
		}, ", "),
		"this block already relit: " .. tostring(storage:get_string(key_of(block_of(p))) ~= ""),
	}
end

core.register_chatcommand("nvdiag", {
	description = "Show lighting diagnostics at your position",
	func = function(name)
		local player = core.get_player_by_name(name)
		if not player then return false, "Player not found" end
		return true, table.concat(diag(player:get_pos()), "\n")
	end,
})

local function set_level(n, player_name)
	LEVEL = n
	apply_level(n)
	S:set("nv_relight.level", tostring(n))
	S:write()
	storage:from_table({fields = {sig = tostring(n)}}) -- forget which blocks were relit
	local player = player_name and core.get_player_by_name(player_name)
	if player then relight_around(player:get_pos()) end
end

core.register_chatcommand("nvlevel", {
	params = "[0-14]",
	description = "Show or change the ambient light level (0 = off)",
	func = function(name, param)
		param = param:trim()
		if param == "" then
			return true, "nv_relight level: " .. LEVEL .. " (use /nvlevel <0-14> to change)"
		end
		if not (core.is_singleplayer() or core.check_player_privs(name, {server = true})) then
			return false, "You need the 'server' privilege."
		end
		local n = tonumber(param)
		if not n or n ~= math.floor(n) or n < 0 or n > 14 then
			return false, "Usage: /nvlevel <0-14>"
		end
		set_level(n, name)
		return true, ("Level set to %d and saved. Relit around you; other areas update as you reach them."):format(n)
	end,
})

nv_relight = {relight_around = relight_around, diag = diag, set_level = set_level}
