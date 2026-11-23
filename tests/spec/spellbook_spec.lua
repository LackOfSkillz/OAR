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
    game:fire("SPELLS_CHANGED")
    game:advance(1)
    T.ok(ns.Spellbook:Known("Multi-Shot"))
    T.ok(ns.db.char.spellbook.spells["multi-shot"])
  end)

  T.it("/ride spells lists them with ranks", function()
    local game = session()
    game:slash("spells arcane")
    T.contains(game:chatText(), "Arcane Shot rank 3 (14282)")
  end)

  T.it("spells to learn come from this character's spellbook, not another visit, and aren't counted twice", function()
    local game, ns = session({ level = 10 })
    local store = ns.Spellbook:TrainingStore()
    -- Gary, 2026-11-23: a visit before Sheer learned them, saved both with and without the rank
    store["arcane shot:Rank 1"] = { name = "Arcane Shot", rank = "Rank 1", level = 6, status = "available" }
    store["arcane shot:level 6"] = { name = "Arcane Shot", level = 6, status = "available" }
    store["multi-shot:Rank 1"] = { name = "Multi-Shot", rank = "Rank 1", level = 10, status = "available" }
    store["serpent sting:Rank 9"] = { name = "Serpent Sting", rank = "Rank 9", level = 10, status = "available" }
    local now = ns.Spellbook:TrainerLists(10)
    local names = {}
    for _, e in ipairs(now) do names[#names + 1] = e.name end
    local text = table.concat(names, ", ")
    T.ok(not text:find("Arcane Shot", 1, true), "known: learned, whatever an old visit said: " .. text)
    T.contains(text, "Multi-Shot (Rank 1)")
    T.contains(text, "Serpent Sting (Rank 9)", "a higher rank than your book has is still to learn")
    T.eq(#now, 2, text)
  end)
end)
