-- tools/sv_dump.lua must read what the addon really writes.
local T, mock = ...

local TMP = "tests/.tmp_saved_variables.lua"

local function runDump(args)
  local captured = {}
  local env = setmetatable({
    arg = args,
    io = { write = function(...) for i = 1, select("#", ...) do captured[#captured + 1] = tostring((select(i, ...))) end end },
    os = { date = os.date, exit = function(code) error({ exit = code }) end },
  }, { __index = _G })
  local chunk = assert(loadfile("tools/sv_dump.lua"))
  setfenv(chunk, env)
  local ok, err = pcall(chunk)
  if not ok and not (type(err) == "table" and err.exit) then error(err) end
  return table.concat(captured)
end

local function writeTmp(text)
  local f = assert(io.open(TMP, "wb"))
  f:write(text)
  f:close()
end

T.describe("sv_dump tool", function()
  local game = mock.new()
  local ns = game:loadAddon()
  game:login()
  game:slash("mark P0-07 start")
  ns.Log:Info("test", "after the mark")
  game:slash("probe")
  game:slash("selftest error")
  writeTmp(game:logout())

  T.it("summary shows loads, errors and the latest session log", function()
    local text = runDump({ [1] = TMP })
    T.contains(text, "loads 1")
    T.contains(text, "deliberate error")
    T.contains(text, "after the mark")
  end)

  T.it("filters the log by marker", function()
    local text = runDump({ [1] = TMP, [2] = "log", [3] = "--mark", [4] = "P0-07" })
    T.contains(text, "after the mark")
    T.no(text:find("start: v", 1, true), "boot lines before the mark are excluded")
  end)

  T.it("prints probe results and characters", function()
    local probe = runDump({ [1] = TMP, [2] = "probe" })
    T.contains(probe, "missing APIs")
    T.contains(probe, "C_Map.GetBestMapForUnit")
    local chars = runDump({ [1] = TMP, [2] = "chars" })
    T.contains(chars, "Torrant-Forever")
  end)

  T.it("reads BugGrabber files and keeps only OAR errors", function()
    writeTmp('BugGrabberDB = { session = 3, errors = { { message = "Interface/AddOns/OAR/Core/X.lua:1: boom", time = "now", counter = 2 }, { message = "Other addon error" } } }\n')
    local text = runDump({ [1] = TMP, [2] = "bugs" })
    T.contains(text, "OAR/Core/X.lua")
    T.no(text:find("Other addon", 1, true))
  end)

  os.remove(TMP)
end)
