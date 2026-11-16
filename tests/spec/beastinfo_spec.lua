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

  T.it("another hunter's pet: says what it was tamed from, logs family and speed, never names", function()
    local game, ns, M = session()
    ns.Data:Register("rare", "spec", { { npcID = 7210, name = "Swift Cat", mapID = 1412, verified = false } })
    game.units.mouseover = { guid = "Pet-0-5250-0-777-7210-0102030405", name = "Ice Ember", level = 12, family = "Cat",
      attackSpeed = 1.1, controlled = true }
    local lines = M:Lines("mouseover")
    T.eq(lines[1]:sub(1, 23), "Tamed from: Swift Cat (")
    local found
    for _, l in ipairs(lines) do if l:find("Attacks every 1.1s", 1, true) then found = true end end
    T.ok(found, "speed line")
    for _, l in ipairs(lines) do T.ok(not l:find("Rare:", 1, true), "a pet is not the rare itself") end
    local seen = ns.db.global.petsSeen
    T.eq(#seen, 1)
    T.eq(seen[1].npcID, 7210)
    T.eq(seen[1].speed, 1.1)
    for _, v in pairs(seen[1]) do T.ok(v ~= "Ice Ember", "the pet's name is not kept") end
    M:Lines("mouseover")
    T.eq(#ns.db.global.petsSeen, 1)   -- once per pet
    -- unknown creature: just its id
    game.units.mouseover.guid = "Pet-0-5250-0-777-99999-0102030406"
    T.eq(M:Lines("mouseover")[1], "Tamed from: npc 99999")
  end)

  T.it("a hunter pet's placeholder id gives no tamed-from line; your own pet is not logged", function()
    local game, ns, M = session()
    ns.Data:Register("rare", "spec", { { npcID = M.HUNTER_PET_ID, name = "Wrong", mapID = 1412, verified = false } })
    game.units.mouseover = { guid = "Pet-0-5250-0-777-" .. M.HUNTER_PET_ID .. "-0102030407", name = "Ice Ember", level = 12,
      family = "Wolf", attackSpeed = 1.1, controlled = true }
    local lines = M:Lines("mouseover")
    for _, l in ipairs(lines) do
      T.ok(not l:find("Tamed from", 1, true), "no guess")
      T.ok(not l:find("Rare:", 1, true), "not a rare")
    end
    T.eq(#ns.db.global.petsSeen, 1)
    T.eq(ns.db.global.petsSeen[1].npcID, nil)
    T.eq(ns.db.global.petsSeen[1].from, "unknown (hunter pet)")
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

  T.it("unit tooltip hooks add the beast line exactly once (shared ordered block, P7-05)", function()
    local game, ns = session()
    local unitHooks = {}
    for _, h in ipairs(game.tooltipHooks) do if h.kind == 2 then unitHooks[#unitHooks + 1] = h end end
    T.ok(#unitHooks <= 2, "lines hook + style hook at most")
    game.units.mouseover = beast(7201, 12)
    local tip = game.env.GameTooltip
    tip.GetUnit = function() return "Beast", "mouseover" end
    tip.__lines = {}
    for _, h in ipairs(unitHooks) do h.fn(tip) end
    T.eq(tip:NumLines(), 1)
    T.eq(#ns.Errors.list, 0, ns.Errors.list[1] and tostring(ns.Errors.list[1].msg or ns.Errors.list[1].message) or "")
  end)
end)
