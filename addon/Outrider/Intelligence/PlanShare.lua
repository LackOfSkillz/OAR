-- Intelligence/PlanShare.lua  (OI06-12: mentor plan portability foundation)
-- A shareable plan REFERENCE: data only, never code. A mentor exports
--   { v, title, source, version, build, classes, roles, minLevel, maxLevel,
--     expires, steps = { opportunity ids } }
-- as an OTR1 string. Importing checks it and puts it in "offered" plans; the
-- player accepts or declines it by hand. An accepted plan only pins its first
-- step the player picks on the Plan page; nothing runs, casts or moves.
-- Rejected: not a plan, too many steps, ids that aren't plain ids, a class
-- or level this character doesn't fit. Marked stale: expired, or made for an
-- older build than the client's (it may still be fine; the player decides).

local _, ns = ...
local PS = { VERSION = 1, MAX_STEPS = 30, MAX_ID = 60 }
ns.PlanShare = PS

local function plainId(v) return type(v) == "string" and #v > 0 and #v <= PS.MAX_ID and v:match("^[%w:_%-%.]+$") ~= nil end

function PS.Store()
  local c = ns.db.char
  c.planshare = ns.KeepTable(c.planshare, "PlanShare:char.planshare") or {}
  c.planshare.offered = ns.KeepTable(c.planshare.offered, "PlanShare:offered") or {}
  return c.planshare
end

function PS.Export(plan)
  if type(plan) ~= "table" or type(plan.steps) ~= "table" then return nil, "a plan needs steps" end
  local out = { v = PS.VERSION, title = tostring(plan.title or "Plan"):sub(1, 60), source = tostring(plan.source or "mentor"):sub(1, 40),
    version = tostring(plan.version or "1"):sub(1, 20), build = plan.build or (ns.World and ns.World.Build()),
    classes = plan.classes, roles = plan.roles, minLevel = plan.minLevel, maxLevel = plan.maxLevel, expires = plan.expires, steps = {} }
  for i, s in ipairs(plan.steps) do
    if not plainId(s) then return nil, "step " .. i .. " isn't a plain id" end
    out.steps[i] = s
  end
  return ns.Serialize.Export(out)
end

-- check a decoded reference for this character; returns rec or nil, why
function PS.Check(d, me, now)
  now = now or time()
  if type(d) ~= "table" or d.v ~= PS.VERSION or type(d.steps) ~= "table" then return nil, "not a plan reference" end
  if #d.steps == 0 or #d.steps > PS.MAX_STEPS then return nil, "a plan has 1 to " .. PS.MAX_STEPS .. " steps" end
  for i, s in ipairs(d.steps) do if not plainId(s) then return nil, "step " .. i .. " isn't a plain id" end end
  for k, v in pairs(d) do if type(v) == "function" then return nil, "field " .. tostring(k) .. " isn't data" end end
  if type(d.classes) == "table" and #d.classes > 0 then
    local ok = false
    for _, c in ipairs(d.classes) do if c == me.class then ok = true end end
    if not ok then return nil, "made for another class" end
  end
  if (tonumber(d.minLevel) and me.level < d.minLevel) or (tonumber(d.maxLevel) and me.level > d.maxLevel) then
    return nil, string.format("made for levels %s to %s", tostring(d.minLevel or "?"), tostring(d.maxLevel or "?"))
  end
  local rec = { title = tostring(d.title), source = tostring(d.source), version = tostring(d.version), build = d.build, steps = d.steps,
    status = "offered", at = now }
  if tonumber(d.expires) and d.expires < now then rec.stale = "expired" end
  if d.build and me.build and ns.World and ns.World.older(d.build, me.build) then rec.stale = rec.stale or ("made for build " .. tostring(d.build)) end
  return rec
end

function PS.Import(text, now)
  local d, err = ns.Serialize.Import(text)
  if d == nil then return nil, err end
  local me = { class = ns.PlayerClass(), level = tonumber(ns.Compat.Readable(ns.Compat.Call("UnitLevel", "player"))) or 1,
    build = ns.World and ns.World.Build() }
  local rec, why = PS.Check(d, me, now)
  if not rec then return nil, why end
  local st = PS.Store()
  st.offered[#st.offered + 1] = rec
  return rec
end

-- the player's choice; accepting changes nothing in the game
function PS.Decide(i, accept)
  local rec = PS.Store().offered[i]
  if not rec or rec.status ~= "offered" then return false end
  rec.status, rec.decided = accept and "accepted" or "declined", time()
  return true
end
