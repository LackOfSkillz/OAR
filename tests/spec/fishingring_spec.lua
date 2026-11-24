-- Fishing ring, effective skill, fish collection, milestones, bite times and
-- cook your fish (FishFry ideas, Gary 2026-11-24). Items are test data.
local T, mock = ...

local function session(opts)
  opts = opts or {}
  opts.mapID = opts.mapID or 1412
  opts.now = opts.now or 1794700000
  local game = mock.new(opts)
  game.items = game.items or {}
  game.items[6303] = { name = "Raw Slitherskin Mackerel", quality = 1, sell = 1 }
  game.items[6289] = { name = "Raw Longjaw Mud Snapper", quality = 1, sell = 2 }
  game.items[6309] = { name = "17 Pound Catfish", quality = 1, sell = 10 }
  game.items[5523] = { name = "Small Barnacled Clam", quality = 2 }
  game.items[6529] = { name = "Shiny Bauble", quality = 1 }
  game.items[6530] = { name = "Nightcrawlers", quality = 1 }
  local ns = game:loadAddon()
  game:login()
  ns.Fishing.PoleEquipped = function() return game.pole == true end
  ns.FishingHUD.Skill = function() return game.fskill, 150, game.fmod end
  return game, ns
end

local function catch(ns, id, name, n)
  for _ = 1, n or 1 do ns.Events:Fire("OTR_LOOT", "fish", { { id = id, name = name, count = 1 } }) end
end

T.describe("fishing ring", function()
  T.it("adds up base, pole, gear and lure, and compares with the zone", function()
    local game, ns = session()
    local R = ns.FishingRing
    T.eq(R:Breakdown(), nil, "no fishing: nothing")
    T.contains(R:BreakdownLine(), "not learned")
    game.fskill, game.fmod = 80, 25
    game.pole = true
    ns.FishingGuide.FishingBonus = function(id) return id == 6256 and 5 or 0 end
    game.env.GetInventoryItemLink = function(_, slot) if slot == 16 then return "|Hitem:6256::|h[Fishing Pole]|h" end end
    local b = R:Breakdown()
    T.eq(b.base, 80)
    T.eq(b.pole, 5)
    T.eq(b.lure, 20, "the rest of the client's bonus is the lure")
    T.eq(b.total, 105)
    T.contains(R:BreakdownLine(b), "Fishing 105 = 80 base +5 pole +20 lure")
  end)

  T.it("shows with the pole: cast, lure (usual first), weapons, page; edges by state", function()
    local game, ns = session()
    local R = ns.FishingRing
    game.fskill = 60
    game.bags = { [0] = { [1] = 6529, [2] = 6530 } }
    ns.db.char.fishingWeapons = { mh = "Thunderbrew Axe" }
    R:Update()
    T.ok(not (R.frame and R.frame:IsShown()), "no pole: hidden")
    game.pole = true
    R:Update()
    T.ok(R.frame:IsShown(), "pole on: shown")
    local keys = {}
    for _, s in ipairs(R.specs) do keys[#keys + 1] = s.key end
    T.eq(table.concat(keys, ","), "cast,lure,weapons,page")
    T.eq(R.frame.cast:GetAttribute("macrotext"), "/cast Fishing")
    local lure = R.frame.buttons[1]
    T.eq(lure.spec.key, "lure")
    T.eq(lure:GetAttribute("macrotext"), "/use Nightcrawlers\n/use 16", "the best lure in the bags")
    T.eq(lure.spec.state, "off", "a lure in the bags, none on")
    -- the flyout: one button per lure; choosing one makes it the usual
    T.eq(R.frame.flyout[1].lureName, "Nightcrawlers")
    T.eq(R.frame.flyout[2].lureName, "Shiny Bauble")
    R:SetUsualLure("Shiny Bauble")
    T.eq(R.frame.buttons[1]:GetAttribute("macrotext"), "/use Shiny Bauble\n/use 16")
    T.eq(ns.Fishing:LureInBags(), "Shiny Bauble", "the fishing key uses your usual lure too")
    game.lureMs = 300000
    R:Paint()
    T.eq(R.frame.buttons[1].spec.state, "ready", "lure on: green")
    T.eq(R.frame.buttons[2]:GetAttribute("macrotext"), "/equipslot 16 Thunderbrew Axe")
    -- in combat nothing secure changes until it ends
    game.combat = true
    game.pole = false
    R:Update()
    T.eq(#game.blocked, 0, "nothing blocked")
    T.ok(R.frame:IsShown(), "still up during combat")
    game.combat = false
    game:fire("PLAYER_REGEN_ENABLED")
    T.ok(not R.frame:IsShown(), "hidden after combat")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("lays out a circle or a bar", function()
    local _, ns = session()
    local c = ns.FishingRing.Layout(4, "circle", 36, 50)
    T.eq(c[1][1], 0) T.eq(c[1][2], 50)
    T.eq(c[2][1], 50) T.eq(c[2][2], 0)
    local b = ns.FishingRing.Layout(3, "bar", 36, 50)
    T.eq(b[3][1], 120) T.eq(b[3][2], 0)
  end)
end)

T.describe("fish book", function()
  T.it("collects fish per character and account with common, rare and trophy", function()
    local _, ns = session()
    catch(ns, 6303, "Raw Slitherskin Mackerel", 3)
    catch(ns, 6309, "17 Pound Catfish")
    catch(ns, 5523, "Small Barnacled Clam")
    local col = ns.FishBook:Collection()
    T.eq(#col, 3)
    T.eq(col[1].name, "Raw Slitherskin Mackerel")
    T.eq(col[1].char, 3)
    T.eq(col[1].account, 3)
    local by = {}
    for _, f in ipairs(col) do by[f.name] = f.rarity end
    T.eq(by["17 Pound Catfish"], "Trophy")
    T.eq(by["Small Barnacled Clam"], "Rare")
    T.eq(by["Raw Slitherskin Mackerel"], "Common")
  end)

  T.it("earns milestones quietly for the backlog, then with one toast each", function()
    local game, ns = session()
    local B = ns.FishBook
    B.book.started = nil
    for k in pairs(B.book.earned) do B.book.earned[k] = nil end
    ns.FishingGuide.stats.catches = 60
    ns.FishingGuide.stats.fish[6303] = { n = 60, name = "Raw Slitherskin Mackerel" }
    local first = B:Check()
    T.eq(#first, 2, "first bite and fifty fish, quietly")
    T.ok(B.book.earned.c1 and B.book.earned.c50)
    local shown = 0
    local old = ns.Toast.Show
    ns.Toast.Show = function(...) shown = shown + 1 return old(...) end
    catch(ns, 6309, "17 Pound Catfish")
    T.ok(B.book.earned.t1, "trophy earned")
    T.eq(shown, 1, "one toast")
    local pts, n = B:Points()
    T.eq(n, 3)
    T.eq(pts, 5 + 5 + 10)
    -- share: a copy box with the line; nothing is sent
    T.contains(B:ShareText("t1"), "Trophy")
    T.ok(B:Share("t1"))
    T.eq(B:Share("c5000"), false, "not earned: nothing to share")
  end)

  T.it("tells when a fish bites from your own catches by server hour", function()
    local game, ns = session()
    local B = ns.FishBook
    local hour = 2
    game.env.GetGameTime = function() return hour, 0 end
    for _ = 1, 10 do catch(ns, 6289, "Raw Longjaw Mud Snapper") end
    for _ = 1, 10 do catch(ns, 6303, "Raw Slitherskin Mackerel") end
    hour = 14
    for _ = 1, 20 do catch(ns, 6303, "Raw Slitherskin Mackerel") end
    local r = B:BiteTimes(6289)
    T.ok(r.ready)
    T.eq(r.best.name, "Late night")
    T.eq(#r.none, 1)
    local line = B:BiteLine(6289)
    T.contains(line, "Bites most late night (0-4 server time)")
    T.contains(line, "never caught afternoon")
    T.eq(B:BiteLine(5523), nil, "never caught: nothing to say")
  end)

  T.it("lists the raw fish in your bags with what they cook into", function()
    local game, ns = session()
    game.items[2678] = { name = "Mild Spices" }
    game.bags = { [0] = { [1] = 6303 } }
    game.env.GetItemCount = function(id) return id == 6303 and 5 or 0 end
    game.env.C_Item.GetItemCount = game.env.GetItemCount
    ns.db.char.professions = { Cooking = { recipes = {
      [7752] = { name = "Slitherskin Mackerel", diff = 1, reagents = { [6303] = 1 } },
      [7753] = { name = "Spiced Mackerel", diff = 0, reagents = { [6303] = 1, [2678] = 1 } },
      [2795] = { name = "Spiced Wolf Meat", diff = 1, reagents = { [2672] = 1 } },
    } } }
    local rows = ns.FishBook:Rows()
    T.eq(#rows, 2, "only recipes that use a fish in the bags")
    T.eq(rows[1].recipe, "Slitherskin Mackerel")
    T.ok(rows[1].n > 0)
    T.eq(rows[2].n, 0)
    T.eq(rows[2].missing[1].name, "Mild Spices")
  end)

  T.it("the Fish collection and Fishing pages build without errors", function()
    local _, ns = session()
    catch(ns, 6303, "Raw Slitherskin Mackerel", 2)
    ns.Hub:Build():Show()
    ns.Hub:ShowTab("fishbook")
    T.ok(ns.Hub.byId.fishbook.panel)
    ns.Hub:ShowTab("fishing")
    T.eq(#ns.Errors.list, 0)
  end)
end)
