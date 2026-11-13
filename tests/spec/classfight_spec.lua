-- Fight macros per class: each class gets only its own keys. Spells are test data.
local T, mock = ...

local function session(class, ...)
  local game = mock.new({ class = class })
  local spells = {}
  for i, n in ipairs({ ... }) do spells[i] = { name = n, id = 9100 + i } end
  game.spells = spells
  local ns = game:loadAddon()
  game:login()
  ns.Modules:SetEnabled("AutoCheck", false)
  game:advance(3)
  game:slash("fight")
  return game, ns
end

local function macro(game, name)
  for _, m in ipairs(game.macros) do if m.name == name then return m end end
end

T.describe("class fight macros", function()
  T.it("mage: Fight nukes, Strike is Frost Nova, Fire Blast, Arcane Explosion; no hunter keys", function()
    local game, ns = session("MAGE", "Fireball", "Frostbolt", "Frost Nova", "Fire Blast", "Arcane Explosion")
    local f, k = macro(game, "Fight"), macro(game, "Strike")
    T.ok(f and k)
    T.contains(f.body, "/cast Frostbolt")
    T.ok(not f.body:find("Fireball", 1, true), "Frostbolt replaces Fireball once learned")
    local a, b, c = k.body:find("Frost Nova", 1, true), k.body:find("Fire Blast", 1, true), k.body:find("Arcane Explosion", 1, true)
    T.ok(a < b and b < c)
    T.eq(macro(game, "Pet"), nil)
    T.ok(not f.body:find("petattack", 1, true))
    T.eq(ns.MacroEngine.Errors(f.body), 0)
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("priest: Fight is SW:Pain once, Mind Blast, Smite; Heal heals who you point at", function()
    local game, ns = session("PRIEST", "Smite", "Shadow Word: Pain", "Mind Blast", "Lesser Heal")
    local f, h = macro(game, "Fight"), macro(game, "Heal")
    T.contains(f.body, "/castsequence reset=combat/target Shadow Word: Pain,null")
    T.ok(f.body:find("Mind Blast", 1, true) < f.body:find("Smite", 1, true))
    T.contains(h.body, "[@mouseover,help,nodead][@target,help,nodead][@player] Lesser Heal")
    T.eq(macro(game, "Strike"), nil, "no melee key for priests")
    T.eq(ns.MacroEngine.Errors(h.body), 0)
  end)

  T.it("a rogue gets no Fight macros and no hunter tools", function()
    local game, ns = session("ROGUE", "Sinister Strike")
    T.eq(macro(game, "Fight"), nil)
    T.eq(ns.Modules:Get("HunterFight").enabled, false)
    T.eq(ns.Modules:Get("TameHelper").enabled, false)
    T.eq(ns.Modules:Get("PetStatus").enabled, false)
    T.eq(#ns.Errors.list, 0)
  end)
end)
