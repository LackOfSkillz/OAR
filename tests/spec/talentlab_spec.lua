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
    T.eq(item.tags[2][1], "example.org")
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
