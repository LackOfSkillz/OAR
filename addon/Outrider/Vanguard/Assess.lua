-- Vanguard/Assess.lua
-- VG03-04/10: one assessment of the current group for one place, and one
-- row per boss. Inputs: the roster snapshot, the cached profiles (memory
-- only), the roles (yours over the group's over the game's guess), the
-- catalog entry and your own answers. Output (spec section 7, Assessment):
--   { contextKey, catalogVersion, rosterGeneration, revisions, score (Readiness),
--     results = per requirement {id, l, u, text, verification}, risks,
--     unknowns, assumptions, bosses = { {name, level, score, risks} }, expiresAt }
-- Risk tags explain; they are not chances. No boss row claims to know a
-- boss's mechanics: none are in the data.
-- Context invalidation: the key covers the group, roles, profile revisions,
-- catalog version, place and your answers; Valid() fails as soon as any of
-- them changes or the oldest profile turns stale. Nothing old is shown as
-- current.

local _, ns = ...
ns.Vanguard = ns.Vanguard or {}
local V = ns.Vanguard
local As = { VERSION = 1 }
V.Assess = As

local function now() return (GetTime and GetTime()) or 0 end

-- members with their role, level and class, from the snapshot
local function people(snap, roleOf)
  local out = {}
  for _, m in ipairs(snap and snap.members or {}) do
    local r = roleOf(m)
    out[#out + 1] = { member = m, role = r and r.value, roleSource = r and r.source, level = V.Obs.Num(m.level),
      class = V.Obs.Value(m.class) }
  end
  return out
end

local function roleCount(ps, role, target)
  local have, unknown = 0, 0
  for _, p in ipairs(ps) do
    if p.role == role then have = have + 1 elseif not p.role then unknown = unknown + 1 end
  end
  local l = math.min(1, have / target)
  local u = math.min(1, (have + unknown) / target)
  local text = string.format("%d of %d%s", have, target, unknown > 0 and string.format(" (%d role(s) unknown)", unknown) or "")
  return l, u, text, have
end

-- evaluate one requirement for the group
function As.Evaluate(r, ps, cov, st)
  if r.category == "role" then
    local role = ({ tank = "TANK", healer = "HEALER", damage = "DAMAGER" })[r.id]
    local l, u, text = roleCount(ps, role, r.target)
    return l, u, text
  elseif r.category == "size" then
    local n = #ps
    local f = math.min(1, n / r.target)
    return f, f, string.format("%d of %d", n, r.target)
  elseif r.category == "level" then
    local ok, unknown = 0, 0
    for _, p in ipairs(ps) do
      if p.level == nil then unknown = unknown + 1 elseif p.level >= r.target then ok = ok + 1 end
    end
    local n = math.max(1, #ps)
    return ok / n, (ok + unknown) / n, string.format("%d of %d at %d or above%s", ok, #ps, r.target,
      unknown > 0 and string.format(", %d unknown", unknown) or "")
  elseif r.category == "utility" then
    local c = cov[r.cap]
    if not c then return 0, 1, "unknown" end
    if c.state == "covered" then return 1, 1, "covered (in your spellbook)" end
    if c.state == "none" then return 0, 0, "nobody in the group has it" end
    if c.state == "potential" then return 0, 1, "likely: class and level could (trained or not, the game doesn't show)" end
    if c.state == "talent" then return 0, 1, "only by a talent we can't see" end
    if c.state == "unlikely" then return 0, 1, "only below its level in the data" end
    return 0, 1, "unknown: someone's class or level isn't readable"
  elseif r.category == "access" then
    local s, why = V.Access.Check(r.entry, st)
    if s == "met" then return 1, 1, why end
    if s == "unmet" then return 0, 0, why end
    return 0, 1, why or "unknown"
  end
  return 0, 1, "not evaluated"
end

local function results(reqs, ps, cov, st)
  local out = {}
  for _, r in ipairs(reqs) do
    local l, u, text = As.Evaluate(r, ps, cov, st)
    out[#out + 1] = { id = r.id, category = r.category, weight = r.weight, critical = r.critical, l = l, u = u, text = text,
      rule = r.rule, verification = r.verification, source = r.source }
  end
  return out
end

-- the context key: anything that changes the answer
function As.Key(snap, entry, profiles, roleRev, st, catVersion)
  local parts = { tostring(snap and snap.generation), tostring(entry and entry.instanceId), tostring(catVersion), tostring(roleRev or 0) }
  for _, m in ipairs(snap and snap.members or {}) do
    local p = profiles[m.key]
    parts[#parts + 1] = p and tostring(p.rev) or "-"
  end
  local a = st and st.access and entry and st.access[entry.instanceId]
  parts[#parts + 1] = tostring(a)
  local needs = {}
  for boss, caps in pairs(st and st.bossNeeds or {}) do
    for cap in pairs(caps) do needs[#needs + 1] = boss .. ":" .. cap end
  end
  table.sort(needs)
  parts[#parts + 1] = table.concat(needs, ",")
  return table.concat(parts, "|")
end

-- ctx: { snap, entry, roleOf(member), profiles = { [key] = profile },
--        cachedAt = { [key] = time }, ttl, roleRev, st }
function As.Build(ctx)
  local entry, snap = ctx.entry, ctx.snap
  local cat = V.Catalog.Get()
  local ps = people(snap, ctx.roleOf)
  local cov = V.Utility.Coverage(snap and snap.members or {})
  local reqs = {}
  for _, r in ipairs(entry and entry.requirements or {}) do reqs[#reqs + 1] = r end
  local answered = entry and ctx.st and ctx.st.access and ctx.st.access[entry.instanceId] ~= nil
  local f = entry and entry.access
  if answered then
    reqs[#reqs + 1] = { id = "access", category = "access", weight = 2, critical = true, target = 1, entry = entry,
      rule = "you can get in (your answer)", verification = "manual", source = "your own answer" }
  elseif type(f) == "table" and f.needs and f.needs ~= "none" then
    reqs[#reqs + 1] = { id = "access", category = "access", weight = 2, critical = true, target = 1, entry = entry,
      rule = string.format("you can get in (%s%s)", tostring(f.itemName or f.questName or f.needs), f.who == "each" and ", everyone needs it" or ""),
      verification = f.kind == "forever" and "reference" or "classic", source = tostring(f.source or "guide") }
  end
  local res = results(reqs, ps, cov, ctx.st)
  local a = { version = As.VERSION, instance = entry and entry.instanceId, catalogVersion = cat.version,
    rosterGeneration = snap and snap.generation, builtAt = now(), results = res, score = V.Readiness.Score(res),
    unknowns = {}, assumptions = {}, risks = {}, bosses = {} }
  for _, u in ipairs(entry and entry.unknowns or {}) do a.unknowns[#a.unknowns + 1] = u end
  a.assumptions[#a.assumptions + 1] = V.Catalog.TEMPLATE
  if entry and entry.availability ~= "verified" then a.assumptions[#a.assumptions + 1] = "level range and size are reference data, not verified on Forever" end
  -- unread members
  local unread = 0
  for _, p in ipairs(ps) do if not ctx.profiles[p.member.key] then unread = unread + 1 end end
  if unread > 0 then a.unknowns[#a.unknowns + 1] = string.format("%d member(s) not scanned: gear and talents unknown", unread) end
  -- risks: what is confirmed short, then what is unknown
  for _, r in ipairs(res) do
    if r.u == 0 then a.risks[#a.risks + 1] = { id = r.id, level = "missing", text = r.rule .. ": " .. r.text }
    elseif r.u < 1 then a.risks[#a.risks + 1] = { id = r.id, level = "short", text = r.rule .. ": " .. r.text }
    elseif r.l < 1 then a.risks[#a.risks + 1] = { id = r.id, level = "unknown", text = r.rule .. ": " .. r.text } end
  end
  -- bosses: the group's requirements plus your own rules for that boss, and
  -- the boss level against the group's levels (a fact from the pack, not a rule)
  local rules = V.Catalog.BossRules(entry, ctx.st)
  for _, enc in ipairs(entry and entry.encounters or {}) do
    local breqs = {}
    for _, r in ipairs(reqs) do breqs[#breqs + 1] = r end
    for _, r in ipairs(rules[enc.name] or {}) do breqs[#breqs + 1] = r end
    local bres = results(breqs, ps, cov, ctx.st)
    local brisks = {}
    for _, r in ipairs(bres) do
      if r.u == 0 then brisks[#brisks + 1] = r.rule .. ": missing"
      elseif r.u < 1 then brisks[#brisks + 1] = r.rule .. ": short"
      elseif r.l < 1 and r.id:find("^boss:") then
        brisks[#brisks + 1] = r.rule .. ": not confirmed" end
    end
    for _, n in ipairs(enc.notes or {}) do brisks[#brisks + 1] = "watch: " .. n end
    if enc.level then
      local below, unknown = 0, 0
      for _, p in ipairs(ps) do
        if p.level == nil then unknown = unknown + 1 elseif p.level < enc.level then below = below + 1 end
      end
      if below > 0 then brisks[#brisks + 1] = string.format("boss is level %d; %d member(s) below it", enc.level, below) end
      if unknown > 0 then brisks[#brisks + 1] = string.format("%d member level(s) unknown", unknown) end
    end
    a.bosses[#a.bosses + 1] = { name = enc.name, level = enc.level, order = enc.order, score = V.Readiness.Score(bres),
      results = bres, risks = brisks, mine = (function() local n = 0 for _, r in ipairs(rules[enc.name] or {}) do if r.verification == "manual" then n = n + 1 end end return n end)(),
      mechanics = enc.factKind == "forever" and "from Forever guides" or enc.factKind == "classic" and "from Classic sources (Forever may differ)" or "unknown (not in the data)",
      source = enc.factSource }
  end
  -- expiry: the oldest profile's freshness end, if any profile is used
  local exp
  for _, p in ipairs(ps) do
    local t = ctx.cachedAt and ctx.cachedAt[p.member.key]
    if t then exp = math.min(exp or math.huge, t + (ctx.ttl or 300)) end
  end
  a.expiresAt = exp
  a.contextKey = As.Key(snap, entry, ctx.profiles, ctx.roleRev, ctx.st, cat.version)
  return a
end

-- is an assessment still about the current context?
function As.Valid(a, key, t)
  if type(a) ~= "table" then return false, "no assessment" end
  if a.contextKey ~= key then return false, "the group, roles, gear or place changed" end
  if a.expiresAt and (t or now()) >= a.expiresAt then return false, "some gear readings turned old" end
  return true
end
