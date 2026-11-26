-- Modules/PlayerInfo.lua
-- Extra lines on other players' tooltips (requirement 2026-11-17: the same
-- speed and other details creature and pet tooltips already show, for
-- players):
--   live        attack speed, max health and mana/energy/rage, PvP flag and rank
--   remembered  professions they linked in trade chat (Census), when and where
--               we last saw them, "your alt"
--   inspect     average item level, gear quality, weapon, talent build
-- Inspect: one NotifyInspect per hover, out of combat, in range, at most one
-- every few seconds, never while Blizzard's inspect window is open; results
-- cached per player for the session. NotifyInspect is a plain query (no
-- protected action), the same one gear-score addons use. Other players'
-- stats (strength, agility...) are not readable, so none are shown.
-- Secret values (C6) are skipped, never guessed.

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("PlayerInfo", {
  title = "Player tooltips",
  phase = "P7",
  order = 39,
  defaults = { inspect = true, odds = true },
  yieldsTo = { "TipTac", "TinyTooltip" },
})
ns.PlayerInfo = M

M.GAP = 3          -- seconds between inspect requests
M.KEEP = 15 * 60   -- seconds an inspect result is kept
M.SLOTS = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 }
M.POWER = { [0] = "mana", [1] = "rage", [2] = "focus", [3] = "energy" }

local function readable(v) return C.Readable(v) end

function M:OnInitialize()
  self.cache, self.lastAsk = {}, 0
end

-- ------------------------------------------------------------------ lines
local function ago(secs)
  if secs < 3600 then return string.format("%d min ago", math.max(1, math.floor(secs / 60))) end
  if secs < 86400 then return string.format("%d h ago", math.floor(secs / 3600)) end
  return string.format("%d days ago", math.floor(secs / 86400))
end
M.Ago = ago

local function big(n)
  if n >= 10000 then return string.format("%.1fk", n / 1000) end
  return tostring(math.floor(n))
end

function M:FullName(unit)
  local name, realm = C.Call("UnitName", unit)
  name, realm = readable(name), readable(realm)
  if not name then return nil end
  return ns.Census and ns.Census.FullName(name, realm) or name
end

-- Lines for a player unit (pure apart from reads; testable). nil/{} for anyone else.
function M:Lines(unit)
  if not readable(C.Call("UnitExists", unit)) or not readable(C.Call("UnitIsPlayer", unit)) then return {} end
  if readable(C.Call("UnitIsUnit", unit, "player")) then return {} end
  local lines = {}
  -- live numbers
  local parts = {}
  local speed = readable(C.Call("UnitAttackSpeed", unit))
  if type(speed) == "number" and speed > 0 then parts[#parts + 1] = string.format("attacks every %.1fs", speed) end
  local hp = readable(C.Call("UnitHealthMax", unit))
  if type(hp) == "number" and hp > 0 then parts[#parts + 1] = big(hp) .. " health" end
  local ptype = readable(C.Call("UnitPowerType", unit))
  local pmax = readable(C.Call("UnitPowerMax", unit))
  if type(pmax) == "number" and pmax > 0 and M.POWER[ptype] then parts[#parts + 1] = big(pmax) .. " " .. M.POWER[ptype] end
  if #parts > 0 then
    local s = table.concat(parts, " · ")
    lines[#lines + 1] = { s:sub(1, 1):upper() .. s:sub(2), "text" }
  end
  -- PvP
  local pvp = {}
  if readable(C.Call("UnitIsPVP", unit)) then pvp[#pvp + 1] = "PvP flagged" end
  local rank = readable(C.Call("UnitPVPRank", unit))
  if type(rank) == "number" and rank >= 5 then
    local title = readable(C.Call("GetPVPRankInfo", rank, unit))
    if type(title) == "string" and title ~= "" then pvp[#pvp + 1] = "rank: " .. title end
  end
  if #pvp > 0 then lines[#lines + 1] = { pvp[1]:sub(1, 1):upper() .. table.concat(pvp, ", "):sub(2), "warn" } end
  -- remembered
  local full = self:FullName(unit)
  local g = ns.db.global
  if full and type(g.alts) == "table" and g.alts[full] then lines[#lines + 1] = { "Your alt", "good" } end
  local cen = ns.Census and ns.Census.store and ns.Census:Realm()
  if full and cen then
    local profs = {}
    for prof in pairs(cen.profs[full] or {}) do profs[#profs + 1] = prof end
    table.sort(profs)
    if #profs > 0 then lines[#lines + 1] = { "Professions: " .. table.concat(profs, ", "), "accent" } end
    local p = cen.players[full]
    local seen = self.seenBefore and self.seenBefore[full]
    if seen and seen.t and time() - seen.t > 300 then
      lines[#lines + 1] = { "Last seen " .. ago(time() - seen.t) .. (seen.z and (" in " .. seen.z) or ""), "muted" }
    elseif not seen and p then
      -- remember what we knew before this hover (Census updates it as we look)
      self.seenBefore = self.seenBefore or {}
      self.seenBefore[full] = { t = p.t, z = p.z }
      if p.t and time() - p.t > 300 then
        lines[#lines + 1] = { "Last seen " .. ago(time() - p.t) .. (p.z and (" in " .. p.z) or ""), "muted" }
      end
    end
  end
  -- inspect
  local guid = readable(C.Call("UnitGUID", unit))
  local info = guid and self.cache[guid]
  if info and time() - info.t < M.KEEP then
    for _, l in ipairs(self:InspectLines(info)) do lines[#lines + 1] = l end
  elseif guid and self:Settings().inspect then
    if self:Ask(unit, guid) then lines[#lines + 1] = { "Looking at their gear...", "muted" } end
  end
  if self:Settings().odds ~= false then
    local ok, line = pcall(self.OddsLine, self, unit, info and time() - info.t < M.KEEP and info or nil)
    if ok and line then lines[#lines + 1] = line end
  end
  return lines
end

function M:InspectLines(info)
  local out = {}
  if info.ilvl then
    local q = {}
    for _, k in ipairs({ { 4, "epic" }, { 3, "rare" }, { 2, "uncommon" } }) do
      local n = info.quality[k[1]]
      if n and n > 0 then q[#q + 1] = n .. " " .. k[2] end
    end
    out[#out + 1] = { string.format("Item level %.1f average%s", info.ilvl, #q > 0 and (" · " .. table.concat(q, ", ")) or ""), "goldText" }
  end
  if info.weapon then out[#out + 1] = { "Weapon: " .. info.weapon, "text" } end
  if info.build then out[#out + 1] = { "Talents: " .. info.build, "accent" } end
  return out
end

-- ------------------------------------------------------------------ inspect
function M:CanAsk(unit)
  if C.InCombat() then return false end
  local frame = rawget(_G, "InspectFrame")
  if frame and frame.IsShown and frame:IsShown() then return false end
  if not readable(C.Call("CanInspect", unit)) then return false end
  if C.Resolve("CheckInteractDistance") and not readable(C.Call("CheckInteractDistance", unit, 1)) then return false end
  return (GetTime and GetTime() or time()) - (self.lastAsk or 0) >= M.GAP
end

function M:Ask(unit, guid)
  if self.pending == guid then return true end
  if not self:CanAsk(unit) then return false end
  local ok = pcall(NotifyInspect, unit)
  if not ok then return false end
  self.pending, self.pendingUnit = guid, unit
  self.lastAsk = GetTime and GetTime() or time()
  return true
end

local function itemLevel(link)
  local lvl
  local detailed = C.Resolve("C_Item.GetDetailedItemLevelInfo") or C.Resolve("GetDetailedItemLevelInfo")
  if detailed then local ok, v = pcall(detailed, link) if ok then lvl = readable(v) end end
  local _, _, quality, base = C.Call("C_Item.GetItemInfo", link)
  if not lvl then _, _, quality, base = C.Call("GetItemInfo", link) end
  return tonumber(lvl or base), tonumber(quality)
end

-- Talent tab info comes in two shapes: Classic (name, icon, points, file) and
-- modern (id, name, description, icon, points, ...).
function M.TabInfo(...)
  local a, b = ...
  if type(a) == "number" and type(b) == "string" then return b, tonumber((select(5, ...))) end
  return a, tonumber((select(3, ...)))
end

function M:Read(unit, guid)
  local info = { t = time(), quality = {} }
  local sum, n = 0, 0
  for _, slot in ipairs(M.SLOTS) do
    local link = readable(C.Call("GetInventoryItemLink", unit, slot))
    if link then
      local lvl, q = itemLevel(link)
      if lvl and slot ~= 18 then sum, n = sum + lvl, n + 1 end
      if q then info.quality[q] = (info.quality[q] or 0) + 1 end
      if slot == 16 then info.weapon = link:match("%[(.-)%]") end
    end
  end
  if n > 0 then info.ilvl = sum / n end
  -- talents of the inspected player
  local tabs = tonumber(readable(C.Call("GetNumTalentTabs", true))) or 0
  local best, pts = nil, {}
  for t = 1, tabs do
    local ok, name, points = pcall(function() return M.TabInfo(GetTalentTabInfo(t, true)) end)
    if ok and type(name) == "string" then
      pts[#pts + 1] = tostring(points or 0)
      if points and (not best or points > best.points) then best = { name = name, points = points } end
    end
  end
  if best and best.points > 0 then
    local _, class = C.Call("UnitClass", unit)
    local cname = ns.Census and ns.Census.ClassName and ns.Census.ClassName(readable(class)) or ""
    info.build = string.format("%s %s (%s)", best.name, (cname or ""):lower(), table.concat(pts, "/"))
  end
  self.cache[guid] = info
  return info
end

-- Vanguard VG00-05: record what this inspect let us read (capability facts
-- only, no names or gear links), at most PROBE_MAX per session and once per
-- player. Runs before ClearInspectPlayer so the data is still there.
M.PROBE_MAX = 6
function M:ProbeInspect(guid)
  if not ns.Probe or not ns.Probe.Inspect or C.InCombat() then return end
  self.probed = self.probed or { n = 0 }
  if self.probed[guid] or self.probed.n >= M.PROBE_MAX then return end
  local unit, source, secs
  if guid == self.pending and self.pendingUnit and readable(C.Call("UnitGUID", self.pendingUnit)) == guid then
    unit, source = self.pendingUnit, "tooltip hover"
    secs = (GetTime and GetTime() or time()) - (self.lastAsk or 0)
  elseif guid == self.pending and readable(C.Call("UnitGUID", "mouseover")) == guid then
    unit, source = "mouseover", "tooltip hover"
    secs = (GetTime and GetTime() or time()) - (self.lastAsk or 0)
  else
    for _, u in ipairs({ "target", "mouseover" }) do
      if readable(C.Call("UnitGUID", u)) == guid then unit, source = u, "inspect window" break end
    end
  end
  if not unit then return end
  self.probed[guid] = true
  self.probed.n = self.probed.n + 1
  ns.Safe("PlayerInfo:ProbeInspect", ns.Probe.Inspect, ns.Probe, unit, source, secs)
end

function M:OnInspect(guid)
  guid = readable(guid)
  if guid then self:ProbeInspect(guid) end
  if not guid or guid ~= self.pending then return end
  local unit = self.pendingUnit
  self.pending, self.pendingUnit = nil, nil
  if not unit or readable(C.Call("UnitGUID", unit)) ~= guid then
    if readable(C.Call("UnitGUID", "mouseover")) == guid then unit = "mouseover" else return end
  end
  self:Read(unit, guid)
  self:Debug("inspected %s", tostring(self:FullName(unit)))
  local frame = rawget(_G, "InspectFrame")
  if not (frame and frame.IsShown and frame:IsShown()) and C.Resolve("ClearInspectPlayer") then pcall(ClearInspectPlayer) end
  -- refresh the tooltip if we're still pointing at them
  local tip = rawget(_G, "GameTooltip")
  if tip and tip:IsShown() and readable(C.Call("UnitGUID", "mouseover")) == guid and tip.SetUnit then
    pcall(tip.SetUnit, tip, "mouseover")
  end
end

ns.TooltipLines:Add("unit", "player", M, function(tip, data)
  local unit = "mouseover"
  if tip and tip.GetUnit then
    local ok, _, u = pcall(tip.GetUnit, tip)
    if ok and readable(u) then unit = u end
  end
  return M:Lines(unit)
end)

-- ------------------------------------------------------------------ PvP odds
-- (requirement 2026-11-17: the likely outcome of a PvP fight against that
-- player) A rough estimate, labelled as one. It
-- adds up what Outrider can measure, as a logistic score:
--   level gap      0.45 per level (capped at 8); a "??" skull level is ~2%
--   health         2 x log(your max health / theirs)
--   item level     0.12 per point of average item level (once inspected)
--   class matchup  +/-0.35 from common Classic PvP wisdom (MATCHUP, unverified)
--   your duels     past duel results with them pull it toward what happened
-- Nothing here is game data; the weights are a starting guess that Gary's
-- own duel record can correct later.
M.MATCHUP = {
  WARLOCK = { WARRIOR = 1, ROGUE = 1, PALADIN = 1, HUNTER = 1 },
  MAGE = { WARRIOR = 1, HUNTER = 1, PALADIN = 1 },
  ROGUE = { MAGE = 1, PRIEST = 1, DRUID = 1 },
  PRIEST = { WARRIOR = 1, ROGUE = 1 },
  HUNTER = { WARRIOR = 1, PALADIN = 1, SHAMAN = 1 },
  DRUID = { WARRIOR = 1, SHAMAN = 1 },
  SHAMAN = { ROGUE = 1, WARRIOR = 1 },
  PALADIN = { WARRIOR = 1, ROGUE = 1 },
}
M.W = { level = 0.45, levelCap = 8, health = 2, ilvl = 0.12, class = 0.35 }

function M.Matchup(mine, theirs)
  if not mine or not theirs or mine == theirs then return 0 end
  if M.MATCHUP[mine] and M.MATCHUP[mine][theirs] then return 1 end
  if M.MATCHUP[theirs] and M.MATCHUP[theirs][mine] then return -1 end
  return 0
end

-- Pure: a = you, b = them: { level, hp, ilvl, class }; record = { w, l } or nil.
-- Returns percent you win (1..99) and a short list of reasons.
function M.Odds(a, b, record)
  local W, score, why = M.W, 0, {}
  if b.level == -1 then return 2, { "they're far above you (??)" } end
  if type(a.level) == "number" and type(b.level) == "number" then
    local d = math.max(-W.levelCap, math.min(W.levelCap, a.level - b.level))
    score = score + d * W.level
    if d ~= 0 then why[#why + 1] = string.format("%+d level%s", d, math.abs(d) == 1 and "" or "s") end
  end
  if type(a.hp) == "number" and type(b.hp) == "number" and a.hp > 0 and b.hp > 0 then
    local r = math.log(a.hp / b.hp)
    score = score + r * W.health
    if math.abs(r) > 0.1 then why[#why + 1] = r > 0 and "more health" or "less health" end
  end
  if a.ilvl and b.ilvl then
    local d = a.ilvl - b.ilvl
    score = score + d * W.ilvl
    why[#why + 1] = math.abs(d) < 2 and "gear about even" or (d > 0 and "better gear" or "worse gear")
  end
  local m = M.Matchup(a.class, b.class)
  if m ~= 0 then
    score = score + m * W.class
    why[#why + 1] = m > 0 and "good class matchup" or "hard class matchup"
  end
  local p = 1 / (1 + math.exp(-score))
  if record and (record.w or 0) + (record.l or 0) > 0 then
    local games = (record.w or 0) + (record.l or 0)
    p = (p * 3 + (record.w or 0)) / (3 + games)
    why[#why + 1] = string.format("your duels %d-%d", record.w or 0, record.l or 0)
  end
  return math.max(1, math.min(99, math.floor(p * 100 + 0.5))), why
end

function M:Me()
  local now = time()
  if not self.me or now - self.me.t > 60 then
    local _, class = C.Call("UnitClass", "player")
    local info = self:Read("player", "me")
    self.cache.me = nil
    self.me = { t = now, class = readable(class), ilvl = info.ilvl }
  end
  self.me.level = readable(C.Call("UnitLevel", "player"))
  self.me.hp = readable(C.Call("UnitHealthMax", "player"))
  return self.me
end

function M:OddsLine(unit, info)
  local _, class = C.Call("UnitClass", unit)
  local them = { level = readable(C.Call("UnitLevel", unit)), hp = readable(C.Call("UnitHealthMax", unit)),
    class = readable(class), ilvl = info and info.ilvl }
  local me = self:Me()
  local full = self:FullName(unit)
  local rec = full and ns.db.global.duels and ns.db.global.duels[full]
  local pct, why = M.Odds({ level = me.level, hp = me.hp, class = me.class, ilvl = them.ilvl and me.ilvl }, them, rec)
  local color = pct >= 60 and "good" or pct <= 40 and "bad" or "warn"
  return { string.format("PvP odds (rough): you win %d%%%s", pct, #why > 0 and (" · " .. table.concat(why, ", ")) or ""), color }
end

-- Duel results from the system message ("X has defeated Y in a duel").
local function pattern(fmt)
  if type(fmt) ~= "string" then return nil end
  fmt = fmt:gsub("%%%d%$s", "%%s"):gsub("([%(%)%.%[%]%*%+%-%?%^%$])", "%%%1"):gsub("%%s", "(.+)")
  return "^" .. fmt .. "$"
end
M.DuelPattern = pattern

function M:OnSystem(_, msg)
  msg = readable(msg)
  if type(msg) ~= "string" or not msg:find("duel", 1, true) then return end
  local me = readable(C.Call("UnitName", "player"))
  for _, key in ipairs({ "DUEL_WINNER_KNOCKOUT", "DUEL_WINNER_RETREAT" }) do
    local pat = pattern(rawget(_G, key))
    local winner, loser
    if pat then winner, loser = msg:match(pat) end
    if winner and loser and (winner == me or loser == me) then
      local other = winner == me and loser or winner
      local full = ns.Census and ns.Census.FullName(other) or other
      local g = ns.db.global
      g.duels = ns.KeepTable(g.duels, "PlayerInfo:g.duels") or {}
      local r = g.duels[full] or { w = 0, l = 0 }
      if winner == me then r.w = r.w + 1 else r.l = r.l + 1 end
      r.t = time()
      g.duels[full] = r
      self:Info("duel with %s: %s (%d-%d)", full, winner == me and "won" or "lost", r.w, r.l)
      return
    end
  end
end

-- ------------------------------------------------------------------ rares and elites
-- (requirement 2026-11-17: the same for rare and elite
-- creatures) The same kind of rough estimate for a fight with a rare,
-- rare elite, elite or boss creature, labelled as one:
--   level gap      0.5 per level (capped at 8); "??" or a world boss is ~1%
--   health         1.6 x log(your side's health / its health), when readable
--   elite          -0.9 (elites hit harder than their health says)
--   your side      your pet counts as half of you; group members count fully
--   your record    fights you won or lost against this creature pull it
--                  toward what happened (win: it died while you fought it;
--                  loss: you died while it was your target)
M.MOB_W = { level = 0.5, levelCap = 8, health = 1.6, elite = 0.9 }
M.TOUGH = { elite = "elite", rareelite = "rare elite", rare = "rare", worldboss = "boss" }

-- Pure: a = you { level, hp, pet (0..1), group (>=1) }, b = it { level, hp, class };
-- record = { w, l } or nil. Returns percent you win (1..99) and reasons.
function M.MobOdds(a, b, record)
  local W, score, why = M.MOB_W, 0, {}
  if b.level == -1 or b.class == "worldboss" then return 1, { "far too strong (boss)" } end
  if type(a.level) == "number" and type(b.level) == "number" then
    local d = math.max(-W.levelCap, math.min(W.levelCap, a.level - b.level))
    score = score + d * W.level
    if d ~= 0 then why[#why + 1] = string.format("%+d level%s", d, math.abs(d) == 1 and "" or "s") end
  end
  local side = (a.group or 1) + (a.pet or 0)
  if side > 1 then why[#why + 1] = (a.group or 1) > 1 and string.format("%d in your group", a.group) or "your pet helps" end
  if type(a.hp) == "number" and type(b.hp) == "number" and a.hp > 0 and b.hp > 0 then
    local r = math.log(a.hp * side / b.hp)
    score = score + r * W.health
    why[#why + 1] = string.format("it has %.1fx your health", b.hp / a.hp)
  else
    score = score + math.log(side) * W.health
  end
  if b.class == "elite" or b.class == "rareelite" then
    score = score - W.elite
    why[#why + 1] = "elite"
  end
  local p = 1 / (1 + math.exp(-score))
  if record and (record.w or 0) + (record.l or 0) > 0 then
    local games = (record.w or 0) + (record.l or 0)
    p = (p * 3 + (record.w or 0)) / (3 + games)
    why[#why + 1] = string.format("your record %d-%d", record.w or 0, record.l or 0)
  end
  return math.max(1, math.min(99, math.floor(p * 100 + 0.5))), why
end

function M:MobRecord(npcID)
  local g = ns.db.global
  g.mobFights = ns.KeepTable(g.mobFights, "PlayerInfo:g.mobFights") or {}
  return g.mobFights, npcID and g.mobFights[npcID]
end

function M:MobLines(unit)
  if not readable(C.Call("UnitExists", unit)) or readable(C.Call("UnitIsPlayer", unit)) then return {} end
  local class = readable(C.Call("UnitClassification", unit))
  if not M.TOUGH[class] then return {} end
  if readable(C.Call("UnitIsDead", unit)) then return {} end
  if readable(C.Call("UnitPlayerControlled", unit)) then return {} end
  local npcID = C.UnitNpcID(unit)
  local prof = npcID and ns.db.global.rareProfiles and ns.db.global.rareProfiles[npcID]
  local hp = readable(C.Call("UnitHealthMax", unit))
  if not (type(hp) == "number" and hp > 0) then hp = prof and prof.hpMax end
  local level = readable(C.Call("UnitLevel", unit))
  local lines, parts = {}, {}
  if hp then parts[#parts + 1] = big(hp) .. " health" end
  local speed = readable(C.Call("UnitAttackSpeed", unit))
  if not (type(speed) == "number" and speed > 0) then speed = prof and prof.attackSpeed end
  if speed then parts[#parts + 1] = string.format("hits every %.1fs", speed) end
  local label = M.TOUGH[class]
  if #parts > 0 then lines[#lines + 1] = { label:sub(1, 1):upper() .. label:sub(2) .. ": " .. table.concat(parts, " · "), "text" } end
  local group = 1
  if readable(C.Call("IsInGroup")) then group = math.max(1, math.min(5, tonumber(readable(C.Call("GetNumGroupMembers"))) or 1)) end
  local pet = (readable(C.Call("UnitExists", "pet")) and not readable(C.Call("UnitIsDead", "pet"))) and 0.5 or 0
  local _, rec = self:MobRecord(npcID)
  local pct, why = M.MobOdds({ level = readable(C.Call("UnitLevel", "player")), hp = readable(C.Call("UnitHealthMax", "player")), pet = pet, group = group },
    { level = level, hp = hp, class = class }, rec)
  local color = pct >= 60 and "good" or pct <= 40 and "bad" or "warn"
  lines[#lines + 1] = { string.format("Fight odds (rough): you win %d%%%s", pct, #why > 0 and (" · " .. table.concat(why, ", ")) or ""), color }
  return lines
end

-- Track fights with tough creatures for the record.
function M:OnTarget()
  local unit = "target"
  local class = readable(C.Call("UnitClassification", unit))
  if not M.TOUGH[class] or readable(C.Call("UnitIsPlayer", unit)) then return end
  local guid = readable(C.Call("UnitGUID", unit))
  local npcID = C.UnitNpcID(unit)
  if guid and npcID then self.fight = { guid = guid, npcID = npcID, name = readable(C.Call("UnitName", unit)) } end
end

function M:EndFight(won)
  local f = self.fight
  if not f or not f.fought then return end
  self.fight = nil
  local all, rec = self:MobRecord(f.npcID)
  rec = rec or { w = 0, l = 0 }
  if won then rec.w = rec.w + 1 else rec.l = rec.l + 1 end
  all[f.npcID] = rec
  self:Info("fight with %s: %s (%d-%d)", tostring(f.name), won and "won" or "lost", rec.w, rec.l)
end

function M:OnEnable()
  self:On("INSPECT_READY", function(mod, _, guid) mod:OnInspect(guid) end)
  self:On("CHAT_MSG_SYSTEM", self.OnSystem)
  self:On("PLAYER_TARGET_CHANGED", function(mod) mod:OnTarget() end)
  self:On("PLAYER_REGEN_DISABLED", function(mod)
    if mod.fight and readable(C.Call("UnitGUID", "target")) == mod.fight.guid then mod.fight.fought = true end
  end)
  self:On("PLAYER_REGEN_ENABLED", function(mod)
    local f = mod.fight
    if f and f.fought and readable(C.Call("UnitGUID", "target")) == f.guid and readable(C.Call("UnitIsDead", "target")) then
      mod:EndFight(true)
    elseif f then
      f.fought = nil
    end
  end)
  self:On("PLAYER_DEAD", function(mod)
    if mod.fight and mod.fight.fought then mod:EndFight(false) end
  end)
end

ns.TooltipLines:Add("unit", "elite", M, function(tip)
  if M:Settings().odds == false then return nil end
  local unit = "mouseover"
  if tip and tip.GetUnit then
    local ok, _, u = pcall(tip.GetUnit, tip)
    if ok and readable(u) then unit = u end
  end
  return M:MobLines(unit)
end)

function M:Activity()
  local n = 0
  for _ in pairs(self.cache or {}) do n = n + 1 end
  return string.format("player tooltips: %d players looked at this session", n)
end
