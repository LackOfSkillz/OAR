-- Spellbook reader (P4-02). Spell IDs are test data.
local T, mock = ...

local function session(opts)
  local game = mock.new(opts)
  local ns = game:loadAddon()
  game:login()
  return game, ns
end

T.describe("spellbook", function()
  T.it("reads the modern spellbook, keeping the highest rank", function()
    local game, ns = session()
    local s = ns.Spellbook:Known("arcane shot")
    T.eq(s.rank, 3)
    T.eq(s.id, 14282)
    T.ok(ns.Spellbook:Known("Tame Beast"))
    T.eq(ns.Spellbook:Known("Multi-Shot"), nil)
    T.eq(ns.Spellbook.source, "C_SpellBook")
  end)

  T.it("learning a spell refreshes it (throttled) and it is saved per character", function()
    local game, ns = session()
    game.spells[#game.spells + 1] = { name = "Multi-Shot", id = 2643, rank = 1 }
    game:fire("LEARNED_SPELL_IN_TAB")
    game:advance(1)
    T.ok(ns.Spellbook:Known("Multi-Shot"))
    T.ok(ns.db.char.spellbook.spells["multi-shot"])
  end)

  T.it("/ride spells lists them with ranks", function()
    local game = session()
    game:slash("spells arcane")
    T.contains(game:chatText(), "Arcane Shot rank 3 (14282)")
  end)
end)
