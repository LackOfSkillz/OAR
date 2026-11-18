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
  defaults = { scale = 1, threat = true },
  yieldsTo = { "Plater", "TidyPlates_ThreatPlates", "Kui_Nameplates" },
})
ns.RarePlates = M

M.ICON = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1" -- star
M.SIZE = 44         -- the star, in pixels before the scale setting
M.PULSE = 0.6       -- seconds from bright to dim
M.GOLD, M.SILVER = { 1, 0.82, 0.2 }, { 0.8, 0.85, 0.95 }

function M:OnInitialize() self.pool, self.active, self.threatMarkers = {}, {}, {} end

function M:OnEnable()
  self:On("NAME_PLATE_UNIT_ADDED", self.OnAdded)
  self:On("UNIT_THREAT_SITUATION_UPDATE", function(mod) mod:RefreshThreat() end)
  self:On("UNIT_THREAT_LIST_UPDATE", function(mod) mod:RefreshThreat() end)
  self:On("UNIT_PET", function(mod) mod:RefreshThreat() end)
  self:On("NAME_PLATE_UNIT_REMOVED", self.OnRemoved)
end

function M:OnDisable()
  for unit in pairs(self.active) do self:OnRemoved(nil, unit) end
  for unit, m in pairs(self.threatMarkers) do m:Hide() self.threatMarkers[unit] = nil end
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
  self:ThreatFor(unit)
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
  local threat = self.threatMarkers[unit]
  if threat then threat:Hide() self.threatMarkers[unit] = nil end
  local m = self.active[unit]
  if not m then return end
  if m.pulse then pcall(m.pulse.Stop, m.pulse) end
  m:Hide()
  m:ClearAllPoints()
  self.active[unit] = nil
  self.pool[#self.pool + 1] = m
end

-- DEEP-17: visual only. Never writes a nameplate's healthbar,
-- threat colors or protected unit settings. A small independent marker sits
-- outside the plate and displays player vs pet threat when both are readable.
M.THREAT_COLORS = {
  player = { 1, 0.35, 0.25 }, pet = { 0.25, 0.60, 1 },
  safe = { 0.30, 0.85, 0.35 },
}
function M:ThreatStatus(unit)
  local get = C.Resolve("UnitDetailedThreatSituation")
  if type(get) ~= "function" then return nil end
  local function one(who)
    local ok, tanking, status, pct = pcall(get, who, unit)
    status, pct = C.Readable(status), C.Readable(pct)
    if not ok or type(status) ~= "number" or type(pct) ~= "number" then return nil end
    return { status = status, pct = pct, tanking = C.Readable(tanking) == true }
  end
  local player, pet = one("player"), one("pet")
  if not player and not pet then return nil end
  local owner = "safe"
  if player and player.status >= 2 then owner = "player"
  elseif pet and pet.status >= 2 then owner = "pet"
  elseif player and pet then owner = player.pct >= pet.pct and "player" or "pet"
  elseif player then owner = "player"
  else owner = "pet" end
  return { owner = owner, player = player, pet = pet }
end

function M:ThreatFor(unit)
  if not self:Settings().threat then return end
  local plate = plateFor(unit)
  if not plate then return end
  local info = self:ThreatStatus(unit)
  local marker = self.threatMarkers[unit]
  if not info then if marker then marker:Hide() end return end
  if not marker then
    marker = CreateFrame("Frame", nil, UIParent)
    marker:SetSize(80, 14)
    marker:SetFrameStrata("HIGH")
    marker.text = ns.UI.Text(marker, "small", "text")
    marker.text:SetPoint("CENTER")
    self.threatMarkers[unit] = marker
  end
  marker:ClearAllPoints()
  marker:SetPoint("TOP", plate, "BOTTOM", 0, -2)
  local color = M.THREAT_COLORS[info.owner]
  marker.text:SetText(string.format("YOU %s  PET %s",
    info.player and (math.floor(info.player.pct) .. "%") or "?",
    info.pet and (math.floor(info.pet.pct) .. "%") or "?"))
  marker.text:SetTextColor(color[1], color[2], color[3])
  marker:Show()
end

function M:RefreshThreat()
  if not self:Settings().threat then return end
  for unit in pairs(self.threatMarkers) do self:ThreatFor(unit) end
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
