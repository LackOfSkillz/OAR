-- Modules/DungeonQuests.lua
-- Dungeon quests and keys, at Attune's level of detail and beyond
-- (requirement 2026-11-21: match that level of information and usability;
-- research in docs/ATTUNE_RESEARCH.md).
-- Own build from cited data: Data/Leveling_DungeonQuests.lua (Wowhead's
-- Forever dungeon guides). Nothing of Attune (All Rights Reserved) is used.
--   * every dungeon for your faction, sorted by level, with your progress
--   * each quest: status (done / in your log / later / to do), level, giver,
--     zone, and a Go button that sets the arrow (Attune has no waypoints)
--   * the entrance, keys and secrets, and how far each of your characters got
--   * "won't do" hides a dungeon; finished ones move to Done; a Next line
-- Status comes from the game: your quest log, quests the client marks
-- completed (by the quest pack's IDs for that name), and Outrider's quest
-- history (per character, so alts show without logging in). Quest data stays
-- verified = false; a wrong step can be reported with /ride dqwrong.

local _, ns = ...
local C = ns.Compat
local UI, Theme = ns.UI, ns.Theme
local M = ns:NewModule("DungeonQuests", {
  title = "Dungeon quests and keys",
  phase = "P6",
  order = 66,
  defaults = { wontDo = {}, filter = "mine", picked = nil, wrong = {} },
})
ns.DungeonQuests = M

M.STATUS = {
  done = { word = "Done", color = "good", icon = "Interface\\RaidFrame\\ReadyCheck-Ready" },
  active = { word = "In your log", color = "gold", icon = "Interface\\GossipFrame\\ActiveQuestIcon" },
  todo = { word = "To do", color = "text", icon = "Interface\\GossipFrame\\AvailableQuestIcon" },
  later = { word = "Later", color = "muted", icon = "Interface\\RaidFrame\\ReadyCheck-Waiting" },
}
M.LATER = 3 -- a quest more than this many levels above you is "later"

local function readable(v) return C.Readable(v) end

-- quest name -> quest IDs from the quest pack (Outrider_Data_Quests), for the
-- client's "completed" flag; built once
function M:IdsByName()
  if self.idsByName then return self.idsByName end
  local out = {}
  local pack = ns.QuestObjectives and ns.QuestObjectives.Pack and ns.QuestObjectives:Pack()
  for id, q in pairs(pack and pack.quests or {}) do
    local name = type(q) == "table" and q[1]
    if type(name) == "string" then
      out[name] = out[name] or {}
      table.insert(out[name], id)
    end
  end
  self.idsByName = out
  return out
end

-- Everything the status of a quest depends on, read once per refresh.
function M:Context(key)
  local ctx = { level = tonumber(readable(C.Call("UnitLevel", "player"))) or 1, log = {}, history = {}, me = true }
  key = key or ns.db.key
  ctx.me = key == ns.db.key
  if ctx.me then
    for _, q in ipairs(ns.QuestObjectives and ns.QuestObjectives.Log and ns.QuestObjectives.Log() or {}) do
      if q.title then ctx.log[q.title] = true end
    end
  end
  local h = ns.db.global.questHistory
  for _, e in ipairs(type(h) == "table" and type(h[key]) == "table" and h[key] or {}) do
    if e.what == "handed in" and e.name then ctx.history[e.name] = true end
  end
  if not ctx.me then
    local a = ns.Alts and ns.Alts.alts and ns.Alts.alts[key]
    ctx.level = a and tonumber(a.level) or ctx.level
  end
  return ctx
end

function M:Status(step, ctx)
  local name = step.quest
  if ctx.history[name] then return "done" end
  if ctx.me then
    for _, id in ipairs(self:IdsByName()[name] or {}) do
      if readable(C.Call("C_QuestLog.IsQuestFlaggedCompleted", id)) == true then return "done" end
    end
    if ctx.log[name] then return "active" end
  end
  if step.level and ctx.level < step.level - M.LATER then return "later" end
  return "todo"
end

-- Every dungeon with its quests for this faction: { name, lo, hi, wings, steps,
-- entrance, notes }, sorted by level.
function M:Chains(faction)
  faction = faction or readable(C.Call("UnitFactionGroup", "player"))
  local levels = ns.Leveling and ns.Leveling.DUNGEON_LEVELS or {}
  local byName = {}
  for name, lv in pairs(levels) do
    byName[name] = { name = name, lo = lv[1], hi = lv[2], wings = lv.wings, levelNote = lv.note, steps = {}, notes = {} }
  end
  for _, p in ipairs(ns.Data:All("place")) do
    local d = p.dungeon and byName[p.dungeon]
    if p.kind == "quest_start" and d and (p.faction == nil or p.faction == faction) then d.steps[#d.steps + 1] = p end
    if p.kind == "dungeon" then
      local dn = byName[p.name] or (p.name and byName[p.name:gsub(":.*$", "")])
      if dn and not dn.entrance then dn.entrance = p end
    end
  end
  for _, n in ipairs(ns.Leveling and ns.Leveling.DUNGEON_NOTES or {}) do
    local d = byName[n.dungeon]
    if d then d.notes[#d.notes + 1] = n.text end
  end
  local out = {}
  for _, d in pairs(byName) do
    table.sort(d.steps, function(a, b)
      if (a.level or 0) ~= (b.level or 0) then return (a.level or 0) < (b.level or 0) end
      return tostring(a.quest) < tostring(b.quest)
    end)
    out[#out + 1] = d
  end
  table.sort(out, function(a, b) if a.lo ~= b.lo then return a.lo < b.lo end return a.name < b.name end)
  return out
end

function M:Progress(d, ctx)
  local done = 0
  for _, s in ipairs(d.steps) do if self:Status(s, ctx) == "done" then done = done + 1 end end
  return done, #d.steps
end

-- where you stand with a dungeon: "ready", "low" (not yet), "high" (no XP left)
function M.Fit(d, level)
  if level < d.lo - 2 then return "low" end
  if level > d.hi + 2 then return "high" end
  return "ready"
end

-- what to do next: the dungeon to run now, or the level the next one opens at
function M:Next(ctx)
  ctx = ctx or self:Context()
  local s = self:Settings()
  local best, unlock
  for _, d in ipairs(self:Chains()) do
    if not s.wontDo[d.name] then
      local done, total = self:Progress(d, ctx)
      local fit = M.Fit(d, ctx.level)
      if fit == "ready" and not best and (total == 0 or done < total) then best = d end
      if fit == "low" and (not unlock or d.lo < unlock.lo) then unlock = d end
    end
  end
  return best, unlock
end

-- your characters' progress on one dungeon: { { name, done, total }, ... }
function M:Alts(d)
  local out = {}
  for key, a in pairs(ns.Alts and ns.Alts.alts or {}) do
    local faction = a.faction
    if faction then
      local steps = 0
      for _, s in ipairs(d.steps) do if s.faction == nil or s.faction == faction then steps = steps + 1 end end
      local ctx = self:Context(key)
      local done = 0
      for _, s in ipairs(d.steps) do if (s.faction == nil or s.faction == faction) and ctx.history[s.quest] then done = done + 1 end end
      if steps > 0 then out[#out + 1] = { name = tostring(key):match("^[^-]+") or key, done = done, total = steps, me = key == ns.db.key } end
    end
  end
  table.sort(out, function(a, b) return a.name < b.name end)
  return out
end

function M:Go(step)
  local mapID = ns.Travel and ns.Travel:MapByName(step.zone)
  if not (mapID and ns.Waypoints) then
    ns.Print("%s: %s isn't on this map list yet", tostring(step.name), tostring(step.zone))
    return false
  end
  ns.Waypoints:Set(mapID, step.x, step.y, (step.quest and (step.quest .. ": ") or "") .. tostring(step.name))
  self:Info("dungeon quest go %s (%s) %s %.1f,%.1f", tostring(step.quest), tostring(step.dungeon), tostring(step.zone), step.x * 100, step.y * 100)
  return true
end

-- ------------------------------------------------------------- page
local function hex(color) return Theme:Hex(color) end

ns.Hub:AddTab("dungeonquests", "Dungeon quests", function(p)
  local s = function() return M:Settings() end
  -- filter chips
  p.chips = {}
  local FILTERS = { { "mine", "For my level" }, { "all", "All" }, { "done", "Done" }, { "wont", "Won't do" } }
  local x = 0
  for _, fl in ipairs(FILTERS) do
    local c = UI:Chip(p, fl[2], function() s().filter = fl[1] p:Refresh() end)
    c:SetPoint("TOPLEFT", x, -26)
    c.key = fl[1]
    x = x + (c:GetWidth() or 80) + 6
    p.chips[#p.chips + 1] = c
  end
  p.next = UI.Text(p, "normal", "goldText")
  p.next:SetPoint("TOPLEFT", 2, 0)
  -- left: dungeons
  p.list = UI:ScrollList(p, {
    rows = 16, rowHeight = 30,
    build = function(row)
      row.pic = row:CreateTexture(nil, "ARTWORK")
      row.pic:SetSize(24, 24)
      row.pic:SetPoint("LEFT", 4, 0)
      row.text:ClearAllPoints()
      row.text:SetPoint("LEFT", row.pic, "RIGHT", 8, 0)
      row.text:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    end,
    render = function(row, d)
      local fit = M.Fit(d, p.ctx.level)
      local col = fit == "ready" and "good" or fit == "low" and "bad" or "muted"
      if not (ns.Art and ns.Art:Set(row.pic, "dungeon_" .. d.name:lower():gsub("[^%a]", ""), "Interface\\Icons\\INV_Misc_Key_14")) then
        row.pic:SetTexture("Interface\\Icons\\INV_Misc_Key_14")
      end
      local done, total = M:Progress(d, p.ctx)
      row.text:SetText(string.format("%s  %s%d-%d|r  %s", d.name, hex(col), d.lo, d.hi,
        total > 0 and string.format("|cff8f96a6%d/%d quests|r", done, total) or "|cff8f96a6no quests|r"))
    end,
    onClick = function(d) s().picked = d.name p:Show1(d) end,
  })
  p.list:SetPoint("TOPLEFT", 0, -56)
  p.list:SetWidth(360)
  -- right: the chosen dungeon
  local card = UI:Card(p, true)
  p.card = card
  card:SetPoint("TOPLEFT", p.list, "TOPRIGHT", 12, 0)
  card:SetPoint("BOTTOMRIGHT", -4, 0)
  card.pic = card:CreateTexture(nil, "ARTWORK")
  card.pic:SetSize(64, 64)
  card.pic:SetPoint("TOPLEFT", 16, -14)
  card.title = UI.Display(card, "side", "goldText")
  card.title:SetPoint("TOPLEFT", card.pic, "TOPRIGHT", 14, -4)
  card.title:SetPoint("RIGHT", card, "RIGHT", -16, 0)
  card.title:SetJustifyH("LEFT")
  card.sub = UI.Text(card, "normal", "text")
  card.sub:SetPoint("TOPLEFT", card.title, "BOTTOMLEFT", 0, -6)
  card.sub:SetPoint("RIGHT", card, "RIGHT", -16, 0)
  card.sub:SetJustifyH("LEFT")
  card.entrance = UI:Button(card, "Go to the entrance", 160, function() if p.d and p.d.entrance then M:Go(p.d.entrance) end end)
  card.entrance:SetPoint("TOPLEFT", card.pic, "BOTTOMLEFT", 0, -10)
  UI.SetPrimary(card.entrance, true)
  UI.Tip(card.entrance, "Go to the entrance", "Points the gold arrow at the dungeon's entrance.")
  card.wont = UI:Button(card, "Won't do", 110, function()
    if not p.d then return end
    s().wontDo[p.d.name] = (not s().wontDo[p.d.name]) or nil
    p:Refresh()
  end)
  card.wont:SetPoint("LEFT", card.entrance, "RIGHT", 8, 0)
  UI.Tip(card.wont, "Won't do", "Hides this dungeon from your list and from Next. Click again to bring it back.")
  card.head = UI.Text(card, "large", "goldText")
  card.head:SetPoint("TOPLEFT", card.entrance, "BOTTOMLEFT", 0, -14)
  card.head:SetText("Quests to take with you")
  card.hint = UI.Text(card, "small", "muted")
  card.hint:SetPoint("LEFT", card.head, "RIGHT", 10, 0)
  card.hint:SetText("click one for the arrow to its giver")
  card.steps = UI:ScrollList(card, {
    rows = 9, rowHeight = 34,
    build = function(row)
      row.icon = row:CreateTexture(nil, "ARTWORK")
      row.icon:SetSize(18, 18)
      row.icon:SetPoint("LEFT", 6, 0)
      row.text:ClearAllPoints()
      row.text:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, 6)
      row.text:SetPoint("RIGHT", row, "RIGHT", -6, 0)
      row.sub = UI.Text(row, "small", "muted")
      row.sub:SetPoint("TOPLEFT", row.text, "BOTTOMLEFT", 0, -2)
      row.sub:SetPoint("RIGHT", row, "RIGHT", -6, 0)
      row.sub:SetJustifyH("LEFT")
      row:SetScript("OnEnter", function(self)
        local st = self.step
        if not st then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(tostring(st.quest), 1, 0.82, 0)
        if st.level then GameTooltip:AddLine("Quest level " .. st.level, 1, 1, 1) end
        GameTooltip:AddLine(string.format("%s, %s%s (%.1f, %.1f)", tostring(st.name), tostring(st.zone), st.place and (", " .. st.place) or "", st.x * 100, st.y * 100), 1, 1, 1)
        if st.note then GameTooltip:AddLine(st.note, 0.8, 0.8, 0.8, true) end
        GameTooltip:AddLine("From the WoW Forever guides, not yet checked in game. Click for the arrow.", 0.55, 0.59, 0.65, true)
        GameTooltip:Show()
      end)
      row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end,
    render = function(row, st)
      row.step = st
      local status = M:Status(st, p.ctx)
      local S = M.STATUS[status]
      row.icon:SetTexture(S.icon)
      row.text:SetText(string.format("%s%s|r  %s%s|r%s", hex(S.color), S.word, hex(status == "later" and "muted" or "text"), tostring(st.quest),
        st.level and string.format("  |cff8f96a6level %d|r", st.level) or ""))
      row.sub:SetText(string.format("%s, %s%s", tostring(st.name), tostring(st.zone), st.place and (" (" .. st.place .. ")") or ""))
    end,
    onClick = function(st) M:Go(st) end,
  })
  card.steps:SetPoint("TOPLEFT", card.head, "BOTTOMLEFT", -6, -8)
  card.steps:SetPoint("RIGHT", card, "RIGHT", -10, 0)
  card.notes = UI.Text(card, "normal", "body")
  card.notes:SetPoint("TOPLEFT", card.steps, "BOTTOMLEFT", 6, -10)
  card.notes:SetPoint("RIGHT", card, "RIGHT", -16, 0)
  card.notes:SetJustifyH("LEFT")
  card.alts = UI.Text(card, "small", "muted")
  card.alts:SetPoint("BOTTOMLEFT", 16, 14)
  card.alts:SetPoint("RIGHT", card, "RIGHT", -16, 0)
  card.alts:SetJustifyH("LEFT")

  function p:Show1(d)
    self.d = d
    if not d then
      card.title:SetText("Dungeon quests and keys")
      card.sub:SetText("Pick a dungeon on the left.")
      card.steps:SetItems({})
      card.notes:SetText("")
      card.alts:SetText("")
      card.entrance:Hide() card.wont:Hide()
      return
    end
    if not (ns.Art and ns.Art:Set(card.pic, "dungeon_" .. d.name:lower():gsub("[^%a]", ""), "Interface\\Icons\\INV_Misc_Key_14")) then
      card.pic:SetTexture("Interface\\Icons\\INV_Misc_Key_14")
    end
    card.title:SetText(d.name)
    local fit = M.Fit(d, self.ctx.level)
    local fitWord = fit == "ready" and (hex("good") .. "right for your level|r") or fit == "low" and (hex("bad") .. "a bit high for you|r")
      or (hex("muted") .. "below your level: little XP|r")
    local done, total = M:Progress(d, self.ctx)
    card.sub:SetText(string.format("Levels %d-%d, %s.  %s", d.lo, d.hi, fitWord,
      total > 0 and string.format("%d of %d quests done.", done, total) or "No quests known for your side."))
    card.entrance:SetShown(d.entrance ~= nil)
    card.wont:Show()
    card.wont.label:SetText(s().wontDo[d.name] and "Bring it back" or "Won't do")
    card.steps:SetItems(d.steps)
    local lines = {}
    if d.entrance and d.entrance.note then lines[#lines + 1] = hex("gold") .. "Entrance:|r " .. d.entrance.note end
    if d.wings then
      local w = {}
      for _, wing in ipairs(d.wings) do w[#w + 1] = string.format("%s %d-%d", wing[1], wing[2], wing[3]) end
      lines[#lines + 1] = hex("gold") .. "Wings:|r " .. table.concat(w, ", ")
    end
    for _, n in ipairs(d.notes) do lines[#lines + 1] = hex("gold") .. "Good to know:|r " .. n end
    card.notes:SetText(table.concat(lines, "\n"))
    local alts = M:Alts(d)
    local parts = {}
    for _, a in ipairs(alts) do parts[#parts + 1] = string.format("%s%s %d/%d|r", a.me and hex("goldText") or "", a.name, a.done, a.total) end
    card.alts:SetText(#parts > 0 and ("Your characters: " .. table.concat(parts, ",  ")) or "")
  end

  function p:Refresh()
    self.ctx = M:Context()
    local set = s()
    for _, c in ipairs(self.chips) do c:SetOn(c.key == set.filter) end
    local shown = {}
    for _, d in ipairs(M:Chains()) do
      local done, total = M:Progress(d, self.ctx)
      local complete = total > 0 and done == total
      local wont = set.wontDo[d.name]
      local keep
      if set.filter == "wont" then keep = wont
      elseif set.filter == "done" then keep = complete and not wont
      elseif set.filter == "all" then keep = not wont
      else keep = not wont and not complete and M.Fit(d, self.ctx.level) ~= "high" end
      if keep then shown[#shown + 1] = d end
    end
    self.list:SetItems(shown)
    local best, unlock = M:Next(self.ctx)
    self.next:SetText(best and string.format("Next: %s (%d-%d)%s", best.name, best.lo, best.hi,
        unlock and string.format("   |cff8f96a6then %s opens at level %d|r", unlock.name, unlock.lo) or "")
      or unlock and string.format("Next: %s at level %d", unlock.name, unlock.lo) or "")
    local pick
    for _, d in ipairs(shown) do if d.name == set.picked then pick = d end end
    self:Show1(pick or shown[1])
  end
end, 13.5)

function M:Activity()
  local n, q = 0, 0
  for _, d in ipairs(self:Chains()) do n = n + 1 q = q + #d.steps end
  local best = self:Next()
  return string.format("%d dungeons, %d quests for your side%s", n, q, best and ("; next: " .. best.name) or "")
end

-- Report a wrong step (Attune's biggest complaint is bad chain data): kept in
-- your settings and written to the log so it gets fixed.
ns.AddCommand("dqwrong", "dqwrong <quest name> [what's wrong]  note a wrong dungeon quest step", function(arg)
  arg = tostring(arg or "")
  if arg == "" then ns.Print("usage: /ride dqwrong <quest name> [what's wrong]") return end
  local list = M:Settings().wrong
  list[#list + 1] = { t = time(), text = arg }
  M:Info("dungeon quest reported wrong: %s", arg)
  ns.Print("noted: %s", arg)
end)
