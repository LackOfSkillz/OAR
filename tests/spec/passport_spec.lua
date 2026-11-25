-- OI08-02 passport snapshot; OI08-04 advice transport limits.
local T, mock = ...

local function session(opts)
  local game = mock.new(opts or { level = 20, class = "HUNTER" })
  local ns = game:loadAddon()
  game:login()
  game.money = 123456
  return game, ns, ns.Passport
end

T.describe("passport snapshot (OI08-02)", function()
  T.it("sensitive fields are off by default; the character is an opaque id", function()
    local _, ns, P = session()
    local pv = P.Preview("plan")
    local d = P.Read(pv.text)
    T.eq(d.fields.level, 20)
    T.eq(d.fields.gold, nil, "exact gold is off by default")
    T.eq(d.fields.goldBand, "10-100g")
    T.eq(d.fields.realm, nil)
    T.ok(not pv.text:find("Torrant", 1, true))
    T.ok(not ns.Serialize.Encode(d):find("Torrant", 1, true), "no name inside")
    T.ok(d.id:match("^c%x+$"))
    T.eq(P.Id(), d.id, "the same character gets the same id")
    T.ok(P.Id("Other-Realm") ~= d.id)
  end)

  T.it("ticking a sensitive field is the player's choice; copying needs the preview's token", function()
    local _, _, P = session()
    local pv = P.Preview("gold", { gold = true, plan = false })
    T.eq(P.Read(pv.text).fields.gold, 123456)
    T.eq(select(2, P.Export(pv, "nope")), "preview it, then copy that preview")
    T.eq(P.Export(pv, pv.token), pv.text)
    T.eq(select(2, P.Preview("hack")), "unknown task")
  end)

  T.it("stale, another character's, another build's and edited passports aren't current", function()
    local game, _, P = session()
    local pv = P.Preview("plan")
    T.eq(select(2, P.Read(pv.text, {}, pv.takenAt + P.MAX_AGE + 1)), "stale: take a new one")
    T.eq(select(2, P.Read(pv.text, { id = "cdeadbeef" })), "another character's passport")
    T.eq(select(2, P.Read(pv.text, { build = "0.0.1" })), "made on another game build")
    T.ok(not P.Read(pv.text:sub(1, -6) .. "AAAAA"))
    T.eq(select(2, P.Read("OTR1:00:AA")), "not a passport")
    T.eq(select(2, P.Read(string.rep("x", P.MAX_BYTES + 1))), "missing or too big")
    game.combat = true
    T.eq(select(2, P.Preview("plan")), "not in combat")
  end)
end)

T.describe("advice transport (OI08-04)", function()
  T.it("an oversized code is refused before decoding; a code that isn't advice is named", function()
    local _, ns = session()
    local A = ns.Advice or ns.AdviceLoader
    T.ok(A and A.Paste, "the advice loader")
    local n, why = A:Paste(string.rep("A", A.MAX_PASTE + 1))
    T.eq(n, 0) T.ok(why:find("too big"))
    n, why = A:Paste(ns.Serialize.Export({ kind = "snapshot" }))
    T.eq(why, "that code is not advice")
    n, why = A:Paste("OTR1:deadbeef:%%%")
    T.eq(n, 0)
    T.eq(#ns.Errors.list, 0)
  end)
end)

T.describe("one Passport contract with the companion (review OI-FR12)", function()
  T.it("every shared fixture gives the same answer as the Python reader", function()
    local game = mock.new()
    local ns = game:loadAddon()
    game:login()
    local P = ns.Passport
    local J = dofile("tests/lib/json.lua")
    local C = J.file("companion/tests/fixtures/passport_contract.json")
    local function copy(t) if type(t) ~= "table" then return t end local o = {} for k, v in pairs(t) do o[k] = copy(v) end return o end
    for _, case in ipairs(C.cases) do
      local body = copy(C.base)
      for k, v in pairs(case.body or {}) do body[k] = copy(v) end
      local text = ns.Serialize.Export(body):gsub("^" .. ns.Serialize.EXPORT_TAG, P.TAG)
      local o, want = case.opts or {}, case.expect
      local d, why = P.Read(text, { id = o.id, build = o.build }, o.now)
      if want.ok then
        T.ok(d, case.name .. ": accepted (" .. tostring(why) .. ")")
        if d then
          local keys = {}
          for k in pairs(d.fields) do keys[#keys + 1] = k end
          table.sort(keys)
          T.same(keys, want.fields, case.name .. " fields")
          T.same(d.dropped, want.dropped, case.name .. " dropped")
        end
      else
        T.eq(d, nil, case.name .. ": refused")
        T.eq(why, want.why, case.name)
      end
    end
    for _, t in ipairs(C.texts) do
      local text = t.text or string.rep(t["repeat"], t.count)
      T.eq(select(2, P.Read(text, {}, 2000)), t.why, t.name)
    end
  end)
end)
