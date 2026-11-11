-- Modules/RareShare.lua  (P8-03 rare sightings sharing)
-- Opt-in per character (/ride share rares guild|party on|off, both off by
-- default). When RareScan sees a rare outside instances, sends RARE
-- { npcID, name, mapID, x, y, layer, t, state } over the chosen channels.
-- Receivers (always listening; receiving sends nothing) only accept RARE
-- over GUILD/PARTY/RAID, drop impossible data (bad coords, future times,
-- older than an hour), add it to Sightings with how="guild"/"party" and
-- by=<sender>, and toast it if the rare is on their watchlist, saying
-- whether it is on their current layer. Pins come from Sightings.

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("RareShare", {
  title = "Share rare sightings",
  phase = "P8",
  order = 91,
  defaults = { guild = false, party = false },
})
ns.RareShare = M

M.MAX_AGE, M.RESEND = 3600, 60
local ACCEPT = { GUILD = "guild", PARTY = "party", RAID = "party" }

function M:OnInitialize() self.sentAt, self.toasted = {}, {} end

function M:OnEnable()
  self:On("OTR_RARE_SEEN", self.OnSeen)
  self:On("OTR_COMM", self.OnComm)
end

function M:OnSeen(_, info)
  local s = self:Settings()
  if not (s.guild or s.party) or not info or not info.npcID or not info.layer then return end
  local key = info.npcID .. (info.dead and "d" or "a")
  local now = time()
  if self.sentAt[key] and now - self.sentAt[key] < self.RESEND then return end
  self.sentAt[key] = now
  local msg = { npcID = info.npcID, name = info.name, mapID = info.mapID, x = info.x, y = info.y,
    layer = info.layer, t = info.t or now, state = info.dead and "dead" or "alive" }
  if s.guild and C.Call("IsInGuild") then ns.Comm:Send("RARE", msg, "GUILD") end
  if s.party then
    if C.Call("IsInRaid") then ns.Comm:Send("RARE", msg, "RAID")
    elseif C.Call("IsInGroup") then ns.Comm:Send("RARE", msg, "PARTY") end
  end
end

-- nil if the message is acceptable, else a reason
function M.Reject(d, now)
  if type(d.npcID) ~= "number" or d.npcID <= 0 then return "npcID" end
  if type(d.t) ~= "number" or d.t > now + 60 or d.t < now - M.MAX_AGE then return "time" end
  if d.x ~= nil and (type(d.x) ~= "number" or type(d.y) ~= "number" or d.x < 0 or d.x > 1 or d.y < 0 or d.y > 1) then return "coords" end
  if d.state ~= "alive" and d.state ~= "dead" then return "state" end
  if d.mapID ~= nil and type(d.mapID) ~= "number" then return "map" end
end

local function ago(sec)
  if sec < 90 then return "just now" end
  return string.format("%d min ago", math.floor(sec / 60 + 0.5))
end

function M:OnComm(_, kind, d, sender, channel)
  if kind ~= "RARE" then return end
  local how = ACCEPT[channel or ""]
  if not how then return end
  local now = time()
  local why = M.Reject(d, now)
  if why then self:Debug("dropped RARE from %s (%s)", tostring(sender), why) return end
  ns.Sightings:Record(d.npcID, { t = d.t, layer = d.layer, mapID = d.mapID, x = d.x, y = d.y,
    how = how, by = sender, state = d.state })
  local scan = ns.Modules:Get("RareScan")
  if not (scan and scan:IsWatched(d.npcID, d.name)) then return end
  local key = d.npcID .. d.state
  if self.toasted[key] and now - self.toasted[key] < 300 then return end
  self.toasted[key] = now
  local mine = ns.Layers and ns.Layers:Current()
  local where = (mine and d.layer) and (mine == d.layer and "your layer" or "another layer") or "layer unknown"
  local who = tostring(sender):match("^[^-]+") or tostring(sender)
  local name = d.name and ns.TitleCase(d.name) or ("NPC " .. d.npcID)
  ns.Toast:Show({ title = string.format("%s saw %s", who, name),
    text = string.format("%s%s (%s)", d.state == "dead" and "dead, " or "", ago(now - d.t), where),
    color = "warn", duration = 15 })
  self:Info("shared rare %d from %s %s %s", d.npcID, tostring(sender), d.state, where)
end

function M:Activity()
  local s = self:Settings()
  local on = {}
  if s.guild then on[#on + 1] = "guild" end
  if s.party then on[#on + 1] = "party" end
  return #on > 0 and ("sharing rares with " .. table.concat(on, " and ")) or "receiving only (/ride share rares guild on)"
end
