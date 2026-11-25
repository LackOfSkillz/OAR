-- Modules/HerbHelper.lua
-- Covers what herbalism addons do (requirement 2026-11-12), built our own way
-- (ideas only, no code or data copied from other addons):
--   * Find Herbs reminder: herb dots on the minimap come from Blizzard's
--     "Find Herbs" tracking. If you have Herbalism and it is off, say so once
--     per character per day (hard rule 6). Outrider never switches it itself.
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
  defaults = { remind = true, pinOnSight = true, hints = true },
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
        -- at most once per character per day: a /reload or another login the
        -- same day doesn't repeat it (it came back 38 times, 2026-11-24)
        local s = self:Settings()
        s.remindedOn = type(s.remindedOn) == "table" and s.remindedOn or {}
        local today = date("%Y-%m-%d")
        if t.name == spell and not t.active and s.remind and s.remindedOn[spell] ~= today then
          s.remindedOn[spell] = today
          -- to the Feed, not chat: login stays quiet (rule 6, premium plan B18)
          if ns.Feed then ns.Feed:Add(nil, { title = spell .. " is off", color = "warn", action = "tracking", arg = spell,
            text = "Herb and ore dots won't show on the minimap. Press Turn on here, or your Herb button (Macros page)." }) end
          self:Info("%s tracking is off", spell)
        end
      end
    end
  end
end

-- Turn a minimap tracking type on, from the player's click on the feed card
-- (the same call Blizzard's tracking menu makes). Checked again afterwards;
-- if this client refuses, the Herb button (a /cast macro) still works.
function M:TurnOn(spell)
  local n = C.Call("C_Minimap.GetNumTrackingTypes")
  if type(n) ~= "number" then return false, "this client doesn't list tracking: press your Herb button instead" end
  for i = 1, n do
    local info = C.Call("C_Minimap.GetTrackingInfo", i)
    if type(info) == "table" and C.Readable(info.name) == spell then
      if info.active then return true, spell .. " is already on" end
      local fn = C.Resolve("C_Minimap.SetTracking")
      local ok = type(fn) == "function" and pcall(fn, i, true)
      local again = C.Call("C_Minimap.GetTrackingInfo", i)
      if ok and type(again) == "table" and again.active then
        self:Info("%s turned on from the feed", spell)
        return true, spell .. " is on: herb dots show on the minimap"
      end
      self:Info("%s: turning on from the feed didn't work", spell)
      return false, "couldn't turn " .. spell .. " on from here: press your Herb button (Macros page)"
    end
  end
  return false, spell .. " isn't in your tracking list"
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
  if ns.FishingHUD and ns.FishingHUD.enabled then ns.FishingHUD:OnPoolTooltip(text[1]) end
  if not self:Settings().pinOnSight or not ns.LootLog or not ns.LootLog.enabled then return end
  local kind
  for i = 2, #text do
    for skill, k in pairs(SKILL_KIND) do
      if text[i]:find(skill, 1, true) then kind = k end
    end
  end
  if not kind then return end
  if kind == "herb" then self:AddSkillLine(tip, text[1]) end
  local mapID, x, y = C.PlayerPosition("player")
  if not (mapID and x) then return end
  ns.LootLog:MarkNode(kind, mapID, x, y, "up")
  local key = string.format("%s:%d:%.0f:%.0f", text[1], mapID, x * 200, y * 200)
  self.seen = self.seen or {}
  if self.seen[key] then return end
  self.seen[key] = true
  local node, new = ns.LootLog:AddNode(kind, mapID, x, y, text[1])
  if node and new then node.seenOnly = true end
end

-- ------------------------------------------------ guide hints (Data/Herbs.lua)
function M:Guide(name) return type(name) == "string" and ns.Data:Get("herb", name) or nil end

function M:MySkill()
  local p = ns.db.char.professions and ns.db.char.professions.Herbalism
  return p and tonumber(p.skill) or nil
end

-- "Herbalism 15 needed (you have 4)" on a herb node, when a guide states the skill.
function M:SkillLine(name)
  local g = self:Guide(name)
  if not (g and g.skill) then return nil end
  local mine = self:MySkill()
  if not mine then return string.format("Herbalism %d needed (guide)", g.skill), "muted" end
  return string.format("Herbalism %d needed (you have %d)", g.skill, mine), mine >= g.skill and "good" or "bad"
end

function M:AddSkillLine(tip, name)
  if not self:Settings().hints then return end
  local text, color = self:SkillLine(name)
  if not text or not tip.AddLine then return end
  local r, g, b = ns.Theme:Color(color)
  tip:AddLine(text, r, g, b)
  if tip.Show then tip:Show() end
end

-- "Grows in: ..." on a herb item (bags, loot, auction house).
function M:ItemLines(name)
  local g = self:Guide(name)
  if not g or not self:Settings().hints then return nil end
  local out = {}
  if g.zones and #g.zones > 0 then out[#out + 1] = { "Grows in: " .. table.concat(g.zones, ", "), "muted" } end
  if g.skill then out[#out + 1] = { string.format("Herbalism %d to pick (guide)", g.skill), "muted" } end
  if g.note then out[#out + 1] = { g.note, "muted" } end
  return #out > 0 and out or nil
end

ns.TooltipLines:Add("item", "herb", M, function(tip)
  if not tip.GetItem then return nil end
  local name = tip:GetItem()
  return M:ItemLines(C.Readable(name))
end)

function M:OnEnable()
  -- the feed card's "Turn on" button (Feed loads after this file)
  if ns.Feed and ns.Feed.RegisterAction then
    ns.Feed.RegisterAction("tracking", "Turn on", "Switch this minimap tracking on now (your click).",
      function(spell) return M:TurnOn(spell) end)
  end
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

ns.AddCommand("herbs", "  where each herb grows and the skill it needs (from guides, unverified)", function()
  local mine = M:MySkill()
  ns.Print("Herbs by guide (unverified on Forever)%s:", mine and (", your Herbalism " .. mine) or "")
  local list = {}
  for _, packs in pairs(ns.Data.packs.herb or {}) do for _, h in ipairs(packs) do list[#list + 1] = h end end
  for _, h in ipairs(list) do
    local skill = h.skill and (" " .. h.skill) or ""
    local where = h.zones and #h.zones > 0 and table.concat(h.zones, ", ") or (h.note or "zones not documented")
    local mark = (mine and h.skill and mine >= h.skill) and "|cff7fff7f" or ""
    ns.Print("  %s%s%s|r: %s", mark, h.name, skill, where)
  end
end)
