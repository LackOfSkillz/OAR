# Data schemas

Packs register with `ns.Data:Register(kind, packName, entries)`. Every kind also accepts two optional provenance fields: `confidence` (`"verified"` seen in game on Forever, `"community"` reported by a cited source, `"inferred"` derived by us, `"unknown"`) and `verifiedOn = { build = "70862", date = "2026-11-14", note = "..." }`. `verified = true` requires `confidence` to be absent or `"verified"`. Required fields (checked by `Data.SCHEMAS` in `Data/Registry.lua`) are marked **req**. Everything else is optional. Coordinates are map fractions 0..1 for the given `mapID` (the uiMapID from `C_Map.GetBestMapForUnit`). **The values in the examples below are placeholders, not real game data.**

## rare

```lua
{
  npcID = 12345,            -- req, from the NPC GUID
  name = "Example Rare",    -- req, display only
  mapID = 1412,             -- req
  verified = false,         -- req, true only after seen in game on Forever
  spawns = { { x = 0.50, y = 0.40 }, { x = 0.52, y = 0.44 } },  -- known spawn points
  level = { 23, 25 },
  elite = false,
  beast = { family = "Cat", tameable = true, attackSpeed = 1.2, abilities = { "Claw", "Prowl" } },
  respawn = { min = 3600, max = 10800 },  -- seconds; only from repeated observation or a cited source
  shares = { 99999 },       -- npcIDs that share the spawn point (placeholder rotation)
  notes = "Short tip shown on the pin card",
  source = "discovery 2026-11-14 / wowhead classic (re-verify: Mulgore redrawn)",
}
```

## poi

```lua
{
  id = "spirit-1412-a",     -- req, stable string: kind-mapID-suffix or "npc-<npcID>"
  kind = "spirit_healer",   -- req: spirit_healer flight_master innkeeper mailbox trainer_<class>
                            --      trainer_<profession> vendor_food vendor_ammo vendor_reagent
                            --      repair bank auction stable_master fishing_spot herb ore
  mapID = 1412, x = 0.45, y = 0.58,   -- req
  verified = false,         -- req
  npcID = 6666,             -- for NPC POIs
  name = "Spirit Healer",
  faction = "Horde",        -- "Horde" | "Alliance" | nil (both)
  source = "discovery",
}
```

## macro

```lua
{
  id = "hunter-tame-target",   -- req, stable
  name = "Tame",               -- req, macro name (16 chars max shown)
  class = "HUNTER",            -- req, class token or "ALL"
  body = "#showtooltip Tame Beast\n/cast Tame Beast",  -- req, <= 255 chars after template fill
  verified = false,            -- req, true after Gary pressed it in game
  icon = 132164,               -- fileID or "INV_Misc_QuestionMark"
  tags = { "pet", "utility" },
  needs = { spells = { 1515 } },          -- spellIDs that must be known to offer it
  template = { TARGET = "The Rake" },     -- {TARGET} placeholders filled at install time
  explain = "One line on what it does and why",
  scope = "character",         -- "character" (default) or "account"
}
```

## beast (hunter pet families)

```lua
{
  family = "Cat",              -- req, UnitCreatureFamily value
  diet = { "Meat", "Fish" },
  abilities = { { name = "Claw", ranks = { { rank = 1, level = 8 } } } },
  notes = "...",
}
```

## gear (upgrade sources; big pack, load on demand)

```lua
{
  itemID = 2504,               -- req
  source = "quest",            -- req: quest | vendor | drop | rare | crafted | dungeon
  questID = 0, npcID = 0, mapID = 0, x = 0, y = 0,
  level = 24, minLevel = 20, faction = "Horde",
  cost = 0,                    -- copper, for vendor items
  verified = false,
}
```

## recipe

```lua
{
  spellID = 2149,              -- req
  profession = "Leatherworking",  -- req
  itemID = 0, makes = 1,
  reagents = { { itemID = 2318, count = 1 } },
  skill = { learn = 1, orange = 1, yellow = 30, green = 45, grey = 60 },
  source = "trainer",          -- trainer | vendor | drop | quest
}
```

## fish (catch tables, built mostly from Gary's own catch log)

```lua
{ itemID = 6291, mapID = 1412, minSkill = 1, pool = false, verified = false }
```

## herb (where each herb grows, from guides; keyed by name)
`{ name, source, verified, skill = n | nil, zones = { "Zone", ... }, note }`. Keyed by name, not item ID: no
cited item IDs, and names are what node tooltips and loot show. `skill` only where a guide states it.
Zones are guide text, never coordinates (Forever redrew zones). `verified = true` only after Gary picks one.

## money (ways to earn gold, from guides; keyed by id)

`{ id, title, minLevel, maxLevel, source, verified, profession?, category?, faction?, gph? = {lo, hi} copper per hour, zones?, how?, minSkill? }`.
`profession` and `category` may be a string or a list (any one counts). `category` names the loot that measures it
(skin, herb, ore, fish, cloth, mob, craft): MoneyGuide shows Gary's own gold per hour for it once he has 15 minutes of it.
Pack: `Data/Money.lua` (Forever gold guides, cited per entry, all unverified).

## Captured at runtime (not packs)

`ns.db.global.discovered.npcs[npcID]`:
```lua
{ name = "...", mapID = 1412, x = 0.5, y = 0.4, level = 24, classification = "rare",
  family = "Cat", creatureType = "Beast", firstSeen = t, lastSeen = t, seen = 3,
  layer = 1234, roles = { "vendor", "trainer" } }
```

`ns.db.global.sightings[npcID]`: list of `{ t = time, layer = zoneUID, mapID, x, y, how = "nameplate"|"target"|"mouseover"|"guild", by = "Char-Realm", state = "alive"|"dead"|"tamed" }`, newest last, capped at 50 per NPC.

## Addon messages (Phase 8)

Prefix `Outrider`. Body = `v<protocol>|<type>|<payload>` where payload is `ns.Serialize.Base64Encode(ns.Serialize.Encode(table))` (base64 so no byte can break the channel), chunked when over 250 bytes (`#1/3` suffix). Types: `RARE` (npcID, mapID, x, y, layer, t, state), `HELLO` (version, build), `LOC` (opt-in position: mapID, x, y, zone). Receivers ignore unknown types and newer protocol versions they can't read.
