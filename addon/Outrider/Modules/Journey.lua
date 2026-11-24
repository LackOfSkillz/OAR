-- Modules/Journey.lua
-- Finds the best gear quests and the best XP quests anywhere, then guides the
-- player there (requirement 2026-11-13). Hub tab Journey (owner's choice) with two
-- lists, plus /ride journey [gear|xp|<number>|stop]:
--   Gear  upgrades from the gear pack on every map (Nearby with world = true),
--         best gain first, then the quicker trip
--   XP    quests you can pick up now on every map (NPC pack), ranked by
--         estimated XP per minute: XP / (trip + 5 minutes to do it)
--         (XP per minute chosen as the metric). XP is an estimate from the quest's
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
        detail = ns.Nearby.Describe(c), note = w.note, source = c.kind }
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
        out[#out + 1] = { kind = "xp", name = q.name, level = q.level, questID = q.questID or q.id,
          faction = q.faction, preAll = q.preAll, preAny = q.preAny,
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
  -- Already at the end of the walk to a dock or flight master (bug
  -- 2026-11-15, Menethil: the arrow was "arrived", set again and cleared
  -- once a second): the step now is the ride, which is the player's to take, so
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
-- Bug 2026-11-13: hovering the map marker only said "Map Pin Sharing".
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
    if goal.sub and goal.sub ~= "" then out[#out + 1] = { tostring(goal.sub):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""), "muted" } end
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
  out[#out + 1] = { "Stop the guide on Outrider's Find page.", "muted" }
  return out
end

-- The game's waypoint marker on the minimap (the one Outrider sets with
-- C_Map.SetUserWaypoint) only says "Map Pin" (reported 2026-11-22: the tooltip
-- gave no other detail). The minimap draws it itself, so there is no pin frame to
-- hook: when the tooltip opens over the minimap and its first line names a
-- pin while Outrider has a waypoint, Outrider adds what it is and why.
function M.MinimapTipLines(owner, firstLine)
  local mm = rawget(_G, "Minimap")
  if not (M.enabled and ns.Waypoints and ns.Waypoints.current) then return nil end
  if not (owner and mm and (owner == mm or (owner.GetParent and owner:GetParent() == mm))) then return nil end
  if type(firstLine) ~= "string" or not firstLine:lower():find("pin", 1, true) then return nil end
  return M:PinLines()
end

function M:HookMinimapTip()
  local tip = rawget(_G, "GameTooltip")
  if M.minimapTipHooked or not (tip and tip.HookScript) then return end
  M.minimapTipHooked = true
  tip:HookScript("OnShow", function(t)
    if t.outriderAdding then return end
    local ok, owner = pcall(t.GetOwner, t)
    local left = rawget(_G, "GameTooltipTextLeft1")
    local first = left and left.GetText and C.Readable(left:GetText())
    local lines = ok and M.MinimapTipLines(owner, first)
    if not lines then return end
    if not M.minimapTipLogged then M.minimapTipLogged = true M:Info("minimap waypoint tooltip: '%s' gets Outrider's lines", tostring(first)) end
    t.outriderAdding = true
    for _, l in ipairs(lines) do
      local r, g, b = ns.Theme:Color(l[2])
      t:AddLine(l[1], r, g, b, true)
    end
    t:Show()
    t.outriderAdding = false
  end)
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
  self:On("OTR_WAYPOINT_SET", function(mod) mod:HookPins() mod:HookMinimapTip() end)
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
  -- a journey to a rare ends when it is tamed or killed (bug 2026-11-15:
  -- after taming The Rake the guide kept pointing back to Mulgore)
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
  return "Find page: best gear and XP quests anywhere, with a route"
end

-- -------------------------------------------------------------------- tab
-- ------------------------------------------------------------------ page
-- Journey, rebuilt so anyone gets it at a glance (requirement 2026-11-20: the
-- old page was unclear; an 8th-grade reader should see at a glance what the
-- page is for and how to use it):
--   * three steps across the top: 1 pick a place, 2 press Go, 3 follow the arrow
--   * "Best picks for you": the best quest for XP, the best gear upgrade and
--     the best zone for your level, each with Go
--   * left: what to look for, in plain words, with icons
--   * middle: the results, each row with an icon, a plain line and how far
--   * right: "Your trip": the steps of the route and one big Go / Stop

-- What each kind is called and what it's for, in plain words.
M.KINDS_PLAIN = {
  { "all", "Everything", "INV_Misc_Map_01", "All of it, nearest first" },
  { "quest", "Quests", "INV_Misc_Note_01", "Quests you can pick up now, most XP for your time first" },
  { "zone", "Zones to level in", "INV_Misc_Map02", "Places with lots of quests for your level" },
  { "gear", "Gear upgrades", "INV_Chest_Chain_05", "Better gear you can get, biggest upgrade first" },
  { "rare", "Rare monsters", "Ability_Hunter_MarkedForDeath", "Rare monsters with good loot" },
  { "node", "Herbs and ore", "Trade_Herbalism", "Where herbs and ore grow" },
  { "place", "Services", "INV_Misc_Bag_10", "Vendors, trainers, inns, repairs, mail" },
  { "npc", "People", "INV_Misc_GroupNeedMore", "Find a person by name" },
  { "mob", "Creatures", "Ability_Hunter_Pet_Wolf", "Monsters to fight, nearest your level first" },
  { "item", "Items", "INV_Misc_Bag_08", "Type an item's name to see where it comes from" },
  { "travel", "Flights and boats", "Ability_Mount_Gryphon_01", "Flight masters, boats and portals" },
}
M.KIND_ICON = {}
for _, k in ipairs(M.KINDS_PLAIN) do M.KIND_ICON[k[1]] = "Interface\\Icons\\" .. k[3] end
M.STEP_ICON = { walk = "Ability_Rogue_Sprint", fly = "Ability_Mount_Gryphon_01", flight = "Ability_Mount_Gryphon_01",
  boat = "INV_Misc_Fish_09", zeppelin = "INV_Misc_Bomb_04", portal = "Spell_Arcane_PortalOrgrimmar", tram = "INV_Misc_Gear_01",
  skycutter = "Ability_Mount_Gryphon_01", learned = "INV_Misc_Map_01", hearth = "INV_Misc_Rune_01" }

-- Plain words for one result: title, the line under it, how far.
function M.Plain(e)
  local title = tostring(e.name)
  if e.level then title = title .. string.format("  |cff8f96a6level %d|r", e.level) end
  local bits = {}
  if e.kind == "quest" then
    bits[#bits + 1] = tostring(e.sub or "")
    if e.xp then bits[#bits + 1] = string.format("about %d XP", e.xp) end
  elseif e.kind == "gear" then
    if e.gain then bits[#bits + 1] = string.format("|cff7fff7f%d%% better|r than what you wear", math.floor(e.gain + 0.5)) end
    if e.sub and e.sub ~= "" then bits[#bits + 1] = tostring(e.sub) end
  elseif e.sub and e.sub ~= "" then
    bits[#bits + 1] = tostring(e.sub)
  end
  bits[#bits + 1] = e.zone or ns.Travel.ZoneName(e.mapID)
  local far = e.seconds and (ns.Travel.Minutes(e.seconds) .. " away") or "no known way yet"
  return title, table.concat(bits, "  ·  "), far
end

-- The best pick of each: { {label, art, entry} } (cached a little: Find works out every trip)
M.PICKS = {
  { "quest", "xpmin", "Best quest for XP", "kind_quest" },
  { "gear", "gain", "Best gear upgrade", "kind_gear" },
  { "zone", "xp", "Best zone for your level", "kind_zone" },
}
function M:Picks()
  local now = GetTime and GetTime() or 0
  if self.picks and now - (self.picksAt or 0) < 30 then return self.picks end
  local out = {}
  for _, pk in ipairs(M.PICKS) do
    local list = ns.Finder:Find({ kind = pk[1], sort = pk[2] })
    out[#out + 1] = { label = pk[3], art = pk[4], kind = pk[1], entry = list[1] }
  end
  self.picks, self.picksAt = out, now
  return out
end

ns.Hub:AddTab("journey", "Journey", function(p)
  local F = ns.Finder
  local Theme = ns.Theme
  p.kind, p.text = "all", ""

  -- 1, 2, 3 across the top
  p.steps = {}
  local STEPS = { "Pick a place, quest or item below", "Press Go", "Follow the gold arrow on your screen" }
  for i, txt in ipairs(STEPS) do
    local s = CreateFrame("Frame", nil, p)
    s:SetSize(300, 30)
    s:SetPoint("TOPLEFT", (i - 1) * 300, 0)
    s.num = s:CreateTexture(nil, "ARTWORK")
    s.num:SetSize(24, 24)
    s.num:SetPoint("LEFT", 0, 0)
    s.num:SetColorTexture(Theme:Color("gold"))
    s.n = UI.Text(s, "large", "onGold")
    s.n:SetPoint("CENTER", s.num, "CENTER", 0, 0)
    s.n:SetText(tostring(i))
    s.text = UI.Text(s, "normal", "text")
    s.text:SetPoint("LEFT", s.num, "RIGHT", 10, 0)
    s.text:SetText(txt)
    p.steps[i] = s
  end

  -- best picks: three picture cards
  p.picksHead = UI.Display(p, "side", "goldText")
  p.picksHead:SetPoint("TOPLEFT", 0, -44)
  p.picksHead:SetText("Best picks for you right now")
  p.pickCards = {}
  for i = 1, #M.PICKS do
    local c = UI:Card(p, true)
    c:SetHeight(92)
    c.art = c:CreateTexture(nil, "ARTWORK")
    c.art:SetSize(72, 72)
    c.art:SetPoint("LEFT", 12, 0)
    c.label = UI.Text(c, "small", "gold")
    c.label:SetPoint("TOPLEFT", c.art, "TOPRIGHT", 12, -2)
    c.title = UI.Text(c, "large", "text")
    c.title:SetPoint("TOPLEFT", c.label, "BOTTOMLEFT", 0, -4)
    c.title:SetPoint("RIGHT", c, "RIGHT", -84, 0)
    c.title:SetJustifyH("LEFT")
    if c.title.SetWordWrap then c.title:SetWordWrap(false) end
    c.sub = UI.Text(c, "small", "muted")
    c.sub:SetPoint("TOPLEFT", c.title, "BOTTOMLEFT", 0, -4)
    c.sub:SetPoint("RIGHT", c, "RIGHT", -84, 0)
    c.sub:SetJustifyH("LEFT")
    if c.sub.SetWordWrap then c.sub:SetWordWrap(false) end
    c.far = UI.Text(c, "small", "goldText")
    c.far:SetPoint("TOPLEFT", c.sub, "BOTTOMLEFT", 0, -4)
    c.go = UI:Button(c, "Go", 64, function() if c.entry then p:Select(c.entry) p:GoNow() end end)
    c.go:SetHeight(30)
    c.go:SetPoint("RIGHT", -12, 0)
    UI.SetPrimary(c.go, true)
    UI.Tip(c.go, "Go", "Shows the trip on the right and puts the gold arrow up. Then just follow it.")
    p.pickCards[i] = c
  end

  -- left: what to look for
  local TOP = -152
  p.kindsHead = UI.Text(p, "small", "gold")
  p.kindsHead:SetPoint("TOPLEFT", 0, TOP)
  p.kindsHead:SetText("WHAT ARE YOU LOOKING FOR?")
  p.kindBtns = {}
  for i, k in ipairs(M.KINDS_PLAIN) do
    local b = CreateFrame("Button", nil, p, Theme:BackdropTemplate())
    b:SetSize(196, 30)
    b:SetPoint("TOPLEFT", 0, TOP - 18 - (i - 1) * 32)
    b.bar = b:CreateTexture(nil, "ARTWORK")
    b.bar:SetPoint("TOPLEFT") b.bar:SetPoint("BOTTOMLEFT") b.bar:SetWidth(3)
    b.bar:SetColorTexture(Theme:Color("gold"))
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(20, 20)
    b.icon:SetPoint("LEFT", 10, 0)
    b.icon:SetTexture(M.KIND_ICON[k[1]])
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    b.label = UI.Text(b, "normal", "body")
    b.label:SetPoint("LEFT", b.icon, "RIGHT", 8, 0)
    b.label:SetText(k[2])
    b:SetScript("OnClick", function() p.kind, p.sort = k[1], nil p:Refresh() end)
    UI.Tip(b, k[2], k[4])
    p.kindBtns[k[1]] = b
  end

  -- right: your trip
  local trip = UI:Card(p, true)
  trip:SetWidth(330)
  trip:SetPoint("TOPRIGHT", p, "TOPRIGHT", -4, TOP)
  trip:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -4, 4)
  p.trip = trip
  trip.head = UI.Text(trip, "small", "gold")
  trip.head:SetPoint("TOPLEFT", 16, -12)
  trip.head:SetText("YOUR TRIP")
  trip.title = UI.Display(trip, "side", "text")
  trip.title:SetPoint("TOPLEFT", trip.head, "BOTTOMLEFT", 0, -6)
  trip.title:SetPoint("RIGHT", trip, "RIGHT", -14, 0)
  trip.title:SetJustifyH("LEFT")
  trip.sub = UI.Text(trip, "small", "muted")
  trip.sub:SetPoint("TOPLEFT", trip.title, "BOTTOMLEFT", 0, -6)
  trip.sub:SetPoint("RIGHT", trip, "RIGHT", -14, 0)
  trip.sub:SetJustifyH("LEFT")
  trip.pic = trip:CreateTexture(nil, "ARTWORK")
  trip.pic:SetSize(256, 128)
  trip.pic:SetPoint("TOP", trip, "TOP", 0, -90)
  trip.stepRows = {}
  for i = 1, 6 do
    local r = CreateFrame("Frame", nil, trip)
    r:SetSize(298, 40)
    r:SetPoint("TOPLEFT", 16, -96 - (i - 1) * 46)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(28, 28)
    r.icon:SetPoint("LEFT", 0, 0)
    r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    r.num = UI.Text(r, "small", "gold")
    r.num:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 10, -1)
    r.text = UI.Text(r, "normal", "text")
    r.text:SetPoint("TOPLEFT", r.num, "BOTTOMLEFT", 0, -2)
    r.text:SetWidth(250)
    r.text:SetJustifyH("LEFT")
    r:Hide()
    trip.stepRows[i] = r
  end
  trip.go = UI:Button(trip, "Go", 140, function() p:GoNow() end)
  trip.go:SetHeight(34)
  trip.go:SetPoint("BOTTOMLEFT", 16, 16)
  UI.SetPrimary(trip.go, true)
  UI.Tip(trip.go, "Go", "Puts the gold arrow and a map marker up for the first step. When you finish a step, the next one comes by itself.")
  trip.stop = UI:Button(trip, "Stop", 100, function() M:Stop("button") p:Refresh() end)
  trip.stop:SetHeight(34)
  trip.stop:SetPoint("LEFT", trip.go, "RIGHT", 8, 0)
  UI.Tip(trip.stop, "Stop", "Takes the arrow and marker away.")
  -- the old names (Guide me again)
  p.go, p.stop = trip.go, trip.stop

  -- middle: search and results
  p.search = UI:SearchBox(p, 300, "Type a name: a quest, item, person or place", function(t) p.text = t p:Refresh() end)
  p.search:SetPoint("TOPLEFT", 212, TOP - 2)
  p.sortBtn = UI:Button(p, "Sort: nearest", 150, function()
    local cur, nxt = p.sort or F.DEFAULT_SORT[p.kind], 1
    for i, s in ipairs(F.SORTS) do if s == cur then nxt = i % #F.SORTS + 1 end end
    p.sort = F.SORTS[nxt]
    p:Refresh()
  end)
  p.sortBtn:SetPoint("LEFT", p.search, "RIGHT", 8, 0)
  UI.Tip(p.sortBtn, "Sort", "Changes the order: nearest, most XP for your time, most XP, best gear, closest to your level, name or zone.")
  p.count = UI.Text(p, "small", "muted")
  p.count:SetPoint("TOPLEFT", p.search, "BOTTOMLEFT", 2, -6)
  p.list = UI:ScrollList(p, {
    rows = 12, rowHeight = 40,
    build = function(row)
      row.text:ClearAllPoints()
      row.icon = row:CreateTexture(nil, "ARTWORK")
      row.icon:SetSize(28, 28)
      row.icon:SetPoint("LEFT", 6, 0)
      row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
      row.text:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 10, -1)
      row.text:SetPoint("RIGHT", row, "RIGHT", -110, 0)
      row.sub = UI.Text(row, "small", "muted")
      row.sub:SetPoint("TOPLEFT", row.text, "BOTTOMLEFT", 0, -3)
      row.sub:SetPoint("RIGHT", row, "RIGHT", -110, 0)
      row.sub:SetJustifyH("LEFT")
      if row.sub.SetWordWrap then row.sub:SetWordWrap(false) end
      row.far = UI.Text(row, "small", "goldText")
      row.far:SetPoint("RIGHT", row, "RIGHT", -10, 0)
      row.far:SetJustifyH("RIGHT")
    end,
    render = function(row, e)
      local title, sub, far = M.Plain(e)
      row.icon:SetTexture(M.KIND_ICON[e.kind] or M.KIND_ICON.all)
      row.text:SetText(title)
      row.sub:SetText(sub)
      row.far:SetText(far)
    end,
    onClick = function(e) p:Select(e) end,
  })
  p.list:SetPoint("TOPLEFT", p.count, "BOTTOMLEFT", -2, -6)
  p.list:SetPoint("RIGHT", trip, "LEFT", -12, 0)
  p.hint = UI.Text(p, "small", "muted")
  p.hint:SetPoint("TOPLEFT", p.list, "BOTTOMLEFT", 2, -6)
  p.hint:SetText("Click a line to see the trip on the right, then press Go. 'Seen' means you met it; community data is unchecked.")
  -- the old name kept for tests and other pages
  p.route = trip.sub

  function p:Select(e)
    self.current = e
    self:ShowTrip()
  end

  function p:GoNow()
    local e = self.current
    if e and e.target then M:Go(e) end
    self:ShowTrip()
  end

  -- The right card: the trip you're on, the one you picked, or what to do.
  function p:ShowTrip()
    local e = self.current
    local going = M.goal
    for _, r in ipairs(trip.stepRows) do r:Hide() end
    trip.stop:SetShown(going ~= nil)
    if not e and going then e = going end
    if not e then
      trip.title:SetText("Pick something")
      trip.sub:SetText("Choose a best pick above or a line in the list. Its trip shows here, step by step.")
      local pic = ns.Art and (ns.Art:Path("journey_empty") or ns.Art:Path("empty_search"))
      trip.pic:SetShown(pic ~= nil)
      if pic then trip.pic:SetTexture(pic) end
      trip.go:Hide()
      return
    end
    trip.pic:Hide()
    local onIt = going and going.name == e.name
    trip.title:SetText(tostring(e.name))
    trip.go:Show()
    trip.go.label:SetText(onIt and "Point again" or "Go")
    if not e.target then trip.sub:SetText("Outrider doesn't know where this is.") trip.go:Hide() return end
    local route, why = ns.Travel:Route(e.target)
    if not route then trip.sub:SetText(tostring(why)) return end
    trip.sub:SetText(string.format("%s%s, about %s, %d step%s", onIt and "|cff7fff7fYou're on your way.|r  " or "",
      ns.Travel.ZoneName(e.mapID), ns.Travel.Minutes(route.seconds), #route.steps, #route.steps == 1 and "" or "s"))
    for i, st in ipairs(route.steps) do
      local r = trip.stepRows[i]
      if r then
        r.icon:SetTexture("Interface\\Icons\\" .. (M.STEP_ICON[st.kind] or "INV_Misc_Map_01"))
        r.num:SetText("STEP " .. i)
        r.text:SetText(st.text)
        r:Show()
      end
    end
  end

  function p:Refresh()
    -- a search typed in the hub's top bar lands here
    local pending = ns.Hub.pendingSearch
    if pending then
      ns.Hub.pendingSearch = nil
      self.kind, self.sort, self.text = "all", nil, pending
      self.search:SetText(pending)
    end
    -- best picks, three across the middle and left
    local W = (self.GetWidth and self:GetWidth()) or 1000
    if not W or W < 600 then W = 1000 end
    local cw = math.floor((W - 16) / 3)
    for i, pk in ipairs(M:Picks()) do
      local c = self.pickCards[i]
      c:ClearAllPoints()
      c:SetPoint("TOPLEFT", self, "TOPLEFT", (i - 1) * (cw + 8), -66)
      c:SetWidth(cw)
      c.entry = pk.entry
      c.label:SetText(pk.label:upper())
      local art = ns.Art and (ns.Art:Path(pk.art) or ns.Art:Path("kind_errand"))
      c.art:SetTexture(art or M.KIND_ICON[pk.kind])
      if pk.entry then
        local title, sub, far = M.Plain(pk.entry)
        c.title:SetText(title) c.sub:SetText(sub) c.far:SetText(far)
        c.go:Show()
      else
        c.title:SetText("Nothing yet")
        c.sub:SetText(pk.kind == "gear" and "No upgrade found that you can reach" or "Nothing found for your level here yet")
        c.far:SetText("")
        c.go:Hide()
      end
    end
    -- left menu: the chosen kind lit
    for k, b in pairs(self.kindBtns) do
      local on = k == self.kind
      Theme:ApplyPanel(b, on and "goldSoft" or "bg", on and "gold" or "bg")
      b.bar:SetShown(on)
      b.label:SetTextColor(Theme:Color(on and "goldText" or "body"))
    end
    local list, total, sort = F:Find({ kind = self.kind, text = self.text, sort = self.sort })
    self.sortBtn.label:SetText("Sort: " .. (F.SORT_LABEL[sort] or sort))
    local plain
    for _, k in ipairs(M.KINDS_PLAIN) do if k[1] == self.kind then plain = k end end
    if #list == 0 then
      self.count:SetText(self.kind == "item" and "Type at least 3 letters of an item's name above."
        or "Nothing found. Item data may still be loading: try again in a moment.")
    else
      self.count:SetText(string.format("%s: %d found%s", plain and plain[2] or "Results", total,
        total > #list and string.format(" (first %d shown)", #list) or ""))
    end
    self.list:SetItems(list)
    self:ShowTrip()
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
