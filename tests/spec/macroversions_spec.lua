-- OI05-10 macro versioning and rollback; OI05-11 all-class macro regression matrix.
local T, mock = ...

local function session(opts)
  local game = mock.new(opts)
  local ns = game:loadAddon()
  game:login()
  ns.Modules:SetEnabled("AutoCheck", false)
  return game, ns, ns.MacroVersions, ns.MacroLibrary
end

local FIGHT = { id = "test-fight", name = "Fight", body = "#showtooltip\n/cast Arcane Shot\n/cast Raptor Strike", scope = "char",
  why = "ranged first, melee when close" }

T.describe("macro versioning and rollback (OI05-10)", function()
  T.it("a preview shows the diff, length, reason and spells; installing needs its token", function()
    local game, ns, V, L = session()
    ns.Spellbook.spells["arcane shot"] = { name = "Arcane Shot", id = 3044, rank = 2 }
    local pv = V.Preview(FIGHT)
    T.eq(pv.diff[1], "+ #showtooltip")
    T.eq(pv.length, #pv.new) T.eq(pv.limit, 255)
    T.eq(pv.rationale, FIGHT.why)
    T.eq(pv.spells[1].name, "Arcane Shot") T.eq(pv.spells[1].rank, 2)
    T.eq(select(2, V.Apply(FIGHT, "wrong")), "the macro changed since the preview: preview again")
    T.eq(#game.macros, 0, "nothing installed without approval")
    T.ok(V.Apply(FIGHT, pv.token))
    T.eq(L:Settings().installed.Fight.why, FIGHT.why)
  end)

  T.it("a respec or a new rank makes the macro stale and the old token invalid", function()
    local _, ns, V = session()
    ns.Spellbook.spells["arcane shot"] = { name = "Arcane Shot", id = 3044, rank = 2 }
    local pv = V.Preview(FIGHT)
    T.ok(V.Apply(FIGHT, pv.token))
    T.eq(V.Stale(FIGHT), nil)
    ns.Spellbook.spells["arcane shot"] = { name = "Arcane Shot", id = 14281, rank = 3 }
    T.ok(V.Stale(FIGHT):find("spells changed"))
    T.ok(not V.Apply(FIGHT, pv.token), "a preview from before the rank is refused")
  end)

  T.it("rollback restores the previous text, keeps the replaced one, and a second rollback is a redo", function()
    local game, _, V, L = session()
    T.ok(V.Apply(FIGHT, V.Preview(FIGHT).token))
    local newer = { id = FIGHT.id, name = "Fight", body = "#showtooltip\n/cast Serpent Sting\n/cast Arcane Shot", scope = "char" }
    T.ok(V.Apply(newer, V.Preview(newer).token))
    local v2 = game.macros[1].body
    T.ok(V.Rollback(newer))
    T.ok(game.macros[1].body:find("Raptor Strike"))
    T.eq(L:Settings().installed.Fight.prev[1], v2, "the replaced text is kept")
    T.ok(V.Rollback(newer))
    T.eq(game.macros[1].body, v2)
  end)

  T.it("rollback is refused in combat, without history, and over a player's edit", function()
    local game, _, V = session()
    T.ok(V.Apply(FIGHT, V.Preview(FIGHT).token))
    T.eq(select(2, V.Rollback(FIGHT)), "no earlier version to go back to")
    local newer = { id = FIGHT.id, name = "Fight", body = "/cast Arcane Shot", scope = "char" }
    T.ok(V.Apply(newer, V.Preview(newer).token))
    game.combat = true
    T.eq(select(2, V.Rollback(newer)), "not in combat")
    game.combat = false
    game.macros[1].body = "/say my own line"
    T.ok(select(2, V.Rollback(newer)):find("changed outside"))
    T.eq(game.macros[1].body, "/say my own line")
  end)

  T.it("script commands are refused; the quiet line is allowed; the 255 limit and slots still hold", function()
    local game, ns, V = session()
    T.ok(V.Prohibited("/run DoSomething()"))
    T.ok(V.Prohibited("/script x()"))
    T.eq(V.Prohibited(ns.HandyKeys.QUIET_LINE), nil)
    local long = { id = "long", name = "Long", body = "/cast " .. string.rep("A", 260), scope = "char" }
    local pv = V.Preview(long)
    T.ok(pv.problems[1].msg:find("limit"))
    T.no(V.Apply(long, pv.token))
    local bad = { id = "bad", name = "Bad", body = "/run print(1)", scope = "char" }
    T.no(V.Apply(bad, V.Preview(bad).token))
    for i = 1, 18 do game.macros[#game.macros + 1] = { name = "M" .. i, body = "/sit", perChar = true } end
    local ok, why = V.Apply(FIGHT, V.Preview(FIGHT).token)
    T.no(ok) T.ok(why:find("slot"), why)
  end)
end)

-- OI05-11: every class's pack macros against the Forever rules we know
local FIXTURE = { TARGET = "Snarler", FOOD = "Tough Jerky", DRINK = "Refreshing Spring Water", MOUNT = "Brown Horse",
  PET = "Wolf", AMMO = "Rough Arrow", HEALTHSTONE = "Minor Healthstone", POTION = "Minor Healing Potion",
  BANDAGE = "Linen Bandage", QUESTITEM = "Quest Thing", TWOHAND = "Big Axe", ONEHAND = "Small Axe", SHIELD = "Buckler",
  RARE_LINES = "/targetexact Snarler" }
-- spells Forever removed (FOREVER_CONSTRAINTS: Lava Burst from the Nov 3 notes; the others from the class pages)
local REMOVED = { "Lava Burst", "Fire Nova Totem", "Dark Pact", "Curse of Shadow", "Faerie Fire (Feral)" }
local CLASSES = { "HUNTER", "WARRIOR", "ROGUE", "MAGE", "PRIEST", "WARLOCK", "DRUID", "SHAMAN", "PALADIN" }

T.describe("macro regression matrix (OI05-11)", function()
  for _, class in ipairs(CLASSES) do
    T.it(class .. ": every pack macro fits the known rules", function()
      local _, ns, V, L = session({ class = class })
      local n = 0
      for _, e in ipairs(ns.Data:All("macro")) do
        if e.class == class or e.class == "ALL" then
          n = n + 1
          local text = L.Final((ns.MacroEngine.Fill(e.body, FIXTURE)))
          local where = e.id .. ": "
          T.ok(#text <= 255, where .. #text .. " characters")
          T.eq(ns.MacroEngine.Errors(text), 0, where .. "validator errors")
          T.eq(V.Prohibited(text), nil, where .. "script command")
          for line in text:gmatch("[^\n]+") do
            T.ok(not line:find(",%s*null"), where .. "castsequence null doesn't hold on Forever")
            if line:match("^/cast ") then T.ok(not line:find("%(Rank %d+%)"), where .. "rank-less /cast casts the highest") end
            for mods in line:gmatch("mod:([%a/]+)") do
              for m in mods:gmatch("[^/]+") do T.ok(m == "shift" or m == "alt" or m == "ctrl", where .. "modifier " .. m) end
            end
            local cs = line:match("^/castsequence%s+(.*)$")
            if cs then
              local reset = cs:match("reset=(%S+)")
              if reset then for r in reset:gmatch("[^/]+") do
                T.ok(r == "combat" or r == "target" or r == "shift" or r == "alt" or r == "ctrl" or tonumber(r), where .. "reset " .. r)
              end end
              local steps = cs:gsub("%b[]", ""):gsub("reset=%S+", "")
              for part in (steps .. ","):gmatch("([^,;]*)[,;]") do T.ok(part:find("%S"), where .. "empty castsequence step") end
            end
          end
          for _, gone in ipairs(REMOVED) do T.ok(not text:find(gone, 1, true), where .. gone .. " was removed on Forever") end
        end
      end
      T.ok(n > 0, "the class has pack macros")
      T.eq(#ns.Errors.list, 0)
    end)
  end
end)
