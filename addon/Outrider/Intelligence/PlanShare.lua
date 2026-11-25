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

-- OI07-06: a mentor's bundle: plan steps, lessons and a route, data only.
--   ExportBundle{ title, source, license, build, steps, lessons, route = { {mapID, x, y, name} } }
--   PreviewBundle(text) checks each part for this character: lesson ids must be
--   Outrider lessons this character is eligible for; route points need a map
--   id and 0..1 coordinates; plan steps as in Check. What doesn't fit is listed
--   and left out. AcceptBundle(preview, token) records what fits: the plan as
--   an offered plan, the lessons as assigned (offered first), the route as a
--   saved suggestion; nothing is set, cast or moved. Source, license and build
--   are kept on the record.
PS.MAX_ROUTE = 50
function PS.ExportBundle(b)
  if type(b) ~= "table" then return nil, "a bundle is a table" end
  if type(b.license) ~= "string" or b.license == "" then return nil, "a bundle needs a license" end
  local out = { v = PS.VERSION, kind = "bundle", title = tostring(b.title or "Bundle"):sub(1, 60), source = tostring(b.source or "mentor"):sub(1, 40),
    license = b.license:sub(1, 40), build = b.build or (ns.World and ns.World.Build()), steps = {}, lessons = {}, route = {},
    classes = b.classes, minLevel = b.minLevel, maxLevel = b.maxLevel }
  for i, s in ipairs(b.steps or {}) do if not plainId(s) then return nil, "step " .. i .. " isn't a plain id" end out.steps[i] = s end
  for i, l in ipairs(b.lessons or {}) do if not plainId(l) and not (type(l) == "string" and l:match("^[%l]+%.[%l]+%.%d+@%d+$")) then return nil, "lesson " .. i .. " isn't a lesson id" end out.lessons[i] = l end
  for i, p in ipairs(b.route or {}) do
    if type(p) ~= "table" then return nil, "route point " .. i .. " isn't a point" end
    out.route[i] = { mapID = p.mapID, x = p.x, y = p.y, name = p.name and tostring(p.name):sub(1, 40) }
  end
  return ns.Serialize.Export(out)
end

function PS.PreviewBundle(text, now)
  local d, err = ns.Serialize.Import(text)
  if type(d) ~= "table" then return nil, err or "not readable" end
  if d.kind ~= "bundle" or d.v ~= PS.VERSION then return nil, "not a mentor bundle" end
  if type(d.license) ~= "string" or d.license == "" then return nil, "no license: not installed" end
  for k, v in pairs(d) do if type(v) == "function" then return nil, "field " .. tostring(k) .. " isn't data" end end
  local me = ns.Expedition and ns.Expedition.Me() or { class = ns.PlayerClass(), level = 1 }
  me.build = ns.World and ns.World.Build()
  local out = { title = tostring(d.title), source = tostring(d.source), license = d.license, build = d.build, fits = { lessons = {}, route = {} }, left = {} }
  if type(d.steps) == "table" and #d.steps > 0 then
    local rec, why = PS.Check({ v = PS.VERSION, steps = d.steps, classes = d.classes, minLevel = d.minLevel, maxLevel = d.maxLevel,
      build = d.build, title = d.title, source = d.source }, me, now)
    if rec then out.fits.plan = rec else out.left[#out.left + 1] = "plan: " .. tostring(why) end
  end
  local eligible = {}
  for _, l in ipairs(ns.Expedition and ns.Expedition.Eligible(me) or {}) do eligible[l.id] = true end
  for _, id in ipairs(type(d.lessons) == "table" and d.lessons or {}) do
    if eligible[id] then out.fits.lessons[#out.fits.lessons + 1] = id else out.left[#out.left + 1] = "lesson " .. tostring(id) .. ": not for you (or unknown)" end
  end
  for i, p in ipairs(type(d.route) == "table" and d.route or {}) do
    if i > PS.MAX_ROUTE then out.left[#out.left + 1] = "route: more than " .. PS.MAX_ROUTE .. " points" break end
    local okPoint = type(p) == "table" and type(p.mapID) == "number" and p.mapID == math.floor(p.mapID) and p.mapID > 0
      and type(p.x) == "number" and p.x > 0 and p.x < 1 and type(p.y) == "number" and p.y > 0 and p.y < 1
    if okPoint then out.fits.route[#out.fits.route + 1] = { mapID = p.mapID, x = p.x, y = p.y, name = p.name and tostring(p.name) }
    else out.left[#out.left + 1] = "route point " .. i .. ": not a map point" end
  end
  out.token = ns.Serialize.Adler32(text)
  return out
end

function PS.AcceptBundle(pv, token)
  if type(pv) ~= "table" or token ~= pv.token then return false, "preview the bundle, then accept that preview" end
  local st = PS.Store()
  local stamp = { source = pv.source, license = pv.license, build = pv.build, at = time() }
  if pv.fits.plan then
    local rec = pv.fits.plan
    rec.license, rec.status = pv.license, "accepted"
    st.offered[#st.offered + 1] = rec
  end
  if #pv.fits.route > 0 then
    st.routes = ns.KeepTable(st.routes, "PlanShare:routes") or {}
    st.routes[#st.routes + 1] = { title = pv.title, points = pv.fits.route, stamp = stamp }
  end
  local X = ns.Expedition
  if X and #pv.fits.lessons > 0 then
    local ex = X.Store()
    ex.assigned = ns.KeepTable(ex.assigned, "Expedition:assigned") or {}
    for _, id in ipairs(pv.fits.lessons) do ex.assigned[id] = stamp end
  end
  return true
end
