-- Modules/CookTrainer.lua
-- One-button cooking training (Gary, 2026-11-14: "if there's anything we have
-- recipe-wise and material-wise that will teach cooking, a button pops up:
-- you can raise your cooking by 10 ... builds a campfire and cooks everything
-- that will train. Don't show it under ten").
-- The estimate uses the cooking recipes Outrider saw the last time the
-- Cooking window was open (colour = skill-up chance) and what is in the bags:
-- orange counts 1 point per craft, yellow 0.75, green 0.25, grey 0 (Classic
-- chances, approximate). Reagents are shared out best colour first, and the
-- total is capped at the skill left before the cap.
-- The button: one action per press (Forever, C16b), so it changes as it goes:
--   "Build fire" -> /cast Basic Campfire (when you have its wood)
--   "Cook"       -> /ride make Cooking train: Create All of the best recipe
--                   that still gives skill (never grey)
-- A "requires a cooking fire" refusal turns it back to "Build fire". It hides
-- below the threshold, in combat, and for 30 minutes after its x is clicked.

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("CookTrainer", {
  title = "Cooking training button",
  phase = "P5",
  order = 74,
  defaults = { threshold = 10, show = true },
})
ns.CookTrainer = M

M.CHANCE = { [0] = 1, [1] = 0.75, [2] = 0.25, [3] = 0 }
M.FIRE = "Basic Campfire"
M.SNOOZE = 30 * 60

function M:Cooking()
  local p = ns.db.char.professions and ns.db.char.professions.Cooking
  return type(p) == "table" and p or nil
end

-- Expected skill points from what's in the bags: total, { {name, n, diff} }, unknownColours
function M:Estimate(have)
  have = have or (ns.Crafter and ns.Crafter.Have) or function() return 0 end
  local p = self:Cooking()
  if not p or type(p.recipes) ~= "table" then return 0, {}, 0 end
  local list, unknown = {}, 0
  for id, r in pairs(p.recipes) do
    if type(r) == "table" and r.name ~= M.FIRE and r.learned ~= false and type(r.reagents) == "table" and next(r.reagents) then
      local diff = tonumber(r.diff)
      if diff == nil then unknown = unknown + 1
      elseif (M.CHANCE[diff] or 0) > 0 then list[#list + 1] = { id = id, name = r.name, diff = diff, reagents = r.reagents, ups = tonumber(r.skillUps) or 1 } end
    end
  end
  table.sort(list, function(a, b) if a.diff ~= b.diff then return a.diff < b.diff end return tostring(a.name) < tostring(b.name) end)
  local left = {}
  local function bag(itemID) if left[itemID] == nil then left[itemID] = have(itemID) end return left[itemID] end
  local total, out = 0, {}
  for _, r in ipairs(list) do
    local n
    for itemID, need in pairs(r.reagents) do
      local k = math.floor(bag(itemID) / math.max(need, 1))
      n = n and math.min(n, k) or k
    end
    n = n or 0
    if n > 0 then
      for itemID, need in pairs(r.reagents) do left[itemID] = left[itemID] - n * need end
      total = total + n * M.CHANCE[r.diff] * r.ups
      out[#out + 1] = { name = r.name, n = n, diff = r.diff }
    end
  end
  local skill, max = tonumber(p.skill), tonumber(p.max)
  if skill and max and max > skill then total = math.min(total, max - skill) end
  return math.floor(total), out, unknown
end

-- ------------------------------------------------------------ the button
-- Can we build a fire: the Basic Campfire recipe is known and its wood is in the bags.
function M:FireReady()
  if not self:HasRecipe(M.FIRE) then return false end
  local p = self:Cooking()
  for _, r in pairs(p and p.recipes or {}) do
    if type(r) == "table" and r.name == M.FIRE and type(r.reagents) == "table" then
      for itemID, need in pairs(r.reagents) do
        if (ns.Crafter and ns.Crafter.Have(itemID) or 0) < need then return false end
      end
    end
  end
  return true
end

function M:HasRecipe(name)
  for _, r in pairs(self:Cooking() and self:Cooking().recipes or {}) do
    if type(r) == "table" and r.name == name then return true end
  end
  return false
end

function M:Label(total)
  if self.state == "fire" then return string.format("Cooking +%d: Build fire", total) end
  return string.format("Cooking +%d: Cook", total)
end

function M:Body()
  if self.state == "fire" then return "/cast " .. M.FIRE end
  return "/ride make Cooking train"
end

function M:Evaluate()
  if not self.enabled then return end
  local s = self:Settings()
  local total, list = self:Estimate()
  self.total, self.list = total, list
  local snoozed = self.snoozeUntil and time() < self.snoozeUntil
  -- the threshold only gates the first show; once training it stays till done
  local want = s.show and not snoozed and not C.InCombat() and total >= 1 and (self.training or total >= (s.threshold or 10))
  if not want then
    if self.btn then self:Hide() end
    if total < 1 then self.training = false end
    return
  end
  if not self.state then self.state = self:FireReady() and "fire" or "cook" end
  self:Show(total)
end

function M:Show(total)
  if not self.btn then
    self.btn = ns.SecureButtons:Acquire("CookTrainer")
    if not self.btn then return end
    self.btn:HookScript("PostClick", function() M.training = true end)
    ns.SecureButtons:Place(self.btn, "TOP", UIParent, "TOP", 0, -150)
    ns.SecureButtons:Raise(self.btn, "HIGH")
    local x = CreateFrame("Button", nil, UIParent, "UIPanelCloseButton")
    x:SetSize(22, 22)
    x:SetPoint("LEFT", self.btn, "RIGHT", 2, 0)
    x:SetScript("OnClick", function() M:Snooze() end)
    self.close = x
  end
  local body = self:Body()
  if body ~= self.body then self.body = body ns.SecureButtons:SetMacro(self.btn, body) end
  ns.SecureButtons:SetLabel(self.btn, self:Label(total))
  ns.SecureButtons:SetShown(self.btn, true)
  if self.close then self.close:Show() end
  if not self.announced then
    self.announced = true
    self:Info("cooking training offered: about +%d from %d recipes", total, #(self.list or {}))
  end
end

function M:Hide()
  if self.btn then ns.SecureButtons:SetShown(self.btn, false) end
  if self.close then self.close:Hide() end
end

function M:Snooze()
  self.snoozeUntil = time() + M.SNOOZE
  self.training = false
  self:Hide()
  self:Info("cooking training snoozed for 30 minutes")
end

-- The fire went up: cook next. "Requires a cooking fire": build one.
function M:OnCast(_, unit, _, spellID)
  if unit ~= "player" then return end
  local name = C.SpellName(spellID)
  if name == M.FIRE then self.state = "cook" self.body = nil self:Evaluate() end
end

function M:OnError(_, _, message)
  if type(message) == "string" and message:lower():find("fire", 1, true) and self.btn then
    self.state = self:FireReady() and "fire" or "cook"
    if self.state == "cook" then ns.Print("cooking: stand by a fire (no Simple Wood for a campfire)") end
    self:Evaluate()
  end
end

function M:OnEnable()
  -- cheap (a few recipes), and BAG_UPDATE_DELAYED is already batched by the game
  local function later(mod) mod:Evaluate() end
  self:On("BAG_UPDATE_DELAYED", later)
  self:On("PLAYER_REGEN_ENABLED", later)
  self:On("PLAYER_REGEN_DISABLED", function(mod) mod:Hide() end)
  self:On("TRADE_SKILL_LIST_UPDATE", later)
  self:On("PLAYER_ENTERING_WORLD", later)
  self:On("UNIT_SPELLCAST_SUCCEEDED", self.OnCast)
  self:On("UI_ERROR_MESSAGE", self.OnError)
end

function M:OnDisable() self:Hide() end

function M:Activity()
  local total, list, unknown = self:Estimate()
  if total >= 1 then return string.format("about +%d cooking from %d recipes in your bags", total, #list) end
  if unknown > 0 then return "open your Cooking window once so Outrider learns each recipe's colour" end
  return "nothing in your bags trains cooking right now"
end
