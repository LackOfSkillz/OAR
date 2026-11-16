-- Richer snapshots (P9-01): plain data, under 50 KB, everything the advisor needs.
local T, mock = ...

local function walk(v, path, bad)
  local t = type(v)
  if t == "table" then
    if getmetatable(v) then bad[#bad + 1] = path .. " has a metatable" end
    for k, x in pairs(v) do
      if type(k) ~= "string" and type(k) ~= "number" then bad[#bad + 1] = path .. " odd key" end
      walk(x, path .. "." .. tostring(k), bad)
    end
  elseif t ~= "string" and t ~= "number" and t ~= "boolean" then
    bad[#bad + 1] = path .. " is a " .. t
  end
end

T.describe("snapshot", function()
  T.it("collects quests and module parts as plain data under 50 KB", function()
    local game = mock.new()
    game.questLog = { { title = "Mulgore", isHeader = true },
      { title = "The Hunt Begins", questID = 747, level = 3 }, { title = "Rite of Strength", questID = 757, level = 4, complete = true } }
    local ns = game:loadAddon()
    game:login()
    game:slash("watch Mystmane")
    ns.Events:Fire("OTR_RARE_SEEN", { npcID = 259388, mapID = 2521, x = 0.6, y = 0.34, layer = 1, t = game.now })
    local s = ns.Snapshot:Collect()
    T.eq(#s.quests, 2)
    T.eq(s.quests[2].complete, true)
    T.same(s.modules.RareScan.watch, { "mystmane" })
    T.eq(s.modules.Sightings.recent[1].npcID, 259388)
    T.ok(s.modules.GearScore.role)
    T.ok(s.modules.Errands)
    local bad = {}
    walk(s, "snapshot", bad)
    T.eq(#bad, 0, table.concat(bad, "; "))
    T.ok(s.bytes < 50 * 1024)
    T.eq(#ns.Errors.list, 0, ns.Errors.list[1] and tostring(ns.Errors.list[1].msg or ns.Errors.list[1].message) or "")
  end)

  T.it("drops the biggest module part if the snapshot grows past the cap", function()
    local game = mock.new()
    local ns = game:loadAddon()
    game:login()
    ns.Snapshot.MAX_BYTES = 600
    local s = ns.Snapshot:Collect()
    T.ok(s.bytes <= 600 or next(s.modules) == nil)
    ns.Snapshot.MAX_BYTES = 50 * 1024
  end)

  T.it("the logout snapshot keeps map, gear and gold seen while playing", function()
    local game = mock.new({ money = 45678 })
    local ns = game:loadAddon()
    game:login()
    game.loggingOut = true   -- what the client reports during logout
    local s = ns.Snapshot:Collect()
    T.ok(s.where and s.where.mapID == 1412)
    T.ok(next(s.gear) ~= nil)
    T.eq(s.money, 45678)
    T.eq(#ns.Errors.list, 0)
  end)
end)
