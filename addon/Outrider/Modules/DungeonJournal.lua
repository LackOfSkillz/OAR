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
