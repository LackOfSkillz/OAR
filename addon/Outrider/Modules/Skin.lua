-- Modules/Skin.lua  (P7-04 Clean dark skin for Blizzard windows, D14)
-- Cosmetic only. The first time a listed window is shown, out of combat,
-- its decorative regions (NineSlice border, background, title bar, inset
-- art) are faded to alpha 0 and a flat Clean dark panel with a 1px border
-- is laid underneath (our own textures on the BACKGROUND layer).
-- Never: SetPoint, SetSize, SetParent, Show/Hide on Blizzard frames (Edit Mode
-- and the game own those, PROBE_RESULTS P7-03), and nothing in combat
-- (deferred to Combat:Run, which waits for combat to end).
-- Steps aside for ElvUI / EllesmereUI (one owner per frame). Turning the
-- module off restores every faded region and hides our panels at once.
-- Logs which windows it skinned (self-collecting check).

local _, ns = ...
local C = ns.Compat
local Theme = ns.Theme
local M = ns:NewModule("Skin", {
  title = "Clean dark skin for Blizzard windows",
  phase = "P7",
  order = 101,
  defaults = {},
  yieldsTo = { "ElvUI", "EllesmereUI", "EllesmereUIFrames" },
})
ns.Skin = M

M.FRAMES = {
  "CharacterFrame", "SpellBookFrame", "PlayerSpellsFrame", "QuestLogFrame", "QuestFrame", "GossipFrame",
  "MerchantFrame", "MailFrame", "OpenMailFrame", "ContainerFrameCombinedBags", "ContainerFrame1",
  "ContainerFrame2", "ContainerFrame3", "ContainerFrame4", "ContainerFrame5", "LootFrame", "GameMenuFrame",
  "StaticPopup1", "StaticPopup2", "StaticPopup3", "FriendsFrame", "BankFrame", "TaxiFrame", "TradeFrame",
}
-- decorative children faded on each window (whichever exist)
M.PARTS = { "NineSlice", "Bg", "Background", "TitleBg", "TopTileStreaks", "Portrait", "PortraitContainer",
  "BorderFrame", "Border", "Inset" }

function M:OnInitialize() self.done, self.faded, self.panels, self.hooked = {}, {}, {}, {} end

function M:OnEnable()
  for _, name in ipairs(self.FRAMES) do self:Hook(name) end
  -- windows from load-on-demand Blizzard addons appear later
  self:On("ADDON_LOADED", function(mod) for _, name in ipairs(mod.FRAMES) do mod:Hook(name) end end)
  for _, p in pairs(self.panels) do p:Show() end
  for region, alpha in pairs(self.faded) do pcall(region.SetAlpha, region, 0) end
end

function M:OnDisable()
  for region, alpha in pairs(self.faded) do pcall(region.SetAlpha, region, alpha) end
  for _, p in pairs(self.panels) do p:Hide() end
end

function M:Hook(name)
  if self.hooked[name] then return end
  local f = rawget(_G, name)
  if type(f) ~= "table" or not f.HookScript then return end
  self.hooked[name] = true
  f:HookScript("OnShow", function(frame)
    if not M.enabled or M.done[name] then return end
    ns.Combat:Run("Skin:" .. name, function() M:Apply(name, frame) end, "skin:" .. name)
  end)
  if f.IsShown and f:IsShown() then ns.Combat:Run("Skin:" .. name, function() M:Apply(name, f) end, "skin:" .. name) end
end

local function fade(self, region)
  if not region or self.faded[region] ~= nil or not region.SetAlpha then return 0 end
  local ok, a = pcall(region.GetAlpha, region)
  self.faded[region] = ok and a or 1
  pcall(region.SetAlpha, region, 0)
  return 1
end

function M:Apply(name, frame)
  if self.done[name] or not self.enabled or C.InCombat() then return false end
  if frame.IsForbidden and frame:IsForbidden() then return false end
  local n = 0
  for _, key in ipairs(self.PARTS) do
    local part = frame[key]
    if type(part) == "table" then n = n + fade(self, part) end
  end
  local panel = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
  panel:SetAllPoints(frame)
  panel:SetColorTexture(Theme:Color("bg"))
  local edges = {}
  for i, side in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" }, { "TOPLEFT", "BOTTOMLEFT" },
      { "TOPRIGHT", "BOTTOMRIGHT" } }) do
    local e = frame:CreateTexture(nil, "BORDER", nil, -8)
    e:SetColorTexture(Theme:Color("border"))
    e:SetPoint(side[1], frame, side[1])
    e:SetPoint(side[2], frame, side[2])
    if i <= 2 then e:SetHeight(1) else e:SetWidth(1) end
    edges[i] = e
  end
  self.panels[name] = panel
  for i, e in ipairs(edges) do self.panels[name .. ":" .. i] = e end
  self.done[name] = true
  self.count = (self.count or 0) + 1
  self:Info("skinned %s (%d decorations faded)", name, n)
  return true
end

function M:Activity()
  return string.format("Clean dark on %d Blizzard windows so far (open one to skin it)", self.count or 0)
end
