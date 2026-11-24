-- DungeonJournal.lua (DEEP-35)
-- Optional read-only journal over the installed *attributed* dungeon and
-- quest packs. Never infers missing loot, bosses or quest rewards.
local _, ns = ...
local C, UI = ns.Compat, ns.UI
local M = ns:NewModule("DungeonJournal", {
  title = "Dungeon and raid journal", phase = "P6", order = 86,
  defaults = { selected = nil },
})
ns.DungeonJournal = M

function M:Names()
  local names = {}
  for name in pairs(ns.DungeonGuide:ByName()) do names[#names + 1] = name end
  table.sort(names)
  return names
end

-- Pure assembled view suitable for the UI, tests and the knowledge bridge.
function M:Details(name)
  local D = ns.DungeonGuide
  local d = D:ByName()[name]
  if not d then return nil, "dungeon not in installed data pack" end
  local meta = ns.Data:Get("dungeon", name)
  local quests, reason = D:QuestList(name)
  local upgrades = D:Upgrades(d)
  local upgradeByItem = {}
  for _, row in ipairs(upgrades) do upgradeByItem[row.itemID] = row end
  local bosses, lootCount = {}, 0
  for _, boss in ipairs(d.bosses or {}) do
    local loot = {}
    for _, id in ipairs(boss[5] or {}) do
      local item = d.items[id]
      local up = upgradeByItem[id]
      loot[#loot + 1] = { id = id, name = item and item[1] or ("Item " .. id),
        requiredLevel = item and tonumber(item[2]) or nil,
        upgradePct = up and up.pct or nil,
        wishlist = ns.BagExtras and ns.BagExtras:Wishlist()[id] ~= nil or false }
    end
    table.sort(loot, function(a, b) return a.id < b.id end)
    lootCount = lootCount + #loot
    bosses[#bosses + 1] = { id = boss[1], name = boss[2], level = boss[3],
      loot = loot, source = "installed dungeon pack; completeness unverified" }
  end
  local suitable
  for _, row in ipairs(D:Rank()) do if row.name == name then suitable = row.status break end end
  return { name = name, mapID = d.map, x = d.x, y = d.y,
    min = meta and meta.min, max = meta and meta.max, size = meta and meta.size,
    raid = meta and meta.raid, verified = meta and meta.verified == true or false,
    status = suitable or "outside recommended levels",
    bosses = bosses, lootCount = lootCount,
    quests = quests, questStatus = reason or "boss-linked and user-linked only",
    ready = D:ReadyCheck(), source = "installed dungeon / quest data packs" }
end

function M:Rows(data, bossName)
  if not data then return {} end
  local out = {}
  local function add(kind, line, details)
    out[#out + 1] = { kind = kind, text = line, details = details }
  end
  add("header", string.format("%s (%s, levels %s-%s)",
    data.name, data.raid and "raid" or "dungeon", tostring(data.min or "?"), tostring(data.max or "?")))
  add("header", string.format("Readiness: %s; %s-person group", data.status, tostring(data.size or "?")))
  for _, x in ipairs(data.ready) do add("ready", (x.ok and "OK  " or "CHECK  ") .. x.text) end
  for _, boss in ipairs(data.bosses) do
    if not bossName or bossName == boss.name then
      add("boss", "Boss: " .. tostring(boss.name) .. " — " .. #boss.loot .. " known drops", boss)
      for _, item in ipairs(boss.loot) do
        local tags = item.wishlist and " [WISHLIST]" or ""
        if item.upgradePct then tags = tags .. string.format(" [+%d%%]", item.upgradePct) end
        add("loot", "  " .. item.name .. " (" .. item.id .. ")" .. tags, item)
      end
    end
  end
  if not bossName then
    add("header", string.format("Known dungeon quests (%d; partial dataset):", #data.quests))
    for _, q in ipairs(data.quests) do
      add("quest", string.format("  [%d] %s %s", q.id,
        tostring(q.name), q.complete and "[READY]" or q.active and "[IN LOG]" or ""), q)
    end
    if data.questStatus then add("note", "Quest coverage: " .. data.questStatus) end
  end
  add("note", "Loot/levels come from installed packs; omitted content is unknown, not absent.")
  return out
end

function M:Build()
  if self.window then return self.window end
  local f = UI:Window("Outrider_DungeonJournal", "Dungeon and raid journal", 760, 510,
    ns.db.char.dungeonJournalWindow or {})
  self.window = f
  local hint = UI.Text(f.content, "small", "muted")
  hint:SetPoint("TOPLEFT", 2, -1)
  hint:SetWidth(720)
  hint:SetText("Bosses • recorded loot • related quests • readiness • entrance. Packs may be incomplete.")
  f.names = UI:ScrollList(f.content, {
    rows = 15, rowHeight = 25,
    render = function(row, name) row.text:SetText(name) end,
    onClick = function(name)
      M:Select(name)
    end,
  })
  f.names:SetWidth(235)
  f.names:SetPoint("TOPLEFT", 2, -30)
  f.rows = UI:ScrollList(f.content, {
    rows = 15, rowHeight = 25,
    render = function(row, entry) row.text:SetText(entry.text) end,
    onClick = function(entry)
      if entry.kind == "boss" and entry.details then
        M.bossFilter = M.bossFilter == entry.details.name and nil or entry.details.name
        M:Refresh()
      elseif entry.kind == "loot" and entry.details then
        local id = entry.details.id
        ns.Print("journal item %d: inspect with your in-game item tooltip; source is unverified", id)
      elseif entry.kind == "quest" and entry.details and ns.QuestObjectives then
        ns.QuestObjectives:Guide(entry.details.id)
      end
    end,
  })
  f.rows:SetPoint("TOPLEFT", f.names, "TOPRIGHT", 8, 0)
  f.rows:SetPoint("RIGHT", -2, 0)
  local go = UI:Button(f.content, "Waypoint to entrance", 170, function()
    local data = M.selected and M:Details(M.selected)
    if data and data.mapID and data.x and data.y and ns.Waypoints then
      ns.Waypoints:Set(data.mapID, data.x, data.y, "Entrance: " .. data.name)
    else ns.Print("entrance coordinates unavailable in dungeon pack") end
  end)
  go:SetPoint("BOTTOMRIGHT", -2, 4)
  UI.Tip(go, "Dungeon entrance", "Set a waypoint to the entrance recorded in the installed dungeon pack.")
  local all = UI:Button(f.content, "All bosses and quests", 170, function() M.bossFilter = nil M:Refresh() end)
  all:SetPoint("RIGHT", go, "LEFT", -8, 0)
  UI.Tip(all, "Show all bosses", "Clear the selected boss filter to display all recorded loot and related quests.")
  f:Hide()
  return f
end

function M:Select(name)
  self.selected = name
  self:Settings().selected = name
  self.bossFilter = nil
  self:Refresh()
end

function M:Refresh()
  if not self.window then return end
  local f = self.window
  local names = self:Names()
  f.names:SetItems(names)
  local selection = self.selected or self:Settings().selected or names[1]
  self.selected = selection
  local data = selection and self:Details(selection)
  f.rows:SetItems(self:Rows(data, self.bossFilter))
end

function M:Toggle()
  local f = self:Build()
  if not f:IsShown() then self:Refresh() f:Show() else f:Hide() end
end

function M:Activity() return #self:Names() .. " dungeons/raids in loaded data" end

ns.AddCommand("journal", "journal [dungeon name]  browse bosses, loot, quests and readiness", function(arg)
  local name = tostring(arg or ""):match("^%s*(.-)%s*$")
  if name ~= "" then
    if not ns.DungeonGuide:ByName()[name] then ns.Print("unknown dungeon %s (install data pack)", name) return end
    M:Select(name)
  end
  M:Toggle()
end)

-- ------------------------------------------------------------ bosses on dungeon maps
-- (Gary, 2026-11-23: ideas from FojjiCore.) The travel pack lists the
-- creatures inside each instance that drop blue or better gear, at their
-- spot in the instance's own world coordinates. On a dungeon map the game
-- turns that spot into a map position (C_Map.GetMapPosFromWorldPos), so the
-- pins come from the client's own map, not from coordinates typed in.
-- Which order the game wants (x, y) or (y, x) is found once from the first
-- boss that lands on the map, and logged. verified = false until seen.
M.bossCache = {}
local function toMap(inst, wx, wy, mapID, order)
  local get, vec = C.Resolve("C_Map.GetMapPosFromWorldPos"), rawget(_G, "CreateVector2D")
  if type(get) ~= "function" or type(vec) ~= "function" then return nil end
  local a, b = wx, wy
  if order == "yx" then a, b = wy, wx end
  local ok, ui, pos = pcall(get, inst, vec(a, b), mapID)
  if not ok or not pos then return nil end
  local okXY, x, y = pcall(pos.GetXY, pos)
  if okXY and x and y and x >= 0 and x <= 1 and y >= 0 and y <= 1 then return x, y end
  return nil
end

function M:BossPins(mapID)
  if not mapID then return {} end
  local hit = self.bossCache[mapID]
  if hit then return hit end
  local out = {}
  self.bossCache[mapID] = out
  local info = C.Call("C_Map.GetMapInfo", mapID)
  local mtype = type(info) == "table" and info.mapType
  if mtype ~= 4 and mtype ~= 5 then return out end   -- dungeon or micro-dungeon maps only
  local inst = ns.Waypoints and ns.Waypoints.WorldPos(mapID, 0.5, 0.5)
  local pack = ns.Travel and ns.Travel:Pack()
  local list = inst and pack and pack.bosses and pack.bosses[inst]
  if not list then return out end
  for _, b in ipairs(list) do
    local x, y = toMap(inst, b[4], b[5], mapID, M.order)
    if not x and not M.order then
      for _, o in ipairs({ "xy", "yx" }) do
        x, y = toMap(inst, b[4], b[5], mapID, o)
        if x then M.order = o self:Info("dungeon map %d: boss spots use (%s) order", mapID, o) break end
      end
    end
    if x then
      local lines = {}
      for i = 1, #(b[6] or {}) - 1, 2 do
        local it = C.ItemInfo(b[6][i])
        local wish = ns.BagExtras and ns.BagExtras:Wishlist()[b[6][i]] and "  |cff66d980(wish list)|r" or ""
        lines[#lines + 1] = string.format("%s  %.0f%%%s", it and it.name or ("item " .. b[6][i]), b[6][i + 1] / 100, wish)
      end
      out[#out + 1] = { id = "boss-" .. b[1], kind = "boss", mapID = mapID, x = x, y = y, name = b[2], npcID = b[1],
        poi = { kind = "boss", name = b[2], title = "drops", note = table.concat(lines, "\n"), source = "ForeverDB, unchecked" } }
    end
  end
  self:Debug("dungeon map %d (instance %s): %d of %d bosses placed", mapID, tostring(inst), #out, #list)
  return out
end

-- ------------------------------------------------------------ wish list drops
-- (FojjiCore idea, 2026-11-23) An item on your wish list is up for a roll,
-- in a loot window, or someone got it: one toast per item per minute. The
-- wish list itself lives in BagExtras (/ride wish, the journal's [WISHLIST]).
M.told = {}
local function itemID(link) return type(link) == "string" and tonumber(link:match("item:(%d+)")) or nil end

function M:WishSeen(id, how, link)
  local wish = ns.BagExtras and ns.BagExtras:Wishlist()
  if not (id and wish and wish[id]) then return false end
  local now = time()
  if self.told[id] and now - self.told[id] < 60 then return false end
  self.told[id] = now
  local name = (C.ItemInfo(id) or {}).name or wish[id].name or ("item " .. id)
  if how == "got" then wish[id].got = now end
  local title = how == "roll" and "Wish list: up for a roll" or how == "loot" and "Wish list: in this loot"
    or how == "got" and "Wish list: you got it" or "Wish list: it dropped"
  ns.Toast:Show({ title = title, text = name, color = "good", duration = 12 })
  if ns.Feed then ns.Feed:Add(nil, { title = title, text = name }) end
  self:Info("wish list %s: %s", how, name)
  return true
end

-- ------------------------------------------------------------ dungeon run timer
-- (FojjiCore idea, 2026-11-23) The clock starts when you enter a dungeon,
-- each boss kill (ENCOUNTER_END with success, the game's own event; no
-- combat log) is a split, and the run ends when you leave: its time is the
-- last kill. Best time per dungeon, account-wide, for runs that killed at
-- least as many bosses. Back inside within REJOIN seconds: the same run.
M.REJOIN = 600
local function runs()
  local g = ns.db.global
  g.dungeonRuns = type(g.dungeonRuns) == "table" and g.dungeonRuns or {}
  return g.dungeonRuns
end
function M.Clock(sec)
  sec = math.floor((sec or 0) + 0.5)
  return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
end

function M:RunCheck()
  local inside, kind = C.Call("IsInInstance")
  local now = C.Call("GetTime") or 0
  local run = self.run
  if inside and (kind == "party" or kind == "raid") then
    local name = C.Readable(C.Call("GetInstanceInfo")) or "dungeon"
    if run and run.name == name and (not run.left or now - run.left < M.REJOIN) then run.left = nil return run end
    if run then self:RunEnd() end
    self.run = { name = name, start = now, splits = {} }
    self:Info("dungeon run: %s started", name)
    return self.run
  elseif run and not run.left then
    run.left = now
  elseif run and run.left and now - run.left >= M.REJOIN then
    self:RunEnd()
  end
  return self.run
end

function M:RunSplit(boss)
  local run = self.run
  if not run or run.left then return nil end
  local t = (C.Call("GetTime") or 0) - run.start
  run.splits[#run.splits + 1] = { boss = boss, t = t }
  local rec = runs()[run.name]
  local best = rec and rec.splits and rec.splits[boss]
  local text = string.format("%s down at %s%s", tostring(boss), M.Clock(t),
    best and string.format(" (best %s, %s%s)", M.Clock(best), t <= best and "-" or "+", M.Clock(math.abs(t - best))) or "")
  ns.Toast:Show({ title = run.name, text = text, color = (best and t > best) and "warn" or "good", duration = 8 })
  self:Info("dungeon run split: %s", text)
  return t
end

function M:RunEnd()
  local run = self.run
  self.run = nil
  if not run or #run.splits == 0 then return nil end
  local total = run.splits[#run.splits].t
  local all = runs()
  local rec = all[run.name] or { splits = {} }
  local better = not rec.best or #run.splits > (rec.bosses or 0) or (#run.splits == (rec.bosses or 0) and total < rec.best)
  for _, sp in ipairs(run.splits) do
    if not rec.splits[sp.boss] or sp.t < rec.splits[sp.boss] then rec.splits[sp.boss] = sp.t end
  end
  if better then rec.best, rec.bosses, rec.at = total, #run.splits, time() end
  rec.runs = (rec.runs or 0) + 1
  rec.last = { t = total, bosses = #run.splits, at = time() }
  all[run.name] = rec
  local text = string.format("%d boss%s in %s%s", #run.splits, #run.splits == 1 and "" or "es", M.Clock(total),
    better and " (new best)" or string.format(" (best %s)", M.Clock(rec.best)))
  ns.Toast:Show({ title = run.name .. " run", text = text, color = better and "good" or "info", duration = 12 })
  self:Info("dungeon run: %s %s", run.name, text)
  return total, better
end

function M:OnEnable()
  self:On("PLAYER_ENTERING_WORLD", function(mod) mod:RunCheck() end)
  self:On("ZONE_CHANGED_NEW_AREA", function(mod) mod:RunCheck() end)
  self:On("ENCOUNTER_END", function(mod, _, _, name, _, _, success)
    if success == 1 or success == true then mod:RunSplit(C.Readable(name) or "boss") end
  end)
  self:On("START_LOOT_ROLL", function(mod, _, rollID) mod:WishSeen(itemID(C.Call("GetLootRollItemLink", rollID)), "roll") end)
  self:On("LOOT_OPENED", function(mod)
    for slot = 1, (C.Call("GetNumLootItems") or 0) do mod:WishSeen(itemID(C.Call("GetLootSlotLink", slot)), "loot") end
  end)
  self:On("CHAT_MSG_LOOT", function(mod, _, msg)
    if type(msg) ~= "string" or C.IsSecret(msg) then return end
    local id = itemID(msg)
    local mine = rawget(_G, "LOOT_ITEM_SELF") and msg:find((LOOT_ITEM_SELF:gsub("%%s.*", "")), 1, true) == 1
    if id then mod:WishSeen(id, mine and "got" or "other") end
  end)
end
