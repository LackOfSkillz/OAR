-- Modules/BuffRow.lua  (Gary, 2026-11-19: "capture all of the useful features"
-- from the macro addons we looked at; idea from MacroKit, written our own way)
-- A small row of icons above your action bars for your own self-buffs that are
-- missing or about to run out. Each icon is a secure button: clicking it casts
-- the buff on you, the same as pressing a macro (rule 1: your click does it).
-- Buttons only change out of combat (rule 5); in a fight the row stays as it
-- was. Only spells your character knows are offered, so a name that is wrong
-- on this client simply never shows. verified = false until seen in game.

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("BuffRow", {
  title = "Missing buffs row",
  phase = "P4",
  order = 63,
  defaults = { on = true, soon = 60, x = 0, y = 190 },
  yieldsTo = { "MacroKit" }, -- it has its own missing-buffs row
})
ns.BuffRow = M

-- Self-buffs per class, in the order to put them up. A group lists buffs
-- that replace each other (only one armor at a time): the first one known is
-- offered, and any of them counts as up.
M.BUFFS = {
  MAGE = { { "Arcane Intellect" }, { "Molten Armor", "Mage Armor", "Ice Armor", "Frost Armor" } },
  PRIEST = { { "Power Word: Fortitude" }, { "Inner Fire" }, { "Shadowform" } },
  DRUID = { { "Mark of the Wild" }, { "Thorns" } },
  WARLOCK = { { "Fel Armor", "Demon Armor", "Demon Skin" } },
  PALADIN = { { "Blessing of Might", "Blessing of Kings", "Blessing of Wisdom" },
    { "Devotion Aura", "Retribution Aura", "Concentration Aura" } },
  SHAMAN = { { "Lightning Shield", "Water Shield" } },
  HUNTER = { { "Trueshot Aura" } }, -- aspects and seals stay in the fight keys, which switch them as you fight
  WARRIOR = { { "Battle Shout" } },
  ROGUE = {},
}
M.MAX = 5

local function known(name) return ns.Spellbook and ns.Spellbook:Known(name) ~= nil end

-- seconds left on a buff of yours, or nil when it isn't up (0 = no end)
function M.Remaining(name)
  local get = C.Resolve("C_UnitAuras.GetAuraDataByIndex")
  if type(get) ~= "function" then return nil end
  local now = C.Call("GetTime") or 0
  for i = 1, 40 do
    local ok, a = pcall(get, "player", i, "HELPFUL")
    if not ok or type(a) ~= "table" then break end
    if C.Readable(a.name) == name then
      local exp = C.Readable(a.expirationTime)
      if type(exp) ~= "number" or exp == 0 then return 0 end
      return math.max(0, exp - now)
    end
  end
  return nil
end

-- The buffs to offer now: { {spell, why} }, "missing" or "runs out in Ns".
function M:Wanted()
  local out, soon = {}, self:Settings().soon or 60
  for _, group in ipairs(M.BUFFS[ns.PlayerClass()] or {}) do
    local offer, up, left
    for _, name in ipairs(group) do
      if known(name) then
        offer = offer or name
        local r = M.Remaining(name)
        if r then up, left = name, r end
      end
    end
    if offer then
      if not up then out[#out + 1] = { spell = offer, why = "missing" }
      elseif left > 0 and left < soon then out[#out + 1] = { spell = up, why = string.format("runs out in %ds", math.floor(left)) } end
    end
    if #out >= M.MAX then break end
  end
  return out
end

-- Re-draws the row (out of combat only: the buttons are secure).
function M:Update(why)
  if not self.enabled or C.InCombat() then return end
  local SB = ns.SecureButtons
  if not SB then return end
  self.btns = self.btns or {}
  local want = self:Settings().on and self:Wanted() or {}
  local s = self:Settings()
  for i = 1, M.MAX do
    local w = want[i]
    local b = self.btns[i]
    if w and not b then
      b = SB:Acquire("buffrow")
      if not b then break end
      self.btns[i] = b
      b.icon = b.icon or b:CreateTexture(nil, "ARTWORK")
      b.icon:SetAllPoints()
      ns.Combat:Run("buffrow:size", function() b:SetSize(32, 32) end, "buffrow:size:" .. i)
      b:HookScript("OnEnter", function(self)
        if not self.buff then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(self.buff.spell)
        GameTooltip:AddLine(self.buff.why .. ": click to put it on yourself", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
      end)
      b:HookScript("OnLeave", function() GameTooltip:Hide() end)
    end
    if b then
      b.buff = w
      if w then
        SB:SetMacro(b, "/cast [@player] " .. w.spell)
        SB:SetLabel(b, "")
        b.icon:SetTexture(C.SpellIcon((ns.Spellbook:Known(w.spell) or {}).id or w.spell) or "Interface\\Icons\\INV_Misc_QuestionMark")
        SB:Place(b, "BOTTOM", UIParent, "BOTTOM", s.x + (i - 1) * 36 - (#want - 1) * 18, s.y)
        SB:SetShown(b, true)
      else
        SB:SetShown(b, false)
      end
    end
  end
  self.shown = #want
  -- look again when the next buff that's up enters its last minute (one timer, no ticker)
  if self.later then self.later:Cancel() self.later = nil end
  local next
  for _, group in ipairs(M.BUFFS[ns.PlayerClass()] or {}) do
    for _, name in ipairs(group) do
      local r = known(name) and M.Remaining(name)
      if r and r > (s.soon or 60) then
        local d = r - (s.soon or 60) + 1
        if not next or d < next then next = d end
      end
    end
  end
  if next and s.on then self.later = ns.Timer.After(next, function() M.later = nil M:Update("expiring") end, "buffrow:later") end
  if why and #want > 0 then self:Debug("buff row (%s): %d", tostring(why), #want) end
end

function M:OnEnable()
  local function upd(mod, ev) ns.Throttle("buffrow", 1, function() mod:Update(ev) end) end
  self:On("PLAYER_ENTERING_WORLD", upd)
  self:On("PLAYER_REGEN_ENABLED", upd)
  self:On("SPELLS_CHANGED", upd)
  self:On("UNIT_AURA", function(mod, ev, unit) if unit == "player" then upd(mod, ev) end end)
end

function M:OnDisable()
  ns.ThrottleCancel("buffrow")
  if self.later then self.later:Cancel() self.later = nil end
  for _, b in ipairs(self.btns or {}) do ns.SecureButtons:SetShown(b, false) end
end

function M:Activity()
  local n = #(M.BUFFS[ns.PlayerClass()] or {})
  if n == 0 then return "no self-buffs for your class" end
  return string.format("%d of your buffs missing or running out (row above your bars)", self.shown or 0)
end

ns.AddCommand("buffs", "on|off  the missing-buffs row above your action bars", function(arg)
  local s = M:Settings()
  if arg == "on" or arg == "off" then s.on = arg == "on" M:Update("command") end
  ns.Print("missing-buffs row %s", s.on and "on" or "off")
end)
