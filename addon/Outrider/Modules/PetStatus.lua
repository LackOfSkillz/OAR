-- Modules/PetStatus.lua  (HUNTER, P2-09)
-- Small movable panel: pet name, level, XP, health, focus, and happiness if
-- the client still has it. Forever has no GetPetHappiness/GetPetLoyalty/
-- GetPetTrainingPoints/GetPetFoodTypes (probe 2026-11-11), so:
--   * happiness shows only when an API for it exists; meanwhile the module
--     logs the pet's buffs once per session so Claude can see how Forever
--     represents happiness (auto-collected, no typing);
--   * Feed (Gary, 2026-11-13: "if I click feed it should feed my pet"): a
--     secure button with "/cast Feed Pet" + "/use <food>", so one click feeds.
--     Forever has no GetPetFoodTypes, so the diet is learned: a Feed Pet cast
--     after a click marks that food as eaten by this pet family, a red error
--     right after marks it refused; the next click picks another food.
--   * more about the pet: abilities with autocast, attack speed and damage,
--     armor, XP to the next level, and the learned diet.
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
  defaults = { pos = {}, warnUnhappy = true, show = true, collapsed = false },
})
ns.PetStatus = M

local HAPPY = { [1] = "Unhappy", [2] = "Content", [3] = "Happy" }

function M:OnEnable()
  self:On("UNIT_PET", function(mod, _, unit) if unit == "player" then mod:Update("pet changed") end end)
  self:On("UNIT_PET_EXPERIENCE", function(mod) mod:Update() end)
  self:On("UNIT_HEALTH", function(mod, _, unit) if unit == "pet" then mod:Update() end end)
  self:On("UNIT_POWER_UPDATE", function(mod, _, unit) if unit == "pet" then mod:Update() end end)
  self:On("UNIT_AURA", function(mod, _, unit) if unit == "pet" then mod:Update() end end)
  self:On("PLAYER_ENTERING_WORLD", function(mod) mod:Update("login") end)
  self:On("BAG_UPDATE_DELAYED", function(mod) mod:Update() end)
  self:On("UNIT_SPELLCAST_SUCCEEDED", self.OnCast)
  self:On("UI_ERROR_MESSAGE", self.OnError)
end

-- ------------------------------------------------------------------ diet
-- ns.db.global.petDiet[family] = { yes = { [food] = true }, no = { [food] = true } }
function M:Diet(family)
  local g = ns.db.global
  g.petDiet = type(g.petDiet) == "table" and g.petDiet or {}
  local key = tostring(family or "?")
  g.petDiet[key] = g.petDiet[key] or { yes = {}, no = {} }
  return g.petDiet[key]
end

-- Foods in the bags (item spell "Food"; conjured food is skipped: pets don't eat it).
function M:Foods()
  local out = {}
  for bag = 0, (rawget(_G, "NUM_BAG_SLOTS") or 4) do
    for slot = 1, C.NumSlots(bag) do
      local count, id = C.ItemCountAt(bag, slot)
      if id then
        local spell = C.Call("C_Item.GetItemSpell", id)
        spell = C.Readable(spell)
        if spell == "Food" or spell == "Refreshment" then
          local info = C.ItemInfo(id)
          local name = info and info.name
          if name and not name:find("Conjured", 1, true) then
            out[name] = (out[name] or 0) + (count or 1)
          end
        end
      end
    end
  end
  return out
end

-- The food to offer: one this family is known to eat (biggest stack), else
-- one not yet refused (biggest stack). Returns name, count or nil.
function M:PickFood(family)
  local diet, foods = self:Diet(family), self:Foods()
  local best, bestN, known
  for name, n in pairs(foods) do
    if not diet.no[name] then
      local k = diet.yes[name] and 1 or 0
      if not best or k > known or (k == known and n > bestN) then best, bestN, known = name, n, k end
    end
  end
  return best, bestN
end

function M:OnCast(_, unit, _, spellID)
  if unit ~= "player" or not self.offered then return end
  local name = C.SpellName(spellID)
  if name == "Feed Pet" and (C.Call("GetTime") or 0) - self.offered.t < 5 then
    local diet = self:Diet(self.offered.family)
    if not diet.yes[self.offered.food] then
      diet.yes[self.offered.food] = true
      self:Info("pet diet: %s eats %s", tostring(self.offered.family), self.offered.food)
    end
    self.offered = nil
  end
end

-- A red error right after a Feed click: this food was refused (logged with
-- the client's own words, so the wording can be checked).
function M:OnError(_, _, message)
  local o = self.offered
  local msg = C.Readable(message)
  if not o or type(msg) ~= "string" or (C.Call("GetTime") or 0) - o.t > 3 then return end
  self:Info("pet feed refused (%s): %s", o.food, msg)
  local low = msg:lower()
  if low:find("like", 1, true) or low:find("food", 1, true) or low:find("diet", 1, true) or low:find("eat", 1, true) then
    self:Diet(o.family).no[o.food] = true
    self:Update()
  end
  self.offered = nil
end

function M:OnDisable()
  ns.ThrottleCancel("petstatus")
  if self.frame then self.frame:Hide() end
  if self.feed then ns.SecureButtons:Release(self.feed) self.feed = nil end
end

-- The throttle keeps only the latest call's arguments, and health/focus
-- updates arrive many times a second, so a "pet changed" reason would be
-- lost. Remember it in a flag instead (bug seen in game 2026-11-11).
function M:Update(why)
  if why then self.logPending = true end
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
  -- raw (possibly secret) values, only ever passed to SetText
  d.rawHp, d.rawFocus = C.Call("UnitHealth", "pet"), C.Call("UnitPower", "pet")
  d.xp, d.xpMax = C.Call("GetPetExperience")
  d.speed = C.Readable(C.Call("UnitAttackSpeed", "pet"))
  local lo, hi = C.Call("UnitDamage", "pet")
  d.dmgLo, d.dmgHi = C.Readable(lo), C.Readable(hi)
  local _, armor = C.Call("UnitArmor", "pet")
  d.armor = C.Readable(armor)
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

-- Average damage per second of plain attacks: mid hit / attack speed.
function M.DPS(lo, hi, speed)
  if type(lo) ~= "number" or type(hi) ~= "number" or type(speed) ~= "number" or speed <= 0 then return nil end
  return (lo + hi) / 2 / speed
end

-- The pet's own abilities from its action bar (not Attack/Follow/Stay, which
-- are "tokens"), with "auto" when autocast is on.
function M:Abilities()
  local out = {}
  for i = 1, (rawget(_G, "NUM_PET_ACTION_SLOTS") or 10) do
    local name, _, isToken, _, autoAllowed, autoOn = C.Call("GetPetActionInfo", i)
    name = C.Readable(name)
    if type(name) == "string" and not isToken then
      out[#out + 1] = name .. ((autoAllowed and autoOn) and " (auto)" or "")
    end
  end
  return out
end

-- Put a value on screen whether it is plain or secret.
function M.ShowRaw(fs, v)
  if v == nil then fs:SetText("?") return end
  if not C.IsSecret(v) then fs:SetText(tostring(v)) return end
  if not pcall(fs.SetText, fs, v) then fs:SetText("?") end
end

function M:Build()
  if self.frame then return self.frame end
  local s = self:Settings()
  local f = UI:Window("Outrider_PetStatus", "Pet", 280, M.OPEN_H, s.pos)
  -- the corner button folds the panel up to its header and opens it again
  -- (Gary, 2026-11-13: "an up or down arrow, the header stays on screen")
  f.close.label:Hide()
  -- the title stops before the Feed button that sits in the folded header
  f.title:SetPoint("RIGHT", f.bar, "RIGHT", -100, 0)
  f.title:SetJustifyH("LEFT")
  if f.title.SetWordWrap then f.title:SetWordWrap(false) end
  f.close.arrow = f.close:CreateTexture(nil, "ARTWORK")
  f.close.arrow:SetSize(16, 16)
  f.close.arrow:SetPoint("CENTER")
  f.close:SetScript("OnClick", function() M:SetCollapsed(not M:Settings().collapsed) end)
  local c = f.content
  f.line1 = UI.Text(c, "normal", "text") f.line1:SetPoint("TOPLEFT", 0, 0)
  f.line2 = UI.Text(c, "small", "muted") f.line2:SetPoint("TOPLEFT", 0, -18)
  -- Health and focus can be secret values on Forever (seen 2026-11-11: current
  -- health and focus hidden, max health readable). Secrets may be shown but
  -- not combined or compared (C6), so each number gets its own text that is
  -- handed the raw value.
  f.line3 = UI.Text(c, "small", "muted") f.line3:SetPoint("TOPLEFT", 0, -34) f.line3:SetText("Health")
  f.hpVal = UI.Text(c, "small", "text") f.hpVal:SetPoint("LEFT", f.line3, "RIGHT", 4, 0)
  f.hpMax = UI.Text(c, "small", "muted") f.hpMax:SetPoint("LEFT", f.hpVal, "RIGHT", 2, 0)
  f.focusLabel = UI.Text(c, "small", "muted") f.focusLabel:SetPoint("LEFT", f.hpMax, "RIGHT", 10, 0) f.focusLabel:SetText("Focus")
  f.focusVal = UI.Text(c, "small", "text") f.focusVal:SetPoint("LEFT", f.focusLabel, "RIGHT", 4, 0)
  f.line4 = UI.Text(c, "small", "text") f.line4:SetPoint("TOPLEFT", 0, -50)
  f.fight = UI.Text(c, "small", "muted") f.fight:SetPoint("TOPLEFT", 0, -66) f.fight:SetWidth(256) f.fight:SetJustifyH("LEFT")
  f.skills = UI.Text(c, "small", "text") f.skills:SetPoint("TOPLEFT", 0, -96) f.skills:SetWidth(236)
  f.skills:SetJustifyH("LEFT")
  f.diet = UI.Text(c, "small", "muted") f.diet:SetPoint("TOPLEFT", 0, -126) f.diet:SetWidth(170)
  f.diet:SetJustifyH("LEFT")
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
    -- remember which food this click offered, to learn the diet (a plain hook,
    -- the secure click itself is untouched)
    if self.feed.HookScript then
      self.feed:HookScript("PostClick", function()
        M:Info("feed clicked: %s (in combat %s)", tostring(M.feedText), tostring(C.InCombat()))
        if M.food then M.offered = { food = M.food, family = M.family, t = C.Call("GetTime") or 0 } end
      end)
    end
  end
  self:SetFood()
  local cx, cy = f:GetCenter()
  if not cx then return end
  local w, h = f:GetWidth() or 220, f:GetHeight() or 120
  if self:Settings().collapsed then
    -- folded: Feed sits in the header, left of the up/down arrow (Gary,
    -- 2026-11-13: it covered the arrow, so the panel couldn't be opened)
    ns.SecureButtons:Place(self.feed, "TOPRIGHT", UIParent, "BOTTOMLEFT", cx + w / 2 - 30, cy + h / 2 - 5)
  else
    ns.SecureButtons:Place(self.feed, "BOTTOMRIGHT", UIParent, "BOTTOMLEFT", cx + w / 2 - 8, cy - h / 2 + 8)
  end
  ns.SecureButtons:Raise(self.feed, "FULLSCREEN") -- above the panel (DIALOG), or the panel eats the click
  ns.SecureButtons:SetShown(self.feed, true)
end

-- Write the Feed button's macro for the food to offer (out of combat; the
-- secure button waits for combat to end).
function M:SetFood()
  if not self.feed then return end
  local food, n = self:PickFood(self.family)
  local text = food and ("Feed Pet on " .. food) or "Feed Pet"
  if text ~= self.feedText then
    self.feedText, self.food = text, food
    ns.SecureButtons:SetSpellOnItem(self.feed, "Feed Pet", food)
    ns.SecureButtons:SetLabel(self.feed, food and "Feed" or "Feed (pick food)")
  end
  self.foodCount = n
end

-- Show or hide the pet panel (and its Feed button), remembered per character.
M.OPEN_H, M.HEADER_H = 200, 34 -- folded height fits Feed and the arrow side by side

-- Fold to the header bar or open again. The header's top-left corner stays
-- put: the panel is pinned by TOPLEFT before its height changes.
function M:ApplyCollapsed()
  local f = self.frame
  if not f then return end
  local s = self:Settings()
  local left, top, parentTop = f:GetLeft(), f:GetTop(), UIParent and UIParent:GetTop()
  if left and top and parentTop then
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", left, top - parentTop)
    s.pos.point, s.pos.x, s.pos.y = "TOPLEFT", math.floor(left + 0.5), math.floor(top - parentTop + 0.5)
  end
  f:SetHeight(s.collapsed and M.HEADER_H or M.OPEN_H)
  f.content:SetShown(not s.collapsed)
  f.close.arrow:SetTexture(s.collapsed and "Interface\\Buttons\\Arrow-Down-Up" or "Interface\\Buttons\\Arrow-Up-Up")
  if self.feed then
    self:PlaceFeed()
  end
end

function M:SetCollapsed(on)
  self:Settings().collapsed = on and true or false
  self:ApplyCollapsed()
end

function M:SetPanel(on)
  self:Settings().show = on and true or false
  self:Info("pet panel %s", on and "shown" or "hidden")
  if on then
    self:Update()
  else
    if self.frame then self.frame:Hide() end
    if self.feed then ns.SecureButtons:SetShown(self.feed, false) end
    ns.Print("pet panel hidden. Show it again on your Hunter page in Outrider.")
  end
end

function M:Refresh(why)
  local d = self:Read()
  if self.logPending then self.logPending = false self:LogPet(d) end
  if not self:Settings().show then d = nil end
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
  M.ShowRaw(f.hpVal, d.rawHp)
  f.hpMax:SetText("/ " .. tostring(d.hpMax or "?"))
  M.ShowRaw(f.focusVal, d.rawFocus)
  f.line4:SetText(d.happiness and ("Happiness: " .. (HAPPY[d.happiness] or tostring(d.happiness))) or "")
  self.family = d.family
  if d.xp and d.xpMax and d.xpMax > 0 then
    f.line2:SetText(string.format("XP %d / %d (%.0f%%), %d to level %d", d.xp, d.xpMax, d.xp / d.xpMax * 100,
      d.xpMax - d.xp, (tonumber(d.level) or 0) + 1))
  end
  local fight = {}
  if type(d.dmgLo) == "number" and type(d.dmgHi) == "number" then
    fight[#fight + 1] = string.format("Hits %d-%d", math.floor(d.dmgLo), math.floor(d.dmgHi + 0.5))
  end
  if type(d.speed) == "number" then fight[#fight + 1] = string.format("every %.1fs", d.speed) end
  if type(d.armor) == "number" then fight[#fight + 1] = string.format("armor %d", d.armor) end
  f.fight:SetText(table.concat(fight, ", "))
  -- How useful is it (Gary, 2026-11-13): average damage per second from its
  -- basic attacks, next to your own ranged weapon's. No combat log (hard
  -- rule 4), so abilities like Bite add on top of this.
  local dps = M.DPS(d.dmgLo, d.dmgHi, d.speed)
  if dps then
    local _, rlo, rhi = C.Call("UnitRangedDamage", "player")
    local rspeed = C.Call("UnitRangedDamage", "player")
    local mine = M.DPS(C.Readable(rlo), C.Readable(rhi), C.Readable(rspeed))
    f.title:SetText(string.format("%s  |cffbbbbbb%d DPS|r", d.name or "Pet", math.floor(dps + 0.5)))
    f.fight:SetText(string.format("About %.1f damage per second from its attacks%s. %s", dps,
      mine and string.format(" (your ranged weapon: %.1f)", mine) or "", table.concat(fight, ", ")))
  end
  local skills = self:Abilities()
  f.skills:SetText(#skills > 0 and ("Abilities: " .. table.concat(skills, ", ")) or "")
  local diet = self:Diet(d.family)
  local yes = {}
  for food in pairs(diet.yes) do yes[#yes + 1] = food end
  table.sort(yes)
  local food = self:PickFood(d.family)
  f.diet:SetText((food and ("Feeds: " .. food .. (self.foodCount and (" (" .. self.foodCount .. ")") or "")) or "No food it eats in your bags")
    .. (#yes > 0 and ("\nEats: " .. table.concat(yes, ", ")) or ""))
  self:CheckUnhappy(d)
  if not f:IsShown() then f:Show() self:ApplyCollapsed() end
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
  -- attack speed and damage too (Gary, 2026-11-14: "Mystmane is supposed to
  -- be one of the fastest bears"; wild readings all say 2.0)
  self:Info("pet %s npcID=%s family=%s level=%s xp=%s/%s focus=%s happinessAPI=%s speed=%s damage=%s-%s buffs=[%s]", tostring(d.name),
    tostring(d.npcID), tostring(d.family), tostring(d.level), tostring(d.xp), tostring(d.xpMax), tostring(d.focus),
    tostring(d.happiness), type(d.speed) == "number" and string.format("%.2f", d.speed) or "?",
    tostring(d.dmgLo), tostring(d.dmgHi), table.concat(self:Auras(), ", "))
  self:LogStable()
end

-- Forever shows loyalty ("Rebellious", Gary's Mystmane, 2026-11-11) though
-- GetPetLoyalty/GetPetHappiness are gone. Log every plain field the modern
-- stable API returns for the active pets, once per session, to find them.
function M:LogStable()
  if self.stableLogged then return end
  local get = C.Resolve("C_StableInfo.GetStablePetInfo")
  if type(get) ~= "function" then return end
  self.stableLogged = true
  for slot = 1, 5 do
    local ok, info = pcall(get, slot)
    if ok and type(info) == "table" then
      local parts = {}
      for k, v in pairs(info) do
        if type(v) ~= "table" and type(v) ~= "function" then
          parts[#parts + 1] = tostring(k) .. "=" .. tostring(C.Readable(v))
        end
      end
      table.sort(parts)
      self:Info("stable slot %d: %s", slot, table.concat(parts, " "))
    end
  end
end

function M:Snapshot()
  local d = self:Read()
  return d and { name = d.name, level = d.level, family = d.family, xp = d.xp, xpMax = d.xpMax } or nil
end

function M:Activity()
  local d = self:Read()
  if not d then return "no pet out" end
  local food = self:PickFood(d.family)
  return string.format("%s, level %s %s; feeds %s", tostring(d.name), tostring(d.level), tostring(d.family or ""),
    food or "nothing in your bags it eats")
end
