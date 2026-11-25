-- OI06-09..11 group protocol, planner and page; OI06-13 two-client and adversarial fixtures.
local T, mock = ...

local function client(name, mate)
  local game = mock.new({ name = name, class = "HUNTER", level = 20, inGroup = true })
  game.units = { party1 = { name = mate, player = true } }
  local ns = game:loadAddon()
  game:login()
  return game, ns, ns.Fellowship
end

local function deliver(from, to, sender, channel)
  for _, m in ipairs(from.sent or {}) do to:fire("CHAT_MSG_ADDON", m.prefix, m.msg, channel or m.channel, sender) end
  from.sent = {}
end

T.describe("group consent and protocol (OI06-09)", function()
  T.it("nothing is sent while sharing is off; turning it on sends goals, picks and ready only", function()
    local a, _, F = client("Torrant", "Oni")
    F:Share()
    T.eq(a.sent, nil)
    F:SetShare(true)
    T.ok(a.sent and #a.sent >= 1)
    local b, nsB, FB = client("Oni", "Torrant")
    deliver(a, b, "Torrant")
    T.ok(FB.peers["Torrant-Forever"], "the other client heard it")
    local flat = nsB.Serialize.Encode(FB.peers["Torrant-Forever"])
    for _, bad in ipairs({ "money", "bags", "inventory" }) do T.ok(not flat:find(bad, 1, true), bad) end
  end)

  T.it("senders outside the group, bad fields, newer versions and floods are dropped", function()
    local _, _, F = client("Oni", "Torrant")
    local good = { v = 1, goals = { "g1" }, eligible = { "quest:1" }, ready = true, level = 20 }
    T.eq(select(2, F:Receive(good, "Stranger", "PARTY", 100)), "not in your group")
    T.eq(select(2, F:Receive(good, "Torrant", "SAY", 100)), "group channels only")
    T.ok(F:Receive(good, "Torrant", "PARTY", 100))
    T.eq(select(2, F:Receive(good, "Torrant", "PARTY", 105)), "too often")
    T.eq(select(2, F:Receive({ v = 2 }, "Torrant", "PARTY", 200)), "newer version")
    T.ok(F.notes["Torrant-Forever"]:find("newer"))
    T.eq(select(2, F:Receive({ v = 1, goals = { string.rep("x", 99) } }, "Torrant", "PARTY", 300)), "bad goal or opportunity list")
    T.eq(select(2, F:Receive({ v = 1, eligible = { "a|cffff0000" } }, "Torrant", "PARTY", 400)), "bad goal or opportunity list")
    T.eq(select(2, F:Receive({ v = 1, level = 999 }, "Torrant", "PARTY", 500)), "bad level")
  end)

  T.it("revoking makes the others forget you; a roster change drops members who left", function()
    local a, _, F = client("Torrant", "Oni")
    local b, _, FB = client("Oni", "Torrant")
    F:SetShare(true)
    deliver(a, b, "Torrant")
    T.ok(FB.peers["Torrant-Forever"])
    F.lastOut = nil
    FB.lastIn = {}
    F:SetShare(false)
    deliver(a, b, "Torrant")
    T.eq(FB.peers["Torrant-Forever"], nil, "revoked")
    FB.peers["Torrant-Forever"] = { eligible = {} }
    b.units = {}
    FB:OnRoster()
    T.eq(FB.peers["Torrant-Forever"], nil, "left the group")
  end)
end)

T.describe("group planner and page (OI06-10, OI06-11)", function()
  T.it("ranks by members helped, then the least served; unshared members are never ready", function()
    local _, _, F = client("Torrant", "Oni")
    local members = { { name = "you", shared = true, eligible = { "a", "b" }, ready = true },
      { name = "Oni", shared = true, eligible = { "a", "c" }, ready = false },
      { name = "Kel", shared = true, eligible = { "b", "c" }, ready = true },
      { name = "Quiet", shared = false } }
    local p = F.GroupPlan(members, { you = 3, Oni = 0, Kel = 0 })
    T.eq(p.items[1].benefit, 2)
    T.eq(p.items[1].id, "c", "the pair whose members were served least")
    T.eq(p.gaps.Quiet, "not shared: can't tell if ready") T.eq(p.gaps.Oni, "not ready yet")
    T.eq(p.gaps.you, nil)
  end)

  T.it("the page offers share, ready and stop with tooltips; nobody is invited", function()
    local game, ns, F = client("Torrant", "Oni")
    local cards = F:Cards()
    T.eq(cards[1].title, "Not sharing")
    for _, c in ipairs(cards) do for _, a in ipairs(c.actions or {}) do T.ok(type(a[3]) == "string" and #a[3] > 0, a[1]) end end
    cards[1].actions[1][2]()
    T.ok(F:Settings().share)
    T.eq(game.invites, nil)
    T.ok(ns.Hub.byId.fellowship)
  end)
end)

T.describe("two clients and adversarial fixtures (OI06-13)", function()
  T.it("repeated and conflicting messages stay bounded; no public channel is ever used", function()
    local a, _, F = client("Torrant", "Oni")
    local b, _, FB = client("Oni", "Torrant")
    F:SetShare(true)
    for _ = 1, 20 do F:Share() end
    local sends = #(a.sent or {})
    T.ok(sends <= 2, "rate limited: " .. sends)
    deliver(a, b, "Torrant")
    for i = 1, 50 do FB:Receive({ v = 1, eligible = { "spam" .. i } }, "Torrant", "PARTY", 100000 + i * 20) end
    local n = 0
    for _ in pairs(FB.peers) do n = n + 1 end
    T.eq(n, 1, "one peer, whatever it sends")
    for _, m in ipairs(a.sent or {}) do T.ok(m.channel == "PARTY" or m.channel == "RAID", m.channel) end
    local src = io.open("addon/Outrider/Intelligence/Fellowship.lua"):read("*a"):gsub("%-%-[^\n]*", "")
    for _, ch in ipairs({ "\"SAY\"", "\"YELL\"", "\"CHANNEL\"", "InviteUnit" }) do T.ok(not src:find(ch, 1, true), ch) end
  end)
end)

T.describe("review OI-FR08..10: real goals, revoke, expiry, realms and raids", function()
  T.it("shares real Nexus goals as objective ids, never the private goalId", function()
    local a, nsA, F = client("Torrant", "Oni")
    T.ok(nsA.NexusGoals:Create("level", { target = 30 }))
    F:Settings().share = true
    local p = F:Payload()
    T.eq(p.goals[1], "level:30")
    for _, id in ipairs(p.goals) do T.ok(not id:find("goal:", 1, true), id) end
    T.ok(F.Check(p), "what we send passes our own checks")
    T.ok(a)
  end)

  T.it("a revoke inside the rate window is still honoured", function()
    local _, _, F = client("Oni", "Torrant")
    local good = { v = 1, goals = { "level:30" }, eligible = { "quest:1" }, ready = true, level = 20 }
    T.ok(F:Receive(good, "Torrant", "PARTY", 1000))
    T.ok(F.peers["Torrant-Forever"])
    T.ok(F:Receive({ v = 1, revoke = true }, "Torrant", "PARTY", 1003), "3 s later")
    T.eq(F.peers["Torrant-Forever"], nil, "forgotten")
    T.eq(select(2, F:Receive({ v = 1, revoke = true }, "Stranger", "PARTY", 1004)), "not in your group")
  end)

  T.it("peers expire after TTL seconds without news", function()
    local _, _, F = client("Oni", "Torrant")
    T.ok(F:Receive({ v = 1, eligible = { "a" } }, "Torrant", "PARTY", 1000))
    F:Expire(1000 + F.TTL - 1)
    T.ok(F.peers["Torrant-Forever"])
    F:Expire(1000 + F.TTL + 1)
    T.eq(F.peers["Torrant-Forever"], nil)
  end)

  T.it("same name on two realms stays two members; unshared raid members are listed", function()
    local game = mock.new({ name = "Oni", class = "HUNTER", level = 20, inGroup = true, inRaid = true })
    game.units = { raid1 = { name = "Oni" }, raid2 = { name = "Torrant" }, raid3 = { name = "Torrant", realm = "Other Realm" },
      raid12 = { name = "Quiet" } }
    local ns = game:loadAddon()
    game:login()
    local F = ns.Fellowship
    T.ok(F:Receive({ v = 1, eligible = { "a" } }, "Torrant", "RAID", 100))
    T.ok(F:Receive({ v = 1, eligible = { "b" } }, "Torrant-OtherRealm", "RAID", 100))
    T.ok(F.peers["Torrant-Forever"] and F.peers["Torrant-OtherRealm"], "two peers")
    local names = {}
    for _, m in ipairs(F:Members(100)) do names[m.name] = m.shared end
    T.eq(names.Torrant, true)
    T.eq(names["Torrant-OtherRealm"], true)
    T.eq(names.Quiet, false, "raid member 12 who hasn't shared")
    T.eq(names.Oni, nil, "you are listed once, as you")
  end)
end)
