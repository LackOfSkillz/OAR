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
    T.contains(m.body, "/castsequence reset=combat/target !Auto Shot,Serpent Sting,null")
    T.ok(not m.body:find("/cast !Auto Shot", 1, true), "Auto Shot never re-sent on each press")
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
    T.contains(body, "/castsequence reset=combat/target Hunter's Mark,!Auto Shot,Serpent Sting,null")
    T.ok(not body:find("Concussive", 1, true), "guide order: Concussive kept for when the pet loses aggro")
    T.ok(body:find("Serpent Sting,null", 1, true) < body:find("/cast Arcane", 1, true), "Arcane fills after the opener")
    local _, autos = body:gsub("Auto Shot", "")
    T.eq(autos, 1, "Auto Shot appears once, inside the opener")
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

  T.it("counts Hunter's Mark cast just before combat starts", function()
    local game, ns = session(sp("Auto Shot", "Serpent Sting", "Hunter's Mark"), BOW)
    game:fire("UNIT_SPELLCAST_SUCCEEDED", "player", "x", 9003)
    game:advance(2)
    game:setCombat(true)
    game:fire("UNIT_SPELLCAST_SUCCEEDED", "player", "x", 9002)
    game:setCombat(false)
    game:fire("PLAYER_LOGOUT")
    local found
    for _, l in ipairs(ns.Log:Tail(20)) do
      local s = ns.Log:FormatLine(l)
      if s:find("Hunter's Mark@-2.0, Serpent Sting@0.0", 1, true) then found = true end
    end
    T.ok(found, "Mark logged with a negative time")
  end)

  T.it("pet: Fight sends it, a Pet key cares for it, the log counts fights with it", function()
    local game, ns = session(sp("Auto Shot", "Raptor Strike", "Hunter's Mark", "Call Pet", "Revive Pet", "Mend Pet"), BOW)
    T.contains(macro(game, "Fight").body, "/petattack [pet,harm]")
    T.contains(macro(game, "Strike").body, "/petattack [pet,harm]")
    local p = macro(game, "Pet")
    T.ok(p, "Pet macro made with the others")
    T.eq(p.body, "#showtooltip\n/cast [@pet,dead] Revive Pet; [nopet] Call Pet; Mend Pet")
    T.eq(ns.MacroEngine.Errors(p.body), 0)
    game.units = { pet = { name = "Crawler" } }
    game:setCombat(true)
    game:fire("UNIT_SPELLCAST_SUCCEEDED", "player", "x", 9003)
    game:setCombat(false)
    game:fire("PLAYER_LOGOUT")
    local found
    for _, l in ipairs(ns.Log:Tail(20)) do
      if ns.Log:FormatLine(l):find("pet out in 1;", 1, true) then found = true end
    end
    T.ok(found, "fights with the pet out counted")
  end)

  T.it("Pet key uses Forever's renamed call spell (Call <pet name>)", function()
    local game = session(sp("Auto Shot", "Raptor Strike", "Call TempMystMane", "Revive Pet", "Mend Pet"), BOW)
    T.contains(macro(game, "Pet").body, "[nopet] Call TempMystMane; Mend Pet")
  end)

  T.it("no pet spells yet: no Pet macro", function()
    local game, ns = session(sp("Auto Shot", "Raptor Strike"), BOW)
    T.eq(macro(game, "Pet"), nil)
    for _, e in ipairs(ns.MacroLibrary:Entries()) do T.ok(e.id ~= "hunter-pet") end
  end)

  T.it("measures the gaps between Auto Shots", function()
    local g = (select(3, session(sp("Auto Shot"), BOW))).AutoGaps({ "Auto Shot@0.5", "Arcane Shot@1.0", "Auto Shot@3.3", "Auto Shot@6.1" })
    T.eq(g.n, 2)
    T.ok(math.abs(g.sum - 5.6) < 0.01)
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
      if s:find("fights this session: 20, average 4s, pet out in 0; cast in: Hunter's Mark 10/20, Serpent Sting 20/20", 1, true) then cast = true end
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

  T.it("Aspect of the Hawk goes on before the pull, never in combat; Distracting Shot stays out", function()
    local game = session(sp("Auto Shot", "Hunter's Mark", "Serpent Sting", "Aspect of the Hawk", "Distracting Shot",
      "Arcane Shot", "Concussive Shot"), BOW)
    local body = macro(game, "Fight").body
    T.contains(body, "/cast [nocombat] !Aspect of the Hawk")
    T.ok(body:find("Aspect of the Hawk", 1, true) < body:find("Hunter's Mark", 1, true))
    T.ok(not body:find("Distracting", 1, true))
    T.ok(#body <= 255)
  end)

  T.it("Concussive comes back in when its toggle is on", function()
    local game, ns = session(sp("Auto Shot", "Hunter's Mark", "Serpent Sting", "Concussive Shot"), BOW)
    game:slash("fight concussive on")
    game:advance(3)
    T.contains(macro(game, "Fight").body, "Hunter's Mark,Concussive Shot,!Auto Shot,Serpent Sting,null")
  end)

  T.it("the Hawk line is only there while Hawk is off; Fight is rewritten when Hawk flips", function()
    local game = session(sp("Auto Shot", "Hunter's Mark", "Aspect of the Hawk"), BOW)
    T.contains(macro(game, "Fight").body, "!Aspect of the Hawk")
    game.units = game.units or {}
    game.units.player = { auras = { { name = "Aspect of the Hawk", spellId = 13165 } } }
    game:fire("UNIT_AURA", "player")
    game:advance(3)
    T.ok(not macro(game, "Fight").body:find("Aspect of the Hawk", 1, true), "no wasted press while Hawk is on")
    game.units.player = { auras = {} }
    game:fire("UNIT_AURA", "player")
    game:advance(3)
    T.contains(macro(game, "Fight").body, "!Aspect of the Hawk")
  end)
end)
