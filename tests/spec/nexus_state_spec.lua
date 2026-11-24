-- OI02-04: read-only character and account state for the Nexus.
local T, mock = ...

local function session(opts)
  local game = mock.new(opts or { mapID = 1412, x = 0.4, y = 0.5 })
  local ns = game:loadAddon()
  game:login()
  return game, ns, ns.NexusState
end

T.describe("nexus character and account state", function()
  T.it("reads fields lazily and keeps them until an event for that field", function()
    local game, _, S = session()
    game.money = 5000
    local g = S:Get("gold")
    T.eq(g.value, 5000)
    T.eq(g.live, true)
    local loc = S:Get("location")
    T.eq(loc.value.mapID, 1412)
    game.money = 7000
    T.eq(S:Get("gold").value, 5000, "cached until the money event")
    game:fire("BAG_UPDATE_DELAYED")
    T.eq(S:Get("gold").value, 5000, "a bag update doesn't drop the gold reading")
    T.ok(S:Get("location") == loc, "nor the location")
    local rev = S:Revision()
    game:fire("PLAYER_MONEY")
    T.eq(S:Get("gold").value, 7000, "the money event refreshes gold")
    T.ok(S:Revision() > rev)
    T.ok(S:Get("location") == loc, "location untouched by PLAYER_MONEY")
  end)

  T.it("an unknown or failing field is reported, not guessed", function()
    local _, _, S = session()
    local v, why = S:Get("mood")
    T.eq(v, nil) T.eq(why, "unknown field")
    S.READERS.broken = function() error("client said no") end
    v, why = S:Get("broken")
    S.READERS.broken = nil
    T.eq(v, nil) T.eq(why, "read failed")
  end)

  T.it("other characters come from their saved snapshot, always marked not live with their age", function()
    local game, ns, S = session()
    ns.Alts.alts["Lumen-Forever"] = { level = 30, class = "PRIEST", money = 99999, zone = "Duskwood", t = game.now - 3 * 86400 }
    local alts = S:Alts(game.now)
    local lumen
    for _, a in ipairs(alts) do if a.key == "Lumen-Forever" then lumen = a end end
    T.ok(lumen)
    T.eq(lumen.live, false)
    T.eq(lumen.copper, 99999)
    T.eq(lumen.ageSeconds, 3 * 86400)
    T.eq(S.AltAge(lumen.ageSeconds), "seen 3 days ago")
    for _, a in ipairs(alts) do T.ok(a.key ~= ns.db.key, "the current character is not an alt") end
  end)

  T.it("reads use public functions only and write nothing", function()
    local _, ns, S = session()
    local before = 0
    for _ in pairs(ns.db.global) do before = before + 1 end
    for f in pairs(S.READERS) do S:Get(f) end
    local after = 0
    for _ in pairs(ns.db.global) do after = after + 1 end
    T.eq(after, before, "no new saved data")
    T.eq(#ns.Errors.list, 0)
  end)
end)
