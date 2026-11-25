-- Intelligence/Foresight.lua  (OI04-10; quiet presentation OI04-15)
-- What's coming up soon that is worth knowing now: a trainer visit, quests
-- that open at your next levels, riding at 40, materials your craft queue
-- needs, a dungeon about to open for you, an upgrade an alt is holding.
-- Facts come from what Outrider already knows (Errands, NPCPack, DungeonGuide,
-- the levelling facts, CraftQueue, Handoffs, your XP pace, the planner's
-- route). A trigger is raised only when its key facts are known; otherwise it
-- is withheld with the reason ("unknown facts are not alerts"). Nothing here
-- accepts a quest, buys, trains or acts: these are notes for you.
--
-- Evaluate(facts) is pure: facts = { level, etaMinutes = { [level] = min },
--   routeMaps = { [mapID] = true }, trainer = { level, mapID, trip },
--   questsAt = { [level] = n }, riding = { level, cost }, copper, reserve,
--   shopping = n, dungeonsSoon = { {name, levels} }, altUpgrades = { {holder, name} } }
-- Each trigger: { id, kind, title, why, importance 0..1, onRoute, saving }.

local _, ns = ...
local C = ns.Compat
local F = { SOON_MINUTES = 60, RIDING_FROM = 4 }
ns.Foresight = F

local function minutesText(m) return m < 60 and (math.floor(m + 0.5) .. " min") or string.format("%.1f h", m / 60) end

function F.Evaluate(f)
  local out, withheld = {}, {}
  local function add(t) out[#out + 1] = t end
  local function hold(id, why) withheld[#withheld + 1] = { id = id, why = why } end
  local eta = f.etaMinutes or {}
  -- trainer
  if f.trainer and f.trainer.level then
    local m = eta[f.trainer.level]
    if not m then hold("trainer", "when you'll reach level " .. f.trainer.level .. " is unknown")
    elseif m <= F.SOON_MINUTES then
      local on = f.trainer.mapID and f.routeMaps and f.routeMaps[f.trainer.mapID]
      add({ id = "trainer:" .. f.trainer.level, kind = "trainer", importance = on and 0.75 or 0.6, onRoute = on or nil,
        saving = on and f.trainer.trip or nil,
        title = string.format("New spells at level %d (about %s away)", f.trainer.level, minutesText(m)),
        why = on and string.format("Your trainer is on your way: training then saves a separate trip of about %s.", minutesText((f.trainer.trip or 0) / 60))
          or "New ranks make every fight faster." })
    end
  end
  -- quests opening at the next levels
  for lvl, n in pairs(f.questsAt or {}) do
    local m = eta[lvl]
    if n > 0 and m and m <= F.SOON_MINUTES then
      add({ id = "quests:" .. lvl, kind = "quest", importance = math.min(0.7, 0.4 + n * 0.05),
        title = string.format("%d quest%s open at level %d", n, n == 1 and "" or "s", lvl),
        why = string.format("About %s away at your pace.", minutesText(m)) })
    elseif n > 0 and not m then hold("quests:" .. lvl, "when you'll reach level " .. lvl .. " is unknown") end
  end
  -- riding
  local r = f.riding
  if r and f.level and f.level < r.level and r.level - f.level <= F.RIDING_FROM then
    if not (r.cost and f.copper) then hold("riding", "the riding cost or your gold is unknown")
    else
      local have = f.copper - (f.reserve or 0)
      local short = r.cost - have
      add({ id = "riding:" .. r.level, kind = "mount", importance = short > 0 and 0.7 or 0.4,
        title = short > 0 and string.format("Riding at %d: you're %s short", r.level, ns.Prices and ns.Prices.Money(short) or tostring(short))
          or string.format("Riding at %d: you have enough", r.level),
        why = string.format("Apprentice Riding costs %s (levelling guides).", ns.Prices and ns.Prices.Money(r.cost) or tostring(r.cost)) })
    end
  end
  -- materials
  if (f.shopping or 0) > 0 then
    add({ id = "materials", kind = "material", importance = 0.5,
      title = string.format("Your craft queue needs %d item%s", f.shopping, f.shopping == 1 and "" or "s"),
      why = "Pick them up while you pass a vendor or the auction house." })
  end
  -- dungeons
  for _, d in ipairs(f.dungeonsSoon or {}) do
    add({ id = "dungeon:" .. tostring(d.name), kind = "dungeon", importance = 0.5,
      title = string.format("%s opens for you in %d level%s", tostring(d.name), d.levels, d.levels == 1 and "" or "s"),
      why = "Pick up its quests before you go (Dungeons page)." })
  end
  -- alts
  for _, a in ipairs(f.altUpgrades or {}) do
    add({ id = "alt:" .. tostring(a.holder) .. ":" .. tostring(a.name), kind = "alt", importance = 0.5,
      title = string.format("%s holds an upgrade for you: %s", tostring(a.holder):match("^[^%-]+") or "an alt", tostring(a.name)),
      why = "Mail it over next time you're on that character." })
  end
  table.sort(out, function(a, b) if a.importance ~= b.importance then return a.importance > b.importance end return a.id < b.id end)
  return out, withheld
end

-- ------------------------------------------------------------ live facts
function F.Facts()
  local f = { routeMaps = {} }
  f.level = tonumber(C.Readable(C.Call("UnitLevel", "player"))) or 1
  local maxXP = tonumber(C.Readable(C.Call("UnitXPMax", "player")))
  local xp = tonumber(C.Readable(C.Call("UnitXP", "player")))
  local pace = ns.GearROI and ns.GearROI.Pace(ns.SessionXP and ns.SessionXP.Merged and ns.SessionXP:Merged() or {}, maxXP)
  f.etaMinutes = {}
  if pace and pace > 0 and maxXP and xp then
    local toNext = (maxXP - xp) / maxXP
    for k = 1, 6 do f.etaMinutes[f.level + k] = (toNext + (k - 1)) / pace * 60 end
  end
  local N = ns.NexusCore
  local cur = N and N.current
  for _, id in ipairs(cur and cur.result and cur.result.plan and cur.result.plan.steps or {}) do
    local node = cur.graph.nodes[id]
    if node and node.meta.mapID then f.routeMaps[node.meta.mapID] = true end
  end
  local nextTrain = f.level % 2 == 0 and f.level + 2 or f.level + 1
  f.trainer = { level = nextTrain }
  if ns.Nearest and ns.Nearest.Find then
    local ok, p, yards = pcall(ns.Nearest.Find, ns.Nearest, "class_trainer")
    if ok and p then f.trainer.mapID, f.trainer.trip = p.mapID, tonumber(yards) and yards / 7 or nil end
  end
  f.questsAt = {}
  local NP = ns.NPCPack
  if NP and NP.ZoneReport then
    local map = tonumber(C.Readable(C.PlayerPosition("player")))
    local ok, rep = pcall(NP.ZoneReport, NP, map, true)
    for _, q in ipairs(ok and type(rep) == "table" and rep.locked or {}) do
      local lvl = tonumber(tostring(q.why or ""):match("^level (%d+)$"))
      if lvl then f.questsAt[lvl] = (f.questsAt[lvl] or 0) + 1 end
    end
  end
  for _, fact in ipairs(ns.Leveling and ns.Leveling.FACTS or {}) do
    if fact.id == "riding-apprentice" then
      local g = tonumber(tostring(fact.text):match("for (%d+) gold"))
      f.riding = { level = fact.minLevel, cost = g and g * 10000 or nil }
    end
  end
  f.copper = tonumber(C.Readable(C.Call("GetMoney")))
  for _, g in ipairs(ns.NexusGoals and ns.NexusGoals:Active() or {}) do f.reserve = math.max(f.reserve or 0, g.reserveCopper or 0) end
  local CQ = ns.Modules:Get("CraftQueue")
  if CQ and CQ.enabled and CQ.Shopping then
    local ok, list = pcall(CQ.Shopping, CQ)
    if ok and type(list) == "table" then f.shopping = #list end
  end
  f.dungeonsSoon = {}
  local DG = ns.DungeonGuide
  if DG and DG.Rank then
    local ok, list = pcall(DG.Rank, DG)
    for _, d in ipairs(ok and type(list) == "table" and list or {}) do
      local min = d.info and tonumber(d.info.min)
      if d.status == "soon" and min then f.dungeonsSoon[#f.dungeonsSoon + 1] = { name = d.name, levels = math.max(1, min - f.level) } end
    end
  end
  f.altUpgrades = {}
  local H = ns.Modules:Get("Handoffs")
  if H and H.enabled and H.Find then
    local ok, list = pcall(H.Find, H)
    for i, h in ipairs(ok and type(list) == "table" and list or {}) do
      if i > 2 then break end
      f.altUpgrades[#f.altUpgrades + 1] = { holder = h.holder, name = h.name }
    end
  end
  return f
end
