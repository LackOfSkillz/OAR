-- Modules/Handoffs.lua  (P6-08 alt handoffs)
-- At login (and once more when uncached item info arrives), looks through the other
-- characters' bags and bank (Inventory, P5-01) for Bind on Equip gear this
-- character can use that scores as an upgrade (GearScore, P6-02), and says
-- so once per item: "Lumen holds a BoE cloak Torrant could wear (+6%)".
-- Inventory stores item IDs only, so a BoE item that the holder already
-- equipped once (now soulbound) can't be told apart: the note says "if it
-- is still unbound". Handoffs are kept in ns.db.global.handoffs[holder].
-- At a mailbox on the holding character, a toast offers to address the
-- mail (fills in the name only); attaching the item and Send stay Gary's.

local _, ns = ...
local C = ns.Compat
local M = ns:NewModule("Handoffs", {
  title = "Alt handoffs",
  phase = "P6",
  order = 83,
  defaults = {},
})
ns.Handoffs = M

local BOE = 2

function M:OnInitialize()
  local g = ns.db.global
  g.handoffs = ns.KeepTable(g.handoffs, "Handoffs:g.handoffs") or {}
  g.handoffTold = ns.KeepTable(g.handoffTold, "Handoffs:g.handoffTold") or {}
  self.db, self.told = g.handoffs, g.handoffTold
end

function M:OnEnable()
  self:On("PLAYER_ENTERING_WORLD", function(mod, _, login, reload) if login or reload then mod:Scan() end end)
  -- items not cached at login: one more scan when the client has loaded them
  self:On("GET_ITEM_INFO_RECEIVED", function(mod)
    if mod.missing and time() - (mod.scannedAt or 0) >= 5 then mod:Scan() end
  end)
  self:On("MAIL_SHOW", self.OnMail)
end

local function short(key) return key:match("^([^-]+)") or key end

-- Returns { {holder, itemID, name, pct} } for this character.
function M:Find()
  local out, me = {}, ns.db.key
  self.missing = false
  if not ns.GearScore then return out end
  for holder, inv in pairs(ns.db.global.inventory or {}) do
    if holder ~= me then
      for _, place in ipairs({ "bags", "bank" }) do
        for id in pairs(inv[place] or {}) do
          local info = C.ItemInfo(id)
          if not info then self.missing = true end
          if info and info.bindType == BOE and info.equipLoc and info.equipLoc ~= "" then
            local r = ns.GearScore:Compare("item:" .. id)
            if r and not r.why and r.pct >= 1 then
              out[#out + 1] = { holder = holder, itemID = id, name = info.name, pct = r.pct, where = place, observedAt = tonumber(inv.at) }
            end
          end
        end
      end
    end
  end
  table.sort(out, function(a, b) return a.pct > b.pct end)
  return out
end

function M:Scan()
  local me = ns.db.key
  self.scannedAt = time()
  local found = self:Find()
  -- forget old handoffs addressed to me, then record the current ones
  for _, list in pairs(self.db) do
    for i = #list, 1, -1 do if list[i].to == me then table.remove(list, i) end end
  end
  for _, h in ipairs(found) do
    self.db[h.holder] = self.db[h.holder] or {}
    table.insert(self.db[h.holder], { to = me, itemID = h.itemID, name = h.name, pct = h.pct })
    local key = me .. ":" .. h.itemID
    if not self.told[key] then
      self.told[key] = time()
      ns.Toast:Show({ title = "Upgrade on " .. short(h.holder),
        text = string.format("%s holds %s (BoE) that %s could wear (+%d%%), if it is still unbound.",
          short(h.holder), tostring(h.name), short(me), math.floor(h.pct + 0.5)),
        color = "good", duration = 15 })
    end
  end
  self:Info("handoff scan: %d BoE upgrades on other characters", #found)
  return found
end

function M:OnMail()
  local list = self.db[ns.db.key]
  if not list or #list == 0 then return end
  local h = list[1]
  local more = #list > 1 and string.format(" (+%d more)", #list - 1) or ""
  ns.Toast:Show({ title = "Mail " .. tostring(h.name) .. " to " .. short(h.to) .. more,
    text = "Address fills in the name; you attach the item and click Send.", color = "accent", duration = 20,
    action = { label = "Address", fn = function() M:Address(h.to) end } })
end

function M:Address(to)
  local tab = rawget(_G, "MailFrameTab2")
  if tab and tab.Click then pcall(tab.Click, tab) end
  local box = rawget(_G, "SendMailNameEditBox")
  if box and box.SetText then box:SetText(short(to)) return true end
  return false
end

function M:Activity()
  local n = #(self.db[ns.db.key] or {})
  return n > 0 and (n .. " items to mail to your other characters") or "watches alts' bags for BoE upgrades"
end
