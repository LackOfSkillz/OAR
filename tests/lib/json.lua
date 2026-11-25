-- tests/lib/json.lua: a small JSON reader for shared test fixtures (objects,
-- arrays, strings with the common escapes, numbers, true/false/null).
local J = {}

local function skip(s, i)
  local _, e = s:find("^[ \t\r\n]*", i)
  return e + 1
end

local decodeValue

local function decodeString(s, i)
  local out, j = {}, i + 1
  while true do
    local c = s:sub(j, j)
    if c == "" then error("unterminated string") end
    if c == '"' then return table.concat(out), j + 1 end
    if c == "\\" then
      local n = s:sub(j + 1, j + 1)
      local map = { n = "\n", t = "\t", r = "\r", b = "\b", f = "\f", ['"'] = '"', ["\\"] = "\\", ["/"] = "/" }
      if map[n] then out[#out + 1] = map[n] j = j + 2
      elseif n == "u" then
        local code = tonumber(s:sub(j + 2, j + 5), 16)
        out[#out + 1] = code < 128 and string.char(code) or "?"
        j = j + 6
      else error("bad escape") end
    else
      out[#out + 1] = c
      j = j + 1
    end
  end
end

function decodeValue(s, i)
  i = skip(s, i)
  local c = s:sub(i, i)
  if c == "{" then
    local t = {}
    i = skip(s, i + 1)
    if s:sub(i, i) == "}" then return t, i + 1 end
    while true do
      local k
      k, i = decodeString(s, skip(s, i))
      i = skip(s, i)
      assert(s:sub(i, i) == ":", "expected :")
      t[k], i = decodeValue(s, i + 1)
      i = skip(s, i)
      local d = s:sub(i, i)
      if d == "}" then return t, i + 1 end
      assert(d == ",", "expected , or }")
      i = i + 1
    end
  elseif c == "[" then
    local t = {}
    i = skip(s, i + 1)
    if s:sub(i, i) == "]" then return t, i + 1 end
    while true do
      t[#t + 1], i = decodeValue(s, i)
      i = skip(s, i)
      local d = s:sub(i, i)
      if d == "]" then return t, i + 1 end
      assert(d == ",", "expected , or ]")
      i = i + 1
    end
  elseif c == '"' then
    return decodeString(s, i)
  elseif s:sub(i, i + 3) == "true" then return true, i + 4
  elseif s:sub(i, i + 4) == "false" then return false, i + 5
  elseif s:sub(i, i + 3) == "null" then return nil, i + 4
  else
    local num = s:match("^-?%d+%.?%d*[eE]?[-+]?%d*", i)
    assert(num and #num > 0, "unexpected character at " .. i)
    return tonumber(num), i + #num
  end
end

function J.decode(s) return (decodeValue(s, 1)) end

function J.file(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return J.decode(s)
end

return J
