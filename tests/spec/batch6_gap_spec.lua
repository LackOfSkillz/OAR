-- DEEP-35-38 final ranked feature tests. No client combat automation.
local T, mock = ...
local function gameSession(opts)
  local g = mock.new(opts or { level = 20 })
  local ns = g:loadAddon()
  g:login()
  return g, ns
end

T.describe("dungeon journal", function()
  T.it("assembles bosses, loot, quests, readiness from the real data model", function()
    local g = mock.new({ level = 20 })
    g.base.Outrider_DataDungeons = { source = "test", dungeons = {
      [50] = { name = "Sample Keep", map = 1412, x = .42, y = .35,
        bosses = { { 111, "Guardian One", 22, 1, { 901 } } },
        items = { [901] = { "Blade of Testing", 20, 21, 2, 7 } } },
    } }
    rawset(g.env, "Outrider_DataDungeons", g.base.Outrider_DataDungeons)
    local ns = g:loadAddon()
    g:login()
    local D = ns.DungeonJournal
    local result = D:Details("Sample Keep")
    T.ok(result)
    T.eq(result.name, "Sample Keep")
    T.eq(result.mapID, 1412)
    T.eq(#result.bosses, 1)
    T.eq(result.bosses[1].loot[1].id, 901)
    T.eq(result.questStatus, "Questie quest data not installed")
    local rows = D:Rows(result)
    T.ok(#rows > 2)
    T.eq(D:Details("missing"), nil)
    T.eq(#ns.Errors.list, 0)
  end)
end)

T.describe("40-member healing bindings", function()
  T.it("has capacity 40, five-column layout and accepts known Ctrl and Alt spell binds", function()
    local g = mock.new({ class = "PRIEST", level = 40, inGroup = true })
    g.spells = { { name = "Heal", id = 2001 }, { name = "Renew", id = 2002 },
      { name = "Power Word: Shield", id = 2003 } }
    g.units = { player = { name = "Healer", hp = 500, hpMax = 500, player = true } }
    for i = 1, 40 do g.units["raid" .. i] = { name = "Raider" .. i,
      hp = 100, hpMax = 500, player = true } end
    g.base.IsInRaid = function() return true end
    rawset(g.env, "IsInRaid", g.base.IsInRaid)
    local ns = g:loadAddon()
    g:login()
    local H = ns.HealPanel
    T.eq(H.MAX, 40)
    T.eq(H.COLS, 5)
    local ok = H:SetBinding("ctrl-1", "Renew")
    T.ok(ok)
    T.eq(H:Settings().bindings["ctrl-1"], "Renew")
    T.no(H:SetBinding("alt-3", "Heal"))
    T.no(H:SetBinding("alt-1", "Nonexistent Spell"))
    H:Layout("test")
    T.eq(H.bars[1]:GetAttribute("ctrl-spell1"), "Renew")
    T.eq(#H:GroupUnits(), 40)
    T.eq(#H:Units(), 40)
    T.eq(#ns.Errors.list, 0)
  end)
end)

T.describe("historical auction prices", function()
  T.it("uses daily low median and coefficient of variation, not inferred sale prices", function()
    local g, ns = gameSession()
    local P = ns.Prices
    P.db[12345] = { { 10, 100 }, { 11, 400 }, { 12, 200 }, { 13, 300 } }
    local row = P:Statistics(12345)
    T.eq(row.count, 4)
    T.eq(row.median, 250)
    T.eq(row.low, 100)
    T.eq(row.high, 400)
    T.ok(row.volatility > 0)
    T.contains(row.source, "daily lowest")
    T.ok(P:ShoppingAdd("Consumables", 12345, 7, 300))
    T.eq(P:ShoppingRows("Consumables")[1].quantity, 7)
    T.no(P:ShoppingAdd("x", 100, 0))
    T.eq(#ns.Errors.list, 0)
  end)
end)

T.describe("read-only boss timelines", function()
  T.it("saves and clears notes; never invents timer if no client data", function()
    local g, ns = gameSession()
    local B = ns.BossTimeline
    T.ok(B:SetNote("The Guardian", "Hide at the pillars"))
    T.eq(B:NoteFor("The Guardian").text, "Hide at the pillars")
    local list, why = B:Events()
    T.eq(#list, 0)
    T.ok(B:SetNote("The Guardian", nil))
    T.eq(B:NoteFor("The Guardian"), nil)
    T.eq(#ns.Errors.list, 0)
  end)
  T.it("renders only readable explicit timeRemaining fields", function()
    local g, ns = gameSession()
    local B = ns.BossTimeline
    rawset(g.env, "C_EncounterTimeline", {
      GetEventList = function() return {
        { eventID = 12, name = "Firestorm", timeRemaining = 15.5 },
        { eventID = 13, name = "Frostbite" },
        { eventID = 14, timeRemaining = 9 },
      } end,
    })
    local rows = B:Events()
    T.eq(#rows, 2)
    T.eq(rows[1].remaining, 15.5)
    T.eq(rows[2].remaining, nil)
    T.eq(#ns.Errors.list, 0)
  end)
end)
