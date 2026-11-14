-- Modules/UnitLook.lua  (P7-06 unit frames and bars, look only, Clean dark D14)
-- Cosmetic only; positions, sizes and visibility stay with Edit Mode
-- (PROBE_RESULTS P7-03). Out of combat at login (Combat:Run):
--   * flat bar texture on player, target, focus, pet and party health bars
--   * action bar end-cap art (gryphons) faded (setting hideArt)
-- And through hooksecurefunc on Blizzard's own health-bar update (runs
-- after Blizzard colors the bar, works in combat because coloring a bar is
-- not a protected action and uses no health numbers): players' health bars
-- in their class color (setting classColors).
-- Not done, on purpose:
--   * fading bars out of combat: Edit Mode already has "visible: in combat"
--     per bar; a state driver of ours would fight it (one owner per frame)
--   * out-of-range coloring, hotkey text, duplicate Cooldown Manager rows:
--     no safe, verified API on Forever yet
-- Logs what it found so the next session tells us what exists.

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("UnitLook", {
  title = "Unit frame and action bar look",
  phase = "P7",
  order = 103,
  defaults = { classColors = true, hideArt = true, flatBars = true },
  yieldsTo = { "ElvUI", "EllesmereUI", "ShadowedUnitFrames", "Bartender4", "Dominos" },
})
ns.UnitLook = M

M.HEALTH_BARS = { "PlayerFrameHealthBar", "TargetFrameHealthBar", "FocusFrameHealthBar", "PetFrameHealthBar",
  "PartyMemberFrame1HealthBar", "PartyMemberFrame2HealthBar", "PartyMemberFrame3HealthBar", "PartyMemberFrame4HealthBar" }
M.ART = { "MainMenuBarLeftEndCap", "MainMenuBarRightEndCap" }
M.ART_PARENTS = { "MainActionBar", "MainMenuBar", "MainMenuBarArtFrame" }

function M:OnInitialize() self.faded, self.textured = {}, {} end

-- Health bars by global name, or inside modern unit frames.
function M:HealthBars()
  local out = {}
  for _, name in ipairs(self.HEALTH_BARS) do
    local bar = rawget(_G, name)
    if type(bar) == "table" and bar.SetStatusBarTexture then out[name] = bar end
  end
  for _, f in ipairs({ "PlayerFrame", "TargetFrame", "FocusFrame", "PetFrame" }) do
    local frame = rawget(_G, f)
    local ok, bar = pcall(function()
      return frame.healthbar or (frame.TargetFrameContent and frame.TargetFrameContent.TargetFrameContentMain
        .HealthBarsContainer.HealthBar) or (frame.PlayerFrameContent and frame.PlayerFrameContent
        .PlayerFrameContentMain.HealthBarsContainer.HealthBar)
    end)
    if ok and type(bar) == "table" and bar.SetStatusBarTexture and not out[f .. "Health"] then out[f .. "Health"] = bar end
  end
  return out
end

function M:ArtRegions()
  local out = {}
  for _, name in ipairs(self.ART) do
    local r = rawget(_G, name)
    if type(r) == "table" and r.SetAlpha then out[#out + 1] = r end
  end
  for _, name in ipairs(self.ART_PARENTS) do
    local p = rawget(_G, name)
    local caps = type(p) == "table" and p.EndCaps
    if type(caps) == "table" and caps.SetAlpha then out[#out + 1] = caps end
  end
  return out
end

function M:Apply()
  local s = self:Settings()
  local bars, art = 0, 0
  if s.flatBars then
    for name, bar in pairs(self:HealthBars()) do
      if not self.textured[bar] then
        local ok, old = pcall(bar.GetStatusBarTexture, bar)
        local path = ok and type(old) == "table" and old.GetTexture and old:GetTexture() or nil
        self.textured[bar] = path or false
        pcall(bar.SetStatusBarTexture, bar, "Interface\\Buttons\\WHITE8x8")
        bars = bars + 1
      end
    end
  end
  if s.hideArt then
    for _, r in ipairs(self:ArtRegions()) do
      if self.faded[r] == nil then
        local ok, a = pcall(r.GetAlpha, r)
        self.faded[r] = ok and a or 1
        pcall(r.SetAlpha, r, 0)
        art = art + 1
      end
    end
  end
  self:Info("unit look: %d health bars flat, %d art pieces faded, class color hook %s", bars, art,
    tostring(self.colorHook or false))
end

function M:Restore()
  for r, a in pairs(self.faded) do pcall(r.SetAlpha, r, a) end
  self.faded = {}
  for bar, path in pairs(self.textured) do
    if path then pcall(bar.SetStatusBarTexture, bar, path) end
  end
  self.textured = {}
end

-- Class color for player units on any Blizzard health bar update.
function M.ColorBar(bar, unit)
  if not M.enabled or not M:Settings().classColors or type(bar) ~= "table" or not bar.SetStatusBarColor then return end
  unit = unit or bar.unit
  if type(unit) ~= "string" or not C.Readable(C.Call("UnitIsPlayer", unit)) then return end
  local _, class = C.Call("UnitClass", unit)
  local cc = C.Readable(class) and (rawget(_G, "RAID_CLASS_COLORS") or {})[class]
  if cc then pcall(bar.SetStatusBarColor, bar, cc.r, cc.g, cc.b) end
end

function M:OnEnable()
  if not self.colorHook and type(rawget(_G, "UnitFrameHealthBar_Update")) == "function" then
    hooksecurefunc("UnitFrameHealthBar_Update", function(bar, unit) ns.Safe("UnitLook:color", M.ColorBar, bar, unit) end)
    self.colorHook = true
  end
  self:On("PLAYER_ENTERING_WORLD", function(mod) ns.Combat:Run("UnitLook:apply", function() mod:Apply() end, "unitlook") end)
  if ns.db and C.Call("IsLoggedIn") then ns.Combat:Run("UnitLook:apply", function() M:Apply() end, "unitlook") end
end

function M:OnDisable() ns.Combat:Run("UnitLook:restore", function() M:Restore() end, "unitlook") end

function M:Activity()
  local n = 0
  for _ in pairs(self.textured) do n = n + 1 end
  return string.format("%d health bars restyled; class colors %s; gryphons %s", n,
    self:Settings().classColors and "on" or "off", self:Settings().hideArt and "hidden" or "shown")
end
