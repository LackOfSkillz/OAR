-- Modules/PlayerInfo.lua
-- Extra lines on other players' tooltips (Gary, 2026-11-17: "when we hover
-- over a creature or a pet it gives us the speed and different info ... is
-- there a way to do that with players"):
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
  defaults = { inspect = true },
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

function M:OnInspect(guid)
  guid = readable(guid)
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

function M:OnEnable()
  self:On("INSPECT_READY", function(mod, _, guid) mod:OnInspect(guid) end)
end

function M:Activity()
  local n = 0
  for _ in pairs(self.cache or {}) do n = n + 1 end
  return string.format("player tooltips: %d players looked at this session", n)
end
