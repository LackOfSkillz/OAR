-- tools/ask_demo.lua
-- The Outrider Intelligence route end to end without the game (AI02-08 prep):
--   snap  <copy of Outrider.lua> <Name-Realm> <out file>
--         /ride ask in the fake client with Gary's real saved data; writes the
--         snapshot code (what Ctrl+C would copy)
--   paste <copy of Outrider.lua> <Name-Realm> <advice code file>
--         same character and time, then Advisor > Paste advice; prints what the
--         Advisor tab would show
-- The companion runs in between: python -m outrider_companion.intelligence.ask
--   --snapshot <code file> --out <advice file> [--no-model]
package.path = "./tests/lib/?.lua;" .. package.path
local mock = require("wowmock")

local mode, svPath, key, file = arg[1], arg[2], arg[3], arg[4]
if not (mode and svPath and key and file) then
  io.write("usage: ask_demo.lua snap|paste <Outrider.lua copy> <Name-Realm> <file>\n") os.exit(1)
end
local f = assert(io.open(svPath, "rb")) local text = f:read("*a") f:close()
local peek = {} local ch = assert(loadstring(text)) setfenv(ch, peek) ch()
local c = peek.Outrider_DB.chars[key]
if not c then io.write("no character " .. key .. "\n") os.exit(1) end
local m = c.meta or {}
local name, realm = key:match("^([^-]+)%-(.+)$")
local zone
for mapID, v in pairs(c.zoneQuests or {}) do
  local t = type(v) == "table" and v.t or 0
  if not zone or t > zone[2] then zone = { tonumber(mapID), t } end
end
local NOW = 1794740000   -- fixed, so both runs bind to the same snapshot
local game = mock.new({ savedVariables = text, name = name, realm = realm, class = m.class, race = m.race,
  faction = m.faction, level = m.level, mapID = zone and zone[1], x = 0.5, y = 0.5, ammo = 1000, now = NOW })
for _, dir in ipairs({ "addon", "private" }) do
  for _, pack in ipairs({ "Outrider_Data_NPC", "Outrider_Data_Gear", "Outrider_Data_Dungeons", "Outrider_Data_Nodes" }) do
    local p = dir .. "/" .. pack .. "/Data.lua"
    local h = io.open(p, "rb")
    if h then h:close() local d = loadfile(p) if d then setfenv(d, game.env) pcall(d, pack, {}) end end
  end
end
local ns = game:loadAddon()
game:login()
local here = zone and zone[1]
ns.Travel.TimeTo = function(_, _, p) if not p then return nil end return p.mapID == here and 120 or 1500 end
ns.Snapshot:Collect(true)
if mode == "snap" then
  local out = assert(io.open(file, "wb"))
  out:write(ns.Snapshot:Code())
  out:close()
  local s = Outrider_Snapshots and Outrider_Snapshots[ns.db.key] or game.env.Outrider_Snapshots[ns.db.key]
  local n = s.modules.WhatNow and #s.modules.WhatNow.candidates or 0
  io.write(string.format("snapshot for %s (%s %s %s): %d candidates, id %s -> %s\n", key, tostring(m.race),
    tostring(m.class), tostring(m.level), n, tostring(s.snapshotId), file))
else
  local h = assert(io.open(file, "rb")) local code = h:read("*a") h:close()
  local n, why = ns.Advice:Paste(code)
  io.write(string.format("pasted: %d cards (%s)\n", n, tostring(why)))
  local items, _, answer = ns.Advice:Load()
  if answer then
    io.write("  " .. tostring(answer.headline) .. "\n  " .. tostring(answer.summary) .. "\n")
    for _, l in ipairs(answer.limits or {}) do io.write("  not checked: " .. l .. "\n") end
  end
  for i, it in ipairs(items) do
    local a = it.args or {}
    io.write(string.format("  %d. %s [%s %s] %s\n", i, it.title, it.action,
      it.action == "waypoint" and string.format("%s %.3f %.3f", a.mapID, a.x, a.y) or tostring(a.panel or a.itemID or ""),
      it.confidence))
  end
  io.write(string.format("errors: %d\n", #ns.Errors.list))
end
