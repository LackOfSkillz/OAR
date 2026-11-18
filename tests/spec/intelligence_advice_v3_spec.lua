-- AI v3 choices must reconstruct actions from Outrider facts, not model fields.
local T, mock = ...
local function session()
  local game = mock.new()
  local ns = game:loadAddon()
  game:login()
  ns.Snapshot:Collect()
  local snap = game.env.Outrider_Snapshots[ns.db.key]
  snap.askedAt = snap.takenAt
  snap.snapshotId = "i2-test-snapshot"
  snap.modules = snap.modules or {}
  snap.modules.WhatNow = { candidates = {
    { candidateId = "quest:Coming of Age", kind = "quest", title = "Travel to trainer",
      why = "Quest from source", label = "community",
      target = { mapID = 1412, x = 0.41, y = 0.52 } },
    { candidateId = "gear:Sword", kind = "gear", title = "Review sword",
      why = "Item came from source", label = "observed", itemID = 2504 },
  }}
  return game, ns, snap
end
local function response(snap)
  return { kind = "advice", schema = 3, forCharacter = "Torrant-Forever",
    answersSnapshot = snap.askedAt, answersSnapshotId = snap.snapshotId,
    rankedCandidateIds = {"quest:Coming of Age", "gear:Sword"},
    rationaleEvidenceIds = {"local:quest:Coming of Age"}, actionRequests = {},
    headline = "Review next steps", summary = "No actions run automatically",
    limitations = {"Still a copied snapshot"} }
end
T.describe("intelligence 2.0 advice v3", function()
  T.it("reconstructs authorized actions from trusted snapshot", function()
    local _, ns, snap = session()
    local items, why, answer = ns.Advice:Check(response(snap))
    T.eq(why, "ok")
    T.eq(#items, 2)
    T.eq(items[1].action, "waypoint")
    T.eq(items[1].args.mapID, 1412)
    T.eq(items[1].args.x, 0.41)
    T.eq(items[2].action, "show_item")
    T.eq(items[2].args.itemID, 2504)
    T.eq(answer.headline, "Review next steps")
  end)
  T.it("rejects invented IDs, model actions and wrong snapshots", function()
    local _, ns, snap = session()
    local base = response(snap)
    base.rankedCandidateIds = {"quest:Fake"}
    T.no(#(ns.Advice:Check(base)) > 0)
    base = response(snap)
    base.actionRequests = {{kind="cast", spell="123"}}
    local _, why = ns.Advice:Check(base)
    T.contains(why, "forbidden")
    base = response(snap)
    base.items = {{action="waypoint", args={mapID=1,x=0.5,y=0.5}}}
    _, why = ns.Advice:Check(base)
    T.contains(why, "forbidden")
    base = response(snap)
    base.answersSnapshotId = "wrong"
    _, why = ns.Advice:Check(base)
    T.contains(why, "stale")
  end)
end)
