-- Modules/MapPages.lua
-- Pages built around the in-window map (UI/MapView.lua), requirement 2026-11-24:
--   Map and places > Map and routes : any map, draw and share routes
--   Dungeons > Dungeon maps         : every dungeon's own map with its bosses
--                                     and your routes for it
--   Rares > Rare map                : the zone you're in with its rares
-- The routes panel on the left is shared by the first two.

local _, ns = ...
local C, UI, Theme = ns.Compat, ns.UI, ns.Theme
local P = {}
ns.MapPages = P

P.LEFT = 236
P.SURE = 4 -- seconds a "Sure?" click stays armed

function P.Open(id, after)
  local Hub = ns.Hub
  if not Hub then return end
  local f = Hub:Build()
  f:Show()
  if Hub.frame and Hub.frame.tabBar then Hub.frame.tabBar:Select(id) else Hub:ShowTab(id) end
  if after then ns.Safe("mappages:after", after) end
end

local function norm(s)
  s = tostring(s or ""):lower():gsub("^the ", "")
  return (s:gsub("[^%w]", ""))
end
P.Norm = norm

-- The dungeon's own map (inside), found by name below the entrance zone, then
-- below the continent. Cached; logged once. nil when the client has none.
P.dungeonMaps = {}
function P.DungeonMap(name, zoneMap)
  if P.dungeonMaps[name] ~= nil then return P.dungeonMaps[name] or nil end
  local want = norm(name)
  local function search(top)
    local kids = C.Call("C_Map.GetMapChildrenInfo", top, nil, true)
    if type(kids) ~= "table" then return nil end
    local loose
    for _, k in ipairs(kids) do
      local t = k.mapType
      local n = norm(k.name)
      if (t == nil or t == 4 or t == 5) and n ~= "" then
        if n == want then return k.mapID end
        if not loose and (n:find(want, 1, true) or want:find(n, 1, true)) and #n >= 5 then loose = k.mapID end
      end
    end
    return loose
  end
  local found = zoneMap and search(zoneMap)
  if not found and zoneMap then
    local info = C.Call("C_Map.GetMapInfo", zoneMap)
    local parent = type(info) == "table" and info.parentMapID
    if parent and parent > 0 then found = search(parent) end
  end
  P.dungeonMaps[name] = found or false
  ns.Log:Info("mappages", "dungeon map for %s: %s", tostring(name), tostring(found or "none found"))
  return found
end

-- floors of a multi-level map: { {mapID, name}, ... } or nil
function P.Floors(mapID)
  local group = C.Call("C_Map.GetMapGroupID", mapID)
  if not group then return nil end
  local list = C.Call("C_Map.GetMapGroupMembersInfo", group)
  if type(list) ~= "table" or #list < 2 then return nil end
  local out = {}
  for _, m in ipairs(list) do out[#out + 1] = { mapID = m.mapID, name = m.name, h = m.relativeHeightIndex or 0 } end
  table.sort(out, function(a, b) return a.h < b.h end)
  return out
end

-- ------------------------------------------------------------------ routes panel
-- A list of routes (all, or only the view's map) with the buttons that act on
-- the selected one. Returns the panel; panel:Refresh().
function P.RoutePanel(parent, view, opts)
  opts = opts or {}
  local R = ns.Routes
  local f = CreateFrame("Frame", nil, parent)
  f:SetWidth(P.LEFT)
  f:SetHeight(opts.height or 330)
  local head = UI.Text(f, "normal", "goldText")
  head:SetPoint("TOPLEFT", 2, 0)
  head:SetText(opts.title or "Your routes")
  local function selected() return view.route and R:Get(view.route) end
  local newBtn = UI:PrimaryButton(f, "New route on this map", P.LEFT, function()
    if not view.mapID then ns.Print("open a map first") return end
    local r, why = R:New(view.mapID)
    if not r then ns.Print("no new route: %s", tostring(why)) return end
    view:SetRoute(r.id)
    view:SetMode("line")
    f:Refresh()
  end)
  newBtn:SetHeight(24)
  newBtn:SetPoint("TOPLEFT", 0, -20)
  UI.Tip(newBtn, "New route", "Starts an empty route on the map shown, then draw with the tools above the map.")
  f.list = UI:ScrollList(f, {
    rows = opts.rows or 7, rowHeight = 22,
    render = function(row, r)
      local mark = r.shown and "|cff66d980on|r " or "|cff888888off|r "
      local here = view.mapID == r.mapID and "" or "  |cff888888(other map)|r"
      local from = r.from and ("  |cff888888from " .. r.from .. "|r") or ""
      local cur = view.route == r.id and "|cffffd27f> |r" or ""
      row.text:SetText(cur .. mark .. r.name .. here .. from)
    end,
    onClick = function(r)
      if r.mapID ~= view.mapID then view:SetMap(r.mapID) end
      view:SetRoute(r.id)
      f:Refresh()
    end,
  })
  f.list:SetWidth(P.LEFT)
  f.list:SetPoint("TOPLEFT", newBtn, "BOTTOMLEFT", 0, -6)
  local grid = {}
  local function btn(label, tip, fn)
    local b = UI:Button(f, label, (P.LEFT - 6) / 3, fn)
    b:SetHeight(22)
    UI.Tip(b, label, tip)
    grid[#grid + 1] = b
    return b
  end
  btn("Show / hide", "Show or hide the selected route on the world map, the minimap and here.", function()
    local r = selected() if r then R:SetShown(r.id, not r.shown) end
  end)
  btn("Rename", "Give the selected route a new name.", function()
    local r = selected() if not r then return end
    UI:TextDialog("Rename route", r.name, "paste", function(text)
      if R:Rename(r.id, text) then return true end
      return false, "type a name"
    end)
    if UI.dialog and UI.dialog.hint then UI.dialog.hint:SetText("Type the new name, then Accept.") end
  end)
  local del = btn("Delete", "Delete the selected route. Click twice.", function(self)
    local r = selected() if not r then return end
    local now = time()
    if f.armed == r.id and now - (f.armedAt or 0) <= P.SURE then
      R:Delete(r.id)
      f.armed = nil
      view:SetRoute(nil)
      self.label:SetText("Delete")
    else
      f.armed, f.armedAt = r.id, now
      self.label:SetText("Sure?")
    end
  end)
  btn("Copy", "Copy the selected route as text, to paste to a friend or keep.", function()
    local r = selected() if not r then return end
    UI:TextDialog("Route: " .. r.name, R:Export(r.id) or "", "copy")
  end)
  btn("Paste", "Add a route someone copied for you.", function()
    UI:TextDialog("Paste a route", "", "paste", function(text)
      local r, why = R:Import(text)
      if not r then return false, why end
      view:SetMap(r.mapID)
      view:SetRoute(r.id)
      f:Refresh()
      return true
    end)
  end)
  btn("Party", "Send the selected route to your party or raid (they need Outrider).", function()
    local r = selected() if not r then return end
    local ch = C.Call("IsInRaid") and "RAID" or C.Call("IsInGroup") and "PARTY"
    if not ch then ns.Print("you're not in a group") return end
    local ok, why = R:Share(r.id, ch)
    ns.Print(ok and ("route sent to your " .. ch:lower()) or ("not sent: " .. tostring(why)))
  end)
  btn("Guild", "Send the selected route to your guild (they need Outrider).", function()
    local r = selected() if not r then return end
    if not C.Call("IsInGuild") then ns.Print("you're not in a guild") return end
    local ok, why = R:Share(r.id, "GUILD")
    ns.Print(ok and "route sent to your guild" or ("not sent: " .. tostring(why)))
  end)
  for i, b in ipairs(grid) do
    local col, rowN = (i - 1) % 3, math.floor((i - 1) / 3)
    b:SetPoint("TOPLEFT", f.list, "BOTTOMLEFT", col * ((P.LEFT - 6) / 3 + 3), -6 - rowN * 26)
  end
  f.note = UI.Text(f, "small", "muted")
  f.note:SetPoint("TOPLEFT", f.list, "BOTTOMLEFT", 0, -6 - 3 * 26 - 4)
  f.note:SetWidth(P.LEFT)
  if f.note.SetJustifyH then f.note:SetJustifyH("LEFT") end
  function f:Refresh()
    if not (R and R.enabled) then
      self.list:SetItems({})
      self.note:SetText("Routes are off (Settings > Modules > Map routes you draw).")
      return
    end
    local items = R:List(opts.mapOnly and view.mapID or nil)
    self.list:SetItems(items)
    if del.label and f.armed ~= view.route then del.label:SetText("Delete") end
    self.note:SetText(#items == 0 and "No routes yet. Press New route, pick Draw and drag on the map."
      or "Shown routes also appear on the world map and as dots on the minimap. Routes from friends arrive switched off.")
  end
  return f
end

-- ------------------------------------------------------------------ Map and routes
ns.Hub:AddTab("worldmap", "Map and routes", function(p)
  local view = UI:MapView(p, { draw = true })
  view:SetPoint("TOPLEFT", P.LEFT + 12, 0)
  view:SetPoint("BOTTOMRIGHT", 0, 0)
  local panel = P.RoutePanel(p, view, { rows = 12, height = 520 })
  panel:SetPoint("TOPLEFT", 0, 0)
  view.opts.onMap = function() panel:Refresh() end
  p.view, p.panel = view, panel
  function p:Refresh()
    if P.pendingMap then view:SetMap(P.pendingMap) P.pendingMap = nil
    elseif not view.mapID then view:GoHere() end
    if not view.mapID then view:SetMap(947) end -- Azeroth
    panel:Refresh()
    view:Refresh()
  end
end)

-- open the routes page on a map (world map dock, journal)
function P.DrawOn(mapID)
  P.pendingMap = mapID
  P.Open("worldmap")
end

-- ------------------------------------------------------------------ Dungeon maps
function P.DungeonList()
  local D = ns.DungeonGuide
  local out = {}
  if not (D and D.enabled and D.ByName) then return out end
  for name, d in pairs(D:ByName()) do
    local meta = ns.Data:Get("dungeon", name)
    out[#out + 1] = { name = name, zone = d.map, min = meta and meta.min or 0, max = meta and meta.max or 0, d = d }
  end
  table.sort(out, function(a, b)
    if a.min ~= b.min then return a.min < b.min end
    return a.name < b.name
  end)
  return out
end

-- The dungeon to open first: one for your level, else the next one up, else
-- the highest below. Battlegrounds (no level range, 0-0) only as a last resort.
function P.Pick(items, level)
  local best, below
  for _, e in ipairs(items) do
    if (e.max or 0) > 0 then
      if level >= e.min and level <= e.max then return e.name end
      if e.min > level and (not best or e.min < best.min) then best = e end
      if e.max < level and (not below or e.max > below.max) then below = e end
    end
  end
  local e = best or below or items[1]
  return e and e.name
end

ns.Hub:AddTab("dungeonmap", "Dungeon maps", function(p)
  local view = UI:MapView(p, { draw = true })
  view:SetPoint("TOPLEFT", P.LEFT + 12, 0)
  view:SetPoint("BOTTOMRIGHT", 0, 0)
  local head = UI.Text(p, "normal", "goldText")
  head:SetPoint("TOPLEFT", 2, 0)
  head:SetText("Dungeons")
  local level = C.Call("UnitLevel", "player") or 1
  local list = UI:ScrollList(p, {
    rows = 9, rowHeight = 22,
    render = function(row, e)
      local col = (level >= e.min and level <= e.max) and "|cff66d980" or level < e.min and "|cff888888" or "|cffaaaaaa"
      local cur = P.dungeon == e.name and "|cffffd27f> |r" or ""
      row.text:SetText(string.format("%s%s  %s%d-%d|r", cur, e.name, col, e.min, e.max))
    end,
    onClick = function(e) P.ShowDungeon(p, e.name) end,
  })
  list:SetWidth(P.LEFT)
  list:SetPoint("TOPLEFT", 0, -20)
  p.list = list
  local floorBtn = UI:Button(p, "Next floor", P.LEFT, function()
    local floors = view.mapID and P.Floors(view.mapID)
    if not floors then return end
    for i, fl in ipairs(floors) do
      if fl.mapID == view.mapID then view:SetMap(floors[i % #floors + 1].mapID) break end
    end
  end)
  floorBtn:SetHeight(22)
  floorBtn:SetPoint("TOPLEFT", list, "BOTTOMLEFT", 0, -6)
  UI.Tip(floorBtn, "Floors", "Step through the dungeon's levels when it has more than one.")
  p.floorBtn = floorBtn
  local panel = P.RoutePanel(p, view, { rows = 5, mapOnly = true, title = "Routes for this map" })
  panel:SetPoint("TOPLEFT", floorBtn, "BOTTOMLEFT", 0, -10)
  p.view, p.panel = view, panel
  view.opts.onMap = function(mapID)
    panel:Refresh()
    local floors = P.Floors(mapID)
    floorBtn:SetShown(floors and true or false)
    if floors then
      for _, fl in ipairs(floors) do
        if fl.mapID == mapID then floorBtn.label:SetText("Floor: " .. tostring(fl.name) .. "  (next)") end
      end
    end
  end
  floorBtn:Hide()
  function p:Refresh()
    local items = P.DungeonList()
    list:SetItems(items)
    if not P.dungeon then
      -- the dungeon you're in, else the first one for your level
      local here = C.PlayerPosition("player")
      for _, e in ipairs(items) do
        local m = P.DungeonMap(e.name, e.zone)
        if m and m == here then P.dungeon = e.name break end
      end
      P.dungeon = P.dungeon or P.Pick(items, level)
      if P.dungeon then P.ShowDungeon(p, P.dungeon) return end
    end
    if #items == 0 then view.empty:SetText("The dungeon data pack (Outrider_Data_Dungeons) isn't installed.") view.empty:Show() end
    panel:Refresh()
    view:Refresh()
  end
end)

function P.ShowDungeon(p, name)
  P.dungeon = name
  local e
  for _, x in ipairs(P.DungeonList()) do if x.name == name then e = x break end end
  if not e then return end
  local m = P.DungeonMap(e.name, e.zone)
  if m then
    p.view:SetMap(m)
  elseif e.zone then
    p.view:SetMap(e.zone)
    ns.Print("no inside map for %s in this client: showing its zone", name)
  end
  p.list:SetItems(P.DungeonList())
  p.panel:Refresh()
end

-- ------------------------------------------------------------------ Rare map
ns.Hub:AddTab("raremap", "Rare map", function(p)
  local view = UI:MapView(p, { kinds = { rare = true, routemark = true } })
  view:SetPoint("TOPLEFT", 0, 0)
  view:SetPoint("BOTTOMRIGHT", 0, 0)
  p.view = view
  function p:Refresh()
    view:GoHere()
    if not view.mapID then view:SetMap(947) end
    view:Refresh()
  end
end)
