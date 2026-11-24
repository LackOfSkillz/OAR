-- Core/Errors.lua
-- Catches errors from OUR code (everything we run goes through ns.Safe) and
-- taint reports that name our addon. HookGlobal wraps (never replaces) the
-- global error handler: we note the error, then hand it to the handler that
-- was there before, so Blizzard's pop-up, BugGrabber and BugSack still see it.

local ADDON, ns = ...
local Errors = { name = "errors", MAX = 50, list = {}, byKey = {}, warnedThisSession = false }
ns.Errors = Errors

local function short(err)
  local s = tostring(err or "?")
  -- strip long Interface\AddOns\... prefixes for readability
  s = s:gsub("Interface[\\/]AddOns[\\/]", "")
  return s
end

function Errors:Record(where, err, trace)
  local msg = short(err)
  local key = (where or "?") .. "|" .. msg
  local entry = self.byKey[key]
  local now = time and time() or 0
  if entry then
    entry.count = entry.count + 1
    entry.last = now
    entry.build = ns.build
  else
    entry = { where = where or "?", msg = msg, trace = trace, count = 1, first = now, last = now,
              session = ns.session, build = ns.build }
    self.byKey[key] = entry
    table.insert(self.list, entry)
    if #self.list > self.MAX then
      local old = table.remove(self.list, 1)
      self.byKey[old.where .. "|" .. old.msg] = nil
    end
  end
  if ns.Log then ns.Log:Error(where or "?", "%s", msg) end
  -- Quiet by default: one chat line per session, more only in debug mode.
  if not self.warnedThisSession or (ns.Log and ns.Log:IsDebug()) then
    self.warnedThisSession = true
    ns.Print("|cffff6060error|r in %s (details: /ride errors)", where or "?")
  end
  self:Save()
  return entry
end

function Errors:Save()
  if type(Outrider_Log) ~= "table" then ns.KeepBad(Outrider_Log, "Errors:Outrider_Log") return end
  Outrider_Log.errors = self.list
end

function Errors:Attach()
  -- Carry errors from the previous session so Claude can read them after a
  -- crash-free reload; they are tagged by session id.
  if type(Outrider_Log) == "table" and type(Outrider_Log.errors) == "table" then
    for _, e in ipairs(Outrider_Log.errors) do
      if type(e) == "table" and e.msg then
        local key = (e.where or "?") .. "|" .. e.msg
        if not self.byKey[key] then
          self.byKey[key] = e
          table.insert(self.list, e)
        end
      end
    end
  end
  self:Save()
end

-- Errors seen on the running build (tour 2026-11-19: Status said "7 errors
-- need a look" for errors fixed two builds ago). Older ones stay in the list.
function Errors:Fresh()
  local n = 0
  for _, e in ipairs(self.list) do if e.build and e.build == ns.build then n = n + 1 end end
  return n
end

function Errors:Clear()
  self.list, self.byKey = {}, {}
  self:Save()
end

function Errors:Recent(n)
  local out = {}
  for i = #self.list, math.max(1, #self.list - (n or 10) + 1), -1 do out[#out + 1] = self.list[i] end
  return out
end

-- Taint: Blizzard fires these when an addon touched something protected.
function Errors:OnBlocked(event, addonName, func)
  if addonName ~= ADDON then return end
  self:Record("taint", string.format("%s: %s", event, tostring(func)), nil)
end

-- Optional: mirror BugGrabber captures that mention our folder.
function Errors:HookBugGrabber()
  local BG = _G.BugGrabber
  if type(BG) ~= "table" or type(BG.RegisterCallback) ~= "function" then return false end
  local ok = pcall(BG.RegisterCallback, Errors, "BugGrabber_BugGrabbed", function(_, bug)
    if type(bug) == "table" and type(bug.message) == "string" and bug.message:find(ADDON, 1, true) then
      if ns.Log then ns.Log:Error("buggrabber", "%s", short(bug.message)) end
    end
  end)
  return ok
end

-- Errors that never pass through ns.Safe (frame scripts like OnUpdate/OnClick,
-- tooltips, other addons) went straight to the game's handler, and Gary got
-- "Your AddOns are experiencing a large number of errors" with nothing in our
-- log (2026-11-19). Now each one is recorded once per message (the same error
-- again only counts up) under "lua:<addon folder>", then passed on unchanged.
function Errors:HookGlobal()
  if self.globalHooked then return true end
  local get, set = rawget(_G, "geterrorhandler"), rawget(_G, "seterrorhandler")
  if type(get) ~= "function" or type(set) ~= "function" then return false end
  local prev = get()
  local busy = false
  local function handler(msg, ...)
    if not busy then
      busy = true
      pcall(function()
        local text = short(msg)
        local folder = text:match("^([%w_%-]+)[\\/]") or "unknown"
        local where = "lua:" .. folder
        local trace
        if not Errors.byKey[where .. "|" .. text] and type(debugstack) == "function" then trace = debugstack(3, 12, 0) end
        Errors:Record(where, text, trace)
      end)
      busy = false
    end
    if type(prev) == "function" then return prev(msg, ...) end
  end
  local ok = pcall(set, handler)
  self.globalHooked = ok
  return ok
end
