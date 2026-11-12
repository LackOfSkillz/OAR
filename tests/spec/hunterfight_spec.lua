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
  T.it("level 4: Fight shoots and stings, Strike strikes; no spell it doesn't know", function()
    local game, ns = session(sp("Auto Shot", "Raptor Strike", "Serpent Sting"), BOW)
    local m, k = macro(game, "Fight"), macro(game, "Strike")
    T.ok(m and k, "both macros created by /ride fight")
    T.ok(m.perChar and k.perChar, "character macros")
    T.contains(m.body, "/cast !Auto Shot")
    T.contains(m.body, "/castsequence reset=15/target Serpent Sting,null")
    T.ok(not m.body:find("Raptor", 1, true), "no melee in the ranged key")
    T.ok(not m.body:find("Concussive", 1, true))
    T.ok(not m.body:find("Arcane", 1, true))
    T.contains(k.body, "/startattack")
    T.contains(k.body, "/cast Raptor Strike")
    T.ok(not k.body:find("Auto Shot", 1, true))
    T.eq(ns.MacroEngine.Errors(m.body), 0)
    T.eq(ns.MacroEngine.Errors(k.body), 0)
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("one spell per press: once-per-target spells first, cooldowns next, Auto Shot last; rewritten after combat", function()
    local game, ns = session(sp("Auto Shot", "Raptor Strike", "Serpent Sting"), BOW)
    local count = #game.macros
    game:setCombat(true)
    game.spells = sp("Auto Shot", "Raptor Strike", "Serpent Sting", "Concussive Shot", "Arcane Shot", "Hunter's Mark",
      "Wing Clip", "Mongoose Bite")
    game:fire("SPELLS_CHANGED")
    game:advance(3)
    T.ok(not macro(game, "Fight").body:find("Arcane", 1, true), "not edited in combat")
    game:setCombat(false)
    game:advance(1)
    local body = macro(game, "Fight").body
    T.eq(#game.macros, count, "same macros, no new ones")
    local a, b, c, d, e = body:find("Hunter's Mark", 1, true), body:find("Serpent", 1, true),
      body:find("Concussive", 1, true), body:find("/cast Arcane", 1, true), body:find("!Auto Shot", 1, true)
    T.ok(a < c and c < b and b < d and d < e, "Mark, Concussive, Serpent, Arcane, Auto Shot")
    local melee = macro(game, "Strike").body
    local w, r, g = melee:find("Wing Clip,null", 1, true), melee:find("Raptor", 1, true), melee:find("Mongoose", 1, true)
    T.ok(w < r and r < g, "melee order: Wing Clip once, Raptor on cooldown, Mongoose last")
    T.eq(#game.blocked, 0)
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("Strike comes along by itself once Fight is ours", function()
    local game, ns = session(sp("Auto Shot", "Raptor Strike"), BOW, { noInstall = true })
    ns.MacroLibrary:Install(ns.HunterFight:Entry("ranged"))
    T.eq(macro(game, "Strike"), nil)
    game:fire("SPELLS_CHANGED")
    game:advance(3)
    T.ok(macro(game, "Strike"), "Strike written on the next spellbook change")
  end)

  T.it("a thrown weapon or empty ranged slot leaves no shots in Fight", function()
    local game = session(sp("Auto Shot", "Raptor Strike", "Serpent Sting", "Arcane Shot"), 3131)
    local body = macro(game, "Fight").body
    T.ok(not body:find("Auto Shot", 1, true))
    T.ok(not body:find("Arcane", 1, true))
    T.contains(macro(game, "Strike").body, "Raptor Strike")
  end)

  T.it("everything known still fits in 255 characters", function()
    local _, _, F = session(sp("Auto Shot", "Raptor Strike", "Mongoose Bite", "Serpent Sting", "Concussive Shot",
      "Arcane Shot", "Hunter's Mark", "Wing Clip"), BOW)
    for _, kind in ipairs({ "ranged", "melee" }) do
      local body, dropped = F:Body(kind)
      T.ok(#body <= 255, #body .. " chars")
      T.eq(#dropped, 0, kind .. " needs no trimming")
    end
  end)

  T.it("logs each fight's casts for checking the order", function()
    local game, ns = session(sp("Auto Shot", "Serpent Sting"), BOW)
    game:setCombat(true)
    game:fire("UNIT_SPELLCAST_SUCCEEDED", "player", "x", 9002)
    game:advance(2)
    game:fire("UNIT_SPELLCAST_SUCCEEDED", "target", "x", 9001)
    game:fire("UNIT_SPELLCAST_FAILED", "player", "x", 9002)
    game:fire("UI_ERROR_MESSAGE", 50, "Out of range.")
    game:fire("UI_ERROR_MESSAGE", 50, "Out of range.")
    game:setCombat(false)
    local refused
    for _, l in ipairs(ns.Log:Tail(10)) do
      local s = ns.Log:FormatLine(l)
      if s:find("failed Serpent Sting x1; errors Out of range. x2", 1, true) then refused = true end
    end
    T.ok(refused, "refusals logged")
    local found
    for _, l in ipairs(ns.Log:Tail(10)) do
      local s = ns.Log:FormatLine(l)
      if s:find("fight", 1, true) and s:find("Serpent Sting@0.0", 1, true) then found = s end
    end
    T.ok(found, "fight line logged")
  end)

  T.it("logs a whole-session tally at logout, past the 15-fight cap", function()
    local game, ns = session(sp("Auto Shot", "Serpent Sting", "Hunter's Mark"), BOW)
    for i = 1, 20 do
      game:setCombat(true)
      if i % 2 == 0 then game:fire("UNIT_SPELLCAST_SUCCEEDED", "player", "x", 9003) end
      game:fire("UNIT_SPELLCAST_SUCCEEDED", "player", "x", 9002)
      game:fire("UNIT_SPELLCAST_SUCCEEDED", "player", "x", 9002)
      game:fire("UI_ERROR_MESSAGE", 50, "Target too close")
      game:advance(4)
      game:setCombat(false)
    end
    game:fire("PLAYER_LOGOUT")
    local cast, refused
    for _, l in ipairs(ns.Log:Tail(20)) do
      local s = ns.Log:FormatLine(l)
      if s:find("fights this session: 20, average 4s; cast in: Hunter's Mark 10/20, Serpent Sting 20/20", 1, true) then cast = true end
      if s:find("fights refused this session: failed none; errors Target too close x20", 1, true) then refused = true end
    end
    T.ok(cast, "cast tally")
    T.ok(refused, "refusal tally")
  end)

  T.it("not created until Gary asks; listed in the Macros tab", function()
    local game, ns = session(sp("Auto Shot", "Raptor Strike"), BOW, { noInstall = true })
    T.eq(macro(game, "Fight"), nil)
    local listed = false
    for _, e in ipairs(ns.MacroLibrary:Entries()) do if e.id == "hunter-fight" then listed = true end end
    T.ok(listed)
    T.eq(ns.MacroLibrary:State(ns.HunterFight:Entry()), "ready")
  end)

  T.it("logs Blizzard's one-button rotation when the client has it", function()
    local game = mock.new()
    game.env.C_AssistedCombat = { GetNextCastSpell = function() return 9001 end, IsAvailable = function() return true end,
      GetActionSpell = function() return 9003 end, GetRotationSpells = function() return { 9001, 9002 } end }
    game.spells = sp("Auto Shot", "Serpent Sting", "Single-Button Assistant")
    local ns = game:loadAddon()
    game:login()
    local found
    for _, l in ipairs(ns.Log:Tail(80)) do
      local s = ns.Log:FormatLine(l)
      if s:find("assisted combat: available true, button spell Single-Button Assistant (9003), rotation 2", 1, true) then found = true end
    end
    T.ok(found)
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
