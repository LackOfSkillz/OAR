-- Handy keys and quiet presses (Gary, 2026-11-19).
local T, mock = ...

local function rogue(level, spells, opts)
  opts = opts or {}
  opts.class, opts.level = "ROGUE", level or 10
  local game = mock.new(opts)
  game.spells = {}
  for i, n in ipairs(spells or { "Sinister Strike", "Kick" }) do game.spells[i] = { name = n, id = 800 + i } end
  local ns = game:loadAddon()
  game:login()
  return game, ns
end

T.describe("handy keys", function()
  T.it("quiet presses: a casting macro gets the clear line when it fits, other macros don't", function()
    local _, ns = rogue()
    local H = ns.HandyKeys
    T.eq(H.Final("#showtooltip\n/cast Kick"), "#showtooltip\n/cast Kick\n" .. H.QUIET_LINE)
    T.eq(H.Final("/ride me"), "/ride me", "not a casting macro")
    local long = "#showtooltip\n/cast " .. string.rep("x", 235)
    T.eq(H.Final(long), long, "never past 255 characters")
    H:Settings().quiet = false
    T.eq(H.Final("#showtooltip\n/cast Kick"), "#showtooltip\n/cast Kick", "switched off")
  end)

  T.it("a macro written from the tree carries the quiet line and still reads as installed", function()
    local game, ns = rogue(12)
    local kick
    for _, it in ipairs(ns.MacroTree:Items("pve")) do if it.id == "rogue-kick" then kick = it end end
    T.ok(ns.MacroTree:PickUp(kick))
    T.contains(game.macros[1].body, ns.HandyKeys.QUIET_LINE)
    T.eq(ns.MacroLibrary:State(kick.entry), "installed")
  end)

  T.it("nameplates switch out of combat only", function()
    local game, ns = rogue(10, nil, { cvars = { nameplateShowEnemies = "0" } })
    local ok, msg = ns.HandyKeys:Plates()
    T.ok(ok) T.contains(msg, "on")
    game.combat = true
    ok, msg = ns.HandyKeys:Plates()
    T.eq(ok, false) T.contains(msg, "fight")
  end)

  T.it("vendor needs a merchant; status says XP, bags and gold", function()
    local _, ns = rogue()
    local ok, msg = ns.HandyKeys:Vendor()
    T.eq(ok, false) T.contains(msg, "vendor first")
    ok, msg = ns.HandyKeys:Status()
    T.ok(ok) T.contains(msg, "gold this session")
  end)

  T.it("the four keys show in the keys card, not in the tree", function()
    local game, ns = rogue()
    game:slash("")
    ns.Hub.frame.tabBar:Select("macros")
    local p = ns.Hub.byId.macros.panel
    T.eq(#p.keys.handy, 4)
    local names = {}
    for _, b in ipairs(p.keys.handy) do names[#names + 1] = b.item.name end
    T.same(names, { "Nameplates", "Next Step", "Status", "Vendor" })
    T.eq(#ns.Errors.list, 0)
  end)
end)
