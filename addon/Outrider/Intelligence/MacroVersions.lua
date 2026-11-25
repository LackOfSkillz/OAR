-- Intelligence/MacroVersions.lua  (OI05-10: macro versioning and rollback)
-- A layer over MacroLibrary's installer (which already refuses combat, full
-- slots, text over 255 characters and macros the player edited). It adds:
--   Preview(entry)       the new text, the text the game holds now, a line diff,
--                        its length, problems, the reason (rationale) and the
--                        spells it relies on with their rank (source: your
--                        spellbook), plus an approval token
--   Apply(entry, token)  installs only with the token of the CURRENT preview: if
--                        anything changed since (spells, bags, the macro), the
--                        player previews again. A press by the player, never on
--                        an event or a timer.
--   Rollback(entry)      puts back the previous text Outrider wrote (MacroLibrary
--                        keeps the last 8, older ones archived), under the same
--                        rules; the replaced text goes to the front of the list,
--                        so nothing is lost and a second rollback is a redo.
--   Stale(entry)         "your spells changed since this was written" after a
--                        respec or a new rank (spell id or rank differs).
-- Prohibited text is refused before anything else: script commands (/run,
-- /script, /console, /dump) other than MacroLibrary's own quiet line. Outrider
-- never presses a macro; the game runs one only when the player presses it.

local _, ns = ...
local C = ns.Compat
local V = { VERSION = "macroversions-1" }
ns.MacroVersions = V
V.PROHIBITED = { "run", "script", "console", "dump" }

local function lib() return ns.MacroLibrary end
local function E() return ns.MacroEngine end

-- the spell names a macro casts: /cast and /castsequence, conditions,
-- reset=, "!" and "(Rank n)" removed
function V.Spells(body)
  local out, seen = {}, {}
  for line in tostring(body or ""):gmatch("[^\r\n]+") do
    local cmd, rest = line:match("^%s*/(%S+)%s*(.*)$")
    cmd = cmd and cmd:lower()
    if cmd == "cast" or cmd == "castsequence" then
      rest = rest:gsub("%b[]", ""):gsub("reset=%S+", "")
      for part in rest:gmatch("[^;,]+") do
        local name = part:gsub("^%s*!?", ""):gsub("%s*%(Rank %d+%)%s*$", ""):gsub("%s+$", "")
        if name ~= "" and not seen[name:lower()] then seen[name:lower()] = true out[#out + 1] = name end
      end
    end
  end
  table.sort(out)
  return out
end

-- each spell with the id and rank the spellbook has now (nil when unknown)
function V.Fingerprint(body)
  local SB = ns.Spellbook
  local fp = {}
  for _, name in ipairs(V.Spells(body)) do
    local s = SB and SB.spells and SB.spells[name:lower()]
    fp[#fp + 1] = { name = name, id = s and s.id or nil, rank = s and s.rank or nil, known = s ~= nil }
  end
  return fp
end

function V.Prohibited(body)
  local quiet = ns.HandyKeys and ns.HandyKeys.QUIET_LINE
  for line in tostring(body or ""):gmatch("[^\r\n]+") do
    local l = line:gsub("^%s+", ""):gsub("%s+$", "")
    local cmd = l:match("^/(%S+)")
    cmd = cmd and cmd:lower()
    for _, p in ipairs(V.PROHIBITED) do
      if cmd == p and l ~= quiet then return "/" .. p .. " is not allowed in an Outrider macro" end
    end
  end
end

-- a plain line diff: "-" lines leave, "+" lines arrive, " " stay
function V.Diff(old, new)
  local a, b, out = {}, {}, {}
  for l in tostring(old or ""):gmatch("[^\r\n]+") do a[#a + 1] = l end
  for l in tostring(new or ""):gmatch("[^\r\n]+") do b[#b + 1] = l end
  local inB, inA = {}, {}
  for _, l in ipairs(b) do inB[l] = (inB[l] or 0) + 1 end
  for _, l in ipairs(a) do inA[l] = (inA[l] or 0) + 1 end
  for _, l in ipairs(a) do
    if (inB[l] or 0) > 0 then inB[l] = inB[l] - 1 out[#out + 1] = "  " .. l else out[#out + 1] = "- " .. l end
  end
  for _, l in ipairs(b) do
    if (inA[l] or 0) > 0 then inA[l] = inA[l] - 1 else out[#out + 1] = "+ " .. l end
  end
  return out
end

local function gameText(name)
  local index = C.Call("GetMacroIndexByName", name) or 0
  if index == 0 then return nil, 0 end
  local _, _, body = C.Call("GetMacroInfo", index)
  return C.Readable(body), index
end

local function token(new, old, fp)
  local parts = { new or "", old or "" }
  for _, s in ipairs(fp) do parts[#parts + 1] = s.name .. ":" .. tostring(s.id) .. ":" .. tostring(s.rank) end
  return tostring(ns.Serialize.Adler32(table.concat(parts, "\n")))
end

function V.Preview(entry)
  local L = lib()
  if not (L and entry and entry.body) then return nil, "invalid library entry" end
  local new = L:Hold(function() return L.Final((E().Fill(entry.body, L:Values()))) end)
  local old = gameText(entry.name)
  local fp = V.Fingerprint(new)
  local problems = {}
  for _, p in ipairs(E().Validate(new)) do problems[#problems + 1] = p end
  local bad = V.Prohibited(new)
  if bad then problems[#problems + 1] = { level = "error", msg = bad } end
  for _, s in ipairs(fp) do
    if not s.known then problems[#problems + 1] = { level = "warn", msg = "you don't know " .. s.name .. " (yet)" } end
  end
  return { name = entry.name, new = new, old = old, diff = V.Diff(old, new), length = #new, limit = E().MAX,
    problems = problems, rationale = entry.why or entry.desc or entry.explain, spells = fp,
    missing = L:Missing(entry), token = token(new, old, fp) }
end

function V.Apply(entry, tok)
  local pv, why = V.Preview(entry)
  if not pv then return false, why end
  if C.InCombat() then return false, "not in combat" end
  if tok ~= pv.token then return false, "the macro changed since the preview: preview again" end
  local bad = V.Prohibited(pv.new)
  if bad then return false, bad end
  local L = lib()
  local ok, res = L:Install(entry)
  if not ok then return false, res end
  local rec = L:Settings().installed[entry.name]
  if rec then rec.why, rec.spells, rec.version = pv.rationale, pv.spells, V.VERSION end
  return true, res
end

function V.Stale(entry)
  local rec = lib() and lib():Settings().installed[entry.name]
  if not (rec and rec.spells) then return nil end
  local now = {}
  for _, s in ipairs(V.Fingerprint(rec.body)) do now[s.name] = s end
  for _, s in ipairs(rec.spells) do
    local n = now[s.name]
    if not n or n.id ~= s.id or n.rank ~= s.rank then
      return "your spells changed since this was written (" .. s.name .. "): preview the update"
    end
  end
end

function V.Rollback(entry)
  local L = lib()
  if not (L and entry and entry.name) then return false, "invalid library entry" end
  if C.InCombat() then return false, "not in combat" end
  local rec = L:Settings().installed[entry.name]
  if not rec then return false, "Outrider didn't install this one" end
  local prev = rec.prev or {}
  local back = prev[1]
  if not back then return false, "no earlier version to go back to" end
  local cur, index = gameText(entry.name)
  if index == 0 then return false, "the macro is gone from the game" end
  if not L.Wrote(rec, cur, back) then return false, "macro text was changed outside Outrider; review it manually" end
  if #back > E().MAX then return false, "the earlier version is over " .. E().MAX .. " characters" end
  local bad = V.Prohibited(back)
  if bad then return false, bad end
  local ok, result = pcall(EditMacro, index, entry.name, nil, back)
  if not ok or result == false then return false, "EditMacro failed" end
  table.remove(prev, 1)
  table.insert(prev, 1, rec.body)
  rec.body, rec.t, rec.prev = back, time(), prev
  rec.spells = V.Fingerprint(back)
  L:Info("rolled back macro %s (%d chars)", entry.name, #back)
  return true
end
