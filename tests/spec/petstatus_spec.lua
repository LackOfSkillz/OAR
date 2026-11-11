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
    T.eq(M.feed:GetAttribute("macrotext"), "/cast Feed Pet")
    local _, rel = M.feed:GetPoint(1)
    T.eq(rel, game.env.UIParent, "Feed button never anchored to the panel")
    T.eq(game.secureAnchoredToInsecure, nil)
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
end)
