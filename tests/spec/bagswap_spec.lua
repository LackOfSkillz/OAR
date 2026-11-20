-- Bag swap: a bigger bag in with one press (Gary, 2026-11-20).
local T, mock = ...

-- backpack 16 slots; bag 1 a 6-slot pouch with 3 items; bag 2 a 10-slot bag;
-- a 14-slot Big Sack waiting in the backpack.
local function session(opts)
  opts = opts or {}
  local game = mock.new()
  game.items = {
    [801] = { name = "Small Pouch", class = 1, subclass = 0, slots = 6 },
    [802] = { name = "Linen Bag", class = 1, subclass = 0, slots = 10 },
    [803] = { name = "Big Sack", class = 1, subclass = 0, slots = 14 },
    [900] = { name = "Rock" }, [901] = { name = "Stick" }, [902] = { name = "Feather" },
  }
  game.itemTips = { [801] = { "Small Pouch", "6 Slot Bag" }, [802] = { "Linen Bag", "10 Slot Bag" }, [803] = { "Big Sack", "14 Slot Bag" } }
  game.bagSize = { [0] = 16, [1] = 6, [2] = 10, [3] = opts.emptySlot and 0 or 10, [4] = opts.emptySlot and 0 or 10 }
  game.bagItem = { [1] = 801, [2] = 802 }
  game.bags = { [0] = { [1] = 803 }, [1] = { [1] = 900, [2] = 901, [5] = 902 }, [2] = {}, [3] = {}, [4] = {} }
  if opts.full then
    for bag = 0, 4 do for slot = 1, game.bagSize[bag] do
      if bag ~= 1 and not game.bags[bag][slot] then game.bags[bag][slot] = 900 end
    end end
    game.bags[0][16] = nil -- one free slot, three items to move
  end
  local ns = game:loadAddon()
  game:login()
  return game, ns
end

local function finish(game) for _ = 1, 40 do game:advance(1) end end

T.describe("bag swap", function()
  T.it("one press: empties the smallest bag into the others and puts the bigger bag in", function()
    local game, ns = session()
    local plan = ns.BagSwap:Plan()
    T.eq(plan.newBag.name, "Big Sack")
    T.eq(plan.target, 1, "the 6-slot pouch is the smallest")
    T.eq(plan.items, 3)
    T.ok(ns.BagSwap:Run())
    finish(game)
    T.eq(game.bagSize[1], 14, "Big Sack is in")
    T.eq(game.bagItem[1], 803)
    local found = {}
    for bag = 0, 4 do for _, id in pairs(game.bags[bag] or {}) do found[id] = (found[id] or 0) + 1 end end
    T.eq(found[900], 1) T.eq(found[901], 1) T.eq(found[902], 1)
    T.eq(found[801], 1, "the old pouch is in your bags, nothing lost")
    T.contains(game:chatText(), "Big Sack (14 slots) is in")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("an empty bag slot: the bag just goes in", function()
    local game, ns = session({ emptySlot = true })
    T.eq(ns.BagSwap:Plan().target, 3)
    ns.BagSwap:Run()
    finish(game)
    T.eq(game.bagSize[3], 14)
    T.eq(game.bagSize[1], 6, "the pouch stays")
  end)

  T.it("not enough room elsewhere: says how many slots to free, moves nothing", function()
    local game, ns = session({ full = true })
    T.eq(ns.BagSwap:Run(), false)
    T.contains(game:chatText(), "need 2 more free slots")
    T.eq(game.moves, nil)
  end)

  T.it("stops in a fight, and won't start in one", function()
    local game, ns = session()
    ns.BagSwap:Run()
    game:setCombat(true)
    finish(game)
    T.eq(ns.BagSwap.job, nil)
    T.eq(game.bagSize[1], 6, "nothing swapped mid-fight")
    T.eq(ns.BagSwap:Run(), false)
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("says once when a bigger bag shows up", function()
    local game, ns = session()
    ns.BagSwap:Check()
    ns.BagSwap:Check()
    local _, n = game:chatText():gsub("beats a bag you wear", "")
    T.eq(n, 1)
  end)
end)
