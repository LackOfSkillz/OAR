-- Intelligence/Troubleshooter.lua  (OI07-07: troubleshooter expansion)
-- "Why isn't this working?" Each check gives a plain reason and a safe thing
-- the player can do by hand. A check that fails to run says "couldn't check"
-- (never "all fine"):
--   quest_prerequisite  plan steps left out because they need an earlier quest
--   stale_route         waypoint route stops on a map the client doesn't know
--   macro_rank          an installed macro written for spells that changed
--                       (respec, a new rank) or carrying a "(Rank n)"
--   unsupported_api     functions the probe found missing, and what they turn off
--   role_mismatch       the role picked isn't one this class can play
--   missing_pack        no data pack for something this character uses
--                       (macros for the class, rares, places); quarantined packs
--   module_off          a module the plan reads from is switched off
-- Export() is the same list without character names, realms or gold.

local _, ns = ...
local C = ns.Compat
local TS = {}
ns.Troubleshooter = TS

local CHECKS = {}
local function check(code, fn) CHECKS[#CHECKS + 1] = { code = code, fn = fn } end

check("quest_prerequisite", function(add)
  local N = ns.NexusCore
  if not (N and N.Diagnose) then return end
  for _, d in ipairs(N:Diagnose()) do
    if d.code == "missing_prerequisite" or d.code == "prerequisites_unplannable" then add(d.text, d.remedy or "do the earlier quest first") end
  end
end)

check("stale_route", function(add)
  local W = ns.Modules:Get("Waypoints")
  local q = W and W:Settings().queue or {}
  if not C.Resolve("C_Map.GetMapInfo") then return end
  local bad = 0
  for _, p in ipairs(q) do if p.mapID and C.Call("C_Map.GetMapInfo", p.mapID) == nil then bad = bad + 1 end end
  if bad > 0 then add(string.format("%d stop%s on your route %s on a map the game doesn't know now.", bad, bad == 1 and "" or "s", bad == 1 and "is" or "are"),
    "clear the route (/ride route clear) and set it again") end
end)

check("macro_rank", function(add)
  local L, V = ns.MacroLibrary, ns.MacroVersions
  if not (L and V) then return end
  for name, rec in pairs(L:Settings().installed or {}) do
    local stale = V.Stale({ name = name })
    if stale then add("Macro " .. name .. ": " .. stale .. ".", "open the Macros page and update it") end
    if type(rec.body) == "string" and rec.body:find("%(Rank %d+%)") then
      add("Macro " .. name .. " names a spell rank; a rank-less /cast casts your best rank.", "update it from the Macros page")
    end
  end
end)

check("unsupported_api", function(add)
  local p = ns.db.global.probe
  if type(p) ~= "table" or type(p.apis) ~= "table" then return end
  local missing = {}
  for api, has in pairs(p.apis) do if has == false then missing[#missing + 1] = api end end
  table.sort(missing)
  if #missing > 0 then
    add(string.format("%d game function%s Outrider can use %s missing on this client (%s%s): the features that need them stay off.",
      #missing, #missing == 1 and "" or "s", #missing == 1 and "is" or "are", table.concat(missing, ", ", 1, math.min(5, #missing)), #missing > 5 and ", ..." or ""),
      "nothing to do: this is how the client is; /ride probe again after a game update")
  end
end)

check("role_mismatch", function(add)
  local P = ns.ClassProfiles
  if not (P and P.Current) then return end
  local cur = P.Current() or {}
  if not cur.role or cur.role == "UNKNOWN" then return end
  for _, r in ipairs(P.ROLES[cur.class or ""] or {}) do if r == cur.role then return end end
  add("Your role is set to " .. tostring(cur.role) .. ", which your class can't play.", "pick a role on the Class page")
end)

check("missing_pack", function(add)
  local class = ns.PlayerClass()
  local n = 0
  for _, e in ipairs(ns.Data:All("macro")) do if e.class == class then n = n + 1 end end
  if n == 0 then add("No macro pack for your class is loaded.", "reinstall Outrider; the macro files may be missing") end
  if #ns.Data:All("rare") == 0 then add("No rare data is loaded.", "reinstall Outrider; Data/Rares.lua may be missing") end
  for name, why in pairs(ns.World and ns.World.Quarantined and ns.World.Quarantined() or {}) do
    add("Data pack " .. name .. " was set aside: " .. tostring(why) .. ".", "use a pack with a license and an evidence class")
  end
end)

check("module_off", function(add)
  local N = ns.NexusCore
  if not (N and N.Settings and N:Settings().on) then return end
  local off = {}
  for _, name in ipairs({ "QuestLog", "Nearby", "Waypoints", "Spellbook", "Prices", "Travel" }) do
    local m = ns.Modules:Get(name)
    if m and not m.enabled then off[#off + 1] = name end
  end
  if #off > 0 then add("The planner reads from modules that are off: " .. table.concat(off, ", ") .. ".", "switch them on on the Modules page, or ignore this") end
end)

TS.CODES = {}
for _, c in ipairs(CHECKS) do TS.CODES[#TS.CODES + 1] = c.code end

function TS.Run()
  local out = {}
  for _, c in ipairs(CHECKS) do
    local ok, err = pcall(c.fn, function(text, remedy) out[#out + 1] = { code = c.code, text = text, remedy = remedy } end)
    if not ok then out[#out + 1] = { code = c.code, couldnt = true, text = "Couldn't check " .. c.code:gsub("_", " ") .. ".", remedy = "type /ride errors and report it", err = tostring(err) } end
  end
  return out
end

-- no names, realms, gold or error text with paths
function TS.Export(list)
  list = list or TS.Run()
  local lines = { "Outrider troubleshooter, build " .. tostring(ns.World and ns.World.Build() or "?") }
  local me = ns.db.key and ns.db.key:match("^([^%-]+)")
  for _, r in ipairs(list) do
    local t = tostring(r.text)
    if me then t = t:gsub(me, "<you>") end
    lines[#lines + 1] = string.format("[%s] %s Fix: %s", r.code, t, tostring(r.remedy or "-"))
  end
  if #list == 0 then lines[#lines + 1] = "No problems found by these checks: " .. table.concat(TS.CODES, ", ") end
  return table.concat(lines, "\n")
end

function TS.Cards(refresh)
  local out = {}
  local list = TS.Run()
  for _, r in ipairs(list) do
    out[#out + 1] = { title = r.couldnt and "Couldn't check" or r.code:gsub("_", " "), line = r.text .. (r.remedy and (" What to do: " .. r.remedy .. ".") or "") }
  end
  if #list == 0 then out[1] = { title = "No problems found", line = "These checks found nothing wrong: " .. table.concat(TS.CODES, ", "):gsub("_", " ") .. "." } end
  out[#out + 1] = { title = "Share it", line = "Copy the list without your name, realm or gold, to paste in a bug report.",
    actions = { { "Copy the list", function() ns.UI:TextDialog("Troubleshooter", TS.Export(list), "copy") end, "Copy the checks to paste in a report." },
      { "Check again", function() if refresh then refresh() end end, "Run every check again." } } }
  return out
end

ns.Hub:AddTab("troubleshoot", "Fix problems", function(p)
  ns.UI:FormPage(p, {
    { "header", "Why isn't it working?", icon = "Trade_Engineering" },
    { "note", "Each check gives a reason and a safe thing you can do yourself." },
    { "cards", function() return TS.Cards(function() p:Refresh() end) end },
  })
end)
