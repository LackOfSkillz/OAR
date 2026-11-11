-- tests/run_tests.lua
-- Run from the repo root with any Lua 5.1 interpreter:
--   lua tests/run_tests.lua            (all specs)
--   lua tests/run_tests.lua profiles   (specs whose file name contains "profiles")
-- or, with no Lua installed:  python tools/lua.py tests/run_tests.lua
-- tools/test.ps1 picks whichever is available.
--
-- Step 1 syntax-checks every .lua file in addon/, tests/ and tools/.
-- Step 2 runs tests/spec/*_spec.lua. Exit code 0 = all green.

package.path = "./tests/lib/?.lua;" .. package.path
local T = require("tiny")
local mock = require("wowmock")

local WINDOWS = package.config:sub(1, 1) == "\\"
local filter = arg and arg[1]

local function listLua(dir)
  -- tools/lua.py provides this because its embedded Lua has no io.popen
  local host = rawget(_G, "OTR_HOST_LIST_LUA")
  if host then
    local out = {}
    for _, f in ipairs(host(dir)) do out[#out + 1] = f end
    return out
  end
  local cmd
  if WINDOWS then
    cmd = 'dir /b /s "' .. dir:gsub("/", "\\") .. '\\*.lua" 2>nul'
  else
    cmd = 'find "' .. dir .. '" -name "*.lua" -type f 2>/dev/null | sort'
  end
  local out = {}
  local p = io.popen(cmd)
  if p then
    for line in p:lines() do
      line = line:gsub("\r", "")
      if line ~= "" then out[#out + 1] = line end
    end
    p:close()
  end
  table.sort(out)
  return out
end
mock.listLua = listLua

-- Path relative to the repo root with forward slashes (works for absolute Windows paths too)
function mock.relpath(p, root)
  p = p:gsub("\\", "/")
  local i = p:find(root, 1, true)
  if i then return p:sub(i) end
  return p
end

io.write("== syntax check\n")
local syntaxErrors = 0
for _, dir in ipairs({ "addon", "tests", "tools" }) do
  for _, file in ipairs(listLua(dir)) do
    local chunk, err = loadfile(file)
    if not chunk then
      syntaxErrors = syntaxErrors + 1
      io.write("  SYNTAX ", tostring(err), "\n")
    end
  end
end
if syntaxErrors == 0 then io.write("  ok   all files parse\n") end

io.write("== specs\n")
local specs = {}
for _, file in ipairs(listLua("tests/spec")) do
  if file:match("_spec%.lua$") and (not filter or file:find(filter, 1, true)) then specs[#specs + 1] = file end
end
if #specs == 0 then io.write("  (no spec files found", filter and (" matching " .. filter) or "", ")\n") end

for _, file in ipairs(specs) do
  io.write("-- ", mock.relpath(file, "tests/spec/"), "\n")
  local chunk, err = loadfile(file)
  if not chunk then
    T.failed = T.failed + 1
    T.failures[#T.failures + 1] = { name = file, err = err }
  else
    local ok, e = pcall(chunk, T, mock)
    if not ok then
      T.failed = T.failed + 1
      T.failures[#T.failures + 1] = { name = file .. " (top level)", err = e }
    end
  end
end

io.write("\n")
for _, f in ipairs(T.failures) do
  io.write("FAILED: ", f.name, "\n", tostring(f.err), "\n\n")
end
local total = T.passed + T.failed
io.write(string.format("%d passed, %d failed, %d syntax errors (%d tests)\n", T.passed, T.failed, syntaxErrors, total))
os.exit((T.failed == 0 and syntaxErrors == 0) and 0 or 1)
