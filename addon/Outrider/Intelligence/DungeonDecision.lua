-- Intelligence/DungeonDecision.lua  (OI04-14)
-- Which dungeon, and why. Ranks the dungeons that fit your level from what
-- Outrider already knows, without assuming drops or a group:
--   quests      dungeon quests still to do (DungeonQuests), and how many must be
--               picked up before you go
--   gear        possible upgrades from its loot (DungeonGuide): a count and a
--               value, always "possible, not guaranteed"
--   readiness   how your level sits in its range (DungeonQuests.Fit)
--   group       a solo session (Horizon) puts it last with the reason; whether
--               you'll find a group is unknown and said so
--   reputation  no reputation data for dungeons yet: said so, not guessed
-- score = 0.4 quests + 0.4 gear + 0.2 readiness, each 0..1. Read only: the
-- existing Dungeons and Dungeon quests pages are unchanged; this adds a
-- section on top.

local _, ns = ...
local C = ns.Compat
local D = { W = { quests = 0.4, gear = 0.4, ready = 0.2 } }
ns.DungeonDecision = D

-- pure: rows = { {name, lo, hi, todo, pickups, gearCount, gearValue} }, level, solo
function D.Rank(rows, level, solo)
  local maxTodo, maxGear = 1, 1
  for _, r in ipairs(rows) do maxTodo = math.max(maxTodo, r.todo or 0) maxGear = math.max(maxGear, r.gearValue or 0) end
  local out = {}
  for _, r in ipairs(rows) do
    local mid = (r.lo + r.hi) / 2
    local ready = math.max(0, 1 - math.abs(level - mid) / math.max(1, (r.hi - r.lo) / 2 + 2))
    local q = (r.todo or 0) / maxTodo
    local g = (r.gearValue or 0) / maxGear
    local e = { name = r.name, score = D.W.quests * q + D.W.gear * g + D.W.ready * ready, lines = {} }
    e.lines[#e.lines + 1] = string.format("%d quest%s to do%s", r.todo or 0, (r.todo or 0) == 1 and "" or "s",
      (r.pickups or 0) > 0 and string.format(" (pick up %d before you go)", r.pickups) or "")
    e.lines[#e.lines + 1] = (r.gearCount or 0) > 0 and string.format("%d possible upgrade%s: possible, not guaranteed", r.gearCount, r.gearCount == 1 and "" or "s")
      or "no known upgrades in its loot"
    e.lines[#e.lines + 1] = string.format("levels %d-%d, you are %d", r.lo, r.hi, level)
    e.lines[#e.lines + 1] = "needs a group: whether you'll find one is unknown; reputation: no data"
    if solo then e.solo = true e.lines[#e.lines + 1] = "you chose a solo session" end
    out[#out + 1] = e
  end
  table.sort(out, function(a, b)
    if (a.solo and 1 or 0) ~= (b.solo and 1 or 0) then return not a.solo end
    if a.score ~= b.score then return a.score > b.score end
    return a.name < b.name
  end)
  return out
end

function D.Rows()
  local Q = ns.DungeonQuests
  if not (Q and Q.Chains) then return {}, 1 end
  local ctx = Q:Context()
  local level = ctx.level or tonumber(C.Readable(C.Call("UnitLevel", "player"))) or 1
  local gear = {}
  local G = ns.DungeonGuide
  if G and G.Rank then
    local ok, list = pcall(G.Rank, G)
    for _, r in ipairs(ok and type(list) == "table" and list or {}) do gear[r.name] = { count = r.count or 0, value = r.value or 0 } end
  end
  local rows = {}
  for _, d in ipairs(Q:Chains()) do
    if Q.Fit(d, level) == "ready" then
      local todo, pickups = 0, 0
      for _, s in ipairs(d.steps) do
        if Q:Status(s, ctx) == "todo" then todo = todo + 1 pickups = pickups + 1 end
      end
      local g = gear[d.name] or {}
      rows[#rows + 1] = { name = d.name, lo = d.lo, hi = d.hi, todo = todo, pickups = pickups, gearCount = g.count, gearValue = g.value }
    end
  end
  return rows, level
end

function D.Mine()
  local rows, level = D.Rows()
  local h = ns.NexusHorizon and ns.NexusCore and ns.NexusHorizon.Get(ns.NexusCore)
  return D.Rank(rows, level, h and h.group == "solo")
end

function D.Cards()
  local out = {}
  for i, e in ipairs(D.Mine()) do
    if i > 3 then break end
    out[#out + 1] = { pic = "Interface\\Icons\\INV_Misc_Key_14", title = e.name,
      tags = { { i == 1 and not e.solo and "best fit now" or ("#" .. i), i == 1 and not e.solo and "good" or "plain" } },
      line = table.concat(e.lines, ". ") .. "." }
  end
  return out
end
