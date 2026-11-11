-- Modules/AutoCheck.lua
-- Collects the Phase 0/1 test data by itself so Gary doesn't have to type
-- commands in the middle of a fight. Read-only: it records what the client
-- lets us read and exercises Outrider's own combat queue. It never casts,
-- targets or clicks anything (hard rule 1).
--   * After login, out of combat: full API probe once per Outrider build.
--   * Out of combat: unit samples on the first 2 target changes per session.
--   * Each of the first 3 combats per session: an in-combat unit sample one
--     second in, a sample on the first target change during the fight, and a
--     combat-queue job that must run when the fight ends. If the secure test
--     button exists, its macro swap is queued too (tests the deferral).
-- Results land in the saved log; Gary only needs to /reload afterwards.

local _, ns = ...
local M = ns:NewModule("AutoCheck", {
  title = "Automatic test checks",
  phase = "P0",
  order = 2,
  defaults = {},
})

local MAX_COMBATS, MAX_IDLE_SAMPLES = 3, 2

function M:OnEnable()
  self.combats, self.idleSamples, self.combatTargetSampled = 0, 0, false
  self:On("PLAYER_ENTERING_WORLD", self.OnEnteringWorld)
  self:On("PLAYER_REGEN_DISABLED", self.OnCombatStart)
  self:On("PLAYER_TARGET_CHANGED", self.OnTarget)
end

function M:OnDisable()
  if self.probeTimer then self.probeTimer:Cancel() self.probeTimer = nil end
end

function M:OnEnteringWorld()
  local p = ns.db.global.probe
  if p and p.addonBuild == ns.build then return end
  if self.probeTimer then return end
  -- Let the world finish loading (nameplates, target frames) first.
  self.probeTimer = ns.Timer.After(10, function() M:AutoProbe() end, "autocheck:probe")
end

function M:AutoProbe()
  self.probeTimer = nil
  if ns.Compat.InCombat() then
    self.probeTimer = ns.Timer.After(5, function() M:AutoProbe() end, "autocheck:probe")
    return
  end
  local r = ns.Probe:Run()
  self:Info("auto probe done: %d present, %d missing", r.summary.present, r.summary.missing)
end

function M:OnTarget()
  if not (UnitExists and UnitExists("target")) then return end
  if ns.Compat.InCombat() then
    if self.inFight and not self.combatTargetSampled then
      self.combatTargetSampled = true
      ns.Probe:RecordUnits("combat target")
    end
  elseif self.idleSamples < MAX_IDLE_SAMPLES then
    self.idleSamples = self.idleSamples + 1
    ns.Probe:RecordUnits("target")
  end
end

function M:OnCombatStart()
  if self.combats >= MAX_COMBATS then return end
  self.combats = self.combats + 1
  self.inFight, self.combatTargetSampled = true, false
  local n = self.combats
  self:Info("combat %d started: sampling", n)
  ns.Timer.After(1, function()
    if ns.Compat.InCombat() then ns.Probe:RecordUnits("combat") end
  end, "autocheck:combat")
  ns.Combat:Run("autocheck", function()
    M.inFight = false
    M:Info("combat queue ran after combat %d", n)
  end, "autocheck:combat" .. n)
  local sb = ns.SecureButtons
  if sb and sb.test then
    local macro = (sb.test.wantMacro == "/wave") and "/cheer" or "/wave"
    local now = sb:SetMacro(sb.test, macro)
    sb:SetLabel(sb.test, macro)
    self:Info("test button macro %s %s", macro, now and "set" or "queued until combat ends")
  end
end
