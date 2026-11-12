-- One-key hunter Fight macro: text follows the spellbook and the ranged slot.
local T, mock = ...

local BOW = 2504
local function session(spells, ranged, opts)
  local game = mock.new(opts)
  game.spells = spells
  game.items = { [BOW] = { name = "Worn Shortbow", equipLoc = "INVTYPE_RANGED", class = 2, subclass = 2 },
    [3131] = { name = "Weighted Throwing Axe", equipLoc = "INVTYPE_THROWN", class = 2, subclass = 16 } }
  game.worn = { [18] = ranged }
  local ns = game:loadAddon()
  game:login()
  ns.Modules:SetEnabled("AutoCheck", false)
  game:advance(3)
  if not (opts and opts.noInstall) then game:slash("fight") end -- Gary's one click (or /ride fight)
  return game, ns, ns.HunterFight
end

local function sp(...)
  local out = {}
  for i, n in ipairs({ ... }) do out[i] = { name = n, id = 9000 + i } end
  return out
end

local function macro(game, name)
  for _, m in ipairs(game.macros) do if m.name == name then return m end end
end

T.describe("hunter fight macro", function()
  T.it("level 4: shoots, stings once, strikes in melee; no spell it doesn't know", function()
    local game, ns = session(sp("Auto Shot", "Raptor Strike", "Serpent Sting"), BOW)
    local m = macro(game, "Fight")
    T.ok(m, "macro created by /ride fight")
    T.ok(m.perChar, "character macro")
    T.contains(m.body, "/cast !Auto Shot")
    T.contains(m.body, "/cast Raptor Strike")
    T.contains(m.body, "/castsequence reset=15/target Serpent Sting,null")
    T.ok(not m.body:find("Concussive", 1, true))
    T.ok(not m.body:find("Arcane", 1, true))
    T.eq(ns.MacroEngine.Errors(m.body), 0)
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("learning Concussive Shot and Arcane Shot rewrites the same macro, after combat", function()
    local game, ns = session(sp("Auto Shot", "Raptor Strike", "Serpent Sting"), BOW)
    local count = #game.macros
    game:setCombat(true)
    game.spells = sp("Auto Shot", "Raptor Strike", "Serpent Sting", "Concussive Shot", "Arcane Shot", "Hunter's Mark")
    game:fire("SPELLS_CHANGED")
    game:advance(3)
    T.ok(not macro(game, "Fight").body:find("Arcane", 1, true), "not edited in combat")
    game:setCombat(false)
    game:advance(1)
    local body = macro(game, "Fight").body
    T.eq(#game.macros, count, "same macro, not a second one")
    T.contains(body, "Concussive Shot,null")
    T.contains(body, "/cast Arcane Shot")
    -- order: mark, then sting, then the slow, then Arcane Shot on cooldown
    local a, b, c, d = body:find("Hunter's Mark", 1, true), body:find("Serpent", 1, true),
      body:find("Concussive", 1, true), body:find("/cast Arcane", 1, true)
    T.ok(a < b and b < c and c < d, "priority order")
    T.ok(body:find("Raptor", 1, true) < a, "melee strike tried before the shots")
    T.eq(#game.blocked, 0)
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("a thrown weapon or empty ranged slot gives a melee-only macro", function()
    local game = session(sp("Auto Shot", "Raptor Strike", "Serpent Sting", "Arcane Shot"), 3131)
    local body = macro(game, "Fight").body
    T.ok(not body:find("Auto Shot", 1, true))
    T.ok(not body:find("Arcane", 1, true))
    T.contains(body, "Raptor Strike")
  end)

  T.it("everything known still fits in 255 characters", function()
    local game, ns, F = session(sp("Auto Shot", "Raptor Strike", "Mongoose Bite", "Serpent Sting", "Concussive Shot",
      "Arcane Shot", "Hunter's Mark", "Wing Clip"), BOW)
    F:Settings().wingclip = true
    local body, dropped = F:Body()
    T.ok(#body <= 255, #body .. " chars")
    T.contains(body, "!Auto Shot")
    T.contains(body, "Raptor Strike")
    T.contains(body, "Serpent Sting")
    T.contains(body, "Arcane Shot")
    T.ok(type(dropped) == "table")
  end)

  T.it("logs each fight's casts for checking the order", function()
    local game, ns = session(sp("Auto Shot", "Serpent Sting"), BOW)
    game:setCombat(true)
    game:fire("UNIT_SPELLCAST_SUCCEEDED", "player", "x", 9002)
    game:advance(2)
    game:fire("UNIT_SPELLCAST_SUCCEEDED", "target", "x", 9001)
    game:setCombat(false)
    local found
    for _, l in ipairs(ns.Log:Tail(10)) do
      local s = ns.Log:FormatLine(l)
      if s:find("fight", 1, true) and s:find("Serpent Sting@0.0", 1, true) then found = s end
    end
    T.ok(found, "fight line logged")
  end)

  T.it("not created until Gary asks; listed in the Macros tab", function()
    local game, ns = session(sp("Auto Shot", "Raptor Strike"), BOW, { noInstall = true })
    T.eq(macro(game, "Fight"), nil)
    local listed = false
    for _, e in ipairs(ns.MacroLibrary:Entries()) do if e.id == "hunter-fight" then listed = true end end
    T.ok(listed)
    T.eq(ns.MacroLibrary:State(ns.HunterFight:Entry()), "ready")
  end)

  T.it("won't overwrite a macro called Fight that Gary made", function()
    local game = mock.new({ macros = { { name = "Fight", icon = "x", body = "/cast Raptor Strike", perChar = true } } })
    game.spells = sp("Auto Shot", "Raptor Strike")
    local ns = game:loadAddon()
    game:login()
    game:advance(3)
    game:slash("fight")
    T.eq(game.macros[1].body, "/cast Raptor Strike")
    T.eq(#ns.Errors.list, 0)
  end)
end)
