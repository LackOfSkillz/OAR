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
--   * Until verified: the secure test button and the sample toast appear by
--     themselves at login (out of combat), so Gary only clicks or drags.
--     The button counts as verified once a click runs the macro that was
--     queued during combat.
--   * At every logout or /reload: a /ride perf report and a character
--     snapshot, so P1-10 and P1-11 need no typing either.
-- Results land in the saved log; Gary only needs to log out afterwards.

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
  -- After each of the first 3 fights: what Blizzard's damage meter returns
  -- (2026-11-16, before building a damage readout on it).
  self.meterFights = 0
  self:On("PLAYER_REGEN_ENABLED", function(mod)
    if mod.meterFights >= MAX_COMBATS then return end
    mod.meterFights = mod.meterFights + 1
    local n = mod.meterFights
    ns.Timer.After(1, function() ns.Probe:DamageMeter("after fight " .. n) end, "autocheck:meter")
  end)
  -- Vanguard VG00-04/06: what one installation can read about the group
  -- (a sample a few seconds after the group changes size, out of combat, at
  -- most ROSTER_MAX per session) and what boss events carry.
  self.rosterSamples, self.lastRosterSize = 0, nil
  self:On("GROUP_ROSTER_UPDATE", self.OnRoster)
  self:On("ENCOUNTER_START", function(mod, _, ...) mod:OnEncounter("ENCOUNTER_START", ...) end)
  self:On("ENCOUNTER_END", function(mod, _, ...) mod:OnEncounter("ENCOUNTER_END", ...) end)
  self:On("PLAYER_LOGOUT", self.OnLogout)
  self:On("OTR_TESTBUTTON_CLICKED", self.OnTestClick)
  local g = ns.db.global
  g.autocheck = ns.KeepTable(g.autocheck, "AutoCheck:g.autocheck") or {}
  self.state = g.autocheck
end

function M:ShowTestsAtLogin()
  -- Nothing pops up at login any more: the test wave popup on first install
  -- and run was removed (owner request 2026-11-22). The Wave test button and the
  -- sample toast still come up on demand: /ride selftest button | toast.
end

function M:OnTestClick(_, macro)
  if self.swapped and macro == self.swapped and not ns.Compat.InCombat() then
    self.state.buttonDone = true
    self.swapped = nil
    self:Info("test button verified: macro %s set during combat ran after combat", tostring(macro))
  end
end

M.ROSTER_MAX, M.ENCOUNTER_MAX = 6, 10

function M:OnRoster()
  if self.rosterSamples >= M.ROSTER_MAX or self.rosterTimer then return end
  local n = tonumber(ns.Compat.Readable(ns.Compat.Call("GetNumGroupMembers"))) or 0
  if n == self.lastRosterSize or n == 0 then return end
  self.rosterTimer = ns.Timer.After(3, function() M:SampleRoster() end, "autocheck:roster")
end

function M:SampleRoster()
  self.rosterTimer = nil
  if ns.Compat.InCombat() then
    self.rosterTimer = ns.Timer.After(5, function() M:SampleRoster() end, "autocheck:roster")
    return
  end
  local n = tonumber(ns.Compat.Readable(ns.Compat.Call("GetNumGroupMembers"))) or 0
  if n == 0 or n == self.lastRosterSize then return end
  self.lastRosterSize = n
  self.rosterSamples = self.rosterSamples + 1
  ns.Probe:Roster("group of " .. n)
end

function M:OnEncounter(event, ...)
  self.encounters = (self.encounters or 0) + 1
  if self.encounters > M.ENCOUNTER_MAX then return end
  ns.Probe:Encounter(event, ...)
end

function M:OnLogout()
  ns.Perf:Report(true)
  ns.Snapshot:OnLogout()
end

function M:OnDisable()
  if self.probeTimer then self.probeTimer:Cancel() self.probeTimer = nil end
  if self.testsTimer then self.testsTimer:Cancel() self.testsTimer = nil end
end

function M:OnEnteringWorld(_, isLogin, isReload)
  if isLogin or isReload then ns.Safe("Snapshot:AfterLogin", ns.Snapshot.AfterLogin, ns.Snapshot) end
  if (isLogin or isReload) and not self.testsTimer then
    self.testsTimer = ns.Timer.After(3, function() M.testsTimer = nil M:ShowTestsAtLogin() end, "autocheck:tests")
  end
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
  -- PLAYER_REGEN_DISABLED fires just BEFORE lockdown starts (seen in game
  -- 2026-11-11: InCombatLockdown() was still false), so the queue checks
  -- wait half a second, when lockdown is really on.
  ns.Timer.After(0.5, function()
    if not ns.Compat.InCombat() then M:Info("combat %d: lockdown not on 0.5 s in, skipped", n) return end
    M:CombatChecks(n)
  end, "autocheck:lockdown")
  ns.Timer.After(1, function()
    if ns.Compat.InCombat() then ns.Probe:RecordUnits("combat") end
  end, "autocheck:combat")
end

function M:CombatChecks(n)
  local queued = ns.Combat:Run("autocheck", function()
    M.inFight = false
    M:Info("combat queue ran after combat %d", n)
  end, "autocheck:combat" .. n)
  self:Info("combat %d: queue job %s", n, queued == false and "queued until combat ends" or "ran at once (not locked)")
  local sb = ns.SecureButtons
  if sb and sb.test then
    local macro = (sb.test.wantMacro == "/wave") and "/cheer" or "/wave"
    local now = sb:SetMacro(sb.test, macro)
    sb:SetLabel(sb.test, macro)
    self.swapped = macro
    self:Info("test button macro %s %s", macro, now and "set" or "queued until combat ends")
  end
end

function M:Activity()
  local p = ns.db.global.probe
  return string.format("test data: probe %s, %d fights sampled", p and p.addonBuild == ns.build and "done" or "pending", self.combats or 0)
end
