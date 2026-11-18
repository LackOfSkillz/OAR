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
  g.feed = type(g.feed) == "table" and g.feed or {}
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
    { "header", "Latest", icon = "INV_Letter_15" },
    { "cards", function()
      local out = {}
      for i, e in ipairs(M.list) do
        if i > 20 then break end
        local tags = { { when(e.t) .. " ago", "plain" } }
        if (e.count or 1) > 1 then tags[#tags + 1] = { "x" .. e.count, "gold" } end
        if e.who and e.who ~= ns.db.key then tags[#tags + 1] = { e.who:match("^[^-]+") or e.who, "gold" } end
        local t = tostring(e.title or ""):lower()
        local icon = t:find("rare") and "Ability_Hunter_SniperShot" or t:find("upgrade") and "Spell_ChargePositive"
          or t:find("ammo") and "INV_Ammo_Arrow_02" or t:find("errand") and "INV_Misc_Bag_08" or "INV_Letter_15"
        out[#out + 1] = { pic = "Interface\\Icons\\" .. icon, title = e.title, tags = tags,
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
