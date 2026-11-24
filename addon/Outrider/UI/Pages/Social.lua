-- UI/Pages/Social.lua
-- Chat and Sharing pages. Split from UI/Pages.lua (OI01-08); page ids, titles and order unchanged.

local _, ns = ...
local UI, Theme = ns.UI, ns.Theme
local C = ns.Compat
local Run = UI.Run
local K = ns.PageKit
local mod, set, onoff = K.mod, K.set, K.onoff

ns.Hub:AddTab("chat", "Chat", function(p)
  local function words()
    local out = {}
    for w in pairs(set("Chat").words or {}) do out[#out + 1] = w end
    table.sort(out)
    return out
  end
  UI:FormPage(p, {
    { "header", "Chat" },
    { "check", "Hide repeated spam", function() return set("Chat").spam end, function(on) ns.Slash:Run("chat spam " .. onoff(on)) end },
    { "check", "LFG and Trade in their own tab", function() return set("Chat").lfgTab end, function(on) ns.Slash:Run("chat lfgtab " .. onoff(on)) end },
    { "check", "Time stamps", function() return (C.Call("GetCVar", "showTimestamps") or "none") ~= "none" end,
      function(on) ns.Slash:Run("chat time " .. onoff(on)) end },
    { "check", "Keep chat after a reload", function() return ns.Tweaks:Settings().history end, function(on) ns.Tweaks:Settings().history = on end },
    { "buttons", { { "Copy the last 100 chat lines", Run("copychat") }, { "Recent alerts", Run("feed") } } },
    { "header", "Highlighted words" },
    { "input", "Highlight a word", "Mystmane", "Add", function(t) ns.Slash:Run("chat word add " .. t) end },
    { "note", "Click a word to stop highlighting it." },
    { "list", 4, function(row, w) row.text:SetText(w) end, function(w) ns.Slash:Run("chat word remove " .. w) p:Refresh() end, words,
      empty = "No highlighted words yet. Your name always stands out." },
    { "header", "Spell check" },
    { "input", "Add a word", "Skyborne", "Add", function(t) ns.Slash:Run("spell add " .. t) end },
    { "input", "Remove a word", "Skyborne", "Remove", function(t) ns.Slash:Run("spell remove " .. t) end },
  })
end)

-- -------------------------------------------------------------- Sharing
-- The Outrider Discord (added 2026-11-23). The game can't open web links, so
-- the button shows the address in a box to copy (Ctrl+C) into a browser.
ns.DISCORD = "https://discord.gg/NqsBsDPqy"
function ns.ShowDiscord() UI:TextDialog("Join us on Discord", ns.DISCORD, "copy") end
ns.AddCommand("discord", "the Outrider Discord invite, to copy", function() ns.ShowDiscord() end)

ns.Hub:AddTab("sharing", "Sharing", function(p)
  UI:FormPage(p, {
    { "header", "Join us on Discord", icon = "INV_Letter_15" },
    { "note", "Talk with other Outrider players, report bugs, ask for features and hear about new versions first. Press the button, copy the link (Ctrl+C) and paste it in your web browser." },
    { "buttons", { { "Copy Discord link", function() ns.ShowDiscord() end, 170 } } },
    { "header", "Share with your guild or party" },
    { "note", "|cfff1d58eNothing is shared until you turn it on.|r  Only other Outrider users see these messages, over guild, party or whisper. Nothing leaves the game." },
    { "check", "Say hello to other Outrider users", function() return set("Comm").hello end,
      function(on) ns.Slash:Run("share hello " .. onoff(on)) end },
    { "check", "Rares: guild", function() return set("RareShare").guild end, function(on) ns.Slash:Run("share rares guild " .. onoff(on)) end },
    { "check", "Rares: party", function() return set("RareShare").party end, function(on) ns.Slash:Run("share rares party " .. onoff(on)) end },
    { "check", "Herb and ore spots: guild", function() return set("GatherShare").guild end, function(on) ns.Slash:Run("share nodes " .. onoff(on)) end },
    { "check", "My location: party", function() return set("LocationShare").on end, function(on) ns.Slash:Run("share location " .. onoff(on)) end },
    { "header", "Outrider network test" },
    { "note", "A test: can Outrider reach every Outrider user on your realm, guild or no guild? When on, Outrider joins a hidden channel (nothing shows in chat) and says a tiny hello once a minute: a version number and a random tag, nothing about you. Two players with it on, anywhere on the realm, tell us if it works. Off by default." },
    { "check", "Outrider network test", function() return set("NetTest").on end, function(on) if ns.NetTest then ns.NetTest:Set(on) end end },
    { "note", function() return ns.NetTest and ns.NetTest:Activity() or "" end },
    { "header", "Gear for alts, family and other Outrider users" },
    { "note", "When something in your bags is an upgrade for someone, Outrider says so: your alts first, then family and friends, then other Outrider users in your guild or party. At a mailbox it fills in their name." },
    { "check", "Share my gear card and see others' (guild and party)", function() return set("KitShare").share end,
      function(on) set("KitShare").share = on if on and ns.KitShare then ns.KitShare:Broadcast() end end, "off: your alts only" },
    { "input", "Add family or friend", "character name", "Add", function(t) if ns.KitShare then ns.KitShare:SetFamily(t, true) end end },
    { "input", "Remove family or friend", "character name", "Remove", function(t) if ns.KitShare then ns.KitShare:SetFamily(t, false) end end },
    { "note", function()
      local fam = set("KitShare").family or {}
      local m = mod("KitShare")
      return "Family and friends: " .. (#fam > 0 and table.concat(fam, ", ") or "none yet") .. "\n" .. (m and m.enabled and m:Activity() or "")
    end, 36 },
  })
end)

-- -------------------------------------------------------------- Settings
