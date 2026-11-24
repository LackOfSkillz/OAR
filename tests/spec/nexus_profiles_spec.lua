-- OI02-03: class and role profiles for the Nexus. The 9 x 6 class-goal cases
-- live in intelligence2_spec; these add hybrids, respec, absent talents,
-- unknown tokens and the v4 CharacterState view.
local T, mock = ...

local function session(class)
  local game = mock.new({ class = class or "HUNTER" })
  local ns = game:loadAddon()
  game:login()
  return game, ns, ns.ClassProfiles
end

T.describe("nexus class and role profiles", function()
  T.it("every class token gives a valid v4 state; roles only from the player's choice", function()
    for _, cls in ipairs({ "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }) do
      local _, ns, P = session(cls)
      local st = P.StateV4()
      T.ok(st, cls .. " state")
      T.eq(st.classToken, cls)
      T.eq(st.role, "unknown", cls .. ": no role until the player picks one")
      T.eq(st.roleSource, "unknown")
      T.ok(ns.Nexus.Validate("CharacterState", st))
    end
  end)

  T.it("hybrids can pick every documented role and nothing else", function()
    local _, _, P = session("DRUID")
    for _, role in ipairs({ "tank", "melee", "caster", "healer" }) do
      T.ok(P.SetRole(role), "druid " .. role)
      local st = P.StateV4()
      T.eq(st.role, role)
      T.eq(st.roleSource, "explicit")
    end
    T.eq(P.SetRole("ranged"), false, "druid ranged is not a documented role")
    local _, _, P2 = session("SHAMAN")
    T.ok(P2.SetRole("melee") and P2.SetRole("caster") and P2.SetRole("healer"))
    T.eq(P2.SetRole("tank"), false)
  end)

  T.it("a respec or talent change never changes the chosen role (no inference)", function()
    local game, _, P = session("PALADIN")
    P.SetRole("healer")
    game:fire("PLAYER_TALENT_UPDATE")
    game:fire("CHARACTER_POINTS_CHANGED", -1)
    game:fire("ACTIVE_TALENT_GROUP_CHANGED", 2, 1)
    T.eq(P.StateV4().role, "healer")
  end)

  T.it("with no talent API the role still comes only from the player", function()
    local game, ns, P = session("WARRIOR")
    game.env.GetTalentInfo, game.env.GetNumTalentTabs = nil, nil
    T.eq(P.StateV4().role, "unknown")
    P.SetRole("tank")
    T.eq(P.StateV4().role, "tank")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("an unknown class token falls back to universal advice only", function()
    local _, _, P = session("HUNTER")
    local token, roles = P.Resolve("MONK")
    T.eq(token, "UNKNOWN")
    T.eq(#roles, 0)
    T.eq(P.CanPlay("MONK", "tank"), false)
    T.ok(P.Allows("MONK", "UNKNOWN", nil), "universal advice still allowed")
    T.eq(P.Allows("MONK", "UNKNOWN", { class = "MONK", role = "tank" }), false)
  end)

  T.it("the character key is opaque and stable, never the character name", function()
    local game, ns, P = session("HUNTER")
    local a = P.StateV4().characterKey
    T.ok(not a:find(ns.db.key:match("^[^%-]+"), 1, true), "no name in the key")
    T.eq(P.StateV4().characterKey, a, "stable")
    local saved = game:logout()
    local g2 = mock.new({ class = "HUNTER", savedVariables = saved })
    local ns2 = g2:loadAddon()
    g2:login()
    T.eq(ns2.ClassProfiles.StateV4().characterKey, a, "stable across sessions")
  end)
end)
