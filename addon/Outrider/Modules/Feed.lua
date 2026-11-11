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
  table.insert(self.list, 1, { n = g.feedN, t = time(), title = tostring(opts.title or ""), text = text, color = opts.color, who = ns.db.key })
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

ns.Hub:AddTab("feed", "Feed", function(p)
  p.list = UI:ScrollList(p, {
    rows = 14, rowHeight = 22,
    render = function(row, e)
      local who = e.who ~= ns.db.key and ("  |cff888888" .. (e.who:match("^[^-]+") or e.who) .. "|r") or ""
      row.text:SetText(string.format("|cff888888%4s|r  %s%s%s", when(e.t), e.title,
        e.text and ("  |cffbbbbbb" .. e.text:gsub("\n", " ") .. "|r") or "", who))
    end,
  })
  p.list:SetPoint("TOPLEFT", 0, 0)
  p.list:SetWidth(560)
  function p:Refresh()
    self.list:SetItems(M.list)
    M:MarkRead()
  end
end, 48)

ns.AddCommand("feed", "show the last 10 notifications", function()
  if #M.list == 0 then ns.Print("no notifications yet") return end
  for i = 1, math.min(10, #M.list) do
    local e = M.list[i]
    ns.Print("%s ago  %s%s", when(e.t), e.title, e.text and (": " .. e.text) or "")
  end
  M:MarkRead()
end)
