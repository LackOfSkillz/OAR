-- Vanguard/Facts.lua
-- Lookups over Data/VanguardFacts.lua (researched 2026-11-26 from cited web
-- sources; verified = false until Gary sees it in game on WoW Forever):
--   Facts.Bosses(instance)   boss list with mechanic tags, source and kind
--   Facts.Access(instance)   what it takes to get in (key, attunement, none)
--   Facts.Raid(name)         raid size, bosses, status, published role counts
--   Facts.Price(id or name)  vendor price { copper, per, source }
--   Facts.Enchant(id)        enchant stats { stats = { token = n } } or proc
-- kind "forever" = a source about WoW Forever; "classic" = a Classic source
-- for a dungeon Forever didn't change (shown as "Classic source: Forever may differ").
-- Tags map onto the utility registry where a class can answer them; the rest
-- (fear, resistances, spread...) are notes, never scored.

local _, ns = ...
ns.Vanguard = ns.Vanguard or {}
local F = { VERSION = 1 }
ns.Vanguard.Facts = F

-- mechanic tag -> utility capability (Vanguard/Utility.lua)
F.TAG_CAP = { interrupt = "interrupt", interrupt_heal = "interrupt", dispel_magic = "dispel_magic", dispel_curse = "dispel_curse",
  dispel_poison = "dispel_poison", dispel_disease = "dispel_disease", purge = "purge", cc = "cc", enrage = "tranq" }
F.TAG_NOTE = { fear = "fears players", tank_swap_or_offtank = "needs a second tank or a tank swap", fire_res = "fire damage (fire resistance helps)",
  nature_res = "nature damage (nature resistance helps)", frost_res = "frost damage (frost resistance helps)",
  shadow_res = "shadow damage (shadow resistance helps)", spread = "spread out", adds = "adds join the fight" }

local function data() return type(ns.VanguardFacts) == "table" and ns.VanguardFacts or {} end

local function lower(s) return type(s) == "string" and s:lower() or nil end

function F.Bosses(instance)
  local b = data().bosses
  return b and b[instance] or nil
end

function F.Access(instance)
  local a = data().access
  return a and a[instance] or nil
end

function F.Raid(name)
  local r = data().raids
  return r and r[name] or nil
end

function F.Raids()
  return data().raids or {}
end

local byName
function F.Price(key)
  local p = data().prices or {}
  if type(key) == "number" then return p[key] end
  if type(key) ~= "string" then return nil end
  if not byName then
    byName = {}
    for id, row in pairs(p) do if type(row) == "table" and row.name then byName[row.name:lower()] = row row.id = id end end
  end
  return byName[key:lower()]
end

function F.Enchant(id)
  local e = data().enchants
  return e and tonumber(id) and e[tonumber(id)] or nil
end

-- requirements and notes for one boss from its tags
function F.BossReqs(boss, kind, source)
  local reqs, notes = {}, {}
  local tags = type(boss) == "table" and boss.tags or {}
  local keys = {}
  for tag in pairs(tags) do keys[#keys + 1] = tag end
  table.sort(keys)
  local seen = {}
  for _, tag in ipairs(keys) do
    local reason = tostring(tags[tag] or "")
    local cap = F.TAG_CAP[tag]
    if cap and not seen[cap] and ns.Vanguard.Utility.CAPS[cap] then
      seen[cap] = true
      reqs[#reqs + 1] = { id = "boss:" .. cap, category = "utility", weight = 1, critical = false, target = 1, cap = cap,
        rule = "this boss: " .. ns.Vanguard.Utility.CAPS[cap].label:lower() .. (reason ~= "" and (" (" .. reason .. ")") or ""),
        scope = "group", source = source or "guide", verification = kind == "forever" and "reference" or "classic" }
    elseif F.TAG_NOTE[tag] then
      notes[#notes + 1] = F.TAG_NOTE[tag] .. (reason ~= "" and (": " .. reason) or "")
    end
  end
  return reqs, notes
end

function F.Reset() byName = nil end

F.lower = lower
