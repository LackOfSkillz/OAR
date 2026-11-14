-- Modules/RarePlates.lua  (P7-07 nameplates, rare marker)
-- When a rare's nameplate appears, a small marker floats just above it:
-- gold star for a rare on this character's watchlist, silver for any other
-- rare (RareScan decides what a rare is). The marker is Outrider's own
-- frame anchored to the plate, never a child of Blizzard's nameplate, and
-- forbidden plates (friendly plates in instances) are skipped, so nothing
-- of Blizzard's is changed or tainted. Nameplate bar and font styling is
-- left to the client and nameplate addons (P7-04 skin decisions come later).

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("RarePlates", {
  title = "Rare marker on nameplates",
  phase = "P7",
  order = 99,
  defaults = { scale = 1 },
  yieldsTo = { "Plater", "TidyPlates_ThreatPlates", "Kui_Nameplates" },
})
ns.RarePlates = M

M.ICON = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1" -- star
M.GOLD, M.SILVER = { 1, 0.82, 0.2 }, { 0.8, 0.85, 0.95 }

function M:OnInitialize() self.pool, self.active = {}, {} end

function M:OnEnable()
  self:On("NAME_PLATE_UNIT_ADDED", self.OnAdded)
  self:On("NAME_PLATE_UNIT_REMOVED", self.OnRemoved)
end

function M:OnDisable()
  for unit in pairs(self.active) do self:OnRemoved(nil, unit) end
end

local function plateFor(unit)
  local get = C.Resolve("C_NamePlate.GetNamePlateForUnit")
  if type(get) ~= "function" then return nil end
  local ok, plate = pcall(get, unit)
  if not ok or not plate then return nil end
  if plate.IsForbidden and plate:IsForbidden() then return nil end
  return plate
end

function M:Marker()
  local m = table.remove(self.pool)
  if m then return m end
  m = CreateFrame("Frame", nil, UIParent)
  m:SetSize(20, 20)
  m:SetFrameStrata("HIGH")
  m.icon = m:CreateTexture(nil, "OVERLAY")
  m.icon:SetAllPoints()
  m.icon:SetTexture(M.ICON)
  return m
end

function M:OnAdded(_, unit)
  if type(unit) ~= "string" then return end
  local scan = ns.Modules:Get("RareScan")
  if not scan then return end
  local npcID, _, _, _, _, watched = scan:Classify(unit)
  if not npcID then return end
  local plate = plateFor(unit)
  if not plate then return end
  local m = self.active[unit] or self:Marker()
  local c = watched and M.GOLD or M.SILVER
  m.icon:SetVertexColor(c[1], c[2], c[3], 1)
  m:SetScale(self:Settings().scale or 1)
  m:ClearAllPoints()
  m:SetPoint("BOTTOM", plate, "TOP", 0, 2)
  m:Show()
  m.npcID, m.watched = npcID, watched
  self.active[unit] = m
  self:Debug("rare marker on %s (npcID %d, %s)", unit, npcID, watched and "watched" or "rare")
end

function M:OnRemoved(_, unit)
  local m = self.active[unit]
  if not m then return end
  m:Hide()
  m:ClearAllPoints()
  self.active[unit] = nil
  self.pool[#self.pool + 1] = m
end

function M:Activity()
  local n = 0
  for _ in pairs(self.active) do n = n + 1 end
  return string.format("stars over rare nameplates (gold = watched); %d showing now", n)
end
