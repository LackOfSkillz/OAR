-- Alt overview, lockouts and run stats (gap analysis 2026-11-17).
local T, mock = ...

local function start()
  local game = mock.new({ class = "HUNTER", level = 20 })
  local ns = game:loadAddon()
  game:login()
  return game, ns, ns.Alts
end

T.describe("alts", function()
  T.it("records this character and estimates rested XP offline", function()
    local game, ns, M = start()
    game.xp, game.xpMax, game.rested = 100, 1000, 100
    local a = M:Record("test")
    T.eq(a.level, 20)
    T.eq(math.floor(a.restedPct), 10)
    a.resting = true
    T.eq(math.floor(M.RestedNow(a, a.t + 8 * 3600)), 15)
    a.resting = false
    T.eq(math.floor(M.RestedNow(a, a.t + 8 * 3600) * 100), 1125)
    T.eq(M.RestedNow(a, a.t + 1000 * 3600), 150)
    T.eq(M:List()[1].current, true)
  end)

  T.it("counts new instances against 5 an hour; re-entering the same one doesn't count", function()
    local game, ns, M = start()
    game.now = 1000000
    game.instance = { name = "Wailing Caverns", map = 43 }
    game:fire("PLAYER_ENTERING_WORLD", false, false)
    T.eq(M:Lockouts().hour, 1)
    game.now = game.now + 600
    game.instance = nil
    game:fire("PLAYER_ENTERING_WORLD", false, false)
    T.eq(#M.runs, 1)
    -- back into the same dungeon 5 minutes later: same instance
    game.now = game.now + 300
    game.instance = { name = "Wailing Caverns", map = 43 }
    game:fire("PLAYER_ENTERING_WORLD", false, false)
    T.eq(M:Lockouts().hour, 1)
    -- after a reset it's new
    game.instance = nil
    game:fire("PLAYER_ENTERING_WORLD", false, false)
    game:fire("CHAT_MSG_SYSTEM", "Wailing Caverns has been reset.")
    game.instance = { name = "Wailing Caverns", map = 43 }
    game:fire("PLAYER_ENTERING_WORLD", false, false)
    T.eq(M:Lockouts().hour, 2)
    -- other dungeons until full
    for i = 1, 3 do
      game.instance = nil
      game:fire("PLAYER_ENTERING_WORLD", false, false)
      game.instance = { name = "Dungeon " .. i, map = 100 + i }
      game:fire("PLAYER_ENTERING_WORLD", false, false)
    end
    local lk = M:Lockouts()
    T.eq(lk.hour, 5)
    T.ok(lk.freeAt)
    game.now = game.now + 3601
    T.eq(M:Lockouts().hour, 0)
    T.eq(M:Lockouts().day, 5)
  end)

  T.it("times a run with XP (across a level-up), kills and gold", function()
    local game, ns, M = start()
    game.now = 2000000
    game.xp, game.xpMax = 900, 1000
    game.money = 1000
    game.instance = { name = "The Deadmines", map = 36 }
    game:fire("PLAYER_ENTERING_WORLD", false, false)
    game.xp = 980
    game:fire("PLAYER_XP_UPDATE", "player")
    game:fire("CHAT_MSG_COMBAT_XP_GAIN", "Defias Pirate dies, you gain 80 experience.")
    game.xp, game.xpMax = 50, 1200
    game:fire("PLAYER_XP_UPDATE", "player")
    game.money = 6000
    game.now = game.now + 1800
    game.instance = nil
    game:fire("PLAYER_ENTERING_WORLD", false, false)
    local r = M.runs[1]
    T.eq(r.name, "The Deadmines")
    T.eq(r.xp, 150)
    T.eq(r.kills, 1)
    T.eq(r.gold, 5000)
    T.contains(M.RunLine(r), "30 min")
  end)

  T.it("starts lockout expiry on leaving and supports deleting a wrong lockout", function()
    local game, ns, M = start()
    game.now = 4000000
    game.instance = { name = "Wailing Caverns", map = 43 }
    game:fire("PLAYER_ENTERING_WORLD", false, false)
    T.eq(M.inst[1].instanceID, 43)
    game.now = game.now + 1200
    game.instance = nil
    game:fire("PLAYER_ENTERING_WORLD", false, false)
    T.eq(M.inst[1].left, game.now)
    game.now = game.now + 3000
    T.eq(M:Lockouts().hour, 1, "entry expired long ago but exit is recent")
    game.now = game.now + 601
    T.eq(M:Lockouts().hour, 0)
    game:slash("runs list")
    T.contains(game:chatText(), "instance 43")
    game:slash("runs delete 1")
    T.eq(#M.inst, 0)
  end)

  T.it("the minimap button tooltip reports estimated instance lockouts", function()
    local game, ns, M = start()
    local b = ns.MinimapButton.button
    T.ok(b, "built-in minimap button available")
    b.__scripts.OnEnter(b)
    T.contains(table.concat(game.env.GameTooltip.__lines or {}, "|"), "Instances (estimated)")
  end)

  T.it("the page and command work", function()
    local game, ns, M = start()
    ns.Hub:Toggle()
    ns.Hub:ShowTab("alts")
    game:slash("runs")
    T.contains(game:chatText(), "this hour")
    T.eq(#ns.Errors.list, 0)
  end)
end)
