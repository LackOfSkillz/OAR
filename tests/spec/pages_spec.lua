-- New hub pages: controls do what the typed commands do.
local T, mock = ...

local function session()
  local game = mock.new()
  local ns = game:loadAddon()
  game:login()
  ns.Modules:SetEnabled("AutoCheck", false)
  game:slash("")
  return game, ns
end

local function page(ns, id)
  ns.Hub.frame.tabBar:Select(id)
  return ns.Hub.byId[id].panel
end

-- the form's rows in order (checks and input rows), from its scroll child
local function checks(p)
  local out = {}
  for _, it in ipairs(p.form.items) do if it.box and it.label then out[#out + 1] = it end end
  return out
end

T.describe("hub pages", function()
  T.it("Hunter page toggles the Fight options like /ride fight", function()
    local _, ns = session()
    local p = page(ns, "class")
    local wing
    for _, c in ipairs(checks(p)) do if c.label:GetText() == "Wing Clip in Strike" then wing = c end end
    T.ok(wing, "Wing Clip toggle")
    local before = ns.Modules:Get("HunterFight"):Settings().wingclip
    wing:GetScript("OnClick")(wing)
    T.eq(ns.Modules:Get("HunterFight"):Settings().wingclip, not before)
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("the top bar search opens Journey with that search", function()
    local _, ns = session()
    ns.Hub:Search("innkeeper")
    T.eq(ns.Hub.current, "journey")
    T.eq(ns.Hub.byId.journey.panel.text, "innkeeper")
  end)

  T.it("All commands lists every /ride command and runs the picked one", function()
    local game, ns = session()
    local p = page(ns, "commands")
    T.eq(#p.list.items, #ns.Slash.order)
    for _, c in ipairs(p.list.items) do if c.name == "version" then p.current = c end end
    p.run:GetScript("OnClick")(p.run)
    local said
    for _, l in ipairs(game.chat) do if l:find("build", 1, true) then said = true end end
    T.ok(said, "version ran")
  end)

  T.it("Reset needs two clicks", function()
    local game, ns = session()
    page(ns, "settings")
    local reset
    for _, f in ipairs(game.frames) do
      if f.label and f.label.GetText and f.label:GetText() == "Reset this character" then reset = f end
    end
    T.ok(reset)
    ns.db.char.marker = true
    reset:GetScript("OnClick")(reset)
    T.eq(reset.label:GetText(), "Click again to reset")
    T.ok(ns.db.char.marker, "nothing reset after one click")
  end)

  T.it("Home shows its cards; the class page follows the character's class", function()
    local _, ns = session()
    local p = page(ns, "home")
    T.ok(p.near and p.quests and p.pet)
    T.eq(#ns.Errors.list, 0)
    T.eq(ns.Hub.byId.class.title, "Hunter")
    local game2 = mock.new({ class = "MAGE" })
    local ns2 = game2:loadAddon()
    game2:login()
    game2:slash("")
    T.eq(ns2.Hub.byId.class.title, "Mage")
    ns2.Hub.frame.tabBar:Select("class")
    local texts = {}
    for _, f in ipairs(game2.frames) do
      if f.__kind == "FontString" and f.__text then texts[#texts + 1] = f.__text end
    end
    local all = table.concat(texts, " | ")
    T.ok(all:find("Frost Nova", 1, true), "mage keys described")
    T.ok(not all:find("Taming", 1, true), "no hunter taming on a mage")
    T.ok(not all:find("Wing Clip", 1, true), "no hunter options on a mage")
    T.eq(#ns2.Errors.list, 0)
  end)
end)
