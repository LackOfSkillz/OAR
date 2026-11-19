local T, mock = ...
local function session()
  local game = mock.new({ level = 20 })
  local ns = game:loadAddon()
  game:login()
  return game, ns
end
local function plan(game, ns)
  local store = ns.db.char.xp60 or {schema=1,history={}}
  ns.db.char.xp60 = store
  store.history[#store.history + 1] = {
    sessionId="xp60-1",final=true,build=tostring(ns.build),flags={},levelEnd=20 }
  return {
    schema=4,kind="nextSessionPlan",forCharacter=ns.db.key,
    basedOnSessionId="xp60-1",sourceDigest=string.rep("a",64),
    createdAt=game.now,expiresAt=game.now+3600,gameBuild=tostring(ns.build),
    levelAtPlan=20,goal="xp",budgetSeconds=3600,
    status="insufficient_evidence",
    headline="Your next hour",summary="Keep your current route.",
    steps={},actions={},limitations={"No verified route improvement"},
  }
end
T.describe("XP60 next-login session-bound plans", function()
  T.it("accepts valid non-action plan and shows quiet UI only by request", function()
    local game, ns = session()
    local a=plan(game,ns)
    local items, why, answer = ns.Advice:Check(a)
    T.eq(why,"ok")
    T.eq(#items,0)
    T.ok(answer.nextSession)
    game.env.Outrider_Advice = a
    local p=ns.NextSession:Plan()
    T.ok(p)
    T.eq(ns.NextSession.window,nil)
    game:slash("nextsession")
    T.ok(ns.NextSession.window)
    T.ok(ns.NextSession:Feedback("already_know"))
    T.eq(ns.NextSession:Plan(),nil)
    T.eq(#ns.Errors.list,0)
  end)
  T.it("rejects mismatched sessions, stale plans, model actions and wrong character", function()
    local game, ns = session()
    local original=plan(game,ns)
    local function check(p,reason)
      local _, why = ns.Advice:Check(p)
      T.contains(why,reason)
    end
    local bad={}
    for k,v in pairs(original) do bad[k]=v end
    bad.actions={{kind="cast"}}
    check(bad,"forbidden")
    bad={}
    for k,v in pairs(original) do bad[k]=v end
    bad.basedOnSessionId="old-session"
    check(bad,"session")
    bad={}
    for k,v in pairs(original) do bad[k]=v end
    bad.expiresAt=game.now-1
    check(bad,"expired")
    bad={}
    for k,v in pairs(original) do bad[k]=v end
    bad.forCharacter="Someone-Else"
    check(bad,"another character")
    bad={}
    for k,v in pairs(original) do bad[k]=v end
    bad.steps={{candidateId="quest:invented",startsAt=0,endsAt=300,xp=100}}
    check(bad,"untrusted")
    bad={}
    for k,v in pairs(original) do bad[k]=v end
    bad.qualitativeCandidateIds={"quest:invented"}
    check(bad,"untrusted suggestion")
  end)
end)
