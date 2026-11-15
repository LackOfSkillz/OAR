-- tools/whatnow_check.lua
-- Runs What now? (Pathfinder Lite) against a COPY of Gary's SavedVariables in
-- the fake client, for each character and goal, and prints the steps. Used to
-- judge the suggestions before asking Gary to look in game.
--   python tools/lua.py tools/whatnow_check.lua <copy of Outrider.lua> [Name-Realm] [goal]
-- Data addons in addon\ and private\ are loaded when present. The position is
-- the middle of the character's latest zone (the save keeps no coordinates).
package.path = "./tests/lib/?.lua;" .. package.path
local mock = require("wowmock")

local svPath, only, onlyGoal = arg[1], arg[2], arg[3]
if not svPath then io.write("usage: whatnow_check.lua <Outrider.lua copy> [Name-Realm] [goal]\n") os.exit(1) end
local f = assert(io.open(svPath, "rb"))
local text = f:read("*a")
f:close()

local peek = {}
local chunk = assert(loadstring(text))
setfenv(chunk, peek)
chunk()
local DB = peek.Outrider_DB or {}

local function exists(p) local h = io.open(p, "rb") if h then h:close() return true end return false end

-- data addons: { name, files }
local DATA = {}
for _, dir in ipairs({ "addon", "private" }) do
  for _, name in ipairs({ "Outrider_Data_NPC", "Outrider_Data_Gear", "Outrider_Data_Mobs", "Outrider_Data_Nodes",
    "Outrider_Data_Dungeons", "Outrider_Data_Words" }) do
    local toc = dir .. "/" .. name .. "/" .. name .. ".toc"
    if exists(toc) then
      local files = {}
      for line in io.lines(toc) do
        line = line:gsub("\r", "")
        if line ~= "" and not line:match("^#") then files[#files + 1] = dir .. "/" .. name .. "/" .. line:gsub("\\", "/") end
      end
      DATA[#DATA + 1] = { name = name, files = files }
    end
  end
end

local function latestZone(c)
  local best, at
  for mapID, v in pairs(c.zoneQuests or {}) do
    local t = type(v) == "table" and (v.at or v.t) or v
    if type(t) == "number" and (not at or t > at) then best, at = tonumber(mapID), t end
  end
  return best
end

local keys = {}
for k in pairs(DB.chars or {}) do if not only or k == only then keys[#keys + 1] = k end end
table.sort(keys)

for _, key in ipairs(keys) do
  local c = DB.chars[key]
  local m = c.meta or {}
  local name, realm = key:match("^([^-]+)%-(.+)$")
  local addons = {}
  for _, d in ipairs(DATA) do addons[#addons + 1] = d.name end
  local game = mock.new({ savedVariables = text, name = name, realm = realm, class = m.class, race = m.race,
    faction = m.faction, level = m.level, mapID = latestZone(c), x = 0.5, y = 0.5, addons = addons, ammo = 1000, now = os.time() })
  for _, d in ipairs(DATA) do
    for _, file in ipairs(d.files) do
      local ch = loadfile(file)
      if ch then setfenv(ch, game.env) pcall(ch, d.name, {}) end
    end
  end
  local ns = game:loadAddon()
  game:login()
  -- the fake client has no real map, so every trip looked like a minute:
  -- estimate 2 minutes inside the character's zone, 25 minutes elsewhere
  local here = latestZone(c)
  ns.Travel.TimeTo = function(_, _, p) if not p then return nil end return p.mapID == here and 120 or 1500 end
  io.write(string.format("\n=== %s  %s %s level %s, zone %s\n", key, tostring(m.race), tostring(m.class), tostring(m.level),
    tostring(latestZone(c))))
  for _, g in ipairs(ns.WhatNow.GOALS) do
    if not onlyGoal or g.id == onlyGoal then
      ns.WhatNow:SetGoal(g.id)
      local list = ns.WhatNow:List(true)
      io.write(string.format("-- goal %s (%s)%s\n", g.id, g.label,
        #ns.WhatNow.failed > 0 and ("  FAILED SOURCES: " .. table.concat(ns.WhatNow.failed, ",")) or ""))
      for i, s in ipairs(list) do
        io.write(string.format("  %d. [%s %.2f] %s\n     why: %s\n     where: %s\n", i, s.kind, s.score or 0, tostring(s.title),
          tostring(s.why), tostring(s.where)))
        if s.caveat then io.write("     note: ", s.caveat, "\n") end
        if s.alt then io.write("     or: ", tostring(s.alt.text), "\n") end
      end
    end
  end
  if #ns.Errors.list > 0 then
    io.write("ERRORS:\n")
    for _, e in ipairs(ns.Errors.list) do io.write("  ", tostring(e.message or e.msg or e[1]), "\n") end
  end
end
