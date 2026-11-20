-- Combined keys (Gary, 2026-11-20: fewer macros, the best sequences combined).
local T, mock = ...

local function char(cls, level, spells, opts)
  opts = opts or {}
  opts.class, opts.level = cls, level
  local game = mock.new(opts)
  game.spells = {}
  for i, n in ipairs(spells or {}) do game.spells[i] = { name = n, id = 700 + i } end
  local ns = game:loadAddon()
  game:login()
  return game, ns
end

local function entry(ns, name)
  for _, e in ipairs(ns.ComboKeys:Entries()) do if e.name == name then return e end end
end

T.describe("combined keys", function()
  T.it("every spell in the combined keys is a real spell of that class (Data/SpellInfo.lua)", function()
    local _, ns = char("ROGUE", 10)
    for cls, def in pairs(ns.ComboKeyData) do
      if cls ~= "ALL" then
        for layer, alts in pairs(def) do
          for _, a in ipairs(alts) do
            T.ok(ns.SpellInfo[cls] and ns.SpellInfo[cls][a[1]], cls .. " " .. layer .. ": " .. a[1])
          end
        end
      end
    end
  end)

  T.it("every class at 60 with every spell and every item: each key has no errors and fits in 255", function()
    for _, cls in ipairs({ "ROGUE", "WARRIOR", "MAGE", "PRIEST", "HUNTER", "WARLOCK", "DRUID", "SHAMAN", "PALADIN" }) do
      local spells = {}
      local game0 = mock.new({ class = cls })
      local ns0 = game0:loadAddon()
      for sp in pairs(ns0.SpellInfo[cls] or {}) do spells[#spells + 1] = sp end
      local game, ns = char(cls, 60, spells)
      game.items = { [1] = { name = "Major Healthstone", sell = 1 }, [2] = { name = "Major Healing Potion", sell = 1 },
        [3] = { name = "Heavy Runecloth Bandage", sell = 1 } }
      game.bags = { [0] = { 1, 2, 3 } }
      local list = ns.ComboKeys:Entries()
      T.ok(#list >= 4, cls .. " has its keys: " .. #list)
      for _, e in ipairs(list) do
        local body = ns.MacroLibrary.Final((ns.MacroEngine.Fill(e.body, ns.MacroLibrary:Build())))
        T.eq(ns.MacroEngine.Errors(body), 0, cls .. " " .. e.name)
        T.ok(#body <= 255, cls .. " " .. e.name .. " is " .. #body)
      end
      T.eq(#ns.Errors.list, 0)
    end
  end)

  T.it("a level 10 rogue's Stop key: Kick on your focus, Shift Gouge; spells you don't know are left out", function()
    local _, ns = char("ROGUE", 12, { "Sinister Strike", "Kick", "Gouge", "Evasion", "Sprint" })
    local stop = entry(ns, "Stop")
    T.contains(stop.body, "[mod:shift] Gouge")
    T.contains(stop.body, "[nomod,@focus,harm,nodead][nomod] Kick")
    T.ok(not stop.body:find("Kidney"), "Kidney Shot not known yet")
    T.eq(stop.layers, "Press: Kick  ·  Shift: Gouge")
    local save = entry(ns, "Save")
    T.eq(save.layers, "Press: Evasion  ·  Ctrl: Sprint")
    T.eq(entry(ns, "Recover"), nil, "nothing in the bags to recover with")
  end)

  T.it("the tree hides the singles a combined key covers, and shows them on request", function()
    local game, ns = char("ROGUE", 12, { "Sinister Strike", "Kick", "Gouge", "Evasion", "Sprint" })
    local function names()
      local grid, cols = ns.MacroTree:Grid("pve")
      local set = {}
      for b = 1, #grid do for c = 1, #cols do for _, it in ipairs(grid[b][c]) do set[it.name] = true end end end
      return set, grid.hidden
    end
    local set, hidden = names()
    T.ok(not set.Kick and not set.Evasion and not set.Assist, "covered singles are hidden")
    T.ok(hidden >= 5, "hidden: " .. hidden)
    T.ok(set.Mount, "a single no key covers stays")
    ns.MacroTree:Settings().singles = true
    set = names()
    T.ok(set.Kick and set.Assist, "shown on request")
    -- the page: a row of combined keys and the switch
    ns.MacroTree:Settings().singles = false
    game:slash("")
    ns.Hub.frame.tabBar:Select("macros")
    local p = ns.Hub.byId.macros.panel
    T.ok(p.keys.combo[1]:IsShown(), "combined keys row")
    T.eq(p.singles:GetText(), "Show singles")
    p:ShowItem(p.keys.combo[1].item)
    T.contains(p.detail.text:GetText(), "Hold to change it")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("a Stop key Outrider wrote follows the spellbook; one you changed is left alone", function()
    local game, ns = char("ROGUE", 30, { "Sinister Strike", "Kick", "Gouge" })
    T.ok(ns.MacroLibrary:Install(entry(ns, "Stop")))
    game.spells[#game.spells + 1] = { name = "Kidney Shot", id = 990 }
    ns.Spellbook:Scan()
    ns.ComboKeys:Update("test")
    game:advance(1)
    T.contains(game.macros[1].body, "Kidney Shot")
    game.macros[1].body = "/cast Kick"
    game.spells[#game.spells + 1] = { name = "Blind", id = 991 }
    ns.Spellbook:Scan()
    ns.ComboKeys:Update("test")
    game:advance(1)
    T.eq(game.macros[1].body, "/cast Kick")
  end)
end)
