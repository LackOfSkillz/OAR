-- Modules/Finder.lua
-- The Journey tab's search engine (Gary, 2026-11-13: "a feature-rich map:
-- pick a place, a critter to hunt, a quest, the best XP or gear for my
-- level, an item, an NPC; searchable and sortable; use the available data,
-- not only places I know"). One list of entries from every source:
--   gear     upgrades for this character from the gear pack, every map
--   item     any item in the gear pack by name, with where it comes from
--   quest    quests you can pick up now, every map (NPC pack), with estimated XP
--   rare     rares and rare elites: creature pack + rares you have met (Discovery)
--   mob      every hostile creature with its level (creature pack) + ones you met
--   npc      service NPCs and quest givers (NPC pack) + NPCs you have met
--   place    places you have used (inns, vendors, flight masters, mailboxes...)
--            and gathering/fishing spots you found
-- Entry: { kind, name, sub, mapID, x, y, level, xp, gain, seconds, target, npcID }.
-- Packs are private community data (D10/D11, verified = false); what Gary met
-- himself is marked "seen". Search matches name, details and zone; sorts:
-- nearest (travel time from Travel), XP, XP per minute, gear gain, closest to
-- your level, name, zone.

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("Finder", {
  title = "Finder: search everything on the map",
  phase = "P3",
  order = 49,
  defaults = {},
})
ns.Finder = M

M.MOBS_ADDON = "Outrider_Data_Mobs"
M.CAP = 300
M.KINDS = { "all", "gear", "item", "quest", "rare", "mob", "npc", "place" }
M.KIND_LABEL = { all = "All", gear = "Gear", item = "Items", quest = "Quests", rare = "Rares", mob = "Creatures",
  npc = "NPCs", place = "Places" }
M.SORTS = { "nearest", "xpmin", "xp", "gain", "level", "name", "zone" }
M.SORT_LABEL = { nearest = "nearest", xpmin = "XP per minute", xp = "most XP", gain = "best gear", level = "your level",
  name = "name", zone = "zone" }
M.DEFAULT_SORT = { gear = "gain", quest = "xpmin", item = "nearest", rare = "nearest", mob = "level", npc = "nearest",
  place = "nearest", all = "nearest" }
local RANK = { [1] = "elite", [2] = "rare elite", [3] = "boss", [4] = "rare" }

function M:Mobs()
  if self.mobs ~= nil then return self.mobs end
  if not rawget(_G, "Outrider_DataMobs") then C.LoadAddOn(self.MOBS_ADDON) end
  local data = rawget(_G, "Outrider_DataMobs")
  self.mobs = type(data) == "table" and type(data.maps) == "table" and data.maps or false
  self:Info(self.mobs and "creature pack loaded from %s" or "no creature pack (%s): creatures you met only",
    self.mobs and tostring(data.source) or self.MOBS_ADDON)
  return self.mobs
end

local function add(out, kind, name, mapID, x, y, t)
  if not (mapID and x and y and name) then return end
  t = t or {}
  t.kind, t.name, t.mapID, t.x, t.y = kind, name, mapID, x, y
  out[#out + 1] = t
end

-- ------------------------------------------------------------ providers
local P = {}

function P.gear(out)
  for _, c in ipairs(ns.Nearby and ns.Nearby:Candidates({ world = true }) or {}) do
    local w = c.where or {}
    add(out, "gear", c.name, w.mapID, w.x, w.y, { gain = c.pct, level = c.reqLevel, itemID = c.itemID,
      sub = ns.Nearby.Describe(c):gsub("^%+%d+%%%s+", ""), note = w.note })
  end
end

function P.item(out, text)
  if not text or #text < 3 or not (ns.Nearby and ns.Nearby:Load()) then return end
  local faction = C.Call("UnitFactionGroup", "player")
  for id, it in pairs(ns.Nearby.pack) do
    if tostring(it[1]):lower():find(text, 1, true) then
      for _, s in ipairs(it[4] or {}) do
        if s[7] == nil or s[7] == faction then
          add(out, "item", it[1], s[2], s[3], s[4], { itemID = id, level = it[2],
            sub = string.format("%s %s", tostring(s[1]), tostring(s[5] or "")) })
          break
        end
      end
    end
  end
end

function P.quest(out)
  local level = C.Call("UnitLevel", "player") or 1
  for _, q in ipairs(ns.NPCPack and ns.NPCPack:AvailableEverywhere() or {}) do
    add(out, "quest", q.name, q.mapID, q.x, q.y, { level = q.level, diff = q.diff, questID = q.id,
      xp = ns.Journey.XP(q.level, level), sub = "from " .. tostring(q.giver) })
  end
end

-- Creatures you met (Discovery), by npcID: name, level, classification, position.
local function met()
  local d = ns.db.global.discovered
  return type(d) == "table" and type(d.npcs) == "table" and d.npcs or {}
end

local function creatures(out, want, text, level)
  local seen = {}
  for npcID, e in pairs(met()) do
    local cls = e.classification
    local isRare = cls == "rare" or cls == "rareelite"
    if e.mapID and e.x and ((want == "rare" and isRare) or (want == "mob" and not isRare and e.creatureType and not e.title and not (e.roles and next(e.roles)))) then
      seen[npcID] = true
      add(out, want, e.name, e.mapID, e.x, e.y, { npcID = npcID, level = tonumber(e.level), seenByYou = true,
        sub = (isRare and (cls == "rareelite" and "rare elite" or "rare") or tostring(e.creatureType or "")) .. ", seen" })
    end
  end
  local mobs = M:Mobs()
  for mapID, rows in pairs(mobs or {}) do
    for _, r in ipairs(rows) do
      local npcID, name, lo, hi, rank, pts = r[1], r[2], r[3], r[4], r[5], r[6]
      local isRare = rank == 2 or rank == 4
      local ok = (want == "rare") == isRare and not seen[npcID]
      if ok and want == "mob" and not (text and #text >= 3) then
        ok = level and hi >= level - 3 and lo <= level + 3 -- no search: only creatures around your level
      end
      if ok and pts and pts[1] then
        add(out, want, name, mapID, pts[1], pts[2], { npcID = npcID, level = hi, levelLo = lo,
          sub = (RANK[rank] or "creature") .. (lo ~= hi and string.format(", level %d-%d", lo, hi) or "")
            .. (#pts > 2 and string.format(", %d spots", #pts / 2) or "") })
      end
    end
  end
end

function P.rare(out, text, level) creatures(out, "rare", text, level) end
function P.mob(out, text, level) creatures(out, "mob", text, level) end

function P.npc(out, text)
  local seen = {}
  for npcID, e in pairs(met()) do
    if e.mapID and e.x and (e.title or (e.roles and next(e.roles))) then
      seen[npcID] = true
      add(out, "npc", e.name, e.mapID, e.x, e.y, { npcID = npcID, level = tonumber(e.level), seenByYou = true,
        sub = (e.title and ("<" .. e.title .. ">") or "") .. ", seen" })
    end
  end
  local raw = ns.NPCPack and ns.NPCPack.raw
  if not raw or not (text and #text >= 2) then return end -- the whole pack only when searching
  local faction = C.Call("UnitFactionGroup", "player")
  for mapID, rows in pairs(raw) do
    for _, r in ipairs(rows) do
      local npcID, kind = r[1], r[2]
      if not seen[npcID] and (r[7] == nil or r[7] == faction) then
        seen[npcID] = true
        add(out, "npc", r[5], mapID, r[3], r[4], { npcID = npcID,
          sub = (r[6] and ("<" .. r[6] .. "> ") or "") .. tostring(kind):gsub("_", " ") })
      end
    end
  end
end

function P.place(out)
  for _, p in pairs(ns.db.global.pois or {}) do
    if p.mapID and p.x then
      add(out, "place", p.title or p.name or p.kind, p.mapID, p.x, p.y, { sub = tostring(p.kind):gsub("_", " "),
        seenByYou = p.source ~= "client" or nil })
    end
  end
  for _, n in ipairs(ns.db.global.nodes or {}) do
    add(out, "place", n.name or n.kind, n.mapID, n.x, n.y, { sub = tostring(n.kind) .. " spot, seen" })
  end
end

-- ---------------------------------------------------------------- search
local ALL_BASE = { "gear", "quest", "rare", "place" }      -- "All" with no search text
local ALL_TEXT = { "gear", "item", "quest", "rare", "mob", "npc", "place" }

local SORTERS = {
  nearest = function(a, b) return (a.seconds or 1e12) < (b.seconds or 1e12) end,
  xp = function(a, b) return (a.xp or -1) > (b.xp or -1) end,
  xpmin = function(a, b) return (a.rate or -1) > (b.rate or -1) end,
  gain = function(a, b) return (a.gain or -1) > (b.gain or -1) end,
  name = function(a, b) return tostring(a.name):lower() < tostring(b.name):lower() end,
  zone = function(a, b)
    if a.zone ~= b.zone then return tostring(a.zone) < tostring(b.zone) end
    return (a.seconds or 1e12) < (b.seconds or 1e12)
  end,
}

-- opts = { kind = "all", text = "", sort = nil (kind's default) }. Returns list (capped), total.
function M:Find(opts)
  opts = opts or {}
  local kind = opts.kind or "all"
  local text = opts.text and opts.text:lower():gsub("^%s+", ""):gsub("%s+$", "") or ""
  if text == "" then text = nil end
  local level = C.Call("UnitLevel", "player") or 1
  local list = {}
  local kinds = kind ~= "all" and { kind } or (text and ALL_TEXT or ALL_BASE)
  for _, k in ipairs(kinds) do
    local fn = P[k]
    if fn then ns.Safe("finder:" .. k, fn, list, text, level) end
  end
  local prep = ns.Travel:Prepare()
  local out = {}
  for _, e in ipairs(list) do
    e.zone = ns.Travel.ZoneName(e.mapID)
    local keep = true
    if text then
      local hay = (tostring(e.name) .. " " .. tostring(e.sub or "") .. " " .. e.zone .. " " .. (M.KIND_LABEL[e.kind] or "")):lower()
      keep = hay:find(text, 1, true) ~= nil
    end
    if keep then
      e.target = ns.Travel.Point(e.mapID, e.x, e.y, e.name)
      e.seconds = e.target and ns.Travel:TimeTo(prep, e.target) or nil
      if e.xp then e.rate = e.xp / (((e.seconds or 3600) + ns.Journey.QUEST_TIME) / 60) end
      out[#out + 1] = e
    end
  end
  local sort = opts.sort or M.DEFAULT_SORT[kind] or "nearest"
  local cmp = SORTERS[sort]
  if sort == "level" then
    cmp = function(a, b)
      local da, db = a.level and math.abs(a.level - level) or 99, b.level and math.abs(b.level - level) or 99
      if da ~= db then return da < db end
      return (a.seconds or 1e12) < (b.seconds or 1e12)
    end
  end
  table.sort(out, cmp or SORTERS.nearest)
  local total = #out
  while #out > M.CAP do table.remove(out) end
  return out, total, sort
end

local KIND_TAG = { gear = "gear", item = "item", quest = "quest", rare = "RARE", mob = "creature", npc = "npc", place = "place" }

function M.Line(e)
  local parts = {}
  if e.gain then parts[#parts + 1] = string.format("+%d%%", math.floor(e.gain + 0.5)) end
  if e.xp then parts[#parts + 1] = string.format("~%d XP", e.xp) end
  parts[#parts + 1] = e.zone or ns.Travel.ZoneName(e.mapID)
  parts[#parts + 1] = e.seconds and ns.Travel.Minutes(e.seconds) or "no known way yet"
  return string.format("%s%s  |cffbbbbbb%s: %s. %s|r", e.level and ("[" .. e.level .. "] ") or "", tostring(e.name),
    KIND_TAG[e.kind] or e.kind, tostring(e.sub or ""), table.concat(parts, ", "))
end

function M:Activity()
  return "search gear, items, quests, rares, creatures, NPCs and places anywhere (Journey tab)"
end
