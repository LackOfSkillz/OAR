-- Modules/LocationShare.lua  (P8-04 location sharing, opt-in)
-- OFF by default, per character (/ride share location on|off).
-- While on: every 30 s Outrider sends your map position to your GUILD
-- (only guild members running Outrider can read it), when you moved or at
-- least every 2 minutes so you don't vanish while standing still. Never
-- from dungeons, raids, battlegrounds or arenas (nothing is sent there).
-- Turning it off sends one "gone" note so your dot disappears at once.
-- Receiving needs nothing switched on: guildmates who share show on the
-- world map with their name and class color, and disappear 150 s after
-- their last update. Party and raid members already show through
-- Blizzard's own map dots, so nothing is sent to groups.

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("LocationShare", {
  title = "Share my location with my guild",
  phase = "P8",
  order = 94,
  defaults = { on = false },
})
ns.LocationShare = M

M.EVERY, M.KEEPALIVE, M.EXPIRE = 30, 120, 150
M.PRIVACY = "Off by default. When on, guild members who also run Outrider see your map position, "
  .. "updated every 30 seconds. Nothing is sent from dungeons, raids or battlegrounds, and turning it off removes you at once."

function M:OnInitialize() self.peers = {} end

function M:OnEnable()
  self:On("OTR_COMM", self.OnComm)
  if self:Settings().on then self:Start() end
end

function M:OnDisable() self:Stop(true) end

function M:Start()
  if self.ticker then return end
  self.ticker = ns.Timer.Ticker(self.EVERY, function() M:Tick() end, "locationshare")
  self:Tick(true)
end

function M:Stop(sendGone)
  if self.ticker then self.ticker:Cancel() self.ticker = nil end
  if sendGone and self.lastSent and C.Call("IsInGuild") then ns.Comm:Send("LOC", { gone = true }, "GUILD") end
  self.lastSent, self.lastPos = nil, nil
end

-- Sends when moved, or every KEEPALIVE seconds; returns true if it sent.
function M:Tick(force)
  if not self:Settings().on or not C.Call("IsInGuild") then return false end
  local inside, kind = C.Call("IsInInstance")
  if inside then return false end
  local mapID, x, y = C.PlayerPosition("player")
  if not (mapID and x) then return false end
  local now = time()
  local moved = not self.lastPos or self.lastPos[1] ~= mapID or math.abs(self.lastPos[2] - x) > 0.001
    or math.abs(self.lastPos[3] - y) > 0.001
  if not force and not moved and self.lastSent and now - self.lastSent < self.KEEPALIVE then return false end
  self.lastPos, self.lastSent = { mapID, x, y }, now
  ns.Comm:Send("LOC", { m = mapID, x = math.floor(x * 10000 + 0.5) / 10000, y = math.floor(y * 10000 + 0.5) / 10000,
    c = ns.PlayerClass() }, "GUILD")
  return true
end

function M:OnComm(_, kind, d, sender, channel)
  if kind ~= "LOC" or channel ~= "GUILD" or type(sender) ~= "string" then return end
  if d.gone then
    self.peers[sender] = nil
  elseif type(d.m) == "number" and type(d.x) == "number" and type(d.y) == "number"
    and d.x >= 0 and d.x <= 1 and d.y >= 0 and d.y <= 1 then
    self.peers[sender] = { mapID = d.m, x = d.x, y = d.y, class = type(d.c) == "string" and d.c or nil, t = time() }
  else
    return
  end
  ns.Events:Fire("OTR_DATA_CHANGED", "guildmates")
end

-- Drops guildmates not heard from for EXPIRE seconds; true if any went.
function M:Prune()
  local now, gone = time(), false
  for name, p in pairs(self.peers) do
    if now - p.t > self.EXPIRE then self.peers[name] = nil gone = true end
  end
  return gone
end

-- { {name, mapID, x, y, class} } for one map, expired ones dropped
function M:PeersOn(mapID)
  local out, now = {}, time()
  for name, p in pairs(self.peers) do
    if now - p.t > self.EXPIRE then
      self.peers[name] = nil
    elseif p.mapID == mapID then
      out[#out + 1] = { name = name:match("^[^-]+") or name, full = name, mapID = p.mapID, x = p.x, y = p.y, class = p.class }
    end
  end
  return out
end

function M:Activity()
  local n = 0
  for _ in pairs(self.peers) do n = n + 1 end
  return string.format("%s; %d guildmates sharing with you", self:Settings().on and "sharing your location with the guild"
    or "not sharing (/ride share location on)", n)
end
