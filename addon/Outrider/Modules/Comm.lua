-- Modules/Comm.lua  (P8-01 comm layer, P8-02 version check)
-- Addon messages between Outrider users, prefix "Outrider" (DATA_SCHEMAS.md):
--   body = "v1|TYPE|" .. Base64(Serialize(table)); a longer body is split into
--   pieces of at most 240 bytes as "~id~i/n~piece" and put back together on
--   receipt, within limits (pieces, size, pending messages, 30 s expiry).
-- Channels: GUILD, PARTY, RAID, WHISPER only (hard rule 10). Received
-- messages fire OTR_COMM(type, data, sender, channel); our own are ignored;
-- unknown types and newer protocol versions are dropped.
-- NOTHING is sent unless Gary switched a sharing feature on: the version
-- hello is off by default (setting `hello`, /ride share hello on).

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("Comm", {
  title = "Sharing with other Outrider users",
  phase = "P8",
  order = 90,
  defaults = { hello = false },
})
ns.Comm = M

M.PREFIX, M.PROTOCOL, M.CHUNK = "Outrider", 1, 240
-- limits for messages from other players
M.MAX_PARTS = 32            -- pieces per message (about 7.5 KB)
M.MAX_BYTES = M.CHUNK * M.MAX_PARTS
M.MAX_PENDING_SENDER = 4    -- half-received messages per sender
M.MAX_PENDING = 32          -- half-received messages in all
M.EXPIRE = 30               -- seconds before a half-received message is dropped
M.BURST, M.PACE = 8, 1      -- sending: pieces per batch, seconds between batches
local CHANNELS = { GUILD = true, PARTY = true, RAID = true, WHISPER = true }
M.KNOWN_TYPES = { HELLO = true, RARE = true, LOC = true, NODE = true }

function M:OnInitialize()
  self.inbox, self.peers, self.perSender, self.outbox = {}, {}, {}, {}
  self.pending = 0
end

function M:OnEnable()
  C.Call("C_ChatInfo.RegisterAddonMessagePrefix", self.PREFIX)
  self:On("CHAT_MSG_ADDON", self.OnMessage)
  self:On("PLAYER_ENTERING_WORLD", function(mod) if mod:Settings().hello then mod:Hello() end end)
end

-- Split an encoded body into chunk strings. A body that fits goes as it is
-- ("v1|TYPE|..."). A longer one goes as "~id~i/n~piece": the id keeps two
-- messages from the same sender apart, and older receivers (which expect a
-- "#i/n" suffix) drop these pieces instead of misreading them.
function M.Chunks(body, size, id)
  size = size or M.CHUNK
  if #body <= size then return { body } end
  local parts, n = {}, math.ceil(#body / size)
  id = id or "000"
  for i = 1, n do parts[i] = "~" .. id .. "~" .. i .. "/" .. n .. "~" .. body:sub((i - 1) * size + 1, i * size) end
  return parts
end

-- three-character message ids in base 36 (46656 before they repeat)
local DIGITS = "0123456789abcdefghijklmnopqrstuvwxyz"
function M.Id(k)
  k = k % 46656
  local out = ""
  for _ = 1, 3 do
    local d = k % 36
    out = DIGITS:sub(d + 1, d + 1) .. out
    k = math.floor(k / 36)
  end
  return out
end

function M:Encode(kind, data)
  return "v" .. self.PROTOCOL .. "|" .. kind .. "|" .. ns.Serialize.Base64Encode(ns.Serialize.Encode(data))
end

function M:Send(kind, data, channel, target)
  if not CHANNELS[channel] then return false, "channel not allowed" end
  local send = C.Resolve("C_ChatInfo.SendAddonMessage") or rawget(_G, "SendAddonMessage")
  if type(send) ~= "function" then return false, "no addon messages" end
  local ok, body = pcall(self.Encode, self, kind, data)
  if not ok then return false, "could not encode" end
  if #body > M.MAX_BYTES then
    self:Warn("not sending %s: %d bytes is over the %d limit", kind, #body, M.MAX_BYTES)
    return false, "too big"
  end
  self.nextId = (self.nextId or math.random(0, 46655)) + 1
  local parts = M.Chunks(body, nil, M.Id(self.nextId))
  for _, p in ipairs(parts) do self.outbox[#self.outbox + 1] = { p, channel, target } end
  self:Pump(send)
  self:Debug("sent %s on %s (%d parts)", kind, channel, #parts)
  return true, #parts
end

-- The game drops addon messages sent in a burst, so pieces go out at most
-- BURST at a time, one batch every PACE seconds. (Addon messages are not
-- protected actions; nothing here casts, targets or presses anything.)
function M:Pump(send)
  send = send or C.Resolve("C_ChatInfo.SendAddonMessage") or rawget(_G, "SendAddonMessage")
  if self.pumping or type(send) ~= "function" then return end
  for _ = 1, M.BURST do
    local m = table.remove(self.outbox, 1)
    if not m then break end
    pcall(send, self.PREFIX, m[1], m[2], m[3])
  end
  if #self.outbox > 0 then
    self.pumping = true
    ns.Timer.After(M.PACE, function() self.pumping = false self:Pump() end, "Comm pump")
  end
end

-- Half-received messages older than EXPIRE seconds are dropped.
function M:Sweep(now)
  for key, box in pairs(self.inbox) do
    if now - box.t > M.EXPIRE then self:Drop(key) end
  end
end

function M:Drop(key)
  local box = self.inbox[key]
  if not box then return end
  self.inbox[key] = nil
  self.pending = math.max(0, self.pending - 1)
  local s = box.sender
  if self.perSender[s] then
    self.perSender[s] = self.perSender[s] - 1
    if self.perSender[s] <= 0 then self.perSender[s] = nil end
  end
end

-- Store one piece. Returns the whole body once every piece is in; otherwise
-- nil and why (for specs).
function M:Piece(sender, channel, id, i, n, piece, now)
  if not (i and n) or n < 2 or n > M.MAX_PARTS or i < 1 or i > n then return nil, "bad index" end
  if #piece == 0 or #piece > M.CHUNK then return nil, "bad size" end
  local key = sender .. "|" .. tostring(channel) .. "|" .. id
  local box = self.inbox[key]
  if box and box.n ~= n then self:Drop(key) return nil, "count changed" end
  if not box then
    if (self.perSender[sender] or 0) >= M.MAX_PENDING_SENDER or self.pending >= M.MAX_PENDING then
      return nil, "too many pending"
    end
    box = { n = n, got = 0, parts = {}, t = now, sender = sender }
    self.inbox[key] = box
    self.pending = self.pending + 1
    self.perSender[sender] = (self.perSender[sender] or 0) + 1
  end
  if box.parts[i] then return nil, "duplicate" end
  box.parts[i] = piece
  box.got = box.got + 1
  if box.got < n then return nil end
  local body = table.concat(box.parts, "", 1, n)
  self:Drop(key)
  return body
end

function M:Decode(body)
  local v, kind, payload = body:match("^v(%d+)|(%u+)|(.+)$")
  v = tonumber(v)
  if not v or v > self.PROTOCOL or not M.KNOWN_TYPES[kind or ""] then return nil end
  local raw = ns.Serialize.Base64Decode(payload)
  if not raw then return nil end
  local ok, data = pcall(ns.Serialize.Decode, raw)
  if not ok or type(data) ~= "table" then return nil end
  return kind, data
end

function M:OnMessage(_, prefix, msg, channel, sender)
  if prefix ~= self.PREFIX or type(msg) ~= "string" or type(sender) ~= "string" then return end
  if #msg > 255 then return end
  local me = ns.db.key
  if sender == me or me:find("^" .. sender:gsub("%W", "%%%0") .. "%-") then return end
  local now = time()
  self:Sweep(now)
  local id, i, n, piece = msg:match("^~(%w%w%w)~(%d+)/(%d+)~(.*)$")
  if id then
    msg = self:Piece(sender, channel, id, tonumber(i), tonumber(n), piece, now)
    if not msg then return end
  elseif msg:sub(1, 1) == "~" then
    return
  else
    -- builds from before 2026-11-14 evening send "piece#i/n", one message
    -- per sender and channel at a time
    local old, oi, on = msg:match("^(.-)#(%d+)/(%d+)$")
    if old then
      if oi == "1" then self:Drop(sender .. "|" .. tostring(channel) .. "|old") end
      msg = self:Piece(sender, channel, "old", tonumber(oi), tonumber(on), old, now)
      if not msg then return end
    end
  end
  if #msg > M.MAX_BYTES then return end
  local kind, data = self:Decode(msg)
  if not kind then return end
  if kind == "HELLO" then self:OnHello(data, sender) end
  ns.Events:Fire("OTR_COMM", kind, data, sender, channel)
end

-- P8-02: version check
function M:Hello()
  if not C.Call("IsInGuild") then return false end
  return self:Send("HELLO", { version = ns.version, build = ns.build }, "GUILD")
end

local function newer(a, b)
  local function parts(v) local t = {} for n in tostring(v):gmatch("%d+") do t[#t + 1] = tonumber(n) end return t end
  local x, y = parts(a), parts(b)
  for i = 1, math.max(#x, #y) do
    local p, q = x[i] or 0, y[i] or 0
    if p ~= q then return p > q end
  end
  return false
end
M.Newer = newer

function M:OnHello(data, sender)
  self.peers[sender] = { version = data.version, t = time() }
  if newer(data.version, ns.version) and not self.toldNewer then
    self.toldNewer = true
    ns.Print("%s has a newer Outrider (%s, you have %s).", tostring(sender), tostring(data.version), ns.version)
  end
end

function M:Activity()
  local n = 0
  for _ in pairs(self.peers) do n = n + 1 end
  return string.format("sharing %s; %d other Outrider users seen", self:Settings().hello and "on (version hello)" or "off", n)
end

ns.AddCommand("share", "hello on|off | rares guild|party on|off | nodes on|off | location on|off  sharing (all off by default)", function(arg)
  local what, state = (arg or ""):match("^(%S+)%s+(%S+)$")
  local where, st2 = (arg or ""):match("^rares%s+(%S+)%s+(%S+)$")
  if what == "hello" and (state == "on" or state == "off") then
    M:Settings().hello = state == "on"
    ns.Print("version hello %s", state)
    if state == "on" then M:Hello() end
  elseif ns.LocationShare and what == "location" and (state == "on" or state == "off") then
    ns.LocationShare:Settings().on = state == "on"
    if state == "on" then ns.LocationShare:Start() else ns.LocationShare:Stop(true) end
    ns.Print("location sharing %s. %s", state, ns.LocationShare.PRIVACY)
  elseif ns.GatherShare and what == "nodes" and (state == "on" or state == "off") then
    ns.GatherShare:Settings().guild = state == "on"
    ns.Print("sharing herb, ore and fishing spots with the guild %s", state)
  elseif ns.RareShare and (where == "guild" or where == "party") and (st2 == "on" or st2 == "off") then
    ns.RareShare:Settings()[where] = st2 == "on"
    ns.Print("rare sharing with %s %s", where, st2)
  else
    ns.Print("usage: /ride share hello on|off | rares guild|party on|off  (%s; %s)", M:Activity(),
      ns.RareShare and ns.RareShare:Activity() or "")
  end
end)
