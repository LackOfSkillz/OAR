-- Modules/NodePack.lua
-- Herb and ore spawn points for the whole world (Gary, 2026-11-13: "pull the
-- node map into our database"), from the private load-on-demand addon
-- Outrider_Data_Nodes (tools/import_nodes.py, Questie's Forever objects, D10).
-- Profession aware: herbs only for herbalists, ore only for miners. Skill
-- aware for herbs: a herb needs the skill the herb guide (Data/Herbs.lua)
-- states; herbs above your skill are left out. Ore skills aren't in any cited
-- data yet, so every ore shows for a miner. Community data, verified = false;
-- nodes Gary gathered himself (LootLog) are drawn on top as "seen".

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("NodePack", {
  title = "Herb and ore map (private node pack)",
  phase = "P5",
  order = 78,
  defaults = { show = true, aboveSkill = 0 },
})
ns.NodePack = M

M.ADDON = "Outrider_Data_Nodes"
M.MAX_PINS = 400

function M:Load()
  if self.maps ~= nil then return self.maps end
  if not rawget(_G, "Outrider_DataNodes") then C.LoadAddOn(self.ADDON) end
  local data = rawget(_G, "Outrider_DataNodes")
  self.maps = type(data) == "table" and type(data.maps) == "table" and data.maps or false
  self:Info(self.maps and "node pack loaded from %s" or "no node pack (%s): only nodes you gathered show",
    self.maps and tostring(data.source) or self.ADDON)
  return self.maps
end

-- Which kinds this character can gather: { herb = skill or true, ore = true }
function M:Kinds()
  local owned = ns.Crafter and ns.Crafter:Owned() or {}
  local out = {}
  if owned.Herbalism then out.herb = (ns.HerbHelper and ns.HerbHelper:MySkill()) or true end
  if owned.Mining then out.ore = true end
  return out
end

-- Can this character gather this node now?
function M:CanGather(name, kind, kinds)
  kinds = kinds or self:Kinds()
  local have = kinds[kind]
  if not have then return false end
  if kind == "herb" and type(have) == "number" then
    local g = ns.Data:Get("herb", name)
    if g and g.skill and g.skill > have + (self:Settings().aboveSkill or 0) then return false end
  end
  return true
end

-- { {name, kind, points = {x,y,...}} } on a map this character can gather.
function M:For(mapID)
  local maps = self:Load()
  local rows = maps and maps[mapID]
  if not rows then return {} end
  local kinds, out = self:Kinds(), {}
  for _, r in ipairs(rows) do
    if self:CanGather(r[1], r[2], kinds) then out[#out + 1] = { name = r[1], kind = r[2], points = r[3] } end
  end
  return out
end

-- Pins for the world map: one per spawn point, capped, skipping spots Gary
-- already has a node of his own on.
function M:Pins(mapID, hidden)
  if not self.enabled or not self:Settings().show then return {} end
  local own = {}
  for _, n in ipairs(ns.LootLog and ns.LootLog:NodesFor(mapID) or {}) do own[#own + 1] = n end
  local out = {}
  for _, node in ipairs(self:For(mapID)) do
    if not (hidden and hidden[node.kind]) then
      local pts = node.points
      for i = 1, #pts - 1, 2 do
        local x, y = pts[i], pts[i + 1]
        local mine = false
        for _, n in ipairs(own) do
          if math.abs(n.x - x) < 0.006 and math.abs(n.y - y) < 0.006 then mine = true break end
        end
        if not mine then
          out[#out + 1] = { id = "pack-" .. node.kind .. "-" .. mapID .. "-" .. i, kind = node.kind, mapID = mapID,
            x = x, y = y, name = node.name .. " (guide)" }
          if #out >= M.MAX_PINS then return out end
        end
      end
    end
  end
  return out
end

-- Nearest spawn point of each node type, for the Finder: { {name, kind, mapID, x, y, count} }
function M:Nearest(px, py, mapID, node)
  local best, bd
  local pts = node.points
  for i = 1, #pts - 1, 2 do
    local d = (pts[i] - (px or 0.5)) ^ 2 + (pts[i + 1] - (py or 0.5)) ^ 2
    if not bd or d < bd then best, bd = i, d end
  end
  return pts[best], pts[best + 1], #pts / 2
end

function M:Activity()
  local k = self:Kinds()
  local list = {}
  if k.herb then list[#list + 1] = "herbs" .. (type(k.herb) == "number" and (" up to skill " .. k.herb) or "") end
  if k.ore then list[#list + 1] = "ore" end
  if #list == 0 then return "learn Herbalism or Mining to see nodes on the map" end
  return "showing " .. table.concat(list, " and ") .. " from the node pack"
end
