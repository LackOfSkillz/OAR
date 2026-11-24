-- Modules/QuestsNear.lua  (Quests, "Near me": the first tab of Quests)
-- Requirement 2026-11-21: near Undercity the quest page pointed all the way
-- back to Orgrimmar; the default tab lists quests near the player to do
-- next, based on level, equipment, location, XP per hour and gold
-- per hour.
-- One ranked list of what's worth doing next, from where you stand:
--   * quests in your log: the time to their nearest objective (or turn-in)
--   * quests you can pick up: from the quest pack's givers, for your level,
--     faction, race and class, earlier quests done (NPCPack:AvailableEverywhere)
-- Each gets a time (the trip from Travel, flights and zeppelins included, plus
-- the work: QUEST_TIME, or a short hand-in), its XP (the game's own number for
-- quests in your log, else Journey.XP's estimate), its gold when the game says
-- (quests in your log), and a gear upgrade when the gear pack lists one of its
-- rewards as an upgrade for you (Nearby, scored by GearScore). Ranked by value
-- per minute, where value = XP x level fit + gold (1 silver = 10 XP) + 20 per
-- % of upgrade. Grey and red quests are left out.
-- Click a row: in your log, the quest is guided (QuestObjectives:Guide: the
-- arrow, or the whole trip when it's elsewhere); to pick up, the trip to the giver.

local _, ns = ...
local C = ns.Compat
local UI, Theme = ns.UI, ns.Theme
local M = ns:NewModule("QuestsNear", {
  title = "Quests near me",
  phase = "P3",
  order = 34,
  defaults = {},
})
ns.QuestsNear = M

M.HANDIN = 30            -- seconds to hand in once there
M.MAX = 40
M.FIT = { yellow = 1, orange = 0.9, green = 0.8 }
M.SILVER_XP = 10         -- 1 silver counts like 10 XP in the ranking
M.UPGRADE_XP = 20        -- each % of gear upgrade counts like 20 XP

local function readable(v) return C.Readable(v) end

-- Quest ID -> best gear upgrade among its rewards { name, pct } (gear pack).
function M.Upgrades()
  local out = {}
  for _, c in ipairs(ns.Nearby and ns.Nearby:Candidates({ world = true }) or {}) do
    local q = c.where and c.where.qid
    if q and (not out[q] or c.pct > out[q].pct) then out[q] = { name = c.name, pct = math.floor(c.pct + 0.5) } end
  end
  return out
end

-- Copper the game says a quest in your log pays, or nil.
function M.Gold(questID)
  local v = C.Call("GetQuestLogRewardMoney", questID)
  v = tonumber(readable(v))
  return v and v > 0 and v or nil
end

-- The level colour of a quest level for you (same rules as quest givers).
local function diff(qlevel, level)
  if ns.NPCPack and ns.NPCPack.Difficulty then return ns.NPCPack.Difficulty(qlevel, level) end
  local d = qlevel - level
  return d >= 5 and "red" or d >= 3 and "orange" or d >= -2 and "yellow" or "green"
end

-- Ranked entries: { kind = "log"|"pickup", questID, name, level, diff, ready,
-- target, seconds, xp, gold, upgrade, perMin, score, zone, who }
function M:List()
  local level = C.Call("UnitLevel", "player") or 1
  local prep = ns.Travel and ns.Travel:Prepare()
  local Q = ns.QuestObjectives
  local ups = M.Upgrades()
  local out, inLog = {}, {}
  local xpOf = {}
  if ns.QuestExtras and ns.QuestExtras.QuestXP then
    local _, _, items = ns.QuestExtras:QuestXP()
    -- the game's own number when it gives one (0 means it didn't say)
    for _, it in ipairs(items or {}) do if (it.xp or 0) > 0 then xpOf[it.id] = it.xp end end
  end
  local function finish(e, work)
    if not e.target then return end
    e.zone = ns.Travel.ZoneName(e.target.mapID)
    e.seconds = prep and ns.Travel:TimeTo(prep, e.target) or nil
    local fit = M.FIT[e.diff] or 0
    if fit == 0 then return end
    local value = (e.xp or 0) * fit + (e.gold or 0) / 100 * M.SILVER_XP + (e.upgrade and e.upgrade.pct * M.UPGRADE_XP or 0)
    local minutes = ((e.seconds or 3600) + work) / 60
    e.perMin = (e.xp or 0) / minutes
    e.score = value / minutes
    out[#out + 1] = e
  end
  -- quests in your log
  for _, q in ipairs(Q and Q.enabled and Q.Log and Q.Log() or {}) do
    inLog[q.questID] = true
    local spot = Q:Nearest(q.questID)
    local entry = Q.Pack and Q:Pack() and Q:Pack().quests[q.questID]
    local qlevel = entry and entry[2] or level
    local e = { kind = "log", questID = q.questID, name = q.title, level = qlevel, diff = diff(qlevel, level), ready = q.complete,
      xp = xpOf[q.questID] or (ns.Journey and ns.Journey.XP(qlevel, level)), gold = M.Gold(q.questID), upgrade = ups[q.questID],
      who = spot and spot.label }
    if e.diff == "grey" then e.diff = "green" end -- it's in your log: still worth finishing
    e.target = spot and ns.Travel.Point(spot.mapID, spot.x, spot.y, spot.label)
    finish(e, q.complete and M.HANDIN or (ns.Journey and ns.Journey.QUEST_TIME or 300))
  end
  -- quests you can pick up (nearest giver of each)
  local best = {}
  for _, q in ipairs(ns.NPCPack and ns.NPCPack.AvailableEverywhere and ns.NPCPack:AvailableEverywhere() or {}) do
    if not inLog[q.id] and q.diff ~= "red" and q.diff ~= "grey" then
      local e = { kind = "pickup", questID = q.id, name = q.name, level = q.level, diff = q.diff,
        xp = ns.Journey and ns.Journey.XP(q.level, level), upgrade = ups[q.id], who = q.giver,
        target = ns.Travel.Point(q.mapID, q.x, q.y, q.giver) }
      local cur = best[q.id]
      if e.target then
        e.seconds = prep and ns.Travel:TimeTo(prep, e.target) or nil
        if not cur or (e.seconds or 1e12) < (cur.seconds or 1e12) then best[q.id] = e end
      end
    end
  end
  for _, e in pairs(best) do finish(e, ns.Journey and ns.Journey.QUEST_TIME or 300) end
  table.sort(out, function(a, b)
    if (a.score or 0) ~= (b.score or 0) then return (a.score or 0) > (b.score or 0) end
    if (a.seconds or 1e12) ~= (b.seconds or 1e12) then return (a.seconds or 1e12) < (b.seconds or 1e12) end
    return tostring(a.name) < tostring(b.name)
  end)
  while #out > M.MAX do table.remove(out) end
  return out
end

-- Go: a quest in your log is guided (arrow here, trip elsewhere); a quest to
-- pick up is a trip to its giver.
function M:Go(e)
  if not e then return false end
  if e.kind == "log" and ns.QuestObjectives then return ns.QuestObjectives:Guide(e.questID) end
  if e.target and ns.Journey then
    return ns.Journey:Go({ name = e.name, sub = "pick up from " .. tostring(e.who), target = e.target, seconds = e.seconds })
  end
  return false
end

function M:Activity()
  local list = self:List()
  return #list > 0 and string.format("%d quests worth doing; best: %s", #list, tostring(list[1].name)) or "no quests found for you here yet"
end

-- ---------------------------------------------------------------- page
local COLOR = { yellow = "|cffffd100", orange = "|cffff8040", green = "|cff40c040" }

function M.Line(e)
  local where = e.seconds and string.format("%s, %s away", tostring(e.zone), ns.Travel.Minutes(e.seconds)) or (tostring(e.zone) .. ", no known way yet")
  local what = e.kind == "log" and (e.ready and "|cff40ff40Ready to hand in|r" or "In your log") or ("Pick up from " .. tostring(e.who))
  local bits = { what, where }
  bits[#bits + 1] = string.format("about %d XP a minute", math.floor((e.perMin or 0) + 0.5))
  if e.gold and ns.Prices and ns.Prices.Coins then bits[#bits + 1] = "pays " .. ns.Prices.Coins(e.gold) end
  if e.upgrade then bits[#bits + 1] = string.format("|cff40ff40upgrade: %s (+%d%%)|r", e.upgrade.name, e.upgrade.pct) end
  return string.format("%s%s|r  |cff8f96a6level %d|r", COLOR[e.diff] or "", tostring(e.name), e.level or 0), table.concat(bits, "  ·  ")
end

ns.Hub:AddTab("questsnear", "Near me", function(p)
  p.list = UI:ScrollList(p, {
    rows = 13, rowHeight = 46,
    build = function(row)
      row.icon = row:CreateTexture(nil, "ARTWORK")
      row.icon:SetSize(28, 28)
      row.icon:SetPoint("LEFT", 8, 0)
      row.text:ClearAllPoints()
      row.text:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 10, 4)
      row.text:SetPoint("RIGHT", row, "RIGHT", -90, 0)
      row.sub = UI.Text(row, "small", "muted")
      row.sub:SetPoint("TOPLEFT", row.text, "BOTTOMLEFT", 0, -4)
      row.sub:SetPoint("RIGHT", row, "RIGHT", -90, 0)
      row.sub:SetJustifyH("LEFT")
      row.go = UI.Text(row, "normal", "goldText")
      row.go:SetPoint("RIGHT", -16, 0)
      row.go:SetText("Go  >")
    end,
    render = function(row, e)
      row.icon:SetTexture(e.kind == "log" and (e.ready and "Interface\\GossipFrame\\ActiveQuestIcon" or "Interface\\GossipFrame\\IncompleteQuestIcon")
        or "Interface\\GossipFrame\\AvailableQuestIcon")
      local title, sub = M.Line(e)
      row.text:SetText(title)
      row.sub:SetText(sub)
    end,
    onClick = function(e) M:Go(e) end,
  })
  p.list:SetPoint("TOPLEFT", 0, -4)
  p.list:SetPoint("RIGHT", p, "RIGHT", -4, 0)
  p.empty = UI.Text(p, "normal", "muted")
  p.empty:SetPoint("TOPLEFT", 8, -14)
  p.empty:SetText("No quests found for you yet. Visit a town with quest givers, or open the Quest log tab.")
  p.note = UI.Text(p, "small", "muted")
  p.note:SetPoint("BOTTOMLEFT", 4, 4)
  p.note:SetPoint("RIGHT", p, "RIGHT", -4, 0)
  p.note:SetJustifyH("LEFT")
  p.note:SetText("Best first: XP and gold for the time it takes from where you stand (trip included), how well it fits your level, and gear upgrades. Times and XP are estimates; quest data is community data, unchecked.")
  function p:Refresh()
    local list = M:List()
    self.list:SetItems(list)
    self.empty:SetShown(#list == 0)
  end
end, 11.05)
