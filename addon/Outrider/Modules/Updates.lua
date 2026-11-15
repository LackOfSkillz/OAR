-- Modules/Updates.lua
-- Telling family installs that a newer Outrider exists (Gary, 2026-11-14:
-- "how do they get notified that there are updates?"). An addon can't reach
-- the internet, so in game it uses what it knows:
--   * its own build date (family builds are stamped "v0.3.0-family-YYYYMMDD-HHMM"):
--     after AGE days, one line a day pointing at the "Update Outrider" desktop
--     shortcut, which asks GitHub (tools/family/updater.ps1);
--   * other Outrider users: their build comes with their gear card (KitShare)
--     or hello (Comm); a newer one gets one pop-up per session.
-- Gary's own deploy builds aren't family builds: nothing is said to him.

local _, ns = ...
local M = ns:NewModule("Updates", {
  title = "Update notices (family installs)",
  phase = "R",
  order = 92,
  defaults = {},
})
ns.Updates = M

M.AGE = 14

-- "20261114-1530" from a family build string, or nil
function M.Stamp(build)
  return type(build) == "string" and build:match("family%-(%d%d%d%d%d%d%d%d%-%d%d%d%d)") or nil
end

-- epoch of a stamp (local noon is close enough for counting days)
function M.Epoch(stamp)
  local y, mo, d = tostring(stamp):match("^(%d%d%d%d)(%d%d)(%d%d)")
  if not y then return nil end
  return time({ year = tonumber(y), month = tonumber(mo), day = tonumber(d), hour = 12 })
end

function M.Pretty(stamp)
  local e = M.Epoch(stamp)
  return e and date("%b %d", e) or tostring(stamp)
end

function M:CheckAge()
  local mine = M.Stamp(ns.build)
  if not mine then return end
  local e = M.Epoch(mine)
  if not e then return end
  local days = math.floor((time() - e) / 86400)
  local g = ns.db.global
  if days >= M.AGE and time() - (g.updateNudge or 0) >= 86400 then
    g.updateNudge = time()
    ns.Print("your Outrider is from %s (%d days old). Double-click 'Update Outrider' on your desktop to check for a newer one.",
      M.Pretty(mine), days)
  end
end

function M:OnComm(_, kind, data, sender)
  if (kind ~= "KIT" and kind ~= "HELLO") or type(data) ~= "table" then return end
  local mine, theirs = M.Stamp(ns.build), M.Stamp(data.build)
  if not (mine and theirs) or theirs <= mine or self.told then return end
  self.told = true
  ns.Toast:Show({ title = "A newer Outrider is out",
    text = string.format("%s has the %s build (yours is %s). Close WoW and double-click 'Update Outrider' on your desktop.",
      tostring(sender):match("^([^-]+)") or tostring(sender), M.Pretty(theirs), M.Pretty(mine)),
    color = "accent", duration = 20 })
  self:Info("newer build seen from %s: %s (mine %s)", tostring(sender), theirs, mine)
end

function M:OnEnable()
  self:On("PLAYER_ENTERING_WORLD", self.CheckAge)
  self:On("OTR_COMM", self.OnComm)
end

function M:Activity()
  local s = M.Stamp(ns.build)
  return s and ("family build from " .. M.Pretty(s)) or "developer build (no update notices)"
end
