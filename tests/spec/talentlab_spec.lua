-- Talents page (Gary, 2026-11-23): the trees from the client, build cards per
-- goal, a sandbox with the game's rules, diff from your build, share codes.
-- Trees and names here are test data.
local T, mock = ...

-- one modern tree with three sub-trees, like C_Traits may give it
local function traits(ranks)
  ranks = ranks or {}
  local function n(id, name, sub, x, y, max, opens)
    return { id = id, name = name, sub = sub, x = x, y = y, max = max, rank = ranks[name] or 0, open = true, opens = opens, spell = id + 5000 }
  end
  return { { treeID = 1, unspent = 0, subNames = { [11] = "Balance", [12] = "Feral Combat", [13] = "Restoration" }, nodes = {
    n(101, "Starlight Wrath", 11, 100, 100, 5),
    n(102, "Nature's Grasp", 11, 200, 100, 1, { 103 }),
    n(103, "Improved Nature's Grasp", 11, 200, 200, 4),
    n(104, "Moonglow", 11, 300, 300, 3),
    n(201, "Ferocity", 12, 100, 100, 5),
    n(202, "Feral Aggression", 12, 200, 100, 5),
    n(203, "Thick Hide", 12, 100, 200, 5),
    n(204, "Sharpened Claws", 12, 200, 300, 3),
    n(301, "Improved Mark of the Wild", 13, 100, 100, 5),
    n(302, "Furor", 13, 200, 100, 5),
  } } }
end

local function session(level, ranks)
  local game = mock.new({ class = "DRUID", level = level or 20 })
  game.traits = traits(ranks)
  local ns = game:loadAddon()
  game:login()
  ns.Modules:SetEnabled("AutoCheck", false)
  return game, ns, ns.TalentLab
end

local function node(model, name) return model.byName[name].node end

T.describe("talent lab", function()
  T.it("reads the three trees, their rows, columns and links from the client", function()
    local _, _, L = session(20, { ["Ferocity"] = 3 })
    local model = L:Load()
    T.eq(#model.trees, 3)
    T.eq(model.trees[1].name, "Balance")
    T.eq(model.trees[2].name, "Feral Combat")
    local grasp = model.byName["Improved Nature's Grasp"]
    T.eq(grasp.tier, 2)
    T.eq(grasp.column, 2)
    T.eq(grasp.req[1], 102, "needs Nature's Grasp")
    T.eq(model.byName["Moonglow"].tier, 3)
    T.eq(L.Mine(model)[201], 3)
    T.eq(L.Split(model, L.Mine(model)), "0/3/0")
  end)

  T.it("keeps the game's rules: points for the level, 5 a row, links maxed first", function()
    local _, _, L = session(20)
    local model = L:Load()
    local r = {}
    T.eq(L.Points(20), 11)
    T.eq(L.Points(60), 51)
    local ok, why = L.Add(model, r, node(model, "Improved Nature's Grasp"), 20)
    T.no(ok, "row 2 is locked")
    T.contains(why, "needs 5 points")
    for _ = 1, 5 do T.ok(L.Add(model, r, node(model, "Starlight Wrath"), 20)) end
    ok, why = L.Add(model, r, node(model, "Improved Nature's Grasp"), 20)
    T.no(ok)
    T.contains(why, "Nature's Grasp maxed first")
    T.ok(L.Add(model, r, node(model, "Nature's Grasp"), 20))
    T.ok(L.Add(model, r, node(model, "Improved Nature's Grasp"), 20))
    ok, why = L.Remove(model, r, node(model, "Nature's Grasp"), 20)
    T.no(ok, "Improved Nature's Grasp depends on it")
    T.contains(why, "depend")
    -- the level's points
    local level10 = {}
    T.ok(L.Add(model, level10, node(model, "Ferocity"), 10))
    ok, why = L.Add(model, level10, node(model, "Ferocity"), 10)
    T.no(ok)
    T.contains(why, "only 1 points at level 10")
  end)

  T.it("a build card fills the trees for a level, says what's missing, and the diff from your build", function()
    local _, ns, L = session(20, { ["Ferocity"] = 2, ["Furor"] = 1 })
    ns.Data:Register("talentcard", "test", {
      { id = "druid-test", class = "DRUID", goal = "leveling", name = "Test bear", source = "https://example.org/x", verified = false,
        points = { ["Ferocity"] = 5, ["Thick Hide"] = 3, ["Missing Talent"] = 1 } },
    })
    local model = L:Load()
    local card
    for _, c in ipairs(L.Cards("DRUID")) do if c.id == "druid-test" then card = c end end
    T.ok(card, "the test card is listed")
    local r, missing = L.RanksFor(model, card, 20)
    T.eq(r[node(model, "Ferocity")], 5)
    T.eq(r[node(model, "Thick Hide")], 3)
    T.eq(missing[1], "Missing Talent")
    r = L.RanksFor(model, card, 12)
    T.eq(L.Total(r), 3, "level 12: three points, the order goes Ferocity first")
    local adds, removes = L.Diff(model, L.Mine(model), L.RanksFor(model, card, 20), L.Order(model, card))
    T.eq(adds[1].name, "Ferocity")
    T.eq(adds[1].n, 3)
    T.eq(removes[1].name, "Furor")
    local best, off = L.Closest(model, L.Mine(model), { card }, 20)
    T.eq(best.id, "druid-test")
    T.eq(off, 1, "Furor is the one point off")
  end)

  T.it("share codes load back, and a code from changed talents is refused", function()
    local _, _, L = session(60)
    local model = L:Load()
    local r = {}
    for _ = 1, 5 do L.Add(model, r, node(model, "Ferocity"), 60) end
    L.Add(model, r, node(model, "Thick Hide"), 60)
    local code = L.Export(model, r)
    T.contains(code, "OTB1:DRUID:")
    local back = L.Import(model, code)
    T.eq(back[node(model, "Ferocity")], 5)
    T.eq(back[node(model, "Thick Hide")], 1)
    local other = code:gsub(":(%w+):(%d)", ":zzzz:%2", 1)
    local _, why = L.Import(model, (code:gsub("^(OTB1:DRUID:)%w+", "%1zzzz")))
    T.contains(why, "talents changed")
    _, why = L.Import(model, (code:gsub("DRUID", "MAGE")))
    T.contains(why, "for a mage")
    T.ok(other)
  end)

  T.it("the Talents page shows goals, cards and the trees without errors", function()
    local game, ns, L = session(20, { ["Ferocity"] = 2 })
    ns.Data:Register("talentcard", "test", {
      { id = "druid-test", class = "DRUID", goal = "leveling", name = "Test bear", source = "https://www.example.org/x", verified = false,
        points = { ["Ferocity"] = 5 } },
    })
    ns.Hub:Toggle()
    ns.Hub:ShowTab("talentlab")
    local item, card
    for _, it in ipairs(L:CardItems()) do if it.title == "Test bear" then item = it end end
    for _, c in ipairs(L.Cards("DRUID")) do if c.id == "druid-test" then card = c end end
    T.ok(item, "the card shows for Levelling")
    local hosts = {}
    for _, tg in ipairs(item.tags) do hosts[#hosts + 1] = tg[1] end
    T.contains(table.concat(hosts, " | "), "example.org")
    L:Use(card)
    T.contains(L:DiffText(), "learn: Ferocity 3")
    game:slash("talentcode")
    T.eq(#ns.Errors.list, 0)
  end)
end)

T.describe("talent cards data", function()
  T.it("every card is a whole build: at most 51 points, its order matches its points, from a cited source", function()
    local _, ns = session(60)
    local n = 0
    for _, c in ipairs(ns.Data:All("talentcard")) do
      n = n + 1
      local total = 0
      for _, v in pairs(c.points) do total = total + v end
      T.ok(total <= 51 and total > 0, c.id .. " has " .. total .. " points")
      T.contains(c.source, "http", c.id .. " cites a page")
      T.eq(c.verified, false, c.id)
      if c.order then
        local counted = {}
        for _, name in ipairs(c.order) do counted[name] = (counted[name] or 0) + 1 end
        for name, v in pairs(c.points) do T.eq(counted[name], v, c.id .. " order for " .. name) end
      end
    end
    T.ok(n >= 50, "the researched builds load: " .. n)
  end)
end)

T.describe("talent build totals", function()
  T.it("adds up crit, stats and damage from the talents' own text, by level too", function()
    local game, ns, L = session(60)
    -- entry ids in the mock are node id x 10
    game.traitDesc = {
      [2010] = "Increases your critical strike chance by 1%.",          -- Ferocity (5 ranks)
      [2030] = "Increases your Stamina by 2%.",                         -- Thick Hide
      [1010] = "Increases the damage done by your Wrath by 2%.",        -- Starlight Wrath
    }
    game.stats = { [3] = 100 }
    local S = ns.TalentStats
    local model = L:Load()
    local r = {}
    for _ = 1, 5 do L.Add(model, r, model.byName["Ferocity"].node, 60) end
    for _ = 1, 5 do L.Add(model, r, model.byName["Thick Hide"].node, 60) end
    L.Add(model, r, model.byName["Feral Aggression"].node, 60)
    local totals, skipped = S.Totals(model, r)
    T.eq(totals.crit.value, 5)
    T.eq(totals.stamina.value, 10)
    T.contains(totals.crit.from[1], "Ferocity 5/5")
    T.eq(skipped[1], "Feral Aggression", "no number in its text: listed, not guessed")
    T.contains(S.Line(totals), "+10% Stamina")
    local card = { id = "x", class = "DRUID", goal = "dps", points = { ["Ferocity"] = 5, ["Thick Hide"] = 5 } }
    local bands = S.ByLevel(model, card)
    T.eq(bands[1].level, 20)
    T.contains(bands[1].line, "Critical strike", "level 20: the first points")
    T.contains(bands[5].line, "+10% Stamina")
    T.eq(#ns.Errors.list, 0)
  end)
end)

T.describe("talent build numbers", function()
  local function caster()
    local game = mock.new({ class = "DRUID", level = 60 })
    game.traits = traits()
    game.spells = {
      { name = "Moonfire", id = 8921, desc = "Burns the enemy for 40 to 50 Arcane damage and then 120 Arcane damage over 12 sec.", cd = 0 },
      { name = "Wrath", id = 5176, desc = "Causes 100 to 120 Nature damage to the target.", cast = 2000 },
    }
    game.traitDesc = { [1010] = "Increases the damage done by your Wrath by 2%.", [2010] = "Increases your critical strike chance by 1%." }
    local ns = game:loadAddon()
    game:login()
    ns.Modules:SetEnabled("AutoCheck", false)
    return game, ns, ns.TalentLab, ns.TalentSim
  end

  T.it("one minute of Moonfire then Wrath from the tooltips, and the build's damage changes it", function()
    local game, ns, L, Sim = caster()
    local spells = { Sim.Spell("Moonfire"), Sim.Spell("Wrath") }
    T.eq(spells[2].avg, 110)
    T.eq(spells[2].cast, 2)
    T.eq(spells[1].dot, 12)
    local total, casts = Sim.Rotation(spells, 60)
    T.ok(casts["Moonfire"] >= 4 and casts["Wrath"] >= 20, "Moonfire every 12 s, Wrath between")
    T.ok(total > 0)
    local model = L:Load()
    local none = Sim.Estimate(model, {}, "ranged")
    local r = {}
    for _ = 1, 5 do L.Add(model, r, model.byName["Starlight Wrath"].node, 60) end
    local more = Sim.Estimate(model, r, "ranged")
    T.ok((more.dps or 0) > (none.dps or 0), "+10% damage from the build: " .. tostring(more.dps) .. " vs " .. tostring(none.dps))
  end)

  T.it("cards for a goal are ranked by the estimate and the best is Outrider's pick", function()
    local game, ns, L, Sim = caster()
    ns.Data:Register("talentcard", "test", {
      { id = "t-low", class = "DRUID", goal = "dps", name = "Bear stuff", source = "https://example.org/a", verified = false, points = { ["Thick Hide"] = 5 } },
      { id = "t-high", class = "DRUID", goal = "dps", name = "Wrath stuff", source = "https://example.org/b", verified = false, points = { ["Starlight Wrath"] = 5 } },
    })
    ns.HunterFight.KeySpells = nil
    Sim.KeySpells = function() return { "Moonfire", "Wrath" } end
    local list = Sim:Rank("dps", 60)
    local pos = {}
    for i, x in ipairs(list) do pos[x.card.id] = i end
    T.ok(pos["t-high"] < pos["t-low"], "the damage build ranks above the bear build")
    L:Settings().goal = "dps"
    local items = L:CardItems()
    T.eq(items[1].tags[1][1], "Outrider's pick for you")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("a training dummy fight is kept for your build and shown as measured", function()
    local game, ns, L, Sim = caster()
    ns.db.char.fights = { { id = 77, name = "Training Dummy", duration = 20, player = 2000, total = 2000 },
      { id = 78, name = "Kobold Miner", duration = 20, player = 500, total = 500 } }
    Sim:OnFightEnd()
    local dps, fights = Sim:Measured()
    T.eq(dps, 100)
    T.eq(fights, 1, "only the dummy counts")
    T.contains(Sim:Report(), "Measured on a training dummy with your build: 100")
    Sim:OnFightEnd()
    T.eq(select(2, Sim:Measured()), 1, "the same fight isn't counted twice")
  end)
end)

T.describe("follow a build card", function()
  T.it("following a card makes it the plan the talent window rings", function()
    local game, ns, L = session(20)
    ns.Data:Register("talentcard", "test", {
      { id = "druid-follow", class = "DRUID", goal = "dps", name = "Follow me", source = "https://example.org/f", verified = false,
        points = { ["Ferocity"] = 5, ["Thick Hide"] = 2 } },
    })
    L:Load()
    ns.Talents:Settings().card = "druid-follow"
    local b = ns.Talents:Build()
    T.eq(b.id, "druid-follow")
    T.eq(b.order[1][1], "Ferocity")
    T.eq(#b.order, 7)
    ns.Talents:Settings().card = nil
    T.ok(ns.Talents:Build() == nil or ns.Talents:Build().id ~= "druid-follow")
    T.eq(#ns.Errors.list, 0)
  end)
end)

T.describe("Forever's one wide tree", function()
  T.it("splits the class's three trees by position and lines their rows up (druid tree 1089)", function()
    local game = mock.new({ class = "DRUID", level = 20 })
    -- positions as the client gave them on 2026-11-23: a 600-unit grid, Restoration at x 9080-10880
    game.traits = { { treeID = 1089, unspent = 0, nodes = {
      { id = 1, name = "Improved Wrath", x = 1280, y = 2730, max = 5, rank = 0, open = true },
      { id = 2, name = "Nature's Grasp", x = 1880, y = 2730, max = 1, rank = 0, open = true },
      { id = 3, name = "Ferocity", x = 5180, y = 2730, max = 5, rank = 0, open = true },
      { id = 4, name = "Thick Hide", x = 5780, y = 3330, max = 5, rank = 0, open = true },
      { id = 5, name = "Naturalist", x = 9080, y = 2730, max = 5, rank = 0, open = true },
      { id = 6, name = "Subtlety", x = 9680, y = 3330, max = 3, rank = 0, open = true },
      { id = 7, name = "Wild Growth", x = 9680, y = 5730, max = 1, rank = 0, open = true },
    } } }
    local ns = game:loadAddon()
    game:login()
    local model = ns.TalentLab:Load()
    T.eq(#model.trees, 3)
    T.eq(model.trees[1].name, "Balance")
    T.eq(model.trees[3].name, "Restoration")
    T.eq(model.byName["Naturalist"].tree, 3)
    T.eq(model.byName["Naturalist"].column, 1)
    T.eq(model.byName["Subtlety"].column, 2)
    T.eq(model.byName["Subtlety"].tier, 2)
    T.eq(model.byName["Wild Growth"].tier, 6, "an empty row still counts")
    T.eq(model.byName["Thick Hide"].tree, 2)
  end)
end)

T.describe("talent page numbers", function()
  T.it("counts every point that differs from your build, and opens at your own level", function()
    local _, ns, L = session(10)
    T.eq(L.Changes({}, { [1] = 5, [2] = 12 }), 17, "no points yet: all 17 to learn")
    T.eq(L.Changes({ [1] = 2 }, { [1] = 5 }), 3)
    T.eq(L.Changes({ [1] = 2, [3] = 1 }, { [1] = 2 }), 1, "one to take off")
    T.eq(L:ViewLevel(), 10)
    L.viewLevel = 26
    T.eq(L:ViewLevel(), 26)
  end)
end)

T.describe("talent totals count each rank once", function()
  T.it("a text that already shows your rank isn't multiplied again, and numbers stay in their sentence", function()
    local game = mock.new({ class = "DRUID", level = 60 })
    game.traits = traits({ ["Moonglow"] = 3, ["Starlight Wrath"] = 5 })
    -- no per-rank text from the client: only the spell's own description,
    -- which shows the talent at the rank you have (Moonglow 3/3: 9%)
    game.spells = {
      { name = "Moonglow", id = 5104, desc = "Reduces the Mana cost of your Moonfire, Starfire and Wrath spells by 9%." },
      { name = "Starlight Wrath", id = 5101, desc = "Reduces the cast time of your Wrath spell by 0.5 sec. Increases damage done by 10%." },
    }
    local ns = game:loadAddon()
    game:login()
    local L, S = ns.TalentLab, ns.TalentStats
    local model = L:Load()
    local mine = L.Mine(model)
    local totals = S.Totals(model, mine)
    T.eq(totals.manacost.value, 9, "Moonglow 3/3 is 9% less mana, not 27%")
    T.eq(totals.damage.value, 10, "the damage sentence, not the cast-time number")
    T.eq(#ns.Errors.list, 0)
    local log = ""
    for _, l in ipairs(ns.Log:Tail(40)) do log = log .. ns.Log:FormatLine(l) .. "\n" end
    T.contains(log, "talent text Moonglow (3/3)")
  end)
end)
