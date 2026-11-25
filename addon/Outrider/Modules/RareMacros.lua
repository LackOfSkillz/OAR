-- Modules/RareMacros.lua  (P4-07)
-- Keeps the two rare macros current (only if Gary installed them from the
-- library, and only out of combat):
--   Outrider Tame  {TARGET} = the newest watched, tameable rare seen
--                  (falls back to the first watched name);
--   Outrider Scan  {RARE_LINES} = /targetexact lines for rares on this map,
--                  watched first, as many as fit in 255 characters; rebuilt
--                  on zone change.

local _, ns = ...
local C = ns.Compat
local E = ns.MacroEngine
local M = ns:NewModule("RareMacros", {
  title = "Rare-aware macros",
  phase = "P4",
  order = 64,
  defaults = { tameTarget = nil },
})
ns.RareMacros = M

function M:OnEnable()
  self:On("OTR_RARE_SEEN", self.OnRareSeen)
  self:On("ZONE_CHANGED_NEW_AREA", function(mod) mod:Refresh("zone") end)
  self:On("PLAYER_ENTERING_WORLD", function(mod) mod:Refresh("login") end)
  self:On("PLAYER_REGEN_ENABLED", function(mod) if mod.pending then mod:Refresh("after combat") end end)
end

function M:OnRareSeen(_, info)
  if info.dead or not info.tameable or not info.watched or not info.name then return end
  local s = self:Settings()
  if s.tameTarget == info.name then return end
  s.tameTarget = info.name
  self:Info("tame macro target -> %s", info.name)
  self:Refresh("rare seen")
end

-- "/targetexact A\n/targetexact B" for rares on the current map, within budget.
function M:RareLines(budget)
  local mapID = C.PlayerPosition("player")
  local names, seen = {}, {}
  local function add(name)
    if type(name) == "string" and not seen[name:lower()] then seen[name:lower()] = true names[#names + 1] = name end
  end
  local scan = ns.Modules:Get("RareScan")
  if scan then
    local watched = {}
    for k in pairs(scan:Settings().watch) do if type(k) == "string" then watched[#watched + 1] = ns.TitleCase(k) end end
    table.sort(watched)
    for _, n in ipairs(watched) do add(n) end
  end
  if mapID and ns.MapPins then
    for _, p in ipairs(ns.MapPins:PinsFor(mapID)) do if p.kind == "rare" then add(p.name) end end
  end
  for _, e in ipairs(ns.Data:All("rare")) do if e.mapID == mapID then add(e.name) end end
  local lines, used = {}, 0
  for _, n in ipairs(names) do
    local l = "/targetexact " .. n
    if used + #l + 1 > budget then break end
    lines[#lines + 1] = l
    used = used + #l + 1
  end
  return table.concat(lines, "\n"), #lines
end

-- Values the library uses for these placeholders.
function M:Values(v)
  local s = self:Settings()
  if s.tameTarget then v.TARGET = s.tameTarget end
  local budget = E.MAX - #"/cleartarget\n"
  local lines, n = self:RareLines(budget)
  if n > 0 then v.RARE_LINES = lines end
  return v
end

function M:Refresh(why)
  local L = ns.MacroLibrary
  if not L then return end
  -- both macros are hunter macros: other classes have nothing to rebuild
  if ns.PlayerClass() ~= "HUNTER" then return end
  if C.InCombat() then self.pending = true return end
  self.pending = false
  -- the two data entries, looked up directly: building the whole macro
  -- library (every fight key, crafting, combo keys) twice on each zone
  -- change cost 60-75 ms (always-on watch, 2026-11-25)
  local want = { ["hunter-tame-rare"] = true, ["hunter-rare-scan"] = true }
  for _, e in ipairs(ns.Data:All("macro")) do
    if want[e.id] and L:State(e) == "changed" then
      local ok = L:Install(e)
      self:Info("%s rebuilt (%s): %s", e.name, why, ok and "ok" or "not updated")
    end
  end
end

function M:Activity()
  local _, n = self:RareLines(E.MAX)
  return string.format("tame target %s; %d rares for the scan macro here", tostring(self:Settings().tameTarget or "not set"), n)
end
