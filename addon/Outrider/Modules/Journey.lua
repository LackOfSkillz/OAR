-- Modules/Journey.lua
-- "Find me the best gear quests and the best XP quests anywhere, then guide
-- me there" (Gary, 2026-11-13). Hub tab Journey (Gary's choice) with two
-- lists, plus /ride journey [gear|xp|<number>|stop]:
--   Gear  upgrades from the gear pack on every map (Nearby with world = true),
--         best gain first, then the quicker trip
--   XP    quests you can pick up now on every map (NPC pack), ranked by
--         estimated XP per minute: XP / (trip + 5 minutes to do it)
--         (Gary chose XP per minute). XP is an estimate from the quest's
--         level, reduced for quests far below you like the game does.
-- Guide me: the route comes from Travel; the arrow points at the end of the
-- first leg. When that leg is done (arrived, landed, loading screen, new
-- zone) the route is worked out again from where Gary stands, so a missed
-- step or a detour fixes itself. Flights and rides are Gary's to take: the
-- guide says which one, once, in chat.

local _, ns = ...
local C = ns.Compat
local UI = ns.UI
local M = ns:NewModule("Journey", {
  title = "Journey: best gear and XP quests anywhere, with a route",
  phase = "P3",
  order = 48,
  defaults = {},
})
ns.Journey = M

M.QUEST_TIME = 300 -- seconds to do a quest once there (estimate)
M.MAX = 40
M.AT = 30         -- yards: standing at a step's end (a dock spot is approximate)

-- Estimated quest XP (no XP data in the pack): grows with quest level,
-- cut for quests far below you (Classic: 6 levels 80%, 7 60%, 8 40%, 9 20%, 10+ 10%).
function M.XP(qlevel, level)
  local base = 1.5 * qlevel * qlevel + 55 * qlevel + 120
  local d = level - qlevel
  local cut = d <= 5 and 1 or d == 6 and 0.8 or d == 7 and 0.6 or d == 8 and 0.4 or d == 9 and 0.2 or 0.1
  return math.floor(base * cut / 10 + 0.5) * 10
end

local function zone(mapID) return ns.Travel.ZoneName(mapID) end

function M:GearList()
  local list = ns.Nearby and ns.Nearby:Candidates({ world = true }) or {}
  local prep = ns.Travel:Prepare()
  local out = {}
  for _, c in ipairs(list) do
    local w = c.where
    local p = w and w.mapID and ns.Travel.Point(w.mapID, w.x, w.y, w.who)
    if p then
      local t = ns.Travel:TimeTo(prep, p)
      out[#out + 1] = { kind = "gear", name = c.name, itemID = c.itemID, pct = c.pct, target = p, seconds = t, mapID = w.mapID,
        detail = ns.Nearby.Describe(c), note = w.note }
    end
  end
  table.sort(out, function(a, b)
    if (a.note ~= nil) ~= (b.note ~= nil) then return a.note == nil end
    local pa, pb = math.floor(a.pct / 5), math.floor(b.pct / 5)
    if pa ~= pb then return pa > pb end
    return (a.seconds or 1e9) < (b.seconds or 1e9)
  end)
  while #out > M.MAX do table.remove(out) end
  return out
end

function M:XPList()
  local level = C.Call("UnitLevel", "player") or 1
  local prep = ns.Travel:Prepare()
  local out = {}
  for _, q in ipairs(ns.NPCPack and ns.NPCPack:AvailableEverywhere() or {}) do
    if q.diff ~= "red" and q.diff ~= "grey" then
      local p = ns.Travel.Point(q.mapID, q.x, q.y, q.giver)
      local t = p and ns.Travel:TimeTo(prep, p)
      if t then
        local xp = M.XP(q.level, level)
        out[#out + 1] = { kind = "xp", name = q.name, level = q.level, questID = q.questID,
          xp = xp, target = p, seconds = t, mapID = q.mapID,
          giver = q.giver, rate = xp / ((t + M.QUEST_TIME) / 60), diff = q.diff }
      end
    end
  end
  table.sort(out, function(a, b) return a.rate > b.rate end)
  while #out > M.MAX do table.remove(out) end
  return out
end

-- DEEP-22: zone-level XP opportunity summary. Estimates are explicitly
-- conditional on the available QuestieDB quest-giver pack; absence is NOT
-- evidence that a zone has no quests.
function M:ZoneOutlook()
  local result, all = {}, {}
  local playerLevel = tonumber(C.Readable(C.Call("UnitLevel", "player"))) or 1
  local currentXP = tonumber(C.Readable(C.Call("UnitXP", "player"))) or 0
  local toNext = tonumber(C.Readable(C.Call("UnitXPMax", "player"))) or 0
  for _, q in ipairs(ns.NPCPack and ns.NPCPack:AvailableEverywhere() or {}) do
    if type(q.mapID) == "number" and type(q.level) == "number" then
      local group = all[q.mapID]
      if not group then
        group = { mapID = q.mapID, name = zone(q.mapID), count = 0, estimatedXP = 0,
          greySoon = 0, greyNow = 0 }
        all[q.mapID] = group
        result[#result + 1] = group
      end
      group.count = group.count + 1
      local xp = M.XP(q.level, playerLevel)
      if q.diff ~= "grey" and q.diff ~= "red" then group.estimatedXP = group.estimatedXP + xp end
      if q.level <= playerLevel - 5 then group.greySoon = group.greySoon + 1 end
      if q.diff == "grey" then group.greyNow = group.greyNow + 1 end
    end
  end
  for _, g in ipairs(result) do
    g.remainingToLevel = math.max(0, toNext - currentXP)
    -- Only indicates whether the currently *known, offered* quests could
    -- theoretically grant enough XP; not a guarantee of level completion.
    g.couldLevel = g.remainingToLevel > 0 and g.estimatedXP >= g.remainingToLevel
  end
  table.sort(result, function(a, b)
    if a.estimatedXP ~= b.estimatedXP then return a.estimatedXP > b.estimatedXP end
    return a.name < b.name
  end)
  return result
end

ns.AddCommand("zones", "zones  known available quest XP by zone (estimates)", function()
  local groups = M:ZoneOutlook()
  if #groups == 0 then ns.Print("zone XP: quest-giver pack unavailable or no confirmed offerings") return end
  for i = 1, math.min(10, #groups) do
    local g = groups[i]
    ns.Print("%s: ~%d XP, %d known quests (%d near-grey, %d grey)%s",
      g.name, g.estimatedXP, g.count, g.greySoon, g.greyNow,
      g.couldLevel and "; enough *estimated* XP for next level" or "")
  end
end)

function M.Line(e)
  if e.kind == "gear" then
    return string.format("%s  |cffbbbbbb%s, %s|r", e.detail, zone(e.mapID), ns.Travel.Minutes(e.seconds))
  end
  return string.format("[%d] %s  |cffbbbbbb~%d XP, %s, %s (%s), %d XP/min|r", e.level, e.name, e.xp, zone(e.mapID),
    ns.Travel.Minutes(e.seconds), tostring(e.giver), math.floor(e.rate + 0.5))
end

-- ------------------------------------------------------------------ guide
function M:Go(entry)
  self.goal = entry
  self.said = {}
  -- kept per character so a /reload, logout or loading screen doesn't end it
  local t = entry.target
  self:Settings().goal = { name = entry.name, sub = entry.sub, seconds = entry.seconds, npcID = entry.npcID, t = time(),
    target = { mapID = t.mapID, x = t.x, y = t.y, label = t.label } }
  self:Info("journey to %s (%s), about %s", tostring(entry.name), zone(entry.target.mapID), ns.Travel.Minutes(entry.seconds))
  return self:Step("start")
end

function M:Stop(why)
  if not self.goal then return end
  self:Info("journey stopped (%s)", tostring(why))
  self.goal = nil
  self:Settings().goal = nil
  if ns.Waypoints.current and ns.Waypoints.current.opts and ns.Waypoints.current.opts.journey then
    ns.Waypoints:Clear("journey stopped", true)
  end
end

local function say(self, text)
  if self.said[text] then return end
  self.said[text] = true
  ns.Print("Journey: %s", text)
end

-- Work out the route again from here and point at the end of the first leg.
function M:Step(why)
  local goal = self.goal
  if not goal then return nil end
  local route, whyNot = ns.Travel:Route(goal.target)
  if not route then
    say(self, whyNot)
    local t = goal.target
    ns.Waypoints:Set(t.mapID, t.x, t.y, tostring(goal.name), { journey = true }) -- the marker still shows where it is
    return nil
  end
  local first = route.steps[1]
  -- Already at the end of the walk to a dock or flight master (Gary,
  -- 2026-11-15, Menethil: the arrow was "arrived", set again and cleared
  -- once a second): the step now is the ride, which is Gary's to take, so
  -- say it once and wait for the loading screen or landing.
  if first.kind == "walk" and route.steps[2] and first.to and first.to.wx then
    local here = ns.Travel.Here()
    if here and here.wx and math.sqrt((here.wx - first.to.wx) ^ 2 + (here.wy - first.to.wy) ^ 2) < M.AT then
      table.remove(route.steps, 1)
      first = route.steps[1]
      if ns.Waypoints.current and ns.Waypoints.current.opts and ns.Waypoints.current.opts.journey then
        ns.Waypoints:Clear("journey ride", true)
      end
      say(self, "Now: " .. first.text)
      self:Debug("journey step (%s): %s", tostring(why), first.text)
      self.route = route
      return route
    end
  end
  if #route.steps == 1 then
    local here = ns.Travel.Here()
    local dx = here and (here.wx - goal.target.wx) or 1e9
    local dy = here and (here.wy - goal.target.wy) or 1e9
    if math.sqrt(dx * dx + dy * dy) < 25 then
      say(self, "you're there: " .. tostring(goal.name))
      self.goal = nil
      self:Settings().goal = nil
      return route
    end
  end
  if first.kind == "walk" then
    local to = first.to
    ns.Waypoints:Set(to.mapID, to.x, to.y, (first.text:gsub("^Go to ", "")), { journey = true })
    if #route.steps > 1 then say(self, first.text .. ", then: " .. route.steps[2].text) end
  else
    say(self, first.text)
  end
  self:Debug("journey step (%s): %s", tostring(why), first.text)
  self.route = route
  return route
end

-- ------------------------------------------------------------ pin tooltip
-- Gary (2026-11-13): hovering the map marker only said "Map Pin Sharing".
-- Blizzard's own waypoint pin keeps its tooltip; we add our lines under it:
-- what the marker is for, the step you're on, distance and time, what's next.
M.PIN_TEMPLATE = "WaypointLocationPinTemplate"

function M:PinLines()
  local w = ns.Waypoints.current
  if not w then return nil end
  local out = {}
  local goal = self.goal
  if goal then
    out[#out + 1] = { "Outrider: " .. tostring(goal.name), "accent" }
    if goal.sub and goal.sub ~= "" then out[#out + 1] = { tostring(goal.sub):gsub("|c%x+", ""):gsub("|r", ""), "muted" } end
  else
    out[#out + 1] = { "Outrider: " .. tostring(w.title), "accent" }
  end
  local d = ns.Waypoints:Distance()
  if d then
    out[#out + 1] = { string.format("%d yards away, about %s on foot", math.floor(d + 0.5), ns.Travel.Minutes(d / ns.Travel.RUN)), "text" }
  end
  local r = goal and self.route
  if r and r.steps then
    out[#out + 1] = { string.format("Now: %s", r.steps[1].text), "text" }
    if r.steps[2] then out[#out + 1] = { string.format("Then: %s", r.steps[2].text), "muted" } end
    if #r.steps > 2 then out[#out + 1] = { string.format("%d steps in all, about %s", #r.steps, ns.Travel.Minutes(r.seconds)), "muted" } end
  end
  out[#out + 1] = { "Stop the guide on Outrider's Journey page.", "muted" }
  return out
end

function M:HookPins()
  local map = rawget(_G, "WorldMapFrame")
  if not (map and map.EnumeratePinsByTemplate) then return 0 end
  local n = 0
  local ok = pcall(function()
    for pin in map:EnumeratePinsByTemplate(M.PIN_TEMPLATE) do
      if not pin.outriderHooked and pin.HookScript then
        pin.outriderHooked = true
        pin:HookScript("OnEnter", function()
          local lines = M.enabled and M:PinLines()
          local tip = rawget(_G, "GameTooltip")
          if not (lines and tip and tip:IsShown()) then return end
          for _, l in ipairs(lines) do
            local r, g, b = ns.Theme:Color(l[2])
            tip:AddLine(l[1], r, g, b, true)
          end
          tip:Show()
        end)
      end
      n = n + 1
    end
  end)
  if not ok and not self.pinWarned then self.pinWarned = true self:Info("map pin tooltip: could not reach the waypoint pins") end
  return n
end

function M:OnEnable()
  -- the waypoint pin exists once a waypoint is set and the map is open
  self:On("OTR_WAYPOINT_SET", function(mod) mod:HookPins() end)
  local map = rawget(_G, "WorldMapFrame")
  if map and map.HookScript and not M.mapHooked then
    M.mapHooked = true
    map:HookScript("OnShow", function() if M.enabled then ns.Safe("journey:pins", M.HookPins, M) end end)
  end
  -- a journey from before the /reload or logout carries on
  local saved = self:Settings().goal
  if not self.goal and type(saved) == "table" and type(saved.target) == "table" and saved.target.mapID then
    local t = saved.target
    local p = ns.Travel.Point(t.mapID, t.x, t.y, t.label)
    -- a rare goal that was tamed or killed meanwhile is done, not resumed
    -- (journeys saved before 2026-11-15 21:30 carry no npcID: found by name)
    local npcID = saved.npcID
    if not npcID then
      for _, e in ipairs(ns.Data:All("rare")) do if e.name == saved.name then npcID = e.npcID end end
    end
    local last = npcID and ns.Sightings and ns.Sightings.Last and ns.Sightings:Last(npcID)
    if last and (last.state == "tamed" or last.state == "dead") and (not saved.t or (last.t or 0) >= saved.t) then
      self:Info("journey to %s not resumed: it was %s", tostring(saved.name), last.state)
      self:Settings().goal = nil
      p = nil
    end
    if p then
      self.goal = { name = saved.name, sub = saved.sub, seconds = saved.seconds, npcID = saved.npcID, target = p }
      self.said = {}
      self:Info("journey to %s carries on after the reload", tostring(saved.name))
      ns.Throttle("journey", 2, function() if M.goal then M:Step("resumed") end end)
    end
  end
  local function again(why) return function(mod) if mod.goal then ns.Throttle("journey", 2, function() mod:Step(why) end) end end end
  self:On("OTR_WAYPOINT_CLEARED", function(mod, _, w, why)
    if mod.goal and why == "arrived" and w and w.opts and w.opts.journey then mod:Step("arrived") end
  end)
  -- a journey to a rare ends when it is tamed or killed (Gary, 2026-11-15:
  -- after taming The Rake the guide kept sending him back to Mulgore)
  self:On("OTR_SIGHTING_ADDED", function(mod, _, npcID, sight)
    local g = mod.goal
    if g and g.npcID and g.npcID == npcID and type(sight) == "table" and (sight.state == "tamed" or sight.state == "dead") then
      say(mod, string.format("%s %s: journey done", tostring(g.name), sight.state == "tamed" and "tamed" or "killed"))
      mod:Stop(sight.state)
    end
  end)
  self:On("ZONE_CHANGED_NEW_AREA", again("zone"))
  self:On("PLAYER_CONTROL_GAINED", again("landed"))
  self:On("PLAYER_ENTERING_WORLD", again("loading screen"))
end

function M:OnDisable() ns.ThrottleCancel("journey") end

function M:Activity()
  if self.goal then return "guiding to " .. tostring(self.goal.name) end
  return "Journey tab: best gear and XP quests anywhere, with a route"
end

-- -------------------------------------------------------------------- tab
ns.Hub:AddTab("journey", "Journey", function(p)
  local F = ns.Finder
  p.kind, p.text = "all", ""
  p.search = UI:SearchBox(p, 220, "Search anything", function(t) p.text = t p:Refresh() end)
  p.search:SetPoint("TOPLEFT", 0, 0)
  p.sortBtn = UI:Button(p, "Sort: nearest", 150, function()
    local cur, nxt = p.sort or F.DEFAULT_SORT[p.kind], 1
    for i, s in ipairs(F.SORTS) do if s == cur then nxt = i % #F.SORTS + 1 end end
    p.sort = F.SORTS[nxt]
    p:Refresh()
  end)
  p.sortBtn:SetPoint("LEFT", p.search, "RIGHT", 8, 0)
  p.count = UI.Text(p, "small", "muted")
  p.count:SetPoint("LEFT", p.sortBtn, "RIGHT", 8, 0)
  p.kindBtns = {}
  local prev
  for _, k in ipairs(F.KINDS) do
    local b = UI:Button(p, F.KIND_LABEL[k], 62, function() p.kind, p.sort = k, nil p:Refresh() end)
    if prev then b:SetPoint("LEFT", prev, "RIGHT", 4, 0) else b:SetPoint("TOPLEFT", p.search, "BOTTOMLEFT", 0, -6) end
    p.kindBtns[k], prev = b, b
  end
  p.list = UI:ScrollList(p, {
    rows = 16, rowHeight = 22,
    render = function(row, e) row.text:SetText(F.Line(e)) end,
    onClick = function(e) p:ShowRoute(e) if e.target then M:Go(e) end end, -- one click: route, marker and arrow
  })
  p.list:SetPoint("TOPLEFT", p.kindBtns.all, "BOTTOMLEFT", 0, -6)
  p.list:SetPoint("RIGHT", p, "RIGHT", -4, 0) -- as wide as the window
  p.route = UI.Text(p, "small", "text")
  p.route:SetPoint("TOPLEFT", p.list, "BOTTOMLEFT", 0, -6)
  p.route:SetPoint("RIGHT", p, "RIGHT", -4, 0)
  p.route:SetJustifyH("LEFT")
  p.go = UI:Button(p, "Guide me again", 130, function() if p.current then M:Go(p.current) end end)
  p.go:SetPoint("TOPLEFT", p.route, "BOTTOMLEFT", 0, -8) -- right under the route, never off the bottom
  p.stop = UI:Button(p, "Stop", 80, function() M:Stop("button") end)
  p.stop:SetPoint("LEFT", p.go, "RIGHT", 6, 0)
  function p:ShowRoute(e)
    self.current = e
    if not e.target then self.route:SetText("No position for this one.") return end
    local route, why = ns.Travel:Route(e.target)
    if not route then self.route:SetText(why) return end
    local lines = { string.format("%s: about %s", tostring(e.name), ns.Travel.Minutes(route.seconds)) }
    for i, st in ipairs(route.steps) do lines[#lines + 1] = string.format("%d. %s", i, st.text) end
    self.route:SetText(table.concat(lines, "\n"))
  end
  function p:Refresh()
    -- a search typed in the hub's top bar lands here
    local pending = ns.Hub.pendingSearch
    if pending then
      ns.Hub.pendingSearch = nil
      self.kind, self.sort, self.text = "all", nil, pending
      self.search:SetText(pending)
    end
    local list, total, sort = F:Find({ kind = self.kind, text = self.text, sort = self.sort })
    self.sortBtn.label:SetText("Sort: " .. (F.SORT_LABEL[sort] or sort))
    self.count:SetText(string.format("%d found%s", total, total > #list and (", first " .. #list .. " shown") or ""))
    self.list:SetItems(list)
    self.route:SetText(#list == 0 and "Nothing found (item data may still be loading: try again in a moment)."
      or "Click a line: the route shows here and the marker and arrow go up. Community data is unverified; 'seen' means you met it.")
  end
end, 45)

ns.AddCommand("journey", "[kind] [search] | <number> | stop  find anything (gear item quest rare mob npc place); a number guides you there", function(arg)
  arg = arg or ""
  if arg:lower() == "stop" then M:Stop("command") ns.Print("Journey stopped") return end
  local n = tonumber(arg)
  if n then
    local e = M.last and M.last[n]
    if not e then ns.Print("search first, e.g. /ride journey quest or /ride journey rare mystmane") return end
    if not e.target then ns.Print("no position for that one") return end
    M:Go(e)
    return
  end
  local first, rest = arg:match("^(%S*)%s*(.-)$")
  local kind, text = "all", arg
  for _, k in ipairs(ns.Finder.KINDS) do if first:lower() == k then kind, text = k, rest end end
  if first:lower() == "xp" then kind, text = "quest", rest end
  local list, total, sort = ns.Finder:Find({ kind = kind, text = text })
  M.last = list
  if #list == 0 then ns.Print("nothing found") return end
  ns.Print("%d found (%s, sorted by %s):", total, ns.Finder.KIND_LABEL[kind], ns.Finder.SORT_LABEL[sort] or sort)
  for i = 1, math.min(8, #list) do ns.Print("%d. %s", i, ns.Finder.Line(list[i])) end
  ns.Print("/ride journey <number> to be guided there")
end)
