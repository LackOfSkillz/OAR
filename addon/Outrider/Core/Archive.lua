-- Core/Archive.lua
-- Where collected data goes instead of being deleted (owner data preservation
-- override and retention decision 2026-11-24,
-- docs/blueprint/OWNER_DIRECTIVE_DATA_PRESERVATION.md; review OI01-R01..R04).
--
-- Contract (v2):
--   ns.Archive:Move(dataset, list, index, ctx) -> ok, err
--       copy list[index] into the archive, confirm the write, and only then
--       remove it from the working list. On any failure the row stays where it
--       was and ok is false, so a `while #list > CAP and Archive:Shift(...)`
--       loop simply stops: no data is lost and nothing loops forever.
--   ns.Archive:Shift(dataset, list, ctx)  = Move(dataset, list, 1, ctx)   (oldest)
--   ns.Archive:Pop(dataset, list, ctx)    = Move(dataset, list, #list, ctx)
--   ns.Archive:Put(dataset, row, ctx)     archive a row that is leaving by
--       another route (the caller removes it only when ok is true)
--   ns.Archive:Rows(dataset, char)        archived entries, oldest first (char filter optional)
--   ns.Archive:Restore(dataset, fn)       calls fn(entry) for each entry, so a
--       module can put rows back into its own store; the archive keeps its copy
--   ctx = { path = "<logical saved-data path>", keys = { npcID = 1, ... },
--           scope = "account" | "char" }
--
-- An entry is { id, path, keys, scope, char, at, row }. `row` is the original table,
-- copied at the moment it was archived (a snapshot); path + keys say exactly
-- where it came from, so it can be put back.
-- Storage: Outrider_DB.global.archive = { v = 2, sets = { [dataset] = { entry, ... } } }.
-- A saved value of the wrong type is never overwritten: it moves, unchanged, to
-- Outrider_DB.global.archiveDamaged with the path it was found at.

local _, ns = ...
local Archive = { V = 2, warned = {} }
ns.Archive = Archive

local function g() return ns.db and ns.db.global end

-- keep a damaged value, unchanged, with where it was found
function Archive:KeepDamaged(path, value)
  local root = g()
  if not root then
    -- saved data not ready: wait in the pending list (flushed after DB init)
    ns.damagedPending[#ns.damagedPending + 1] = { path = path, value = value }
    return true
  end
  -- the same damaged value seen again this session is already kept
  local sig = tostring(path) .. "|" .. type(value) .. "|" .. tostring(value)
  Archive.keptThisSession = Archive.keptThisSession or {}
  if type(value) ~= "table" and Archive.keptThisSession[sig] then return true end
  Archive.keptThisSession[sig] = true
  -- no cap: only values that were already saved reach this (incoming messages,
  -- packs, pasted codes and API results are rejected by their callers, review
  -- OI01-R10), and a saved value is always kept (review OI01-R12)
  local d = root.archiveDamaged
  if d ~= nil and type(d) ~= "table" then
    d = { { path = "archiveDamaged", value = d, at = time() } }
  end
  d = d or {}
  root.archiveDamaged = d
  d[#d + 1] = { path = path, value = value, at = time() }
  return true
end

-- values found damaged before the saved data was ready (ns.KeepBad, Init.lua)
function Archive:FlushPending()
  local list = ns.damagedPending
  if type(list) ~= "table" or #list == 0 or not g() then return 0 end
  ns.damagedPending = {}
  for _, d in ipairs(list) do self:KeepDamaged(d.path, d.value) end
  return #list
end

-- the v2 sets table; an older or damaged archive is kept aside, never dropped
function Archive:Sets()
  local root = g()
  if not root then return nil, "no saved data yet" end
  local a = root.archive
  if a ~= nil and (type(a) ~= "table" or a.v ~= Archive.V or type(a.sets) ~= "table") then
    self:KeepDamaged("archive", a)
    a = nil
  end
  if not a then
    a = { v = Archive.V, sets = {} }
    root.archive = a
  end
  return a.sets
end

local function report(dataset, err)
  if Archive.warned[dataset] then return end
  Archive.warned[dataset] = true
  if ns.Log then ns.Log:Warn("archive", "%s: row kept in place, archive write failed (%s)", tostring(dataset), tostring(err)) end
end

function Archive:Put(dataset, row, ctx)
  if row == nil then return false, "nothing to archive" end
  if type(dataset) ~= "string" or dataset == "" then return false, "no dataset name" end
  local sets, err = self:Sets()
  if not sets then return false, err end
  local list = sets[dataset]
  if list ~= nil and type(list) ~= "table" then
    self:KeepDamaged("archive.sets." .. dataset, list)
    list = nil
  end
  if not list then list = {} sets[dataset] = list end
  ctx = type(ctx) == "table" and ctx or {}
  -- a stable id per entry (session + counter) so a later lossless off-load can
  -- confirm exactly which entries it copied (docs/ARCHIVE_GROWTH.md)
  Archive.seq = (Archive.seq or 0) + 1
  -- a snapshot, not a reference: later edits to the source row (another module
  -- still holding it) can't change what was archived (review OI01-R09)
  local snap = type(row) == "table" and ns.CopyTable(row) or row
  local entry = { id = string.format("%s:%d", tostring(ns.session or "?"), Archive.seq), path = ctx.path,
    keys = type(ctx.keys) == "table" and ns.CopyTable(ctx.keys) or ctx.keys,
    scope = ctx.scope or "account", char = ns.db and ns.db.key, at = time(), row = snap }
  local n = #list
  list[n + 1] = entry
  if list[n + 1] ~= entry then return false, "write not confirmed" end
  return true
end

function Archive:Move(dataset, list, index, ctx)
  if type(list) ~= "table" then return false, "not a list" end
  index = index or 1
  local row = list[index]
  if row == nil then return false, "no row at " .. tostring(index) end
  local okCall, ok, err = pcall(self.Put, self, dataset, row, ctx)
  if not okCall then ok, err = false, ok end
  if not ok then report(dataset, err) return false, err end
  table.remove(list, index)
  return true
end

-- Keep a value that is about to be replaced (an old schema, say): the archive
-- first, the damaged-data list if that fails. True only when one of them
-- confirmed it. A caller that gets false must NOT replace the value (review
-- OI-FR03): it keeps the original and works on a copy that isn't saved.
function Archive:Preserve(dataset, value, ctx)
  local okPut, put, err = pcall(self.Put, self, dataset, value, ctx)
  if okPut and put then return true end
  local path = type(ctx) == "table" and ctx.path or dataset
  local okKeep, kept = pcall(self.KeepDamaged, self, path, value)
  if okKeep and kept then return true end
  report(dataset, (okPut and err) or put or "could not keep it")
  return false
end

function Archive:Shift(dataset, list, ctx) return self:Move(dataset, list, 1, ctx) end
function Archive:Pop(dataset, list, ctx) return self:Move(dataset, list, type(list) == "table" and #list or 0, ctx) end

function Archive:Rows(dataset, char)
  local sets = self:Sets()
  local list = sets and sets[dataset]
  if type(list) ~= "table" then return {} end
  if not char then return list end
  local out = {}
  for _, e in ipairs(list) do if e.char == char then out[#out + 1] = e end end
  return out
end

-- Review OI-FR02: what learning and reports read. The archived rows of one
-- dataset for THIS character (oldest first, as Shift moved them), then the
-- active list, as one array of references (nothing is copied or changed).
--   opts.char   character key (default: the current one); false = every character
--   opts.keys   only entries whose keys match ({ character = ... })
--   opts.where  function(row) -> bool, applied to both parts
--   opts.max    keep only the newest max rows (default MAX_HISTORY)
-- Archive files moved off the saved variables (docs/ARCHIVE_GROWTH.md) are
-- not read here.
Archive.MAX_HISTORY = 5000
function Archive:WithActive(dataset, active, opts)
  opts = opts or {}
  local char = opts.char
  if char == nil then char = ns.db and ns.db.key end
  local out = {}
  local sets = self:Sets()
  local list = sets and sets[dataset]
  -- cached while both lists keep their length (rows only ever move from the
  -- active list to the archive), so hot paths such as route times stay cheap
  local memoKey
  if not opts.where then
    local ks = {}
    for k, v in pairs(type(opts.keys) == "table" and opts.keys or {}) do ks[#ks + 1] = tostring(k) .. "=" .. tostring(v) end
    table.sort(ks)
    memoKey = table.concat({ dataset, tostring(char), tostring(list), type(list) == "table" and #list or 0, tostring(active),
      type(active) == "table" and #active or 0, table.concat(ks, ","), tostring(opts.max) }, "|")
    Archive.memo = Archive.memo or {}
    local hit = Archive.memo[dataset]
    if hit and hit.key == memoKey then return hit.rows end
  end
  if type(list) == "table" then
    for _, e in ipairs(list) do
      local ok = type(e) == "table" and e.row ~= nil and (not char or e.char == char)
      if ok and type(opts.keys) == "table" then
        for k, v in pairs(opts.keys) do if type(e.keys) ~= "table" or e.keys[k] ~= v then ok = false break end end
      end
      if ok and (not opts.where or opts.where(e.row)) then out[#out + 1] = e.row end
    end
  end
  for _, r in ipairs(type(active) == "table" and active or {}) do
    if not opts.where or opts.where(r) then out[#out + 1] = r end
  end
  local max = opts.max or Archive.MAX_HISTORY
  if #out > max then
    local trimmed = {}
    for i = #out - max + 1, #out do trimmed[#trimmed + 1] = out[i] end
    out = trimmed
  end
  if memoKey then Archive.memo[dataset] = { key = memoKey, rows = out } end
  return out
end

function Archive:Restore(dataset, fn)
  local n = 0
  for _, e in ipairs(self:Rows(dataset)) do
    local ok = pcall(fn, e)
    if ok then n = n + 1 end
  end
  return n
end

-- total archived entries, for the perf report
function Archive:Count()
  local n = 0
  local sets = self:Sets()
  for _, list in pairs(sets or {}) do if type(list) == "table" then n = n + #list end end
  return n
end
