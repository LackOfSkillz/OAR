-- Modules/RarePlates.lua  (P7-07 nameplates, rare marker)
-- When a rare's nameplate appears, a big pulsing star floats just above it
-- (Gary, 2026-11-15: The Rake spawned among a crowd of beasts and he could
-- not find it fast enough): gold for a rare on this character's watchlist or
-- in the rare pack, silver for any other rare (RareScan decides what a rare
-- is). M.Direction says where the plate is on screen for the alert toast. The marker is Outrider's own
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
M.SIZE = 44         -- the star, in pixels before the scale setting
M.PULSE = 0.6       -- seconds from bright to dim
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
  m:SetSize(M.SIZE, M.SIZE)
  m:SetFrameStrata("HIGH")
  m.glow = m:CreateTexture(nil, "ARTWORK")
  m.glow:SetPoint("CENTER", m, "CENTER", 0, 0)
  m.glow:SetSize(M.SIZE * 1.8, M.SIZE * 1.8)
  m.glow:SetTexture(M.ICON)
  if m.glow.SetBlendMode then m.glow:SetBlendMode("ADD") end
  m.icon = m:CreateTexture(nil, "OVERLAY")
  m.icon:SetAllPoints()
  m.icon:SetTexture(M.ICON)
  -- the glow breathes so the star catches the eye; no animation API, no pulse
  if m.CreateAnimationGroup then
    pcall(function()
      local g = m:CreateAnimationGroup()
      g:SetLooping("BOUNCE")
      local a = g:CreateAnimation("Alpha")
      a:SetTarget(m.glow)
      a:SetFromAlpha(0.9)
      a:SetToAlpha(0.15)
      a:SetDuration(M.PULSE)
      m.pulse = g
    end)
  end
  return m
end

function M:OnAdded(_, unit)
  if type(unit) ~= "string" then return end
  local scan = ns.Modules:Get("RareScan")
  if not scan then return end
  local npcID, _, _, _, pack, watched = scan:Classify(unit)
  if not npcID then return end
  local plate = plateFor(unit)
  if not plate then return end
  local m = self.active[unit] or self:Marker()
  local c = (watched or pack) and M.GOLD or M.SILVER
  m.icon:SetVertexColor(c[1], c[2], c[3], 1)
  m.glow:SetVertexColor(c[1], c[2], c[3], 0.9)
  m:SetScale(self:Settings().scale or 1)
  m:ClearAllPoints()
  m:SetPoint("BOTTOM", plate, "TOP", 0, 2)
  m:Show()
  if m.pulse then pcall(m.pulse.Play, m.pulse) end
  m.npcID, m.watched = npcID, watched
  self.active[unit] = m
  self:Debug("rare marker on %s (npcID %d, %s)", unit, npcID, watched and "watched" or "rare")
end

function M:OnRemoved(_, unit)
  local m = self.active[unit]
  if not m then return end
  if m.pulse then pcall(m.pulse.Stop, m.pulse) end
  m:Hide()
  m:ClearAllPoints()
  self.active[unit] = nil
  self.pool[#self.pool + 1] = m
end

-- Where a nameplate sits on screen, as a way to turn: "ahead", "ahead,
-- slightly left", "to your right"... nil when the plate or screen size is
-- unknown. Nameplates only exist for units in view, so this is about the
-- screen, not the map: the player still finds it with their own eyes.
function M.Direction(unit)
  local plate = plateFor(unit)
  local ui = rawget(_G, "UIParent")
  if not (plate and plate.GetCenter and ui and ui.GetWidth) then return nil end
  local ok, x = pcall(plate.GetCenter, plate)
  local w = ui:GetWidth()
  if not ok or type(x) ~= "number" or type(w) ~= "number" or w <= 0 then return nil end
  local scale = (plate.GetEffectiveScale and plate:GetEffectiveScale() or 1) / (ui.GetEffectiveScale and ui:GetEffectiveScale() or 1)
  local r = (x * scale - w / 2) / (w / 2)   -- -1 left edge, 0 middle, 1 right edge
  if r < -0.5 then return "to your left" end
  if r > 0.5 then return "to your right" end
  if r < -0.15 then return "ahead, slightly left" end
  if r > 0.15 then return "ahead, slightly right" end
  return "straight ahead"
end

function M:Activity()
  local n = 0
  for _ in pairs(self.active) do n = n + 1 end
  return string.format("stars over rare nameplates (gold = watched); %d showing now", n)
end
