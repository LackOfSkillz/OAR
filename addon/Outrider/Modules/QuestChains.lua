-- Modules/QuestChains.lua
-- Quest chains, step by step (requirement 2026-11-21: show which steps in a
-- chain are complete; clicking an unfinished step sets the arrow and pin
-- to it).
-- From the quest pack (Outrider_Data_Quests, QuestieDB, community data):
-- info[id].pa / .pl = quests that must come first (any / all), info[id].n =
-- the next quest. Givers from the NPC pack (quest givers carry the quests
-- they start) and the pack's object starters; finishers from quests[id].fin.
-- Status from the game: completed flag, your quest log, else available
-- (everything before it is done) or locked. Click a step: an active quest
-- goes to its objective or turn-in (QuestObjectives:Guide), a quest to pick
-- up goes to its giver. The arrow also puts the pin on the minimap.

local _, ns = ...
local C = ns.Compat
local UI, Theme = ns.UI, ns.Theme
local M = ns:NewModule("QuestChains", {
  title = "Quest chains",
  phase = "P3",
  order = 58,
  defaults = { picked = nil },
})
ns.QuestChains = M

M.MAX = 40 -- steps followed either way; chains are far shorter
M.STATUS = {
  done = { word = "Done", color = "good", icon = "Interface\\RaidFrame\\ReadyCheck-Ready" },
  ready = { word = "Hand in", color = "good", icon = "Interface\\GossipFrame\\ActiveQuestIcon" },
  active = { word = "In your log", color = "gold", icon = "Interface\\GossipFrame\\ActiveQuestIcon" },
  available = { word = "Pick up", color = "text", icon = "Interface\\GossipFrame\\AvailableQuestIcon" },
  locked = { word = "Not yet", color = "muted", icon = "Interface\\RaidFrame\\ReadyCheck-Waiting" },
}

local function readable(v) return C.Readable(v) end
function M:Pack() return ns.QuestObjectives and ns.QuestObjectives.Pack and ns.QuestObjectives:Pack() or nil end

-- questID -> { npcID or objectID, name, mapID, x, y, faction } of who starts it
function M:Starters()
  if self.starters then return self.starters end
  local out = {}
  local npc = rawget(_G, "Outrider_DataNPC")
  for mapID, rows in pairs(type(npc) == "table" and npc.maps or {}) do
    for _, r in ipairs(rows) do
      for _, q in ipairs(ns.KeepTable(r[8], "QuestChains:r[8]") or {}) do
        local id = q[1]
        if id and not out[id] then out[id] = { id = r[1], name = r[5], mapID = mapID, x = r[3], y = r[4], faction = r[7] } end
      end
    end
  end
  local pack = self:Pack()
  for objID, list in pairs(pack and pack.starters or {}) do
    local o = pack.objects and pack.objects[objID]
    local spots = o and o[2]
    for mapID, pts in pairs(type(spots) == "table" and spots or {}) do
      for _, q in ipairs(list) do
        if q[1] and not out[q[1]] and pts[1] then out[q[1]] = { id = objID, name = o[1], mapID = mapID, x = pts[1], y = pts[2], object = true } end
      end
      break
    end
  end
  self.starters = out
  return out
end

-- where a quest is handed in: { name, mapID, x, y } of its first finisher with a spot
function M:Finisher(questID)
  local pack = self:Pack()
  local q = pack and pack.quests[questID]
  for _, npcID in ipairs(type(q) == "table" and q.fin or {}) do
    local n = pack.npcs and pack.npcs[npcID]
    for mapID, pts in pairs(type(n) == "table" and type(n[2]) == "table" and n[2] or {}) do
      if pts[1] then return { name = n[1], mapID = mapID, x = pts[1], y = pts[2] } end
    end
  end
end

-- The whole chain a quest belongs to, oldest first: walk back through what
-- must come first, then forward through "next".
function M:Chain(questID)
  local pack = self:Pack()
  if not (pack and pack.quests[questID]) then return {} end
  local info = pack.info or {}
  local seen, back = {}, {}
  local ctx = self:Context()
  local function before(id, depth)
    if seen[id] or depth > M.MAX then return end
    seen[id] = true
    local i = info[id] or {}
    for _, p in ipairs(i.pl or {}) do before(p, depth + 1) end
    -- "any of these first": follow the one you did (or are doing), else the first
    local pick
    for _, p in ipairs(i.pa or {}) do if ctx.done(p) or ctx.log[p] then pick = p break end end
    pick = pick or (i.pa and i.pa[1])
    if pick then before(pick, depth + 1) end
    back[#back + 1] = id
  end
  before(questID, 0)
  local id, n = (info[questID] or {}).n, 0
  while id and not seen[id] and n < M.MAX and pack.quests[id] do
    seen[id] = true
    back[#back + 1] = id
    id, n = (info[id] or {}).n, n + 1
  end
  return back
end

function M:Context()
  local ctx = { log = {}, complete = {} }
  for _, q in ipairs(ns.QuestObjectives and ns.QuestObjectives.Log and ns.QuestObjectives.Log() or {}) do
    ctx.log[q.questID] = true
    if q.complete then ctx.complete[q.questID] = true end
  end
  ctx.done = function(id) return readable(C.Call("C_QuestLog.IsQuestFlaggedCompleted", id)) == true end
  return ctx
end

function M:Status(id, ctx)
  if ctx.done(id) then return "done" end
  if ctx.log[id] then return ctx.complete[id] and "ready" or "active" end
  local i = (self:Pack() or {}).info
  i = i and i[id] or {}
  for _, p in ipairs(i.pl or {}) do if not ctx.done(p) then return "locked" end end
  if i.pa and #i.pa > 0 then
    local any = false
    for _, p in ipairs(i.pa) do if ctx.done(p) then any = true break end end
    if not any then return "locked" end
  end
  return "available"
end

-- one step for the page: { id, name, level, status, where }
function M:Steps(questID)
  local pack, ctx = self:Pack(), self:Context()
  local out = {}
  for _, id in ipairs(self:Chain(questID)) do
    local q = pack.quests[id]
    local st = self:Status(id, ctx)
    local where
    if st == "available" or st == "locked" then
      local s = self:Starters()[id]
      where = s and { what = "Picked up from", name = s.name, mapID = s.mapID, x = s.x, y = s.y }
    elseif st == "ready" or st == "active" then
      local f = self:Finisher(id)
      where = f and { what = st == "ready" and "Hand in to" or "Hand in to", name = f.name, mapID = f.mapID, x = f.x, y = f.y }
    end
    -- a chain runs in order: nothing is open until the step before it is done
    local prev = out[#out]
    if st == "available" and prev and prev.status ~= "done" then st = "locked" end
    out[#out + 1] = { id = id, name = q[1], level = q[2], status = st, where = where }
  end
  return out
end

-- Click a step: a quest in your log goes to its objective or turn-in, a quest
-- to pick up goes to its giver.
function M:Go(step)
  if (step.status == "active" or step.status == "ready") and ns.QuestObjectives and ns.QuestObjectives:Guide(step.id) then return true end
  local w = step.where
  if w and w.mapID and ns.Waypoints then
    ns.Waypoints:Set(w.mapID, w.x, w.y, string.format("%s: %s", step.name, tostring(w.name)))
    self:Info("chain step %s (%d): %s", tostring(step.name), step.id, tostring(w.name))
    return true
  end
  ns.Print("no location known for %s yet", tostring(step.name))
  return false
end

-- quests in your log that belong to a chain of two or more
function M:LogChains()
  local out = {}
  if not self:Pack() then return out end
  for _, q in ipairs(ns.QuestObjectives and ns.QuestObjectives.Log and ns.QuestObjectives.Log() or {}) do
    local chain = self:Chain(q.questID)
    if #chain > 1 then
      local pos = 1
      for i, id in ipairs(chain) do if id == q.questID then pos = i end end
      out[#out + 1] = { questID = q.questID, title = q.title, pos = pos, total = #chain }
    end
  end
  table.sort(out, function(a, b) return a.title < b.title end)
  return out
end

function M:Activity()
  if not self:Pack() then return "no quest pack installed" end
  return string.format("%d quests in your log are part of a chain", #self:LogChains())
end

-- ------------------------------------------------------------- page
local function hex(c) return Theme:Hex(c) end

ns.Hub:AddTab("questchains", "Quest chains", function(p)
  p.list = UI:ScrollList(p, {
    rows = 18, rowHeight = 26,
    render = function(row, c)
      row.text:SetText(string.format("%s  |cff8f96a6step %d of %d|r", c.title, c.pos, c.total))
    end,
    onClick = function(c) M:Settings().picked = c.questID p:Show1(c) end,
  })
  p.list:SetPoint("TOPLEFT", 0, -4)
  p.list:SetWidth(340)
  local card = UI:Card(p, true)
  p.card = card
  card:SetPoint("TOPLEFT", p.list, "TOPRIGHT", 12, 0)
  card:SetPoint("BOTTOMRIGHT", -4, 0)
  card.title = UI.Display(card, "side", "goldText")
  card.title:SetPoint("TOPLEFT", 16, -14)
  card.title:SetPoint("RIGHT", card, "RIGHT", -16, 0)
  card.title:SetJustifyH("LEFT")
  card.sub = UI.Text(card, "normal", "text")
  card.sub:SetPoint("TOPLEFT", card.title, "BOTTOMLEFT", 0, -6)
  card.sub:SetPoint("RIGHT", card, "RIGHT", -16, 0)
  card.sub:SetJustifyH("LEFT")
  card.steps = UI:ScrollList(card, {
    rows = 12, rowHeight = 36,
    build = function(row)
      row.icon = row:CreateTexture(nil, "ARTWORK")
      row.icon:SetSize(18, 18)
      row.icon:SetPoint("LEFT", 6, 0)
      row.text:ClearAllPoints()
      row.text:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, 7)
      row.text:SetPoint("RIGHT", row, "RIGHT", -6, 0)
      row.sub = UI.Text(row, "small", "muted")
      row.sub:SetPoint("TOPLEFT", row.text, "BOTTOMLEFT", 0, -2)
      row.sub:SetPoint("RIGHT", row, "RIGHT", -6, 0)
      row.sub:SetJustifyH("LEFT")
    end,
    render = function(row, st)
      local S = M.STATUS[st.status]
      row.icon:SetTexture(S.icon)
      row.text:SetText(string.format("%d.  %s%s|r  %s  |cff8f96a6level %s|r", st.n, hex(S.color), S.word, st.name, tostring(st.level or "?")))
      local w = st.where
      row.sub:SetText(st.status == "done" and "" or w and string.format("%s %s%s", w.what, tostring(w.name),
        ns.Travel and ns.Travel.ZoneName and (", " .. tostring(ns.Travel.ZoneName(w.mapID))) or "") or "where: not known yet")
    end,
    onClick = function(st) if st.status ~= "done" then M:Go(st) end end,
  })
  card.steps:SetPoint("TOPLEFT", card.sub, "BOTTOMLEFT", -6, -10)
  card.steps:SetPoint("RIGHT", card, "RIGHT", -10, 0)
  card.note = UI.Text(card, "small", "muted")
  card.note:SetPoint("BOTTOMLEFT", 16, 12)
  card.note:SetPoint("RIGHT", card, "RIGHT", -16, 0)
  card.note:SetJustifyH("LEFT")
  card.note:SetText("Click a step that isn't done: the gold arrow and the minimap pin lead you there. Chains come from community quest data, not yet checked in game.")

  function p:Show1(c)
    if not c then
      card.title:SetText("Quest chains")
      card.sub:SetText(M:Pack() and "None of the quests in your log are part of a chain." or "The quest data pack isn't installed yet.")
      card.steps:SetItems({})
      return
    end
    local steps = M:Steps(c.questID)
    local done, firstOpen = 0, nil
    for i, st in ipairs(steps) do
      st.n = i
      if st.status == "done" then done = done + 1 elseif not firstOpen then firstOpen = st end
    end
    card.title:SetText(c.title)
    card.sub:SetText(string.format("%d of %d steps done.%s", done, #steps,
      firstOpen and string.format("  Next: %s%s|r (%s).", hex("goldText"), firstOpen.name, M.STATUS[firstOpen.status].word:lower()) or ""))
    card.steps:SetItems(steps)
  end

  function p:Refresh()
    local list = M:LogChains()
    self.list:SetItems(list)
    local pick
    for _, c in ipairs(list) do if c.questID == M:Settings().picked then pick = c end end
    self:Show1(pick or list[1])
  end
end, 16.6)
