-- Modules/RaresTab.lua
-- Hub tab "Rares": every rare Outrider knows (rare packs, sightings, and
-- Discovery captures classified rare/rareelite), for this zone or all zones.
-- Each row: name, state/respawn window on the current layer (Sightings),
-- last layer seen, and a Watch toggle (per-character watchlist, RareScan).

local _, ns = ...
local C = ns.Compat
local UI = ns.UI

local R = { name = "rarestab", scope = "zone" }
ns.RaresTab = R
ns.RaresTab = R

local RARE = { rare = true, rareelite = true }

-- { npcID, name, mapID } for every known rare, deduplicated.
function R:Known()
  local out, seen = {}, {}
  local function add(id, name, mapID)
    if not id or seen[id] then return end
    seen[id] = true
    out[#out + 1] = { npcID = id, name = name or ("NPC " .. id), mapID = mapID }
  end
  for _, e in ipairs(ns.Data:All("rare")) do add(e.npcID, e.name, e.mapID) end
  local g = ns.db.global
  for id, list in pairs(g.sightings or {}) do
    local last = list[#list]
    local d = g.discovered and g.discovered.npcs and g.discovered.npcs[id]
    add(id, d and d.name, last and last.mapID)
  end
  for id, d in pairs((g.discovered and g.discovered.npcs) or {}) do
    if RARE[d.classification or ""] then add(id, d.name, d.mapID) end
  end
  table.sort(out, function(a, b) return a.name < b.name end)
  return out
end

function R:Rows()
  local here = C.PlayerPosition("player")
  local rows = {}
  for _, r in ipairs(self:Known()) do
    if self.scope == "all" or r.mapID == nil or r.mapID == here then rows[#rows + 1] = r end
  end
  return rows
end

local function scan() return ns.Modules:Get("RareScan") end

-- Premium redesign (2026-11-18 tour): a stat strip, then one card-like row per
-- rare: name, a coloured status word (ALIVE / WINDOW OPEN / DEAD / UNKNOWN,
-- the same colours as its map pin), what Outrider knows in words, the layer
-- it was last on, a star to watch it and a Waypoint button.
R.STATE = {
  alive = { "ALIVE", "bad" }, open = { "MAY BE UP", "warn" }, waiting = { "NOT YET", "muted" },
  dead = { "DEAD", "muted" }, passed = { "OVERDUE", "warn" }, unknown = { "NOT SEEN LATELY", "muted" },
}
-- the same, in a sentence (requirement 2026-11-20: at a glance)
R.STATE_SAYS = {
  alive = "Someone saw it alive in the last 15 minutes. Go now!",
  open = "It could be up now: its usual respawn time has come.",
  waiting = "Killed recently: it won't be back for a while yet.",
  dead = "Killed. Outrider doesn't know its respawn time yet; it learns from the kills it sees.",
  passed = "Its usual respawn time has passed: it may be up, or someone killed it unseen.",
  unknown = "Nobody with Outrider has seen it lately.",
}

-- Everything a player wants to know about one rare, in plain words.
function R:Details(r)
  local out = {}
  local pack
  for _, e in ipairs(ns.Data:All("rare")) do if e.npcID == r.npcID then pack = e end end
  local d = ns.db.global.discovered and ns.db.global.discovered.npcs and ns.db.global.discovered.npcs[r.npcID]
  out.level = (pack and pack.level and pack.level[1]) or (d and d.level)
  out.zone = r.mapID and ns.Travel and ns.Travel.ZoneName(r.mapID) or nil
  local lines = {}
  if pack and pack.elite then lines[#lines + 1] = "Elite: much tougher than a normal monster. Bring a friend if you're low level." end
  if pack and pack.beast and pack.beast.tameable then
    lines[#lines + 1] = string.format("A %s hunters can tame.", tostring(pack.beast.family or "beast"):lower())
  end
  if pack and pack.notes then lines[#lines + 1] = tostring(pack.notes) end
  -- OI07-08: one way to say how sure (a word, with when and where from)
  if pack and ns.Confidence then lines[#lines + 1] = "How sure: " .. ns.Confidence.Text(pack) end
  local prof = ns.RareProfile and ns.RareProfile.Summary and ns.RareProfile:Summary(r.npcID)
  if prof then lines[#lines + 1] = "Seen fighting: " .. prof:gsub("^[^:]+: ", "") end
  local loot = ns.RareAlerts and ns.RareAlerts.KnownLoot and ns.RareAlerts:KnownLoot(r.npcID) or {}
  local drops = {}
  for i, row in ipairs(loot) do
    if i > 4 then break end
    local info = C.ItemInfo(row.id)
    drops[#drops + 1] = info and info.name or ("item " .. row.id)
  end
  out.drops = #drops > 0 and table.concat(drops, ", ") or nil
  out.lines = lines
  return out
end

function R:State(npcID, layer)
  local w = ns.Sightings:Window(npcID, layer)
  local st = w and w.state or "unknown"
  if st == "alive" and not (w.last and w.last.t and time() - w.last.t < 900) then st = "unknown" end
  return st, w
end

ns.Hub:AddTab("rares", "Rares", function(p)
  local Theme = ns.Theme
  p.stats = UI:StatStrip(p)
  p.stats:SetPoint("TOPLEFT", 0, 0)
  p.stats:SetPoint("RIGHT", p, "RIGHT", -4, 0)
  p.scope = UI:Dropdown(p, 150, { { "zone", "This zone" }, { "all", "All zones" } },
    function() return R.scope end, function(v) R.scope = v p:Refresh() end)
  p.scope:SetPoint("TOPLEFT", 0, -80)
  p.layer = UI.Text(p, "small", "muted")
  p.layer:SetPoint("LEFT", p.scope, "RIGHT", 12, 0)
  p.empty = UI.Text(p, "normal", "muted")
  p.empty:SetPoint("TOPLEFT", 0, -120)
  p.empty:SetText("No rares known here yet. Mouse over or target one and it appears.")
  p.list = UI:ScrollList(p, {
    rows = 11, rowHeight = 44,
    build = function(row)
      -- a word, not a bare star (requirement 2026-11-20: clear at a glance)
      row.star = UI:Button(row, "Watch", 86)
      row.star:SetHeight(26)
      row.star:SetPoint("RIGHT", -10, 0)
      row.go = UI:Button(row, "Waypoint", 96)
      row.go:SetHeight(26)
      row.go:SetPoint("RIGHT", row.star, "LEFT", -6, 0)
      row.text:ClearAllPoints()
      row.text:SetPoint("TOPLEFT", 10, -6)
      row.text:SetPoint("RIGHT", row.go, "LEFT", -10, 0)
      row.sub = UI.Text(row, "small", "muted")
      row.sub:SetPoint("TOPLEFT", row.text, "BOTTOMLEFT", 0, -3)
      row.sub:SetPoint("RIGHT", row.go, "LEFT", -10, 0)
      row.sub:SetJustifyH("LEFT")
      if row.sub.SetWordWrap then row.sub:SetWordWrap(false) end
    end,
    render = function(row, r)
      local layer = ns.Layers.current
      local st = R:State(r.npcID, layer)
      local tag = R.STATE[st] or R.STATE.unknown
      local d = ns.db.global.discovered and ns.db.global.discovered.npcs and ns.db.global.discovered.npcs[r.npcID]
      local lvl = d and d.level and ("  |cff8f96a6[" .. tostring(d.level) .. "]|r") or ""
      row.text:SetText(string.format("|cfff1d58e%s|r%s   %s%s|r", r.name, lvl, Theme:Hex(tag[2]), tag[1]))
      local last = ns.Sightings:Last(r.npcID)
      local where = last and last.layer and ("  ·  last on " .. ns.Layers.Label(last.layer)) or ""
      local desc = ns.Sightings:Describe(r.npcID, layer)
      -- an old "alive" sighting is shown as UNKNOWN: say it was alive then, not
      -- now (tour 2026-11-19: "UNKNOWN" next to "Alive, seen 1 day 18 h ago")
      if st == "unknown" then desc = desc:gsub("^[Aa]live, seen ", "last seen alive ") end
      row.sub:SetText(ns.TitleCase(desc:sub(1, 1)) .. desc:sub(2) .. where)
      local watched = scan():IsWatched(r.npcID, r.name)
      row.star.watched = watched
      row.star.label:SetText(watched and "Watching" or "Watch")
      UI.SetPrimary(row.star, watched)
      ns.UI.Tip(row.star, watched and "Watching" or "Watch", watched and "Click to stop watching this rare." or "Click to be alerted when it shows up.")
      row.star:SetScript("OnClick", function() scan():Watch(r.npcID, not watched) p:Refresh() end)
      local spot = last and last.mapID and last.x and last
      row.go:SetShown(spot and true or false)
      row.go:SetScript("OnClick", function()
        if spot and ns.Waypoints then ns.Waypoints:Set(spot.mapID, spot.x, spot.y, r.name) end
      end)
    end,
    onClick = function(r) p:Select(r) end,
  })
  -- the chosen rare, explained (requirement 2026-11-20)
  local d = UI:Card(p, true)
  d:SetWidth(330)
  d:SetPoint("TOPRIGHT", p, "TOPRIGHT", -4, -110)
  d:SetPoint("BOTTOM", p, "BOTTOM", 0, 4)
  p.detail = d
  d.pic = d:CreateTexture(nil, "ARTWORK")
  d.pic:SetSize(96, 96)
  d.pic:SetPoint("TOP", 0, -16)
  d.name = UI.Display(d, "side", "goldText")
  d.name:SetPoint("TOP", d.pic, "BOTTOM", 0, -10)
  d.name:SetWidth(300)
  d.state = UI.Text(d, "normal", "text")
  d.state:SetPoint("TOP", d.name, "BOTTOM", 0, -6)
  d.text = UI.Text(d, "normal", "body")
  d.text:SetPoint("TOPLEFT", 16, -170)
  d.text:SetPoint("RIGHT", d, "RIGHT", -16, 0)
  d.text:SetJustifyH("LEFT")
  if d.text.SetJustifyV then d.text:SetJustifyV("TOP") end
  d.go = UI:Button(d, "Waypoint", 140, function() if p.sel and p.sel.go then p.sel.go() end end)
  d.go:SetHeight(32)
  d.go:SetPoint("BOTTOMLEFT", 16, 16)
  UI.SetPrimary(d.go, true)
  UI.Tip(d.go, "Waypoint", "Points the gold arrow at where it was last seen.")
  d.watch = UI:Button(d, "Watch", 140, function()
    local r = p.sel and p.sel.r
    if r then scan():Watch(r.npcID, not scan():IsWatched(r.npcID, r.name)) p:Refresh() end
  end)
  d.watch:SetHeight(32)
  d.watch:SetPoint("LEFT", d.go, "RIGHT", 8, 0)
  p.list:SetPoint("TOPLEFT", 0, -110)
  p.list:SetPoint("RIGHT", d, "LEFT", -12, 0)

  function p:Select(r)
    local layer = ns.Layers.current
    local st = R:State(r.npcID, layer)
    local tag = R.STATE[st] or R.STATE.unknown
    local info = R:Details(r)
    local last = ns.Sightings:Last(r.npcID)
    local spot = last and last.mapID and last.x and last
    if not spot then
      for _, e in ipairs(ns.Data:All("rare")) do
        if e.npcID == r.npcID and e.spawns and e.spawns[1] then spot = { mapID = e.mapID, x = e.spawns[1].x, y = e.spawns[1].y } end
      end
    end
    self.sel = { r = r, go = spot and function() ns.Waypoints:Set(spot.mapID, spot.x, spot.y, r.name) end }
    if not (ns.Art and ns.Art:Set(d.pic, "kind_rare", "Interface\\Icons\\Ability_Hunter_MarkedForDeath")) then
      d.pic:SetTexture("Interface\\Icons\\Ability_Hunter_MarkedForDeath")
    end
    d.name:SetText(r.name)
    d.state:SetText(string.format("%s%s|r%s", Theme:Hex(tag[2]), tag[1], info.level and ("   |cff8f96a6level " .. info.level .. "|r") or ""))
    local lines = { R.STATE_SAYS[st] or "" }
    if info.zone then lines[#lines + 1] = "\n|cfff1d58eWhere|r  " .. info.zone end
    lines[#lines + 1] = "\n|cfff1d58eLast seen|r  " .. ns.Sightings:Describe(r.npcID, layer)
    if info.drops then lines[#lines + 1] = "\n|cfff1d58eDrops|r  " .. info.drops end
    for _, l in ipairs(info.lines) do lines[#lines + 1] = "\n" .. l end
    lines[#lines + 1] = "\n|cff8f96a6Layers: the server runs several copies of a zone. A rare killed on one copy can be alive on another.|r"
    d.text:SetText(table.concat(lines, "\n"))
    d.go:SetShown(spot ~= nil)
    local watched = scan():IsWatched(r.npcID, r.name)
    d.watch.label:SetText(watched and "Stop watching" or "Watch")
    UI.Tip(d.watch, "Watch", "Watched rares give a sound and a pop-up when one shows up nearby.")
  end
  function p:Refresh()
    local _, conf, label = ns.Layers:Current()
    self.layer:SetText(ns.Layers.current and string.format("You are on %s (%.0f%% sure)", label, conf * 100) or "Layer not known yet: respawn timers are per layer")
    local rows = R:Rows()
    local watched, alive, today = 0, 0, 0
    for _, r in ipairs(rows) do
      if scan():IsWatched(r.npcID, r.name) then watched = watched + 1 end
      local st = R:State(r.npcID, ns.Layers.current)
      if st == "alive" then alive = alive + 1 end
      local last = ns.Sightings:Last(r.npcID)
      if last and last.t and time() - last.t < 86400 then today = today + 1 end
    end
    self.stats:SetItems({
      { cap = R.scope == "all" and "Rares known" or "Rares in this zone", value = tostring(#rows) },
      { cap = "Alive now", value = tostring(alive), color = alive > 0 and "bad" or nil },
      { cap = "Seen in the last day", value = tostring(today) },
      { cap = "Watching", value = tostring(watched), color = watched > 0 and "gold" or nil },
    })
    self.list:SetItems(rows)
    self.empty:SetShown(#rows == 0)
    -- keep the chosen rare (or the first) explained on the right
    local pick = rows[1]
    for _, r in ipairs(rows) do if self.sel and self.sel.r and self.sel.r.npcID == r.npcID then pick = r end end
    self.detail:SetShown(pick ~= nil)
    if pick then self:Select(pick) end
    self.scope:Refresh()
  end
end, 40)

-- Refresh the tab live when something new is seen.
ns.Events:On("OTR_SIGHTING_ADDED", R, function() ns.Hub:Refresh() end)
