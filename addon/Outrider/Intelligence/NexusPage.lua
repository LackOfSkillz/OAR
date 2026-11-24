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
  for _, r in ipairs(c.ranked or {}) do scores[r.id] = r end
  local cards = {}
  for i, id in ipairs(res.plan.steps) do
    if i > 3 then break end
    local node = c.graph and c.graph.nodes[id]
    local o = node and node.opp
    if o then
      local tags = { { i == 1 and "Do this next" or ("Then " .. i), i == 1 and "good" or "plain" }, { o.confidence, "plain" }, { minutes(o.costSeconds), "plain" } }
      if o.costCopper and o.costCopper > 0 then tags[#tags + 1] = { ns.Prices and ns.Prices.Money(o.costCopper) or tostring(o.costCopper), "gold" } end
      local line = o.why or ""
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
  if left > 0 then notes[#notes + 1] = string.format("%d left out (faction, budget, prerequisites...): see Status.", left) end
  return cards, table.concat(notes, "\n")
end

ns.Hub:AddTab("nexusplan", "Plan (preview)", function(p)
  local function refresh() p:Refresh() end
  UI:FormPage(p, {
    { "header", "Plan (preview)" },
    { "note", "A plan for your goals from everything Outrider knows. 1. Switch it on. 2. Set goals on the Next steps page. 3. Press Go on the top card." },
    { "check", "Use the Nexus planner (preview)", function() return ns.NexusCore:Settings().on end,
      function(on) ns.NexusCore:Settings().on = on if on then ns.NexusCore:Replan("switched on") end refresh() end, "off by default while it is being tested" },
    { "buttons", { { "Re-plan", function() ns.NexusCore:Replan("button") refresh() end, 110 },
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
  })
end, 1.5)
