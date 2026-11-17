-- Modules/QuestObjectives.lua
-- Where your quests' objectives are (Gary, 2026-11-17: "build all of those
-- quests into outrider by using the information in the Questie database").
-- The private pack Outrider_Data_Quests (tools/import_questie_quests.py, D10)
-- lists every quest's mobs, objects, items and places to explore with their
-- spawn points. For the quests in your log, the unfinished objectives become
-- pins on the world map and minimap (MapPins asks Pins(mapID)). Finished
-- objectives drop off as the client reports them done.
-- Quest objects can't be detected when they spawn (no event exists for
-- them), but the moment your mouse passes over one your quest needs (its
-- name in the tooltip), a pop-up says so and the spot is saved as seen on
-- Forever (verified), so the next search starts there.
-- Questie parity (Gary, 2026-11-17: "as full featured as Questie for quest
-- items and areas"):
--   * "?" turn-in pins where a finished quest is handed in
--   * "!" pins on objects that give quests (wanted posters...), filtered like
--     NPC quest givers (level, faction, class, race, quests done and needed)
--   * quest lines in mob, object and item tooltips with your progress
--   * the Quests page: every quest in your log, its progress, and an arrow
--     to the nearest objective or the turn-in
-- Community data, unverified; steps aside when Questie is installed.

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("QuestObjectives", {
  title = "Quest objectives on the map",
  phase = "P3",
  order = 36,
  defaults = { show = true, hoverAlert = true },
  yieldsTo = { "Questie" },
})
ns.QuestObjectives = M

M.ADDON = "Outrider_Data_Quests"
M.MAX_PINS = 150
M.ALERT_GAP = 60

local function readable(v) return v ~= nil and C.Readable(v) and v or nil end

function M:OnInitialize()
  local g = ns.db.global
  g.questSpots = type(g.questSpots) == "table" and g.questSpots or {} -- [name] = { {mapID, x, y, t} }
  self.seen, self.alerted = g.questSpots, {}
end

function M:Pack()
  if self.pack ~= nil then return self.pack end
  if not rawget(_G, "Outrider_DataQuests") then C.LoadAddOn(self.ADDON) end
  local d = rawget(_G, "Outrider_DataQuests")
  self.pack = type(d) == "table" and type(d.quests) == "table" and d or false
  self:Info(self.pack and "quest pack loaded (%s)" or "no quest pack (%s)", self.pack and tostring(d.source) or self.ADDON)
  return self.pack
end

-- ------------------------------------------------------------------ your quests
-- { {questID, title, objectives = { {text, finished} }} } from the quest log
function M.Log()
  local out = {}
  local n = tonumber(readable(C.Call("C_QuestLog.GetNumQuestLogEntries"))) or 0
  local info = C.Resolve("C_QuestLog.GetInfo")
  local objs = C.Resolve("C_QuestLog.GetQuestObjectives")
  if type(info) ~= "function" then return out end
  for i = 1, math.min(n, 60) do
    local ok, q = pcall(info, i)
    if ok and type(q) == "table" and not q.isHeader and q.questID then
      local list = {}
      if type(objs) == "function" then
        local ok2, o = pcall(objs, q.questID)
        for _, e in ipairs(ok2 and type(o) == "table" and o or {}) do
          list[#list + 1] = { text = readable(e.text) or "", finished = readable(e.finished) and true or false }
        end
      end
      out[#out + 1] = { questID = q.questID, title = readable(q.title) or "?", objectives = list,
        complete = readable(q.isComplete) and true or false }
    end
  end
  return out
end

-- is the objective about `name` already done in the client's list?
local function done(clientObjs, name)
  if not name then return false end
  local low = name:lower()
  for _, o in ipairs(clientObjs) do
    if o.text:lower():find(low, 1, true) then return o.finished end
  end
  return false
end

-- the unfinished targets of your quests: { {kind, id, name, quest, progress} }
function M:Targets()
  local pack = self:Pack()
  if not pack then return {} end
  local out = {}
  for _, q in ipairs(M.Log()) do
    local e = pack.quests[q.questID]
    if e and not q.complete then
      for _, o in ipairs(e[3] or {}) do
        local kind, id, text = o[1], o[2], o[3]
        local src = kind == "npc" and pack.npcs[id] or kind == "object" and pack.objects[id] or kind == "item" and pack.items[id]
        local name = src and src[1]
        if name and not done(q.objectives, text or name) then
          local progress
          for _, c in ipairs(q.objectives) do if c.text:lower():find((text or name):lower(), 1, true) then progress = c.text end end
          out[#out + 1] = { kind = kind, id = id, name = name, quest = q.title, questID = q.questID, progress = progress }
        end
      end
      if e.explore and not done(q.objectives, e.explore[1] or "") then
        out[#out + 1] = { kind = "explore", explore = e.explore, name = e.explore[1] or "Explore", quest = q.title, questID = q.questID }
      end
    end
  end
  return out
end

-- ------------------------------------------------------------------ pins
local function addPoints(out, mapID, pts, base, cap)
  for i = 1, #pts - 1, 2 do
    if #out >= cap then return end
    local pin = {}
    for k, v in pairs(base) do pin[k] = v end
    pin.id, pin.x, pin.y, pin.mapID = base.id .. "-" .. i, pts[i], pts[i + 1], mapID
    out[#out + 1] = pin
  end
end

-- "?" pins for finished quests, "!" pins for objects that give quests
function M:ExtraPins(mapID, hidden, out)
  local pack = self:Pack()
  if not pack then return end
  if not (hidden and hidden.turnin) then
    for _, q in ipairs(M.Log()) do
      local e = pack.quests[q.questID]
      if q.complete and e then
        local base = { kind = "turnin", name = "Turn in: " .. q.title, title = "Hand in " .. q.title, id = "turnin-" .. q.questID }
        for _, n in ipairs(e.fin or {}) do
          local src = pack.npcs[n]
          local pts = src and src[2] and src[2][mapID]
          if pts then base.title = "Hand in " .. q.title .. " to " .. src[1] addPoints(out, mapID, pts, base, M.MAX_PINS) end
        end
        for _, o in ipairs(e.finObj or {}) do
          local src = pack.objects[o]
          local pts = src and src[2] and src[2][mapID]
          if pts then base.title = "Hand in " .. q.title .. " at " .. src[1] addPoints(out, mapID, pts, base, M.MAX_PINS) end
        end
      end
    end
  end
  if not (hidden and hidden.quest_giver) and ns.NPCPack and pack.starters then
    for oid, list in pairs(pack.starters) do
      local src = pack.objects[oid]
      local pts = src and src[2] and src[2][mapID]
      if pts then
        local quests = ns.NPCPack:QuestsFor({ quests = list })
        if #quests > 0 then
          for i = 1, #pts - 1, 2 do
            out[#out + 1] = { kind = "quest_giver", id = "objgiver-" .. oid .. "-" .. i, mapID = mapID, x = pts[i], y = pts[i + 1],
              name = src[1], quests = quests, questColor = ns.NPCPack.DIFF_COLOR and ns.NPCPack.DIFF_COLOR[quests[1].diff] }
          end
        end
      end
    end
  end
end

function M:Pins(mapID, hidden)
  if not (self.enabled and self:Settings().show) then return {} end
  local pack = self:Pack()
  if not pack then return {} end
  local out = {}
  self:ExtraPins(mapID, hidden, out)
  if hidden and hidden.objective then return out end
  for _, t in ipairs(self:Targets()) do
    local title = (t.progress or t.name) .. "  (" .. t.quest .. ")"
    local base = { kind = "objective", name = t.name, title = title, id = "obj-" .. t.questID .. "-" .. t.kind .. "-" .. tostring(t.id) }
    if t.kind == "npc" or t.kind == "object" then
      local src = (t.kind == "npc" and pack.npcs or pack.objects)[t.id]
      local pts = src and src[2] and src[2][mapID]
      if pts then addPoints(out, mapID, pts, base, M.MAX_PINS) end
    elseif t.kind == "item" then
      local it = pack.items[t.id]
      for _, n in ipairs(it and it[2] or {}) do
        local src = pack.npcs[n]
        local pts = src and src[2] and src[2][mapID]
        if pts then
          base.title = title .. ", from " .. src[1]
          addPoints(out, mapID, pts, base, M.MAX_PINS)
        end
      end
      for _, o in ipairs(it and it[3] or {}) do
        local src = pack.objects[o]
        local pts = src and src[2] and src[2][mapID]
        if pts then
          base.title = title .. ", in " .. src[1]
          addPoints(out, mapID, pts, base, M.MAX_PINS)
        end
      end
    elseif t.kind == "explore" and t.explore[2] == mapID then
      addPoints(out, mapID, { t.explore[3], t.explore[4] }, base, M.MAX_PINS)
    end
    -- spots seen on Forever come first-class: a gold pin
    for _, s in ipairs(self.seen[t.name] or {}) do
      if s[1] == mapID and #out < M.MAX_PINS then
        out[#out + 1] = { kind = "objective", id = "seen-" .. t.name .. "-" .. s[2] .. "-" .. s[3], mapID = mapID, x = s[2], y = s[3],
          name = t.name .. " (seen here)", title = title .. ", seen here " .. date("%b %d", s[4] or time()) }
      end
    end
  end
  return out
end

-- ------------------------------------------------------------------ hover alert
-- names of the objects (and drop objects) your unfinished quests need
function M:ObjectNames()
  local pack = self:Pack()
  local out = {}
  if not pack then return out end
  for _, t in ipairs(self:Targets()) do
    if t.kind == "object" then out[t.name] = t
    elseif t.kind == "item" then
      local it = pack.items[t.id]
      for _, o in ipairs(it and it[3] or {}) do
        local src = pack.objects[o]
        if src then out[src[1]] = t end
      end
    end
  end
  return out
end

function M:OnTooltip(tt)
  if not (self:Settings().hoverAlert and tt and tt.GetUnit) then return end
  if tt:GetUnit() then return end
  local line = rawget(_G, "GameTooltipTextLeft1")
  local text = line and line.GetText and readable(line:GetText())
  if type(text) ~= "string" or text == "" then return end
  local target = self:ObjectNames()[text]
  if not target then return end
  local now = time()
  if self.alerted[text] and now - self.alerted[text] < M.ALERT_GAP then return end
  self.alerted[text] = now
  local mapID, x, y = C.PlayerPosition("player")
  if mapID and x then
    local list = self.seen[text] or {}
    local near = false
    for _, s in ipairs(list) do if s[1] == mapID and math.abs(s[2] - x) < 0.01 and math.abs(s[3] - y) < 0.01 then near = true end end
    if not near then list[#list + 1] = { mapID, x, y, now } end
    self.seen[text] = list
  end
  self:Info("quest object under the mouse: %s (%s)", text, target.quest)
  if ns.Toast then
    ns.Toast:Show({ title = text .. " is here", text = "Your quest " .. target.quest .. " needs it. Spot saved on your map.", color = { 0.4, 1, 0.4 } })
  end
  if ns.MapPins then ns.MapPins:Invalidate() end
end

-- ------------------------------------------------------------------ tooltips
-- lines for a mob (npcID), an object (by name) or an item your quests need
function M:LinesFor(kind, key)
  local pack = self:Pack()
  if not (pack and self:Settings().show) then return {} end
  local out = {}
  for _, t in ipairs(self:Targets()) do
    local hit = false
    if kind == "npc" then
      if t.kind == "npc" and t.id == key then hit = true end
      if t.kind == "item" then
        local it = pack.items[t.id]
        for _, n in ipairs(it and it[2] or {}) do if n == key then hit = true end end
      end
    elseif kind == "object" then
      if t.kind == "object" and t.name == key then hit = true end
      if t.kind == "item" then
        local it = pack.items[t.id]
        for _, o in ipairs(it and it[3] or {}) do
          local src = pack.objects[o]
          if src and src[1] == key then hit = true end
        end
      end
    elseif kind == "item" then
      hit = t.kind == "item" and t.id == key
    end
    if hit then out[#out + 1] = { t.quest .. ": " .. (t.progress or t.name), "good" } end
  end
  return out
end

ns.TooltipLines.ORDER.quest = ns.TooltipLines.ORDER.quest or 45
ns.TooltipLines:Add("unit", "quest", M, function(tip)
  if not tip.GetUnit then return end
  local _, unit = tip:GetUnit()
  local npc = unit and C.UnitNpcID(unit)
  if npc then return M:LinesFor("npc", npc) end
end)
ns.TooltipLines:Add("item", "quest", M, function(tip, data)
  local id = type(data) == "table" and readable(data.id)
  if not id and tip.GetItem then
    local _, link = tip:GetItem()
    id = link and tonumber(tostring(link):match("item:(%d+)"))
  end
  if id then return M:LinesFor("item", id) end
end)

-- ------------------------------------------------------------------ guiding
-- the nearest place for one quest: the turn-in when it's done, else the
-- closest spawn of an unfinished objective (this map first)
function M:Nearest(questID)
  local pack = self:Pack()
  if not pack then return nil end
  local here, px, py = C.PlayerPosition("player")
  local best, bestD
  local function consider(mapID, x, y, label)
    local d = (mapID == here and px) and ((x - px) ^ 2 + (y - py) ^ 2) or (10 + (best and 0 or 0))
    if not bestD or d < bestD then best, bestD = { mapID = mapID, x = x, y = y, label = label }, d end
  end
  local function each(src, label)
    for mapID, pts in pairs(src and src[2] or {}) do
      for i = 1, #pts - 1, 2 do consider(mapID, pts[i], pts[i + 1], label) end
    end
  end
  for _, q in ipairs(M.Log()) do
    if q.questID == questID then
      local e = pack.quests[questID]
      if not e then return nil end
      if q.complete then
        for _, n in ipairs(e.fin or {}) do each(pack.npcs[n], "Hand in: " .. q.title) end
        for _, o in ipairs(e.finObj or {}) do each(pack.objects[o], "Hand in: " .. q.title) end
        return best
      end
      for _, t in ipairs(self:Targets()) do
        if t.questID == questID then
          if t.kind == "npc" then each(pack.npcs[t.id], t.name)
          elseif t.kind == "object" then each(pack.objects[t.id], t.name)
          elseif t.kind == "item" then
            local it = pack.items[t.id]
            for _, n in ipairs(it and it[2] or {}) do each(pack.npcs[n], t.name) end
            for _, o in ipairs(it and it[3] or {}) do each(pack.objects[o], t.name) end
          elseif t.kind == "explore" then consider(t.explore[2], t.explore[3], t.explore[4], t.name) end
        end
      end
      return best
    end
  end
end

function M:Guide(questID)
  local spot = self:Nearest(questID)
  if not (spot and ns.Waypoints) then return false end
  ns.Waypoints:Set(spot.mapID, spot.x, spot.y, spot.label)
  return true
end

-- ------------------------------------------------------------------ module
function M:OnEnable()
  self:On("QUEST_LOG_UPDATE", function()
    ns.Throttle("questobjectives:refresh", 2, function()
      if ns.MapPins and ns.MapPins.Invalidate then ns.MapPins:Invalidate() end
    end)
  end)
  local tt = rawget(_G, "GameTooltip")
  if tt and tt.HookScript and not self.hooked then
    self.hooked = true
    tt:HookScript("OnShow", function(self) if M.enabled then ns.Safe("questobjectives:tooltip", M.OnTooltip, M, self) end end)
  end
end

ns.Hub:AddTab("quests", "Quests", function(p)
  local UI = ns.UI
  UI:FormPage(p, {
    { "header", "Quests" },
    { "header", "Your quest log", icon = "INV_Misc_Note_01" },
    { "note", function()
      if not M:Pack() then return "The quest data pack isn't installed: run python tools/import_questie_quests.py --deploy, then restart the game." end
      return "Go puts the arrow on the nearest objective (or the turn-in when it's done). Pins on the map show every spot. Community data, unverified."
    end },
    { "cards", function()
      local out = {}
      local pack = M:Pack()
      for _, q in ipairs(M.Log()) do
        local e = pack and pack.quests[q.questID]
        local tags = { { e and ("Level " .. e[2]) or "", "plain" } }
        if q.complete then tags[#tags + 1] = { "Ready to hand in", "gold" } end
        local lines = {}
        for _, o in ipairs(q.objectives) do lines[#lines + 1] = (o.finished and "|cff7fff7f" or "") .. o.text .. (o.finished and "|r" or "") end
        local actions = {}
        if e then
          actions[1] = { q.complete and "Go hand it in" or "Go to nearest", function() if not M:Guide(q.questID) then ns.Print("no location known for %s", q.title) end end,
            q.complete and "Sets the arrow on the quest's turn-in." or "Sets the arrow on the nearest spot of an objective you still need." }
        end
        out[#out + 1] = { pic = "Interface\\GossipFrame\\" .. (q.complete and "ActiveQuestIcon" or "AvailableQuestIcon"),
          title = q.title, tags = tags, line = #lines > 0 and table.concat(lines, "; ") or "No objectives listed.", actions = actions, highlight = q.complete }
      end
      return out
    end },
    { "note", function() return #M.Log() == 0 and "Your quest log is empty. Quest givers (!) show on the map." or "" end },
  })
end)

function M:Activity()
  local pack = self:Pack()
  if not pack then return "no quest pack: run tools/import_questie_quests.py --deploy" end
  return string.format("%d objectives of your quests on the map", #self:Targets())
end
