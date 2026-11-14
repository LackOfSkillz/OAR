-- Modules/Find.lua  (P7-10 command bar)
-- One search box (key binding "Outrider: find", or /ride find [text]).
-- Type and press Enter (or click a result). It only opens panels and sets
-- waypoints; it never casts or targets anything.
--   "rake"       rare card + waypoint to its last sighting
--   "spirit"     nearest spirit healer (any /ride near word: bank, mail...)
--   "varia"      a known NPC by name: waypoint
--   "bow"        Gear tab filtered to matching upgrades
--   "macro pull" the macro library entry
--   "feed"       any hub tab by name
-- ("crates" waits for the Merchant's Favor planner, P5-06.)

local _, ns = ...
local UI = ns.UI
local M = ns:NewModule("Find", {
  title = "Command bar (find anything)",
  phase = "P7",
  order = 98,
  defaults = {},
})
ns.Find = M

M.MAX = 8

-- Key binding labels (Bindings.xml)
_G.BINDING_HEADER_OUTRIDER = "Outrider"
_G.BINDING_NAME_OUTRIDER_FIND = "Find anything (command bar)"

local function has(hay, needle) return hay and hay:lower():find(needle, 1, true) ~= nil end

-- { {label, kind, run = fn} } best first
function M:Search(text)
  local q = (text or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
  local out = {}
  if q == "" then return out end
  local function add(label, kind, run) if #out < M.MAX then out[#out + 1] = { label = label, kind = kind, run = run } end end

  -- places by kind (/ride near words)
  local alias = ns.Nearest and ns.Nearest.ALIASES[q]
  if alias then add("Nearest " .. alias:gsub("_", " "), "place", function() local _, msg = ns.Nearest:Go(alias) ns.Print(tostring(msg)) end) end

  -- hub tabs
  for _, t in ipairs(ns.Hub.tabs or {}) do
    if has(t.title, q) or t.id == q then
      add("Open " .. t.title .. " tab", "tab", function() ns.Hub:Build():Show() ns.Hub:ShowTab(t.id) end)
    end
  end

  -- macros ("macro pull" or just "pull")
  local mq = q:match("^macros?%s+(.+)$") or q
  if ns.MacroLibrary then
    for _, e in ipairs(ns.MacroLibrary:Entries()) do
      if has(e.name, mq) or (q ~= mq and has(e.explain, mq)) then
        add("Macro: " .. e.name, "macro", function()
          ns.Hub:Build():Show() ns.Hub:ShowTab("macros")
          local p = ns.Hub.byId.macros and ns.Hub.byId.macros.panel
          if p and p.ShowEntry then p:ShowEntry(e) end
        end)
      end
    end
  end

  -- rares
  if ns.RaresTab then
    for _, r in ipairs(ns.RaresTab:Known()) do
      if has(r.name, q) then
        add("Rare: " .. r.name, "rare", function()
          local last = ns.Sightings and ns.Sightings:Last(r.npcID)
          local pin = { kind = "rare", rare = true, npcID = r.npcID, name = r.name, mapID = last and last.mapID or r.mapID,
            x = last and last.x or 0, y = last and last.y or 0 }
          if last and last.x then ns.Waypoints:Set(last.mapID, last.x, last.y, r.name) end
          ns.MapPins:ShowCard(pin)
        end)
      end
    end
  end

  -- gear upgrades
  if ns.Nearby then
    for _, c in ipairs(ns.Nearby:Candidates()) do
      if has(c.name, q) or has(ns.Nearby.SlotWord(c.itemID), q) then
        add("Upgrade: " .. tostring(c.name), "gear", function()
          ns.Nearby.filter = q
          ns.Hub:Build():Show() ns.Hub:ShowTab("gear")
        end)
        break
      end
    end
  end

  -- known NPCs and places by name (own visits, then the pack on this map)
  if #q >= 3 then
    local seen = {}
    local function place(p)
      if p.name and not seen[p.name] and has(p.name, q) then
        seen[p.name] = true
        add(p.name .. "  (" .. (ns.MapPins.LABELS[p.kind] or p.kind or "place") .. ")", "npc",
          function() ns.Waypoints:Set(p.mapID, p.x, p.y, p.name) end)
      end
    end
    for _, p in pairs(ns.db.global.pois or {}) do place(p) end
    local mapID = ns.Compat.PlayerPosition("player")
    if ns.NPCPack and mapID then for _, p in ipairs(ns.NPCPack:PlacesFor(mapID)) do place(p) end end
  end
  return out
end

function M:Run(text)
  local r = self:Search(text)[1]
  if not r then ns.Print("nothing found for '%s'", tostring(text)) return false end
  self:Info("find '%s' -> %s", tostring(text), r.label)
  ns.Safe("Find:run", r.run)
  return true, r
end

function M:Build()
  if self.frame then return self.frame end
  local f = UI:Window("Outrider_Find", "Find", 360, 250)
  local c = f.content
  f.box = UI:SearchBox(c, 336, "rare, place, NPC, gear, macro or tab", function(t) M:Show(t) end)
  f.box:SetPoint("TOPLEFT", 0, 0)
  f.box:SetScript("OnEnterPressed", function(box)
    M:Run(box:GetText())
    box:SetText("")
    f:Hide()
  end)
  f.box:HookScript("OnEscapePressed", function() f:Hide() end)
  f.list = UI:ScrollList(c, {
    rows = M.MAX, rowHeight = 22,
    render = function(row, r) row.text:SetText(r.label) end,
    onClick = function(r) ns.Safe("Find:run", r.run) f:Hide() end,
  })
  f.list:SetPoint("TOPLEFT", f.box, "BOTTOMLEFT", 0, -6)
  f.list:SetWidth(336)
  self.frame = f
  return f
end

function M:Show(text)
  local f = self:Build()
  f.list:SetItems(self:Search(text))
end

function M:Toggle()
  local f = self:Build()
  if f:IsShown() then f:Hide() return end
  f:Show()
  f.box:SetText("")
  f.list:SetItems({})
  f.box:SetFocus()
end

function M:Activity() return "press your Find key (Key Bindings, Outrider) or /ride find" end

ns.AddCommand("find", "[text]  find a rare, place, NPC, gear upgrade, macro or tab", function(arg)
  if arg and arg ~= "" then M:Run(arg) else M:Toggle() end
end)
