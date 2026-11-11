-- Core/Log.lua
-- Ring-buffer debug log saved to Outrider_Log (SavedVariables). This is how Claude
-- Code "sees" what happened in game: Gary types /reload, WoW writes
-- WTF\Account\<ACCOUNT>\SavedVariables\Outrider.lua, tools/read-logs.ps1 prints it.
--
-- Levels: 1 error, 2 warn, 3 info, 4 debug. Debug lines are kept only while
-- debug mode is on (/ride debug on), so normal play stays light.

local _, ns = ...
local Log = { name = "log", MAX = 600, LEVELS = { "ERROR", "WARN", "INFO", "DEBUG" } }
ns.Log = Log

local buffer      -- points at Outrider_Log.lines once Boot has run
local pending = {} -- lines logged before SavedVariables are available

local function str(v)
  if v == nil then return "nil" end
  if ns.Compat and ns.Compat.IsSecret(v) then return "<secret>" end
  local ok, s = pcall(tostring, v)
  return ok and s or "<?>"
end

local function format(msg, ...)
  if select("#", ...) == 0 then return str(msg) end
  local args = { ... }
  for i = 1, select("#", ...) do
    local a = args[i]
    if type(a) ~= "number" then args[i] = str(a) end
  end
  local ok, out = pcall(string.format, str(msg), unpack(args, 1, select("#", ...)))
  return ok and out or (str(msg) .. " [format error]")
end

function Log:Attach()
  Outrider_Log = type(Outrider_Log) == "table" and Outrider_Log or {}
  Outrider_Log.lines = type(Outrider_Log.lines) == "table" and Outrider_Log.lines or {}
  buffer = Outrider_Log.lines
  for _, line in ipairs(pending) do self:_push(line) end
  pending = {}
end

function Log:_push(line)
  if not buffer then pending[#pending + 1] = line return end
  buffer[#buffer + 1] = line
  local extra = #buffer - self.MAX
  if extra > 0 then
    for _ = 1, extra do table.remove(buffer, 1) end
  end
end

function Log:IsDebug()
  return ns.db and ns.db.global and ns.db.global.debug == true
end

function Log:Write(level, module, msg, ...)
  if level >= 4 and not self:IsDebug() then return end
  local line = {
    t = time and time() or 0,
    s = ns.session or "boot",
    l = level,
    m = module or "core",
    x = format(msg, ...),
  }
  self:_push(line)
  if level <= 2 and self:IsDebug() then
    ns.Print("|cffff6060%s|r [%s] %s", self.LEVELS[level], line.m, line.x)
  end
  return line
end

function Log:Error(module, msg, ...) return self:Write(1, module, msg, ...) end
function Log:Warn(module, msg, ...)  return self:Write(2, module, msg, ...) end
function Log:Info(module, msg, ...)  return self:Write(3, module, msg, ...) end
function Log:Debug(module, msg, ...) return self:Write(4, module, msg, ...) end

-- Markers let tools/read-logs.ps1 show only what happened after a test step:
-- /ride mark P2-04 start
function Log:Mark(text)
  return self:Write(3, "MARK", "%s", text or "")
end

function Log:Tail(n)
  local src = buffer or pending
  n = n or 20
  local out = {}
  for i = math.max(1, #src - n + 1), #src do out[#out + 1] = src[i] end
  return out
end

function Log:FormatLine(line)
  local stamp = date and date("%H:%M:%S", line.t) or tostring(line.t)
  return string.format("%s %s [%s] %s", stamp, self.LEVELS[line.l] or "?", line.m, line.x)
end
