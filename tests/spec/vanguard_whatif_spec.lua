-- Vanguard VG04: hypothetical rosters, the subgroup optimizer, alternatives,
-- assignment notes, the opt-in prep protocol (consent, revoke, replay,
-- expiry) and putting sources together without hiding conflicts.
local T, mock = ...

local function set(game, k, v) game.base[k] = v rawset(game.env, k, v) end

local function start()
  local game = mock.new({ class = "HUNTER", level = 20 })
  game.units = {
    party1 = { name = "Khreos", player = true, guid = "Player-1-0000BEEF", level = 20, class = "WARRIOR", role = "TANK" },
    party2 = { name = "Mirae", player = true, guid = "Player-1-0000CAFE", level = 20, class = "PRIEST", role = "NONE" },
  }
  local ns = game:loadAddon()
  game:login()
  game.inGroup = true
  set(game, "UnitGroupRolesAssigned", function(u) local d = game.units[u] return d and d.role or "NONE" end)
  set(game, "UnitIsConnected", function() return true end)
  set(game, "UnitIsUnit", function(a, b) return a == b end)
  set(game, "NotifyInspect", function() end)
  ns.Modules:SetEnabled("Vanguard", true)
  return game, ns, ns.Vanguard, ns.VanguardModule
end

-- a raid-like hypothetical roster from a class list
local function roster(V, list)
  local r = { version = 1, members = {}, next = 1 }
  for i, c in ipairs(list) do
    r.members[i] = { id = "m" .. i, class = c[1], role = c[2], level = 60, group = c[3] or (math.floor((i - 1) / 5) + 1), locked = c[4] }
  end
  return r
end

T.describe("vanguard what-if and sharing (VG04)", function()
  T.it("hypothetical edits make new rosters and never touch the live group", function()
    local _, _, V, M = start()
    local live = M.snap
    local gen = live.generation
    local r = M:Hypo(true)
    T.eq(#r.members, 3)
    local r2 = V.WhatIf.Edit(r, "role", "m2", "HEALER")
    T.eq(r2.members[2].role, "HEALER")
    T.ok(r.members[2].role ~= "HEALER", "the original roster is unchanged")
    T.eq(live.generation, gen)
    T.eq(V.Obs.Value(live.members[3].role), nil, "the live member's role is untouched")
    local locked = V.WhatIf.Edit(r, "lock", "m1", true)
    T.eq((V.WhatIf.Edit(locked, "move", "m1", 2)), nil, "a locked member doesn't move")
    T.eq((V.WhatIf.Edit(r, "role", "m1", "WIZARD")), nil)
    T.eq((V.WhatIf.Edit(r, "add", { class = "MAGE", role = "TANK" })), nil, "a mage can't tank")
    local added = V.WhatIf.Edit(r, "add", { class = "PRIEST", role = "HEALER", level = 20 })
    T.eq(#added.members, 4)
    T.eq((V.WhatIf.Edit(added, "drop", "m1")), nil, "real members can't be dropped, only benched")
    T.eq(#V.WhatIf.Edit(added, "drop", added.members[4].id).members, 3)
    -- the page's edits go through the same rules
    M.hypoSel = "m2"
    T.ok(M:HypoEdit("nextrole"))
    T.ok(M:HypoEdit("bench"))
    T.eq(M:Hypo().members[2].bench, true)
  end)

  T.it("the optimizer matches an exhaustive search on small rosters and keeps locks", function()
    local _, _, V = start()
    local cases = {
      { { "WARRIOR", "DAMAGER" }, { "WARRIOR", "DAMAGER" }, { "ROGUE", "DAMAGER" }, { "ROGUE", "DAMAGER" }, { "ROGUE", "DAMAGER" },
        { "PRIEST", "HEALER" }, { "PRIEST", "HEALER" }, { "MAGE", "DAMAGER" }, { "MAGE", "DAMAGER" }, { "HUNTER", "DAMAGER" } },
      { { "PALADIN", "HEALER" }, { "PALADIN", "TANK" }, { "WARRIOR", "TANK" }, { "MAGE", "DAMAGER" }, { "WARLOCK", "DAMAGER" },
        { "WARRIOR", "DAMAGER" }, { "HUNTER", "DAMAGER" }, { "DRUID", "HEALER" } },
    }
    for _, list in ipairs(cases) do
      local r = roster(V, list)
      local best = V.WhatIf.Exhaustive(r)
      local out, info = V.WhatIf.Optimize(r)
      T.eq(info.after, best, "local search reaches the exhaustive best here")
      T.ok(info.after >= info.before)
      local n = {}
      for _, m in ipairs(out.members) do n[m.group] = (n[m.group] or 0) + 1 T.ok(n[m.group] <= 5, "groups of 5 at most") end
    end
    -- a lock holds
    local r = roster(V, { { "WARRIOR", "DAMAGER", 1, true }, { "WARRIOR", "DAMAGER", 1, true }, { "ROGUE", "DAMAGER", 2 }, { "PRIEST", "HEALER", 1 },
      { "PRIEST", "HEALER", 1 }, { "MAGE", "DAMAGER", 2 } })
    local out = V.WhatIf.Optimize(r)
    T.eq(out.members[1].group, 1)
    T.eq(out.members[2].group, 1)
  end)

  T.it("a 40-player optimization finishes within its bounds", function()
    local _, _, V = start()
    local classes = { { "WARRIOR", "TANK" }, { "PRIEST", "HEALER" }, { "MAGE", "DAMAGER" }, { "ROGUE", "DAMAGER" }, { "HUNTER", "DAMAGER" },
      { "PALADIN", "HEALER" }, { "DRUID", "HEALER" }, { "WARLOCK", "DAMAGER" }, { "SHAMAN", "HEALER" } }
    local list = {}
    for i = 1, 40 do list[i] = classes[(i % #classes) + 1] end
    local r = roster(V, list)
    local t0 = os.clock()
    local out, info = V.WhatIf.Optimize(r)
    T.ok(info.iterations <= V.WhatIf.MAX_ITER)
    T.ok(info.evaluations <= V.WhatIf.MAX_EVAL + 2000)
    T.eq(#out.members, 40)
    T.ok(os.clock() - t0 < 5, "terminates quickly")
    -- deterministic
    local _, again = V.WhatIf.Optimize(r)
    T.eq(again.after, info.after)
  end)

  T.it("alternatives rank single changes and never promise a clear", function()
    local _, _, V, M = start()
    local entry = V.Catalog.Find("The Deadmines")
    local alts, base, reason = V.WhatIf.Alternatives(M:Hypo(true), entry)
    T.ok(#alts > 0)
    T.eq(reason, nil)
    T.ok(alts[1].dLow >= alts[#alts].dLow, "best first")
    local found
    for _, a in ipairs(alts) do if a.label:find("add a priest healer") then found = a end end
    T.ok(found and found.dLow > 0, "adding a healer raises the low end")
    for _, a in ipairs(alts) do T.ok(not a.why:lower():find("guarantee") and not a.why:lower():find("chance")) end
    T.ok(base.score)
    -- a full group of classes with one role each: nothing to try
    local full = roster(V, { { "HUNTER", "DAMAGER" }, { "ROGUE", "DAMAGER" }, { "MAGE", "DAMAGER" }, { "WARLOCK", "DAMAGER" }, { "HUNTER", "DAMAGER" } })
    local none, _, why = V.WhatIf.Alternatives(full, entry)
    T.eq(#none, 0)
    T.ok(why and why:find("full"), tostring(why))
  end)

  T.it("assignment notes are yours, copyable, and send nothing", function()
    local _, ns, _, M = start()
    M:Settings().instance = "The Deadmines"
    ns.Slash:Run("vgnote Edwin VanCleef | Khreos | tank the boss, pull adds to the ramp")
    ns.Slash:Run("vgnote Edwin VanCleef | you | interrupt nothing, kill adds")
    local text = M:NotesText()
    T.ok(text:find("tank the boss"))
    T.eq(#M:Notes("The Deadmines")["Edwin VanCleef"], 2)
    local shown
    ns.UI.TextDialog = function(_, _, body) shown = body end
    ns.Hub:Toggle()
    ns.Hub:ShowTab("vanguard_whatif")
    ns.Hub:Refresh()
    T.eq(#(ns.Comm.outbox or {}), 0, "nothing sent")
    ns.Slash:Run("vgnote clear Edwin VanCleef")
    T.eq(M:Notes("The Deadmines")["Edwin VanCleef"], nil)
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("protocol checks: malformed, unknown fields, sizes, newer versions noted once", function()
    local _, _, V = start()
    local S = V.Share
    T.ok(S.Check({ v = 1, seq = 5, exp = 600, role = "HEALER", level = 20, ready = true, prep = { ok = 3, todo = 1, unknown = 0 } }))
    T.eq((S.Check({ v = 1, seq = 5, exp = 600, name = "Bob" })), nil, "unknown field refused")
    T.eq((S.Check({ v = 1, seq = 5, exp = 99999 })), nil, "expiry too long")
    T.eq((S.Check({ v = 1, seq = 5, exp = 60, prep = { ok = 1000, todo = 0, unknown = 0 } })), nil, "count too big")
    T.eq((S.Check({ v = 1, seq = 5, exp = 60, role = "BOSS" })), nil)
    T.eq((S.Check({ v = 1, seq = 0 / 0, exp = 60 })), nil, "NaN seq")
    T.eq((S.Check("x")), nil)
    local _, why = S.Check({ v = 2, seq = 1, exp = 60 })
    T.eq(why, "newer version")
  end)

  T.it("receive: group only, rate limit, replay refused, revoke at once, late packets can't revive, leaving forgets", function()
    local game, _, V = start()
    local S = V.Share
    local p = function(seq, extra) local t = { v = 1, seq = seq, exp = 600, role = "HEALER", prep = { ok = 4, todo = 1, unknown = 0 } }
      for k, v in pairs(extra or {}) do t[k] = v end return t end
    T.eq((S.Receive(p(10), "Mirae", "GUILD", 100)), false, "group channels only")
    T.eq((S.Receive(p(10), "Stranger", "PARTY", 100)), false, "not in your group")
    T.ok(S.Receive(p(10), "Mirae", "PARTY", 100))
    local key = next(S.peers)
    T.ok(key and key:find("Mirae"))
    T.eq((S.Receive(p(11), "Mirae", "PARTY", 101)), false, "too often")
    T.eq((S.Receive(p(9), "Mirae", "PARTY", 200)), false, "older seq: replay refused")
    -- revoke right after an update: honoured at once
    T.ok(S.Receive({ v = 1, seq = 12, revoke = true }, "Mirae", "PARTY", 102))
    T.eq(S.peers[key], nil)
    -- a late update from before the revoke can't bring it back
    T.eq((S.Receive(p(11), "Mirae", "PARTY", 300)), false)
    T.eq(S.peers[key], nil)
    -- a newer one after the revoke is fine (they turned sharing on again)
    T.ok(S.Receive(p(13), "Mirae", "PARTY", 400))
    -- expiry
    S.Sweep(400 + 601)
    T.eq(S.peers[key], nil)
    -- leaving the group forgets
    T.ok(S.Receive(p(14), "Mirae", "PARTY", 2000))
    game.units.party2 = nil
    S.Sweep(2001)
    T.eq(S.peers[key], nil)
  end)

  T.it("reconcile: yours over the game's over theirs, and conflicts are shown", function()
    local _, _, V = start()
    local r = V.Share.Reconcile("role", { { value = nil, source = "manual" }, { value = "TANK", source = "native" }, { value = "DAMAGER", source = "peer", at = 5 } })
    T.eq(r.value, "TANK")
    T.eq(r.source, "native")
    T.eq(#r.conflicts, 1)
    T.eq(r.conflicts[1].source, "peer")
    local m = V.Share.Reconcile("role", { { value = "HEALER", source = "manual" }, { value = "TANK", source = "native" } })
    T.eq(m.value, "HEALER")
    T.eq(V.Share.Reconcile("role", {}).source, "unknown")
  end)

  T.it("your sharing: off by default, preview is exactly what's sent, stop sends a revoke; others keep the native view", function()
    local game, ns, V, M = start()
    T.eq(M:Settings().sharePrep, false)
    T.eq(M:SharePayload(), nil)
    local sentKinds = {}
    ns.Comm.Send = function(_, kind, data, channel) sentKinds[#sentKinds + 1] = { kind = kind, data = data, channel = channel } return true end
    T.eq((M:SendShare()), false, "off: nothing to send")
    T.eq(#sentKinds, 0)
    M:SetSharePrep(true)
    T.eq(#sentKinds, 1)
    local d = sentKinds[1].data
    T.eq(sentKinds[1].kind, "VPREP")
    T.eq(sentKinds[1].channel, "PARTY")
    T.ok(V.Share.Check(d), "what we send passes our own checks")
    for k in pairs(d) do T.ok(({ v = 1, seq = 1, exp = 1, role = 1, level = 1, ready = 1, prep = 1 })[k], "only listed fields: " .. k) end
    T.ok(V.Share.Preview(d):find("no names"))
    M:SetSharePrep(false)
    T.eq(sentKinds[2].data.revoke, true)
    -- a member who shares: their role fills an unknown; the game's assigned role still wins, with the conflict shown
    V.Share.Receive({ v = 1, seq = 50, exp = 600, role = "HEALER" }, "Mirae", "PARTY", game.env.time())
    local mirae
    for _, m in ipairs(M.snap.members) do if m.name == "Mirae" then mirae = m end end
    local r = M:RoleOf(mirae)
    T.eq(r.value, "HEALER")
    T.eq(r.source, "peer")
    V.Share.Receive({ v = 1, seq = 60, exp = 600, role = "DAMAGER" }, "Khreos", "PARTY", game.env.time())
    local khreos
    for _, m in ipairs(M.snap.members) do if m.name == "Khreos" then khreos = m end end
    local k = M:RoleOf(khreos)
    T.eq(k.value, "TANK", "the group's role wins")
    T.ok(k.conflict and k.conflict[1].value == "DAMAGER", "but the disagreement is shown")
    -- turning Group check off forgets peers and revokes your share
    M:SetSharePrep(true)
    ns.Modules:SetEnabled("Vanguard", false)
    T.eq(next(V.Share.peers), nil)
    T.eq(sentKinds[#sentKinds].data.revoke, true)
    T.eq(#ns.Errors.list, 0)
  end)
end)
