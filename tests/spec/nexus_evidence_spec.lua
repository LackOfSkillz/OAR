-- OI02-02: the evidence registry rejects malformed, stale, cross-character,
-- cross-build, future and secret data, and never infers "verified" from a name.
local T, mock = ...

local function session()
  local game = mock.new()
  local ns = game:loadAddon()
  game:login()
  return game, ns, ns.IntelEvidence
end

T.describe("nexus evidence registry", function()
  T.it("rejects malformed input: unknown source, kind, label, bad key, bad TTL", function()
    local _, _, E = session()
    T.ok(E:Register("WhatNow"))
    T.eq(E:Register("bad name!"), false)
    T.eq(E:Register("x", "ready", { sourceType = "internet" }), false)
    T.eq(E:Record("nobody", "k", "quest", {}, "observed"), nil)
    T.eq(E:Record("WhatNow", "k", "rumour", {}, "observed"), nil)
    T.eq(E:Record("WhatNow", "k", "quest", {}, "guaranteed"), nil)
    T.eq(E:Record("WhatNow", "bad|key", "quest", {}, "observed"), nil)
    T.eq(E:Record("WhatNow", "k", "quest", {}, "observed", 999999), nil)
  end)

  T.it("verified is never inferred from a source's name", function()
    local _, _, E = session()
    E:Register("VerifiedBlizzardData") -- the name says verified; the registration does not
    T.eq(E:Record("VerifiedBlizzardData", "k", "quest", {}, "verified"), nil)
    T.ok(E:Record("VerifiedBlizzardData", "k", "quest", {}, "observed"))
    E:Register("ClientRead", "ready", { sourceType = "client", canVerify = true })
    T.ok(E:Record("ClientRead", "k", "quest", {}, "verified"))
  end)

  T.it("stale, future, other-character and other-build facts are refused with a reason", function()
    local game, _, E = session()
    E:Register("WhatNow")
    local r = E:Record("WhatNow", "quest:1", "quest", { benefit = 0.5 }, "observed", 60)
    T.ok(E:Get(r.id))
    local row, why = E:Get(r.id, game.now + 61)
    T.eq(row, nil) T.eq(why, "stale")
    r = E:Record("WhatNow", "quest:2", "quest", {}, "observed", 60)
    r.observedAt = game.now + 600
    row, why = E:Get(r.id) T.eq(why, "future")
    r = E:Record("WhatNow", "quest:3", "quest", {}, "observed", 60)
    r.char = "Someone-Else"
    row, why = E:Get(r.id) T.eq(why, "other character")
    r = E:Record("WhatNow", "quest:4", "quest", {}, "observed", 60)
    r.build = "old-build"
    row, why = E:Get(r.id) T.eq(why, "other build")
  end)

  T.it("secret values never enter a fact", function()
    local _, ns, E = session()
    E:Register("WhatNow")
    local isSecret = ns.Compat.IsSecret
    ns.Compat.IsSecret = function(v) return v == "SECRET" end
    local r = E:Record("WhatNow", "quest:5", "quest", { hp = "SECRET", ok = 1 }, "observed")
    local refused = E:Record("WhatNow", "SECRET", "quest", {}, "observed")
    ns.Compat.IsSecret = isSecret
    T.eq(refused, nil, "a secret key is refused")
    T.eq(r.value.hp, nil)
    T.eq(r.value.ok, 1)
  end)

  T.it("a stored fact becomes a valid v4 Evidence record with provenance and privacy", function()
    local _, ns, E = session()
    E:Register("WhatNow", "ready", { sourceType = "module" })
    local r = E:Record("WhatNow", "quest:6", "quest", {}, "community")
    local rec = E:AsV4(r.id)
    T.ok(rec)
    T.eq(rec.sourceType, "module")
    T.eq(rec.confidence, "community")
    T.eq(rec.privacy, "local")
    T.ok(ns.Nexus.Validate("Evidence", rec))
  end)
end)
