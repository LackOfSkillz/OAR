-- Modules/HerbHelper.lua
-- Gary asked (2026-11-12) for what herbalism addons do, built our own way
-- (ideas only, no code or data copied from other addons):
--   * Find Herbs reminder: herb dots on the minimap come from Blizzard's
--     "Find Herbs" tracking. If you have Herbalism and it is off, say so once
--     per session (hard rule 6). Outrider never switches it itself.
--   * Pin on sight: mouse over a herb or ore node and it goes on the map
--     straight away (LootLog already pins it when you gather). Position is
--     where you stand, merged like gathered nodes; verified = false.
--   * Self-check: the first few object tooltips are logged with their lines
--     so Claude can see how Forever words a node tooltip.
-- A node tooltip is recognised by a line naming the gathering skill
-- ("Herbalism", "Mining"), the same way the client marks them.

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("HerbHelper", {
  title = "Herbalism helper (Find Herbs reminder, pin herbs you see)",
  phase = "P5",
  order = 77,
  defaults = { remind = true, pinOnSight = true },
})
ns.HerbHelper = M

local SKILL_KIND = { Herbalism = "herb", Mining = "ore" }
local TRACKING = { Herbalism = "Find Herbs", Mining = "Find Minerals" }
M.LOG_TOOLTIPS = 5

-- Tracking types on the minimap: list of { name, active }.
function M:Tracking()
  local out = {}
  local n = C.Call("C_Minimap.GetNumTrackingTypes")
  if type(n) ~= "number" then return out end
  for i = 1, n do
    local info = C.Call("C_Minimap.GetTrackingInfo", i)
    if type(info) == "table" and info.name then
      out[#out + 1] = { name = C.Readable(info.name), active = info.active and true or false }
    end
  end
  return out
end

function M:CheckTracking()
  local owned = ns.Crafter and ns.Crafter:Owned() or {}
  local list = self:Tracking()
  if not self.trackingLogged and #list > 0 then
    self.trackingLogged = true
    local names = {}
    for _, t in ipairs(list) do names[#names + 1] = t.name .. (t.active and " (on)" or "") end
    self:Info("minimap tracking: %s", table.concat(names, ", "))
  end
  for skill, spell in pairs(TRACKING) do
    if owned[skill] then
      for _, t in ipairs(list) do
        if t.name == spell and not t.active and self:Settings().remind and not (self.reminded or {})[spell] then
          self.reminded = self.reminded or {}
          self.reminded[spell] = true
          ns.Print("%s is off, so herb and ore dots won't show on the minimap. Turn it on from the minimap's tracking (magnifier) button.", spell)
          self:Info("%s tracking is off", spell)
        end
      end
    end
  end
end

-- Lines of a tooltip from its data (TooltipDataProcessor) or the frame.
local function lines(tip, data)
  local out = {}
  if type(data) == "table" and type(data.lines) == "table" then
    for _, l in ipairs(data.lines) do
      local t = C.Readable(l.leftText)
      if type(t) == "string" then out[#out + 1] = t end
    end
  end
  if #out == 0 and tip and tip.NumLines and tip.GetName then
    local name = tip:GetName()
    for i = 1, (tip:NumLines() or 0) do
      local fs = name and rawget(_G, name .. "TextLeft" .. i)
      local t = fs and fs.GetText and C.Readable(fs:GetText())
      if type(t) == "string" then out[#out + 1] = t end
    end
  end
  return out
end

-- An object tooltip: log the first few, pin gathering nodes.
function M:OnObjectTooltip(tip, data)
  local text = lines(tip, data)
  if #text == 0 then return end
  self.logged = self.logged or {}
  if #self.logged < M.LOG_TOOLTIPS and not self.logged[text[1]] then
    self.logged[#self.logged + 1] = text[1]
    self.logged[text[1]] = true
    self:Info("object tooltip: %s", table.concat(text, " | "))
  end
  if not self:Settings().pinOnSight or not ns.LootLog or not ns.LootLog.enabled then return end
  local kind
  for i = 2, #text do
    for skill, k in pairs(SKILL_KIND) do
      if text[i]:find(skill, 1, true) then kind = k end
    end
  end
  if not kind then return end
  local mapID, x, y = C.PlayerPosition("player")
  if not (mapID and x) then return end
  local key = string.format("%s:%d:%.0f:%.0f", text[1], mapID, x * 200, y * 200)
  self.seen = self.seen or {}
  if self.seen[key] then return end
  self.seen[key] = true
  local node, new = ns.LootLog:AddNode(kind, mapID, x, y, text[1])
  if node and new then node.seenOnly = true end
end

function M:OnEnable()
  self:On("PLAYER_ENTERING_WORLD", function(mod) mod:CheckTracking() end)
  self:On("MINIMAP_UPDATE_TRACKING", function(mod) mod:CheckTracking() end)
  if not M.hooked then
    local add, enum = C.Resolve("TooltipDataProcessor.AddTooltipPostCall"), C.Resolve("Enum.TooltipDataType.Object")
    if type(add) == "function" and enum then
      M.hooked = true
      add(enum, function(tip, data)
        if M.enabled and tip == rawget(_G, "GameTooltip") then ns.Safe("HerbHelper:tooltip", M.OnObjectTooltip, M, tip, data) end
      end)
    else
      self:Info("object tooltips can't be hooked on this client: pins come from gathering only")
    end
  end
end

function M:Activity()
  local seen = 0
  for _, n in ipairs(ns.db.global.nodes or {}) do if n.seenOnly then seen = seen + 1 end end
  return string.format("%d nodes pinned on sight", seen)
end
