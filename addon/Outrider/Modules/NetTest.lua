-- Modules/NetTest.lua  (Gary, 2026-11-21: "is there a way Outrider could
-- communicate with other Outrider users without being in the same party or
-- guild ... let's test it")
-- A TEST of an Outrider-wide network through a hidden chat channel. On
-- Classic clients Blizzard switched addon messages off in custom channels
-- (FOREVER_CONSTRAINTS C11, reported, never measured on Forever); this finds
-- out on Forever. Off by default; a switch on the Sharing page turns it on.
-- While on:
--   * joins the hidden channel CHANNEL_NAME and takes it out of every chat
--     window (nothing shows in chat);
--   * says a tiny hello there through addon messages once a minute:
--     "hi|<build>|<random tag>|<count>" (nothing about the player);
--   * logs the join, the game's answer to each send, its own echo, and every
--     hello heard from another Outrider user (the real proof).
-- Results in ns.db.global.netTest and the log. Switched off: leaves the channel.
-- Decision D25: test only, opt-in. Real sharing still goes over guild,
-- party, raid and whisper (hard rule 10) until the result is in.

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("NetTest", {
  title = "Outrider network test",
  phase = "P8",
  order = 92,
  defaults = { on = false },
})
ns.NetTest = M

M.CHANNEL_NAME = "OutriderNet"
M.PREFIX = "OutriderNet"
M.EVERY = 60

function M:OnInitialize()
  local g = ns.db.global
  g.netTest = type(g.netTest) == "table" and g.netTest or {}
  self.r = g.netTest
  self.tag = string.format("%04x", math.random(0, 65535))
end

function M:OnEnable()
  C.Call("C_ChatInfo.RegisterAddonMessagePrefix", M.PREFIX)
  self:On("CHAT_MSG_ADDON", self.OnMessage)
  self:On("PLAYER_ENTERING_WORLD", function(mod) if mod:Settings().on then ns.Timer.After(5, function() mod:Start("login") end, "nettest:login") end end)
end

function M:OnDisable() self:Stop("module off") end

-- Remove the channel from every chat window, so nothing shows in chat.
function M.Hide()
  local n = tonumber(rawget(_G, "NUM_CHAT_WINDOWS")) or 10
  local remove = rawget(_G, "ChatFrame_RemoveChannel")
  for i = 1, n do
    local f = rawget(_G, "ChatFrame" .. i)
    if f and type(remove) == "function" then pcall(remove, f, M.CHANNEL_NAME) end
  end
end

function M:ChannelID()
  local id = C.Call("GetChannelName", M.CHANNEL_NAME)
  id = tonumber(C.Readable(id))
  return id and id > 0 and id or nil
end

function M:Start(why)
  if self.running then return true end
  self.running = true
  local r = self.r
  r.tries = (r.tries or 0) + 1
  r.build, r.started = ns.build, time()
  local joinFn = C.Resolve("JoinTemporaryChannel") or C.Resolve("JoinChannelByName")
  local ok, a, b = pcall(joinFn or error, M.CHANNEL_NAME)
  r.joinCall = joinFn and (ok and "ok" or ("error: " .. tostring(a))) or "no join function"
  M.Hide()
  -- joining answers a moment later: check, then say hello, then every minute
  ns.Timer.After(3, function()
    M.Hide()
    local id = self:ChannelID()
    r.joined, r.channel = id ~= nil, id
    self:Info("network test (%s): join %s, channel %s", tostring(why), r.joinCall, tostring(id or "none"))
    self:Hello()
  end, "nettest:joined")
  self.ticker = ns.Timer.Ticker(M.EVERY, function() M:Hello() end, "nettest:hello")
  return true
end

function M:Stop(why)
  if not self.running then return end
  self.running = false
  if self.ticker then self.ticker:Cancel() self.ticker = nil end
  pcall(C.Resolve("LeaveChannelByName") or function() end, M.CHANNEL_NAME)
  self:Info("network test stopped (%s): sent %d, heard myself %d, heard others %d", tostring(why),
    self.r.sends or 0, self.r.heardSelf or 0, self.r.heardOthers or 0)
end

function M:Hello()
  local r = self.r
  local id = self:ChannelID()
  if not id then r.lastSend = "not in the channel" self:Debug("network test: not in the channel") return end
  local send = C.Resolve("C_ChatInfo.SendAddonMessage")
  if type(send) ~= "function" then r.lastSend = "no SendAddonMessage" return end
  r.sends = (r.sends or 0) + 1
  local msg = string.format("hi|%s|%s|%d", tostring(ns.build), self.tag, r.sends)
  local ok, res = pcall(send, M.PREFIX, msg, "CHANNEL", tostring(id))
  r.lastSend = ok and ("result " .. tostring(C.Readable(res))) or ("error: " .. tostring(res))
  if r.sends <= 3 or r.sends % 10 == 0 then self:Info("network test: hello %d sent on channel %d: %s", r.sends, id, r.lastSend) end
end

function M:OnMessage(_, prefix, text, channel, sender)
  if prefix ~= M.PREFIX or type(text) ~= "string" then return end
  local build, tag, n = text:match("^hi|([^|]*)|(%x+)|(%d+)$")
  if not tag then return end
  local r = self.r
  r.heardOn = tostring(channel)
  if tag == self.tag then
    r.heardSelf = (r.heardSelf or 0) + 1
    if r.heardSelf == 1 then self:Info("network test: heard my own hello back on %s", tostring(channel)) end
    return
  end
  r.heardOthers = (r.heardOthers or 0) + 1
  r.others = type(r.others) == "table" and r.others or {}
  local who = tostring(C.Readable(sender) or "?")
  local first = r.others[who] == nil
  r.others[who] = build
  if first then self:Info("network test: HEARD ANOTHER OUTRIDER USER (%s, build %s) on %s", who, tostring(build), tostring(channel)) end
end

function M:Activity()
  local r = self.r
  if not self:Settings().on then return "off (Sharing page: Outrider network test)" end
  local others = 0
  for _ in pairs(r.others or {}) do others = others + 1 end
  return string.format("in the channel: %s; hellos sent %d; heard myself %d; other Outrider users heard: %d",
    r.joined and "yes" or "no", r.sends or 0, r.heardSelf or 0, others)
end

function M:Set(on)
  self:Settings().on = on and true or false
  if on then self:Start("switched on") else self:Stop("switched off") end
end
