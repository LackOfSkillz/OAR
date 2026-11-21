-- The class page lists what the trainer really teaches (Gary, 2026-11-21: Outrider
-- missed Backstab Rank 2, Parry and Sinister Strike Rank 3 and showed Pick Lock at 1).
-- The rows below copy what Gary's rogue trainer showed at level 14.
local T, mock = ...

local ROWS = {
  { "Backstab", "Rank 2", "available", 12, 900, 132090 },
  { "Kick", "Rank 1", "available", 12, 900, 132219 },
  { "Parry", nil, "available", 12, 900, 132269 },
  { "Expose Armor", "Rank 1", "available", 14, 1100, 132354 },
  { "Garrote", "Rank 1", "available", 14, 1100, 132297 },
  { "Sinister Strike", "Rank 3", "available", 14, 1100, 136189 },
  { "Sinister Strike", "Rank 2", "used", 6, 100, 136189 },
  { "Feint", "Rank 1", "unavailable", 16, 1500, 132294 },
  { "Ambush", "Rank 1", "unavailable", 18, 2000, 132282 },
}

local function session(classic)
  local game = mock.new({ class = "ROGUE", level = 14 })
  game.trainer, game.trainerClassic = ROWS, classic
  local ns = game:loadAddon()
  game:login()
  game.units = { npc = { guid = "Creature-0-1-0-1-3401-1", name = "Boarton Shadetotem", title = "Rogue Trainer" } }
  game:fire("TRAINER_SHOW")
  game:advance(0.5)
  return game, ns
end

T.describe("trainer list", function()
  for _, classic in ipairs({ false, true }) do
    T.it("reads ranks and status from the trainer (" .. (classic and "Classic" or "Forever") .. " order)", function()
      local _, ns = session(classic)
      local now, soon, nextLevel, from = ns.ClassPage.TrainerSpells("ROGUE")
      T.eq(from, "trainer")
      local names = {}
      for _, sp in ipairs(now) do names[#names + 1] = sp.name end
      T.same(names, { "Backstab (Rank 2)", "Kick (Rank 1)", "Parry", "Expose Armor (Rank 1)", "Garrote (Rank 1)", "Sinister Strike (Rank 3)" })
      T.eq(nextLevel, 16)
      T.eq(soon[1].name, "Feint (Rank 1)")
      T.eq(#ns.Errors.list, 0)
    end)
  end

  T.it("a spell bought at the trainer drops off the list", function()
    local game, ns = session()
    ROWS[2][3] = "used"
    game:fire("TRAINER_UPDATE")
    game:advance(1)
    ROWS[2][3] = "available"
    local now = ns.ClassPage.TrainerSpells("ROGUE")
    for _, sp in ipairs(now) do T.ok(sp.name ~= "Kick (Rank 1)", "Kick learned") end
  end)

  T.it("without a trainer visit the page says the list is an estimate", function()
    local game = mock.new({ class = "ROGUE", level = 14 })
    local ns = game:loadAddon()
    game:login()
    local _, _, _, from = ns.ClassPage.TrainerSpells("ROGUE")
    T.eq(from, "estimate")
  end)

  T.it("no Lua string has a single backslash after Interface (broken icon paths)", function()
    local bad = {}
    for line in io.lines("addon/Outrider/Outrider.toc") do
      local rel = line:match("^([%w_\\]+%.lua)%s*$")
      if rel then
        local n = 0
        for code in io.lines("addon/Outrider/" .. rel:gsub("\\", "/")) do
          n = n + 1
          if not code:match("^%s*%-%-") and code:find('"Interface\\[^\\]') then bad[#bad + 1] = rel .. ":" .. n end
        end
      end
    end
    T.eq(#bad, 0, table.concat(bad, ", "))
  end)
end)
