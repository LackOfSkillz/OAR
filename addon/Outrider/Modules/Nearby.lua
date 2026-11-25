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
M.EFFORT = { craft = 1, vendor = 1, alt = 2, crafted = 3, gearquest = 3, quest = 3, drop = 4, rare = 4, chest = 4, container = 4, dungeon = 5, world = 6 }
M.KIND_LABEL = { vendor = "sold by", quest = "quest", drop = "dropped by", alt = "on", rare = "dropped by the rare",
  chest = "found in a", dungeon = "dropped by", craft = "you can make it with", world = "world drop from",
  container = "found in", crafted = "made with" }

-- A source this character can use: gear made by a profession only when you
-- have that profession ("crafted" sources from the crafting pack say
-- "Tailoring (skill 75)").
function M.CanUse(s)
  if s[1] ~= "crafted" then return true end
  local prof = type(s[5]) == "string" and s[5]:match("^(.-) %(")
  local mine = ns.db and ns.db.char and ns.db.char.professions
  return prof ~= nil and type(mine) == "table" and mine[prof] ~= nil
end

-- Gear this character can craft (requirement 2026-11-23: widen the sources): learned
-- recipes from the profession windows you opened, product = item made.
function M.Crafted()
  local out = {}
  for prof, p in pairs(ns.db and ns.db.char and ns.db.char.professions or {}) do
    if type(p) == "table" and prof ~= "" then
      for _, r in pairs(p.recipes or {}) do
        if type(r) == "table" and type(r.product) == "number" and r.learned ~= false then
          out[#out + 1] = { itemID = r.product, name = r.name, prof = prof }
        end
      end
    end
  end
  return out
end

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
        -- world drops and containers have no spot on a map (mapID 0 in the pack)
        if s[2] == 0 then s[2], s[3], s[4] = nil, nil, nil end
        local list = s[2] and self.byMap[s[2]]
        if s[2] and not list then list = {} self.byMap[s[2]] = list end
        if list then list[#list + 1] = id end
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

-- Can this character do the quest behind a quest source? (Case: Bow of Hours,
-- a level 11 quest after an earlier one, was shown to a level 4.)
-- Returns false for done or far-too-high quests; else true and a note when
-- it is not available yet ("from level 5", "after 1 earlier quest").
function M.QuestOpen(s, level)
  if s[1] ~= "quest" or not s[8] then return true, nil end
  local qid, qreq, preAny, preAll, qlvl = s[8], s[9] or 1, s[10] or {}, s[11] or {}, s[6]
  local function done(id) return C.Call("C_QuestLog.IsQuestFlaggedCompleted", id) == true end
  if done(qid) then return false end
  if qlvl and qlvl > level + 4 then return false end
  local missing = 0
  if #preAny > 0 then
    local any = false
    for _, p in ipairs(preAny) do if done(p) then any = true break end end
    if not any then missing = missing + 1 end
  end
  for _, p in ipairs(preAll) do if not done(p) then missing = missing + 1 end end
  local notes = {}
  if qreq > level then notes[#notes + 1] = "from level " .. qreq end
  if missing > 0 then notes[#notes + 1] = string.format("after %d earlier quest%s", missing, missing == 1 and "" or "s") end
  return true, #notes > 0 and table.concat(notes, ", ") or nil
end

-- Within reach of this level: required level from 6 below to 3 above. Items
-- the data lists with no real level requirement (0 or 1: reputation and
-- event items like Furbolg Medicine Pouch, item level 52) go by item level.
function M.LevelFits(it, level)
  local req, ilvl = it[2] or 0, it[3] or 0
  if req <= 1 and ilvl > level + 10 then return false end
  return req <= level + 3 and req >= level - 6
end

-- The continent a map is on (nil when the client can't say).
M.contCache = {}
function M.Continent(mapID)
  if not mapID then return nil end
  local hit = M.contCache[mapID]
  if hit ~= nil then return hit or nil end
  local id, out = mapID, false
  for _ = 1, 8 do
    local info = C.Call("C_Map.GetMapInfo", id)
    if type(info) ~= "table" then break end
    if info.mapType == 2 then out = info.mapID or id break end
    if not info.parentMapID or info.parentMapID == 0 then break end
    id = info.parentMapID
  end
  M.contCache[mapID] = out
  return out or nil
end

function M.ZoneName(mapID)
  local info = mapID and C.Call("C_Map.GetMapInfo", mapID)
  return type(info) == "table" and info.name or nil
end

-- Best upgrade per slot from the rest of the pack (sources not on this map):
-- your continent before others, then the bigger gain. Cached 20 s (the Gear
-- page asks several times per refresh); gear or level changes clear it.
M.FEW, M.ELSEWHERE_MAX = 6, 10
function M:Elsewhere(level, faction, mapID)
  local key = tostring(level) .. ":" .. tostring(mapID)
  local now = C.Call("GetTime") or 0
  local ec = self.elsewhereCache
  if ec and ec.key == key and now - ec.at < ((ec.missing or 0) > 0 and 4 or 20) then return ec.list end
  local here = M.Continent(mapID)
  local best, missing = {}, 0
  for id, it in pairs(self.pack or {}) do
    if M.LevelFits(it, level) then
      for _, s in ipairs(it[4] or {}) do
        if s[2] ~= mapID and (s[7] == nil or s[7] == faction) and M.CanUse(s) then
          local ok, note = M.QuestOpen(s, level)
          if ok then
            if not stats(id) then
              missing = missing + 1
              C.Call("C_Item.RequestLoadItemDataByID", id)
            else
              local r = ns.GearScore:Compare("item:" .. id)
              if r and not r.why and r.pct >= 1 then
                local near = here ~= nil and M.Continent(s[2]) == here
                local slot = r.slot or ("x" .. id)
                local cur = best[slot]
                if not cur or (near and not cur.near) or (near == cur.near and r.pct > cur.pct) then
                  best[slot] = { itemID = id, name = it[1], pct = r.pct, kind = s[1], reqLevel = it[2] or 0, near = near, away = true,
                    zone = M.ZoneName(s[2]),
                    where = { mapID = s[2], x = s[3], y = s[4], who = s[5], qlevel = s[6], note = note, qid = s[1] == "quest" and s[8] or nil } }
                end
              end
            end
            break
          end
        end
      end
    end
  end
  local list = {}
  for _, c in pairs(best) do list[#list + 1] = c end
  table.sort(list, function(a, b)
    if a.near ~= b.near then return a.near end
    if a.pct ~= b.pct then return a.pct > b.pct end
    return a.itemID < b.itemID
  end)
  while #list > M.ELSEWHERE_MAX do table.remove(list) end
  self.elsewhereCache = { key = key, at = now, list = list, missing = missing }
  return list
end

-- { {itemID, name, pct, kind, where = {mapID, x, y, who, qlevel, note}, reqLevel} } best first;
-- quests you cannot take yet come after the ones you can
function M:Candidates(opts)
  local world = opts and opts.world
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
  if self:Load() and world then
    -- every map (Find page): the first source this character can use
    for id, it in pairs(self.pack) do
      local req = it[2] or 0
      if M.LevelFits(it, level) then
        for _, s in ipairs(it[4]) do
          if (s[7] == nil or s[7] == faction) and M.CanUse(s) then
            local ok, note = M.QuestOpen(s, level)
            if ok then
              add(id, it[1], s[1], { mapID = s[2], x = s[3], y = s[4], who = s[5], qlevel = s[6], note = note, qid = s[1] == "quest" and s[8] or nil }, req)
              break
            end
          end
        end
      end
    end
  elseif self:Load() and mapID then
    for _, id in ipairs(self.byMap[mapID] or {}) do
      local it = self.pack[id]
      local req = it[2] or 0
      if M.LevelFits(it, level) then
        for _, s in ipairs(it[4]) do
          if s[2] == mapID and (s[7] == nil or s[7] == faction) and M.CanUse(s) then
            local ok, note = M.QuestOpen(s, level)
            if ok then
              add(id, it[1], s[1], { mapID = s[2], x = s[3], y = s[4], who = s[5], qlevel = s[6], note = note, qid = s[1] == "quest" and s[8] or nil }, req)
              break
            end
          end
        end
      end
    end
  end
  -- Few upgrades on this map (bug 2026-11-23: GearQuest off and the Gear
  -- page was empty in Moonglade): the best one per slot from other zones,
  -- your continent first.
  if not world and self.pack and #out < M.FEW then
    for _, c in ipairs(self:Elsewhere(level, faction, mapID)) do
      if not seen[c.itemID] then
        seen[c.itemID] = true
        out[#out + 1] = c
      end
    end
    missing = missing + (self.elsewhereCache and self.elsewhereCache.missing or 0)
  end
  -- what you can make yourself
  for _, r in ipairs(world and {} or M.Crafted()) do
    if not seen[r.itemID] then
      local before = #out
      add(r.itemID, r.name, "craft", { who = r.prof }, 0)
      if #out > before then out[#out].prof = r.prof end
    end
  end
  -- GearQuest's own best pick per slot (P6-07), scored with Outrider weights
  if ns.GearQuestBridge and ns.GearQuestBridge.enabled and not world then
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
  if ns.Handoffs and not world then
    for _, h in ipairs(ns.Handoffs:Find()) do
      out[#out + 1] = { itemID = h.itemID, name = h.name, pct = h.pct, kind = "alt", where = { who = h.holder } }
    end
  end
  table.sort(out, function(a, b)
    -- this map before other zones
    local za, zb = a.away and 1 or 0, b.away and 1 or 0
    if za ~= zb then return za < zb end
    local la, lb = (a.where and a.where.note) and 1 or 0, (b.where and b.where.note) and 1 or 0
    if la ~= lb then return la < lb end
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

-- where the item comes from, without the item: "dropped by Slydris"
function M.Source(c)
  local w = c.where or {}
  -- no "?" when the source has no named NPC ("profession ?" in the tour)
  local who = w.who and (tostring(w.who):match("^[^-]+") or w.who) or nil
  local src = (M.KIND_LABEL[c.kind] or c.kind) .. (who and (" " .. who) or "")
  if c.kind == "gearquest" then
    -- no other addon's name on screen (requirement 2026-11-20: Outrider stands alone)
    src = (tostring(c.via or "upgrade"):gsub("^%l", string.upper)) .. (who and (" " .. who) or "") .. (c.zone and (", " .. c.zone) or "")
  end
  if c.kind == "quest" and w.qlevel then src = src .. " (level " .. w.qlevel .. ")" end
  if c.away and c.zone then src = src .. ", " .. c.zone end
  if w.note then src = src .. ", " .. w.note end
  return src
end

function M.Describe(c)
  return string.format("%s  %s  |cffbbbbbb%s|r", ns.GearScore.UpText(c.pct), tostring(c.name), M.Source(c))
end

function M:Scan(why)
  if C.InCombat() or C.Call("IsInInstance") then return end
  local list = self:Candidates()
  local s = self:Settings()
  -- GearQuest shows its own upgrade toasts: step aside (one owner, hard rule 8)
  local quiet = ns.GearQuestBridge and ns.GearQuestBridge:GQ() ~= nil
  for _, c in ipairs(quiet and {} or list) do
    if c.pct >= s.threshold and not s.told[c.itemID] and c.kind ~= "alt" and not c.away then
      s.told[c.itemID] = time()
      ns.Toast:Show({ title = "Upgrade nearby: " .. tostring(c.name), text = M.Describe(c):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""),
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
  self:On("PLAYER_EQUIPMENT_CHANGED", function(mod) mod.elsewhereCache = nil end)
  self:On("PLAYER_LEVEL_UP", function(mod) ns.Throttle("nearby:scan", 5, function() mod:Scan("level") end) end)
  self:On("GET_ITEM_INFO_RECEIVED", function(mod)
    if (mod.missing or 0) > 0 then ns.Throttle("nearby:scan", 3, function() mod:Scan() end) end
  end)
end

function M:OnDisable() ns.ThrottleCancel("nearby:scan") end

-- P9-01: the best upgrade candidates right now (top 8)
function M:Snapshot()
  local out = {}
  for i, c in ipairs(self:Candidates()) do
    if i > 8 then break end
    local w = c.where or {}
    out[i] = { itemID = c.itemID, name = c.name, pct = math.floor(c.pct + 0.5), source = c.kind,
      who = w.who, mapID = w.mapID, x = w.x, y = w.y }
  end
  return { candidates = out }
end

function M:Activity()
  if self.pack == false then return "no gear pack installed; alts' items only" end
  return "upgrades from quests, vendors and drops in this zone (Gear tab)"
end

-- Gear page as premium cards (2026-11-16): the item's own icon and tooltip,
-- how much better it is, where it comes from, and a waypoint button.
-- The equipment slot an upgrade is for (from GearScore's comparison).
function M.SlotOf(c)
  local ok, r = pcall(ns.GearScore.Compare, ns.GearScore, "item:" .. tostring(c.itemID))
  return ok and type(r) == "table" and r.slot or nil
end

-- Paper-doll strip (premium rebuild 2026-11-18): what you wear, by slot, with
-- a quality border; a green arrow where an upgrade is waiting; click a slot
-- to show only its upgrades (click again for all).
M.DOLL = { 1, 2, 3, 15, 5, 9, 10, 6, 7, 8, 11, 12, 13, 14, 16, 17, 18 }

function M:Doll(host)
  local f = CreateFrame("Frame", nil, host)
  f:SetSize(600, 92)
  f.slots = {}
  local SIZE, GAP = 38, 6
  for i, slot in ipairs(M.DOLL) do
    local b = CreateFrame("Button", nil, f, ns.Theme:BackdropTemplate())
    b:SetSize(SIZE, SIZE)
    local col, row = (i - 1) % 9, math.floor((i - 1) / 9)
    b:SetPoint("TOPLEFT", col * (SIZE + GAP), -row * (SIZE + GAP))
    ns.Theme:ApplyPanel(b, "bg", "strong")
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", 2, -2)
    b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    b.up = b:CreateTexture(nil, "OVERLAY")
    b.up:SetSize(14, 14)
    b.up:SetPoint("TOPRIGHT", 2, 2)
    b.up:SetTexture("Interface\\Buttons\\UI-MicroStream-Green")
    b.slot = slot
    b:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      local link = C.Call("GetInventoryItemLink", "player", self.slot)
      if link and GameTooltip.SetInventoryItem then pcall(GameTooltip.SetInventoryItem, GameTooltip, "player", self.slot)
      else GameTooltip:AddLine(ns.TitleCase(ns.GearScore.SLOT_NAMES[self.slot] or "slot") .. ": empty") end
      if self.hasUp then GameTooltip:AddLine("Upgrade waiting: click to see it", 0.4, 0.85, 0.5) end
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("OnClick", function(self)
      M.slotFilter = M.slotFilter ~= self.slot and self.slot or nil
      if ns.Hub.Refresh then ns.Hub:Refresh() end
    end)
    f.slots[i] = b
  end
  function f:Refresh()
    local ups = {}
    for _, c in ipairs(M:Candidates()) do local sl = M.SlotOf(c) if sl then ups[sl] = true end end
    -- rings and trinkets share an upgrade either way
    if ups[11] or ups[12] then ups[11], ups[12] = true, true end
    if ups[13] or ups[14] then ups[13], ups[14] = true, true end
    for _, b in ipairs(self.slots) do
      local tex = C.Call("GetInventoryItemTexture", "player", b.slot)
      b.icon:SetTexture(tex or "Interface\\PaperDoll\\UI-Backpack-EmptySlot")
      b.icon:SetDesaturated(tex == nil)
      local q = tonumber(C.Readable(C.Call("GetInventoryItemQuality", "player", b.slot)))
      local qc = q and rawget(_G, "ITEM_QUALITY_COLORS") and ITEM_QUALITY_COLORS[q]
      if b.SetBackdropBorderColor then
        if M.slotFilter == b.slot then b:SetBackdropBorderColor(ns.Theme:Color("gold"))
        elseif qc then b:SetBackdropBorderColor(qc.r, qc.g, qc.b, 1)
        else b:SetBackdropBorderColor(ns.Theme:Color("strong")) end
      end
      b.hasUp = ups[b.slot] and true or false
      b.up:SetShown(b.hasUp)
    end
  end
  f:Refresh()
  return f
end

function M:CardItems()
  local list, f = self:Candidates(), self.filter
  if self.slotFilter then
    local keep, want = {}, self.slotFilter
    for _, c in ipairs(list) do
      local sl = M.SlotOf(c)
      if sl == want or (want == 11 or want == 12) and (sl == 11 or sl == 12) or (want == 13 or want == 14) and (sl == 13 or sl == 14) then
        keep[#keep + 1] = c
      end
    end
    list = keep
  end
  if f and f ~= "" then
    local keep = {}
    for _, c in ipairs(list) do
      if tostring(c.name):lower():find(f, 1, true) or M.SlotWord(c.itemID):find(f, 1, true) then keep[#keep + 1] = c end
    end
    list = keep
  end
  local out = {}
  for i, c in ipairs(list) do
    if i > 15 then break end
    local w = c.where or {}
    -- the source only: the card's title and tag already say the item and how big
    -- an upgrade it is (the tour showed "big upgrade Rusty Cutlass" repeated under the title)
    local src = M.Source(c)
    local tags = { { ns.GearScore.UpText(c.pct), "gold" } }
    local slot = M.SlotWord(c.itemID)
    if slot and slot ~= "" then tags[#tags + 1] = { slot:gsub("^%l", string.upper), "plain" } end
    local actions = {}
    if w.mapID and w.x then
      actions[1] = { "Set waypoint", function() ns.Waypoints:Set(w.mapID, w.x, w.y, tostring(c.name)) end, "Sets the arrow to where you get it." }
    end
    out[#out + 1] = { itemID = c.itemID, title = tostring(c.name), tags = tags, line = src, actions = actions, highlight = i == 1 }
  end
  return out
end

ns.Hub:AddTab("gear", "Gear", function(p)
  UI:FormPage(p, {
    { "header", "Gear" },
    { "header", "What you wear", icon = "INV_Chest_Chain" },
    { "custom", function(host) return M:Doll(host) end, 92 },
    { "note", "Green arrow: an upgrade is waiting. Click a slot to see only its upgrades." },
    { "header", "Upgrades for you", icon = "INV_Chest_Chain" },
    { "note", function()
      if M.slotFilter then return "Upgrades for your " .. tostring(ns.GearScore.SLOT_NAMES[M.slotFilter] or "slot") .. " (click the slot again for all)." end
      return M.filter and M.filter ~= "" and ("Upgrades matching '" .. M.filter .. "'.") or "This zone first, then the best one per slot in other zones (your continent first). Hover the picture for the item."
    end },
    { "cards", function() return M:CardItems() end },
    { "note", function() return #M:Candidates() == 0 and "No upgrades found here yet (item data may still be loading)." or "" end },
    -- sections other parts of Outrider add to this page (Hub:Sections("gear");
    -- GearROI's "Worth getting?", OI04-09), drawn without knowing them
    { "header", "Worth getting?", icon = "INV_Misc_Coin_02" },
    { "note", function() local s = ns.Hub:Sections("gear")[1] return s and s.note or "" end },
    { "cards", function() local s = ns.Hub:Sections("gear")[1] return s and s.cards(function() p:Refresh() end) or {} end },
  })
  local refresh = p.Refresh
  function p:Refresh() refresh(self) M.filter = nil end
end, 44)

ns.AddCommand("nearby", "upgrades you can get in this zone", function()
  local list = M:Candidates()
  if #list == 0 then ns.Print("no upgrades found here%s", (M.missing or 0) > 0 and " yet (item data still loading)" or "") return end
  for i = 1, math.min(6, #list) do ns.Print("%s", M.Describe(list[i])) end
end)
