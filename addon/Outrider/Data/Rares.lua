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
  -- Forever spawns from conquestcapped.com/guides/wow-forever/wow-forever-the-rake/
  -- (read 2026-11-15; a Forever guide, so the redrawn map): main 51.5, 27.5
  -- west of Red Rocks, north about 49, 16; it wanders a little around each.
  { npcID = 5807, name = "The Rake", mapID = 1412, verified = false, confidence = "community",
    level = { 10, 10 }, beast = { family = "Cat", tameable = true, attackSpeed = 1.2, abilities = { "Faster Attack" } },
    spawns = { { x = 0.515, y = 0.275 }, { x = 0.49, y = 0.16 } },
    notes = "Wanders around each spot: circle the hills west of Red Rocks",
    source = "conquestcapped.com Forever guide (spawns, family, speed), read 2026-11-15; npcID: " .. WDB },
  -- Forever-only (added in 1.60.1): npcID and spot from warcraft.wiki.gg/wiki/Coldrasp,
  -- spawns, speed and abilities from conquestcapped.com/guides/wow-forever/wow-forever-coldrasp/
  -- (read 2026-11-15). Gary saw one as another hunter's pet: level 12, 1.1 s.
  { npcID = 274300, name = "Coldrasp", mapID = 1420, verified = false, confidence = "community",
    level = { 12, 12 }, beast = { family = "Wolf", tameable = true, attackSpeed = 1.5, abilities = { "Furious Howl", "Faster Attack III" } },
    spawns = { { x = 0.197, y = 0.656 }, { x = 0.195, y = 0.704 } },
    notes = "Spirit wolf skin; wanders the mushroom ring west of Deathknell; respawn hours, not minutes",
    source = "warcraft.wiki.gg (Forever) and conquestcapped.com Forever guide, read 2026-11-15" },
  { npcID = 3056, name = "Ghost Howl", mapID = 1412, verified = false, confidence = "community",
    spawns = {}, notes = "Mulgore was redrawn: no spawn points until Outrider captures it", source = WDB },
})
