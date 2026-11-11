-- Modules/Welcome.lua
-- Reference module: the smallest complete example of the module pattern
-- (spec, defaults, events, settings, snapshot). Copy it when starting a new
-- module. Behavior: one chat line the first time each character logs in with
-- Outrider, then silence.

local _, ns = ...
local M = ns:NewModule("Welcome", {
  title = "Welcome message",
  phase = "P1",
  order = 1,
  defaults = { greeted = false },
})

function M:OnEnable()
  self:On("PLAYER_ENTERING_WORLD", self.OnEnteringWorld)
end

function M:OnEnteringWorld(_, isLogin, isReload)
  local s = self:Settings()
  if s.greeted then return end
  s.greeted = true
  ns.Print("loaded for %s. Type /ride to open the hub.", ns.db.key)
  self:Info("first login greeting shown (login=%s reload=%s)", tostring(isLogin), tostring(isReload))
end

function M:Snapshot()
  return { greeted = self:Settings().greeted }
end

function M:Activity() return "greets each character once" end
