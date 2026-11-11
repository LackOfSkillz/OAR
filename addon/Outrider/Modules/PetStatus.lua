-- Modules/PetStatus.lua  (HUNTER, P2-09)
-- Small movable panel: pet name, level, XP, health, focus, and happiness if
-- the client still has it. Forever has no GetPetHappiness/GetPetLoyalty/
-- GetPetTrainingPoints/GetPetFoodTypes (probe 2026-11-11), so:
--   * happiness shows only when an API for it exists; meanwhile the module
--     logs the pet's buffs once per session so Claude can see how Forever
--     represents happiness (auto-collected, no typing);
--   * Feed is a secure button with "/cast Feed Pet": Gary clicks it, then
--     clicks the food. No diet guessing.
-- The secure Feed button is placed against UIParent at the panel's position,
-- never anchored to the panel (a frame with a secure frame anchored to it is
-- protected; moving it got Outrider blocked once).

local _, ns = ...
local C = ns.Compat
local UI = ns.UI
local M = ns:NewModule("PetStatus", {
  title = "Pet status",
  phase = "P2",
  order = 36,
  classes = { HUNTER = true },
  defaults = { pos = {}, warnUnhappy = true },
})

local HAPPY = { [1] = "Unhappy", [2] = "Content", [3] = "Happy" }

function M:OnEnable()
  self:On("UNIT_PET", function(mod, _, unit) if unit == "player" then mod:Update("pet changed") end end)
  self:On("UNIT_PET_EXPERIENCE", function(mod) mod:Update() end)
  self:On("UNIT_HEALTH", function(mod, _, unit) if unit == "pet" then mod:Update() end end)
  self:On("UNIT_POWER_UPDATE", function(mod, _, unit) if unit == "pet" then mod:Update() end end)
  self:On("UNIT_AURA", function(mod, _, unit) if unit == "pet" then mod:Update() end end)
  self:On("PLAYER_ENTERING_WORLD", function(mod) mod:Update("login") end)
end

function M:OnDisable()
  ns.ThrottleCancel("petstatus")
  if self.frame then self.frame:Hide() end
  if self.feed then ns.SecureButtons:Release(self.feed) self.feed = nil end
end

function M:Update(why)
  ns.Throttle("petstatus", 0.2, function() M:Refresh(why) end)
end

-- Plain data about the pet (nil when there is none).
function M:Read()
  if not C.Call("UnitExists", "pet") then return nil end
  local d = {
    name = C.Readable(C.Call("UnitName", "pet")),
    level = C.Readable(C.Call("UnitLevel", "pet")),
    hp = C.Readable(C.Call("UnitHealth", "pet")), hpMax = C.Readable(C.Call("UnitHealthMax", "pet")),
    focus = C.Readable(C.Call("UnitPower", "pet")), focusMax = C.Readable(C.Call("UnitPowerMax", "pet")),
    family = C.Readable(C.Call("UnitCreatureFamily", "pet")),
  }
  d.xp, d.xpMax = C.Call("GetPetExperience")
  d.happiness = C.Call("GetPetHappiness")
  d.npcID = C.UnitNpcID("pet")
  return d
end

-- Names of the pet's buffs (where happiness may live on Forever).
function M:Auras()
  local out = {}
  local get = C.Resolve("C_UnitAuras.GetAuraDataByIndex")
  if type(get) ~= "function" then return out end
  for i = 1, 40 do
    local ok, a = pcall(get, "pet", i, "HELPFUL")
    if not ok or type(a) ~= "table" then break end
    local name = C.Readable(a.name)
    out[#out + 1] = tostring(name or "?") .. (a.spellId and ("#" .. tostring(C.Readable(a.spellId))) or "")
  end
  return out
end

function M:Build()
  if self.frame then return self.frame end
  local s = self:Settings()
  local f = UI:Window("Outrider_PetStatus", "Pet", 220, 120, s.pos)
  f.close:Hide()
  local c = f.content
  f.line1 = UI.Text(c, "normal", "text") f.line1:SetPoint("TOPLEFT", 0, 0)
  f.line2 = UI.Text(c, "small", "muted") f.line2:SetPoint("TOPLEFT", 0, -18)
  f.line3 = UI.Text(c, "small", "muted") f.line3:SetPoint("TOPLEFT", 0, -34)
  f.line4 = UI.Text(c, "small", "text") f.line4:SetPoint("TOPLEFT", 0, -50)
  f:HookScript("OnDragStart", function() if M.feed and not C.InCombat() then ns.SecureButtons:SetShown(M.feed, false) end end)
  f:HookScript("OnDragStop", function() M:PlaceFeed() end)
  self.frame = f
  return f
end

-- Feed button next to the panel's bottom-right corner, anchored to UIParent.
function M:PlaceFeed()
  local f = self.frame
  if not f or not f:IsShown() then return end
  if not self.feed then
    self.feed = ns.SecureButtons:Acquire("PetStatus")
    if not self.feed then return end
    ns.SecureButtons:SetMacro(self.feed, "/cast Feed Pet")
    ns.SecureButtons:SetLabel(self.feed, "Feed")
  end
  local cx, cy = f:GetCenter()
  if not cx then return end
  local w, h = f:GetWidth() or 220, f:GetHeight() or 120
  ns.SecureButtons:Place(self.feed, "BOTTOMRIGHT", UIParent, "BOTTOMLEFT", cx + w / 2 - 8, cy - h / 2 + 8)
  ns.SecureButtons:SetShown(self.feed, true)
end

function M:Refresh(why)
  local d = self:Read()
  if why == "login" or why == "pet changed" then self:LogPet(d) end
  if not d then
    if self.frame then self.frame:Hide() end
    if self.feed then ns.SecureButtons:SetShown(self.feed, false) end
    return
  end
  local f = self:Build()
  f.title:SetText(d.name or "Pet")
  f.line1:SetText(string.format("%s level %s", tostring(d.family or "Pet"), tostring(d.level or "?")))
  if d.xp and d.xpMax and d.xpMax > 0 then
    f.line2:SetText(string.format("XP %d / %d (%.0f%%)", d.xp, d.xpMax, d.xp / d.xpMax * 100))
  else
    f.line2:SetText("XP unknown")
  end
  f.line3:SetText(string.format("Health %s / %s   Focus %s", tostring(d.hp or "?"), tostring(d.hpMax or "?"), tostring(d.focus or "?")))
  f.line4:SetText(d.happiness and ("Happiness: " .. (HAPPY[d.happiness] or tostring(d.happiness))) or "")
  self:CheckUnhappy(d)
  if not f:IsShown() then f:Show() end
  self:PlaceFeed()
end

function M:CheckUnhappy(d)
  local prev = self.lastHappiness
  self.lastHappiness = d.happiness
  if not d.happiness or not self:Settings().warnUnhappy then return end
  if d.happiness == 1 and prev and prev > 1 and not self.warnedUnhappy then
    self.warnedUnhappy = true
    ns.Toast:Show({ title = (d.name or "Your pet") .. " is unhappy", text = "Feed it soon.", color = "warn" })
    self:Info("pet unhappy warning shown")
  elseif d.happiness > 1 then
    self.warnedUnhappy = false
  end
end

-- One log line per login / pet change: Claude's view of what Forever exposes.
function M:LogPet(d)
  if not d then self:Info("no pet") return end
  self:Info("pet %s npcID=%s family=%s level=%s xp=%s/%s focus=%s happinessAPI=%s buffs=[%s]", tostring(d.name),
    tostring(d.npcID), tostring(d.family), tostring(d.level), tostring(d.xp), tostring(d.xpMax), tostring(d.focus),
    tostring(d.happiness), table.concat(self:Auras(), ", "))
end

function M:Snapshot()
  local d = self:Read()
  return d and { name = d.name, level = d.level, family = d.family, xp = d.xp, xpMax = d.xpMax } or nil
end
