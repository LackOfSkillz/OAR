-- Core/Serialize.lua
-- Pure-Lua serializer + strict parser for export strings and addon messages.
-- The parser never calls loadstring, so an import string cannot run code.
--
-- Wire format:  Z nil | T true | F false | N<number>; | S<len>:<bytes> | { k v k v ... }
-- Export form:  OTR1:<8 hex adler32>:<base64 payload>

local _, ns = ...
local S = { MAX_DEPTH = 32, MAX_LEN = 400000 }
ns.Serialize = S

local floor, byte, char, sub, format = math.floor, string.byte, string.char, string.sub, string.format

-- ---------------------------------------------------------------- encode
local function encodeValue(v, out, depth)
  local t = type(v)
  if v == nil then out[#out + 1] = "Z"
  elseif t == "boolean" then out[#out + 1] = v and "T" or "F"
  elseif t == "number" then
    if v ~= v or v == math.huge or v == -math.huge then error("cannot serialize NaN/inf") end
    if v == floor(v) and v > -2^53 and v < 2^53 then
      out[#out + 1] = format("N%.0f;", v) -- %.0f, not %d: %d overflows past 2^31 on Windows
    else
      out[#out + 1] = format("N%.17g;", v)
    end
  elseif t == "string" then
    out[#out + 1] = "S" .. #v .. ":" .. v
  elseif t == "table" then
    if depth >= S.MAX_DEPTH then error("table too deep") end
    out[#out + 1] = "{"
    -- deterministic order: array part first, then sorted remaining keys
    local n = #v
    for i = 1, n do encodeValue(i, out, depth + 1) encodeValue(v[i], out, depth + 1) end
    local keys = {}
    for k in pairs(v) do
      local kt = type(k)
      if not (kt == "number" and k >= 1 and k <= n and k == floor(k)) then
        if kt ~= "string" and kt ~= "number" and kt ~= "boolean" then error("bad key type " .. kt) end
        keys[#keys + 1] = k
      end
    end
    table.sort(keys, function(a, b)
      local ta, tb = type(a), type(b)
      if ta ~= tb then return ta < tb end
      if ta == "boolean" then return (a and 1 or 0) < (b and 1 or 0) end
      return a < b
    end)
    for _, k in ipairs(keys) do encodeValue(k, out, depth + 1) encodeValue(v[k], out, depth + 1) end
    out[#out + 1] = "}"
  else
    error("cannot serialize type " .. t)
  end
end

function S.Encode(v)
  local out = {}
  encodeValue(v, out, 0)
  return table.concat(out)
end

-- ---------------------------------------------------------------- decode
local function decodeValue(s, pos, depth)
  local c = sub(s, pos, pos)
  if c == "Z" then return nil, pos + 1
  elseif c == "T" then return true, pos + 1
  elseif c == "F" then return false, pos + 1
  elseif c == "N" then
    local stop = s:find(";", pos + 1, true)
    if not stop then error("unterminated number at " .. pos) end
    local raw = sub(s, pos + 1, stop - 1)
    if not raw:match("^%-?[%d%.]+[eE]?[%+%-]?%d*$") then error("bad number at " .. pos) end
    local n = tonumber(raw)
    if not n then error("bad number at " .. pos) end
    return n, stop + 1
  elseif c == "S" then
    local colon = s:find(":", pos + 1, true)
    if not colon then error("bad string header at " .. pos) end
    local len = tonumber(sub(s, pos + 1, colon - 1))
    if not len or len < 0 or len ~= floor(len) then error("bad string length at " .. pos) end
    local last = colon + len
    if last > #s then error("string runs past end at " .. pos) end
    return sub(s, colon + 1, last), last + 1
  elseif c == "{" then
    if depth >= S.MAX_DEPTH then error("table too deep") end
    local t = {}
    pos = pos + 1
    while true do
      if pos > #s then error("unterminated table") end
      if sub(s, pos, pos) == "}" then return t, pos + 1 end
      local k, v
      k, pos = decodeValue(s, pos, depth + 1)
      if k == nil then error("nil table key") end
      if type(k) == "table" then error("table as key") end
      v, pos = decodeValue(s, pos, depth + 1)
      t[k] = v
    end
  end
  error("unexpected '" .. c .. "' at " .. pos)
end

-- Returns value or nil, err
function S.Decode(s)
  if type(s) ~= "string" then return nil, "not a string" end
  if #s > S.MAX_LEN then return nil, "too long" end
  local ok, v, nextPos = pcall(decodeValue, s, 1, 0)
  if not ok then return nil, tostring(v) end
  if nextPos ~= #s + 1 then return nil, "trailing data" end
  return v
end

-- ---------------------------------------------------------------- base64
local ALPHA = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local ENC, DEC = {}, {}
for i = 1, 64 do
  local ch = sub(ALPHA, i, i)
  ENC[i - 1] = ch
  DEC[ch] = i - 1
end

function S.Base64Encode(s)
  local out = {}
  for i = 1, #s, 3 do
    local a, b, c = byte(s, i, i + 2)
    local n = a * 65536 + (b or 0) * 256 + (c or 0)
    local c1, c2 = floor(n / 262144) % 64, floor(n / 4096) % 64
    local c3, c4 = floor(n / 64) % 64, n % 64
    out[#out + 1] = ENC[c1] .. ENC[c2] .. (b and ENC[c3] or "=") .. (c and ENC[c4] or "=")
  end
  return table.concat(out)
end

function S.Base64Decode(s)
  s = s:gsub("%s+", "")
  if #s % 4 ~= 0 then return nil, "bad base64 length" end
  local out = {}
  for i = 1, #s, 4 do
    local q = { sub(s, i, i), sub(s, i + 1, i + 1), sub(s, i + 2, i + 2), sub(s, i + 3, i + 3) }
    local v1, v2 = DEC[q[1]], DEC[q[2]]
    local v3 = q[3] == "=" and 0 or DEC[q[3]]
    local v4 = q[4] == "=" and 0 or DEC[q[4]]
    if not (v1 and v2 and v3 and v4) then return nil, "bad base64 character" end
    local n = v1 * 262144 + v2 * 4096 + v3 * 64 + v4
    local a, b, c = floor(n / 65536) % 256, floor(n / 256) % 256, n % 256
    if q[3] == "=" then out[#out + 1] = char(a)
    elseif q[4] == "=" then out[#out + 1] = char(a, b)
    else out[#out + 1] = char(a, b, c) end
  end
  return table.concat(out)
end

-- ---------------------------------------------------------------- checksum
function S.Adler32(s)
  local a, b = 1, 0
  for i = 1, #s do
    a = (a + byte(s, i)) % 65521
    b = (b + a) % 65521
  end
  return format("%04x%04x", b, a) -- two halves: avoids 32-bit %x overflow on Windows
end

-- ---------------------------------------------------------------- export
S.EXPORT_TAG = "OTR1"

function S.Export(value)
  local payload = S.Encode(value)
  return S.EXPORT_TAG .. ":" .. S.Adler32(payload) .. ":" .. S.Base64Encode(payload)
end

-- Returns value or nil, err
function S.Import(text)
  if type(text) ~= "string" then return nil, "nothing to import" end
  text = text:gsub("^%s+", ""):gsub("%s+$", "")
  local tag, sum, body = text:match("^(%w+):(%x+):(.+)$")
  if tag ~= S.EXPORT_TAG then return nil, "not an Outrider export string" end
  local payload, err = S.Base64Decode(body)
  if not payload then return nil, err end
  if S.Adler32(payload) ~= sum:lower() then return nil, "checksum mismatch (string was cut off or edited)" end
  return S.Decode(payload)
end
