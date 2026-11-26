-- Vanguard/Catalog.lua
-- VG03-01: the encounter catalog. One entry per dungeon or raid in the
-- installed data, versioned, with where every fact comes from:
--   * level range, size, raid flag: Data/Dungeons.lua (foreverdb / Wowhead
--     guides, verified = false: shown as "reference");
--   * bosses and their levels: the installed dungeon pack (completeness unverified);
--   * requirements: Outrider's group template (one tank, one healer, damage
--     to fill, levels in range, an interrupt and a resurrection), marked
--     "template", never "verified". Raids get no role template: their
--     makeup on Forever isn't known, so it stays unknown.
--   * your own boss rules (a boss you say needs a dispel, say) are marked
--     "manual" and only count for you.
-- Boss mechanics are not in any installed data: every boss lists them as
-- unknown. Nothing is assumed from Classic, and no future raid is invented.

local _, ns = ...
ns.Vanguard = ns.Vanguard or {}
local Cat = { VERSION = 1 }
ns.Vanguard.Catalog = Cat

Cat.TEMPLATE = "Outrider group template (common makeup), not a game rule"

-- requirement: { id, category, weight, critical, unit, target, rule, scope, source, verification }
local function req(id, category, weight, target, rule, extra)
  local r = { id = id, category = category, weight = weight, critical = false, target = target, rule = rule,
    scope = "group", source = Cat.TEMPLATE, verification = "template" }
  for k, v in pairs(extra or {}) do r[k] = v end
  return r
end

function Cat.Template(size, raid, minLevel)
  local out = {}
  if size and minLevel then out[#out + 1] = req("level", "level", 2, minLevel, "every member at least the level", { source = "level range (reference data)", verification = "reference" }) end
  if size then out[#out + 1] = req("size", "size", 1, size, "members in the group", { source = "group size (reference data)", verification = "reference" }) end
  if raid then return out end
  if size == 5 then
    out[#out + 1] = req("tank", "role", 3, 1, "tanks")
    out[#out + 1] = req("healer", "role", 3, 1, "healers")
    out[#out + 1] = req("damage", "role", 2, 3, "damage dealers")
    out[#out + 1] = req("interrupt", "utility", 1, 1, "someone who can interrupt", { cap = "interrupt" })
    out[#out + 1] = req("rez", "utility", 1, 1, "someone who can resurrect", { cap = "rez" })
  end
  return out
end

local function build()
  local D = ns.DungeonGuide
  local packs = {}
  local ok, byName = pcall(function() return D and D:ByName() end)
  if ok and type(byName) == "table" then packs = byName end
  local list, byId = {}, {}
  for _, meta in ipairs(ns.Data and ns.Data:All("dungeon") or {}) do
    if type(meta) == "table" and type(meta.name) == "string" then
      local d = packs[meta.name]
      local e = { instanceId = meta.name, name = meta.name, difficulty = "normal", size = tonumber(meta.size),
        min = tonumber(meta.min), max = tonumber(meta.max), raid = meta.raid == true, new = meta.new == true,
        availability = meta.verified == true and "verified" or "reference", source = tostring(meta.source or "?"),
        encounters = {}, unknowns = { "boss mechanics: not in any installed data" } }
      if e.raid then e.unknowns[#e.unknowns + 1] = "raid makeup on Forever: not known (no role template)" end
      e.requirements = Cat.Template(e.size, e.raid, e.min)
      for i, b in ipairs(d and d.bosses or {}) do
        e.encounters[#e.encounters + 1] = { encounterId = tostring(b[1] or i), name = tostring(b[2] or ("Boss " .. i)),
          level = tonumber(b[3]), order = i, source = "installed dungeon pack (completeness unverified)" }
      end
      Cat.Merge(e)
      if #e.encounters == 0 then e.unknowns[#e.unknowns + 1] = "bosses: not in the installed dungeon pack" end
      list[#list + 1] = e
      byId[e.instanceId] = e
    end
  end
  -- raids in the researched facts that Data/Dungeons.lua doesn't list (new on Forever)
  for name, r in pairs(ns.Vanguard.Facts.Raids()) do
    if not byId[name] and type(r) == "table" and tonumber(r.size) then
      local e = { instanceId = name, name = name, difficulty = "normal", size = tonumber(r.size), min = tonumber(r.min) or 60,
        max = tonumber(r.max) or 60, raid = true, new = true, availability = "reference", source = tostring(r.source or "?"),
        status = r.status, encounters = {}, unknowns = {} }
      e.requirements = Cat.Template(e.size, true, e.min)
      Cat.Merge(e)
      if #e.encounters == 0 then e.unknowns[#e.unknowns + 1] = "bosses: not published" end
      list[#list + 1] = e
      byId[name] = e
    end
  end
  table.sort(list, function(a, b) if (a.min or 0) ~= (b.min or 0) then return (a.min or 0) < (b.min or 0) end return a.name < b.name end)
  local nb = 0
  for _, e in ipairs(list) do nb = nb + #e.encounters end
  return { version = Cat.VERSION .. "." .. #list .. "." .. nb, list = list, byId = byId }
end

-- researched facts (Vanguard/Facts.lua): boss mechanics, published raid
-- makeup and access. Facts never overwrite the pack; they add to it, each
-- with its source, and "classic" facts are labeled as such.
function Cat.Merge(e)
  local Facts = ns.Vanguard.Facts
  local fb = Facts.Bosses(e.name)
  if fb and type(fb.list) == "table" then
    -- the researched list is the boss list (the pack also lists every mob that
    -- drops loot); pack rows give the level where the names match. The pack
    -- itself is not changed.
    local byName = {}
    for _, enc in ipairs(e.encounters) do byName[enc.name:lower()] = enc end
    local list, used = {}, {}
    for i, b in ipairs(fb.list) do
      if type(b) == "table" and type(b.name) == "string" then
        local packed = byName[b.name:lower()]
        local enc = { encounterId = tostring(b.npc or (packed and packed.encounterId) or ("f" .. i)), name = b.name,
          level = tonumber(b.level) or (packed and packed.level), order = #list + 1, optional = b.optional or nil,
          source = tostring(b.source or fb.source or "guide") }
        if packed then used[packed] = true end
        list[#list + 1] = enc
        enc.factKind = b.kind or fb.kind
        enc.factSource = b.source or fb.source
        enc.reqs, enc.notes = Facts.BossReqs(b, enc.factKind, enc.factSource)
        enc.mechanicsKnown = b.unknown ~= true
        if b.conflict then enc.notes[#enc.notes + 1] = "sources disagree: " .. b.conflict end
      end
    end
    local others = 0
    for _, enc in ipairs(e.encounters) do if not used[enc] then others = others + 1 end end
    e.encounters = list
    if others > 0 then e.unknowns[#e.unknowns + 1] = string.format("%d other named mob(s) with loot in the dungeon pack are not shown as bosses", others) end
    local kind = fb.kind == "forever" and "WoW Forever guides" or "Classic sources (Forever may differ)"
    for i, u in ipairs(e.unknowns) do
      if u:find("^boss mechanics") then e.unknowns[i] = "boss mechanics: from " .. kind .. ", not verified in game" end
    end
  end
  local raid = Facts.Raid(e.name)
  if raid and type(raid.roles) == "table" then
    local src = tostring(raid.roles.source or raid.source or "guide")
    for _, x in ipairs({ { "tank", "tanks", 3 }, { "healer", "healers", 3 }, { "damage", "damage dealers", 2 } }) do
      local n = tonumber(raid.roles[x[1]])
      if n and n > 0 then
        e.requirements[#e.requirements + 1] = req(x[1], "role", x[3], n, x[2], { source = src, verification = raid.roles.kind or "community" })
      end
    end
    for i, u in ipairs(e.unknowns) do
      if u:find("^raid makeup") then e.unknowns[i] = "raid makeup: a " .. (raid.roles.kind or "community") .. " suggestion, not a game rule" end
    end
  end
  if raid and raid.status then
    e.status = raid.status
    if tostring(raid.status):find("not announced") then table.insert(e.unknowns, 1, "status: " .. raid.status) e.announced = false end
  end
  if raid and raid.note then e.unknowns[#e.unknowns + 1] = raid.note end
  if fb and fb.orderUnconfirmed then e.unknowns[#e.unknowns + 1] = "boss order: not confirmed" end
  e.access = Facts.Access(e.name)
  if e.access and e.access.note then e.unknowns[#e.unknowns + 1] = "access: " .. e.access.note end
  if e.access and e.access.conflict then e.unknowns[#e.unknowns + 1] = "access sources disagree: " .. e.access.conflict end
end

function Cat.Get()
  if not Cat.cache then Cat.cache = build() end
  return Cat.cache
end

function Cat.Reset() Cat.cache = nil end

function Cat.Find(id) return Cat.Get().byId[id] end

-- your own boss rules: settings.bossNeeds[boss name] = { cap = true }
function Cat.BossRules(e, st)
  local out = {}
  local needs = st and st.bossNeeds or {}
  for _, enc in ipairs(e and e.encounters or {}) do
    local mine = needs[enc.name]
    local list = {}
    for _, r in ipairs(enc.reqs or {}) do
      if not (type(mine) == "table" and mine[r.cap]) then list[#list + 1] = r end
    end
    if type(mine) == "table" then
      for cap in pairs(mine) do
        if ns.Vanguard.Utility.CAPS[cap] then
          list[#list + 1] = { id = "boss:" .. cap, category = "utility", weight = 1, critical = false, target = 1, cap = cap,
            rule = "you said this boss needs " .. ns.Vanguard.Utility.CAPS[cap].label:lower(), scope = "group",
            source = "your own rule", verification = "manual" }
        end
      end
      table.sort(list, function(a, b) return a.id < b.id end)
    end
    out[enc.name] = list
  end
  return out
end
