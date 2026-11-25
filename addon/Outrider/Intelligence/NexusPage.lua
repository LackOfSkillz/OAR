-- Intelligence/NexusPage.lua  (OI02-12)
-- Home > "Plan (preview)": the Nexus plan in the existing Hub card style.
-- With the Nexus off this page only offers the switch; the rest of Outrider
-- (What now?, Radar) is unchanged. With it on:
--   * one primary card and up to two secondary cards (the plan's first steps),
--     each with Go (the step's own waypoint or page, the player's click), Pin,
--     Skip, and Why: a progressive evidence view that shows that step's
--     confidence, evidence id and score trace;
--   * alternatives (other good first steps) and what was left out, with the reason;
--   * a stale plan says so and offers Re-plan; nothing updates in combat.
-- Every opportunity appears once (the planner's steps are unique). Plain button
-- labels, each with a tooltip (UI/Tips.lua).

local _, ns = ...
local UI = ns.UI
local P = { expanded = {} }
ns.NexusPage = P

local KIND_ICON = { quest = "INV_Misc_Note_01", dungeon = "INV_Misc_Key_14", errand = "INV_Misc_Bag_08", gold = "INV_Misc_Coin_02",
  gather = "INV_Misc_Herb_07", profession = "Trade_BlackSmithing", gear = "INV_Chest_Chain", rare = "Ability_Hunter_SniperShot",
  travel = "INV_Misc_Map02", explore = "INV_Misc_Spyglass_03" }

local function minutes(s) return s and (s < 60 and "under a minute" or string.format("%d min", math.floor(s / 60 + 0.5))) or "time unknown" end

-- The cards for the current plan (pure apart from reading NexusCore): cards, note
function P.Cards(refresh)
  local N = ns.NexusCore
  local c = N and N.current
  if not (c and c.result) then return {}, "No plan yet: press Re-plan." end
  local res = c.result
  if not res.plan then return {}, "No plan: " .. tostring(res.why) .. "." end
  local scores = {}
  -- how risky each step's place is for you (Intelligence/Guardian.lua, OI04-12)
  local risk = ns.Guardian and ns.Guardian.ForPlan(c, ns.Guardian.Level()) or {}
  for _, r in ipairs(c.ranked or {}) do scores[r.id] = r end
  local cards = {}
  local gone = 0
  for i, id in ipairs(res.plan.steps) do
    if #cards >= 3 then break end
    local node = c.graph and c.graph.nodes[id]
    local o = node and node.opp
    -- a step that expired or went stale is not shown as current (OI02-R16)
    if o and not N:StillShown(id) then gone = gone + 1 o = nil end
    if o then
      local tags = { { i == 1 and "Do this next" or ("Then " .. i), i == 1 and "good" or "plain" }, { o.confidence, "plain" }, { minutes(o.costSeconds), "plain" } }
      if o.costCopper and o.costCopper > 0 then tags[#tags + 1] = { ns.Prices and ns.Prices.Money(o.costCopper) or tostring(o.costCopper), "gold" } end
      local line = o.why or ""
      local r = risk[id]
      if r and (r.level == "risky" or r.level == "dangerous") then
        tags[#tags + 1] = { r.level, "warn" }
        line = (r.safer and ("Safer: " .. tostring(r.safer.title) .. ". ") or "") .. line
      end
      if P.expanded[id] and r then line = line .. "  Risk: " .. r.level .. " (" .. tostring(r.why) .. ")." end
      if o.costUnknown then
        -- not a confirmed purchase (OI02-R13): the plan doesn't count its gold
        tags[#tags + 1] = { "price unknown", "plain" }
        line = "Check the price first: the plan doesn't count it as gold spent. " .. line
      end
      if P.expanded[id] then
        local parts = { "Evidence " .. tostring(o.evidenceIds[1]) .. " (" .. o.confidence .. ")." }
        for _, t in ipairs(scores[id] and scores[id].trace or {}) do parts[#parts + 1] = string.format("%s %+.2f", t[1], t[2]) end
        for _, n in ipairs(node.notes or {}) do parts[#parts + 1] = n end
        line = line .. "  " .. table.concat(parts, "; ")
      end
      cards[#cards + 1] = { pic = "Interface\\Icons\\" .. (KIND_ICON[o.kind] or "INV_Misc_QuestionMark"), title = o.title, tags = tags, line = line,
        actions = {
          { "Go", function() local ok, why = N:Act(id) if not ok then ns.Print("plan: %s", tostring(why)) end end, "Show the way or open the page for this step." },
          { "Why", function() P.expanded[id] = not P.expanded[id] if refresh then refresh() end end, "Show the evidence and the score behind this step." },
          { "Pin", function() N:Pin(id) N:Replan("pin") if refresh then refresh() end end, "Always do this step first." },
          { "Skip", function() N:Skip(id) N:Replan("skip") if refresh then refresh() end end, "Leave this step out of the plan." },
        } }
    end
  end
  local notes = {}
  if N:IsStale() then notes[#notes + 1] = "|cffffc84dYour character changed since this plan: press Re-plan.|r" end
  if gone > 0 then notes[#notes + 1] = string.format("%d step%s went out of date: press Re-plan.", gone, gone == 1 and "" or "s") end
  if res.closing then notes[#notes + 1] = "|cffffc84dYour session is nearly over: closing steps only.|r" end
  if res.estimateSeconds and res.estimateSeconds > 0 then
    notes[#notes + 1] = string.format("About %d min for these steps (an estimate; allow up to %d min). Travel shared between steps on one map is counted once.",
      math.floor(res.estimateSeconds / 60 + 0.5), math.floor(res.bufferedSeconds / 60 + 0.5))
  end
  if res.truncated then notes[#notes + 1] = "The search stopped at its time limit; this is the best plan found so far." end
  if #(res.alternatives or {}) > 0 then
    local alt = {}
    for _, a in ipairs(res.alternatives) do
      local n = c.graph.nodes[a.firstStep]
      alt[#alt + 1] = n and n.opp.title or a.firstStep
    end
    notes[#notes + 1] = "Other good starts: " .. table.concat(alt, ", ") .. "."
  end
  local left = 0
  for _ in pairs(c.rejected or {}) do left = left + 1 end
  if left > 0 then notes[#notes + 1] = string.format("%d left out: see below why.", left) end
  return cards, table.concat(notes, "\n")
end

-- ------------------------------------------------------------ goals (OI02-R07)
-- The player's goals as cards: raise or lower the priority, pause or resume,
-- add or clear a gold reserve, archive (kept, never deleted). Add buttons make
-- a new goal of each kind. All edits go through ns.NexusGoals (validated, and
-- they trigger a re-plan through OTR_NEXUS_GOALS_CHANGED).
P.OBJECTIVES = { { "level", "Level up", "+ Level" }, { "gold", "Make gold", "+ Gold" }, { "gear", "Better gear", "+ Gear" },
  { "professions", "Professions", "+ Professions" }, { "explore", "Explore", "+ Explore" }, { "mix", "A bit of everything", "+ Mix" } }
P.RESERVE_STEP = 10000 -- one gold
local OBJ_LABEL, OBJ_ICON = {}, { level = "Spell_Holy_SurgeOfLight", gold = "INV_Misc_Coin_02", gear = "INV_Chest_Chain",
  professions = "Trade_BlackSmithing", explore = "INV_Misc_Spyglass_03", mix = "INV_Misc_Book_09" }
for _, o in ipairs(P.OBJECTIVES) do OBJ_LABEL[o[1]] = o[2] end

function P.AddGoal(objective)
  local G = ns.NexusGoals
  local n = 0
  for _, g in ipairs(G:All()) do if g.status == "active" or g.status == "paused" then n = n + 1 end end
  return G:Create(objective, { priority = math.min(5, n + 1) })
end

function P.GoalCards(refresh)
  local G = ns.NexusGoals
  local list = {}
  for _, g in ipairs(G:All()) do if g.status == "active" or g.status == "paused" then list[#list + 1] = g end end
  table.sort(list, function(a, b)
    if a.priority ~= b.priority then return a.priority < b.priority end
    return a.goalId < b.goalId
  end)
  local function redo() if refresh then refresh() end end
  local cards = {}
  for _, g in ipairs(list) do
    local id = g.goalId
    local tags = { { "Priority " .. g.priority, g.priority == 1 and "good" or "plain" }, { g.status == "paused" and "paused" or "active", "plain" } }
    if g.reserveCopper and g.reserveCopper > 0 then
      tags[#tags + 1] = { "keep " .. (ns.Prices and ns.Prices.Money(g.reserveCopper) or tostring(g.reserveCopper)), "gold" }
    end
    cards[#cards + 1] = { pic = "Interface\\Icons\\" .. (OBJ_ICON[g.objective] or "INV_Misc_QuestionMark"),
      title = OBJ_LABEL[g.objective] or g.objective, tags = tags,
      line = g.status == "paused" and "Paused: the plan ignores it until you resume it." or "The plan works toward this; priority 1 counts most.",
      actions = {
        { "Higher", function() G:Edit(id, { priority = math.max(1, g.priority - 1) }) redo() end, "Make this goal count more (priority 1 is the most)." },
        { "Lower", function() G:Edit(id, { priority = math.min(5, g.priority + 1) }) redo() end, "Make this goal count less." },
        { g.status == "paused" and "Resume goal" or "Pause goal", function()
          if g.status == "paused" then G:Resume(id) else G:Pause(id) end redo() end,
          g.status == "paused" and "Plan for this goal again." or "Leave this goal out of the plan for now; it stays here." },
        { "Keep 1g more", function() G:Edit(id, { reserveCopper = (g.reserveCopper or 0) + P.RESERVE_STEP }) redo() end,
          "Raise the gold the plan must leave untouched by 1 gold." },
        { "No reserve", function() G:Edit(id, { reserveCopper = 0 }) redo() end, "Let the plan spend all your gold for this goal." },
        { "Archive", function() G:Delete(id) redo() end, "Put this goal away. It is kept in your saved goals, not deleted." },
      } }
  end
  return cards
end

ns.Hub:AddTab("nexusplan", "Plan (preview)", function(p)
  local function refresh() p:Refresh() end
  UI:FormPage(p, {
    { "header", "Plan (preview)" },
    { "note", "A plan for your goals from everything Outrider knows. 1. Switch it on. 2. Add your goals below. 3. Press Go on the top card." },
    { "check", "Use the Nexus planner (preview)", function() return ns.NexusCore:Settings().on end,
      function(on) ns.NexusCore:SetOn(on) refresh() end, "off by default while it is being tested" },
    { "buttons", { { "Re-plan", function() ns.NexusCore:Replan("button") refresh() end, 110 },
      { "Try another start", function() local ok, why = ns.NexusCore:UseAlternative() if not ok then ns.Print("plan: %s", why) end refresh() end, 150 },
      { "Pause", function() ns.NexusCore:Pause() refresh() end, 90 },
      { "Resume", function() ns.NexusCore:Resume() ns.NexusCore:Replan("resume") refresh() end, 90 } } },
    { "cards", function()
      if not ns.NexusCore:Settings().on then return {} end
      local cards = P.Cards(refresh)
      return cards
    end },
    { "note", function()
      if not ns.NexusCore:Settings().on then return "The planner is off. Outrider's other pages work as always." end
      local _, note = P.Cards(refresh)
      return note
    end },
    -- after time away: what changed, and your choice (OI03-13)
    { "cards", function()
      local N = ns.NexusCore
      local rec = N and N.recovery
      if not rec then return {} end
      return { { pic = "Interface\\Icons\\INV_Misc_PocketWatch_01", title = "Welcome back: your last plan",
        tags = { { rec.long and "a long time away" or "since you left", rec.long and "warn" or "plain" } },
        line = table.concat(rec.lines, "  "),
        actions = {
          { "Resume where I left off", function() ns.NexusRecovery.Resume(N) refresh() end,
            "Plan again, starting with the first step from last time that is still good." },
          { "Start a new plan", function() ns.NexusRecovery.NewPlan(N) refresh() end,
            "Forget last time's plan and plan from what is true now." },
        } } }
    end },
    -- coming up (Foresight, OI04-10/15): quiet notes, one primary and two more
    { "header", "Coming up" },
    { "cards", function() return ns.Foresight and ns.Foresight.Cards(refresh) or {} end },
    -- the session you plan for (OI04-01)
    { "header", "This session" },
    { "note", function() return "Planning for: " .. ns.NexusHorizon.Label(ns.NexusHorizon.Get(ns.NexusCore)) .. "." end },
    { "buttons", (function()
      local row = {}
      for _, m in ipairs({ { "15 min", 15 }, { "30 min", 30 }, { "1 hour", 60 }, { "2 hours", 120 }, { "No limit", false } }) do
        row[#row + 1] = { m[1], function()
          local h = ns.NexusHorizon.Get(ns.NexusCore)
          ns.NexusHorizon.Set(ns.NexusCore, { minutes = m[2] or nil, group = h.group, stopRest = h.stopRest })
          ns.NexusCore:Request("horizon") refresh()
        end, 80 }
      end
      return row
    end)(), plain = true },
    { "buttons", (function()
      local row = {}
      for _, g in ipairs({ { "Solo", "solo" }, { "With a group", "group" }, { "Either", "either" } }) do
        row[#row + 1] = { g[1], function()
          local h = ns.NexusHorizon.Get(ns.NexusCore)
          ns.NexusHorizon.Set(ns.NexusCore, { minutes = h.minutes, group = g[2], stopRest = h.stopRest })
          ns.NexusCore:Request("horizon") refresh()
        end, 110 }
      end
      row[#row + 1] = { "End at a rest point", function()
        local h = ns.NexusHorizon.Get(ns.NexusCore)
        ns.NexusHorizon.Set(ns.NexusCore, { minutes = h.minutes, group = h.group, stopRest = not h.stopRest })
        ns.NexusCore:Request("horizon") refresh()
      end, 160 }
      row[#row + 1] = { "Start a new session", function()
        if ns.NexusHorizon.StartNew(ns.NexusCore) then ns.NexusCore:Request("horizon") end
        refresh()
      end, 150 }
      return row
    end)(), plain = true },
    { "header", "My goals" },
    { "note", function()
      local n = #P.GoalCards()
      return n == 0 and "No goals yet: the plan uses your What now? goal. Add one or more:" or "Add another goal:"
    end },
    { "buttons", (function()
      local row = {}
      for _, o in ipairs(P.OBJECTIVES) do row[#row + 1] = { o[3], function() P.AddGoal(o[1]) refresh() end, 100 } end
      return row
    end)(), plain = true },
    { "cards", function() return P.GoalCards(refresh) end },
    { "header", "What's holding the plan back" },
    { "note", function()
      if not ns.NexusCore:Settings().on then return "" end
      local lines = {}
      for i, d in ipairs(ns.NexusCore:Diagnose()) do
        if i > 8 then break end
        local mark = d.kind == "error" and "|cffff7f7f" or d.kind == "limit" and "|cffffc84d" or "|cffbbbbbb"
        lines[#lines + 1] = mark .. d.text .. "|r" .. (d.remedy and ("  " .. d.remedy .. ".") or "")
      end
      return #lines > 0 and table.concat(lines, "\n") or "Nothing: the plan uses everything it found."
    end },
  })
end, 1.5)
