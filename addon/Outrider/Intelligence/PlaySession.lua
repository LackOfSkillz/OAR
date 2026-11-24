-- Intelligence/PlaySession.lua  (OI03-01)
-- One shared idea of "a play session" for every recorder (SessionXP, Ledger,
-- and what AfterAction builds on them), instead of each guessing on its own.
--
-- A play session runs from a login to a logout. A /reload splits it into
-- segments but doesn't end it. A login with no logout seen before it (crash,
-- disconnect, killed client) ends the previous session as "interrupted".
--
-- How it is told apart: PLAYER_LOGOUT fires for a logout and for a reload
-- alike, so at logout the session is only marked "closing". The next
-- PLAYER_ENTERING_WORLD says which it was: isReloadingUi means the same
-- session goes on (segment + 1, the last segment ended by "reload");
-- isInitialLogin after "closing" means it ended by "logout"; isInitialLogin
-- while still "open" means it was "interrupted". A zone change
-- (PLAYER_ENTERING_WORLD with neither flag) changes nothing.
--
-- Saved: only the marker for this character (ns.db.char.playSession), no
-- history of its own: recorders stamp their own records with Id() and
-- Segment() and are told how the last segment ended (OTR_PLAYSESSION).
-- Merge() joins a recorder's segment records into play sessions, so a reload
-- is never counted as two sessions and never as a completed one.

local _, ns = ...
local M = ns:NewModule("PlaySession", {
  title = "Play session boundaries", phase = "P9", order = 4,
  defaults = {},
})
ns.PlaySession = M

function M:Store()
  local c = ns.db.char
  local s = ns.KeepTable(c.playSession, "PlaySession:char.playSession")
  if type(s) ~= "table" then s = {} c.playSession = s end
  return s
end

function M:Id() return self:Store().id end
function M:Segment() return tonumber(self:Store().segment) or 1 end
function M:Current() local s = self:Store() return { id = s.id, segment = tonumber(s.segment) or 1, startedAt = s.startedAt, state = s.state, lastEnd = s.lastEnd } end

local function newId(now)
  return string.format("ps:%s:%s", tostring(now), tostring(ns.session or "s"))
end

-- the boundary decision, pure: previous marker state and the PEW flags ->
-- kind ("new"|"reload"|"zone"), how the previous segment ended
function M.Decide(state, isInitialLogin, isReloadingUi)
  if isReloadingUi then
    if state == "closing" or state == "open" then return "reload", "reload" end
    return "new", nil -- a reload with no session known: start one
  end
  if isInitialLogin then
    if state == "closing" then return "new", "logout" end
    if state == "open" then return "new", "interrupted" end
    return "new", nil
  end
  return "zone", nil
end

function M:OnEnter(isInitialLogin, isReloadingUi)
  local s, now = self:Store(), time()
  local kind, ended = M.Decide(s.state, isInitialLogin == true, isReloadingUi == true)
  if kind == "zone" then
    if not s.id then kind = "new" else return end
  end
  local prev = s.id and { id = s.id, segment = tonumber(s.segment) or 1, reason = ended, at = s.closingAt or s.lastSeenAt } or nil
  if kind == "reload" then
    s.segment = (tonumber(s.segment) or 1) + 1
  else
    s.id, s.segment, s.startedAt = newId(now), 1, now
  end
  s.state, s.lastSeenAt, s.closingAt = "open", now, nil
  s.lastEnd = prev and { id = prev.id, segment = prev.segment, reason = prev.reason, at = prev.at } or nil
  self:Info("play session %s segment %d (%s%s)", tostring(s.id), s.segment, kind,
    prev and prev.reason and (", last ended by " .. prev.reason) or "")
  ns.Events:Fire("OTR_PLAYSESSION", kind, prev)
end

function M:OnLogout()
  local s = self:Store()
  if not s.id then return end
  s.state, s.closingAt, s.lastSeenAt = "closing", time(), time()
end

function M:OnEnable()
  self:On("PLAYER_ENTERING_WORLD", function(mod, _, isInitialLogin, isReloadingUi) mod:OnEnter(isInitialLogin, isReloadingUi) end)
  self:On("PLAYER_LOGOUT", self.OnLogout)
end

-- Join segment records into play sessions. records: a recorder's list in
-- time order, each optionally with playSessionId; spec says how to combine:
--   sum = { fields added up }, first = { fields from the first segment },
--   last = { fields from the last segment }, any = { boolean fields OR-ed }.
-- A record without a playSessionId (older data) stays its own session.
-- Returns new tables; the records themselves are never changed.
function M.Merge(records, spec)
  spec = spec or {}
  local out, byId = {}, {}
  for _, r in ipairs(records or {}) do
    if type(r) == "table" then
      local id = r.playSessionId
      local into = id and byId[id]
      if not into then
        into = { segments = 0, playSessionId = id }
        for k, v in pairs(r) do into[k] = v end
        into.segments = 1
        out[#out + 1] = into
        if id then byId[id] = into end
      else
        into.segments = into.segments + 1
        for _, f in ipairs(spec.sum or {}) do
          if type(r[f]) == "number" then into[f] = (tonumber(into[f]) or 0) + r[f] end
        end
        for _, f in ipairs(spec.last or {}) do if r[f] ~= nil then into[f] = r[f] end end
        for _, f in ipairs(spec.any or {}) do if r[f] then into[f] = true end end
      end
    end
  end
  return out
end

function M:Activity()
  local s = self:Store()
  return s.id and string.format("session %s, segment %d", tostring(s.id), tonumber(s.segment) or 1) or "no session yet"
end
