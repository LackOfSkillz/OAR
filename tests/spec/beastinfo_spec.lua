-- Beast tooltips (P2-10). Unit data is test data.
local T, mock = ...

local function session(opts)
  local game = mock.new(opts)
  local ns = game:loadAddon()
  game:login()
  ns.Modules:SetEnabled("AutoCheck", false)
  game.units = {}
  return game, ns, ns.Modules:Get("BeastInfo")
end

local function beast(id, level, extra)
  local u = { guid = "Creature-0-5250-0-777-" .. id .. "-00000001", name = "Beast", level = level, family = "Cat", classification = "normal" }
  for k, v in pairs(extra or {}) do u[k] = v end
  return u
end

T.describe("beast info", function()
  T.it("hunter sees family, level and tameable", function()
    local game, ns, M = session()
    game.units.mouseover = beast(7201, 12)
    T.same(M:Lines("mouseover"), { "Cat · level 12 (you 24) · tameable" })
    game.units.mouseover = beast(7201, 30)
    T.contains(M:Lines("mouseover")[1], "tameable at 30")
  end)

  T.it("other classes get no tame text; non-beasts get nothing", function()
    local game, ns, M = session({ class = "PRIEST" })
    game.units.mouseover = beast(7201, 12)
    T.same(M:Lines("mouseover"), { "Cat · level 12 (you 24)" })
    game.units.mouseover = { guid = "Creature-0-5250-0-777-7202-00000001", name = "Guard", level = 30 }
    T.same(M:Lines("mouseover"), {})
  end)

  T.it("rares get a sighting line; Shift adds unverified pack details", function()
    local game, ns, M = session()
    ns.Data:Register("rare", "spec", { { npcID = 7203, name = "R", mapID = 1, verified = false,
      beast = { family = "Cat", tameable = true, attackSpeed = 1.2, abilities = { "Claw" } } } })
    game.units.mouseover = beast(7203, 20)
    local lines = M:Lines("mouseover")
    T.eq(#lines, 2)
    T.contains(lines[2], "Rare: never seen")
    lines = M:Lines("mouseover", true)
    T.eq(#lines, 4)
    T.eq(lines[3], "Attack speed 1.20 (unverified)")
    T.eq(lines[4], "Abilities: Claw (unverified)")
  end)

  T.it("registers one unit tooltip post-hook, and the hook adds lines to GameTooltip", function()
    local game, ns = session()
    local unitHooks = {}
    for _, h in ipairs(game.tooltipHooks) do if h.kind == 2 then unitHooks[#unitHooks + 1] = h end end
    T.eq(#unitHooks, 1)
    game.tooltipHooks = unitHooks
    game.units.mouseover = beast(7201, 12)
    local tip = game.env.GameTooltip
    tip.GetUnit = function() return "Beast", "mouseover" end
    tip.__lines = {}
    game.tooltipHooks[1].fn(tip)
    T.eq(tip:NumLines(), 1)
    T.eq(#ns.Errors.list, 0)
  end)
end)
