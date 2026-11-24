-- Modules/QuestObjectives.lua
-- Where your quests' objectives are (requirement 2026-11-17: build every quest
-- into Outrider from the information in the Questie database).
-- The private pack Outrider_Data_Quests (tools/import_questie_quests.py, D10)
-- lists every quest's mobs, objects, items and places to explore with their
-- spawn points. For the quests in your log, the unfinished objectives become
-- pins on the world map and minimap (MapPins asks Pins(mapID)). Finished
-- objectives drop off as the client reports them done.
-- Quest objects can't be detected when they spawn (no event exists for
-- them), but the moment your mouse passes over one your quest needs (its
-- name in the tooltip), a pop-up says so and the spot is saved as seen on
-- Forever (verified), so the next search starts there.
-- Questie parity (requirement 2026-11-17: as full featured as Questie for quest
-- items and areas):
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
  defaults = { show = true, hoverAlert = true, arrowToTurnIn = true },
  yieldsTo = { "Questie" },
})
ns.QuestObjectives = M

M.ADDON = "Outrider_Data_Quests"
M.MAX_PINS = 150
M.ALERT_GAP = 60

local function readable(v) return v ~= nil and C.Readable(v) and v or nil end

function M:OnInitialize()
  local g = ns.db.global
  g.questSpots = ns.KeepTable(g.questSpots, "QuestObjectives:g.questSpots") or {} -- [name] = { {mapID, x, y, t} }
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
  if type(info) ~= "function" then return out end
  for i = 1, math.min(n, 60) do
    local ok, q = pcall(info, i)
    if ok and type(q) == "table" and not q.isHeader and q.questID then
      local list = M.Objectives(q.questID)
      out[#out + 1] = { questID = q.questID, title = readable(q.title) or "?", objectives = list,
        complete = M.IsDone(q.questID, q, list) }
    end
  end
  return out
end

-- A quest's objectives with a trustworthy "finished": the client's flag must
-- agree with the counts (numFulfilled/numRequired, else the "1/5" in the
-- text). Bug 2026-11-18: with 1 of 5 Crisp Spider Meat the quest showed as
-- done; a count below what's needed is never finished, whatever a flag says.
local function counts(e, text)
  local have, need = tonumber(readable(e.numFulfilled)), tonumber(readable(e.numRequired))
  if not (have and need and need > 0) and type(text) == "string" then
    local a, b = text:match("(%d+)%s*/%s*(%d+)")
    have, need = tonumber(a), tonumber(b)
  end
  if have and need and need > 0 then return have >= need end
  return nil -- no counts known (talk to, explore...)
end

function M.Objectives(questID)
  local list = {}
  local objs = C.Resolve("C_QuestLog.GetQuestObjectives")
  if type(objs) ~= "function" then return list end
  local ok, o = pcall(objs, questID)
  for _, e in ipairs(ok and ns.KeepTable(o, "QuestObjectives:o") or {}) do
    if type(e) == "table" then
      local text = readable(e.text) or ""
      local flag, enough = readable(e.finished), counts(e, text)
      local finished
      if enough == false then finished = false
      elseif flag == true or flag == 1 then finished = true
      else finished = enough == true end
      list[#list + 1] = { text = text, finished = finished }
    end
  end
  return list
end

-- Is a quest ready to hand in? The objectives decide when there are any: all
-- finished = ready, one short = not ready, whatever the other signals say
-- (old Classic values like -1 "failed" or 0 are truthy in Lua and wrongly
-- marked quests done). Quests without objectives (talk to someone) use the
-- client's own signals, counted only as a real true or 1. The modern client
-- can leave GetInfo's isComplete empty, so that alone never means "not done".
local function yes(v)
  v = readable(v)
  return v == true or v == 1
end

function M.IsDone(questID, info, objectives)
  if type(objectives) == "table" and #objectives > 0 then
    for _, o in ipairs(objectives) do if not o.finished then return false end end
    return true
  end
  if type(info) == "table" and yes(info.isComplete) then return true end
  if yes(C.Call("C_QuestLog.IsComplete", questID)) then return true end
  if yes(C.Call("C_QuestLog.ReadyForTurnIn", questID)) then return true end
  return false
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
  if ns.QuestInfo and ns.QuestInfo.enabled and not (hidden and hidden.qpath) then
    for _, pin in ipairs(ns.QuestInfo:PathPins(mapID)) do out[#out + 1] = pin end
  end
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
    if hit then
      out[#out + 1] = { t.quest .. ": " .. (t.progress or t.name), "good" }
      if ns.PartyQuests and ns.PartyQuests.enabled and t.progress then
        local party = ns.PartyQuests:ObjectiveLines(t.questID, t.progress)
        if #party > 0 then out[#out + 1] = { "  party: " .. table.concat(party, ", "), "muted" } end
      end
    end
  end
  return out
end

-- NEW-09: item quest context independent of the player's current log.
-- Reverse indexes are generated by tools/import_questie_quests.py from
-- quest startedBy and objective item references. This reads only those
-- indexes, never enumerates all quests on each tooltip.
function M:ItemQuestLines(itemID)
  local pack = self:Pack()
  if not pack or type(itemID) ~= "number" then return {} end
  local started, used = pack.itemStarts and pack.itemStarts[itemID],
    pack.itemUses and pack.itemUses[itemID]
  if type(started) ~= "table" and type(used) ~= "table" then return {} end
  local out, seen = {}, {}
  local cap = (ns.TooltipLines and ns.TooltipLines:Settings().questUsesLimit) or 2
  cap = math.max(1, math.min(10, tonumber(cap) or 2))
  local function add(list, prefix)
    if type(list) ~= "table" then ns.KeepBad(list, "QuestObjectives:list") return end
    local total = 0
    for _, questID in ipairs(list) do
      local q = pack.quests and pack.quests[questID]
      if type(questID) == "number" and q and not seen[questID] then
        seen[questID] = true
        total = total + 1
        if total <= cap then
          local done = C.Readable(C.Call("C_QuestLog.IsQuestFlaggedCompleted", questID)) == true
          local active = C.Readable(C.Call("C_QuestLog.IsOnQuest", questID)) == true
          local status = done and "done" or active and "in log" or "not completed (unverified)"
          out[#out + 1] = { prefix .. ": " .. tostring(q[1] or questID)
            .. " (" .. status .. ")", "warn" }
        end
      end
    end
    if total > cap then
      out[#out + 1] = { "  +" .. (total - cap) .. " more " .. prefix:lower() .. " references", "muted" }
    end
  end
  add(started, "Starts quest")
  add(used, "Used by quest")
  return out
end

ns.TooltipLines:Add("item", "questuses", M, function(tip, data)
  local id = type(data) == "table" and tonumber(C.Readable(data.id))
  if not id and tip.GetItem then
    local _, link = tip:GetItem()
    id = type(link) == "string" and tonumber(link:match("item:(%d+)"))
  end
  return id and M:ItemQuestLines(id) or {}
end)

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
  local W = ns.Waypoints
  local cont, wx, wy
  if W and W.PlayerWorldPos then cont, wx, wy = W.PlayerWorldPos() end
  local best, bestD
  -- distance in yards: on your map from map spots, elsewhere from world
  -- positions (bug 2026-11-21: by Undercity, "Go to nearest" pointed back
  -- to Orgrimmar because every other map counted the same); another
  -- continent counts as very far
  local function consider(mapID, x, y, label)
    local d
    if mapID == here and px and W and W.MapSize then
      local mw, mh = W.MapSize(mapID)
      d = math.sqrt(((x - px) * (mw or 1000)) ^ 2 + ((y - py) * (mh or 1000)) ^ 2)
    elseif wx and W and W.WorldPos then
      local c2, x2, y2 = W.WorldPos(mapID, x, y)
      if x2 and (c2 == nil or cont == nil or c2 == cont) then d = math.sqrt((x2 - wx) ^ 2 + (y2 - wy) ^ 2)
      else d = 1e7 end
    else
      d = 1e7
    end
    if not bestD or d < bestD then best, bestD = { mapID = mapID, x = x, y = y, label = label, yards = d < 1e7 and d or nil }, d end
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

-- Track the quest the way clicking it on the world map does (bug
-- 2026-11-18: the tracker click showed no arrow or area on the minimap): the
-- game's own super-tracking draws the arrow and the shaded objective area from
-- Forever's own quest data, and moves to the turn-in when the quest is done.
-- Outrider's own waypoint (Questie data) is only the fallback.
function M:Track(questID)
  local set = C.Resolve("C_SuperTrack.SetSuperTrackedQuestID")
  if type(set) ~= "function" or not questID then return false end
  local ok = pcall(set, questID)
  if not ok then return false end
  -- keep it watched so the game draws its area on the minimap
  local watch = C.Resolve("C_QuestLog.AddQuestWatch")
  if type(watch) == "function" then pcall(watch, questID) end
  -- our own arrow would sit on top of the game's: clear it if it's ours
  local W = ns.Waypoints
  if W and self.guideWP and W.current == self.guideWP then W:Clear("quest tracked") end
  self.guideWP, self.guideQuest, self.tracked = nil, questID, questID
  self:Info("tracking quest %d (game's own arrow and area)", questID)
  return true
end

-- Is this spot in the zone you're standing in? (the game's quest arrow and
-- our plain arrow only help there; elsewhere you need a route)
function M.SameZone(spot)
  local here = C.PlayerPosition("player")
  return here ~= nil and spot ~= nil and spot.mapID == here
end

function M:Guide(questID)
  local spot = self:Nearest(questID)
  -- in another zone or on another continent: plan the trip (flight masters,
  -- zeppelins, skyboats, boats) and let the arrow lead step by step (bug
  -- 2026-11-21: Exploring the Horde leads to Undercity and the click did
  -- nothing). The game's own quest arrow can't cross continents.
  if spot and not M.SameZone(spot) and ns.Journey and ns.Travel then
    local target = ns.Travel.Point(spot.mapID, spot.x, spot.y, spot.label)
    if target then
      local name = spot.label or ("quest " .. tostring(questID))
      local ok = pcall(ns.Journey.Go, ns.Journey, { name = name, target = target, sub = "quest" })
      if ok then
        -- the game still highlights the quest's area on the map
        local set = C.Resolve("C_SuperTrack.SetSuperTrackedQuestID")
        if type(set) == "function" then pcall(set, questID) end
        self.guideQuest = questID
        self:Info("quest %d is in %s: trip planned", questID, tostring(ns.Travel.ZoneName(spot.mapID)))
        return true
      end
    end
  end
  if self:Track(questID) then return true end
  if not (spot and ns.Waypoints) then return false end
  local ok, w = ns.Waypoints:Set(spot.mapID, spot.x, spot.y, spot.label)
  if ok then self.guideWP, self.guideQuest = w, questID end
  return ok and true or false
end

-- When a quest becomes ready, move the arrow to its turn-in right away
-- (requirement 2026-11-18). Only when the arrow is free or still on one of our
-- quest spots; a waypoint the player set (/way, a map note, a rare) stays.
function M:CheckReady()
  local now = {}
  for _, q in ipairs(M.Log()) do if q.complete then now[q.questID] = q end end
  local before = self.readySet
  self.readySet = now
  if not before or not self:Settings().arrowToTurnIn then return end -- first look after login: remember only
  local W = ns.Waypoints
  for id, q in pairs(now) do
    if not before[id] then
      local info = {}
      for i, o in ipairs(q.objectives or {}) do info[i] = o.text .. (o.finished and " [done]" or "") end
      self:Info("quest %d ready: %s | objectives: %s | IsComplete=%s ReadyForTurnIn=%s", id, q.title,
        table.concat(info, "; "), tostring(readable(C.Call("C_QuestLog.IsComplete", id))),
        tostring(readable(C.Call("C_QuestLog.ReadyForTurnIn", id))))
      local cur = W and W.current
      local ours = cur == nil or (self.guideWP ~= nil and cur == self.guideWP)
      -- a quest the game tracks: its arrow already moves to the turn-in
      if self.tracked == id then ours = false end
      if ours and self:Guide(id) then
        self:Info("quest ready: arrow to the turn-in of %s", q.title)
        return
      elseif not ours then
        self:Info("quest ready: %s (arrow kept on your own waypoint)", q.title)
      end
    end
  end
end

-- ------------------------------------------------------------------ module
function M:OnEnable()
  self:On("QUEST_LOG_UPDATE", function()
    ns.Throttle("questobjectives:ready", 0.3, function() M:CheckReady() end)
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
    { "stats", function()
      local log, ready = M.Log(), 0
      for _, q in ipairs(log) do if q.complete then ready = ready + 1 end end
      local QE, total, readyXP = ns.QuestExtras, 0, 0
      if QE and QE.QuestXP then total, readyXP = QE:QuestXP() end
      local need = tonumber(C.Readable(C.Call("UnitXPMax", "player"))) or 0
      local pace = QE and QE.Pace and QE:Pace()
      return {
        { cap = "In your log", value = tostring(#log), note = #log >= 20 and "log is filling up" or "quests" },
        { cap = "Ready to hand in", value = tostring(ready), color = ready > 0 and "good" or nil,
          note = readyXP > 0 and (readyXP .. " XP waiting") or "none yet" },
        { cap = "Log is worth", value = total > 0 and (total .. " XP") or "—", color = "gold",
          fill = need > 0 and total / need or nil },
        { cap = "XP pace", value = pace and pace.perHour and (math.floor(pace.perHour + 0.5) .. "/h") or "—",
          note = pace and pace.secondsToLevel and ("level in " .. ns.Duration(pace.secondsToLevel)) or "this session" },
      }
    end },
    { "header", "Your quest log", icon = "INV_Misc_Note_01" },
    { "note", function()
      if not M:Pack() then return "The quest data pack isn't installed yet." end
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
        if ns.QuestInfo and ns.QuestInfo.enabled then
          for _, l in ipairs(ns.QuestInfo:Lines(q.questID)) do lines[#lines + 1] = "|cff8fb4ff" .. l .. "|r" end
        end
        local actions = {}
        if e then
          actions[1] = { q.complete and "Go hand it in" or "Go to nearest", function() if not M:Guide(q.questID) then ns.Print("no location known for %s", q.title) end end,
            q.complete and "Sets the arrow on the quest's turn-in." or "Sets the arrow on the nearest spot of an objective you still need." }
        end
        out[#out + 1] = { pic = "Interface\\GossipFrame\\" .. (q.complete and "ActiveQuestIcon" or "AvailableQuestIcon"),
          title = q.title, tags = tags, line = #lines > 0 and table.concat(lines, "; ") or "No objectives listed.", actions = actions, highlight = q.complete }
      end
      return out
    end, compact = true },
    { "note", function() return #M.Log() == 0 and "Your quest log is empty. Quest givers (!) show on the map." or "" end },
    { "header", "Quest tracker", icon = "INV_Misc_Spyglass_02" },
    { "check", "Show Outrider's quest tracker", function() return ns.QuestTracker and ns.QuestTracker:Settings().show end,
      function(on) if ns.QuestTracker then ns.QuestTracker:Settings().show = on ns.QuestTracker:Refresh() end end },
    { "check", "Arrow to the turn-in when a quest is done", function() return M:Settings().arrowToTurnIn end,
      function(on) M:Settings().arrowToTurnIn = on end },
    { "check", "Hide the game's quest tracker", function() return ns.QuestTracker and ns.QuestTracker:Settings().hideBlizzard end,
      function(on) if ns.QuestTracker then ns.QuestTracker:Settings().hideBlizzard = on ns.QuestTracker:Refresh() end end },
    { "note", "Click a quest for the arrow, right-click to fold it, drag the title to move. /ride tracker level or nearest sorts it." },
    { "header", "Quests on the map and nameplates", icon = "INV_Misc_Map_01" },
    { "check", "Quest objectives on the map", function() return M:Settings().show end, function(on) M:Settings().show = on ns.MapPins:Invalidate() end },
    { "check", "Alert when I mouse over a quest object", function() return M:Settings().hoverAlert end, function(on) M:Settings().hoverAlert = on end },
    { "check", "Quest marks on nameplates", function() return ns.QuestExtras and ns.QuestExtras:Settings().plates end,
      function(on) if ns.QuestExtras then ns.QuestExtras:Settings().plates = on ns.QuestExtras:RefreshAll() end end },
    { "header", "Quest givers and sounds", icon = "INV_Misc_Bell_01" },
    { "check", "Show event quests (Darkmoon Faire, holidays)", function() return ns.QuestInfo and ns.QuestInfo:Settings().showEvent end,
      function(on) if ns.QuestInfo then ns.QuestInfo:Settings().showEvent = on end if ns.MapPins then ns.MapPins:Invalidate() end end },
    { "check", "Show quests for professions I don't have", function() return ns.QuestInfo and ns.QuestInfo:Settings().showOtherProf end,
      function(on) if ns.QuestInfo then ns.QuestInfo:Settings().showOtherProf = on end if ns.MapPins then ns.MapPins:Invalidate() end end },
    { "check", "Show repeatable quests", function() return ns.QuestInfo and ns.QuestInfo:Settings().showRepeatable end,
      function(on) if ns.QuestInfo then ns.QuestInfo:Settings().showRepeatable = on end if ns.MapPins then ns.MapPins:Invalidate() end end },
    { "check", "Sound when an objective or quest is done", function() return ns.QuestInfo and ns.QuestInfo:Settings().sounds end,
      function(on) if ns.QuestInfo then ns.QuestInfo:Settings().sounds = on end end },
    { "check", "Quest levels in chat links", function() return ns.QuestInfo and ns.QuestInfo:Settings().links end,
      function(on) if ns.QuestInfo then ns.QuestInfo:Settings().links = on end end },
    { "check", "Warn about skipped breadcrumb quests", function() return ns.QuestInfo and ns.QuestInfo:Settings().warnBreadcrumb end,
      function(on) if ns.QuestInfo then ns.QuestInfo:Settings().warnBreadcrumb = on end end },
    { "check", "Walking paths of escort NPCs on the map", function() return ns.QuestInfo and ns.QuestInfo:Settings().paths end,
      function(on) if ns.QuestInfo then ns.QuestInfo:Settings().paths = on end if ns.MapPins then ns.MapPins:Invalidate() end end },
  })
end)

function M:Activity()
  local pack = self:Pack()
  if not pack then return "no quest pack installed" end
  return string.format("%d objectives of your quests on the map", #self:Targets())
end
