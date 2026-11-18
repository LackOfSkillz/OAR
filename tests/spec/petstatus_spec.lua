-- PetStatus (P2-09). Pet data is test data.
local T, mock = ...

local function session(opts)
  local game = mock.new(opts)
  local ns = game:loadAddon()
  game:login()
  ns.Modules:SetEnabled("AutoCheck", false)
  game.units = game.units or {}
  return game, ns, ns.Modules:Get("PetStatus")
end

local function pet(extra)
  local p = { name = "Rake", guid = "Pet-0-5250-0-777-2971-0100000001", level = 15, family = "Cat",
              hp = 300, hpMax = 400, focus = 80, focusMax = 100, xp = 500, xpMax = 2000,
              auras = { { name = "Test Buff", spellId = 1234 } } }
  for k, v in pairs(extra or {}) do p[k] = v end
  return p
end

T.describe("pet status", function()
  T.it("shows the panel with level, XP, health and focus, and a Feed button", function()
    local game, ns, M = session()
    game.units.pet = pet()
    game:fire("UNIT_PET", "player")
    game:advance(0.5)
    T.ok(M.frame:IsShown())
    T.eq(M.frame.title:GetText(), "Rake")
    T.contains(M.frame.line2:GetText(), "XP 500 / 2000 (25%)")
    T.eq(M.frame.focusVal:GetText(), "80")
    T.eq(M.frame.hpVal:GetText(), "300")
    T.eq(M.frame.hpMax:GetText(), "/ 400")
    T.eq(M.feed:GetAttribute("spell"), "Feed Pet")
    local _, rel = M.feed:GetPoint(1)
    T.eq(rel, game.env.UIParent, "Feed button never anchored to the panel")
    T.eq(game.secureAnchoredToInsecure, nil)
    T.eq(M.feed:GetFrameStrata(), "FULLSCREEN", "drawn above the panel so clicks reach it")
  end)

  T.it("logs the pet and its buffs once per pet change (auto-collected)", function()
    local game, ns, M = session()
    game.units.pet = pet()
    game:fire("UNIT_PET", "player")
    game:advance(0.5)
    local found = false
    for _, line in ipairs(ns.Log:Tail(10)) do
      if ns.Log:FormatLine(line):find("buffs=[Test Buff#1234]", 1, true) then found = true end
    end
    T.ok(found)
  end)

  T.it("hides when the pet is dismissed", function()
    local game, ns, M = session()
    game.units.pet = pet()
    game:fire("UNIT_PET", "player")
    game:advance(0.5)
    game.units.pet = nil
    game:fire("UNIT_PET", "player")
    game:advance(0.5)
    T.no(M.frame:IsShown())
    T.no(M.feed:IsShown())
  end)

  T.it("warns once when happiness drops to unhappy, if the client has happiness", function()
    local game, ns, M = session({ petHappiness = 3 })
    game.units.pet = pet()
    game:fire("UNIT_PET", "player")
    game:advance(0.5)
    game.petHappiness = 1
    game:fire("UNIT_AURA", "pet")
    game:advance(0.5)
    game:fire("UNIT_AURA", "pet")
    game:advance(0.5)
    T.eq(ns.Toast:Count(), 1)
    T.contains(ns.Toast.visible[1].title:GetText(), "unhappy")
  end)

  T.it("warns on missing or movement aspect in combat without spamming", function()
    local game, ns, M = session()
    game.units.player = { auras = {} }
    game:setCombat(true)
    T.eq(ns.Toast:Count(), 1)
    T.contains(ns.Toast.visible[1].title:GetText(), "No hunter aspect")
    game:fire("UNIT_AURA", "player")
    T.eq(ns.Toast:Count(), 1)
    game.units.player.auras = { { name = "Aspect of the Hawk" } }
    game:fire("UNIT_AURA", "player")
    game.units.player.auras = { { name = "Aspect of the Cheetah" } }
    game:fire("UNIT_AURA", "player")
    T.eq(ns.Toast:Count(), 2)
    T.contains(ns.Toast.visible[2].title:GetText(), "Cheetah")
    game:setCombat(false)
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("warns when Growl autocast remains on in a party and resets after corrected", function()
    local game, ns, M = session()
    game.petActions = { { name = "Growl", allowed = true, auto = true } }
    game.inGroup = true
    game:fire("GROUP_ROSTER_UPDATE")
    T.eq(ns.Toast:Count(), 1)
    T.contains(ns.Toast.visible[1].title:GetText(), "Growl")
    game:fire("PET_BAR_UPDATE")
    T.eq(ns.Toast:Count(), 1)
    game.petActions[1].auto = false
    game:fire("PET_BAR_UPDATE")
    game.petActions[1].auto = true
    game:fire("PET_BAR_UPDATE")
    T.eq(ns.Toast:Count(), 2)
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("does not guess Growl when pet action API has no relevant information", function()
    local game, ns, M = session({ inGroup = true })
    game:fire("GROUP_ROSTER_UPDATE")
    T.eq(ns.Toast:Count(), 0)
    T.eq(M:GrowlAutocast(), nil)
  end)

  T.it("not loaded for other classes", function()
    local _, ns = session({ class = "PRIEST" })
    T.no(ns.Modules:Get("PetStatus").enabled)
  end)
end)

T.describe("pet status secret values", function()
  T.it("secret health and focus are handed to the text as-is, never computed", function()
    local game, ns, M = session()
    local secret = { __secret = true }
    game.units.pet = pet({ hp = secret, focus = secret })
    game:fire("UNIT_PET", "player")
    game:advance(0.5)
    T.eq(M.frame.hpVal:GetText(), secret)
    T.eq(M.frame.focusVal:GetText(), secret)
    T.eq(#ns.Errors.list, 0)
  end)
end)

T.describe("pet log under event storms", function()
  T.it("the pet line is logged even when health/focus updates flood in", function()
    local game, ns, M = session()
    game.units.pet = pet()
    game:fire("UNIT_PET", "player")
    for _ = 1, 20 do game:fire("UNIT_POWER_UPDATE", "pet") game:fire("UNIT_HEALTH", "pet") end
    game:advance(0.5)
    local found = false
    for _, l in ipairs(ns.Log:Tail(15)) do if ns.Log:FormatLine(l):find("pet Rake npcID", 1, true) then found = true end end
    T.ok(found)
  end)

  T.it("Feed uses a food from your bags in one click and learns what the pet eats", function()
    local game, ns, M = session()
    game.items = { [117] = { name = "Tough Jerky", spell = "Food" }, [4536] = { name = "Shiny Red Apple", spell = "Food" },
      [1113] = { name = "Conjured Bread", spell = "Food" } }
    game.bags = { [0] = { 117, 117, 4536, 1113 } }
    game.spells = { { name = "Feed Pet", id = 6991 } }
    game.units.pet = pet()
    game:fire("UNIT_PET", "player")
    game:advance(0.5)
    T.eq(M.feed:GetAttribute("type"), "spell")
    T.eq(M.feed:GetAttribute("spell"), "Feed Pet")
    T.eq(M.feed:GetAttribute("target-item"), "Tough Jerky", "biggest stack, conjured food skipped")
    -- the pet refuses it: next click offers the apple
    M.offered = { food = "Tough Jerky", family = "Cat", t = game.clock }
    game:fire("UI_ERROR_MESSAGE", 50, "Your pet doesn't like that food.")
    game:advance(0.5)
    T.eq(M.feed:GetAttribute("target-item"), "Shiny Red Apple")
    -- it eats the apple: remembered for cats
    M.offered = { food = "Shiny Red Apple", family = "Cat", t = game.clock }
    game:fire("UNIT_SPELLCAST_SUCCEEDED", "player", "x", 6991)
    T.ok(ns.db.global.petDiet.Cat.yes["Shiny Red Apple"])
    T.ok(ns.db.global.petDiet.Cat.no["Tough Jerky"])
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("average DPS from damage and attack speed", function()
    local _, _, M = session()
    T.eq(M.DPS(10, 20, 2), 7.5)
    T.eq(M.DPS(nil, 20, 2), nil)
  end)

  T.it("the arrow folds the panel to its header and opens it again; the header stays put", function()
    local game, ns, M = session()
    game.units.pet = pet()
    game:fire("UNIT_PET", "player")
    game:advance(0.5)
    M.frame.close:GetScript("OnClick")(M.frame.close)
    T.ok(M.frame:IsShown(), "header stays on screen")
    T.eq(M.frame:GetHeight(), M.HEADER_H)
    T.ok(not M.frame.content:IsShown())
    T.ok(M.feed:IsShown(), "Feed stays usable in the header")
    T.eq(select(1, M.feed:GetPoint(1)), "TOPRIGHT", "in the header, left of the arrow")
    T.eq(M:Settings().pos.point, "TOPLEFT", "pinned by its top so the header doesn't move")
    game:fire("UNIT_HEALTH", "pet")
    game:advance(0.5)
    T.eq(M.frame:GetHeight(), M.HEADER_H, "stays folded")
    M.frame.close:GetScript("OnClick")(M.frame.close)
    T.eq(M.frame:GetHeight(), M.OPEN_H)
    T.ok(M.frame.content:IsShown())
    T.ok(M.feed:IsShown())
    M:SetPanel(false)
    T.ok(not M.frame:IsShown(), "the Hunter page switch still hides it all")
  end)

end)
