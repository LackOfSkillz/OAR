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

ns.Hub:AddTab("rares", "Rares", function(p)
  p.scope = UI:Dropdown(p, 150, { { "zone", "This zone" }, { "all", "All zones" } },
    function() return R.scope end, function(v) R.scope = v p:Refresh() end)
  p.scope:SetPoint("TOPLEFT", 0, 0)
  p.layer = UI.Text(p, "small", "muted")
  p.layer:SetPoint("LEFT", p.scope, "RIGHT", 12, 0)
  p.empty = UI.Text(p, "normal", "muted")
  p.empty:SetPoint("TOPLEFT", 0, -40)
  p.empty:SetText("No rares known here yet. Mouse over or target one and it appears.")
  p.list = UI:ScrollList(p, {
    rows = 12, rowHeight = 28,
    build = function(row)
      row.watch = UI:Button(row, "Watch", 80)
      row.watch:SetHeight(20)
      row.watch:SetPoint("RIGHT", -4, 0)
      row.text:SetPoint("RIGHT", row.watch, "LEFT", -6, 0)
    end,
    render = function(row, r)
      local layer = ns.Layers.current
      local last = ns.Sightings:Last(r.npcID)
      local where = last and last.layer and (" | last on " .. ns.Layers.Label(last.layer)) or ""
      row.text:SetText(string.format("%s  |  %s%s", r.name, ns.Sightings:Describe(r.npcID, layer), where))
      local watched = scan():IsWatched(r.npcID, r.name)
      row.watch.label:SetText(watched and "Watching" or "Watch")
      row.watch:SetScript("OnClick", function()
        scan():Watch(r.npcID, not watched)
        p:Refresh()
      end)
    end,
  })
  p.list:SetPoint("TOPLEFT", 0, -30)
  p.list:SetPoint("RIGHT", 0, 0)
  function p:Refresh()
    local _, conf, label = ns.Layers:Current()
    self.layer:SetText(ns.Layers.current and string.format("You are on layer %s (%.0f%%)", label, conf * 100) or "Layer not known yet")
    local rows = R:Rows()
    self.list:SetItems(rows)
    self.empty:SetShown(#rows == 0)
    self.scope:Refresh()
  end
end, 40)

-- Refresh the tab live when something new is seen.
ns.Events:On("OTR_SIGHTING_ADDED", R, function() ns.Hub:Refresh() end)
