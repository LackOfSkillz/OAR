-- Vanguard/Cache.lua
-- VG01-08: the current-view cache of inspected group members (D27, Gary
-- 2026-11-26): memory only, 5 minutes per member, shown as stale after that,
-- dropped when the member leaves the group, on logout or reload. It is never
-- written to SavedVariables, logs, snapshots or exports, so nothing about a
-- player who didn't install Outrider outlives the current view.

local _, ns = ...
ns.Vanguard = ns.Vanguard or {}
local K = { entries = {}, n = 0 }
ns.Vanguard.Cache = K

K.TTL = 5 * 60
K.MAX = 45 -- a full raid plus a little slack; the oldest goes first

local function now() return (GetTime and GetTime()) or 0 end

function K:Put(key, profile)
  if type(key) ~= "string" then return end
  if not self.entries[key] then self.n = self.n + 1 end
  profile.cachedAt = now()
  profile.expiresAt = profile.cachedAt + self.TTL
  self.entries[key] = profile
  while self.n > self.MAX do
    local oldK, oldT
    for k, e in pairs(self.entries) do if not oldT or e.cachedAt < oldT then oldK, oldT = k, e.cachedAt end end
    self:Drop(oldK)
  end
end

-- profile, "fresh" | "stale"; nil when we have nothing
function K:Get(key, t)
  local e = key and self.entries[key]
  if not e then return nil end
  return e, ((t or now()) >= e.expiresAt) and "stale" or "fresh"
end

function K:Drop(key)
  if key and self.entries[key] then self.entries[key] = nil self.n = self.n - 1 end
end

-- keep only members still in the group
function K:Keep(snapshot)
  local dropped = 0
  for k in pairs(self.entries) do
    if not (snapshot and snapshot.byKey[k]) then self:Drop(k) dropped = dropped + 1 end
  end
  return dropped
end

function K:Clear()
  self.entries, self.n = {}, 0
end

function K:Count() return self.n end
