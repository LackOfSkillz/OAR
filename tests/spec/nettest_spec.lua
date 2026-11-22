-- Outrider network test (D25): a hidden channel, a tiny hello a minute, and
-- a log of what comes back. The channel functions are faked here.
local T, mock = ...

local function start()
  local game = mock.new({ class = "ROGUE", level = 14 })
  local joined = {}
  local removed = {}
  local fakes = {
    JoinTemporaryChannel = function(name) joined[name] = 5 end,
    GetChannelName = function(name) return joined[name] or 0, name end,
    LeaveChannelByName = function(name) joined[name] = nil end,
    ChatFrame_RemoveChannel = function(frame, name) removed[#removed + 1] = name end,
    ChatFrame1 = {},
  }
  for k, v in pairs(fakes) do game.base[k] = v rawset(game.env, k, v) end
  local ns = game:loadAddon()
  game:login()
  ns.Modules:SetEnabled("AutoCheck", false)
  return game, ns, ns.NetTest, joined, removed
end

T.describe("network test", function()
  T.it("is off by default and sends nothing", function()
    local game, ns = start()
    game:advance(120)
    for _, m in ipairs(game.sent or {}) do T.ok(m.channel ~= "CHANNEL", "nothing on a channel") end
    T.eq(ns.NetTest:Settings().on, false)
  end)

  T.it("switched on: joins the hidden channel, hides it, says hello once a minute, and leaves when off", function()
    local game, ns, N, joined, removed = start()
    N:Set(true)
    game:advance(4)
    T.ok(joined.OutriderNet, "joined")
    T.ok(#removed > 0, "taken out of the chat windows")
    local hellos = {}
    for _, m in ipairs(game.sent or {}) do if m.channel == "CHANNEL" then hellos[#hellos + 1] = m end end
    T.eq(#hellos, 1)
    T.eq(hellos[1].prefix, "OutriderNet")
    T.eq(hellos[1].target, "5")
    T.ok(hellos[1].msg:match("^hi|[^|]*|%x+|1$"), "only build, tag and count: " .. hellos[1].msg)
    game:advance(61)
    local n = 0
    for _, m in ipairs(game.sent or {}) do if m.channel == "CHANNEL" then n = n + 1 end end
    T.eq(n, 2, "again a minute later")
    N:Set(false)
    T.eq(joined.OutriderNet, nil, "left the channel")
  end)

  T.it("tells its own echo from another Outrider user", function()
    local game, ns, N = start()
    N:Set(true)
    game:advance(4)
    local mine = game.sent[#game.sent].msg
    game:fire("CHAT_MSG_ADDON", "OutriderNet", mine, "CHANNEL", "Me-Realm")
    game:fire("CHAT_MSG_ADDON", "OutriderNet", "hi|20261122-000000|beef|3", "CHANNEL", "Daughter-Realm")
    game:fire("CHAT_MSG_ADDON", "OutriderNet", "garbage", "CHANNEL", "Stranger-Realm")
    local r = ns.db.global.netTest
    T.eq(r.heardSelf, 1)
    T.eq(r.heardOthers, 1)
    T.eq(r.others["Daughter-Realm"], "20261122-000000")
    T.contains(N:Activity(), "other Outrider users heard: 1")
    T.eq(#ns.Errors.list, 0)
  end)
end)
