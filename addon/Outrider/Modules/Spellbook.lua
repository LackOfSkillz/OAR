-- Modules/Spellbook.lua  (P4-02)
-- Which spells this character knows: { [lowercase name] = { name, id, rank } },
-- keeping the highest rank per name. Modern C_SpellBook first (present on
-- Forever, probe 2026-11-11), Classic spell tabs as fallback. Refreshed on
-- SPELLS_CHANGED / LEARNED_SPELL_IN_TAB (throttled). Saved per character in
-- ns.db.char.spellbook so Claude can read it from the SavedVariables file
-- (auto-collected; also what RankCheck in P4-06 compares against).
-- Pack macros use English spell names; Known(name) answers by name.

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("Spellbook", {
  title = "Spellbook reader",
  phase = "P4",
  order = 60,
  defaults = {},
})
ns.Spellbook = M

M.spells = {}

local function rankOf(sub)
  return tonumber(type(sub) == "string" and sub:match("(%d+)") or nil)
end

function M:Add(out, name, id, sub)
  name = C.Readable(name)
  if type(name) ~= "string" or name == "" then return end
  local key = name:lower()
  local rank = rankOf(C.Readable(sub))
  local cur = out[key]
  if not cur or (rank or 0) > (cur.rank or 0) then out[key] = { name = name, id = id, rank = rank } end
end

function M:ScanModern(out)
  local SB = rawget(_G, "C_SpellBook")
  if not (SB and SB.GetNumSpellBookSkillLines and SB.GetSpellBookSkillLineInfo and SB.GetSpellBookItemInfo) then return false end
  local bank = (Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player) or 0
  local lines = SB.GetNumSpellBookSkillLines() or 0
  for i = 1, lines do
    local line = SB.GetSpellBookSkillLineInfo(i)
    if type(line) == "table" and not line.shouldHide then
      local first = (line.itemIndexOffset or 0) + 1
      for idx = first, first + (line.numSpellBookItems or 0) - 1 do
        local info = SB.GetSpellBookItemInfo(idx, bank)
        if type(info) == "table" and info.spellID and not info.isPassive then
          self:Add(out, info.name, info.spellID, info.subName)
        end
      end
    end
  end
  return true
end

function M:ScanClassic(out)
  if not (rawget(_G, "GetNumSpellTabs") and rawget(_G, "GetSpellTabInfo") and rawget(_G, "GetSpellBookItemName")) then return false end
  for tab = 1, GetNumSpellTabs() do
    local _, _, offset, num = GetSpellTabInfo(tab)
    for i = (offset or 0) + 1, (offset or 0) + (num or 0) do
      local name, sub = GetSpellBookItemName(i, "spell")
      local _, id = C.Call("GetSpellBookItemInfo", i, "spell")
      self:Add(out, name, id, sub)
    end
  end
  return true
end

function M:Scan()
  local out = {}
  local how = "none"
  local ok, done = pcall(self.ScanModern, self, out)
  if ok and done then how = "C_SpellBook"
  else
    ok, done = pcall(self.ScanClassic, self, out)
    if ok and done then how = "classic" end
  end
  self.spells, self.source = out, how
  local n = 0
  for _ in pairs(out) do n = n + 1 end
  self.count = n
  ns.db.char.spellbook = { at = time(), source = how, spells = ns.CopyTable(out) }
  if n ~= self.lastLogged then
    self.lastLogged = n
    self:Info("spellbook: %d spells via %s", n, how)
  end
  return out
end

-- DEEP-20: no invented trainer costs or spell unlock levels. Until a
-- sourced class-training pack is shipped, cards use *observed* class-trainer
-- service info from this character's prior visits, across later level-ups.
-- This supports advance planning AFTER observation, but full independent
-- 1-60 coverage is a separate cited-data task.
function M:TrainingStore()
  ns.db.global.classTraining = ns.KeepTable(ns.db.global.classTraining, "Spellbook:ns.db.global.classTraining") or {}
  local class = ns.PlayerClass()
  ns.db.global.classTraining[class] = ns.db.global.classTraining[class] or {}
  return ns.db.global.classTraining[class]
end

-- The trainer's own list is the truth (bug 2026-11-21: Outrider's typed-in
-- list missed Backstab Rank 2, Parry and Sinister Strike Rank 3 and showed
-- Pick Lock at 1). GetTrainerServiceInfo's returns differ between clients:
-- on Forever the second value is the status ("available", "unavailable",
-- "used"), elsewhere it is the rank. Read them by what they look like.
M.STATUS = { available = true, unavailable = true, used = true }
function M.ParseService(...)
  local name, rank, status
  for i = 1, select("#", ...) do
    local v = C.Readable((select(i, ...)))
    if type(v) == "string" then
      if i == 1 then name = v
      elseif M.STATUS[v] then status = v
      elseif v:find("%d") and not rank then rank = v end
    end
  end
  return name, rank, status
end

function M:ObserveTrainer()
  local num = tonumber(C.Readable(C.Call("GetNumTrainerServices")))
  local info = C.Resolve("GetTrainerServiceInfo")
  local price = C.Resolve("GetTrainerServiceCost")
  local levelOf = C.Resolve("GetTrainerServiceLevelReq")
  local iconOf = C.Resolve("GetTrainerServiceIcon")
  -- Profession trainers belong to ProfExtras; this list is class spells only.
  if C.Readable(C.Call("IsTradeskillTrainer")) then return 0 end
  if not (num and num > 0 and type(info) == "function" and type(levelOf) == "function") then
    self:Info("class training: trainer has no readable service list")
    return 0
  end
  -- the filter can hide learned or too-high spells: the full list needs them all
  local saved, n = self:TrainingStore(), 0
  for key, r in pairs(saved) do
    -- older saves keyed by "name:available": drop them, this visit rewrites the list
    if M.STATUS[tostring(r.rank or "")] and ns.Archive:Put("trainingOldFormat", r, { path = "global.classTraining[key]", keys = { key = key } }) then saved[key] = nil end
  end
  for i = 1, math.min(300, num) do
    local packed = { pcall(info, i) }
    local ok = table.remove(packed, 1)
    local name, rank, status = M.ParseService(unpack(packed))
    local okLevel, reqLevel = pcall(levelOf, i)
    reqLevel = okLevel and tonumber(C.Readable(reqLevel)) or nil
    local copper = type(price) == "function" and select(2, pcall(price, i)) or nil
    copper = tonumber(C.Readable(copper))
    local icon = type(iconOf) == "function" and C.Readable(select(2, pcall(iconOf, i))) or nil
    if not self.signatureLogged and ok then
      self.signatureLogged = true
      self:Info("trainer service 1 returns: %s", table.concat((function()
        local t = {} for j, v in ipairs(packed) do t[j] = type(v) .. "=" .. tostring(C.Readable(v)) end return t end)(), ", "))
    end
    -- category headers have no level; skip them
    if ok and type(name) == "string" and name ~= "" and reqLevel and reqLevel >= 1 and reqLevel <= 80 then
      local key = name:lower() .. ":" .. (rank or ("level " .. reqLevel))
      saved[key] = { name = name, rank = rank, level = reqLevel, status = status, cost = copper, icon = icon,
        observedAt = time(), source = "your class trainer", charKey = ns.db.key }
      n = n + 1
    end
  end
  if n > 0 then
    self:Info("class training: %d services read from the trainer", n)
    ns.Events:Fire("OTR_TRAINER_READ", n)
  end
  return n
end

-- The class page's lists from what the trainer showed: ready now (your level
-- or lower, not learned), coming next (the next two levels with spells), the
-- next level, and whether anything was observed at all.
-- Has this character learned a trainer row? The list is kept for the class
-- (every druid sees the same trainer), but what one character learned isn't
-- another's (bug 2026-11-23: Sheer had learned everything to 10 and the
-- page said 20 spells to learn, from a visit before she learned them). The
-- spellbook decides: a spell you know counts as learned, unless the book
-- shows a lower rank than the row.
function M:Learned(r)
  local k = self:Known(r.name)
  if not k then return r.status == "used" and r.charKey == ns.db.key end
  local want = rankOf(r.rank)
  if want and k.rank and k.rank < want then return false end
  return true
end

function M:TrainerLists(level)
  level = tonumber(level) or tonumber(C.Readable(C.Call("UnitLevel", "player"))) or 1
  local now, later = {}, {}
  local any = false
  -- the same spell saved with and without its rank (two client readings): keep the ranked one
  local ranked = {}
  for _, r in pairs(self:TrainingStore()) do
    if type(r) == "table" and r.name and r.level and r.rank then ranked[r.name:lower() .. ":" .. r.level] = true end
  end
  for _, r in pairs(self:TrainingStore()) do
    if type(r) == "table" and r.name and r.level and not M.STATUS[tostring(r.rank or "")]
      and not (not r.rank and ranked[r.name:lower() .. ":" .. r.level]) then
      any = true
      local learned = self:Learned(r)
      local label = r.rank and (r.name .. " (" .. r.rank .. ")") or r.name
      local e = { name = label, level = r.level, icon = r.icon, cost = r.cost }
      if not learned and r.level <= level then now[#now + 1] = e
      elseif not learned and r.level > level then later[#later + 1] = e end
    end
  end
  local byLevel = function(a, b) if a.level ~= b.level then return a.level < b.level end return a.name < b.name end
  table.sort(now, byLevel)
  table.sort(later, byLevel)
  local soon, levels = {}, {}
  for _, sp in ipairs(later) do
    if not levels[sp.level] then levels[sp.level] = true levels[#levels + 1] = sp.level end
    if #levels <= 2 then soon[#soon + 1] = sp end
  end
  return now, soon, levels[1], any
end

function M:TrainingAt(level)
  level = tonumber(level) or tonumber(C.Readable(C.Call("UnitLevel", "player"))) or 1
  local rows = {}
  for _, r in pairs(self:TrainingStore()) do
    if r.level == level and not self:Learned(r) then rows[#rows + 1] = r end
  end
  table.sort(rows, function(a, b) return a.name < b.name end)
  return rows
end

function M:TrainingNotice(level)
  local rows = self:TrainingAt(level)
  if #rows == 0 then return end
  local cost = 0
  for _, r in ipairs(rows) do cost = cost + r.cost end
  ns.Toast:Show({ title = "Trainer options at level " .. level,
    text = string.format("%d observed class-training options, total %s. Check a trainer; costs may change.",
      #rows, ns.Prices.Money(cost)), color = "good", duration = 14 })
end

ns.AddCommand("training", "training [level]  spells observed at your class trainer", function(arg)
  local level = tonumber(arg) or tonumber(C.Readable(C.Call("UnitLevel", "player"))) or 1
  local rows = M:TrainingAt(level)
  if #rows == 0 then ns.Print("training level %d: no *observed* unlearned spells in data yet; no independent training pack installed", level) return end
  for i = 1, math.min(#rows, 25) do
    local x = rows[i]
    ns.Print("%s%s at level %d: %s (seen at trainer, cost may change)",
      x.name, type(x.rank) == "string" and (" " .. x.rank) or "", level, ns.Prices.Money(x.cost))
  end
end)

function M:OnEnable()
  self:On("SPELLS_CHANGED", function(mod) ns.Throttle("spellbook", 0.5, function() mod:Scan() end) end)
  -- the service list fills in just after the window opens
  self:On("TRAINER_SHOW", function(mod) ns.Timer.After(0.3, function() mod:ObserveTrainer() end, "spellbook:trainer") end)
  self:On("TRAINER_UPDATE", function(mod) ns.Throttle("spellbook:trainerupdate", 0.5, function() mod:ObserveTrainer() end) end)
  self:On("PLAYER_LEVEL_UP", function(mod, _, level) mod:TrainingNotice(level) end)
  -- (LEARNED_SPELL_IN_TAB does not exist on Forever; SPELLS_CHANGED covers learning)
  self:On("PLAYER_ENTERING_WORLD", function(mod) mod:Scan() end)
end

function M:OnDisable() ns.ThrottleCancel("spellbook") end

-- entry or nil
function M:Known(name)
  return type(name) == "string" and self.spells[name:lower()] or nil
end

function M:Activity()
  return string.format("%d spells known (%s)", self.count or 0, tostring(self.source or "not scanned"))
end

ns.AddCommand("spells", "[filter]  list the spells Outrider sees in your spellbook", function(arg)
  local list = {}
  for _, s in pairs(M.spells) do
    if not arg or s.name:lower():find(arg:lower(), 1, true) then list[#list + 1] = s end
  end
  table.sort(list, function(a, b) return a.name < b.name end)
  ns.Print("%d spells%s:", #list, arg and (" matching " .. arg) or "")
  for i = 1, math.min(#list, 30) do
    local s = list[i]
    ns.Print("  %s%s (%s)", s.name, s.rank and (" rank " .. s.rank) or "", tostring(s.id))
  end
end)
