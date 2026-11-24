-- Modules/WhatNow.lua
-- Pathfinder Lite: "What now?" (requirement 2026-11-14). Not a new routing
-- engine: a decision layer over what Outrider already knows. It gathers
-- candidates from other modules (errands, quests, gear, dungeons, training,
-- rares, gold, gathering), scores them by benefit, the player's goal, how
-- far away they are and how sure the data is, and shows the 3 to 5 worth
-- doing next. Each one says what to do, why, where, offers a Go button and,
-- when there is one, an alternative.
-- Deterministic rules only (no AI). Uncertain data is said to be uncertain.
-- Nothing here casts, targets or buys: Go sets a waypoint or opens a page.

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("WhatNow", {
  title = "What now? (next steps for this character)",
  phase = "P9",
  order = 5,
  defaults = { goal = "mix" },
})
ns.WhatNow = M

M.MAX, M.MIN, M.PER_KIND = 5, 3, 2
M.CACHE = 30          -- seconds a list stays fresh
M.SKIP_FOR = 86400    -- "Not useful" hides a step this long
M.NEAR_BONUS = 1.15   -- steps in the same zone as the top step

M.GOALS = {
  { id = "level", label = "Level up" },
  { id = "gold", label = "Make gold" },
  { id = "gear", label = "Better gear" },
  { id = "professions", label = "Professions" },
  { id = "explore", label = "Explore" },
  { id = "mix", label = "A bit of everything" },
}

-- how much each kind of step counts for each goal
M.WEIGHTS = {
  level       = { quest = 1.0, dungeon = 0.8, errand = 0.7, gear = 0.6, profession = 0.3, rare = 0.3, gold = 0.3, gather = 0.2, tip = 0.6 },
  gold        = { gold = 1.0, gather = 0.8, errand = 0.7, profession = 0.6, quest = 0.4, gear = 0.3, dungeon = 0.3, rare = 0.3, tip = 0.3 },
  gear        = { gear = 1.0, dungeon = 1.0, quest = 0.6, errand = 0.6, rare = 0.4, gold = 0.3, profession = 0.3, gather = 0.2, tip = 0.3 },
  professions = { profession = 1.0, gather = 0.9, gold = 0.5, errand = 0.5, quest = 0.3, gear = 0.3, dungeon = 0.2, rare = 0.2, tip = 0.4 },
  explore     = { rare = 1.0, quest = 0.7, dungeon = 0.6, gather = 0.5, errand = 0.5, gear = 0.4, profession = 0.2, gold = 0.2, tip = 0.5 },
  mix         = { quest = 0.8, gear = 0.8, dungeon = 0.7, profession = 0.7, errand = 0.8, rare = 0.6, gold = 0.6, gather = 0.5, tip = 0.5 },
}

local function clamp(v) return math.max(0, math.min(1, v or 0)) end

-- Score: benefit x goal weight x confidence, less for far-away steps.
-- Urgent steps (gear about to break, out of ammo) always come first.
function M.Score(c, goal)
  local w = (M.WEIGHTS[goal] or M.WEIGHTS.mix)[c.kind] or 0.5
  local minutes = (c.seconds or 0) / 60
  local s = clamp(c.benefit) * w * clamp(c.confidence or 1) / (1 + minutes / 15)
  if c.urgent then s = s + 10 end
  return s
end

-- Pick up to MAX (at least MIN when there are enough), at most PER_KIND of a
-- kind; the best one left over of the same kind becomes the alternative.
function M.Pick(cands, goal, skip, now)
  now = now or time()
  local list = {}
  for _, src in ipairs(cands) do
    local hidden = skip and skip[src.key] and now - skip[src.key] < M.SKIP_FOR
    if not hidden and (src.benefit or 0) > 0 then
      -- a copy: the same candidates are picked once per goal for the log,
      -- and one goal's score or alternative must not leak into the next
      local c = {}
      for k, v in pairs(src) do c[k] = v end
      c.score = M.Score(c, goal)
      list[#list + 1] = c
    end
  end
  local function order(a, b)
    if a.score ~= b.score then return a.score > b.score end
    return tostring(a.key) < tostring(b.key)
  end
  table.sort(list, order)
  -- a little route-planning: once the top step is known, steps in the same
  -- zone count 15% more ("while you're there")
  local top = list[1]
  if top and top.mapID then
    for i = 2, #list do
      local c = list[i]
      if c.mapID == top.mapID then c.score = c.score * M.NEAR_BONUS c.near = true end
    end
    local rest = {}
    for i = 2, #list do rest[#rest + 1] = list[i] end
    table.sort(rest, order)
    list = { top }
    for _, c in ipairs(rest) do list[#list + 1] = c end
  end
  local out, per, used = {}, {}, {}
  for _, c in ipairs(list) do
    if #out >= M.MAX then break end
    if (per[c.kind] or 0) < M.PER_KIND then
      out[#out + 1] = c
      per[c.kind] = (per[c.kind] or 0) + 1
      used[c] = true
    end
  end
  -- fewer than MIN because of the per-kind cap: let more of a kind in
  for _, c in ipairs(list) do
    if #out >= M.MIN then break end
    if not used[c] then out[#out + 1] = c used[c] = true end
  end
  for _, c in ipairs(out) do
    if not c.alt then
      for _, o in ipairs(list) do
        if not used[o] and o.kind == c.kind then c.alt = { text = o.title, go = o.go } used[o] = true break end
      end
    end
  end
  return out
end

-- ------------------------------------------------------------ sources
-- Each returns candidates { key, kind, title, why, where, benefit 0..1,
-- confidence 0..1, seconds, urgent, caveat, go, alt }. Any source can be
-- missing or fail: it is skipped (fail soft).
local function zone(mapID) return mapID and ns.Travel and ns.Travel.ZoneName(mapID) or "?" end
local function minutes(sec) return sec and ns.Travel and ns.Travel.Minutes(sec) or nil end
local function hub(tab) return function() local f = ns.Hub:Build() f:Show() ns.Hub:ShowTab(tab) end end
local function wp(mapID, x, y, title)
  return function() if mapID and x and y then return ns.Waypoints:Set(mapID, x, y, title) end end
end

local SOURCES = {}
M.SOURCES = SOURCES

local ERRAND_WHERE = { repair = "any repair vendor", vendor = "any vendor", ammo = "an ammo vendor",
  trainer = "your class trainer", auction = "the auction house" }
SOURCES.errands = function()
  if not ns.Errands then return {} end
  local out = {}
  local d = ns.Errands.Durability()
  local ammo = ns.Modules:Get("Ammo")
  for _, e in ipairs(ns.Errands:List()) do
    local c = { key = "errand:" .. e.kind, kind = "errand", title = e.text, benefit = 0.4, confidence = 1, label = "observed",
      where = ERRAND_WHERE[e.kind], go = function() return ns.Errands:Go(e) end }
    if e.kind == "repair" then
      c.benefit = clamp(1 - (d or 1) / 0.35) + 0.3
      c.urgent = d and d < 0.1
      c.why = c.urgent and "Your gear is about to break: broken gear gives no stats." or "Repairs are cheaper before anything breaks."
    elseif e.kind == "ammo" then
      local n = ammo and ammo:Count()
      c.urgent = n and n < ammo:Settings().critical
      c.benefit = c.urgent and 1 or 0.6
      c.why = "Hunters can't Auto Shot without ammo."
    elseif e.kind == "trainer" then
      c.benefit = 0.7
      c.why = "New ranks and spells make every fight faster."
    elseif e.kind == "vendor" then
      c.benefit = 0.35
      c.why = "Frees bag space and turns junk into gold."
    else
      c.why = "Gets you what your crafting list is missing."
    end
    if ns.Nearest then
      local poi, yards = ns.Nearest:Find(e.kind == "trainer" and "class_trainer" or e.kind)
      if poi then
        c.where = (poi.name or c.where) .. (yards and string.format(" (%d yards)", yards) or "")
        c.seconds = yards and yards / 7 or nil
        c.mapID = poi.mapID
        c.target = poi.x and poi.y and { mapID = poi.mapID, x = poi.x, y = poi.y } or nil
      else
        c.alt = { text = "No " .. (ERRAND_WHERE[e.kind] or e.kind) .. " known nearby yet: the closest town will have one." }
      end
    end
    out[#out + 1] = c
  end
  return out
end

SOURCES.quests = function()
  if not (ns.Journey and ns.NPCPack) then return {} end
  local list = ns.Journey:XPList()
  local best = list[1] and list[1].rate or 0
  local out = {}
  -- orange quests (3-4 levels up) give the most XP per minute but are hard
  -- fights solo, so they count for less; battleground quests are left out
  for _, e in ipairs(list) do
    if not M.PVP(e.name, e.giver) then
      local hard = e.diff == "orange"
      local benefit = best > 0 and 0.4 + 0.5 * (e.rate or 0) / best or 0.5
      if hard then benefit = benefit * 0.55 end
      out[#out + 1] = { key = "quest:" .. tostring(e.name), kind = "quest",
        title = string.format("Pick up %s [%d]", tostring(e.name), e.level or 0),
        why = string.format("About %d XP, %d XP a minute counting the trip.%s", e.xp or 0, math.floor((e.rate or 0) + 0.5),
          hard and " Several levels above you: expect hard fights." or ""),
        where = string.format("%s, %s, %s away", tostring(e.giver or "quest giver"), zone(e.mapID), minutes(e.seconds) or "?"),
        benefit = benefit, confidence = 0.6, seconds = e.seconds, mapID = e.mapID, label = "community",
        -- Journey uses a Classic-level formula and fixed five-minute task
        -- estimate. These are NOT observed quest XP or completion times.
        questID = e.questID, estimatedQuestXP = e.xp, estimatedTripSeconds = e.seconds,
        estimatedActivitySeconds = ns.Journey.QUEST_TIME, estimateBasis = "journey_community",
        target = e.target and not e.target.approx and { mapID = e.target.mapID, x = e.target.x, y = e.target.y } or nil,
        caveat = "Quest spots come from Classic data and may have moved on Forever.",
        go = function() return ns.Journey:Go(e) end }
    end
  end
  -- keep the 8 best after the hard-fight discount
  table.sort(out, function(x, y) if x.benefit ~= y.benefit then return x.benefit > y.benefit end return x.key < y.key end)
  for i = #out, 9, -1 do out[i] = nil end
  -- Forever redrew some zones (Coldridge Valley came out with one quest, from a
  -- chicken): when the data knows fewer than 3 here, say so instead of sending
  -- the player across the world
  local here = C.PlayerPosition("player")
  local local_ = 0
  for _, e in ipairs(list) do if e.mapID == here and not M.PVP(e.name, e.giver) then local_ = local_ + 1 end end
  -- quests the data knows here at all (done, in the log, locked behind a
  -- chain): the Skyborne start zone has 98, 97 of them behind Coming of Age
  local known = local_
  local rep = here and ns.NPCPack.ZoneReport and M.Safe(ns.NPCPack.ZoneReport, ns.NPCPack, here, true)
  if type(rep) == "table" then
    known = #(rep.available or {}) + #(rep.locked or {}) + #(rep.active or {}) + (tonumber(rep.done) or 0)
  end
  if here and local_ < 3 and known < 5 then
    out[#out + 1] = { key = "quest:look-around", kind = "quest", title = "Look for quest givers (!) around you",
      why = string.format("Outrider knows only %d quest%s in %s; Forever added and moved many.", local_, local_ == 1 and "" or "s", zone(here)),
      where = "nearby: check the minimap for ! marks", benefit = 0.7, confidence = 1, seconds = 60 }
  end
  return out
end

-- Battleground quests need a battleground, not a walk to the giver; holiday
-- quests (Winter's Presents for a level 1 Dwarf) only run during their event.
local PVP_WORDS = { "warsong gulch", "arathi basin", "alterac valley", "battleground", "warbringer", "brigadier general",
  "winter's presents", "winter veil", "new year", "wonderform operator", "hallow's end", "midsummer", "brewfest",
  "lunar festival", "love is in the air", "noblegarden", "children's week", "harvest festival", "pilgrim's bounty" }
function M.PVP(name, giver)
  local t = (tostring(name) .. " " .. tostring(giver)):lower()
  for _, w in ipairs(PVP_WORDS) do if t:find(w, 1, true) then return true end end
  return false
end

-- one step per equipment slot: a second item for the same slot (Polished and
-- Worn Shortbow) becomes that step's alternative
local function slotOf(itemID)
  if not itemID then return nil end
  local _, _, _, loc = C.Call("C_Item.GetItemInfoInstant", itemID)
  if loc == "INVTYPE_ROBE" then loc = "INVTYPE_CHEST" end
  if loc == "INVTYPE_RANGEDRIGHT" or loc == "INVTYPE_THROWN" then loc = "INVTYPE_RANGED" end
  return loc
end

SOURCES.gear = function()
  if not (ns.Journey and ns.Nearby) then return {} end
  local out, bySlot = {}, {}
  for _, e in ipairs(ns.Journey:GearList()) do
    local slot = slotOf(e.itemID) or ("item" .. tostring(e.name))
    local c = { key = "gear:" .. tostring(e.name), kind = "gear",
      title = "Get " .. tostring(e.name),
      why = string.format("A %d%% upgrade for you.", math.floor((e.pct or 0) + 0.5)),
      where = string.format("%s, %s away%s", zone(e.mapID), minutes(e.seconds) or "?", e.note and (" (" .. e.note .. ")") or ""),
      benefit = clamp((e.pct or 0) / 30), confidence = 0.7, seconds = e.seconds, mapID = e.mapID, label = "community",
      itemID = e.itemID, panel = "gear",
      target = e.target and not e.target.approx and { mapID = e.target.mapID, x = e.target.x, y = e.target.y } or nil,
      caveat = "Where it drops or sells comes from Classic data.",
      go = function() return ns.Journey:Go(e) end }
    local first = bySlot[slot]
    if not first then
      bySlot[slot] = c
      out[#out + 1] = c
    elseif not first.alt then
      first.alt = { text = c.title .. " (" .. c.where .. ")", go = c.go }
    end
    if #out >= 3 then break end
  end
  return out
end

SOURCES.dungeons = function()
  local G = ns.DungeonGuide
  if not (G and G:Pack()) then return {} end
  local out = {}
  -- the trip counts (the Deadmines from Zephras Isle is a long way: it had no
  -- time and outranked nearby quests, 2026-11-15), and a group has to be found
  local prep = ns.Travel and M.Safe(ns.Travel.Prepare, ns.Travel)
  for _, r in ipairs(G:Rank()) do
    if r.status == "ready" and (r.count or 0) > 0 then
      local secs, routeNote = nil, ""
      if prep and r.map and r.x and r.y then
        local pt = ns.Travel.Point(r.map, r.x, r.y, r.name)
        secs = pt and M.Safe(ns.Travel.TimeTo, ns.Travel, prep, pt)
      end
      if not secs then secs, routeNote = 3600, ", no known route" end
      out[#out + 1] = { key = "dungeon:" .. r.name, kind = "dungeon", title = "Run " .. r.name,
        why = string.format("%d upgrade%s for you. %s", r.count, r.count == 1 and "" or "s", M.Safe(G.UpgradeLine, r.ups, 2) or ""),
        where = zone(r.map) .. " (needs a group" .. routeNote .. ")", seconds = secs, mapID = r.map, label = "community",
        target = r.map and r.x and r.y and { mapID = r.map, x = r.x, y = r.y } or nil,
        benefit = (clamp((r.value or 0) / 60) * 0.9 + 0.1) * 0.75, confidence = 0.6,
        caveat = "Loot lists come from Classic data; Forever may differ.",
        go = function() return G:Go(r) end }
      if #out >= 2 then break end
    end
  end
  return out
end

SOURCES.training = function()
  local P = ns.ProfTrainer
  if not P then return {} end
  local prof, total = P:Best()
  if not prof or (total or 0) < 1 then return {} end
  return { { key = "profession:" .. prof, kind = "profession",
    title = string.format("Train %s (+%d expected)", prof, total),
    why = "You already carry what it needs: no shopping trip.",
    where = "anywhere (press your Training key)", benefit = clamp(total / 10), confidence = 0.85,
    label = "observed", panel = "professions",
    go = hub("professions") } }
end

SOURCES.rares = function()
  local scan, S = ns.Modules:Get("RareScan"), ns.Sightings
  if not (scan and S) then return {} end
  local out = {}
  local npcs = ns.db.global.discovered and ns.db.global.discovered.npcs or {}
  for id in pairs(scan:Settings().watch or {}) do
    if type(id) == "number" then
      local win = S:Window(id)
      local last = S:Last(id)
      if last and (win.state == "open" or win.state == "overdue" or win.state == "alive") then
        local name = npcs[id] and npcs[id].name or ("rare " .. id)
        out[#out + 1] = { key = "rare:" .. id, kind = "rare", title = "Check for " .. name,
          why = win.state == "alive" and "Seen alive recently." or "Its respawn window is open, going by past sightings.",
          where = zone(last.mapID) .. " (last seen spot)", benefit = win.state == "alive" and 0.9 or 0.6,
          confidence = win.state == "alive" and 0.8 or 0.4,
          caveat = win.state ~= "alive" and "Respawn windows are a guess from a few sightings." or nil,
          mapID = last.mapID, label = win.state == "alive" and "observed" or "inferred", panel = "rares",
          target = last.x and last.y and { mapID = last.mapID, x = last.x, y = last.y } or nil,
          go = wp(last.mapID, last.x, last.y, name) }
      end
    end
  end
  return out
end

SOURCES.gold = function()
  local G = ns.MoneyGuide
  if not G then return {} end
  local r = (G:Rank() or {})[1]
  if not (r and r.entry) then return {} end
  return { { key = "gold:" .. tostring(r.entry.id), kind = "gold", title = tostring(r.entry.title),
    why = M.Safe(G.RateText, r) or "A good earner at your level.",
    where = r.entry.zones and table.concat(r.entry.zones, ", ") or "see the Money page",
    -- "loot everything" is a habit, not a step: it counts for less
    benefit = r.entry.id == "loot-everything" and 0.3 or 0.6, confidence = r.measured and 0.85 or 0.5,
    label = r.measured and "observed" or "community", panel = "hub",
    caveat = not r.measured and "Rate from guides, not measured on you yet." or nil,
    go = hub("money") } }
end

SOURCES.gather = function()
  local L = ns.LootLog
  local here = ns.Travel and ns.Travel.Here()
  if not (L and here and here.mapID) then return {} end
  local out = {}
  for _, n in ipairs(L:NodesFor(here.mapID) or {}) do
    local state, age = L:NodeState(n.mapID, n.x, n.y)
    if state == "up" then
      local fish = n.kind == "fish" or n.kind == "pool"
      out[#out + 1] = { key = "gather:" .. n.mapID .. ":" .. math.floor(n.x * 1000) .. ":" .. math.floor(n.y * 1000),
        kind = "gather", title = fish and ("Fish here (" .. tostring(n.name or "pool") .. ")") or ("Gather " .. tostring(n.name or n.kind)),
        why = string.format("You saw it up %d minute%s ago.", math.floor((age or 0) / 60), math.floor((age or 0) / 60) == 1 and "" or "s"),
        where = zone(n.mapID) .. " (nearby)",
        benefit = 0.5, confidence = 0.7, mapID = n.mapID, label = "observed",
        target = { mapID = n.mapID, x = n.x, y = n.y }, go = wp(n.mapID, n.x, n.y, n.name) }
      if #out >= 2 then break end
    end
  end
  return out
end

function M.Safe(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, v = pcall(fn, ...)
  if ok then return v end
  return nil
end

-- ------------------------------------------------------------ build
-- Tips from the leveling knowledge base (Data/Leveling_Facts.lua, Wowhead's
-- Forever guides): a fact shows for the first levels after it becomes useful
-- (riding at 40, the Cozy Sleeping Bag at 14), for your class and race only.
M.TIP_SPAN = 5
SOURCES.tips = function()
  local facts = ns.Leveling and ns.Leveling.FACTS or {}
  local level = tonumber(ns.Compat.Call("UnitLevel", "player")) or 1
  local cls = ns.PlayerClass and ns.PlayerClass()
  local race = select(2, ns.Compat.Call("UnitRace", "player"))
  local out = {}
  for _, f in ipairs(facts) do
    local from = tonumber(f.minLevel)
    local to = tonumber(f.maxLevel) or (from and from + M.TIP_SPAN)
    if from and level >= from and level <= to and (not f.class or f.class == cls)
      and (not f.race or tostring(race or ""):lower() == tostring(f.race):lower()) then
      out[#out + 1] = { key = "tip:" .. tostring(f.id), kind = "tip", title = tostring(f.text),
        why = "From the WoW Forever leveling guides (" .. tostring(f.topic or "tip") .. ").",
        where = "", benefit = 0.5, confidence = 0.6, label = "guide", panel = "help", go = hub("help") }
    end
  end
  return out
end

-- Dungeon quests to take along (Modules/DungeonQuests.lua): for the next
-- dungeon right for your level, the first quest you haven't done.
SOURCES.dungeonquests = function()
  local D = ns.DungeonQuests
  if not (D and D.enabled) then return {} end
  local ctx = D:Context()
  local best = D:Next(ctx)
  if not best then return {} end
  for _, st in ipairs(best.steps) do
    local status = D:Status(st, ctx)
    if status == "todo" then
      return { { key = "dq:" .. tostring(st.id), kind = "dungeon",
        title = string.format("Pick up %s for %s", tostring(st.quest), best.name),
        why = string.format("A dungeon quest is a lot of XP; %s is right for your level (%d-%d).", best.name, best.lo, best.hi),
        where = string.format("%s, %s", tostring(st.name), tostring(st.zone)), benefit = 0.6, confidence = 0.6, label = "guide",
        go = function() return D:Go(st) end } }
    end
  end
  return {}
end

M.ORDER = { "errands", "quests", "gear", "dungeons", "dungeonquests", "training", "rares", "gold", "gather", "tips" }

function M:Candidates()
  local all, failed = {}, {}
  for _, name in ipairs(M.ORDER) do
    local ok, list = pcall(SOURCES[name])
    if ok and type(list) == "table" then
      for _, c in ipairs(list) do all[#all + 1] = c end
    else
      failed[#failed + 1] = name
      self:Debug("what now: source %s failed: %s", name, tostring(list))
    end
  end
  return all, failed
end

function M:Store()
  local c = ns.db.char
  c.whatNow = c.whatNow or { skip = {}, shown = {} }
  return c.whatNow
end

function M:Goal() return self:Settings().goal or "mix" end

function M:SetGoal(goal)
  if not M.WEIGHTS[goal] then return false end
  self:Settings().goal = goal
  self.cache = nil
  self:Info("what now goal: %s", goal)
  return true
end

function M:List(force)
  local now = time()
  if not force and self.cache and now - self.cacheAt < M.CACHE then return self.cache end
  local cands, failed = self:Candidates()
  local st = self:Store()
  local list = M.Pick(cands, self:Goal(), st.skip, now)
  self.cache, self.cacheAt, self.failed = list, now, failed
  if not self.loggedAt then self:LogAll("first look") end
  local keys = {}
  for _, c in ipairs(list) do keys[#keys + 1] = c.key end
  -- the page refreshes often: log and count only when the steps change
  -- (the same line every 30 s filled the log, 2026-11-15)
  local sig = self:Goal() .. "|" .. table.concat(keys, ",")
  if sig ~= self.lastSig then
    self.lastSig = sig
    for _, k in ipairs(keys) do st.shown[k] = (st.shown[k] or 0) + 1 end
    self:Info("what now (%s): %d candidates -> %s%s", self:Goal(), #cands, table.concat(keys, ", "),
      #failed > 0 and (" (failed: " .. table.concat(failed, ",") .. ")") or "")
    -- keep the steps as of now (position known) for the logout snapshot, so
    -- an advisor reading the saved file has candidates without an Ask
    local ok, snap = pcall(self.BuildSnapshot, self)
    if ok and snap then snap.seenAt = now self.lastSnap = snap end
  end
  return list
end

function M:Go(c)
  if not (c and c.go) then return false end
  local ok, a, b = pcall(c.go)
  self:Info("what now go: %s (%s)", tostring(c.key), ok and "ok" or tostring(a))
  if ok and a == false then
    if c.alt then ns.Print("%s Try instead: %s", tostring(b or "Couldn't set that up."), c.alt.text) end
    return false
  end
  return ok
end

function M:Skip(c)
  if not c then return end
  self:Store().skip[c.key] = time()
  self:Info("what now not useful: %s (%s, score %.2f)", tostring(c.key), self:Goal(), c.score or 0)
  self.cache = nil
end

-- One log line per goal with what would be suggested, so the suggestions can
-- be judged from the saved log (tests are self-collecting). Taken the first
-- time the page lists steps in a session, then on each new zone (at most every
-- 10 min). Not at logout: the game no longer reports the position then, so
-- every quest's trip time came back empty. Not at login either: it would load
-- the gear pack (4 MB) for players who never open the page.
M.LOG_GAP = 600
function M:LogAll(why)
  local now = time()
  if self.loggedAt and now - self.loggedAt < M.LOG_GAP then return end
  self.loggedAt = now
  local cands, failed = self:Candidates()
  local skip = self:Store().skip
  for _, g in ipairs(M.GOALS) do
    local keys = {}
    for _, c in ipairs(M.Pick(cands, g.id, skip)) do keys[#keys + 1] = string.format("%s %.2f", c.key, c.score or 0) end
    self:Info("what now %s (%s): %s", tostring(why), g.id, #keys > 0 and table.concat(keys, "; ") or "nothing")
  end
  if #failed > 0 then self:Warn("what now sources failed: %s", table.concat(failed, ", ")) end
end

-- tidy old skips at login; after a first look, log the suggestions on new zones
function M:OnEnable()
  self:On("PLAYER_ENTERING_WORLD", function(mod)
    local st, now = mod:Store(), time()
    for k, t in pairs(st.skip) do if now - t > M.SKIP_FOR then st.skip[k] = nil end end
    -- where this session started (XP, level, gold), for the "This session" card
    if not mod.session then
      mod.session = { t = now, level = C.Call("UnitLevel", "player") or 1, xp = C.Call("UnitXP", "player") or 0,
        money = C.Call("GetMoney") or 0 }
    end
  end)
  self:On("ZONE_CHANGED_NEW_AREA", function(mod) if mod.loggedAt then mod:LogAll("new zone") end end)
end

-- This session so far: xpGained (counts whole levels in between using the XP
-- needed at the current level, close enough), gold, seconds played.
function M:SessionStats()
  local s = self.session
  if not s then return nil end
  local level = C.Call("UnitLevel", "player") or s.level
  local xp, max = C.Call("UnitXP", "player") or 0, C.Call("UnitXPMax", "player") or 0
  local gained = level == s.level and (xp - s.xp) or ((max - s.xp) + xp + (level - s.level - 1) * max)
  return { xp = math.max(0, gained), levels = level - s.level, money = (C.Call("GetMoney") or 0) - s.money,
    seconds = time() - s.t }
end

-- Average level of the gear worn, or nil.
function M.ItemLevel()
  local avg = C.Call("GetAverageItemLevel")
  if type(avg) == "number" and avg > 0 then return math.floor(avg + 0.5) end
  local sum, n = 0, 0
  for slot = 1, 18 do
    if slot ~= 4 then
      local link = C.Call("GetInventoryItemLink", "player", slot)
      if link then
        local _, _, _, ilvl = C.Call("C_Item.GetItemInfo", link)
        if type(ilvl) ~= "number" then _, _, _, ilvl = C.Call("GetItemInfo", link) end
        if type(ilvl) == "number" then sum, n = sum + ilvl, n + 1 end
      end
    end
  end
  return n > 0 and math.floor(sum / n + 0.5) or nil
end

-- For the AI companion (Outrider Intelligence, AI01-02): the top candidates
-- for the current goal, best first, as plain data. Every place comes from
-- Outrider's own records (target = map id and coordinates, or a panel to
-- open); the companion may only point at these, never invent one.
M.SNAPSHOT_MAX = 12
function M:Ranked(n)
  local cands = self:Candidates()
  local goal, skip, now = self:Goal(), self:Store().skip, time()
  local list = {}
  for _, c in ipairs(cands) do
    local hidden = skip[c.key] and now - skip[c.key] < M.SKIP_FOR
    if not hidden and (c.benefit or 0) > 0 then
      local copy = {}
      for k, v in pairs(c) do copy[k] = v end
      copy.score = M.Score(copy, goal)
      list[#list + 1] = copy
    end
  end
  table.sort(list, function(a, b) if a.score ~= b.score then return a.score > b.score end return tostring(a.key) < tostring(b.key) end)
  for i = #list, (n or M.SNAPSHOT_MAX) + 1, -1 do list[i] = nil end
  return list
end

function M:Snapshot()
  -- /ride ask: fresh. At logout the position is gone, so the steps last seen
  -- while playing (seenAt) are saved instead; nil if What now? never ran.
  if not (ns.Snapshot and ns.Snapshot.asking) then return self.lastSnap end
  return self:BuildSnapshot()
end

function M:BuildSnapshot()
  local out = { goal = self:Goal(), candidates = {}, feedback = {} }
  local fb = ns.KeepTable(ns.db.char.adviceFeedback, "WhatNow:ns.db.char.adviceFeedback") or {}
  for i = #fb, math.max(1, #fb - 19), -1 do   -- the 20 newest
    local f = fb[i]
    out.feedback[#out.feedback + 1] = { id = f.id, v = f.v, t = f.t }
  end
  for i, c in ipairs(self:Ranked(M.SNAPSHOT_MAX)) do
    out.candidates[i] = {
      candidateId = c.key, kind = c.kind, title = c.title, why = c.why, where = c.where, caveat = c.caveat,
      minutes = c.seconds and math.floor(c.seconds / 60 + 0.5) or nil,
      score = math.floor((c.score or 0) * 1000 + 0.5) / 1000,
      label = c.label or ((c.confidence or 1) >= 0.7 and "inferred" or "unknown"),
      urgent = c.urgent or nil, itemID = c.itemID, panel = c.panel,
      target = c.target, questID = c.questID,
      estimatedQuestXP = c.estimatedQuestXP,
      estimatedTripSeconds = c.estimatedTripSeconds,
      estimatedActivitySeconds = c.estimatedActivitySeconds,
      estimateBasis = c.estimateBasis,
    }
  end
  return out
end

function M:Activity()
  return "goal: " .. self:Goal()
end

ns.AddCommand("now", "level|gold|gear|professions|explore|mix  What now? next steps (optional goal)", function(arg)
  arg = (arg or ""):lower()
  if arg ~= "" and not M:SetGoal(arg) then ns.Print("goals: level, gold, gear, professions, explore, mix") return end
  local f = ns.Hub:Build() f:Show() ns.Hub:ShowTab("whatnow")
end)
