-- Modules/TalentStats.lua
-- What a talent build gives, added up (requirement 2026-11-23: show the
-- stats at different level ranges for the selected
-- build). Phase 2 of docs/TALENT_BUILDS_RESEARCH_2026-11-23.md.
--   * Each talent's own description from the client (C_Traits.GetTraitDescription
--     for the rank, else the spell's description) is read for the numbers it
--     gives: crit, hit, stats in %, damage and healing in %, mana cost, armor,
--     dodge, parry... (TalentPath Forever's idea: totals with the talents
--     they come from).
--   * Totals for any set of points, for the build at levels 20 to 60, and
--     your stats now with the build's difference from yours applied.
-- Numbers come from the game's own text; a talent whose text doesn't match a
-- known phrase is listed as "not counted" rather than guessed.

local _, ns = ...
local C = ns.Compat
local L = ns.TalentLab
if not L then return end

local M = ns:NewModule("TalentStats", {
  title = "Talent build totals",
  phase = "P6",
  order = 86,
  defaults = {},
})
ns.TalentStats = M

-- { key, label, unit, patterns }: the first number after the phrase, per rank
M.KINDS = {
  { key = "crit", label = "Critical strike", unit = "%", find = { "critical strike chance[^%d%.]-by (%d+%.?%d*)%%", "chance to critically[^%d%.]-by (%d+%.?%d*)%%", "critical strike chance[^%d%.]-(%d+%.?%d*)%%" } },
  { key = "hit", label = "Chance to hit", unit = "%", find = { "chance to hit[^%d%.]-by (%d+%.?%d*)%%", "hit chance[^%d%.]-by (%d+%.?%d*)%%" } },
  { key = "damage", label = "Damage", unit = "%", find = { "damage done[^%d%.]-by (%d+%.?%d*)%%", "increases[^%.]-damage[^%d%.]-by (%d+%.?%d*)%%" } },
  { key = "healing", label = "Healing", unit = "%", find = { "healing done[^%d%.]-by (%d+%.?%d*)%%", "increases[^%.]-healing[^%d%.]-by (%d+%.?%d*)%%" } },
  { key = "manacost", label = "Mana cost", unit = "% less", find = { "mana cost[^%d%.]-by (%d+%.?%d*)%%", "reduces the mana cost[^%d%.]-(%d+%.?%d*)%%" } },
  { key = "stamina", label = "Stamina", unit = "%", find = { "stamina by (%d+%.?%d*)%%" } },
  { key = "intellect", label = "Intellect", unit = "%", find = { "intellect by (%d+%.?%d*)%%" } },
  { key = "spirit", label = "Spirit", unit = "%", find = { "spirit by (%d+%.?%d*)%%" } },
  { key = "strength", label = "Strength", unit = "%", find = { "strength by (%d+%.?%d*)%%" } },
  { key = "agility", label = "Agility", unit = "%", find = { "agility by (%d+%.?%d*)%%" } },
  { key = "health", label = "Health", unit = "%", find = { "maximum health by (%d+%.?%d*)%%", "health by (%d+%.?%d*)%%" } },
  { key = "mana", label = "Mana", unit = "%", find = { "maximum mana by (%d+%.?%d*)%%" } },
  { key = "armor", label = "Armor", unit = "%", find = { "armor[^%d%.]-by (%d+%.?%d*)%%" } },
  { key = "dodge", label = "Dodge", unit = "%", find = { "dodge[^%d%.]-by (%d+%.?%d*)%%" } },
  { key = "parry", label = "Parry", unit = "%", find = { "parry[^%d%.]-by (%d+%.?%d*)%%" } },
  { key = "speed", label = "Attack or cast speed", unit = "%", find = { "attack speed[^%d%.]-by (%d+%.?%d*)%%", "casting time[^%d%.]-by (%d+%.?%d*)%%" } },
  { key = "threat", label = "Threat", unit = "%", find = { "threat[^%d%.]-by (%d+%.?%d*)%%" } },
}

-- The talent's text at a rank (nil when the client gives none).
function M.Text(t, rank)
  rank = math.max(1, rank or 1)
  local text = t.entry and C.Call("C_Traits.GetTraitDescription", t.entry, rank)
  text = C.Readable(text)
  if type(text) == "string" and text ~= "" then return text, rank end
  local d = t.spell and C.Call("C_Spell.GetSpellDescription", t.spell)
  d = C.Readable(d)
  if type(d) == "string" and d ~= "" then return d, nil end -- rank unknown: read as one rank's worth
  return nil
end

-- The numbers a text gives: { [key] = value } (first match per kind).
function M.Parse(text)
  if type(text) ~= "string" then return nil end
  local low, out = text:lower(), nil
  for _, k in ipairs(M.KINDS) do
    for _, pat in ipairs(k.find) do
      local v = tonumber(low:match(pat))
      if v then out = out or {} out[k.key] = v break end
    end
  end
  return out
end

-- What one rank of a talent gives: { [key] = value }; nil when nothing matched.
-- Bug 2026-11-23: a Balance build said "+74% less Mana cost". A text that
-- already shows a talent at its rank (Moonglow 3/3: "by 9%") was multiplied
-- by the rank again. Now: the client's rank 1 and rank 2 texts are compared
-- when it has them (rank 1's number is one rank); a single text is read as
-- your current rank's (divided by it), or rank 1's when you have none.
M.cache = {}
M.logged = 0
function M.PerRank(t)
  local hit = M.cache[t.node]
  if hit ~= nil then return hit or nil end
  local function trait(rank)
    local x = t.entry and C.Readable(C.Call("C_Traits.GetTraitDescription", t.entry, rank))
    return type(x) == "string" and x ~= "" and x or nil
  end
  local one = trait(1)
  local two = (t.max or 1) > 1 and trait(2) or nil
  local text = one
  if not text then
    local d = t.spell and C.Readable(C.Call("C_Spell.GetSpellDescription", t.spell))
    text = type(d) == "string" and d ~= "" and d or nil
  end
  local v1 = M.Parse(text)
  local v2 = M.Parse(two)
  local out
  if v1 then
    out = {}
    local differs = false
    if v2 then for k, v in pairs(v1) do if v2[k] and v2[k] ~= v then differs = true end end end
    local div = 1
    if not differs and (t.rank or 0) > 1 then div = t.rank end
    for k, v in pairs(v1) do out[k] = v / div end
  end
  -- what was read, once a session per talent (to check against the game)
  if M.logged < 80 and text then
    M.logged = M.logged + 1
    local parts = {}
    for k, v in pairs(out or {}) do parts[#parts + 1] = k .. "=" .. tostring(v) end
    table.sort(parts)
    ns.Log:Info("TalentStats", "talent text %s (%d/%d)%s: %s -> %s", tostring(t.name), t.rank or 0, t.max or 1,
      two and " [rank 2 text]" or "", (text:gsub("\n", " ")):sub(1, 160), #parts > 0 and table.concat(parts, " ") or "nothing counted")
  end
  M.cache[t.node] = out or false
  return out
end

-- Totals for a set of points: { [key] = { value, from = { "Talent 3/5", ... } } }, notCounted = { names }
function M.Totals(model, r)
  local out, skipped = {}, {}
  for node, n in pairs(r or {}) do
    local t = model.byNode[node]
    if t and n > 0 then
      local per = M.PerRank(t)
      if per then
        for key, v in pairs(per) do
          local e = out[key] or { value = 0, from = {} }
          e.value = e.value + v * n
          e.from[#e.from + 1] = string.format("%s %d/%d", t.name, n, t.max)
          out[key] = e
        end
      else
        skipped[#skipped + 1] = t.name
      end
    end
  end
  table.sort(skipped)
  return out, skipped
end

-- "+5% Critical strike, +10% Stamina" (largest first, up to n)
function M.Line(totals, n)
  local list = {}
  for _, k in ipairs(M.KINDS) do
    local e = totals[k.key]
    if e and e.value ~= 0 then list[#list + 1] = { k = k, v = e.value } end
  end
  table.sort(list, function(a, b) return a.v > b.v end)
  local parts = {}
  for i, x in ipairs(list) do
    if n and i > n then break end
    local v = math.floor(x.v * 10 + 0.5) / 10
    parts[#parts + 1] = string.format("+%s%s %s", tostring(v), x.k.unit == "%" and "%" or (" " .. x.k.unit .. ""), x.k.label)
  end
  return table.concat(parts, ", ")
end

-- The build at each level band: { { level, split, line } }
M.BANDS = { 20, 30, 40, 50, 60 }
function M.ByLevel(model, card)
  local out = {}
  for _, lvl in ipairs(M.BANDS) do
    local r = L.RanksFor(model, card, lvl)
    out[#out + 1] = { level = lvl, split = L.Split(model, r), line = M.Line((M.Totals(model, r))) }
  end
  return out
end

-- Your stats now, and with the build: { { label, now, with } } for the
-- stats a talent changes by a percentage of what you have.
M.STATS = { { "strength", 1, "Strength" }, { "agility", 2, "Agility" }, { "stamina", 3, "Stamina" }, { "intellect", 4, "Intellect" }, { "spirit", 5, "Spirit" } }
function M.Now(model, r)
  local mineT = M.Totals(model, L.Mine(model))
  local buildT = M.Totals(model, r)
  local function pct(t, key) return t[key] and t[key].value or 0 end
  local out = {}
  for _, s in ipairs(M.STATS) do
    local cur = tonumber(C.Readable((C.Call("UnitStat", "player", s[2]))))
    if cur then
      local base = cur / (1 + pct(mineT, s[1]) / 100)
      out[#out + 1] = { label = s[3], now = math.floor(cur + 0.5), with = math.floor(base * (1 + pct(buildT, s[1]) / 100) + 0.5) }
    end
  end
  local hp = tonumber(C.Readable(C.Call("UnitHealthMax", "player")))
  if hp then
    local base = hp / (1 + pct(mineT, "health") / 100)
    out[#out + 1] = { label = "Health", now = hp, with = math.floor(base * (1 + pct(buildT, "health") / 100) + 0.5) }
  end
  local crit = tonumber(C.Readable(C.Call("GetCritChance")))
  if crit then
    out[#out + 1] = { label = "Crit %", now = math.floor(crit * 10 + 0.5) / 10,
      with = math.floor((crit - pct(mineT, "crit") + pct(buildT, "crit")) * 10 + 0.5) / 10 }
  end
  return out
end

-- Page text: the build's totals with the talents they come from, then by level.
function M:Report()
  local r, model = L:Sandbox()
  if not model then return "" end
  local totals, skipped = M.Totals(model, r)
  local lines = {}
  local line = M.Line(totals)
  lines[#lines + 1] = line ~= "" and ("This build gives: " .. line) or "This build's talents don't add a stat Outrider can count yet."
  if #skipped > 0 then
    lines[#lines + 1] = "|cff8f96a6Not counted (no number in their text): " .. table.concat(skipped, ", ", 1, math.min(#skipped, 8))
      .. (#skipped > 8 and ", ..." or "") .. "|r"
  end
  local card = L.card
  if card then
    for _, b in ipairs(M.ByLevel(model, card)) do
      lines[#lines + 1] = string.format("Level %d (%s): %s", b.level, b.split, b.line ~= "" and b.line or "nothing countable yet")
    end
  end
  return table.concat(lines, "\n")
end

function M:OnEnable()
  self:On("PLAYER_TALENT_UPDATE", function() M.cache = {} end)
end

function M:Activity()
  local r, model = L:Sandbox()
  if not model then return "talent trees not readable yet" end
  return M.Line((M.Totals(model, r)), 3)
end
