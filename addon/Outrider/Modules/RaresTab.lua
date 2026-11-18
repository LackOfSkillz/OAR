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
  alive = { "ALIVE", "bad" }, open = { "WINDOW OPEN", "warn" }, waiting = { "WAITING", "muted" },
  dead = { "DEAD", "muted" }, passed = { "WINDOW PASSED", "warn" }, unknown = { "UNKNOWN", "muted" },
}

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
      row.star = UI:Button(row, "", 30)
      row.star:SetHeight(26)
      row.star:SetPoint("RIGHT", -10, 0)
      -- the game's raid-target star (fonts may lack a star character)
      row.star.icon = row.star:CreateTexture(nil, "OVERLAY")
      row.star.icon:SetSize(16, 16)
      row.star.icon:SetPoint("CENTER")
      row.star.icon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_1")
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
      row.sub:SetText(ns.TitleCase(desc:sub(1, 1)) .. desc:sub(2) .. where)
      local watched = scan():IsWatched(r.npcID, r.name)
      row.star.watched = watched
      if row.star.icon.SetDesaturated then row.star.icon:SetDesaturated(not watched) end
      row.star.icon:SetAlpha(watched and 1 or 0.45)
      ns.UI.Tip(row.star, watched and "Watching" or "Watch", watched and "Click to stop watching this rare." or "Click to be alerted when it shows up.")
      row.star:SetScript("OnClick", function() scan():Watch(r.npcID, not watched) p:Refresh() end)
      local spot = last and last.mapID and last.x and last
      row.go:SetShown(spot and true or false)
      row.go:SetScript("OnClick", function()
        if spot and ns.Waypoints then ns.Waypoints:Set(spot.mapID, spot.x, spot.y, r.name) end
      end)
    end,
  })
  p.list:SetPoint("TOPLEFT", 0, -110)
  p.list:SetPoint("RIGHT", 0, 0)
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
    self.scope:Refresh()
  end
end, 40)

-- Refresh the tab live when something new is seen.
ns.Events:On("OTR_SIGHTING_ADDED", R, function() ns.Hub:Refresh() end)
