-- Modules/FishingGuide.lua
-- The Fishing page (Gary, 2026-11-17: "look up fishing addons ... add all the
-- best fishing features and data"; Fishing Buddy Forever, Forever Fishing and
-- FishFry compared). Outrider already had one-key cast and hook, sound focus,
-- auto loot, lure timer, catches per zone, gold per hour, rare-catch sound,
-- pool pins and a goal (Fishing, FishingHUD, LootLog). This adds:
--   * lifetime stats (casts, catches, getaways, catch rate, fish caught) and a
--     skill-up predictor measured from YOUR catches per skill point
--   * the next milestone (Journeyman, the Expert book, Nat Pagle) and the
--     zones for your skill, with what you've caught there (Data/Fishing.lua,
--     cited WoW Forever guide, unverified)
--   * fishing trainers and supply vendors for your faction, with an arrow
--   * fishing gear: one click puts on your best pole and any gear with a
--     Fishing bonus, another puts your usual gear back (your clicks, out of
--     combat)
--   * the Stranglethorn Fishing Extravaganza countdown (Classic schedule,
--     unverified on Forever)

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("FishingGuide", {
  title = "Fishing guide, stats and gear",
  phase = "P5",
  order = 82,
  defaults = {},
  yieldsTo = { "FishingBuddy", "ForeverFishing", "FishFry" },
})
ns.FishingGuide = M

M.KEEP_POINTS = 10
local POLE_CLASS, POLE_SUBCLASS = 2, 20
M.GEAR_SLOTS = { 1, 5, 9, 10, 8 } -- head, chest, wrist, hands, feet: where Fishing bonus gear usually sits

local function readable(v) return v ~= nil and C.Readable(v) and v or nil end

function M:OnInitialize()
  local g = ns.db.global
  g.fishStats = type(g.fishStats) == "table" and g.fishStats or { casts = 0, catches = 0, escapes = 0, fish = {} }
  self.stats = g.fishStats
  self.stats.fish = self.stats.fish or {}
end

function M:Char()
  local c = ns.db.char
  c.fishSkill = type(c.fishSkill) == "table" and c.fishSkill or { since = 0, per = {} }
  return c.fishSkill
end

-- ------------------------------------------------------------------ stats
function M:OnLoot(_, kind, items)
  if kind ~= "fish" or type(items) ~= "table" then return end
  for _, it in ipairs(items) do
    local n = it.count or 1
    self.stats.catches = self.stats.catches + n
    local name = it.name or (C.ItemInfo(it.id) or {}).name
    if it.id then
      local f = self.stats.fish[it.id] or { n = 0, name = name }
      f.n, f.name = f.n + n, f.name or name
      self.stats.fish[it.id] = f
    end
  end
  local s = self:Char()
  s.since = (s.since or 0) + 1
end

function M:OnCast(_, unit, _, spellID)
  if unit ~= "player" then return end
  local info = C.Call("C_Spell.GetSpellInfo", spellID)
  if readable(type(info) == "table" and info.name or nil) == "Fishing" then self.stats.casts = self.stats.casts + 1 end
end

function M:OnError(_, _, message)
  local escaped = rawget(_G, "ERR_FISH_ESCAPED") or rawget(_G, "FISH_ESCAPED")
  if type(message) == "string" and ((escaped and message == escaped) or message:lower():find("got away", 1, true)) then
    self.stats.escapes = self.stats.escapes + 1
  end
end

-- "Your skill in Fishing has increased to 87."
function M:OnSkill(_, msg)
  msg = readable(msg)
  if type(msg) ~= "string" or not msg:find("Fishing", 1, true) then return end
  local s = self:Char()
  if (s.since or 0) > 0 then
    table.insert(s.per, 1, s.since)
    for i = M.KEEP_POINTS + 1, #s.per do s.per[i] = nil end
  end
  s.since = 0
end

-- catches still to go to the next point, from your last few points (nil until measured)
function M:NextPoint()
  local s = self:Char()
  if #s.per < 2 then return nil end
  local sum = 0
  for _, n in ipairs(s.per) do sum = sum + n end
  local avg = sum / #s.per
  return math.max(0, math.ceil(avg - (s.since or 0))), avg
end

function M:Rate()
  local st = self.stats
  if st.casts == 0 then return nil end
  return math.floor(math.min(st.catches, st.casts) / st.casts * 100 + 0.5)
end

-- ------------------------------------------------------------------ advice
function M.Data() return ns.FishingData end

function M:Skill()
  if ns.FishingHUD and ns.FishingHUD.Skill then return ns.FishingHUD:Skill() end
end

function M:Tier(skill)
  local d = M.Data()
  for _, t in ipairs(d and d.tiers or {}) do
    if (skill or 0) >= t.lo and (skill or 0) < t.hi then return t end
  end
  return d and d.tiers[#d.tiers]
end

-- the next training step, or nil: { title, how, ready, why }
function M:Milestone(skill, max, level)
  local d = M.Data()
  for _, m in ipairs(d and d.milestones or {}) do
    if max and max <= m.max then
      local ready = (skill or 0) >= m.need and (level or 1) >= m.level
      local why = ready and "You're ready now." or string.format("Needs Fishing %d and level %d (you: %d, level %d).", m.need, m.level, skill or 0, level or 1)
      return { title = m.title, how = m.how, ready = ready, why = why, npc = m.npc, zone = m.zone, fish = m.fish }
    end
  end
end

-- what you've caught in a zone (by name), from the catch log
function M:CaughtIn(zone)
  local maps = ns.Travel and ns.Travel.ZoneMaps and ns.Travel:ZoneMaps() or nil
  local out, total = {}, 0
  for mapID, fish in pairs(ns.db.global.fishing or {}) do
    local info = C.Call("C_Map.GetMapInfo", mapID)
    local name = type(info) == "table" and readable(info.name)
    if name == zone then
      for id, n in pairs(fish) do
        local f = self.stats.fish[id]
        local nm = (f and f.name) or ((C.ItemInfo(id) or {}).name) or ("item " .. id)
        out[#out + 1] = { name = nm, n = n }
        total = total + n
      end
    end
  end
  table.sort(out, function(a, b) return a.n > b.n end)
  return out, total, maps
end

-- trainers or vendors for your faction: { {name, zone, where} }
function M:People(kind)
  local d = M.Data()
  local faction = C.Call("UnitFactionGroup", "player")
  local out = {}
  for _, p in ipairs(d and d[kind] or {}) do
    if p[4] == nil or p[4] == faction then out[#out + 1] = { name = p[1], zone = p[2], where = p[3] } end
  end
  return out
end

-- where an NPC stands, from the NPC pack or what Outrider discovered
function M.Place(name)
  local pack = rawget(_G, "Outrider_DataNPC")
  if not pack and ns.NPCPack and ns.NPCPack.Load then pcall(ns.NPCPack.Load, ns.NPCPack) pack = rawget(_G, "Outrider_DataNPC") end
  for mapID, list in pairs(pack and pack.maps or {}) do
    for _, e in ipairs(list) do
      if e[5] == name then return mapID, e[3], e[4] end
    end
  end
  for _, p in pairs(ns.db.global.pois or {}) do
    if type(p) == "table" and p.name == name and p.mapID then return p.mapID, p.x, p.y end
  end
end

function M:Go(name)
  local mapID, x, y = M.Place(name)
  if not (mapID and ns.Waypoints) then return false end
  ns.Waypoints:Set(mapID, x, y, name)
  return true
end

-- ------------------------------------------------------------------ gear
local function itemID(link) return link and tonumber(tostring(link):match("item:(%d+)")) end

local function isPole(id)
  local get = C.Resolve("C_Item.GetItemInfoInstant") or rawget(_G, "GetItemInfoInstant")
  if type(get) ~= "function" or not id then return false end
  local ok, _, _, _, _, _, class, subclass = pcall(get, id)
  return ok and class == POLE_CLASS and subclass == POLE_SUBCLASS
end

-- the Fishing bonus an item gives, from its tooltip ("+5 Fishing" / "Increased Fishing +5")
function M.FishingBonus(id)
  local get = C.Resolve("C_TooltipInfo.GetItemByID")
  if type(get) ~= "function" or not id then return 0 end
  local ok, data = pcall(get, id)
  local best = 0
  for _, line in ipairs(ok and type(data) == "table" and data.lines or {}) do
    local t = readable(line.leftText)
    if type(t) == "string" and t:find("Fishing", 1, true) then
      local n = tonumber(t:match("%+(%d+)")) or tonumber(t:match("(%d+)"))
      if n and n > best then best = n end
    end
  end
  return best
end

-- the best pole and Fishing-bonus pieces in your bags: { [slot] = {bag, slot, id, bonus} }
function M:BestGear()
  local out = {}
  for bag = 0, 4 do
    for slot = 1, (C.Call("C_Container.GetContainerNumSlots", bag) or 0) do
      local info = C.Call("C_Container.GetContainerItemInfo", bag, slot)
      local id = type(info) == "table" and readable(info.itemID)
      if id then
        local bonus = M.FishingBonus(id)
        if isPole(id) then
          if not out[16] or bonus > out[16].bonus then out[16] = { bag = bag, slot = slot, id = id, bonus = bonus } end
        elseif bonus > 0 then
          local equip = (C.ItemInfo(id) or {}).equipLoc
          local map = { INVTYPE_HEAD = 1, INVTYPE_CHEST = 5, INVTYPE_ROBE = 5, INVTYPE_WRIST = 9, INVTYPE_HAND = 10, INVTYPE_FEET = 8 }
          local s = map[equip or ""]
          if s and (not out[s] or bonus > out[s].bonus) then out[s] = { bag = bag, slot = slot, id = id, bonus = bonus } end
        end
      end
    end
  end
  return out
end

function M:GearOn()
  if C.InCombat() then return false, "not in combat" end
  local best = self:BestGear()
  if not next(best) then return false, "no fishing pole or fishing gear in your bags" end
  local before = {}
  for slot in pairs(best) do before[slot] = itemID(C.Call("GetInventoryItemLink", "player", slot)) end
  if best[16] then before[17] = itemID(C.Call("GetInventoryItemLink", "player", 17)) end
  ns.db.char.preFishing = before
  local equip = C.Resolve("C_Item.EquipItemByName") or rawget(_G, "EquipItemByName")
  if type(equip) ~= "function" then return false, "can't equip on this client" end
  local n = 0
  for slot, g in pairs(best) do
    if pcall(equip, "item:" .. g.id, slot) then n = n + 1 end
  end
  self:Info("fishing gear on: %d items", n)
  return true
end

function M:GearOff()
  if C.InCombat() then return false, "not in combat" end
  local before = ns.db.char.preFishing
  if type(before) ~= "table" or not next(before) then return false, "nothing to put back" end
  local equip = C.Resolve("C_Item.EquipItemByName") or rawget(_G, "EquipItemByName")
  if type(equip) ~= "function" then return false, "can't equip on this client" end
  for slot, id in pairs(before) do
    if id then pcall(equip, "item:" .. id, slot) end
  end
  ns.db.char.preFishing = nil
  return true
end

-- ------------------------------------------------------------------ extravaganza
-- seconds to the next start, and whether it's on now (server time)
function M:Extravaganza(now)
  local e = M.Data() and M.Data().extravaganza
  if not e then return nil end
  local t
  if not now then
    -- the realm's own clock (the event runs on realm time), else this PC's
    local cal = C.Call("C_DateAndTime.GetCurrentCalendarTime")
    if type(cal) == "table" and readable(cal.weekday) and readable(cal.hour) then
      t = { wday = cal.weekday, hour = cal.hour, min = cal.minute or 0, sec = 0 }
    end
  end
  t = t or date("*t", now or time())
  local secsToday = t.hour * 3600 + t.min * 60 + t.sec
  local start = e.startHour * 3600
  local days = (e.wday - t.wday) % 7
  if days == 0 and secsToday >= e.endHour * 3600 then days = 7 end
  if days == 0 and secsToday >= start then return 0, true, e end
  return days * 86400 + start - secsToday, false, e
end

-- ------------------------------------------------------------------ module
function M:OnEnable()
  self:On("OTR_LOOT", self.OnLoot)
  self:On("UNIT_SPELLCAST_SUCCEEDED", self.OnCast)
  self:On("UI_ERROR_MESSAGE", self.OnError)
  self:On("CHAT_MSG_SKILL", self.OnSkill)
end

function M:Activity()
  local st = self.stats
  return string.format("%d casts, %d fish caught (lifetime)", st.casts, st.catches)
end

-- ------------------------------------------------------------------ page
local function clock(secs)
  if secs >= 86400 then return string.format("%dd %dh", math.floor(secs / 86400), math.floor(secs % 86400 / 3600)) end
  return string.format("%dh %02dm", math.floor(secs / 3600), math.floor(secs % 3600 / 60))
end

ns.Hub:AddTab("fishing", "Fishing", function(p)
  local UI = ns.UI
  local function act(fn) return function() local ok, why = fn() M.status = ok and nil or why p:Refresh() end end
  UI:FormPage(p, {
    { "header", "Fishing" },
    { "stats", function()
      local skill, max = M:Skill()
      local lvl = tonumber(C.Readable(C.Call("UnitLevel", "player")))
      local nxt = skill and M:Milestone(skill, max, lvl)
      return {
        { cap = "Fishing skill", value = skill and (skill .. " / " .. (max or "?")) or "—", color = "gold",
          fill = skill and max and max > 0 and skill / max or nil },
        { cap = "Next step", value = nxt and nxt.title or (skill and max and skill >= max and "Train the next rank" or "Keep fishing"),
          note = nxt and nxt.how or nil },
      }
    end },
    { "header", "Your fishing", icon = "Trade_Fishing" },
    { "tiles", function()
      local skill, max = M:Skill()
      local st = M.stats
      local nxt = M:NextPoint()
      local level = tonumber(C.Call("UnitLevel", "player")) or 1
      local m = M:Milestone(skill, max, level)
      local out = {
        { ok = true, icon = "Interface\\Icons\\Trade_Fishing", text = skill and string.format("Fishing %d / %d", skill, max or 0) or "Fishing not learned yet" },
        { ok = true, icon = "Interface\\Icons\\INV_Misc_Fish_02", text = string.format("%d fish in %d casts (%s caught)", st.catches, st.casts, M:Rate() and (M:Rate() .. "%") or "?") },
        { ok = nxt ~= nil, icon = "Interface\\Icons\\Spell_Holy_SurgeOfLight",
          text = nxt and string.format("About %d more catches to the next point", nxt) or "Next point: measured after two skill-ups" },
      }
      if m then out[#out + 1] = { ok = m.ready, icon = "Interface\\Icons\\INV_Misc_Book_09", text = m.title .. (m.ready and ": ready" or ": not yet") } end
      return out
    end },
    { "note", function()
      local skill, max = M:Skill()
      local m = M:Milestone(skill, max, tonumber(C.Call("UnitLevel", "player")) or 1)
      local t = m and (m.title .. ". " .. m.how .. " " .. m.why) or ""
      if M.status then t = t .. "\n|cffff7f7f" .. M.status .. "|r" end
      return t
    end },
    { "header", "Where to fish now", icon = "INV_Misc_Map_01" },
    { "cards", function()
      local skill = M:Skill() or 1
      local t = M:Tier(skill)
      local out = {}
      if not t then return out end
      for _, zone in ipairs(t.zones) do
        local fish, total = M:CaughtIn(zone)
        local parts = {}
        for i, f in ipairs(fish) do
          if i > 4 then break end
          parts[#parts + 1] = string.format("%s %d%%", f.name, math.floor(f.n / total * 100 + 0.5))
        end
        out[#out + 1] = { pic = "Interface\\Icons\\INV_Misc_Fish_14", title = zone,
          tags = { { string.format("Fishing %d-%d", t.lo, t.hi), "plain" }, { t.lure, "gold" } },
          line = #parts > 0 and ("You've caught: " .. table.concat(parts, ", ")) or "Not fished here yet: what bites is logged as you fish." }
      end
      return out
    end },
    { "note", function() local t = M:Tier(M:Skill() or 1) return t and (t.note .. " Zones from the WoW Forever fishing guide (unverified).") or "" end },
    { "header", "Fishing gear", icon = "INV_Fishingpole_02" },
    { "buttons", { { "Fishing gear on", act(function() return M:GearOn() end), 150 }, { "Usual gear back", act(function() return M:GearOff() end), 150 } } },
    { "note", "Puts on your best fishing pole and any gear with a Fishing bonus from your bags; Usual gear back puts back what you wore. Out of combat." },
    { "header", "Trainers and supplies", icon = "INV_Misc_Book_09" },
    { "cards", function()
      local out = {}
      for _, kind in ipairs({ "trainers", "vendors" }) do
        for i, x in ipairs(M:People(kind)) do
          if i > 6 then break end
          out[#out + 1] = { pic = "Interface\\Icons\\" .. (kind == "trainers" and "Trade_Fishing" or "INV_Misc_Bag_08"), title = x.name,
            tags = { { kind == "trainers" and "Trainer" or "Supplies", "plain" }, { x.zone, "plain" } }, line = x.where or "",
            actions = { { "Show the way", function() if not M:Go(x.name) then ns.Print("no location known for %s yet", x.name) end end, "Sets the arrow to " .. x.name .. "." } } }
        end
      end
      return out
    end },
    { "header", "Stranglethorn Fishing Extravaganza", icon = "INV_Misc_Fish_31" },
    { "note", function()
      local secs, on, e = M:Extravaganza()
      if not e then return "" end
      local head = on and "|cff7fff7fIt's on now|r in " .. e.where .. "." or ("Next one in " .. clock(secs) .. " (Sundays " .. e.startHour .. ":00-" .. e.endHour .. ":00 server time).")
      return head .. " Catch Speckled Tastyfish in Stranglethorn Vale and bring them to Riggle Bassbait in Booty Bay (Classic rules and schedule; unverified on Forever)."
    end },
    { "header", "Fish you've caught", icon = "INV_Misc_Fish_02" },
    { "note", function()
      local list = {}
      for _, f in pairs(M.stats.fish) do list[#list + 1] = f end
      table.sort(list, function(a, b) return a.n > b.n end)
      local parts = {}
      for i, f in ipairs(list) do if i > 20 then break end parts[#parts + 1] = string.format("%s x%d", tostring(f.name or "?"), f.n) end
      return #parts > 0 and table.concat(parts, ", ") or "Nothing yet. Every catch is kept here for all your characters."
    end },
  })
end)
