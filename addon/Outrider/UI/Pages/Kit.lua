-- UI/Pages/Kit.lua
-- Shared helpers for the Hub pages in UI/Pages/ (split from UI/Pages.lua, OI01-08).
-- Hub pages that turn /ride commands into controls (requirement 2026-11-13:
-- everything doable inside the Outrider window, logical and helpful). Buttons run
-- the same code as the typed command (UI.Run), so nothing behaves differently.
-- Anything without its own control is on the All commands tab in Help.
-- Home: what you need right now (nearest places, where you're headed, best
-- quests, upgrades, rare watch, errands, pet).

local _, ns = ...
local K = {}
ns.PageKit = K

function K.mod(name) return ns.Modules:Get(name) end
function K.set(name) local m = K.mod(name) return m and m:Settings() or {} end
function K.onoff(v) return v and "on" or "off" end
