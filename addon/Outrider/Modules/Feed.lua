-- Modules/Feed.lua  (P7-11 notification center)
-- Every toast (rares, upgrades, rank-ready, ammo, errands, shared sightings)
-- is also kept here, newest first, the last 50 across characters
-- (ns.db.global.feed), so nothing is lost when a toast fades. Feed hub tab
-- shows them; opening it marks them read. The minimap button tooltip shows
-- the unread count. Lua errors stay in /ride errors (already counted there).

local _, ns = ...
local UI = ns.UI
local M = ns:NewModule("Feed", {
  title = "Notification feed",
  phase = "P7",
  order = 95,
  defaults = {},
})
ns.Feed = M

M.CAP = 50

function M:OnInitialize()
  local g = ns.db.global
  g.feed = ns.KeepTable(g.feed, "Feed:g.feed") or {}
  g.feedSeen = tonumber(g.feedSeen) or 0
  g.feedN = tonumber(g.feedN) or 0
  self.list = g.feed
end

function M:OnEnable() self:On("OTR_TOAST", self.Add) end

function M:Add(_, opts)
  local text = opts.text
  if type(text) ~= "string" then text = nil end
  local g = ns.db.global
  g.feedN = g.feedN + 1
  local title = tostring(opts.title or "")
  -- the same notice again within 6 hours: one entry, counted (x3), moved to the
  -- top (premium plan B13: "No hunter aspect active" was listed three times)
  for i = 1, math.min(8, #self.list) do
    local e = self.list[i]
    if e.title == title and e.text == text and time() - (e.t or 0) < 6 * 3600 then
      table.remove(self.list, i)
      e.count, e.t, e.n = (e.count or 1) + 1, time(), g.feedN
      table.insert(self.list, 1, e)
      ns.Hub:Refresh()
      return
    end
  end
  table.insert(self.list, 1, { n = g.feedN, t = time(), title = title, text = text, color = opts.color, who = ns.db.key })
  while #self.list > self.CAP do table.remove(self.list) end
  ns.Hub:Refresh()
end

function M:Unread()
  local seen, n = ns.db.global.feedSeen or 0, 0
  for _, e in ipairs(self.list) do if (e.n or 0) > seen then n = n + 1 else break end end
  return n
end

function M:MarkRead() ns.db.global.feedSeen = ns.db.global.feedN end

local function when(t)
  local d = time() - t
  if d < 60 then return "now" end
  if d < 3600 then return math.floor(d / 60) .. "m" end
  if d < 86400 then return math.floor(d / 3600) .. "h" end
  return math.floor(d / 86400) .. "d"
end
M.When = when

function M:Activity() return string.format("%d notifications kept, %d new", #self.list, self:Unread()) end

-- The feed as premium cards (2026-11-16): newest first, when, and who.
ns.Hub:AddTab("feed", "Feed", function(p)
  UI:FormPage(p, {
    { "header", "Feed" },
    { "stats", function()
      local today, rares = 0, 0
      for _, e in ipairs(M.list) do
        if time() - (e.t or 0) < 86400 then
          today = today + (e.count or 1)
          if tostring(e.title or ""):lower():find("rare") then rares = rares + 1 end
        end
      end
      return {
        { cap = "New since you looked", value = tostring(M:Unread()), color = M:Unread() > 0 and "gold" or nil },
        { cap = "Last 24 hours", value = tostring(today), note = "notifications" },
        { cap = "Rare alerts today", value = tostring(rares), color = rares > 0 and "bad" or nil },
      }
    end },
    { "header", "Latest", icon = "INV_Letter_15" },
    { "cards", function()
      local out = {}
      for i, e in ipairs(M.list) do
        if i > 20 then break end
        local tags = { { when(e.t) .. " ago", "plain" } }
        if (e.count or 1) > 1 then tags[#tags + 1] = { "x" .. e.count, "gold" } end
        if e.who and e.who ~= ns.db.key then tags[#tags + 1] = { e.who:match("^[^-]+") or e.who, "gold" } end
        local t = tostring(e.title or ""):lower()
        -- Outrider's own feed pictures when installed (feed_rare, feed_upgrade, ...), else game icons;
        -- an upgrade shows armour, a reward a chest, a tip a note (tour 2026-11-19: a blue cross and envelopes)
        local kind = t:find("rare") and "rare" or t:find("upgrade") and "upgrade" or t:find("reward") and "reward"
          or t:find("ammo") and "ammo" or t:find("errand") and "errand" or "tip"
        local icon = ({ rare = "Ability_Hunter_SniperShot", upgrade = "INV_Chest_Chain_05", reward = "INV_Box_01",
          ammo = "INV_Ammo_Arrow_02", errand = "INV_Misc_Bag_08", tip = "INV_Misc_Note_01" })[kind]
        local art = ns.Art and ns.Art:Has("feed_" .. kind) and ("feed_" .. kind) or nil
        out[#out + 1] = { art = art, pic = "Interface\\Icons\\" .. icon, title = e.title, tags = tags,
          line = e.text and e.text:gsub("\n", " ") or "" }
      end
      return out
    end },
    { "note", function() return #M.list == 0 and "No notifications yet. Every pop-up Outrider shows lands here." or "" end },
  })
  local refresh = p.Refresh
  function p:Refresh() refresh(self) M:MarkRead() end
end, 48)

ns.AddCommand("feed", "show the last 10 notifications", function()
  if #M.list == 0 then ns.Print("no notifications yet") return end
  for i = 1, math.min(10, #M.list) do
    local e = M.list[i]
    ns.Print("%s ago  %s%s", when(e.t), e.title, e.text and (": " .. e.text) or "")
  end
  M:MarkRead()
end)
