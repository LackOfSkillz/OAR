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
      out[#out + 1] = { kind = "gear", name = c.name, pct = c.pct, target = p, seconds = t, mapID = w.mapID,
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
        out[#out + 1] = { kind = "xp", name = q.name, level = q.level, xp = xp, target = p, seconds = t, mapID = q.mapID,
          giver = q.giver, rate = xp / ((t + M.QUEST_TIME) / 60), diff = q.diff }
      end
    end
  end
  table.sort(out, function(a, b) return a.rate > b.rate end)
  while #out > M.MAX do table.remove(out) end
  return out
end

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
  self:Info("journey to %s (%s), about %s", tostring(entry.name), zone(entry.target.mapID), ns.Travel.Minutes(entry.seconds))
  return self:Step("start")
end

function M:Stop(why)
  if not self.goal then return end
  self:Info("journey stopped (%s)", tostring(why))
  self.goal = nil
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
  if not route then say(self, whyNot) return nil end
  local first = route.steps[1]
  if #route.steps == 1 then
    local here = ns.Travel.Here()
    local dx = here and (here.wx - goal.target.wx) or 1e9
    local dy = here and (here.wy - goal.target.wy) or 1e9
    if math.sqrt(dx * dx + dy * dy) < 25 then
      say(self, "you're there: " .. tostring(goal.name))
      self.goal = nil
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

function M:OnEnable()
  local function again(why) return function(mod) if mod.goal then ns.Throttle("journey", 2, function() mod:Step(why) end) end end end
  self:On("OTR_WAYPOINT_CLEARED", function(mod, _, w, why)
    if mod.goal and why == "arrived" and w and w.opts and w.opts.journey then mod:Step("arrived") end
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
  p.mode = "gear"
  p.head = UI.Text(p, "small", "muted")
  p.head:SetPoint("TOPLEFT", 0, 0)
  p.gear = UI:Button(p, "Gear", 80, function() p.mode = "gear" p:Refresh() end)
  p.gear:SetPoint("TOPLEFT", 0, -18)
  p.xp = UI:Button(p, "XP quests", 100, function() p.mode = "xp" p:Refresh() end)
  p.xp:SetPoint("LEFT", p.gear, "RIGHT", 6, 0)
  p.list = UI:ScrollList(p, {
    rows = 9, rowHeight = 22,
    render = function(row, e) row.text:SetText(M.Line(e)) end,
    onClick = function(e) p:ShowRoute(e) end,
  })
  p.list:SetPoint("TOPLEFT", p.gear, "BOTTOMLEFT", 0, -8)
  p.list:SetWidth(580)
  p.route = UI.Text(p, "small", "text")
  p.route:SetPoint("TOPLEFT", p.list, "BOTTOMLEFT", 0, -8)
  p.route:SetWidth(580)
  p.route:SetJustifyH("LEFT")
  p.go = UI:Button(p, "Guide me", 100, function() if p.current then M:Go(p.current) end end)
  p.go:SetPoint("BOTTOMLEFT", 0, 0)
  p.stop = UI:Button(p, "Stop", 80, function() M:Stop("button") end)
  p.stop:SetPoint("LEFT", p.go, "RIGHT", 6, 0)
  function p:ShowRoute(e)
    self.current = e
    local route, why = ns.Travel:Route(e.target)
    if not route then self.route:SetText(why) return end
    local lines = { string.format("%s: about %s", tostring(e.name), ns.Travel.Minutes(route.seconds)) }
    for i, s in ipairs(route.steps) do lines[#lines + 1] = string.format("%d. %s", i, s.text) end
    self.route:SetText(table.concat(lines, "\n"))
  end
  function p:Refresh()
    local list = self.mode == "gear" and M:GearList() or M:XPList()
    self.head:SetText(self.mode == "gear" and "Gear upgrades anywhere, biggest first, then the shortest trip. Click one for its route."
      or "Quests you can pick up now, most XP per minute first (estimates). Click one for its route.")
    self.list:SetItems(list)
    self.route:SetText(#list == 0 and "Nothing found yet (item data may still be loading: open this tab again in a moment)." or "")
  end
end, 45)

ns.AddCommand("journey", "[gear|xp|<number>|stop]  best gear or XP quests anywhere; a number starts the guide", function(arg)
  arg = (arg or ""):lower()
  if arg == "stop" then M:Stop("command") ns.Print("Journey stopped") return end
  local n = tonumber(arg)
  if n then
    local e = M.last and M.last[n]
    if not e then ns.Print("list first: /ride journey gear or /ride journey xp") return end
    M:Go(e)
    return
  end
  local list = arg == "xp" and M:XPList() or M:GearList()
  M.last = list
  if #list == 0 then ns.Print("nothing found yet (item data may still be loading)") return end
  for i = 1, math.min(8, #list) do ns.Print("%d. %s", i, M.Line(list[i])) end
  ns.Print("/ride journey <number> to be guided there")
end)
