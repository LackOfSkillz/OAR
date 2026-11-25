-- Intelligence/Challenges.lua  (OI07-10: explorer challenges)
-- Voluntary personal milestones, no timers and no pressure:
--   visit     a zone from the leveling guide that fits your level (its range
--             covers you) and your faction isn't shut out of; done when your
--             Chronicle has your first visit. With the outcome recorder off,
--             Outrider doesn't know where you've been: "visit unknown", never done.
--   meet      meet 5 NPCs in a zone (Discovery counts NPCs seen there on this
--             account); a count Outrider has, so it's known
-- Only from guide entries and your own records; nothing invented. Dismiss
-- hides one; Reset brings dismissed ones back (archived first).

local _, ns = ...
local C = ns.Compat
local CH = { MEET = 5, MAX = 4 }
ns.Challenges = CH

function CH.Store()
  local c = ns.db.char
  c.challenges = ns.KeepTable(c.challenges, "Challenges:char.challenges") or {}
  c.challenges.dismissed = ns.KeepTable(c.challenges.dismissed, "Challenges:dismissed") or {}
  return c.challenges
end

-- visited zone names from the Chronicle, or nil when Outrider can't know
local function visited()
  local O = ns.Outcomes
  if not (O and O.enabled) then return nil end
  local ok, store = pcall(O.Store, O)
  if not ok or type(store) ~= "table" then return nil end
  local out = {}
  for _, e in ipairs(store.chronicle or {}) do
    if e.kind == "zone" and type(e.text) == "string" then out[e.text:gsub("^First visit to ", "")] = true end
  end
  return out
end

local function metIn(zoneName)
  local n = 0
  for _, e in pairs(ns.db.global.discovered and ns.db.global.discovered.npcs or {}) do
    if type(e) == "table" and e.mapID then
      local info = C.Call("C_Map.GetMapInfo", e.mapID)
      if type(info) == "table" and info.name == zoneName then n = n + 1 end
    end
  end
  return n
end

function CH.List(me)
  me = me or { level = tonumber(C.Readable(C.Call("UnitLevel", "player"))) or 1, faction = C.Readable(C.Call("UnitFactionGroup", "player")) }
  local st = CH.Store()
  local seen = visited()
  local out = {}
  local zones = ns.Data:All("zoneguide")
  table.sort(zones, function(a, b) return (a.lo or 0) < (b.lo or 0) or ((a.lo or 0) == (b.lo or 0) and a.name < b.name) end)
  for _, z in ipairs(zones) do
    local fits = (z.lo or 1) <= me.level and me.level <= (z.hi or 60)
    local shut = z.faction and me.faction and z.faction ~= me.faction
    if fits and not shut then
      local id = "visit:" .. z.name
      if not st.dismissed[id] then
        local state = seen == nil and "unknown" or (seen[z.name] and "done" or "open")
        out[#out + 1] = { id = id, kind = "visit", title = "Visit " .. z.name, state = state, source = z.source, verified = z.verified,
          why = state == "unknown" and "where you've been isn't recorded (the outcome recorder is off)" or nil }
      end
      local mid = "meet:" .. z.name
      if not st.dismissed[mid] then
        local n = metIn(z.name)
        out[#out + 1] = { id = mid, kind = "meet", title = string.format("Meet %d people in %s", CH.MEET, z.name), state = n >= CH.MEET and "done" or "open",
          progress = math.min(n, CH.MEET), goal = CH.MEET }
      end
    end
  end
  return out
end

function CH.Dismiss(id) CH.Store().dismissed[id] = time() end
function CH.Reset()
  local st = CH.Store()
  if ns.Archive and ns.Archive.Put then ns.Archive:Put("challengesDismissed", st.dismissed, { path = "char.challenges.dismissed", scope = "char" }) end
  st.dismissed = {}
end

function CH.Cards(refresh)
  local function again() if refresh then refresh() end end
  local out = {}
  for _, c in ipairs(CH.List()) do
    if #out >= CH.MAX then break end
    if c.state ~= "done" then
      local line = c.kind == "meet" and string.format("%d of %d so far.", c.progress, c.goal)
        or (c.state == "unknown" and ("Can't tell if you've been: " .. c.why .. ".") or "Not yet visited.")
      out[#out + 1] = { title = c.title, tags = { c.state == "unknown" and { "visit unknown", "warn" } or { "open", "plain" } }, line = line .. " Just for fun: no timer.",
        actions = { { "Not for me", function() CH.Dismiss(c.id) again() end, "Hide this challenge." } } }
    end
  end
  if #out == 0 then out[1] = { title = "Explorer", line = "No challenge right now." } end
  out[#out + 1] = { title = "Challenges", line = "Small goals for exploring, from the leveling guide and what you've seen.",
    actions = { { "Show hidden ones", function() CH.Reset() again() end, "Bring back the challenges you hid." } } }
  return out
end
