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
      if #e.encounters == 0 then e.unknowns[#e.unknowns + 1] = "bosses: not in the installed dungeon pack" end
      list[#list + 1] = e
      byId[e.instanceId] = e
    end
  end
  table.sort(list, function(a, b) if (a.min or 0) ~= (b.min or 0) then return (a.min or 0) < (b.min or 0) end return a.name < b.name end)
  local nb = 0
  for _, e in ipairs(list) do nb = nb + #e.encounters end
  return { version = Cat.VERSION .. "." .. #list .. "." .. nb, list = list, byId = byId }
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
