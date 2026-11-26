-- Vanguard/Adequacy.lua
-- VG02-03/04/05: role indicators for one member. For a tank, healer or damage
-- dealer it reads the stats the role cares about (Vanguard/Roles.lua) from
-- the member's gear (Vanguard/Stats.lua), as ranges. It never turns them into
-- damage taken, healing per second or damage per second: those formulas are
-- not verified on Forever and are listed under "not modeled".
--
-- A check against a target only happens when a target exists (from the
-- encounter catalog, VG03, or one you set yourself, marked as yours):
--   met      the low end reaches the target
--   short    the high end is known and below the target
--   unknown  the range spans the target (some gear unread)
--   no target  nothing verified to compare with: shown for reference
-- Missing inputs widen the range; they never count as zero or as failing.
-- Forge estimates are not used: Forge is experimental and not validated for
-- this (spec section 2).

local _, ns = ...
ns.Vanguard = ns.Vanguard or {}
local Roles, Stats = ns.Vanguard.Roles, ns.Vanguard.Stats
local A = { VERSION = 1 }
ns.Vanguard.Adequacy = A

function A.Check(range, target)
  if type(target) ~= "number" then return "no target" end
  if range.lo >= target then return "met" end
  if range.hi ~= nil and range.hi < target then return "short" end
  return "unknown"
end

-- member: roster member; profile: MemberProfile (may be nil); role: TANK |
-- HEALER | DAMAGER | nil; targets: { [indicator id] = { value, source } }
function A.Assess(member, profile, role, targets, reader)
  local class = member and ns.Vanguard.Obs.Value(member.class)
  local out = { version = A.VERSION, role = role, class = class, indicators = {}, missing = {}, notes = {} }
  local rp, why = Roles.Get(class, role)
  if not rp then
    out.state = "unsupported"
    out.notes[#out.notes + 1] = why
    return out
  end
  out.kinds, out.hybrid, out.missing = rp.kinds, rp.hybrid, rp.missing
  if not profile then
    out.state = "not checked"
    out.notes[#out.notes + 1] = "gear not read yet: scan this member"
    for _, id in ipairs(rp.indicators) do
      local ind = Roles.INDICATORS[id]
      out.indicators[#out.indicators + 1] = { id = id, label = ind.label, unit = ind.unit, range = { lo = 0, hi = nil }, state = "unknown" }
    end
    return out
  end
  local derived = Stats.Derive(profile, reader)
  out.derived = derived
  local counts = { met = 0, short = 0, unknown = 0, ["no target"] = 0 }
  for _, id in ipairs(rp.indicators) do
    local ind = Roles.INDICATORS[id]
    local r = Stats.Range(derived, ind)
    local t = targets and targets[id]
    local state = A.Check(r, t and t.value)
    counts[state] = counts[state] + 1
    out.indicators[#out.indicators + 1] = { id = id, label = ind.label, unit = ind.unit, range = r, state = state,
      target = t and t.value, targetSource = t and t.source, text = Stats.RangeText(r, ind.unit) }
  end
  out.counts = counts
  out.complete = derived.complete
  if not derived.complete then
    out.notes[#out.notes + 1] = string.format("%d slot(s) not fully read: totals are a lower bound", #derived.open)
  end
  if out.hybrid then out.notes[#out.notes + 1] = "hybrid role: build not known, all kinds shown" end
  if counts.short > 0 then out.state = "short"
  elseif counts.unknown > 0 then out.state = "unknown"
  elseif counts.met > 0 then out.state = "met"
  else out.state = "reference" end
  return out
end

local WORD = { met = "|cff66dd77met|r", short = "|cffff6060short|r", unknown = "|cffffd100unknown|r", ["no target"] = "reference" }
function A.Lines(a, max)
  local lines = {}
  for _, i in ipairs(a.indicators or {}) do
    if max and #lines >= max then break end
    lines[#lines + 1] = string.format("%s: %s (%s%s)", i.label, i.text or "unknown", WORD[i.state] or i.state,
      i.target and (", target " .. i.target .. (i.targetSource == "manual" and " (yours)" or "")) or "")
  end
  return lines
end
