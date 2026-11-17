-- Click-to-heal bars: a bar per group member, clicks cast heals through the
-- secure template, assigned players replace the group, nothing changes in combat.
local T, mock = ...

local function sp(...)
  local out = {}
  for i, n in ipairs({ ... }) do out[i] = { name = n, id = 7000 + i } end
  return out
end

local function party(game)
  game.units = game.units or {}
  game.units.party1 = { name = "Thrall", hp = 300, hpMax = 400, player = true }
  game.units.party2 = { name = "Jaina", hp = 100, hpMax = 400, player = true }
  game.units.party3 = { name = "Rexxar", hp = 400, hpMax = 400, player = true, inRange = false }
end

local function priest()
  local game = mock.new({ class = "PRIEST", level = 20 })
  game.spells = sp("Lesser Heal", "Heal", "Renew", "Power Word: Shield", "Smite")
  party(game)
  game.inGroup = true
  local ns = game:loadAddon()
  game:login()
  ns.Modules:SetEnabled("AutoCheck", false)
  game:advance(1)
  return game, ns, ns.HealPanel
end

local function shown(H)
  local out = {}
  for _, b in ipairs(H.bars) do if b:IsShown() then out[#out + 1] = b:GetAttribute("unit") end end
  return table.concat(out, ",")
end

T.describe("click-to-heal bars", function()
  T.it("a bar per member; clicks cast Heal, Renew and Shield on that unit", function()
    local game, ns, H = priest()
    T.eq(shown(H), "player,party1,party2,party3")
    local b = H.bars[2]
    T.eq(b:GetAttribute("unit"), "party1")
    T.eq(b:GetAttribute("type1"), "spell")
    T.eq(b:GetAttribute("spell1"), "Heal", "best heal known")
    T.eq(b:GetAttribute("spell2"), "Renew")
    T.eq(b:GetAttribute("shift-spell1"), "Power Word: Shield")
    T.eq(b:GetAttribute("shift-spell2"), nil, "Flash Heal not known")
    T.ok(H.bars[3].edge:IsShown(), "Jaina is under half health")
    T.ok(not H.bars[2].edge:IsShown())
    T.eq(#game.blocked, 0)
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("assigned players replace the group; you stay unless switched off", function()
    local game, ns, H = priest()
    game:slash("heal assign jaina")
    game:advance(1)
    T.eq(shown(H), "player,party2")
    T.contains(game:chatText(), "Assigned: Jaina")
    game:slash("heal self off")
    T.eq(shown(H), "party2")
    game:slash("heal clear")
    T.eq(shown(H), "player,party1,party2,party3", "no one assigned: the whole group")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("an assigned player not in the group: the whole group shows", function()
    local game, _, H = priest()
    game:slash("heal assign Uther")
    T.eq(shown(H), "player,party1,party2,party3")
  end)

  T.it("a roster change in combat waits for the fight to end; health still updates", function()
    local game, ns, H = priest()
    game:setCombat(true)
    game.units.party4 = { name = "Varian", hp = 50, hpMax = 400, player = true }
    game:fire("GROUP_ROSTER_UPDATE")
    game:advance(1)
    T.eq(#game.blocked, 0, "no secure change in combat")
    T.eq(shown(H), "player,party1,party2,party3")
    game.units.party1.hp = 120
    game:fire("UNIT_HEALTH", "party1")
    T.eq(H.bars[2].bar:GetValue(), 120)
    T.ok(H.bars[2].edge:IsShown())
    game:setCombat(false)
    game:advance(1)
    T.eq(shown(H), "player,party1,party2,party3,party4")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("secret health goes to the bar but draws no low edge", function()
    local game, _, H = priest()
    game.units.party2.hp = { __secret = true }
    game:fire("UNIT_HEALTH", "party2")
    T.ok(not H.bars[3].edge:IsShown())
  end)

  T.it("solo: hidden; hunters get the pet's bar with Mend Pet", function()
    local game = mock.new({ class = "PRIEST", level = 20 })
    game.spells = sp("Lesser Heal")
    local ns = game:loadAddon()
    game:login()
    game:advance(1)
    T.ok(not (ns.HealPanel.panel and ns.HealPanel.panel:IsShown()))

    local hg = mock.new({ class = "HUNTER", level = 20 })
    hg.spells = sp("Mend Pet", "Auto Shot")
    hg.units = { pet = { name = "The Rake", hp = 200, hpMax = 300 } }
    hg.inGroup = true
    local hns = hg:loadAddon()
    hg:login()
    hg:advance(1)
    local H = hns.HealPanel
    T.eq(shown(H), "pet")
    T.eq(H.bars[1]:GetAttribute("spell1"), "Mend Pet")
    T.eq(#hns.Errors.list, 0)
  end)
end)
