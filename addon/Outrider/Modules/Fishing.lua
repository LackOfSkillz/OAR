-- Modules/Fishing.lua  (P5-11)
-- One key for fishing while a fishing pole is equipped and Gary chose a key
-- (setting `key`, /ride fishkey <KEY>; off until chosen):
--   bobber not out -> the key clicks a pooled secure button: /cast Fishing
--   bobber out     -> the key does the client's INTERACTTARGET binding,
--                     which hooks the bobber on modern clients (soft interact)
-- The switch happens on the Fishing channel start/stop, out of combat only
-- (override bindings are protected in combat). Every cast and hook is Gary's
-- key press; nothing fires by itself.
-- While fishing mode is on, sound effects go up and music/ambience down;
-- the old values come back when the pole comes off.

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("Fishing", {
  title = "Fishing on one key",
  phase = "P5",
  order = 75,
  defaults = { key = nil, loudSplash = true },
})
ns.Fishing = M

local POLE_CLASS, POLE_SUBCLASS = 2, 20
local LOUD = { Sound_SFXVolume = "1.0", Sound_MusicVolume = "0.0", Sound_AmbienceVolume = "0.1" }
-- Soft targeting for objects, so the Interact key reaches the bobber without
-- the mouse on it (Gary, 2026-11-14: "it casts but won't catch"). 3 = on for
-- mouse and keyboard; arc 2 = wide; range in yards (the bobber lands about
-- 20 away). Only while the pole is on; the old values come back after.
-- autoLootDefault: Blizzard's own Auto Loot option, so the press that hooks
-- the fish also takes it (Gary, 2026-11-14); restored with the rest.
local SOFT = { SoftTargetInteract = "3", SoftTargetInteractArc = "2", SoftTargetInteractRange = "30", autoLootDefault = "1" }

function M:PoleEquipped()
  local link = C.Call("GetInventoryItemLink", "player", 16)
  local id = link and tonumber(link:match("item:(%d+)"))
  if not id then return false end
  local get = C.Resolve("C_Item.GetItemInfoInstant") or rawget(_G, "GetItemInfoInstant")
  if type(get) ~= "function" then return false end
  local ok, _, _, _, _, _, class, subclass = pcall(get, id)
  return ok and class == POLE_CLASS and subclass == POLE_SUBCLASS
end

-- Lures by name, best first (Classic bonuses: Attractor +100, Flesh Eating Worm
-- and Bright Baubles +75, Fish Lens and Nightcrawlers +50, Shiny Bauble +25;
-- wowhead classic item pages, unverified on Forever). Gary, 2026-11-14: the
-- fish key puts a lure on when none is active, then casts on the next press.
M.LURES = { "Aquadynamic Fish Attractor", "Flesh Eating Worm", "Bright Baubles", "Aquadynamic Fish Lens",
  "Nightcrawlers", "Shiny Bauble" }

function M:LureActive()
  return C.Readable((C.Call("GetWeaponEnchantInfo"))) and true or false
end

-- The best lure in the bags that hasn't failed this session, or nil.
function M:LureInBags()
  self.badLure = self.badLure or {}
  local have = {}
  for bag = 0, 4 do
    for slot = 1, (C.Call("C_Container.GetContainerNumSlots", bag) or 0) do
      local info = C.Call("C_Container.GetContainerItemInfo", bag, slot)
      local it = type(info) == "table" and info.itemID and C.ItemInfo(info.itemID)
      if it and it.name then have[it.name] = true end
    end
  end
  -- your usual lure first (picked on the fishing ring), then the best
  local usual = ns.FishingRing and ns.FishingRing.enabled and ns.FishingRing:Settings().lure
  if usual and have[usual] and not self.badLure[usual] then return usual end
  for _, name in ipairs(M.LURES) do
    if have[name] and not self.badLure[name] then return name end
  end
  return nil
end

function M:Body()
  if not self:LureActive() then
    local lure = self:LureInBags()
    if lure then return "/use " .. lure .. "\n/use 16", lure end
  end
  return "/cast Fishing"
end

-- Rewrite the cast button when the lure state changes (combat-deferred).
function M:RefreshMacro()
  if not (self.on and self.button) then return end
  local body, lure = self:Body()
  self.lureNow = lure
  if body ~= self.body then
    self.body = body
    ns.SecureButtons:SetMacro(self.button, body)
  end
end

-- After a press that used a lure: if no lure took (skill too low, say), stop
-- offering that lure so the key goes back to casting.
function M:CheckLure(name)
  if not name or self:LureActive() then return end
  self.badLure = self.badLure or {}
  self.badLure[name] = true
  ns.Print("fishing: %s didn't go on (fishing skill too low?); the key casts without it", name)
  self:Info("lure %s failed, skipped this session", name)
  self:RefreshMacro()
end

function M:OnEnable()
  self.owner = self.owner or CreateFrame("Frame", "Outrider_FishingBindings")
  self:On("UNIT_INVENTORY_CHANGED", function(mod, _, unit) if unit == "player" then mod:RefreshMacro() end end)
  self:On("BAG_UPDATE_DELAYED", self.RefreshMacro)
  self:On("PLAYER_ENTERING_WORLD", self.Update)
  self:On("PLAYER_EQUIPMENT_CHANGED", self.Update)
  self:On("UNIT_SPELLCAST_CHANNEL_START", function(mod, _, unit, _, spellID) mod:OnChannel(unit, spellID, true) end)
  self:On("UNIT_SPELLCAST_CHANNEL_STOP", function(mod, _, unit, _, spellID) mod:OnChannel(unit, spellID, false) end)
end

function M:OnDisable() self:SetMode(false) end

function M:Update()
  self:SetMode(self:PoleEquipped())
end

local function isFishing(spellID)
  local info = C.Call("C_Spell.GetSpellInfo", spellID)
  local name = type(info) == "table" and info.name or C.Call("GetSpellInfo", spellID)
  return C.Readable(name) == "Fishing"
end

function M:OnChannel(unit, spellID, started)
  if unit ~= "player" or not self.on or not isFishing(spellID) then return end
  self.bobber = started
  self:RefreshMacro()
  self:Bind()
end

-- Point the chosen key at the cast button or at the interact binding.
function M:Bind()
  local key = self:Settings().key
  if not key or not self.button then return end
  ns.Combat:Run("fishing:bind", function()
    ClearOverrideBindings(M.owner)
    if not M.on then return end
    if M.bobber then
      SetOverrideBinding(M.owner, true, key, "INTERACTTARGET")
    else
      SetOverrideBindingClick(M.owner, true, key, M.button:GetName())
    end
  end, "fishing:bind")
end

function M:SetMode(on)
  on = on and true or false
  if on == (self.on or false) then return end
  self.on = on
  if on then
    if not self.button then
      self.button = ns.SecureButtons:Acquire("Fishing")
      self.body = nil
      if self.button then
        self:RefreshMacro()
        if not self.button.outriderLureHook then
          self.button.outriderLureHook = true
          self.button:HookScript("PostClick", function()
            local lure = M.lureNow
            if lure then ns.Timer.After(3, function() M:CheckLure(lure) end, "fishing:lure") end
          end)
        end
      end
    end
    self:Loud(true)
    self:SoftInteract(true)
    self:Info("fishing mode on (key %s)", tostring(self:Settings().key or "not set"))
  else
    self.bobber = false
    ns.Combat:Run("fishing:bind", function() ClearOverrideBindings(M.owner) end, "fishing:bind")
    self:Loud(false)
    self:SoftInteract(false)
    if self.button then ns.SecureButtons:Release(self.button) self.button = nil end
    self:Info("fishing mode off")
  end
  self:Bind()
end

function M:SoftInteract(on)
  if self:Settings().softInteract == false then return end
  local get, set = C.Resolve("C_CVar.GetCVar") or rawget(_G, "GetCVar"), C.Resolve("C_CVar.SetCVar") or rawget(_G, "SetCVar")
  if type(get) ~= "function" or type(set) ~= "function" then return end
  ns.Combat:Run("fishing:soft", function()
    if on then
      M.softSaved = M.softSaved or {}
      local now = {}
      for cvar, value in pairs(SOFT) do
        if M.softSaved[cvar] == nil then M.softSaved[cvar] = get(cvar) end
        pcall(set, cvar, value)
        now[#now + 1] = cvar .. "=" .. tostring(get(cvar))
      end
      table.sort(now)
      M:Info("bobber soft target on: %s", table.concat(now, " "))
    elseif M.softSaved then
      for cvar, value in pairs(M.softSaved) do if value ~= nil then pcall(set, cvar, value) end end
      M.softSaved = nil
    end
  end, "fishing:soft")
end

function M:Loud(on)
  if not self:Settings().loudSplash then return end
  local get, set = C.Resolve("C_CVar.GetCVar") or rawget(_G, "GetCVar"), C.Resolve("C_CVar.SetCVar") or rawget(_G, "SetCVar")
  if type(get) ~= "function" or type(set) ~= "function" then return end
  if on then
    self.saved = {}
    for cvar, value in pairs(LOUD) do self.saved[cvar] = get(cvar) pcall(set, cvar, value) end
  elseif self.saved then
    for cvar, value in pairs(self.saved) do if value ~= nil then pcall(set, cvar, value) end end
    self.saved = nil
  end
end

function M:Activity()
  local key = self:Settings().key
  if not key then return "pick a key: /ride fishkey <KEY>" end
  return string.format("key %s; %s", key, self.on and "fishing mode ON" or "equip a fishing pole to start")
end

ns.AddCommand("fishkey", "<KEY>|off  the key that casts Fishing and hooks the bobber", function(arg)
  if not arg then ns.Print("usage: /ride fishkey <KEY> (e.g. F) or /ride fishkey off") return end
  local s = M:Settings()
  if arg:lower() == "off" then s.key = nil else s.key = arg:upper() end
  ns.Print("fishing key: %s", tostring(s.key or "off"))
  M:Bind()
end)
