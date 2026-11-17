-- Player tooltips: live numbers, census memory, one gentle inspect (2026-11-17).
local T, mock = ...

local function set(game, k, v) game.base[k] = v rawset(game.env, k, v) end

local function start()
  local game = mock.new({ class = "HUNTER", level = 20 })
  game.units = { mouseover = { name = "Khreos", player = true, guid = "Player-1-0000BEEF", level = 19, hpMax = 812, attackSpeed = 2.04 } }
  local ns = game:loadAddon()
  game:login()
  set(game, "UnitIsUnit", function(a, b) return a == b end)
  set(game, "UnitPowerType", function() return 0 end)
  set(game, "UnitPowerMax", function(u) return u == "mouseover" and 640 or 0 end)
  set(game, "UnitIsPVP", function() return true end)
  game.inspects = 0
  set(game, "CanInspect", function() return true end)
  set(game, "CheckInteractDistance", function() return true end)
  set(game, "NotifyInspect", function() game.inspects = game.inspects + 1 end)
  return game, ns, ns.PlayerInfo
end

local function text(lines)
  local out = {}
  for _, l in ipairs(lines) do out[#out + 1] = l[1] end
  return table.concat(out, "\n")
end

T.describe("player tooltips", function()
  T.it("shows live numbers, PvP, professions from trade chat and your alts", function()
    local game, ns, M = start()
    local realm = ns.Census:Realm()
    local full = ns.Census.FullName("Khreos")
    realm.profs[full] = { Alchemy = 1, Herbalism = 1 }
    realm.players[full] = { l = 19, c = "HUNTER", z = "Durotar", t = game.env.time() - 2 * 86400 }
    ns.db.global.alts = ns.db.global.alts or {}
    ns.db.global.alts[full] = { level = 19 }
    local s = text(M:Lines("mouseover"))
    T.contains(s, "Attacks every 2.0s")
    T.contains(s, "812 health")
    T.contains(s, "640 mana")
    T.contains(s, "PvP flagged")
    T.contains(s, "Professions: Alchemy, Herbalism")
    T.contains(s, "Last seen 2 days ago in Durotar")
    T.contains(s, "Your alt")
    T.eq(#M:Lines("player"), 0, "never on yourself")
  end)

  T.it("inspects once, out of combat, then shows item level, weapon and talents", function()
    local game, ns, M = start()
    T.contains(text(M:Lines("mouseover")), "Looking at their gear")
    T.eq(game.inspects, 1)
    M:Lines("mouseover")
    T.eq(game.inspects, 1, "one request per player")
    set(game, "GetInventoryItemLink", function(_, slot)
      if slot == 16 then return "|cffa335ee|Hitem:100::::::::20:::::|h[Big Axe]|h|r" end
      if slot == 1 then return "|cff0070dd|Hitem:101::::::::20:::::|h[Hat]|h|r" end
    end)
    set(game, "GetDetailedItemLevelInfo", function(link) return link:find("Big Axe", 1, true) and 30 or 20 end)
    set(game, "GetNumTalentTabs", function() return 3 end)
    set(game, "GetTalentTabInfo", function(t) return ({ "Beast Mastery", "Marksmanship", "Survival" })[t], nil, ({ 5, 11, 0 })[t], "bg" end)
    game:fire("INSPECT_READY", "Player-1-0000BEEF")
    local s = text(M:Lines("mouseover"))
    T.contains(s, "Item level 25.0 average")
    T.contains(s, "Weapon: Big Axe")
    T.contains(s, "Talents: Marksmanship")
    T.contains(s, "(5/11/0)")
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("never inspects in combat or while the inspect window is open", function()
    local game, ns, M = start()
    game:setCombat(true)
    M:Lines("mouseover")
    T.eq(game.inspects, 0)
    game:setCombat(false)
    set(game, "InspectFrame", { IsShown = function() return true end })
    M:Lines("mouseover")
    T.eq(game.inspects, 0)
  end)

  T.it("talent tab info in both shapes", function()
    local game, ns, M = start()
    T.eq(select(2, M.TabInfo("Holy", 1, 21, "x")), 21)
    local name, pts = M.TabInfo(201, "Holy", "desc", 1, 21)
    T.eq(name, "Holy")
    T.eq(pts, 21)
  end)

  T.it("PvP odds: levels, health, gear, class matchup and your duel record", function()
    local game, ns, M = start()
    local even = M.Odds({ level = 20, hp = 800 }, { level = 20, hp = 800 })
    T.eq(even, 50)
    local up = M.Odds({ level = 22, hp = 900, class = "HUNTER" }, { level = 20, hp = 800, class = "WARRIOR" })
    T.ok(up > 70, "two levels up, more health, good matchup: " .. up)
    local down, why = M.Odds({ level = 20, hp = 800 }, { level = 24, hp = 1100 })
    T.ok(down < 20, "four levels down: " .. down)
    T.contains(table.concat(why, ","), "-4 levels")
    T.eq((M.Odds({ level = 20 }, { level = -1 })), 2, "skull level")
    local rec = M.Odds({ level = 20, hp = 800 }, { level = 20, hp = 800 }, { w = 0, l = 3 })
    T.ok(rec < 30, "lost three duels to them: " .. rec)
    T.eq(M.Matchup("MAGE", "WARRIOR"), 1)
    T.eq(M.Matchup("WARRIOR", "MAGE"), -1)
    T.contains(text(M:Lines("mouseover")), "PvP odds (rough): you win")
  end)

  T.it("records duels you win and lose from the system message", function()
    local game, ns, M = start()
    set(game, "DUEL_WINNER_KNOCKOUT", "%1$s has defeated %2$s in a duel")
    local me = game.env.UnitName("player")
    game:fire("CHAT_MSG_SYSTEM", me .. " has defeated Khreos in a duel")
    game:fire("CHAT_MSG_SYSTEM", "Khreos has defeated " .. me .. " in a duel")
    game:fire("CHAT_MSG_SYSTEM", "Khreos has defeated " .. me .. " in a duel")
    local r = ns.db.global.duels[ns.Census.FullName("Khreos")]
    T.eq(r.w, 1)
    T.eq(r.l, 2)
    T.contains(text(M:Lines("mouseover")), "your duels 1-2")
  end)
end)
