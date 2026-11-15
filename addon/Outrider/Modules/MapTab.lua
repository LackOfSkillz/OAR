-- Modules/MapTab.lua  (P3-09)
-- Hub tab "Map": which pin kinds show (per character), whether Discovery and
-- place recording are on, counts of what is stored, and a two-click "clear"
-- for recorded places and NPCs. All of it stays on this PC (hard rule 10).

local _, ns = ...
local UI = ns.UI

local KINDS = { "rare", "vendor", "repair", "trainer", "flight_master", "spirit_healer", "bank", "auction",
  "stable_master", "mailbox", "innkeeper", "guild_master", "tabard", "quest_giver", "herb", "ore", "fish", "guildmate", "trail", "ride" }

local T = { name = "maptab" }
ns.MapTab = T

function T:ClearAll()
  local g = ns.db.global
  local n = 0
  for _ in pairs(g.pois or {}) do n = n + 1 end
  g.pois = {}
  if ns.POI then ns.POI.db = g.pois end
  if g.discovered then g.discovered.npcs, g.discovered.recent = {}, {} end
  local D = ns.Modules:Get("Discovery")
  if D and D.db then D.db = g.discovered end
  ns.Log:Info("maptab", "cleared %d places and all recorded NPCs", n)
  if ns.MapPins then ns.MapPins:Invalidate() end
  if ns.MapPins and ns.MapPins.map and ns.MapPins.map:IsShown() then ns.MapPins:Refresh() end
  return n
end

ns.Hub:AddTab("map", "Map", function(p)
  local head = UI.Display(p, "side", "goldText")
  head:SetPoint("TOPLEFT", 0, 0)
  head:SetText("Pins shown on the world map and minimap")
  p.checks = {}
  for i, kind in ipairs(KINDS) do
    local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
    local c = UI:Check(p, ns.MapPins.LABELS[kind] or kind,
      function() return not ns.MapPins:Settings().hidden[kind] end,
      function(on)
        ns.MapPins:Settings().hidden[kind] = (not on) or nil
        ns.MapPins:Invalidate()
        ns.Modules:Get("MinimapPins"):Update()
      end)
    c:SetPoint("TOPLEFT", col * 260, -24 - row * 22)
    c:SetWidth(250)
    p.checks[#p.checks + 1] = c
  end
  local y = -24 - math.ceil(#KINDS / 2) * 22 - 14
  local head2 = UI.Display(p, "side", "goldText")
  head2:SetPoint("TOPLEFT", 0, y)
  head2:SetText("Recording (account-wide, never leaves this PC)")
  p.disc = UI:Check(p, "Record NPCs I meet (Discovery)",
    function() return ns.Modules:Get("Discovery").enabled end,
    function(on) ns.Modules:SetEnabled("Discovery", on) end)
  p.disc:SetPoint("TOPLEFT", 0, y - 24)
  p.poi = UI:Check(p, "Record places I use (vendors, trainers...)",
    function() return ns.Modules:Get("POICapture").enabled end,
    function(on) ns.Modules:SetEnabled("POICapture", on) end)
  p.poi:SetPoint("TOPLEFT", 0, y - 46)
  p.counts = UI.Text(p, "small", "muted")
  p.counts:SetPoint("TOPLEFT", 0, y - 76)
  p.clear = UI:Button(p, "Clear recorded data", 170, function()
    if p.armed then
      p.armed = false
      local n = T:ClearAll()
      ns.Print("cleared %d places and all recorded NPCs", n)
      p:Refresh()
    else
      p.armed = true
      p.clear.label:SetText("Click again to clear")
      ns.Timer.After(4, function() p.armed = false p.clear.label:SetText("Clear recorded data") end, "maptab:disarm")
    end
  end)
  p.clear:SetPoint("TOPLEFT", 0, y - 100)
  -- legend: group colours
  local lx = 0
  for _, g in ipairs({ "merchant", "trainer", "service", "quest", "rare", "gather" }) do
    local c = ns.MapPins.GROUP_COLOR[g]
    local sw = p:CreateTexture(nil, "ARTWORK")
    sw:SetSize(12, 12)
    sw:SetPoint("TOPLEFT", lx, y - 134)
    sw:SetColorTexture(c[1], c[2], c[3], 1)
    local t = UI.Text(p, "small", "text")
    t:SetPoint("LEFT", sw, "RIGHT", 4, 0)
    t:SetText(ns.MapPins.GROUP_LABEL[g])
    lx = lx + 92
  end
  function p:Refresh()
    for _, c in ipairs(self.checks) do c:Refresh() end
    self.disc:Refresh()
    self.poi:Refresh()
    local g = ns.db.global
    local places, npcs = 0, 0
    for _ in pairs(g.pois or {}) do places = places + 1 end
    for _ in pairs(g.discovered and g.discovered.npcs or {}) do npcs = npcs + 1 end
    self.counts:SetText(string.format("%d places and %d NPCs recorded", places, npcs))
  end
end, 45)
