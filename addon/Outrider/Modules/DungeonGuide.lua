-- Modules/DungeonGuide.lua  (dungeon and raid module, phase 1)
-- Which dungeons this character is ready for, what each one holds for it,
-- and where to go next for the next step up in gear (Gary, 2026-11-14: "gear
-- awareness that comes from dungeons ... what dungeons you're ready for and
-- what dungeons you need for the gear to get to your next tier").
-- Data: Outrider_Data_Dungeons (tools/import_dungeons.py from QuestieDB:
-- bosses, their gear drops, entrances) and Data/Dungeons.lua (level ranges,
-- foreverdb.net). Gear is scored with the gear advisor (class weights, armor
-- type, weapon skills) against what is worn now.
--   ready: your level is inside the range (or up to 2 below its start)
--   soon:  starts within 8 levels: its gear is your next tier
-- A dungeon's value is the best upgrade per slot it offers, added up.

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("DungeonGuide", {
  title = "Dungeons and raids: where your gear is",
  phase = "P6",
  order = 84,
  defaults = {},
})
ns.DungeonGuide = M

M.ADDON = "Outrider_Data_Dungeons"
M.EARLY, M.SOON = 2, 8

function M:Pack()
  if self.pack ~= nil then return self.pack end
  if not rawget(_G, "Outrider_DataDungeons") then C.LoadAddOn(self.ADDON) end
  local data = rawget(_G, "Outrider_DataDungeons")
  self.pack = type(data) == "table" and type(data.dungeons) == "table" and data.dungeons or false
  self:Info(self.pack and "dungeon pack loaded (%s)" or "no dungeon pack (%s)", self.pack and tostring(data.source) or self.ADDON)
  return self.pack
end

-- Dungeons with one name (Dire Maul has several wings) merged: { name = {ids, entrance, bosses, items} }
function M:ByName()
  if self.byName then return self.byName end
  local out = {}
  for id, d in pairs(self:Pack() or {}) do
    local e = out[d.name]
    if not e then
      e = { name = d.name, ids = {}, map = d.map, x = d.x, y = d.y, bosses = {}, items = {} }
      out[d.name] = e
    end
    e.ids[#e.ids + 1] = id
    for _, b in ipairs(d.bosses or {}) do e.bosses[#e.bosses + 1] = b end
    for iid, it in pairs(d.items or {}) do e.items[iid] = it end
  end
  self.byName = out
  return out
end

-- DEEP-19: a conservative cross-reference between the QuestieDB objective
-- pack and the dungeon boss NPC IDs already present in the dungeon pack.
-- This finds boss-specific quests without pretending every dungeon quest
-- is covered. The user can label additional known quests explicitly.
function M:QuestLinks()
  ns.db.global.dungeonQuestLinks = ns.db.global.dungeonQuestLinks or {}
  return ns.db.global.dungeonQuestLinks
end

function M:QuestList(dungeon)
  local d = self:ByName()[dungeon]
  if not d then return {}, "unknown dungeon" end
  local questPack = ns.QuestObjectives and ns.QuestObjectives:Pack()
  if not questPack then return {}, "Questie quest data not installed" end
  local bosses = {}
  for _, boss in ipairs(d.bosses) do bosses[boss[1]] = true end
  local active = {}
  for _, q in ipairs(ns.QuestObjectives.Log()) do active[q.questID] = q end
  local links, out = self:QuestLinks(), {}
  for id, q in pairs(questPack.quests or {}) do
    local linked = links[id] == dungeon
    local fromBoss = false
    for _, objective in ipairs(q[3] or {}) do
      if objective[1] == "npc" and bosses[objective[2]] then fromBoss = true break end
    end
    if linked or fromBoss then
      local live = active[id]
      local entry = { id = id, name = q[1], level = q[2],
        active = live ~= nil, complete = live and live.complete or false,
        objectives = live and live.objectives or {}, source = linked and "user-linked" or "boss objective",
        chain = ns.QuestInfo and { ns.QuestInfo:Chain(id) } or nil }
      out[#out + 1] = entry
    end
  end
  table.sort(out, function(a, b) return (a.level or 0) < (b.level or 0) or
    (a.level == b.level and tostring(a.name) < tostring(b.name)) end)
  return out
end

ns.AddCommand("dungeonquests", "dungeonquests <dungeon name> | link <questID> <dungeon name>", function(arg)
  arg = tostring(arg or "")
  local id, name = arg:match("^link%s+(%d+)%s+(.+)$")
  if id then
    id = tonumber(id)
    if not M:ByName()[name] then ns.Print("unknown dungeon: %s", name) return end
    M:QuestLinks()[id] = name
    ns.Print("linked quest %d to %s (user-supplied)", id, name)
    return
  end
  local rows, why = M:QuestList(arg)
  if why then ns.Print("%s", why) return end
  ns.Print("%s: %d known boss-related or linked quests; incomplete until quest-data coverage is checked", arg, #rows)
  for i = 1, math.min(#rows, 25) do
    local q = rows[i]
    ns.Print("  [%d] %s (%s%s)", q.id, q.name or "?", q.source, q.active and ", in log" or "")
  end
end)

-- Boss loot is taken directly from the loaded dungeon pack, not scraped
-- dynamically, and is only as complete as that pack's last import.
function M:BossLoot(bossName)
  local out = {}
  local needle = type(bossName) == "string" and bossName:lower() or ""
  if needle == "" then return out end
  for _, dungeon in pairs(self:ByName()) do
    for _, boss in ipairs(dungeon.bosses) do
      if tostring(boss[2]):lower():find(needle, 1, true) then
        for _, itemID in ipairs(boss[5] or {}) do
          local item = dungeon.items[itemID]
          out[#out + 1] = { id = itemID, name = item and item[1] or ("item " .. itemID),
            boss = boss[2], dungeon = dungeon.name, source = "imported boss loot" }
        end
      end
    end
  end
  table.sort(out, function(a, b) return a.id < b.id end)
  return out
end

ns.AddCommand("bossloot", "bossloot <boss name>  known boss drops, with wishlist markers", function(arg)
  local loot = M:BossLoot(arg)
  if #loot == 0 then ns.Print("no boss loot matches in installed dungeon pack") return end
  for i, row in ipairs(loot) do
    if i > 35 then break end
    local marked = ns.BagExtras and ns.BagExtras:Wishlist()[row.id]
    ns.Print("%s: %s [item %d]%s", row.boss, row.name, row.id, marked and " (WISHLIST)" or "")
  end
end)

-- Upgrades for this character from one dungeon: now = usable today, later = needs a few more levels.
-- { {itemID, name, boss, pct, slot, reqLevel, later} } best first
function M:Upgrades(d)
  local G, S = ns.GearScore, ns.GearShop
  if not G then return {} end
  local level = C.Call("UnitLevel", "player") or 1
  local bossOf = {}
  for _, b in ipairs(d.bosses) do for _, iid in ipairs(b[5] or {}) do bossOf[iid] = bossOf[iid] or b[2] end end
  local out = {}
  for iid, it in pairs(d.items) do
    local fits = not S or S:Fits(iid)
    local r = fits and G:Compare("item:" .. iid)
    if r then
      local req = it[2] or 0
      local later = type(r.why) == "string" and r.why:find("^level ") and req > level
      if (not r.why or later) and (r.pct >= 1 or (r.empty and r.new > 0)) then
        out[#out + 1] = { itemID = iid, name = it[1], boss = bossOf[iid], pct = r.empty and 100 or math.min(r.pct, 100),
          slot = r.slot, reqLevel = req, later = later }
      end
    end
  end
  table.sort(out, function(a, b) if a.pct ~= b.pct then return a.pct > b.pct end return a.itemID < b.itemID end)
  return out
end

-- Value: best upgrade per slot, added up (now-usable or later, as asked).
function M.Value(ups, later)
  local per, total, n = {}, 0, 0
  for _, u in ipairs(ups) do
    if (u.later and true or false) == (later and true or false) and not per[u.slot] then
      per[u.slot] = u
      total, n = total + u.pct, n + 1
    end
  end
  return total, n
end

-- { {name, info, status, value, count, laterValue, laterCount, ups, entrance} } for this character
function M:Rank()
  local level = C.Call("UnitLevel", "player") or 1
  local out = {}
  for name, d in pairs(self:ByName()) do
    local info = ns.Data:Get("dungeon", name)
    if info then
      local status
      if level >= info.min - M.EARLY and level <= info.max then status = "ready"
      elseif level < info.min - M.EARLY and info.min - level <= M.SOON then status = "soon"
      elseif level > info.max then status = "past" end
      if status and status ~= "past" then
        local ups = self:Upgrades(d)
        local v, n = M.Value(ups, false)
        local lv, ln = M.Value(ups, true)
        out[#out + 1] = { name = name, info = info, status = status, value = v, count = n, laterValue = lv, laterCount = ln,
          ups = ups, map = d.map, x = d.x, y = d.y }
      end
    end
  end
  table.sort(out, function(a, b)
    if a.status ~= b.status then return a.status == "ready" end
    if a.status == "ready" and a.value ~= b.value then return a.value > b.value end
    if a.status == "soon" and a.info.min ~= b.info.min then return a.info.min < b.info.min end
    return a.name < b.name
  end)
  return out
end

-- The next tier: among dungeons you're not quite ready for, the one with the most gear for you.
function M:NextTier(rank)
  local best
  for _, r in ipairs(rank or self:Rank()) do
    if r.status == "soon" and (not best or r.laterValue > best.laterValue) then best = r end
  end
  return best
end

-- "Edwin VanCleef: Cruel Barb +45%, ..." (top n, with the boss)
function M.UpgradeLine(ups, n, later)
  local parts = {}
  for _, u in ipairs(ups) do
    if (u.later and true or false) == (later and true or false) then
      parts[#parts + 1] = string.format("%s |cff7fff7f%s|r%s (%s)", tostring(u.name), ns.GearScore.UpText(u.pct),
        u.later and (" at " .. u.reqLevel) or "", tostring(u.boss or "?"))
      if #parts >= (n or 3) then break end
    end
  end
  return table.concat(parts, ", ")
end

function M:Go(r)
  if not (r.map and r.x and ns.Waypoints) then ns.Print("no entrance location for %s yet", r.name) return end
  ns.Waypoints:Set(r.map, r.x, r.y, "Entrance: " .. r.name)
end

-- warm the item cache for the dungeons that matter now (stats need it)
function M:Warm()
  for _, r in ipairs(self:Rank()) do
    local d = self:ByName()[r.name]
    for iid in pairs(d and d.items or {}) do
      if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, iid) end
    end
  end
end

-- Ready check before a dungeon (phase 2, 2026-11-15): { {ok, text} }.
-- Gear not about to break, food (and drink for mana users), bag space for
-- loot, and ammo for hunters. Anything Outrider can't read is left out.
M.READY = { durability = 0.6, freeSlots = 6, ammo = 1000 }
local NO_MANA = { WARRIOR = true, ROGUE = true }
function M:ReadyCheck()
  local out = {}
  local function add(ok, text, soft) out[#out + 1] = { ok = ok and true or false, text = text, warn = (not ok) and soft or nil } end
  local d = ns.Errands and ns.Errands.Durability and ns.Errands.Durability()
  if d then
    add(d >= M.READY.durability, d >= M.READY.durability and string.format("Gear in good repair (most worn piece %d%%)", math.floor(d * 100))
      or string.format("Repair first: most worn piece at %d%%", math.floor(d * 100)))
  end
  if ns.BagFood then
    local ok, food, drink = pcall(ns.BagFood.Scan, ns.BagFood)
    if ok then
      add(food ~= nil, food and ("Food: " .. tostring(food)) or "No food in your bags")
      if not NO_MANA[ns.PlayerClass and ns.PlayerClass() or ""] then
        add(drink ~= nil, drink and ("Drink: " .. tostring(drink)) or "No drink in your bags")
      end
    end
  end
  local free, known = 0, false
  for bag = 0, 4 do
    local n = C.Call("C_Container.GetContainerNumFreeSlots", bag)
    if type(n) == "number" then free, known = free + n, true end
  end
  if known then
    add(free >= M.READY.freeSlots, free >= M.READY.freeSlots and string.format("%d free bag slots", free)
      or string.format("Only %d free bag slots: sell or bank something", free))
  end
  if ns.PlayerClass and ns.PlayerClass() == "HUNTER" then
    local ammo = ns.Modules:Get("Ammo")
    local n = ammo and ammo.Count and ammo:Count()
    if n then add(n >= M.READY.ammo, string.format("%d ammo%s", n, n >= M.READY.ammo and "" or " (buy more)"), n >= 100) end
  end
  return out
end

function M.ReadyText(list)
  local lines = {}
  for _, c in ipairs(list) do
    lines[#lines + 1] = (c.ok and "|cff66dd77OK|r  " or "|cffff6060X|r  ") .. c.text
  end
  return #lines > 0 and table.concat(lines, "\n") or "Nothing to check here."
end

-- Party ready check: one click sends yours to party members who run
-- Outrider (only when Gary clicks; addon messages, PARTY only); theirs show
-- under yours for 15 minutes.
M.PARTY_FOR = 900
function M:ShareReady()
  if not (ns.Comm and C.Call("IsInGroup")) then return false, "not in a group" end
  local checks = {}
  for _, c in ipairs(self:ReadyCheck()) do checks[#checks + 1] = { ok = c.ok, text = c.text, warn = c.warn } end
  local ok = ns.Comm:Send("READY", { level = C.Call("UnitLevel", "player"), class = ns.PlayerClass and ns.PlayerClass(),
    checks = checks }, "PARTY")
  self:Info("ready check shared with the party: %s", tostring(ok))
  return ok
end

function M:OnReady(_, kind, data, sender)
  if kind ~= "READY" or type(data) ~= "table" or type(data.checks) ~= "table" then return end
  self.party = self.party or {}
  local list = {}
  for i, c in ipairs(data.checks) do
    if i > 8 then break end
    if type(c) == "table" and type(c.text) == "string" then list[#list + 1] = { ok = c.ok == true, text = c.text:sub(1, 80) } end
  end
  self.party[tostring(sender)] = { t = time(), level = tonumber(data.level), class = type(data.class) == "string" and data.class or nil, checks = list }
end

function M:PartyText()
  local lines, now = {}, time()
  local names = {}
  for name, p in pairs(self.party or {}) do
    if now - p.t <= M.PARTY_FOR then names[#names + 1] = name else self.party[name] = nil end
  end
  table.sort(names)
  for _, name in ipairs(names) do
    local p = self.party[name]
    local todo = {}
    for _, c in ipairs(p.checks) do if not c.ok then todo[#todo + 1] = c.text end end
    lines[#lines + 1] = string.format("%s%s: %s", name:match("^[^-]+") or name, p.level and (" (" .. p.level .. ")") or "",
      #todo == 0 and "|cff66dd77all set|r" or ("|cffff6060" .. table.concat(todo, "; ") .. "|r"))
  end
  return #lines > 0 and table.concat(lines, "\n") or "No party ready checks yet. Party members who run Outrider can share theirs too."
end

-- For the AI companion (AI04-03): dungeons that fit now and the next tier,
-- with the upgrades in each, as plain data. Only on /ride ask.
function M:Snapshot()
  if not (ns.Snapshot and ns.Snapshot.asking) or not self:Pack() then return nil end
  local out = { ready = {}, soon = {} }
  for _, r in ipairs(self:Rank()) do
    local row = { name = r.name, min = r.info and r.info.min, max = r.info and r.info.max, status = r.status,
      upgrades = r.count, laterUpgrades = r.laterCount, raid = r.info and r.info.raid or nil,
      target = r.map and r.x and r.y and { mapID = r.map, x = r.x, y = r.y } or nil, ups = {} }
    for _, u in ipairs(r.ups or {}) do
      if #row.ups >= 4 then break end
      row.ups[#row.ups + 1] = { item = u.name, pct = u.pct and math.floor(u.pct + 0.5), boss = u.boss,
        later = u.later or nil, reqLevel = u.reqLevel }
    end
    local list = r.status == "ready" and out.ready or out.soon
    if #list < 5 then list[#list + 1] = row end
  end
  return out
end

function M:OnEnable()
  if ns.Comm then ns.Comm.KNOWN_TYPES.READY = true end
  self:On("OTR_COMM", self.OnReady)
end

function M:Activity()
  if not self:Pack() then return "dungeon pack not installed" end
  local rank = self:Rank()
  local top = rank[1]
  if not top then return "no dungeon in your level range" end
  return string.format("best now: %s (%d upgrades)", top.name, top.count)
end
