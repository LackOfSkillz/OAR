-- Modules/RareTimer.lua
-- A countdown for a rare said to spawn on a fixed timer (report 2026-11-13:
-- the server rebooted at 3pm EST; Mystmane reportedly spawns every three
-- hours, to be tracked). A timer = { every (s), from (epoch), source }.
-- Next window = from + k * every. When Outrider sees the rare dead, the timer
-- restarts from that death. The claim stays marked unverified; the spawn log
-- and sightings show whether she really comes on time.
-- One pop-up about 5 minutes before a window (rare alerts were requested). Home's
-- rare card and the Watch and alerts tab on Rares show the countdown.

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("RareTimer", {
  title = "Rare timers (claimed respawn every N hours)",
  phase = "P2",
  order = 33,
  defaults = { warnBefore = 300 },
})
ns.RareTimer = M

function M:OnInitialize()
  local g = ns.db.global
  g.rareTimers = type(g.rareTimers) == "table" and g.rareTimers or {}
  -- Field report 2026-11-13: server restart 15:00 EST (20:00 UTC), Mystmane every 3 h (unverified)
  if not g.rareTimers[259388] and not g.mystmaneTimerSeeded then
    g.mystmaneTimerSeeded = true
    g.rareTimers[259388] = { name = "Mystmane", every = 3 * 3600, from = 1794600000,
      source = "Gary: server restart 3pm EST, every 3 h (unverified)" }
  end
  -- Tested 2026-11-13: no Mystmane in the 18:00 or 21:00 windows (bears and
  -- Shrieklings only at her spot), so the claim is not supported: the timer
  -- is switched off but kept, with the result, in case it is ever retried.
  local myst = g.rareTimers[259388]
  if myst and not g.mystmaneTimerOff20261113 then
    g.mystmaneTimerOff20261113 = true
    myst.off = true
    myst.result = "not supported: missed the 18:00 and 21:00 windows on 2026-11-13"
  end
  self.warned = {}
end

-- Next window start at or after `now`.
function M.Next(t, now)
  if not (t and t.every and t.from) then return nil end
  if now <= t.from then return t.from end
  local k = math.ceil((now - t.from) / t.every)
  return t.from + k * t.every
end

-- "Mystmane: next window 18:00 (in 1h 52m), every 3 h, unverified"
function M:Line(npcID, now)
  now = now or time()
  local t = ns.db.global.rareTimers[npcID]
  local nxt = t and not t.off and M.Next(t, now)
  if not nxt then return nil end
  local left = nxt - now
  return string.format("%s: next window %s (in %dh %02dm), every %d h%s", tostring(t.name), date("%H:%M", nxt),
    math.floor(left / 3600), math.floor(left % 3600 / 60), math.floor(t.every / 3600 + 0.5),
    t.restartedAt and (", restarted from a kill at " .. date("%H:%M", t.restartedAt)) or " (unverified)")
end

-- Seen dead: the next windows count from this death.
function M:OnRareSeen(_, info)
  local t = type(info) == "table" and ns.db.global.rareTimers[info.npcID]
  if not t or t.off or not info.dead then return end
  local now = time()
  if t.restartedAt and now - t.restartedAt < 600 then return end
  t.from, t.restartedAt = now + t.every, now
  self:Info("%s seen dead: timer restarts, next window %s", tostring(t.name), date("%H:%M", t.from))
end

-- Once a minute: a pop-up shortly before a window opens.
function M:Tick()
  local now = time()
  local before = self:Settings().warnBefore or 300
  for npcID, t in pairs(ns.db.global.rareTimers) do
    local nxt = not t.off and M.Next(t, now)
    if nxt and nxt - now <= before and not self.warned[npcID .. ":" .. nxt] then
      self.warned[npcID .. ":" .. nxt] = true
      ns.Toast:Show({ title = tostring(t.name) .. " soon", color = "warn", duration = 15,
        text = string.format("Window at %s, in %d min. %s", date("%H:%M", nxt), math.ceil((nxt - now) / 60), t.source or "") })
      self:Info("%s window soon: %s", tostring(t.name), date("%H:%M", nxt))
    end
  end
end

-- No timer of our own (nothing runs while idle): the check rides on things
-- that happen while playing, at most every 30 s.
function M:OnEnable()
  self:On("OTR_RARE_SEEN", self.OnRareSeen)
  local function check() if (time() - (M.lastTick or 0)) >= 30 then M.lastTick = time() M:Tick() end end
  for _, e in ipairs({ "PLAYER_STARTED_MOVING", "NAME_PLATE_UNIT_ADDED", "PLAYER_REGEN_DISABLED",
    "PLAYER_TARGET_CHANGED", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED" }) do
    self:On(e, check)
  end
end

function M:Activity()
  local lines = {}
  for npcID, t in pairs(ns.db.global.rareTimers) do
    -- in words, not a status code (2026-11-18 tour): "Mystmane: no fixed
    -- timer. The claimed 3-hour windows were tested and missed (Nov 13)."
    local why = t.result and tostring(t.result):gsub("^not supported: ", ""):gsub("(%d%d%d%d)%-(%d%d)%-(%d%d)", function(y, mo, d)
      local names = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }
      return (names[tonumber(mo)] or mo) .. " " .. tonumber(d)
    end)
    lines[#lines + 1] = self:Line(npcID) or (why and string.format("%s: no fixed timer. The claimed windows were tested and %s.", tostring(t.name), why)) or nil
  end
  return #lines > 0 and table.concat(lines, "; ") or "no rare timers"
end
