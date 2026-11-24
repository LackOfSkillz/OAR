-- OI02-07: resource adapters. Each producer is independent and disables
-- gracefully; every cost and gain has a unit and evidence; no new scans.
local T, mock = ...

local function session()
  local game = mock.new()
  local ns = game:loadAddon()
  game:login()
  return game, ns, ns.NexusAdapters
end

local function withSources(ns, fixtures, fn)
  local S = ns.WhatNow.SOURCES
  local saved = {}
  for k, v in pairs(fixtures) do saved[k] = S[k] S[k] = v end
  local ok, err = pcall(fn)
  for k in pairs(fixtures) do S[k] = saved[k] end
  if not ok then error(err, 0) end
end

local EMPTY = { gear = function() return {} end, training = function() return {} end, rares = function() return {} end,
  gold = function() return {} end, gather = function() return {} end }

T.describe("nexus resource adapters", function()
  T.it("gear, training, rares, gold and gather become units-and-evidence records", function()
    local game, ns, A = session()
    local fx = {
      gear = function() return { { key = "gear:Sturdy Belt", kind = "gear", title = "Buy Sturdy Belt", benefit = 0.7, costCopper = 5400, seconds = 120, label = "community" } } end,
      training = function() return { { key = "profession:Cooking", kind = "profession", title = "Train Cooking", benefit = 0.4, costCopper = 100, label = "observed" } } end,
      rares = function() return { { key = "rare:61", kind = "rare", title = "Thuros may be up", benefit = 0.5, confidence = 0.3, label = "inferred" } } end,
      gold = function() return { { key = "gold:boar", kind = "gold", title = "Farm boars", benefit = 0.5, seconds = 1800, label = "community" } } end,
      gather = function() return { { key = "gather:1412:400:500", kind = "gather", title = "Peacebloom nearby", benefit = 0.3, seconds = 60, label = "observed" } } end,
    }
    withSources(ns, fx, function()
      local list = A:Resources(1, game.now)
      T.eq(#list, 5)
      for _, r in ipairs(list) do
        T.ok(ns.Nexus.Validate("Opportunity", r), r.opportunityId)
        T.ok(#r.evidenceIds == 1, "evidence for " .. r.opportunityId)
      end
      local byKind = {}
      for _, r in ipairs(list) do byKind[r.kind] = r end
      T.eq(byKind.gear.costCopper, 5400)
      T.eq(byKind.gear.costSeconds, 120)
      T.ok(math.abs(byKind.rare.risk - 0.7) < 1e-9, "a doubtful rare carries its risk")
    end)
  end)

  T.it("a broken or disabled producer is reported and the rest still arrive", function()
    local game, ns, A = session()
    local fx = {}
    for k, v in pairs(EMPTY) do fx[k] = v end
    fx.rares = function() error("sightings unavailable") end
    fx.gold = function() return { { key = "gold:x", kind = "gold", title = "Farm", benefit = 0.4 } } end
    ns.Modules:SetEnabled("Handoffs", false)
    withSources(ns, fx, function()
      local list, _, unavailable = A:Resources(1, game.now)
      T.eq(#list, 1)
      T.eq(unavailable[1], "rares")
    end)
    T.eq(#ns.Errors.list, 0)
  end)

  T.it("deal lots come only from the player's own searches, profit in copper", function()
    local game, ns, A = session()
    local D = ns.Modules:Get("DealDesk")
    D.enabled, D.open = true, true
    D.lots = { { id = "2318:77", itemID = 2318, costCopper = 300, profitCopper = 1200, expiresAt = game.now + 60,
      source = "verified live listing and vendor value" } }
    local sent = 0
    local env = game.env.C_AuctionHouse
    local oldSend = env.SendBrowseQuery
    env.SendBrowseQuery = function(...) sent = sent + 1 return oldSend(...) end
    withSources(ns, EMPTY, function()
      local list = A:Resources(1, game.now)
      local deal
      for _, r in ipairs(list) do if r.opportunityId:find("deals:deal", 1, true) then deal = r end end
      T.ok(deal, "the deal is an opportunity")
      T.eq(deal.costCopper, 300)
      T.eq(deal.confidence, "observed")
    end)
    env.SendBrowseQuery = oldSend
    T.eq(sent, 0, "no auction search started by the adapter")
  end)

  T.it("All() merges progression and resources with one id each", function()
    local game, ns, A = session()
    local list = A:All(1, game.now)
    local seen = {}
    for _, r in ipairs(list) do
      T.eq(seen[r.opportunityId], nil, "unique id")
      seen[r.opportunityId] = true
      T.ok(ns.Nexus.Validate("Opportunity", r))
    end
    T.eq(#ns.Errors.list, 0)
  end)
end)
