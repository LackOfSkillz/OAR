-- Intelligence/Outcomes.lua  (OI03-02)
-- Observed outcomes for AfterAction: what actually happened, as v4
-- OutcomeEvent records (Intelligence/Contracts.lua). Opt-in (off by default,
-- like the XP recorder), per character, bounded (MAX), and the oldest go to the
-- archive ("outcomeEvents"), never deleted.
--
-- Recorded from the game's own events, never the combat log:
--   quest_accepted / quest_completed / quest_abandoned (QUEST_ACCEPTED,
--     QUEST_TURNED_IN, QUEST_REMOVED without a turn-in), xp_gain (a quest's
--     reported XP), level_up, money_in / money_out (PLAYER_MONEY, with the
--     Ledger's window context), gear_equipped (PLAYER_EQUIPMENT_CHANGED),
--     profession_skill (a rank going up), death (PLAYER_DEAD), recovery
--     (PLAYER_UNGHOST, or PLAYER_ALIVE when not a ghost), zone_entered.
-- Rules:
--   * one record per real happening: a semantic key (kind, subject, amount)
--     seen again inside DEDUP seconds is the same event;
--   * a value the client hides (a secret) or doesn't give is left out and its
--     field named in unknownFields, never guessed;
--   * only this character: a record for another characterKey is refused;
--   * a record observed before this play session started, or reported more
--     than LATE seconds after it happened, is marked late;
--   * attribution is "likely" only when the player pressed Go on a plan step
--     (NexusCore:Act, announced as OTR_NEXUS_ACTED) about the same thing (quest, item or map) within
--     ATTRIBUTION_WINDOW, and the record isn't late; otherwise "unknown".
--     Nothing is ever "direct": an outcome after a suggestion is not proof
--     that the suggestion caused it.

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("Outcomes", {
  title = "Outcome recorder (private, opt-in)", phase = "P9", order = 99,
  defaultEnabled = false, defaults = { chronicleHide = {}, keep = {} },
})
ns.Outcomes = M

M.SCHEMA, M.MAX, M.LATE, M.ATTRIBUTION_WINDOW = 1, 500, 60, 1800
M.DEDUP = { money_in = 1, money_out = 1, xp_gain = 2, default = 10 }

-- OI03-15: per-character retention caps, each within bounds; past a cap the
-- oldest records go to the archive (never deleted). keep = { events, travel,
-- activity, sales, chronicle } in this module's settings.
M.CAPS = { events = { 500, 100, 2000 }, travel = { 200, 50, 500 }, activity = { 20, 5, 60 },
  sales = { 200, 50, 500 }, chronicle = { 300, 100, 1000 } }
function M:Cap(name)
  local c = M.CAPS[name]
  if not c then return nil end
  local keep = self.Settings and self:Settings().keep
  local v = type(keep) == "table" and tonumber(keep[name]) or nil
  if not v then return c[1] end
  return math.max(c[2], math.min(c[3], math.floor(v)))
end
M.KINDS = { quest_accepted = true, quest_completed = true, quest_abandoned = true, xp_gain = true, level_up = true,
  money_in = true, money_out = true, gear_equipped = true, profession_skill = true, death = true, recovery = true,
  zone_entered = true }

function M:Store()
  local c = ns.db.char
  local s = ns.KeepTable(c.outcomes, "Outcomes:char.outcomes")
  if type(s) ~= "table" or s.schema ~= M.SCHEMA then
    -- OI-FR03: replace the old store only once it is safely kept; if it can't
    -- be kept, leave it saved as it is and work on a copy that isn't saved
    if type(s) == "table" and not ns.Archive:Preserve("outcomeEvents", s, { path = "char.outcomes", scope = "char" }) then
      M.recovery = "old outcome records could not be archived; they are left as they were"
      M.scratch = M.scratch or { schema = M.SCHEMA, events = {}, serial = 0, recovery = true }
      return M.scratch
    end
    s = { schema = M.SCHEMA, events = {}, serial = 0 }
    c.outcomes = s
  end
  s.events = ns.KeepTable(s.events, "Outcomes:char.outcomes.events") or {}
  s.serial = tonumber(s.serial) or 0
  return s
end

local function readable(v)
  if v == nil or C.IsSecret(v) then return nil end
  return C.Readable(v)
end

function M.CharacterKey()
  local P = ns.ClassProfiles
  local st = P and P.StateV4 and P.StateV4()
  return st and st.characterKey
end

-- the subjects a plan step is about, for attribution
function M.Subjects(cand)
  local out = {}
  if type(cand) ~= "table" then return out end
  if tonumber(cand.questID) then out["quest:" .. tonumber(cand.questID)] = true end
  if tonumber(cand.itemID) then out["item:" .. tonumber(cand.itemID)] = true end
  if tonumber(cand.mapID) then out["map:" .. tonumber(cand.mapID)] = true end
  return out
end

function M:Attribute(rec)
  local a = self.lastActed
  if rec.late or not (a and rec.subject and a.subjects and a.subjects[rec.subject]) then return "unknown" end
  if rec.at < a.at or rec.at - a.at > M.ATTRIBUTION_WINDOW then return "unknown" end
  return "likely", a.planId, a.stepId
end

-- Record one outcome. f: { subject, amount, context, at, characterKey } (all
-- optional). Returns the stored record, or nil, why.
function M:Record(kind, f)
  if not M.KINDS[kind] then return nil, "kind" end
  f = f or {}
  local now = time()
  local mine = M.CharacterKey()
  if not mine then return nil, "no character key" end
  if f.characterKey ~= nil and f.characterKey ~= mine then return nil, "other character" end
  local unknown = {}
  local function field(name, v)
    if v == nil then return nil end
    if C.IsSecret(v) then unknown[#unknown + 1] = name return nil end
    return C.Readable(v)
  end
  local subject = field("subject", f.subject)
  if f.subjectUnknown then unknown[#unknown + 1] = "subject" end
  local amount = field("amount", f.amount)
  if f.amountUnknown then unknown[#unknown + 1] = "amount" end
  amount = tonumber(amount)
  if amount then amount = math.floor(amount) end
  local at = tonumber(f.at) or now
  if at > now + 5 then return nil, "future" end
  local P = ns.PlaySession
  local sid = P and P:Id() or ("local:" .. tostring(ns.session or "s"))
  local started = P and P:Current().startedAt
  local late = (now - at > M.LATE) or (started and at < started) or nil
  -- one record per real happening
  local store = self:Store()
  local key = kind .. "|" .. tostring(subject) .. "|" .. tostring(amount)
  self.recent = self.recent or {}
  local prev = self.recent[key]
  if prev and math.abs(at - prev) <= (M.DEDUP[kind] or M.DEDUP.default) then return nil, "duplicate" end
  self.recent[key] = at
  store.serial = store.serial + 1
  local rec = { eventId = string.format("out:%s:%d", tostring(ns.session or "s"), store.serial), kind = kind,
    characterKey = mine, sessionId = sid, at = math.floor(at), subject = subject, amount = amount,
    context = type(f.context) == "string" and f.context:sub(1, 60) or nil, late = late and true or nil,
    unknownFields = #unknown > 0 and unknown or nil }
  local attribution, planId, stepId = self:Attribute(rec)
  rec.attribution, rec.planId, rec.stepId = attribution, planId, stepId
  local ok, bad = ns.Nexus.Validate("OutcomeEvent", rec)
  if not ok then store.serial = store.serial - 1 return nil, "invalid " .. tostring(bad) end
  store.events[#store.events + 1] = rec
  while #store.events > self:Cap("events") and ns.Archive:Shift("outcomeEvents", store.events, { path = "char.outcomes.events", scope = "char" }) do end
  ns.Events:Fire("OTR_OUTCOME", rec)
  return rec
end

-- ------------------------------------------------------------ game events
local function questArg(a, b)
  local id = tonumber(readable(b)) or tonumber(readable(a))
  return id and id > 0 and id or nil
end

function M:Professions()
  local out = {}
  local list = { C.Call("GetProfessions") }
  for _, idx in pairs(list) do
    if type(idx) == "number" then
      local name, _, rank = C.Call("GetProfessionInfo", idx)
      name, rank = readable(name), tonumber(readable(rank))
      if type(name) == "string" and rank then out[name] = rank end
    end
  end
  return out
end

function M:OnDisable()
  if ns.ActivityTimeline then ns.ActivityTimeline:Stop() end
  if ns.TravelTimes then ns.TravelTimes:Stop(self) end
end

function M:OnEnable()
  self:Store()
  -- what the time went to (OI03-03), in the same store and under the same switch
  if ns.ActivityTimeline then ns.ActivityTimeline:Start(self) ns.ActivityTimeline:Wire(self) end
  -- real trip times to the destinations you set (OI03-05)
  if ns.TravelTimes then ns.TravelTimes:Wire(self) end
  -- confirmed sales, transfers, deposits (OI03-06)
  if ns.EconomyOutcomes then ns.EconomyOutcomes:Wire(self) end
  -- milestones and your choices, in order (OI03-08)
  if ns.Chronicle then ns.Chronicle:Wire(self) end
  -- the player's Go on a plan step (NexusCore:Act), kept in memory only
  self:On("OTR_NEXUS_ACTED", function(mod, _, info)
    if type(info) ~= "table" then return end
    mod.lastActed = { planId = info.planId, stepId = info.stepId, at = tonumber(info.at) or time(), subjects = M.Subjects(info) }
  end)
  self.money = tonumber(readable(C.Call("GetMoney")))
  self.ranks = self:Professions()
  self.turnedIn = {}
  self:On("QUEST_ACCEPTED", function(mod, _, a, b)
    local q = questArg(a, b)
    mod:Record("quest_accepted", { subject = q and ("quest:" .. q), subjectUnknown = not q })
  end)
  self:On("QUEST_TURNED_IN", function(mod, _, questID, xp)
    local q = questArg(questID)
    mod.turnedIn[q or 0] = time()
    mod:Record("quest_completed", { subject = q and ("quest:" .. q), subjectUnknown = not q })
    local x = tonumber(readable(xp))
    if x and x > 0 then mod:Record("xp_gain", { subject = q and ("quest:" .. q), amount = x }) end
  end)
  self:On("QUEST_REMOVED", function(mod, _, questID)
    local q = questArg(questID)
    if not q then return end
    -- QUEST_REMOVED also follows a turn-in: wait a moment, then only a quest
    -- that was not turned in counts as abandoned
    mod:After(1, function(m)
      local t = m.turnedIn[q]
      if not (t and time() - t <= 5) then m:Record("quest_abandoned", { subject = "quest:" .. q }) end
    end, "outcomes:abandon")
  end)
  self:On("PLAYER_LEVEL_UP", function(mod, _, level)
    local l = tonumber(readable(level))
    mod:Record("level_up", { subject = l and ("level:" .. l), subjectUnknown = not l })
  end)
  self:On("PLAYER_MONEY", function(mod)
    local now = tonumber(readable(C.Call("GetMoney")))
    if not (now and mod.money) then mod.money = now return end
    local delta = now - mod.money
    mod.money = now
    if delta == 0 then return end
    -- the category of this change (OI03-06): what the gold actually did
    local L = ns.Ledger
    local ctx = L and L.Context and L:Context() or nil
    local cat = ns.EconomyOutcomes and ns.EconomyOutcomes:Classify(delta, ctx) or ctx
    mod:Record(delta > 0 and "money_in" or "money_out", { amount = math.abs(delta), context = cat })
  end)
  self:On("PLAYER_EQUIPMENT_CHANGED", function(mod, _, slot, empty)
    local s = tonumber(readable(slot))
    if not s or empty == true then return end
    local id = tonumber(readable(C.Call("GetInventoryItemID", "player", s)))
    mod:Record("gear_equipped", { subject = id and ("item:" .. id), subjectUnknown = not id, context = "slot " .. s })
  end)
  local function skills(mod)
    local now = mod:Professions()
    for name, rank in pairs(now) do
      local was = mod.ranks[name]
      if was and rank > was then mod:Record("profession_skill", { subject = "prof:" .. name:gsub("[^%w]", ""), amount = rank - was }) end
    end
    mod.ranks = now
  end
  self:On("SKILL_LINES_CHANGED", skills)
  self:On("TRADE_SKILL_LIST_UPDATE", skills)
  self:On("PLAYER_DEAD", function(mod) mod:Record("death", {}) end)
  self:On("PLAYER_UNGHOST", function(mod) mod:Record("recovery", { context = "back to life" }) end)
  self:On("PLAYER_ALIVE", function(mod)
    -- PLAYER_ALIVE also fires on release (as a ghost): only a real return counts
    if C.Call("UnitIsGhost", "player") ~= true then mod:Record("recovery", { context = "resurrected" }) end
  end)
  self:On("ZONE_CHANGED_NEW_AREA", function(mod)
    local id = C.PlayerPosition("player")
    id = tonumber(readable(id))
    mod:Record("zone_entered", { subject = id and ("map:" .. id), subjectUnknown = not id })
  end)
end

-- "Start fresh": this character's whole record goes to the archive
-- (outcomesReset), then a new one begins; the working state built on it (the
-- open timeline segment, an open trip, the duplicate filter) starts over too.
-- Under the owner's data preservation rule this is what "reset" and "delete"
-- mean here: nothing is destroyed, and if archiving fails nothing changes.
function M:StartFresh()
  local old = ns.db.char.outcomes
  if type(old) == "table" and next(old) ~= nil and not ns.Archive:Put("outcomesReset", old, { path = "char.outcomes", scope = "char" }) then
    return false, "couldn't archive, so nothing was reset"
  end
  ns.db.char.outcomes = nil
  self.recent, self.lastActed = {}, nil
  if ns.TravelTimes then ns.TravelTimes:Reset() end
  self:Store()
  if self.enabled and ns.ActivityTimeline then ns.ActivityTimeline:Start(self) end
  return true
end

-- all of this character's records as one data code (OTR1) to copy; nothing is sent
function M:ExportText()
  local store = self:Store()
  local n = #store.events
  return string.format("Outrider outcome records: %d events, %d trips, %d chronicle entries.\n", n, #(store.travel or {}), #(store.chronicle or {}))
    .. ns.Serialize.Export(store)
end

function M:Recent(n)
  local ev = self:Store().events
  local out = {}
  for i = #ev, math.max(1, #ev - (n or 20) + 1), -1 do out[#out + 1] = ev[i] end
  return out
end

function M:Activity()
  local line = string.format("%d outcomes recorded", #self:Store().events)
  if M.recovery then line = line .. "; " .. M.recovery end
  return line
end
