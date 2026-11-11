-- Modules/Comm.lua  (P8-01 comm layer, P8-02 version check)
-- Addon messages between Outrider users, prefix "Outrider" (DATA_SCHEMAS.md):
--   body = "v1|TYPE|" .. Base64(Serialize(table)), split into chunks of at
--   most 240 bytes with a "#i/n" suffix and put back together on receipt.
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
local CHANNELS = { GUILD = true, PARTY = true, RAID = true, WHISPER = true }
M.KNOWN_TYPES = { HELLO = true, RARE = true, LOC = true }

function M:OnInitialize()
  self.inbox, self.peers = {}, {}
end

function M:OnEnable()
  C.Call("C_ChatInfo.RegisterAddonMessagePrefix", self.PREFIX)
  self:On("CHAT_MSG_ADDON", self.OnMessage)
  self:On("PLAYER_ENTERING_WORLD", function(mod) if mod:Settings().hello then mod:Hello() end end)
end

-- Split an encoded body into chunk strings.
function M.Chunks(body, size)
  size = size or M.CHUNK
  if #body <= size then return { body } end
  local parts, n = {}, math.ceil(#body / size)
  for i = 1, n do parts[i] = body:sub((i - 1) * size + 1, i * size) .. "#" .. i .. "/" .. n end
  return parts
end

function M:Encode(kind, data)
  return "v" .. self.PROTOCOL .. "|" .. kind .. "|" .. ns.Serialize.Base64Encode(ns.Serialize.Encode(data))
end

function M:Send(kind, data, channel, target)
  if not CHANNELS[channel] then return false, "channel not allowed" end
  local send = C.Resolve("C_ChatInfo.SendAddonMessage") or rawget(_G, "SendAddonMessage")
  if type(send) ~= "function" then return false, "no addon messages" end
  local parts = M.Chunks(self:Encode(kind, data))
  for _, p in ipairs(parts) do pcall(send, self.PREFIX, p, channel, target) end
  self:Debug("sent %s on %s (%d parts)", kind, channel, #parts)
  return true, #parts
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
  if prefix ~= self.PREFIX or type(msg) ~= "string" then return end
  local me = ns.db.key
  if sender == me or (sender and me:find("^" .. sender:gsub("%-", "%%-"))) then return end
  local body, i, n = msg:match("^(.-)#(%d+)/(%d+)$")
  if body then
    i, n = tonumber(i), tonumber(n)
    local key = tostring(sender) .. channel
    local box = self.inbox[key] or {}
    if i == 1 then box = {} end
    box[i] = body
    self.inbox[key] = box
    if i < n then return end
    local all = {}
    for k = 1, n do
      if not box[k] then self.inbox[key] = nil return end
      all[k] = box[k]
    end
    self.inbox[key] = nil
    msg = table.concat(all)
  end
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

ns.AddCommand("share", "hello on|off  tell guildmates which Outrider version you run (off by default)", function(arg)
  local what, state = (arg or ""):match("^(%S+)%s+(%S+)$")
  if what == "hello" and (state == "on" or state == "off") then
    M:Settings().hello = state == "on"
    ns.Print("version hello %s", state)
    if state == "on" then M:Hello() end
  else
    ns.Print("usage: /ride share hello on|off  (%s)", M:Activity())
  end
end)
