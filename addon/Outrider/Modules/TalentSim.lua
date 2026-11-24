-- Modules/TalentSim.lua
-- Numbers per talent build, and a ranking (requirement 2026-11-23: a damage/heal/
-- tank sim, so Outrider can analyze builds and recommend
-- the best ones). Phases 3 and 4 of docs/TALENT_BUILDS_RESEARCH_2026-11-23.md.
--   * Estimate: one minute against a dummy with the spells Outrider's own
--     Fight (or Heal) key casts, in its order: damage over time when it has
--     run out, cooldowns when ready, the filler between. Each spell's numbers
--     are the client's own tooltip (average of "X to Y", cast time, cooldown);
--     the build changes them by its totals (damage or healing %, crit),
--     with your current talents taken out first so they don't count twice.
--     Melee and ranged classes add their auto attack. Tanks get toughness:
--     health with the build, spread over the chance to dodge or parry.
--   * Ranking: the cards for a goal are scored this way and the best is
--     marked on the page ("Outrider's pick for you").
--   * Training dummy (phase 4): after a fight against a training dummy,
--     Blizzard's own damage meter (FightMeter) gives your real damage per
--     second; it's kept per build and shown next to the estimate.
-- An estimate, not a full simulator: talents that add or change spells,
-- procs, hit, resistances and mana running out are not modelled; the page
-- says so. Read only; casting stays Gary's keys.

local _, ns = ...
local C = ns.Compat
local L = ns.TalentLab
local S = ns.TalentStats
if not (L and S) then return end

local M = ns:NewModule("TalentSim", {
  title = "Talent build numbers",
  phase = "P6",
  order = 87,
  defaults = {},
})
ns.TalentSim = M

M.FIGHT = 60       -- seconds against the dummy
M.GCD = 1.5
M.SPELL_CRIT = 0.5 -- a spell crit adds half (Classic 1.12)
M.MELEE_CRIT = 1.0
M.MELEE = { WARRIOR = true, ROGUE = true, PALADIN = true, SHAMAN = true, DRUID = true, HUNTER = true }
M.DUMMY = { "training dummy", "target dummy", "combat dummy" }

-- ------------------------------------------------------------ spells
-- What a spell does from its tooltip: { name, id, avg, dot, heal, cast, cd }
function M.Spell(name)
  local e = ns.Spellbook and ns.Spellbook:Known(name)
  if not (e and e.id) then return nil end
  local info = C.Call("C_Spell.GetSpellInfo", e.id)
  local cast = type(info) == "table" and tonumber(C.Readable(info.castTime)) or 0
  local cd = tonumber(C.Readable(C.Call("GetSpellBaseCooldown", e.id))) or 0
  local text = C.Readable(C.Call("C_Spell.GetSpellDescription", e.id))
  local s = { name = name, id = e.id, cast = (cast or 0) / 1000, cd = cd / 1000 }
  if type(text) == "string" then
    local low = text:lower():gsub(",", "")
    local a, b = low:match("(%d+) to (%d+)")
    local one = tonumber(low:match("(%d+) %a* ?damage")) or tonumber(low:match("for (%d+)"))
    local amount = a and (tonumber(a) + tonumber(b)) / 2 or one
    s.avg = amount
    s.dot = tonumber(low:match("over (%d+%.?%d*) sec"))
    s.heal = low:find("heal", 1, true) ~= nil and not low:find("damage", 1, true)
  end
  return s
end

-- The spell names a key casts, in its order (conditions and modifiers stripped;
-- lines that need Shift, Ctrl or Alt are left out).
function M.KeySpells(kind)
  local F = ns.HunterFight
  if not (F and F.Lines) then return {} end
  local out, seen = {}, {}
  for _, l in ipairs(F:Lines(kind) or {}) do
    local text = l.text or ""
    local verb, rest = text:match("^/(%a+)%s+(.*)$")
    if (verb == "cast" or verb == "castsequence") and not rest:find("mod:", 1, true) and not rest:find("nocombat", 1, true) then
      rest = rest:gsub("%[[^%]]*%]", ""):gsub("reset=%S+", "")
      for part in rest:gmatch("[^,;]+") do
        local name = part:match("^%s*!?(.-)%s*$")
        if name ~= "" and not seen[name] then seen[name] = true out[#out + 1] = name end
      end
    end
  end
  return out
end

-- One minute of the key against a dummy: total amount and casts per spell.
function M.Rotation(spells, fight)
  fight = fight or M.FIGHT
  local t, total, ready, ticking, casts = 0, 0, {}, {}, {}
  local guard = 0
  while t < fight and guard < 400 do
    guard = guard + 1
    local pick
    for _, s in ipairs(spells) do
      if s.avg and s.avg > 0 and (ready[s.name] or 0) <= t then
        if s.dot then
          if (ticking[s.name] or 0) <= t then pick = s break end
        else
          pick = s
          break
        end
      end
    end
    if not pick then
      -- nothing ready: wait for the next one
      local nextT
      for _, s in ipairs(spells) do
        local w = math.max(ready[s.name] or 0, s.dot and (ticking[s.name] or 0) or 0)
        if s.avg and w > t and (not nextT or w < nextT) then nextT = w end
      end
      if not nextT then break end
      t = nextT
    else
      local took = math.max(M.GCD, pick.cast or 0)
      local amount = pick.avg
      -- a damage-over-time spell cut short by the end of the fight counts its share
      if pick.dot then amount = amount * math.min(1, (fight - t) / pick.dot) ticking[pick.name] = t + pick.dot end
      total = total + amount
      casts[pick.name] = (casts[pick.name] or 0) + 1
      if (pick.cd or 0) > 0 then ready[pick.name] = t + pick.cd end
      t = t + took
    end
  end
  return total, casts
end

-- ------------------------------------------------------------ the estimate
local function pct(t, key) return t[key] and t[key].value or 0 end

-- { dps, hps, toughness, casts, notes } for a set of points
function M.Estimate(model, r, kind)
  local cls = ns.PlayerClass()
  local mineT = S.Totals(model, L.Mine(model))
  local buildT = S.Totals(model, r)
  local out = { notes = {} }
  local list = {}
  for _, name in ipairs(M.KeySpells(kind or "ranged")) do
    local s = M.Spell(name)
    if s and s.avg then list[#list + 1] = s end
  end
  local raw, casts = M.Rotation(list)
  out.casts = casts
  local heal = kind == "heal"
  local key = heal and "healing" or "damage"
  local mult = (1 + pct(buildT, key) / 100) / (1 + pct(mineT, key) / 100)
  local critNow = tonumber(C.Readable(C.Call(heal and "GetSpellCritChance" or "GetCritChance", heal and 2 or nil))) or 0
  local crit = math.max(0, critNow - pct(mineT, "crit") + pct(buildT, "crit")) / 100
  local perSec = raw / M.FIGHT * mult * (1 + crit * M.SPELL_CRIT)
  if heal then out.hps = perSec else out.dps = perSec end
  -- auto attack for weapon classes
  if not heal and M.MELEE[cls] then
    local lo, hi = C.Call(cls == "HUNTER" and "UnitRangedDamage" or "UnitDamage", "player")
    local speed = C.Call(cls == "HUNTER" and "UnitRangedDamage" or "UnitAttackSpeed", "player")
    lo, hi, speed = tonumber(C.Readable(lo)), tonumber(C.Readable(hi)), tonumber(C.Readable(speed))
    if lo and hi and speed and speed > 0 then
      out.dps = (out.dps or 0) + (lo + hi) / 2 / speed * mult * (1 + crit * M.MELEE_CRIT)
    end
  end
  -- toughness: health with the build over the chance a hit lands
  local hp = tonumber(C.Readable(C.Call("UnitHealthMax", "player")))
  if hp then
    local hpWith = hp / (1 + pct(mineT, "health") / 100) * (1 + pct(buildT, "health") / 100)
    local stamina = (1 + pct(buildT, "stamina") / 100) / (1 + pct(mineT, "stamina") / 100)
    local avoid = math.min(0.75, (pct(buildT, "dodge") + pct(buildT, "parry")) / 100)
    out.toughness = hpWith * stamina / (1 - avoid)
  end
  if #list == 0 then out.notes[#out.notes + 1] = "no spell with a number in its tooltip on your key yet" end
  return out
end

-- The score that ranks cards for a goal.
function M.Score(est, goal)
  if goal == "hps" then return est.hps or 0 end
  if goal == "tank" then return est.toughness or 0 end
  return est.dps or 0
end

function M.Kind(goal) return goal == "hps" and "heal" or "ranged" end

-- Cards for a goal with their estimates, best first: { { card, est, score } }
function M:Rank(goal, level)
  local model = L.model or L:Load()
  if not model then return {} end
  local key = table.concat({ model.checksum, tostring(goal), tostring(level), tostring(L.Total(L.Mine(model))) }, ":")
  if self.rankCache and self.rankCache.key == key then return self.rankCache.list end
  local out = {}
  for _, card in ipairs(L.Cards(ns.PlayerClass())) do
    if card.goal == goal then
      local r = L.RanksFor(model, card, level)
      local est = M.Estimate(model, r, M.Kind(goal))
      out[#out + 1] = { card = card, est = est, score = M.Score(est, goal) }
    end
  end
  table.sort(out, function(a, b) if a.score ~= b.score then return a.score > b.score end return a.card.id < b.card.id end)
  self.rankCache = { key = key, list = out }
  return out
end

-- "~123 damage per second" for a goal
function M.Words(est, goal)
  if goal == "hps" then return est.hps and string.format("~%d healing per second", math.floor(est.hps + 0.5)) or nil end
  if goal == "tank" then return est.toughness and string.format("~%d toughness", math.floor(est.toughness + 0.5)) or nil end
  return est.dps and string.format("~%d damage per second", math.floor(est.dps + 0.5)) or nil
end

-- ------------------------------------------------------------ training dummy
function M.IsDummy(name)
  local low = tostring(name or ""):lower()
  for _, d in ipairs(M.DUMMY) do if low:find(d, 1, true) then return true end end
  return false
end

function M:Dummy()
  ns.db.char.talentDummy = ns.KeepTable(ns.db.char.talentDummy, "TalentSim:ns.db.char.talentDummy") or {}
  return ns.db.char.talentDummy
end

-- After a fight: new dummy rows in FightMeter's history count for your build.
function M:OnFightEnd()
  local FM = ns.FightMeter
  if not (FM and FM.History) then return end
  local model = L.model or L:Load()
  if not model then return end
  local code = L.Export(model, L.Mine(model))
  local d = self:Dummy()
  self.seenFights = self.seenFights or {}
  for _, row in ipairs(FM:History()) do
    if row.id and not self.seenFights[row.id] then
      self.seenFights[row.id] = true
      if M.IsDummy(row.name) and (row.duration or 0) >= 10 and (row.player or 0) > 0 then
        local e = d[code] or { split = L.Split(model, L.Mine(model)), fights = 0, total = 0, secs = 0 }
        e.fights, e.total, e.secs, e.at = e.fights + 1, e.total + row.player, e.secs + row.duration, time()
        d[code] = e
        self:Info("dummy fight with %s: %.1f DPS (%d s), %d fights for this build", e.split, row.player / row.duration, row.duration, e.fights)
      end
    end
  end
end

-- Your measured DPS on a dummy with your current build, or nil.
function M:Measured()
  local model = L.model or L:Load()
  if not model then return nil end
  local e = self:Dummy()[L.Export(model, L.Mine(model))]
  if not (e and e.secs > 0) then return nil end
  return e.total / e.secs, e.fights
end

function M:OnEnable()
  self:On("PLAYER_REGEN_ENABLED", function()
    -- the meter session is readable a moment after combat ends
    ns.Timer.After(3, function() ns.Safe("talentsim:dummy", M.OnFightEnd, M) end, "talentsim:dummy")
  end)
  self:On("PLAYER_TALENT_UPDATE", function(mod) mod.rankCache = nil end)
end

-- Page text: the estimate for the build in the trees, the dummy, the caveat.
function M:Report()
  local r, model = L:Sandbox()
  if not model then return "" end
  local goal = L:Goal()
  local est = M.Estimate(model, r, M.Kind(goal))
  local lines = {}
  local words = M.Words(est, goal)
  lines[#lines + 1] = words and ("This build, your spells now: " .. words .. ".") or "No estimate yet: your key has no spell with a number in its tooltip."
  local mine = M.Estimate(model, L.Mine(model), M.Kind(goal))
  local mineWords = M.Words(mine, goal)
  if mineWords and words and L.Total(r) > 0 then lines[#lines + 1] = "Your build now: " .. mineWords .. "." end
  local real, fights = self:Measured()
  if real then
    lines[#lines + 1] = string.format("Measured on a training dummy with your build: %d damage per second (%d fight%s, Blizzard's meter).",
      math.floor(real + 0.5), fights, fights == 1 and "" or "s")
  else
    lines[#lines + 1] = "Hit a training dummy in a capital for 10 seconds or more: Outrider records your real damage per second for your build here."
  end
  lines[#lines + 1] = "|cff8f96a6An estimate from your spells' tooltips and the build's numbers: talents that add or change spells, procs, hit and mana running out aren't counted.|r"
  return table.concat(lines, "\n")
end

function M:Activity()
  local real, fights = self:Measured()
  if real then return string.format("dummy: %d DPS with your build (%d fights)", math.floor(real + 0.5), fights) end
  return "estimates build numbers from your spells"
end
