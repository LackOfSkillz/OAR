-- Core/Modules.lua
-- Feature modules: one file (or folder) per feature, each switchable per
-- character. See docs/CONVENTIONS.md "Module template".
--
--   local M = ns:NewModule("RareAlerts", {
--     title = "Rare alerts", phase = "P2",
--     classes = nil,                 -- nil = every class, or { HUNTER = true }
--     requires = nil,                -- addons that must be loaded, e.g. { "Questie" }
--     yieldsTo = { "RareScanner" },  -- default OFF when one of these is loaded
--     defaultEnabled = true,
--     defaults = { sound = true },   -- per-character settings defaults
--   })
--   function M:OnInitialize() end   -- once, after SavedVariables load
--   function M:OnEnable() self:On("PLAYER_TARGET_CHANGED", self.Check) end
--   function M:OnDisable() end      -- events registered with self:On are removed for you

local _, ns = ...
local Modules = { name = "modules", list = {}, byName = {}, initialized = false }
ns.Modules = Modules

local Base = {}
Base.__index = Base
Modules.Base = Base

function Base:On(event, fn)
  local mod = self
  return ns.Events:On(event, mod, function(...) return fn(mod, ...) end)
end
function Base:Off(event) ns.Events:Off(event, self) end
function Base:Settings() return ns.DB:ModuleSettings(self.name) end
function Base:IsEnabled() return self.enabled == true end
function Base:Debug(msg, ...) return ns.Log:Debug(self.name, msg, ...) end
function Base:Info(msg, ...)  return ns.Log:Info(self.name, msg, ...) end
function Base:Warn(msg, ...)  return ns.Log:Warn(self.name, msg, ...) end
function Base:Error(msg, ...) return ns.Log:Error(self.name, msg, ...) end
-- Protected-frame work: runs now, or after combat if we are in combat.
function Base:Secure(label, fn) return ns.Combat:Run(self.name .. ":" .. label, fn, self.name .. ":" .. label) end

function ns:NewModule(name, spec)
  assert(type(name) == "string" and name:match("^%a[%w_]*$"), "module name must be an identifier")
  assert(not Modules.byName[name], "duplicate module " .. name)
  spec = spec or {}
  local mod = setmetatable({ name = name, spec = spec, enabled = false, broken = nil }, Base)
  Modules.list[#Modules.list + 1] = mod
  Modules.byName[name] = mod
  ns.DB:RegisterModuleDefaults(name, spec.defaults)
  return mod
end

function Modules:Get(name) return self.byName[name] end

-- Can this module run for this character at all?
function Modules:Eligible(mod)
  local spec = mod.spec
  if spec.classes and not spec.classes[ns.PlayerClass()] then
    return false, "not for this class"
  end
  if spec.requires then
    for _, addon in ipairs(spec.requires) do
      if not ns.Compat.IsAddOnLoaded(addon) then return false, "needs " .. addon end
    end
  end
  if mod.broken then return false, "turned off after an error" end
  return true
end

-- Should it be on? Returns bool, reason
function Modules:ShouldEnable(mod)
  local ok, reason = self:Eligible(mod)
  if not ok then return false, reason end
  local state = ns.DB:ModuleState(mod.name)
  if state.enabled ~= nil then
    return state.enabled, state.enabled and "on" or "off (your choice)"
  end
  if mod.spec.yieldsTo then
    for _, addon in ipairs(mod.spec.yieldsTo) do
      if ns.Compat.IsAddOnLoaded(addon) then return false, "off: " .. addon .. " is installed" end
    end
  end
  if mod.spec.defaultEnabled == false then return false, "off by default" end
  return true, "on"
end

function Modules:InitializeAll()
  if self.initialized then return end
  self.initialized = true
  for _, mod in ipairs(self.list) do
    if mod.OnInitialize then
      local ok = ns.Safe(mod.name .. ":OnInitialize", mod.OnInitialize, mod)
      if not ok then mod.broken = true end
    end
  end
end

function Modules:Enable(mod)
  if mod.enabled then return true end
  mod.enabled = true
  if mod.OnEnable then
    local ok = ns.Safe(mod.name .. ":OnEnable", mod.OnEnable, mod)
    if not ok then
      mod.broken = true
      self:Disable(mod)
      return false
    end
  end
  ns.Log:Debug("modules", "enabled %s", mod.name)
  return true
end

function Modules:Disable(mod)
  if not mod.enabled then return end
  ns.Events:OffAll(mod)
  mod.enabled = false
  if mod.OnDisable then ns.Safe(mod.name .. ":OnDisable", mod.OnDisable, mod) end
  ns.Log:Debug("modules", "disabled %s", mod.name)
end

function Modules:EnableAll()
  local ordered = {}
  for i, mod in ipairs(self.list) do ordered[i] = mod end
  table.sort(ordered, function(a, b) return (a.spec.order or 100) < (b.spec.order or 100) end)
  for _, mod in ipairs(ordered) do
    if self:ShouldEnable(mod) then self:Enable(mod) end
  end
end

-- User toggle from slash command or hub. Saved per character.
function Modules:SetEnabled(name, on)
  local mod = self.byName[name]
  if not mod then return false, "no module named " .. tostring(name) end
  if on then
    local ok, reason = self:Eligible(mod)
    if not ok then return false, reason end
  end
  ns.DB:ModuleState(name).enabled = on and true or false
  -- If this waits for combat to end, re-read the wanted state when it runs:
  -- a later toggle, profile import or reset may have changed it meanwhile.
  ns.Combat:Run("toggle " .. name, function()
    local want = self:ShouldEnable(mod)
    if want then self:Enable(mod) else self:Disable(mod) end
  end, "toggle:" .. name)
  return true
end

function Modules:Status()
  local out = {}
  for _, mod in ipairs(self.list) do
    local want, reason = self:ShouldEnable(mod)
    -- Optional mod:Activity() -> one short line saying what it is doing now.
    local activity
    if mod.enabled and mod.Activity then
      local ok, line = ns.Safe(mod.name .. ":Activity", mod.Activity, mod)
      if ok then activity = line end
    end
    out[#out + 1] = { name = mod.name, title = mod.spec.title or mod.name, enabled = mod.enabled,
                      want = want, reason = reason, phase = mod.spec.phase, activity = activity }
  end
  return out
end
