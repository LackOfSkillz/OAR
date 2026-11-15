-- Comm layer (P8-01) and version check (P8-02).
local T, mock = ...

local function session(opts)
  local game = mock.new(opts)
  local ns = game:loadAddon()
  game:login()
  return game, ns
end

T.describe("comm", function()
  T.it("sends nothing by default", function()
    local game = session({ inGuild = true })
    T.eq(game.sent, nil)
  end)

  T.it("a long message is chunked and reassembled on the other side", function()
    local game, ns = session()
    local big = {}
    for i = 1, 60 do big[i] = "item number " .. i end
    T.ok(ns.Comm:Send("RARE", { list = big }, "GUILD"))
    T.ok(#game.sent > 1)
    local g2, ns2 = session({ name = "Other" })
    local got
    ns2.Events:On("OTR_COMM", { name = "spec" }, function(_, kind, data, sender) got = { kind, data, sender } end)
    for _, m in ipairs(game.sent) do g2:fire("CHAT_MSG_ADDON", m.prefix, m.msg, "GUILD", "Torrant") end
    T.eq(got[1], "RARE")
    T.eq(got[2].list[60], "item number 60")
    T.eq(got[3], "Torrant")
  end)

  -- helpers for the reassembly specs
  local function big(n, tag)
    local t = {}
    for i = 1, n do t[i] = tag .. " item number " .. i end
    return { list = t }
  end
  local function listener(ns)
    local got = {}
    ns.Events:On("OTR_COMM", { name = "spec" }, function(_, kind, data, sender) got[#got + 1] = { kind = kind, data = data, sender = sender } end)
    return got
  end
  local function piecesOf(ns, data)
    local g = mock.new()
    local n2 = g:loadAddon()
    g:login()
    n2.Comm:Send("RARE", data, "GUILD")
    g:advance(30)
    local out = {}
    for _, m in ipairs(g.sent) do out[#out + 1] = m.msg end
    return out
  end

  T.it("two long messages from the same sender, interleaved, both arrive intact", function()
    local g2, ns2 = session({ name = "Other" })
    local got = listener(ns2)
    local a, b = piecesOf(ns2, big(60, "A")), piecesOf(ns2, big(60, "B"))
    T.ok(#a > 2)
    T.ok(a[1]:match("^~%w%w%w~1/") ~= nil)
    for k = 1, math.max(#a, #b) do
      if a[k] then g2:fire("CHAT_MSG_ADDON", "Outrider", a[k], "GUILD", "Torrant") end
      if b[k] then g2:fire("CHAT_MSG_ADDON", "Outrider", b[k], "GUILD", "Torrant") end
    end
    T.eq(#got, 2)
    local seen = {}
    for _, m in ipairs(got) do seen[m.data.list[60]] = true end
    T.ok(seen["A item number 60"] and seen["B item number 60"])
  end)

  T.it("out of order and duplicate pieces still give one message", function()
    local g2, ns2 = session({ name = "Other" })
    local got = listener(ns2)
    local a = piecesOf(ns2, big(60, "A"))
    for k = #a, 1, -1 do
      g2:fire("CHAT_MSG_ADDON", "Outrider", a[k], "GUILD", "Torrant")
      g2:fire("CHAT_MSG_ADDON", "Outrider", a[k], "GUILD", "Torrant")
    end
    T.eq(#got, 1)
    T.eq(got[1].data.list[1], "A item number 1")
  end)

  T.it("a message missing a piece never arrives and expires", function()
    local g2, ns2 = session({ name = "Other" })
    local got = listener(ns2)
    local a = piecesOf(ns2, big(60, "A"))
    for k = 2, #a do g2:fire("CHAT_MSG_ADDON", "Outrider", a[k], "GUILD", "Torrant") end
    T.eq(#got, 0)
    T.eq(ns2.Comm.pending, 1)
    g2:advance(31)
    g2:fire("CHAT_MSG_ADDON", "Outrider", "v1|HELLO|xx", "GUILD", "Bob")
    T.eq(ns2.Comm.pending, 0)
    T.eq(next(ns2.Comm.inbox), nil)
    -- the late first piece starts a new, incomplete message: still nothing
    g2:fire("CHAT_MSG_ADDON", "Outrider", a[1], "GUILD", "Torrant")
    T.eq(#got, 0)
  end)

  T.it("malformed, oversized and flooding pieces are refused", function()
    local g2, ns2 = session({ name = "Other" })
    local got = listener(ns2)
    local bad = {
      "~abc~0/3~xx", "~abc~4/3~xx", "~abc~1/1~xx", "~abc~1/999~xx", "~abc~1/3~",
      "~ab~1/3~xx", "~abc~x/3~xx", "~" .. string.rep("x", 300), "~abc~1/2~" .. string.rep("x", 241),
    }
    for _, m in ipairs(bad) do g2:fire("CHAT_MSG_ADDON", "Outrider", m, "GUILD", "Bob") end
    T.eq(ns2.Comm.pending, 0)
    -- changing the piece count mid-message drops it
    g2:fire("CHAT_MSG_ADDON", "Outrider", "~abc~1/3~xx", "GUILD", "Bob")
    g2:fire("CHAT_MSG_ADDON", "Outrider", "~abc~2/4~xx", "GUILD", "Bob")
    T.eq(ns2.Comm.pending, 0)
    -- one sender can hold at most 4 half-received messages, everyone 32
    for k = 1, 10 do g2:fire("CHAT_MSG_ADDON", "Outrider", "~" .. ns2.Comm.Id(k) .. "~1/2~xx", "GUILD", "Bob") end
    T.eq(ns2.Comm.pending, 4)
    for s = 1, 20 do
      for k = 1, 4 do g2:fire("CHAT_MSG_ADDON", "Outrider", "~" .. ns2.Comm.Id(k) .. "~1/2~xx", "GUILD", "Spam" .. s) end
    end
    T.eq(ns2.Comm.pending, 32)
    -- a complete message whose pieces don't decode fires nothing
    g2:fire("CHAT_MSG_ADDON", "Outrider", "~zzz~1/2~v1|RARE|!!", "GUILD", "Eve")
    g2:fire("CHAT_MSG_ADDON", "Outrider", "~zzz~2/2~@@", "GUILD", "Eve")
    T.eq(#got, 0)
    T.eq(#ns2.Errors.list, 0)
  end)

  T.it("too big to send is refused; long sends are paced", function()
    local game, ns = session()
    local ok, why = ns.Comm:Send("RARE", big(2000, "X"), "GUILD")
    T.no(ok)
    T.eq(why, "too big")
    local ok2, n = ns.Comm:Send("RARE", big(150, "Y"), "GUILD")
    T.ok(ok2)
    T.ok(n > ns.Comm.BURST)
    T.eq(#game.sent, ns.Comm.BURST)
    game:advance(5)
    T.eq(#game.sent, n)
  end)

  T.it("still reads long messages from older builds (#i/n)", function()
    local g2, ns2 = session({ name = "Other" })
    local got = listener(ns2)
    local body = ns2.Comm:Encode("RARE", big(30, "L"))
    local size = 200
    local n = math.ceil(#body / size)
    T.ok(n > 1)
    for i = 1, n do
      g2:fire("CHAT_MSG_ADDON", "Outrider", body:sub((i - 1) * size + 1, i * size) .. "#" .. i .. "/" .. n, "GUILD", "Granny")
    end
    T.eq(#got, 1)
    T.eq(got[1].data.list[30], "L item number 30")
  end)

  T.it("refuses CHANNEL/SAY, ignores own and unknown or newer messages", function()
    local game, ns = session()
    T.no(ns.Comm:Send("HELLO", {}, "CHANNEL"))
    local fired = 0
    ns.Events:On("OTR_COMM", { name = "spec" }, function() fired = fired + 1 end)
    game:fire("CHAT_MSG_ADDON", "Outrider", ns.Comm:Encode("HELLO", { version = "9.9" }), "GUILD", "Torrant")
    game:fire("CHAT_MSG_ADDON", "Outrider", "v1|EVIL|xx", "GUILD", "Bob")
    game:fire("CHAT_MSG_ADDON", "Outrider", "v9|HELLO|xx", "GUILD", "Bob")
    T.eq(fired, 0)
  end)

  T.it("version hello on: sends once at login, tells you once about a newer version", function()
    local game, ns = session({ inGuild = true })
    game:slash("share hello on")
    T.eq(game.sent[1].channel, "GUILD")
    game:fire("CHAT_MSG_ADDON", "Outrider", ns.Comm:Encode("HELLO", { version = "9.0.0" }), "GUILD", "Guildie")
    game:fire("CHAT_MSG_ADDON", "Outrider", ns.Comm:Encode("HELLO", { version = "9.1.0" }), "GUILD", "Guildie2")
    local _, n = game:chatText():gsub("has a newer Outrider", "")
    T.eq(n, 1)
    T.ok(ns.Comm.Newer("0.10.0", "0.2.0"))
    T.eq(#ns.Errors.list, 0)
  end)
end)
