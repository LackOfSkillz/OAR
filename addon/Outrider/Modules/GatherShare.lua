-- Modules/GatherShare.lua  (P8-05 gathering and fishing sharing)
-- Opt-in per character (/ride share nodes on|off, off by default): each new
-- herb, ore or fishing spot Gary finds himself (LootLog OTR_NODE_FOUND) is
-- sent to the guild as NODE { kind, mapID, x, y, name }, at most 6 a minute.
-- Receiving needs nothing switched on and sends nothing: nodes from guild
-- members are added through LootLog (merged by position, marked sharedBy,
-- verified = false) and show as pins "from <name>". Only GUILD is accepted
-- and impossible data is dropped.

local _, ns = ...
local M = ns:NewModule("GatherShare", {
  title = "Share gathering and fishing spots",
  phase = "P8",
  order = 93,
  defaults = { guild = false },
})
ns.GatherShare = M

M.KINDS = { herb = true, ore = true, fish = true }
M.PER_MINUTE = 6

function M:OnInitialize() self.sent = {} end

function M:OnEnable()
  self:On("OTR_NODE_FOUND", self.OnFound)
  self:On("OTR_COMM", self.OnComm)
end

function M:OnFound(_, n)
  if not self:Settings().guild or not n or not M.KINDS[n.kind] then return end
  local now = time()
  for i = #self.sent, 1, -1 do if now - self.sent[i] >= 60 then table.remove(self.sent, i) end end
  if #self.sent >= self.PER_MINUTE then return end
  if not ns.Compat.Call("IsInGuild") then return end
  self.sent[#self.sent + 1] = now
  ns.Comm:Send("NODE", { kind = n.kind, mapID = n.mapID, x = n.x, y = n.y, name = n.name }, "GUILD")
end

function M.Reject(d)
  if not M.KINDS[d.kind or ""] then return "kind" end
  if type(d.mapID) ~= "number" or d.mapID <= 0 then return "map" end
  if type(d.x) ~= "number" or type(d.y) ~= "number" or d.x < 0 or d.x > 1 or d.y < 0 or d.y > 1 then return "coords" end
  if d.name ~= nil and (type(d.name) ~= "string" or #d.name > 64) then return "name" end
end

function M:OnComm(_, kind, d, sender, channel)
  if kind ~= "NODE" or channel ~= "GUILD" or not ns.LootLog then return end
  local why = M.Reject(d)
  if why then self:Debug("dropped NODE from %s (%s)", tostring(sender), why) return end
  ns.LootLog:AddNode(d.kind, d.mapID, d.x, d.y, d.name, tostring(sender))
end

function M:Activity()
  local n = 0
  for _, node in ipairs(ns.db.global.nodes or {}) do if node.sharedBy then n = n + 1 end end
  return string.format("%s; %d spots from guildmates", self:Settings().guild and "sharing new spots with the guild"
    or "receiving only (/ride share nodes on)", n)
end
