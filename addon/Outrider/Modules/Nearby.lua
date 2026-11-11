-- Modules/Nearby.lua  (P6-05 loader, P6-06 nearby upgrades)
-- Upgrade candidates for this character from the private gear pack
-- Outrider_Data_GearPack (tools/import_gear.py from QuestieDB, D10/D13;
-- loaded on demand the first time the Gear tab opens or a zone scan runs,
-- memory before/after logged) plus alts' BoE items (Handoffs).
-- Candidates: a source on the current map, Gary's faction or neutral,
-- required level from level-6 to level+3. Scored in game with GearScore
-- (item stats come from the client, so uncached items are requested and
-- scored when they arrive). Ranked by gain, then effort: vendor, alt,
-- quest, drop. Gear hub tab: click a row for a waypoint.
-- One toast per item when a new candidate is a 10%+ upgrade usable now,
-- never in combat or instances. Without the pack only alts' items show.

local _, ns = ...
local C = ns.Compat
local UI = ns.UI
local M = ns:NewModule("Nearby", {
  title = "Nearby upgrades",
  phase = "P6",
  order = 84,
  defaults = { threshold = 10, told = {} },
})
ns.Nearby = M

M.ADDON = "Outrider_Data_Gear"
M.EFFORT = { vendor = 1, alt = 2, gearquest = 3, quest = 3, drop = 4 }
M.KIND_LABEL = { vendor = "sold by", quest = "quest", drop = "dropped by", alt = "on" }

function M:Load()
  if self.pack ~= nil then return self.pack end
  local before = collectgarbage("count")
  if not rawget(_G, "Outrider_DataGear") then C.LoadAddOn(self.ADDON) end
  local data = rawget(_G, "Outrider_DataGear")
  if type(data) == "table" and type(data.items) == "table" then
    self.pack = data.items
    self.byMap = {}
    local n = 0
    for id, it in pairs(data.items) do
      n = n + 1
      for _, s in ipairs(it[4] or {}) do
        local list = self.byMap[s[2]]
        if not list then list = {} self.byMap[s[2]] = list end
        list[#list + 1] = id
      end
    end
    self:Info("gear pack loaded: %d items from %s, memory %+.0f KB", n, tostring(data.source), collectgarbage("count") - before)
  else
    self.pack = false
    self:Info("no %s installed: nearby upgrades use alts' items only", self.ADDON)
  end
  return self.pack
end

local function stats(id)
  local get = C.Resolve("C_Item.GetItemStats") or rawget(_G, "GetItemStats")
  if type(get) ~= "function" then return nil end
  local ok, s = pcall(get, "item:" .. id)
  return ok and type(s) == "table" and next(s) and s or nil
end

-- { {itemID, name, pct, kind, where = {mapID, x, y, who, qlevel}, reqLevel} } best first
function M:Candidates()
  local out, missing = {}, 0
  if not ns.GearScore then return out end
  local level = C.Call("UnitLevel", "player") or 1
  local faction = C.Call("UnitFactionGroup", "player")
  local mapID = C.PlayerPosition("player")
  local seen = {}
  local function add(id, name, kind, where, req)
    if seen[id] then return end
    if not stats(id) then
      missing = missing + 1
      C.Call("C_Item.RequestLoadItemDataByID", id)
      return
    end
    local r = ns.GearScore:Compare("item:" .. id)
    if r and not r.why and r.pct >= 1 then
      seen[id] = true
      out[#out + 1] = { itemID = id, name = name, pct = r.pct, kind = kind, where = where, reqLevel = req }
    end
  end
  if self:Load() and mapID then
    for _, id in ipairs(self.byMap[mapID] or {}) do
      local it = self.pack[id]
      local req = it[2] or 0
      if req <= level + 3 and req >= level - 6 then
        for _, s in ipairs(it[4]) do
          if s[2] == mapID and (s[7] == nil or s[7] == faction) then
            add(id, it[1], s[1], { mapID = s[2], x = s[3], y = s[4], who = s[5], qlevel = s[6] }, req)
            break
          end
        end
      end
    end
  end
  -- GearQuest's own best pick per slot (P6-07), scored with Outrider weights
  if ns.GearQuestBridge and ns.GearQuestBridge.enabled then
    for _, g in ipairs(ns.GearQuestBridge:Picks()) do
      if not seen[g.itemID] then
        if not stats(g.itemID) then
          missing = missing + 1
          C.Call("C_Item.RequestLoadItemDataByID", g.itemID)
        else
          local r = ns.GearScore:Compare("item:" .. g.itemID)
          if r and not r.why and r.pct >= 1 then
            seen[g.itemID] = true
            out[#out + 1] = { itemID = g.itemID, name = g.name, pct = r.pct, kind = "gearquest", via = g.label,
              zone = g.zone, where = g.where }
          end
        end
      end
    end
  end
  if ns.Handoffs then
    for _, h in ipairs(ns.Handoffs:Find()) do
      out[#out + 1] = { itemID = h.itemID, name = h.name, pct = h.pct, kind = "alt", where = { who = h.holder } }
    end
  end
  table.sort(out, function(a, b)
    local pa, pb = math.floor(a.pct + 0.5), math.floor(b.pct + 0.5)
    if pa ~= pb then return pa > pb end
    return (M.EFFORT[a.kind] or 9) < (M.EFFORT[b.kind] or 9)
  end)
  self.missing = missing
  return out
end

-- Plain slot word for an item ("bow", "cloak", "ring"...), for the command bar.
local SLOT_WORDS = { INVTYPE_HEAD = "helm head", INVTYPE_NECK = "neck amulet", INVTYPE_SHOULDER = "shoulder",
  INVTYPE_CHEST = "chest", INVTYPE_ROBE = "chest robe", INVTYPE_WAIST = "belt waist", INVTYPE_LEGS = "legs pants",
  INVTYPE_FEET = "boots feet", INVTYPE_WRIST = "bracers wrist", INVTYPE_HAND = "gloves hands", INVTYPE_FINGER = "ring",
  INVTYPE_TRINKET = "trinket", INVTYPE_CLOAK = "cloak back", INVTYPE_WEAPON = "weapon", INVTYPE_2HWEAPON = "weapon two-hand",
  INVTYPE_WEAPONMAINHAND = "weapon", INVTYPE_WEAPONOFFHAND = "weapon offhand", INVTYPE_SHIELD = "shield offhand",
  INVTYPE_HOLDABLE = "offhand", INVTYPE_RANGED = "bow ranged", INVTYPE_RANGEDRIGHT = "gun crossbow wand ranged",
  INVTYPE_THROWN = "thrown ranged" }
function M.SlotWord(id)
  local info = C.ItemInfo(id)
  return info and SLOT_WORDS[info.equipLoc or ""] or ""
end

function M.Describe(c)
  local w = c.where or {}
  local who = w.who and (tostring(w.who):match("^[^-]+") or w.who) or "?"
  local src = (M.KIND_LABEL[c.kind] or c.kind) .. " " .. who
  if c.kind == "gearquest" then
    src = "GearQuest: " .. tostring(c.via or "") .. " " .. who .. (c.zone and (", " .. c.zone) or "")
  end
  if c.kind == "quest" and w.qlevel then src = src .. " (level " .. w.qlevel .. ")" end
  return string.format("+%d%%  %s  |cffbbbbbb%s|r", math.floor(c.pct + 0.5), tostring(c.name), src)
end

function M:Scan(why)
  if C.InCombat() or C.Call("IsInInstance") then return end
  local list = self:Candidates()
  local s = self:Settings()
  -- GearQuest shows its own upgrade toasts: step aside (one owner, hard rule 8)
  local quiet = ns.GearQuestBridge and ns.GearQuestBridge:GQ() ~= nil
  for _, c in ipairs(quiet and {} or list) do
    if c.pct >= s.threshold and not s.told[c.itemID] and c.kind ~= "alt" then
      s.told[c.itemID] = time()
      ns.Toast:Show({ title = "Upgrade nearby: " .. tostring(c.name), text = M.Describe(c):gsub("|c%x+", ""):gsub("|r", ""),
        color = "good", duration = 12 })
      self:Info("nearby upgrade %s (%s)", tostring(c.name), M.Describe(c))
      break -- one toast per scan
    end
  end
  if why then self:Debug("nearby scan (%s): %d candidates, %d items not cached yet", why, #list, self.missing or 0) end
  ns.Hub:Refresh()
  return list
end

function M:OnEnable()
  self:On("ZONE_CHANGED_NEW_AREA", function(mod) ns.Throttle("nearby:scan", 5, function() mod:Scan("zone") end) end)
  self:On("PLAYER_LEVEL_UP", function(mod) ns.Throttle("nearby:scan", 5, function() mod:Scan("level") end) end)
  self:On("GET_ITEM_INFO_RECEIVED", function(mod)
    if (mod.missing or 0) > 0 then ns.Throttle("nearby:scan", 3, function() mod:Scan() end) end
  end)
end

function M:OnDisable() ns.ThrottleCancel("nearby:scan") end

function M:Activity()
  if self.pack == false then return "no gear pack installed; alts' items only" end
  return "upgrades from quests, vendors and drops in this zone (Gear tab)"
end

ns.Hub:AddTab("gear", "Gear", function(p)
  p.head = UI.Text(p, "small", "muted")
  p.head:SetPoint("TOPLEFT", 0, 0)
  p.head:SetText("Upgrades near you, best first. Click one for a waypoint. Sources are unverified community data.")
  p.list = UI:ScrollList(p, {
    rows = 13, rowHeight = 22,
    render = function(row, c) row.text:SetText(M.Describe(c)) end,
    onClick = function(c)
      local w = c.where
      if w and w.mapID and w.x then ns.Waypoints:Set(w.mapID, w.x, w.y, tostring(c.name)) end
    end,
  })
  p.list:SetPoint("TOPLEFT", p.head, "BOTTOMLEFT", 0, -8)
  p.list:SetWidth(560)
  function p:Refresh()
    local list, f = M:Candidates(), M.filter
    if f and f ~= "" then
      local keep = {}
      for _, c in ipairs(list) do
        if tostring(c.name):lower():find(f, 1, true) or M.SlotWord(c.itemID):find(f, 1, true) then keep[#keep + 1] = c end
      end
      list = keep
      self.head:SetText("Upgrades matching '" .. f .. "'. Click one for a waypoint.")
      M.filter = nil
    else
      self.head:SetText("Upgrades near you, best first. Click one for a waypoint. Sources are unverified community data.")
    end
    self.list:SetItems(list)
  end
end, 44)

ns.AddCommand("nearby", "upgrades you can get in this zone", function()
  local list = M:Candidates()
  if #list == 0 then ns.Print("no upgrades found here%s", (M.missing or 0) > 0 and " yet (item data still loading)" or "") return end
  for i = 1, math.min(6, #list) do ns.Print("%s", M.Describe(list[i])) end
end)
