local T, mock = ...

local game = mock.new()
local ns = game:loadAddon()
local S = ns.Serialize

T.describe("serialize", function()
  T.it("round-trips nested values", function()
    local v = { 1, 2, "three", { deep = { true, false } }, name = "Torrant", n = -12.5, big = 2^40, zero = 0,
      ["key with spaces"] = "x:y;{}", [10] = "sparse" }
    T.same(S.Decode(S.Encode(v)), v)
  end)

  T.it("encodes deterministically", function()
    T.eq(S.Encode({ b = 1, a = 2, 7 }), S.Encode({ 7, a = 2, b = 1 }))
  end)

  T.it("rejects functions, NaN and deep tables", function()
    T.raises(function() S.Encode({ f = print }) end, "cannot serialize")
    T.raises(function() S.Encode(0 / 0) end, "NaN")
    local t = {}
    local cur = t
    for _ = 1, 40 do cur.x = {} cur = cur.x end
    T.raises(function() S.Encode(t) end, "too deep")
  end)

  T.it("refuses malformed input without throwing", function()
    for _, bad in ipairs({ "", "{", "S5:abc", "Nabc;", "Q", "{S1:aN1;", "{N1;N1;}junk", "S-1:", "{{}N1;}" }) do
      local v, err = S.Decode(bad)
      T.eq(v, nil, "decoded " .. bad)
      T.ok(err, "error message for " .. bad)
    end
  end)

  T.it("base64 matches standard vectors", function()
    T.eq(S.Base64Encode(""), "")
    T.eq(S.Base64Encode("f"), "Zg==")
    T.eq(S.Base64Encode("fo"), "Zm8=")
    T.eq(S.Base64Encode("foo"), "Zm9v")
    T.eq(S.Base64Encode("Man"), "TWFu")
    T.eq(S.Base64Decode("Zm9vYmFy"), "foobar")
    T.eq(S.Base64Decode("Zm8="), "fo")
  end)

  T.it("adler32 matches the reference value", function()
    T.eq(S.Adler32("Wikipedia"), "11e60398")
  end)

  T.it("export strings round-trip and detect tampering", function()
    local v = { kind = "x", list = { 1, 2, 3 } }
    local s = S.Export(v)
    T.eq(s:sub(1, 5), "OTR1:")
    T.same(S.Import(s), v)
    T.same(S.Import("  " .. s .. "\n"), v, "whitespace tolerated")
    local tampered = s:sub(1, -3) .. (s:sub(-2, -2) == "A" and "B" or "A") .. s:sub(-1)
    local r, err = S.Import(tampered)
    T.eq(r, nil)
    T.ok(err)
    T.eq((S.Import("hello")), nil)
  end)
end)
