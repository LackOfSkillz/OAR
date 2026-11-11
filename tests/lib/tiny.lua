-- tests/lib/tiny.lua
-- Minimal test framework: describe / it / expectations. No dependencies.

local T = { passed = 0, failed = 0, failures = {}, prefix = {} }

function T.describe(name, fn)
  table.insert(T.prefix, name)
  fn()
  table.remove(T.prefix)
end

function T.it(name, fn)
  local full = table.concat(T.prefix, " > ") .. " > " .. name
  local ok, err = xpcall(fn, function(e) return debug.traceback(tostring(e), 2) end)
  if ok then
    T.passed = T.passed + 1
    io.write("  ok   ", full, "\n")
  else
    T.failed = T.failed + 1
    T.failures[#T.failures + 1] = { name = full, err = err }
    io.write("  FAIL ", full, "\n")
  end
end

local function fmt(v)
  if type(v) == "string" then return string.format("%q", v) end
  return tostring(v)
end

function T.eq(actual, expected, msg)
  if actual ~= expected then
    error(string.format("%sexpected %s, got %s", msg and (msg .. ": ") or "", fmt(expected), fmt(actual)), 2)
  end
end

function T.ok(v, msg)
  if not v then error(msg or "expected truthy value", 2) end
end

function T.no(v, msg)
  if v then error((msg or "expected falsy value") .. ", got " .. fmt(v), 2) end
end

function T.contains(haystack, needle, msg)
  if type(haystack) ~= "string" or not haystack:find(needle, 1, true) then
    error(string.format("%sexpected text to contain %q", msg and (msg .. ": ") or "", needle), 2)
  end
end

local function deepEq(a, b, path)
  if type(a) ~= type(b) then return false, path .. ": type " .. type(a) .. " vs " .. type(b) end
  if type(a) ~= "table" then
    if a ~= b then return false, path .. ": " .. fmt(a) .. " vs " .. fmt(b) end
    return true
  end
  for k, v in pairs(a) do
    local ok, where = deepEq(v, b[k], path .. "." .. tostring(k))
    if not ok then return false, where end
  end
  for k in pairs(b) do
    if a[k] == nil then return false, path .. "." .. tostring(k) .. ": missing on left" end
  end
  return true
end

function T.same(actual, expected, msg)
  local ok, where = deepEq(actual, expected, "value")
  if not ok then error((msg and (msg .. ": ") or "") .. "tables differ at " .. where, 2) end
end

function T.raises(fn, needle)
  local ok, err = pcall(fn)
  if ok then error("expected an error", 2) end
  if needle and not tostring(err):find(needle, 1, true) then
    error("error did not mention " .. needle .. ": " .. tostring(err), 2)
  end
end

return T
