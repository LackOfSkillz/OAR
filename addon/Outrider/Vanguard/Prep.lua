-- Vanguard/Prep.lua
-- VG02-08/09/10: your own preparation before a dungeon or raid.
--   Prep.Profile(activity, role, minutes)  the amounts to carry
--   Prep.Supplies(profile)    food, drink, ammo, reagents, repair, bag space
--   Prep.Equipment(profile)   empty slots, enchants, access, your own items
--   Prep.Journal(instance)    missing quests and upgrades there (existing pages)
-- Rules:
--   * Carried only counts as ready. What's in the bank is shown apart
--     ("N more in the bank") and never counted as carried.
--   * Amounts are Outrider's starting points, not game data, and you can see
--     where each comes from; your own checklist items are marked as yours and
--     can't pose as a verified rule.
--   * Missing (we read it and it isn't there) and unknown (we couldn't read
--     it) are different results.
--   * Nothing is used, bought or equipped: it's a list.

local _, ns = ...
local C = ns.Compat
ns.Vanguard = ns.Vanguard or {}
local P = { VERSION = 1, SOURCE = "Outrider starting points (not game data); change them in your profile" }
ns.Vanguard.Prep = P

P.ACTIVITY = {
  dungeon = { minutes = 60, durability = 0.6, freeSlots = 6 },
  raid = { minutes = 180, durability = 0.8, freeSlots = 10 },
}
P.PER_HOUR = { food = 10, drink = 10, ammo = 1000 }
P.NO_MANA = { WARRIOR = true, ROGUE = true }

-- class reagents: shown only when you know the spell that uses them
-- (names from Classic; verified = false on Forever)
P.REAGENTS = {
  MAGE = { { item = "Arcane Powder", spell = "Arcane Brilliance", want = 20 }, { item = "Rune of Teleportation", spell = "Teleport: Orgrimmar", want = 2 },
    { item = "Rune of Teleportation", spell = "Teleport: Stormwind", want = 2 } },
  WARLOCK = { { item = "Soul Shard", spell = "Create Healthstone", want = 5 }, { item = "Soul Shard", spell = "Create Soulstone", want = 5 } },
  SHAMAN = { { item = "Ankh", spell = "Reincarnation", want = 1 } },
  PRIEST = { { item = "Sacred Candle", spell = "Prayer of Fortitude", want = 10 }, { item = "Holy Candle", spell = "Prayer of Fortitude", want = 10 } },
  ROGUE = { { item = "Flash Powder", spell = "Vanish", want = 5 } },
  PALADIN = { { item = "Symbol of Divinity", spell = "Divine Intervention", want = 1 } },
}

-- slots you'd normally fill, and slots enchanting reaches (Classic; unverified on Forever)
P.FILL = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 }
P.ENCHANTABLE = { [5] = "chest", [8] = "feet", [9] = "wrists", [10] = "hands", [15] = "back", [16] = "main weapon" }
P.SLOT_NAME = { [1] = "head", [2] = "neck", [3] = "shoulders", [5] = "chest", [6] = "waist", [7] = "legs", [8] = "feet",
  [9] = "wrists", [10] = "hands", [11] = "ring 1", [12] = "ring 2", [13] = "trinket 1", [14] = "trinket 2", [15] = "back",
  [16] = "main weapon", [17] = "off hand", [18] = "ranged" }

local function myClass() return ns.PlayerClass and ns.PlayerClass() or C.Readable(select(2, C.Call("UnitClass", "player"))) end

function P.Profile(activity, role, minutes)
  local a = P.ACTIVITY[activity] or P.ACTIVITY.dungeon
  minutes = tonumber(minutes) or a.minutes
  if minutes < 10 then minutes = 10 elseif minutes > 600 then minutes = 600 end
  local hours = minutes / 60
  local class = myClass()
  return { version = P.VERSION, activity = P.ACTIVITY[activity] and activity or "dungeon", role = role, minutes = minutes,
    class = class, durability = a.durability, freeSlots = a.freeSlots,
    food = math.ceil(P.PER_HOUR.food * hours),
    drink = (not P.NO_MANA[class or ""]) and math.ceil(P.PER_HOUR.drink * hours) or nil,
    ammo = class == "HUNTER" and math.ceil(P.PER_HOUR.ammo * hours) or nil, source = P.SOURCE }
end

-- carried and bank counts of an item; bank = total minus carried, nil when unknown
function P.Count(item)
  local get = C.Resolve("C_Item.GetItemCount") or C.Resolve("GetItemCount")
  if not get then return nil, nil end
  local ok, carried = pcall(get, item, false)
  carried = ok and C.Readable(carried) or nil
  if type(carried) ~= "number" then return nil, nil end
  local ok2, total = pcall(get, item, true)
  total = ok2 and C.Readable(total) or nil
  local bank = (type(total) == "number" and total > carried) and (total - carried) or nil
  return carried, bank
end

local function check(list, id, state, text, extra)
  local row = { id = id, state = state, text = text }
  for k, v in pairs(extra or {}) do row[k] = v end
  list[#list + 1] = row
  return row
end

local function knows(spell) return ns.Vanguard.Utility.Knows(spell) == true end

-- states: ok, missing (read and short), unknown (couldn't read)
function P.Supplies(pf)
  local out = {}
  local d = ns.Errands and ns.Errands.Durability and ns.Errands.Durability()
  if type(d) == "number" then
    check(out, "repair", d >= pf.durability and "ok" or "missing", d >= pf.durability
      and string.format("Gear in repair (most worn %d%%)", math.floor(d * 100))
      or string.format("Repair: most worn piece at %d%% (want %d%%+)", math.floor(d * 100), math.floor(pf.durability * 100)), { action = "repair" })
  else
    check(out, "repair", "unknown", "Repair: durability not readable")
  end
  local free, known = 0, false
  for bag = 0, 4 do
    local n = C.Readable(C.Call("C_Container.GetContainerNumFreeSlots", bag))
    if type(n) == "number" then free, known = free + n, true end
  end
  if known then
    check(out, "bags", free >= pf.freeSlots and "ok" or "missing",
      string.format("%d free bag slots (want %d)", free, pf.freeSlots), { action = free < pf.freeSlots and "bags" or nil })
  else
    check(out, "bags", "unknown", "Bag space not readable")
  end
  local food, drink
  if ns.BagFood and ns.BagFood.Scan then
    local ok, f, dr = pcall(ns.BagFood.Scan, ns.BagFood)
    if ok then food, drink = f, dr else food, drink = false, false end
  end
  local function stock(id, name, want, label)
    if want == nil then return end
    if name == false then check(out, id, "unknown", label .. ": bags not readable") return end
    if not name then check(out, id, "missing", string.format("No %s in your bags (want %d)", label:lower(), want), { want = want, action = id }) return end
    local carried, bank = P.Count(name)
    if not carried then check(out, id, "unknown", label .. ": " .. tostring(name) .. ", count not readable") return end
    check(out, id, carried >= want and "ok" or "missing", string.format("%s: %d %s (want %d)%s", label, carried, tostring(name), want,
      bank and string.format(", %d more in the bank (not carried)", bank) or ""), { have = carried, want = want, bank = bank,
      action = carried < want and id or nil })
  end
  stock("food", food, pf.food, "Food")
  stock("drink", drink, pf.drink, "Drink")
  if pf.ammo then
    local a = ns.Modules and ns.Modules:Get("Ammo")
    local n = a and a.Count and a:Count()
    if type(n) == "number" then
      check(out, "ammo", n >= pf.ammo and "ok" or "missing", string.format("Ammo: %d (want %d)", n, pf.ammo),
        { have = n, want = pf.ammo, action = n < pf.ammo and "ammo" or nil })
    else
      check(out, "ammo", "unknown", "Ammo: not readable")
    end
  end
  local seen = {}
  for _, r in ipairs(P.REAGENTS[pf.class or ""] or {}) do
    if not seen[r.item] and knows(r.spell) then
      seen[r.item] = true
      local carried, bank = P.Count(r.item)
      if carried then
        check(out, "reagent:" .. r.item, carried >= r.want and "ok" or "missing",
          string.format("%s: %d (want %d for %s)%s", r.item, carried, r.want, r.spell,
            bank and string.format(", %d more in the bank (not carried)", bank) or ""),
          { have = carried, want = r.want, bank = bank, action = carried < r.want and "reagent" or nil, item = r.item })
      else
        check(out, "reagent:" .. r.item, "unknown", r.item .. ": count not readable")
      end
    end
  end
  return out
end

-- equipment and access; self = your own MemberProfile (Profile.Collect("player"))
-- st: per-character settings { access = { [instance] = true|false }, custom = { {text, done} } }
function P.Equipment(pf, self, st, instance)
  local out = {}
  local bySlot = {}
  for _, s in ipairs(self and self.slots or {}) do bySlot[s.slot] = s end
  for _, slot in ipairs(P.FILL) do
    local s = bySlot[slot]
    if not s then check(out, "slot:" .. slot, "unknown", P.SLOT_NAME[slot] .. ": not read")
    elseif s.state == "empty" then check(out, "slot:" .. slot, "missing", "Nothing worn: " .. P.SLOT_NAME[slot], { action = "gear", slot = slot })
    elseif s.state ~= "known" and s.state ~= "pending" then check(out, "slot:" .. slot, "unknown", P.SLOT_NAME[slot] .. ": " .. s.state) end
  end
  if pf.class == "HUNTER" then
    local s = bySlot[18]
    if s and s.state == "empty" then check(out, "slot:18", "missing", "Nothing worn: ranged", { action = "gear", slot = 18 }) end
  end
  for slot, name in pairs(P.ENCHANTABLE) do
    local s = bySlot[slot]
    if s and (s.state == "known" or s.state == "pending") then
      if s.enchant then check(out, "enchant:" .. slot, "ok", "Enchanted: " .. name)
      elseif s.link then check(out, "enchant:" .. slot, "missing", "No enchant: " .. name, { action = "enchant", slot = slot, after = "slot:" .. slot })
      else check(out, "enchant:" .. slot, "unknown", "Enchant on " .. name .. ": not readable") end
    end
  end
  table.sort(out, function(a, b) return a.id < b.id end)
  if instance then
    local info = ns.Data and ns.Data:Get("dungeon", instance)
    local level = C.Readable(C.Call("UnitLevel", "player"))
    if info and type(level) == "number" and info.min then
      check(out, "level", level >= info.min and "ok" or "missing", string.format("Level %d for %s (suggested %d-%d, reference data)",
        level, instance, info.min, info.max or info.min), { source = "catalog", verified = info.verified == true })
    else
      check(out, "level", "unknown", "Level range for this place not in the data")
    end
    local a = st and st.access and st.access[instance]
    if a == true then check(out, "access", "ok", "Access: you said you have it", { source = "manual" })
    elseif a == false then check(out, "access", "missing", "Access: you said you don't have it yet", { source = "manual" })
    else check(out, "access", "unknown", "Access (key or attunement): not known; tick it yourself if you have it", { source = "unknown" }) end
  end
  for i, c in ipairs(st and st.custom or {}) do
    if type(c) == "table" and type(c.text) == "string" then
      check(out, "custom:" .. i, c.done and "ok" or "missing", c.text:sub(1, 80) .. " (your own item)", { source = "manual", custom = true })
    end
  end
  return out
end

-- VG02-10: what an instance offers you, from the existing quest and journal data
function P.Journal(instance)
  local D = ns.DungeonGuide
  local out = { instance = instance, quests = {}, upgrades = {} }
  if not (D and instance) then out.reason = "dungeon guide not loaded" return out end
  local d = D:ByName()[instance]
  if not d then out.reason = "not in the installed dungeon data" return out end
  local ok, quests, why = pcall(D.QuestList, D, instance)
  if ok then
    for _, q in ipairs(quests or {}) do
      if not q.complete then out.quests[#out.quests + 1] = { id = q.id, name = q.name, active = q.active, source = q.source } end
    end
    out.questsWhy = why
  end
  local ok2, ups = pcall(D.Upgrades, D, d)
  if ok2 then
    for i, u in ipairs(ups or {}) do
      if i > 8 then break end
      out.upgrades[#out.upgrades + 1] = { itemID = u.itemID, name = u.name, boss = u.boss, pct = u.pct, later = u.later, slot = u.slot }
    end
  end
  out.source = "installed dungeon and quest packs (completeness unverified)"
  return out
end

function P.Count2(list)
  local c = { ok = 0, missing = 0, unknown = 0 }
  for _, r in ipairs(list) do c[r.state] = (c[r.state] or 0) + 1 end
  return c
end
