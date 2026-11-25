-- Intelligence/Expedition.lua  (OI07-02 lesson contract, OI07-03 curriculum, OI07-04 delivery, OI07-05 practice)
-- Short lessons about playing your class, offered when they fit you.
-- OI07-02 contract: a lesson is { id (versioned "class.topic.n@v"), class,
--   role (optional), topic = fundamentals | survival | utility | group,
--   minLevel, needs = { spell names }, practice (safe: alone, a training
--   dummy or an easy mob), source }. Its words live apart in L[id] (title,
--   text, objective, check = { question, answers, right }) so they can be
--   translated. A lesson whose spell you don't know is skipped, never
--   rewritten to fit. Lessons are words only: nothing presses keys or casts.
-- OI07-03 curriculum: four lessons per class (fundamentals, survival,
--   utility, group), with role variants for the hybrid classes. They use the
--   spells the Fight macros already use, from the Forever levelling guides
--   cited in Modules/ClassFight.lua (read 2026-11-16) and Gary's hunter tests
--   (FOREVER_CONSTRAINTS); they describe how to practise, not numbers, and
--   stay unverified until seen on Forever.
-- OI07-04 delivery: Offer() picks the lessons you're eligible for (class,
--   role, level, the spells your spellbook has), topics you chose first, not
--   done or skipped; never in combat; you can skip one, switch lessons off,
--   or reset. Nothing is guessed about your skill.
-- OI07-05 practice: Practice(lesson) is the exercise; with training-dummy
--   fights recorded (TalentSim) a check compares only like with like
--   (Forge.Calibrate: same build, similar length); without them it is
--   practice in words only. A knowledge check is voluntary.

local _, ns = ...
local C = ns.Compat
local X = { VERSION = 1 }
ns.Expedition = X
X.TOPICS = { "fundamentals", "survival", "utility", "group" }
local GUIDE = "WoW Forever levelling guides cited in Modules/ClassFight.lua (read 2026-11-16); unverified on Forever"
local HUNTER = "Gary's hunter fight tests (docs/FOREVER_CONSTRAINTS.md C16b, 2026-11-12) and the hunter guides"

-- the contract records (no words here)
X.LESSONS = {
  { id = "hunter.fundamentals.1@1", class = "HUNTER", topic = "fundamentals", minLevel = 1, needs = { "Auto Shot" }, source = HUNTER },
  { id = "hunter.survival.1@1", class = "HUNTER", topic = "survival", minLevel = 8, needs = { "Raptor Strike" }, source = HUNTER },
  { id = "hunter.utility.1@1", class = "HUNTER", topic = "utility", minLevel = 10, needs = { "Tame Beast" }, source = HUNTER },
  { id = "hunter.group.1@1", class = "HUNTER", topic = "group", minLevel = 10, needs = {}, source = GUIDE },
  { id = "warrior.fundamentals.1@1", class = "WARRIOR", topic = "fundamentals", minLevel = 1, needs = { "Heroic Strike" }, source = GUIDE },
  { id = "warrior.survival.1@1", class = "WARRIOR", topic = "survival", minLevel = 6, needs = {}, source = GUIDE },
  { id = "warrior.utility.1@1", class = "WARRIOR", topic = "utility", minLevel = 4, needs = { "Charge" }, source = GUIDE },
  { id = "warrior.group.1@1", class = "WARRIOR", role = "tank", topic = "group", minLevel = 10, needs = {}, source = GUIDE },
  { id = "rogue.fundamentals.1@1", class = "ROGUE", topic = "fundamentals", minLevel = 1, needs = { "Sinister Strike" }, source = GUIDE },
  { id = "rogue.survival.1@1", class = "ROGUE", topic = "survival", minLevel = 8, needs = { "Evasion" }, source = GUIDE },
  { id = "rogue.utility.1@1", class = "ROGUE", topic = "utility", minLevel = 1, needs = { "Stealth" }, source = GUIDE },
  { id = "rogue.group.1@1", class = "ROGUE", topic = "group", minLevel = 12, needs = { "Kick" }, source = GUIDE },
  { id = "mage.fundamentals.1@1", class = "MAGE", topic = "fundamentals", minLevel = 1, needs = { "Fireball" }, source = GUIDE },
  { id = "mage.survival.1@1", class = "MAGE", topic = "survival", minLevel = 10, needs = { "Frost Nova" }, source = GUIDE },
  { id = "mage.utility.1@1", class = "MAGE", topic = "utility", minLevel = 1, needs = { "Arcane Intellect" }, source = GUIDE },
  { id = "mage.group.1@1", class = "MAGE", topic = "group", minLevel = 10, needs = {}, source = GUIDE },
  { id = "warlock.fundamentals.1@1", class = "WARLOCK", topic = "fundamentals", minLevel = 1, needs = { "Shadow Bolt" }, source = GUIDE },
  { id = "warlock.survival.1@1", class = "WARLOCK", topic = "survival", minLevel = 6, needs = { "Life Tap" }, source = GUIDE },
  { id = "warlock.utility.1@1", class = "WARLOCK", topic = "utility", minLevel = 1, needs = { "Demon Skin" }, source = GUIDE },
  { id = "warlock.group.1@1", class = "WARLOCK", topic = "group", minLevel = 10, needs = {}, source = GUIDE },
  { id = "priest.fundamentals.1@1", class = "PRIEST", topic = "fundamentals", minLevel = 1, needs = { "Smite" }, source = GUIDE },
  { id = "priest.survival.1@1", class = "PRIEST", topic = "survival", minLevel = 6, needs = { "Power Word: Shield" }, source = GUIDE },
  { id = "priest.utility.1@1", class = "PRIEST", topic = "utility", minLevel = 1, needs = { "Power Word: Fortitude" }, source = GUIDE },
  { id = "priest.group.1@1", class = "PRIEST", role = "heal", topic = "group", minLevel = 10, needs = { "Lesser Heal" }, source = GUIDE },
  { id = "druid.fundamentals.1@1", class = "DRUID", topic = "fundamentals", minLevel = 1, needs = { "Wrath" }, source = GUIDE },
  { id = "druid.survival.1@1", class = "DRUID", topic = "survival", minLevel = 4, needs = { "Rejuvenation" }, source = GUIDE },
  { id = "druid.utility.1@1", class = "DRUID", topic = "utility", minLevel = 1, needs = { "Mark of the Wild" }, source = GUIDE },
  { id = "druid.group.1@1", class = "DRUID", role = "heal", topic = "group", minLevel = 10, needs = { "Healing Touch" }, source = GUIDE },
  { id = "druid.group.2@1", class = "DRUID", role = "tank", topic = "group", minLevel = 10, needs = { "Bear Form" }, source = GUIDE },
  { id = "shaman.fundamentals.1@1", class = "SHAMAN", topic = "fundamentals", minLevel = 1, needs = { "Lightning Bolt" }, source = GUIDE },
  { id = "shaman.survival.1@1", class = "SHAMAN", topic = "survival", minLevel = 1, needs = { "Healing Wave" }, source = GUIDE },
  { id = "shaman.utility.1@1", class = "SHAMAN", topic = "utility", minLevel = 8, needs = { "Lightning Shield" }, source = GUIDE },
  { id = "shaman.group.1@1", class = "SHAMAN", topic = "group", minLevel = 10, needs = {}, source = GUIDE },
  { id = "paladin.fundamentals.1@1", class = "PALADIN", topic = "fundamentals", minLevel = 1, needs = { "Seal of Righteousness" }, source = GUIDE },
  { id = "paladin.survival.1@1", class = "PALADIN", topic = "survival", minLevel = 1, needs = { "Holy Light" }, source = GUIDE },
  { id = "paladin.utility.1@1", class = "PALADIN", topic = "utility", minLevel = 4, needs = { "Blessing of Might" }, source = GUIDE },
  { id = "paladin.group.1@1", class = "PALADIN", topic = "group", minLevel = 10, needs = {}, source = GUIDE },
}

-- the words (English); a translation replaces L, not the records
local L = {}
X.L = L
local function add(id, title, text, objective, practice, q, answers, right)
  L[id] = { title = title, text = text, objective = objective, practice = practice,
    check = q and { question = q, answers = answers, right = right } or nil }
end
add("hunter.fundamentals.1@1", "Start the shot once", "Auto Shot keeps firing by itself. Pressing it again can restart the shot, so your Fight key starts it once per pull.",
  "Pull with your Fight key and let Auto Shot run.", "A training dummy: press Fight once, then only your other shots.",
  "What does pressing Auto Shot again do?", { "Nothing", "It can restart the shot", "It doubles the damage" }, 2)
add("hunter.survival.1@1", "Too close to shoot", "When a mob reaches you, ranged shots are refused. Your melee key (Raptor Strike) is the one to press then.",
  "Switch to your melee key when a mob is next to you.", "An easy mob: let it reach you and use the melee key.",
  "A mob is next to you. Which key?", { "Ranged Fight key", "Melee key" }, 2)
add("hunter.utility.1@1", "A pet that fits", "Tame a beast near your level; the Tame key targets and tames in one press. Feed it to keep it happy.",
  "Tame a beast and keep it fed.", "Find a beast near your level, out of other mobs' reach.")
add("hunter.group.1@1", "Pet in groups", "In a group, keep the pet from pulling extra mobs: set it to defensive and let the tank start.",
  "Keep your pet defensive in dungeons.", "Before a dungeon, check your pet's stance.")
add("warrior.fundamentals.1@1", "Rage comes from fighting", "Rage builds as you hit and are hit. Spend it on Heroic Strike when you have spare.",
  "Use Heroic Strike when your rage bar has room to spare.", "A training dummy: watch rage build, then spend it.")
add("warrior.survival.1@1", "Rest between pulls", "Warriors don't heal themselves: eat between fights so each pull starts at full health.",
  "Start each fight at full health.", "After a fight, eat before the next pull.")
add("warrior.utility.1@1", "Charge to start", "Charge closes the distance and gives rage, but only from a distance and out of combat.",
  "Open a fight with Charge.", "An easy mob: step back and Charge in.")
add("warrior.group.1@1", "Hold their attention", "As a tank, hit each mob so it stays on you; mark the one to kill first.",
  "Keep mobs on you in a group.", "With a friend: pull two mobs and keep both on you.")
add("rogue.fundamentals.1@1", "Builders and finishers", "Sinister Strike builds combo points; a finisher spends them.",
  "Build combo points, then finish.", "A training dummy: build to a few points, then use a finisher.")
add("rogue.survival.1@1", "Evasion when it goes wrong", "Evasion helps you dodge for a short time: use it when two mobs are on you.",
  "Use Evasion when you're in trouble.", "An easy pair of mobs: try Evasion when both attack.")
add("rogue.utility.1@1", "Stealth first", "Start fights from Stealth to choose when and where.", "Open fights from Stealth.", "Sneak up on an easy mob.")
add("rogue.group.1@1", "Interrupt casters", "Kick stops a spell being cast; save it for the caster's big spells in a group.",
  "Kick a caster's spell.", "An easy caster mob: Kick when its cast bar shows.")
add("mage.fundamentals.1@1", "Cast from range", "Fireball has a cast time: start it before the mob reaches you.", "Open with a cast from range.", "A training dummy: cast from as far as you can.")
add("mage.survival.1@1", "Freeze and step back", "Frost Nova holds nearby mobs in place: use it, step away, and keep casting.",
  "Use Frost Nova and move away.", "An easy mob: let it reach you, Nova, step back.")
add("mage.utility.1@1", "Buff yourself and friends", "Arcane Intellect lasts a while: put it on yourself and your group before fights.",
  "Keep Arcane Intellect up.", "Check your buffs before a pull.")
add("mage.group.1@1", "Let the tank go first", "In a group, wait a moment after the tank pulls so mobs stay on the tank.",
  "Start damage after the tank has the mobs.", "In a dungeon, count two seconds after the pull.")
add("warlock.fundamentals.1@1", "Shadow Bolt and your demon", "Send your demon in, then cast Shadow Bolt.", "Pull with your demon, then cast.", "A training dummy: demon first, then Shadow Bolt.")
add("warlock.survival.1@1", "Health for mana", "Life Tap turns health into mana; use it when your health is high and mana low.",
  "Life Tap only with health to spare.", "Between fights, Life Tap and then eat or bandage.")
add("warlock.utility.1@1", "Armour up", "Keep your armour spell up before every fight.", "Keep your armour spell on.", "Check your buffs before a pull.")
add("warlock.group.1@1", "Keep the demon on your target", "In a group, send your demon at the tank's target so it doesn't pull extra mobs.",
  "Demon attacks the tank's target.", "In a dungeon, use your demon on the marked target.")
add("priest.fundamentals.1@1", "Smite and your wand", "Cast Smite to start, then save mana with a wand once you have one.", "Open with Smite.", "A training dummy: a cast, then a wand.")
add("priest.survival.1@1", "Shield before it hurts", "Power Word: Shield soaks damage: put it on before you're hit.",
  "Shield yourself before a pull.", "An easy mob: shield first, then fight.")
add("priest.utility.1@1", "Fortitude for everyone", "Power Word: Fortitude gives health: keep it on yourself and your group.",
  "Keep Fortitude up.", "Check your buffs before a pull.")
add("priest.group.1@1", "Healing the group", "As a healer, watch the tank's health first and heal early with small heals.",
  "Heal the tank before health drops low.", "With a friend: heal them during easy fights.")
add("druid.fundamentals.1@1", "Wrath from range", "Cast Wrath before mobs reach you; Moonfire works while you move.", "Open with Wrath from range.", "A training dummy: Wrath, then Moonfire.")
add("druid.survival.1@1", "Heal over time", "Rejuvenation heals over a few seconds: cast it early, not at the last moment.",
  "Rejuvenation before health is low.", "An easy mob: Rejuvenation while fighting.")
add("druid.utility.1@1", "Mark of the Wild", "Mark of the Wild is a buff for you and your group: keep it on.", "Keep Mark of the Wild up.", "Check your buffs before a pull.")
add("druid.group.1@1", "Healing in a group", "Out of forms, watch the tank's health and heal before it drops low.",
  "Heal the tank early.", "With a friend: heal them during easy fights.")
add("druid.group.2@1", "Bear Form to tank", "In Bear Form you take hits for the group; hit each mob so it stays on you.",
  "Keep mobs on you in Bear Form.", "With a friend: pull two mobs in Bear Form.")
add("shaman.fundamentals.1@1", "Lightning Bolt to open", "Open with Lightning Bolt from range, then fight up close.", "Open with Lightning Bolt.", "A training dummy: a bolt, then melee.")
add("shaman.survival.1@1", "Heal yourself", "Healing Wave has a cast time: heal between hits, before health is low.",
  "Heal before health is low.", "An easy mob: heal once mid-fight.")
add("shaman.utility.1@1", "Lightning Shield", "Lightning Shield hurts what hits you: keep it on while you quest.", "Keep Lightning Shield up.", "Check your buffs before a pull.")
add("shaman.group.1@1", "Totems for the group", "Drop totems where the group fights, not where you stood before the pull.",
  "Place totems near the fight.", "In a dungeon, place totems after the tank pulls.")
add("paladin.fundamentals.1@1", "Seal, then fight", "Put a Seal on before the pull; Judgement uses it on the target.", "Seal before every pull.", "A training dummy: Seal, then Judgement.")
add("paladin.survival.1@1", "Heal between fights", "Holy Light has a cast time: heal between fights or when a mob is stopped.",
  "Heal between fights.", "After a fight, Holy Light instead of eating.")
add("paladin.utility.1@1", "Blessings", "Blessings help you and your group: keep yours on.", "Keep a Blessing up.", "Check your buffs before a pull.")
add("paladin.group.1@1", "Auras for the group", "Your aura helps everyone near you; pick the one your group needs.",
  "Choose an aura for the group.", "In a dungeon, check your aura before the first pull.")

-- OI07-02 check one record against the contract
function X.Check(l)
  if type(l) ~= "table" then return "not a lesson" end
  if type(l.id) ~= "string" or not l.id:match("^[%l]+%.[%l]+%.%d+@%d+$") then return "bad id" end
  if not ns.ClassProfiles or not ns.ClassProfiles.ROLES[l.class] then return "unknown class" end
  local okTopic = false
  for _, t in ipairs(X.TOPICS) do if t == l.topic then okTopic = true end end
  if not okTopic then return "unknown topic" end
  if type(l.needs) ~= "table" then return "needs must be a list" end
  if type(l.source) ~= "string" or l.source == "" then return "no source" end
  if not L[l.id] or not L[l.id].title then return "no words" end
  return nil
end

function X.Store(mod)
  local c = ns.db.char
  c.expedition = ns.KeepTable(c.expedition, "Expedition:char.expedition") or {}
  local s = c.expedition
  s.done = ns.KeepTable(s.done, "Expedition:done") or {}
  s.skipped = ns.KeepTable(s.skipped, "Expedition:skipped") or {}
  s.topics = ns.KeepTable(s.topics, "Expedition:topics") or {}
  s.answers = ns.KeepTable(s.answers, "Expedition:answers") or {}
  if s.on == nil then s.on = true end
  return s
end

local function known(name) return ns.Spellbook and ns.Spellbook.Known and ns.Spellbook:Known(name) and true or false end

-- OI07-04 eligible lessons for this character, in order
function X.Eligible(me)
  local out = {}
  for _, l in ipairs(X.LESSONS) do
    if not X.Check(l) and l.class == me.class and (not l.role or l.role == me.role) and me.level >= (l.minLevel or 1) then
      local ok = true
      for _, sp in ipairs(l.needs) do if not known(sp) then ok = false end end
      if ok then out[#out + 1] = l end
    end
  end
  return out
end

function X.Me()
  local P = ns.ClassProfiles and ns.ClassProfiles.Current and ns.ClassProfiles.Current() or {}
  return { class = ns.PlayerClass(), role = P.role, level = tonumber(C.Readable(C.Call("UnitLevel", "player"))) or 1 }
end

function X.Offer(n)
  if C.InCombat() then return {}, "not in combat" end
  local st = X.Store()
  if not st.on then return {}, "lessons are off" end
  local list = {}
  for _, l in ipairs(X.Eligible(X.Me())) do
    if not st.done[l.id] and not st.skipped[l.id] then list[#list + 1] = l end
  end
  local chosen = {}
  for _, t in ipairs(st.topics) do chosen[t] = true end
  local assigned = st.assigned or {} -- lessons a mentor bundle assigned come first (OI07-06)
  local order = {}
  for i, t in ipairs(X.TOPICS) do order[t] = i end
  table.sort(list, function(a, b)
    local aa, ab = assigned[a.id] and 0 or 1, assigned[b.id] and 0 or 1
    if aa ~= ab then return aa < ab end
    local ca, cb = chosen[a.topic] and 0 or 1, chosen[b.topic] and 0 or 1
    if ca ~= cb then return ca < cb end
    if order[a.topic] ~= order[b.topic] then return order[a.topic] < order[b.topic] end
    return a.id < b.id
  end)
  local out = {}
  for i = 1, math.min(n or 3, #list) do out[i] = list[i] end
  return out
end

function X.Done(id) X.Store().done[id] = time() end
function X.Skip(id) X.Store().skipped[id] = time() end
function X.SetOn(on) X.Store().on = on and true or false end
function X.SetTopics(list) local st = X.Store() st.topics = {} for _, t in ipairs(list or {}) do st.topics[#st.topics + 1] = t end end
-- reset: done and skipped marks are archived first, then cleared
function X.Reset()
  local st = X.Store()
  if ns.Archive and ns.Archive.Put then ns.Archive:Put("expeditionProgress", { done = st.done, skipped = st.skipped, answers = st.answers }, { path = "char.expedition", scope = "char" }) end
  st.done, st.skipped, st.answers = {}, {}, {}
end

-- OI07-05 practice and a voluntary check
function X.Practice(l, fights, cond)
  local w = L[l.id] or {}
  local out = { text = w.practice, objective = w.objective }
  local F = ns.Forge
  if fights and #fights > 0 and F and cond and cond.estimate then
    out.check = F.Calibrate(cond.estimate, fights, cond)
  else
    out.check = { verdict = "practice only: no matching training-dummy fights recorded to compare" }
  end
  return out
end

function X.Answer(id, choice)
  local w = L[id]
  if not (w and w.check) then return nil, "this lesson has no question" end
  local right = choice == w.check.right
  X.Store().answers[id] = { right = right, at = time() }
  return right
end

-- for the page
function X.Cards(refresh)
  local function again() if refresh then refresh() end end
  local list, why = X.Offer(3)
  local out = {}
  if why then out[1] = { title = "Lessons", line = why == "lessons are off" and "Lessons are off." or "Lessons wait until the fight is over.",
    actions = why == "lessons are off" and { { "Turn lessons on", function() X.SetOn(true) again() end, "Offer short lessons for your class again." } } or nil }
    return out end
  for _, l in ipairs(list) do
    local w = L[l.id]
    out[#out + 1] = { title = w.title, tags = { { l.topic, "plain" } },
      line = w.text .. " Try it: " .. w.practice .. " (Source: " .. l.source .. ".)",
      actions = { { "Done", function() X.Done(l.id) again() end, "Mark this lesson done." },
        { "Skip", function() X.Skip(l.id) again() end, "Don't show this lesson again." } } }
  end
  if #out == 0 then out[1] = { title = "Lessons", line = "No new lesson fits you right now. New spells and levels bring more." } end
  out[#out + 1] = { title = "Lesson settings", line = "Lessons are short tips; nothing is pressed for you.",
    actions = { { "Turn lessons off", function() X.SetOn(false) again() end, "Stop offering lessons." },
      { "Start over", function() X.Reset() again() end, "Show done and skipped lessons again (your marks are archived)." } } }
  return out
end

-- the Lessons page (Class > Lessons): lessons first, then explorer challenges
ns.Hub:AddTab("lessons", "Lessons", function(p)
  ns.UI:FormPage(p, {
    { "header", "Lessons for you", icon = "INV_Misc_Book_09" },
    { "note", "Short tips for your class and role, picked from the spells you know. Nothing is pressed for you." },
    { "cards", function() return X.Cards(function() p:Refresh() end) end },
    { "header", "Explorer challenges", icon = "INV_Misc_Spyglass_03" },
    { "cards", function() return ns.Challenges and ns.Challenges.Cards(function() p:Refresh() end) or {} end },
  })
end)
