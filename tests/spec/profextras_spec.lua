-- Trainer list, skill-up chance and craft cooldowns (gap analysis 2026-11-17).
local T, mock = ...

local function start()
  local game = mock.new({ class = "HUNTER", level = 20 })
  local services = {
    { "Alchemy", "", "header" },
    { "Elixir of Lesser Agility", "", "available", 1500, "Alchemy", 140, 0 },
    { "Elixir of Fortitude", "", "unavailable", 2000, "Alchemy", 175, 0 },
    { "Swiftness Potion", "", "unavailable", 1800, "Alchemy", 60, 0 },
    { "Minor Healing Potion", "", "used", 10, "Alchemy", 1, 0 },
  }
  local function set(k, v) rawset(game.env, k, v) game.base[k] = v end
  set("GetNumTrainerServices", function() return #services end)
  set("GetTrainerServiceInfo", function(i) local s = services[i] return s[1], s[2], s[3] end)
  set("GetTrainerServiceCost", function(i) return services[i][4] or 0 end)
  set("GetTrainerServiceSkillReq", function(i) local s = services[i] return s[5], s[6] end)
  set("GetTrainerServiceLevelReq", function(i) return services[i][7] or 0 end)
  local ns = game:loadAddon()
  game:login()
  return game, ns, ns.ProfExtras
end

T.describe("profession extras", function()
  T.it("reads a trainer: learn now, and what comes next by skill", function()
    local game, ns, M = start()
    local kind = M:ReadTrainer()
    T.eq(kind, "Alchemy")
    local u = M:Upcoming("Alchemy")
    T.eq(#u.ready, 1)
    T.eq(u.ready[1].name, "Elixir of Lesser Agility")
    T.eq(#u.later, 2)
    T.eq(u.later[1].name, "Swiftness Potion")
  end)

  T.it("skill-up chance from recipe colour; grey recipes left out", function()
    local game, ns, M = start()
    ns.db.char.professions = { Alchemy = { skill = 46, max = 75, recipes = {
      [1] = { name = "Minor Healing Potion", diff = 3 }, [2] = { name = "Elixir of Minor Agility", diff = 0 },
      [3] = { name = "Minor Mana Potion", diff = 1 } } } }
    local list = M:SkillRecipes("Alchemy")
    T.eq(#list, 2)
    T.eq(list[1].name, "Elixir of Minor Agility")
    T.contains(list[1].chance, "always")
    T.contains(list[2].chance, "likely")
  end)

  T.it("keeps craft cooldowns per character and says when one is ready", function()
    local game, ns, M = start()
    game.now = 1000
    M.cds[ns.db.key] = { ["Transmute: Arcanite"] = 1500 }
    T.eq(M:Cooldowns()[1].ready, false)
    game.now = 2000
    T.eq(M:Cooldowns()[1].ready, true)
    M:WarnReady()
    T.contains(game:chatText(), "Transmute: Arcanite")
  end)

  T.it("the Professions page builds with the new sections", function()
    local game, ns, M = start()
    M:ReadTrainer()
    ns.Hub:Toggle()
    ns.Hub:ShowTab("professions")
    T.eq(#ns.Errors.list, 0)
  end)
end)
