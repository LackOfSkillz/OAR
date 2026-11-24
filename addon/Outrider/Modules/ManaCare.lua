-- Modules/ManaCare.lua  (requirement 2026-11-22: the healing macro should
-- include mana restoration, using mana potions only below a
-- set mana level)
-- A macro can't see your mana (no [mana<30] condition exists; FOREVER_CONSTRAINTS),
-- and Outrider may not press anything for you (hard rule 1). So, the legal way:
--   * the best mana potion in your bags goes on Alt of the Heal key (and Ctrl
--     of the Recover key for classes without one); Outrider rewrites the name
--     out of combat when your bags change;
--   * in a fight, when your mana drops under the threshold (30% unless you set
--     another) and the potion is ready, a cue says so once per fight: "Mana
--     24%: Alt + Heal drinks Lesser Mana Potion". You press it.
-- Best = the potion you can use that sells for most (bigger potions sell for more).

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("ManaCare", {
  title = "Mana potion on Alt and a low mana cue",
  phase = "P4",
  order = 33,
  defaults = { cue = true, threshold = 30 },
})
ns.ManaCare = M

-- classes that use mana (a warrior or rogue never needs this)
M.MANA = { DRUID = true, PRIEST = true, PALADIN = true, SHAMAN = true, MAGE = true, WARLOCK = true, HUNTER = true }
M.HEALERS = { DRUID = true, PRIEST = true, PALADIN = true, SHAMAN = true }

function M.UsesMana() return M.MANA[ns.PlayerClass() or ""] == true end

-- Best usable mana potion in the bags: { name, id } or nil.
function M.Scan()
  local level = tonumber(C.Call("UnitLevel", "player")) or 1
  local best
  for bag = 0, 4 do
    for slot = 1, (tonumber(C.Call("C_Container.GetContainerNumSlots", bag)) or 0) do
      local info = C.Call("C_Container.GetContainerItemInfo", bag, slot)
      local id = type(info) == "table" and C.Readable(info.itemID)
      local item = id and C.ItemInfo(id)
      local name = item and item.name
      if type(name) == "string" and name:find("Mana Potion", 1, true) and (tonumber(item.reqLevel) or 0) <= level then
        local worth = tonumber(item.sellPrice) or 0
        if not best or worth > best.worth then best = { name = name, id = id, worth = worth } end
      end
    end
  end
  return best
end

function M:OnEnable()
  self.potion = M.UsesMana() and M.Scan() or nil
  self:On("BAG_UPDATE_DELAYED", function(mod) ns.Throttle("manacare", 1, function() mod:BagsChanged() end) end)
  self:On("PLAYER_LEVEL_UP", function(mod) mod:BagsChanged() end)
  self:On("UNIT_POWER_UPDATE", function(mod, _, unit) if unit == "player" then mod:Check() end end)
  self:On("PLAYER_REGEN_ENABLED", function(mod) mod.cued = false mod:HideCue() end)
end

function M:OnDisable() ns.ThrottleCancel("manacare") self:HideCue() end

-- The name the Heal / Recover keys use, or nil.
function M:Potion() return self.enabled and self.potion and self.potion.name or nil end

function M:BagsChanged()
  if not M.UsesMana() then return end
  local was = self:Potion()
  self.potion = M.Scan()
  local now = self:Potion()
  if was ~= now then
    self:Debug("mana potion: %s -> %s", tostring(was), tostring(now))
    local F = ns.HunterFight
    if F and F.enabled and F:Settings().auto and F.Update then F:Update("mana potion") end
    if ns.ComboKeys and ns.ComboKeys.enabled and ns.ComboKeys.Update then pcall(ns.ComboKeys.Update, ns.ComboKeys, "mana potion") end
  end
end

-- Mana as a percent, or nil when the client won't say (secret values: rule 4).
function M.ManaPct()
  local cur = tonumber(C.Readable(C.Call("UnitPower", "player", 0)))
  local max = tonumber(C.Readable(C.Call("UnitPowerMax", "player", 0)))
  if not cur or not max or max <= 0 then return nil end
  return cur / max * 100
end

function M.PotionReady(id)
  local start, dur = C.Call("C_Container.GetItemCooldown", id)
  start, dur = tonumber(C.Readable(start)), tonumber(C.Readable(dur))
  if not start or not dur or dur == 0 then return true end
  local now = tonumber(C.Call("GetTime")) or 0
  return start + dur <= now
end

-- The words of the cue: which key does what.
function M:CueText(pct)
  local p = self:Potion()
  if not p then return nil end
  local key = M.HEALERS[ns.PlayerClass() or ""] and "Alt + Heal" or "Ctrl + Recover"
  local first
  for _, n in ipairs({ "Innervate", "Inner Focus" }) do if not first and ns.Spellbook and ns.Spellbook:Known(n) then first = n end end
  if first and key == "Alt + Heal" then return string.format("Mana %d%%: %s (%s, then %s)", math.floor(pct + 0.5), key, first, p) end
  return string.format("Mana %d%%: %s drinks %s", math.floor(pct + 0.5), key, p)
end

function M:Check()
  local s = self:Settings()
  if not s.cue or self.cued or not C.InCombat() or not self.potion then return end
  local pct = M.ManaPct()
  if not pct or pct >= (tonumber(s.threshold) or 30) then return end
  if not M.PotionReady(self.potion.id) then return end
  self.cued = true
  local text = self:CueText(pct)
  self:Info("low mana cue: %s", tostring(text))
  self:ShowCue(text)
end

function M:Frame()
  if self.frame then return self.frame end
  local f = C.Call("CreateFrame", "Frame", "Outrider_ManaCue", rawget(_G, "UIParent"))
  if not f then return nil end
  f:SetSize(520, 40)
  f:SetPoint("CENTER", rawget(_G, "UIParent"), "CENTER", 0, 170)
  f.text = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  f.text:SetAllPoints()
  f.text:SetTextColor(0.45, 0.7, 1)
  f:Hide()
  self.frame = f
  return f
end

function M:ShowCue(text)
  local f = self:Frame()
  if not f or not text then return end
  f.text:SetText(text)
  f:Show()
  ns.Timer.After(6, function() M:HideCue() end, "manacare:hide")
end

function M:HideCue() if self.frame then self.frame:Hide() end end

function M:Activity()
  if not M.UsesMana() then return "your class doesn't use mana" end
  return string.format("mana potion on the key: %s; cue under %d%% mana: %s", tostring(self:Potion() or "none in your bags"),
    tonumber(self:Settings().threshold) or 30, self:Settings().cue and "on" or "off")
end
