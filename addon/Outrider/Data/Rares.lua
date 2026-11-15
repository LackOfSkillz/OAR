-- Data/Rares.lua  (P2-02 rare data pack seed)
-- Rares Gary hunts first. Hard rule 7: nothing invented.
--   * Captured: entries Outrider's discovery recorded on Gary's client
--     (npcID, map, level, family, one position), read from SavedVariables
--     2026-11-15 with tools/discovered-to-pack.lua. Seen in game on Forever,
--     so verified = true only where Gary also confirmed it (Mystmane: tamed
--     2026-11-11); the others stay false until he says he saw them.
--   * Cited: npcIDs from Warcraft DB (Classic) page titles, read 2026-11-15
--     (tbc.warcraftdb.com/wowclassicdb/tbc/npc/<id>). Mulgore was redrawn on
--     Forever (C14), so no coordinates and no family until captured.
-- mapID 2521 is the zone where Gary's Skyborne characters start (captured).

local _, ns = ...
local DISC = "discovery on Gary's client 2026-11-15"
local WDB = "Warcraft DB (Classic) npc page, read 2026-11-15; Forever not checked"

ns.Data:Register("rare", "seed", {
  { npcID = 259388, name = "Mystmane", mapID = 2521, verified = true, confidence = "verified",
    level = { 13, 13 }, beast = { family = "Bear", tameable = true, attackSpeed = 2 },
    spawns = { { x = 0.598, y = 0.344 } }, shares = { 250936 },
    verifiedOn = { date = "2026-11-11", note = "Gary tamed it with the tame macro" },
    source = DISC },
  { npcID = 250936, name = "Den'dralass", mapID = 2521, verified = false,
    level = { 12, 12 }, beast = {},
    spawns = { { x = 0.599, y = 0.344 } }, shares = { 259388 },
    notes = "Seen at Mystmane's spot", source = DISC },
  { npcID = 259394, name = "Snapbeak the Quick", mapID = 2521, verified = false,
    level = { 9, 9 }, elite = true,
    spawns = { { x = 0.351, y = 0.582 } }, source = DISC },
  { npcID = 5807, name = "The Rake", mapID = 1412, verified = false, confidence = "community",
    spawns = {}, notes = "Mulgore was redrawn: no spawn points until Outrider captures it", source = WDB },
  { npcID = 3056, name = "Ghost Howl", mapID = 1412, verified = false, confidence = "community",
    spawns = {}, notes = "Mulgore was redrawn: no spawn points until Outrider captures it", source = WDB },
})
