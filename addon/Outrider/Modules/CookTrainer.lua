-- Modules/CookTrainer.lua  (module "ProfTrainer")
-- One-button profession training for every crafting profession the character
-- has (Gary, 2026-11-14: cooking first, then "mining, enchanting, all the
-- crafting professions ... aware of what crafting skill the character has").
-- For each profession the character knows, from the recipes Outrider saw the
-- last time that profession's window was open (colour = skill-up chance) and
-- what is in the bags: orange counts 1 point per craft, yellow 0.75, green
-- 0.25, grey 0 (Classic chances, approximate). Reagents are shared out best
-- colour first; the total is capped at the skill left before the cap.
-- One button shows the profession with the most to gain, when that is at
-- least `threshold` (10). Gathering-only professions (Herbalism, Skinning,
-- Fishing) never show; Mining counts its smelting recipes.
-- The button: one action per press (Forever, C16b), so it changes as it goes:
--   Cooking only: "Build fire" -> /cast Basic Campfire (when you have its wood)
--   "Make"        -> /ride make <Profession> train: Create All of the best
--                    recipe that still gives skill (never grey)
-- A chosen key (setting `key`) presses the button while it shows (override
-- binding, out of combat only). It hides in combat and for 30 minutes after
-- its x is clicked. Every craft is Gary's press (hard rule 1).

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("ProfTrainer", {
  title = "Profession training button",
  phase = "P5",
  order = 74,
  defaults = { threshold = 10, show = true, key = nil, off = {} },
})
ns.ProfTrainer = M
ns.CookTrainer = M -- the name it had for cooking only

M.CHANCE = { [0] = 1, [1] = 0.75, [2] = 0.25, [3] = 0 }
M.FIRE = "Basic Campfire"
M.SNOOZE = 30 * 60
M.GATHER_ONLY = { Herbalism = true, Skinning = true, Fishing = true }
-- What a refusal usually means, by the word in the game's message.
M.NEEDS = { forge = "stand by a forge", anvil = "stand by an anvil", fire = "stand by a fire" }

function M:Record(prof)
  local p = ns.db.char.professions and ns.db.char.professions[prof]
  return type(p) == "table" and p or nil
end

-- Crafting professions this character has, with recipe records.
function M:Professions()
  local owned = ns.Crafter and ns.Crafter:Owned() or {}
  local out = {}
  for name in pairs(owned) do
    if type(name) == "string" and name ~= "" and not M.GATHER_ONLY[name] and self:Record(name) then out[#out + 1] = name end
  end
  table.sort(out)
  return out
end

-- Expected skill points from what's in the bags: total, { {name, n, diff} }, unknownColours
function M:Estimate(have, prof)
  prof = prof or "Cooking"
  have = have or (ns.Crafter and ns.Crafter.Have) or function() return 0 end
  local p = self:Record(prof)
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

-- The profession with the most to gain now: prof, total, list (or nil).
function M:Best()
  local off = self:Settings().off or {}
  local best, bt, bl
  for _, prof in ipairs(self:Professions()) do
    if not off[prof] then
      local t, l = self:Estimate(nil, prof)
      if t > (bt or 0) then best, bt, bl = prof, t, l end
    end
  end
  return best, bt or 0, bl or {}
end

-- ------------------------------------------------------------ the button
-- A crafted campfire waiting in the bags (Forever: crafting Basic Campfire
-- makes an item that is then used to place the fire; Gary, 2026-11-14).
function M:FireItem()
  for bag = 0, 4 do
    for slot = 1, (C.Call("C_Container.GetContainerNumSlots", bag) or 0) do
      local info = C.Call("C_Container.GetContainerItemInfo", bag, slot)
      local it = type(info) == "table" and info.itemID and C.ItemInfo(info.itemID)
      local name = it and it.name
      if type(name) == "string" and name:lower():find("campfire", 1, true) then return name end
    end
  end
  return nil
end

-- Cooking: can we build a fire (a campfire in the bags, or its recipe and wood)?
function M:FireReady()
  if self:FireItem() then return true end
  local p = self:Record("Cooking")
  for _, r in pairs(p and p.recipes or {}) do
    if type(r) == "table" and r.name == M.FIRE and type(r.reagents) == "table" then
      for itemID, need in pairs(r.reagents) do
        if (ns.Crafter and ns.Crafter.Have(itemID) or 0) < need then return false end
      end
      return true
    end
  end
  return false
end

-- "Alchemy +10: make Elixir of Minor Defense x5" (Gary, 2026-11-14: "+10: Make"
-- told him nothing). The next recipe is the best colour the bags can make.
local VERB = { Cooking = "cook", Alchemy = "brew", Enchanting = "enchant", Mining = "smelt", ["First Aid"] = "make" }
function M:Label(total)
  if self.state == "fire" then
    if self:FireItem() then return string.format("Cooking +%d: click to place the campfire", total) end
    if not (ns.Crafter and ns.Crafter:OpenFor("Cooking")) then
      return string.format("Cooking +%d: click to open Cooking, then again for a campfire", total)
    end
    return string.format("Cooking +%d: click to build a campfire", total)
  end
  -- crafting needs the profession window open: the first press opens it
  if not (ns.Crafter and ns.Crafter:OpenFor(self.prof)) then
    return string.format("%s +%d: open %s (then press again)", tostring(self.prof), total, tostring(self.prof))
  end
  local nxt = self.list and self.list[1]
  return string.format("%s +%d: %s %s", tostring(self.prof), total, VERB[self.prof] or "make",
    nxt and string.format("%s x%d", tostring(nxt.name), nxt.n) or "next recipe")
end

function M:Body()
  -- the campfire is a Cooking recipe on Forever, crafted like the food
  -- three steps: make the campfire (a Cooking recipe), place it (use the item), cook
  if self.state == "fire" then
    local item = self:FireItem()
    if item then return "/use " .. item end
    return "/ride make Cooking fire"
  end
  return "/ride make " .. tostring(self.prof) .. " train"
end

function M:Evaluate()
  if not self.enabled then return end
  local s = self:Settings()
  local prof, total, list = self:Best()
  -- stay with the profession being trained until it runs out
  if self.training and self.prof and prof ~= self.prof then
    local t, l = self:Estimate(nil, self.prof)
    if t >= 1 then prof, total, list = self.prof, t, l end
  end
  self.total, self.list = total, list
  local snoozed = self.snoozeUntil and time() < self.snoozeUntil
  local want = prof and s.show and not snoozed and not C.InCombat() and total >= 1
    and (self.training or total >= (s.threshold or 10))
  if not want then
    if self.btn then self:Hide() end
    if total < 1 then self.training = false end
    return
  end
  if prof ~= self.prof then self.prof, self.state = prof, nil end
  if not self.state then self.state = (prof == "Cooking" and self:FireReady()) and "fire" or "make" end
  self:Show(total)
end

function M:Show(total)
  if not self.btn then
    self.btn = ns.SecureButtons:Acquire("ProfTrainer")
    if not self.btn then return end
    self.btn:HookScript("PostClick", function() M.training = true end)
    -- hover: everything still to make, with its colour
    self.btn:HookScript("OnEnter", function(b)
      GameTooltip:SetOwner(b, "ANCHOR_BOTTOM")
      GameTooltip:AddLine(string.format("%s training, about +%d", tostring(M.prof), M.total or 0))
      local COLOR = { [0] = { 1, 0.5, 0.25 }, [1] = { 1, 1, 0 }, [2] = { 0.25, 0.75, 0.25 } }
      for _, r in ipairs(M.list or {}) do
        local c = COLOR[r.diff] or { 0.6, 0.6, 0.6 }
        GameTooltip:AddLine(string.format("%s x%d", tostring(r.name), r.n), c[1], c[2], c[3])
      end
      GameTooltip:AddLine("Each press makes one stack. The x hides this for 30 minutes.", 0.6, 0.6, 0.6)
      GameTooltip:Show()
    end)
    self.btn:HookScript("OnLeave", function() GameTooltip:Hide() end)
    ns.SecureButtons:Place(self.btn, "TOP", UIParent, "TOP", 0, -150)
    -- on top of other frames, so the click lands (the Feed button needed the same)
    ns.SecureButtons:Raise(self.btn, "FULLSCREEN")
    local x = CreateFrame("Button", nil, UIParent, "UIPanelCloseButton")
    x:SetSize(22, 22)
    x:SetPoint("LEFT", self.btn, "RIGHT", 2, 0)
    x:SetScript("OnClick", function() M:Snooze() end)
    self.close = x
    self.owner = self.owner or CreateFrame("Frame", "Outrider_TrainerBindings")
  end
  local body = self:Body()
  if body ~= self.body then self.body = body ns.SecureButtons:SetMacro(self.btn, body) end
  ns.SecureButtons:SetLabel(self.btn, self:Label(total))
  ns.SecureButtons:FitWidth(self.btn, 120, 420)
  ns.SecureButtons:SetShown(self.btn, true)
  if self.close then self.close:Show() end
  self:Bind(true)
  if self.announced ~= self.prof then
    self.announced = self.prof
    self:Info("training offered: %s about +%d from %d recipes", tostring(self.prof), total, #(self.list or {}))
  end
end

function M:Hide()
  if self.btn then ns.SecureButtons:SetShown(self.btn, false) end
  if self.close then self.close:Hide() end
  self:Bind(false)
end

-- The chosen key presses the button while it shows.
function M:Bind(on)
  local key = self:Settings().key
  if not self.owner then return end
  ns.Combat:Run("trainer:bind", function()
    ClearOverrideBindings(M.owner)
    if on and key and M.btn then SetOverrideBindingClick(M.owner, true, key, M.btn:GetName()) end
  end, "trainer:bind")
end

function M:SetKey(key)
  self:Settings().key = key
  self:Info("training key %s", tostring(key or "off"))
  if self.btn and self.btn:IsShown() then self:Bind(true) end
end

function M:Snooze()
  self.snoozeUntil = time() + M.SNOOZE
  self.training = false
  self:Hide()
  self:Info("training button snoozed for 30 minutes")
end

-- The fire went up: make next.
function M:OnCast(_, unit, _, spellID)
  if unit ~= "player" then return end
  -- crafting the campfire and placing it can both cast "Basic Campfire": only
  -- move on to cooking once no campfire item is left in the bags
  local name = C.SpellName(spellID)
  if type(name) == "string" and name:lower():find("campfire", 1, true) then
    ns.Timer.After(0.5, function()
      M.state = M:FireItem() and "fire" or "make"
      M.body = nil
      M:Evaluate()
    end, "trainer:fire")
  end
end

-- A refusal while training: say what's needed, once per kind.
function M:OnError(_, _, message)
  if type(message) ~= "string" or not (self.btn and self.training) then return end
  local low = message:lower()
  if self.prof == "Cooking" and low:find("fire", 1, true) then
    self.state = self:FireReady() and "fire" or "make"
    if self.state == "make" then ns.Print("cooking: stand by a fire (no Simple Wood for a campfire)") end
    self:Evaluate()
    return
  end
  self.said = self.said or {}
  for word, hint in pairs(M.NEEDS) do
    if low:find(word, 1, true) and not self.said[word] then
      self.said[word] = true
      ns.Print("%s: %s", tostring(self.prof), hint)
    end
  end
end

function M:OnEnable()
  -- cheap (a few recipes), and BAG_UPDATE_DELAYED is already batched by the game
  local function later(mod) mod:Evaluate() end
  -- drop the blank-named copy an old scan stored (2026-11-14)
  if type(ns.db.char.professions) == "table" then ns.db.char.professions[""] = nil end
  self:On("BAG_UPDATE_DELAYED", later)
  self:On("PLAYER_REGEN_ENABLED", later)
  self:On("PLAYER_REGEN_DISABLED", function(mod) mod:Hide() end)
  self:On("TRADE_SKILL_LIST_UPDATE", later)
  self:On("TRADE_SKILL_SHOW", later)
  self:On("TRADE_SKILL_CLOSE", later)
  self:On("PLAYER_ENTERING_WORLD", later)
  self:On("UNIT_SPELLCAST_SUCCEEDED", self.OnCast)
  self:On("UI_ERROR_MESSAGE", self.OnError)
end

function M:OnDisable() self:Hide() end

-- "Cooking about +12 · Alchemy about +3 · Leatherworking: open its window once"
function M:Activity()
  local parts = {}
  for _, prof in ipairs(self:Professions()) do
    local t, _, unknown = self:Estimate(nil, prof)
    if t >= 1 then parts[#parts + 1] = string.format("%s about +%d", prof, t)
    elseif unknown > 0 then parts[#parts + 1] = prof .. ": open its window once"
    else parts[#parts + 1] = prof .. ": nothing in your bags trains it" end
  end
  return #parts > 0 and table.concat(parts, " · ") or "no crafting profession yet"
end
