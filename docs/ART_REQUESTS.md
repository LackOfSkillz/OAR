# Art requests for the Outrider redesign

Gary makes these with GPT image generation (his offer, 2026-11-15) and drops the
PNGs into `art/incoming/` in the repo with the exact file names below. Then
`python tools/art.py` converts each to the size WoW needs (32-bit TGA, power-of-two
sides, alpha kept) into `addon/Outrider/Art/` and updates the manifest. Outrider
falls back to built-in game art for anything not delivered yet, so nothing breaks
while art is missing.

Rules for every image:
- Original art only: no Blizzard logos, no WoW characters, no text or lettering
  inside the image (Outrider draws all text itself).
- PNG, the size GPT offers (1024x1024, 1536x1024 or 1024x1536 are all fine; the
  tool crops and scales).
- Shared style: painted fantasy, rich but dark, warm gold highlights against deep
  blue-teal shadows, soft rim light, high detail, no harsh outlines. Everything
  must read well very small.

Paste the shared style line into every prompt:

> Painted dark-fantasy game art, deep blue-teal shadows with warm gold highlights,
> soft rim lighting, high detail, no text, no logos, no watermark.

## Batch 1 (What now? page)

| File name | Ask GPT for | Final size in game | Background |
|---|---|---|---|
| `emblem.png` | 1024x1024 | 128x128 | transparent |
| `header.png` | 1536x1024 | 1024x256 (cropped strip) | opaque |
| `kind_quest.png` | 1024x1024 | 128x128 | opaque |
| `kind_dungeon.png` | 1024x1024 | 128x128 | opaque |
| `kind_gear.png` | 1024x1024 | 128x128 | opaque |
| `kind_profession.png` | 1024x1024 | 128x128 | opaque |
| `kind_rare.png` | 1024x1024 | 128x128 | opaque |
| `kind_gold.png` | 1024x1024 | 128x128 | opaque |
| `kind_gather.png` | 1024x1024 | 128x128 | opaque |
| `kind_errand.png` | 1024x1024 | 128x128 | opaque |

### emblem.png
The Outrider mark next to the name in the title bar.
> A single ornate golden compass star with four long points and four short
> points, polished gold with a faint inner glow, centered, filling about 80% of
> the canvas, on a fully transparent background. Painted dark-fantasy game art,
> warm gold highlights, soft rim lighting, high detail, no text, no logos, no
> watermark.

### header.png
The scene behind the page title. Only a 4:1 strip from the middle is used, and the
left side sits under the title, so keep the left third calm.
> Wide panoramic dusk landscape: distant castle spires and a dark pine forest on
> rolling hills, a few lit windows, misty blue-teal sky with a faint gold glow on
> the horizon, very dark overall, the left third almost plain dark sky. Painted
> dark-fantasy game art, deep blue-teal shadows with warm gold highlights, soft
> rim lighting, high detail, no text, no logos, no watermark.

### Step pictures (kind_*.png)
One square picture per kind of step, shown at 64x64 on each card. Each: a single
object centered, three-quarter view, on a dark vignette background (deep
blue-black, lighter in the middle), filling about 75% of the canvas, no frame or
border (Outrider draws the frame).

| File | Object |
|---|---|
| `kind_quest.png` | an old rolled parchment scroll, half open, with a bold golden exclamation mark floating above it and a red wax seal |
| `kind_dungeon.png` | a stone archway into a dark dungeon, blue magical glow inside, two torn banners on the sides |
| `kind_gear.png` | a piece of steel chest armor on a stand, a glowing green upward arrow beside it |
| `kind_profession.png` | a glass alchemy flask with bubbling green liquid next to a wooden mortar and pestle with herbs |
| `kind_rare.png` | a fierce prowling big cat silhouette with glowing eyes, a faint silver star above its head |
| `kind_gold.png` | a small pile of gold coins spilling from an open leather pouch |
| `kind_gather.png` | a glowing herb flower beside a chunk of copper ore with a pickaxe leaning on it |
| `kind_errand.png` | a leather travel bag with a small blacksmith hammer and a few coins in front |

Add the shared style line at the end of each.

## Batch 2 (a picture for every page, 2026-11-16)

Gary: "every page a custom premium feel". Each page's title now sits beside a
picture in a gold frame (like What now?), and its section cards reuse it until
section art exists. One square picture per page, shown at 52x52, made the same
way as the step pictures: **1024x1024, opaque**, a single object centered,
three-quarter view, on a dark vignette background (deep blue-black, lighter in
the middle), filling about 75% of the canvas, no frame or border. Add the shared
style line at the end of each prompt.

Until a picture arrives the page shows the game icon it has now, so they can come
in any order. Start with the pages you use most: help, map, rares, gear, money,
professions, then your class.

| File | Object |
|---|---|
| `page_help.png` | an open leather-bound tome with glowing golden runes and a quill resting on it |
| `page_journey.png` | a brass explorer's compass lying on a weathered map with a red route line |
| `page_map.png` | a rolled-out parchment map of a coastline with small gold pins stuck in it |
| `page_waypoints.png` | a tall wooden signpost at a crossroads with three arrow boards, a lantern hanging from it |
| `page_rares.png` | a spyglass resting on a rock, a faint silver star glinting in the distance |
| `page_rarealerts.png` | a small brass bell with a glowing gold star above it, sound rings around the bell |
| `page_dungeons.png` | a heavy iron dungeon key with an ornate bow, a faint blue glow behind it |
| `page_gear.png` | a steel helmet and a round shield leaning together, gold trim catching the light |
| `page_gearsets.png` | a wooden armor stand holding a full set of leather armor with shoulder pads |
| `page_professions.png` | a crafter's workbench with a hammer, tongs, a glass flask and a spool of thread |
| `page_crafting.png` | a glowing anvil with a half-forged glowing blade on it and sparks flying |
| `page_macros.png` | a parchment card with a glowing gold rune symbol, a feather quill beside it |
| `page_money.png` | a tall stack of gold coins next to an open treasure chest spilling coins |
| `page_errands.png` | a merchant's leather satchel with a rolled shopping list and a small hammer |
| `page_forecasts.png` | a brass hourglass with glowing gold sand and a small star chart behind it |
| `page_feed.png` | a stack of sealed letters with red wax seals and a raven feather |
| `page_chat.png` | two speech scrolls crossing each other with a glowing quill |
| `page_sharing.png` | a carrier pigeon in flight holding a small rolled message tied with gold string |
| `page_settings.png` | a set of brass gears and cogs interlocking, one large gear in front |
| `page_modules.png` | a wooden toolbox opened, filled with small glowing magical gadgets |
| `page_characters.png` | three small carved wooden figurines of adventurers standing on a table |
| `page_advisor.png` | a glowing crystal ball on a bronze stand with soft blue mist inside |
| `page_overview.png` | a brass spyglass and a small brass telescope crossed over an open logbook |
| `page_tools.png` | a leather tool roll with a wrench, a screwdriver and a small magnifying glass |
| `page_commands.png` | a stone tablet carved with glowing gold symbols in neat rows |

### Class page (one per class; the Class page shows the one for the character you're on)

| File | Object |
|---|---|
| `class_hunter.png` | a longbow with a quiver of feathered arrows and a wolf paw print |
| `class_warrior.png` | a battle axe crossed with a sword over a dented round shield |
| `class_rogue.png` | two curved daggers crossed over a dark hooded cloak |
| `class_mage.png` | a glowing arcane staff with a floating blue crystal at its tip |
| `class_priest.png` | a golden holy symbol of a radiant sun on a white cloth |
| `class_warlock.png` | a dark grimoire with a glowing green fel flame above it |
| `class_druid.png` | a carved wooden staff wrapped in green vines with a bear claw charm |
| `class_paladin.png` | a heavy war hammer with golden light shining from its head |
| `class_shaman.png` | a carved wooden totem pole with lightning crackling around it |

## Batch 3 (dungeons and raids, 2026-11-16)

The Dungeons page shows each dungeon as a card with its picture (a key icon until
the art arrives). One square picture per dungeon, **1024x1024, opaque**: the place
itself as a small dramatic vignette, centered, on the same dark blue-black
background as the other pictures, no frame, no text. Add the shared style line.
Ready-to-paste GPT prompts: docs/ART_PACKAGE_BATCH3.md. A labelled sheet is fine:
`tools/slice_sheet.py` cuts it up.

| File | Dungeon | Picture |
|---|---|---|
| `dungeon_thehallofthanes.png` | The Hall of Thanes | a great dwarven stone hall with carved pillars and a throne lit by braziers |
| `dungeon_ragefirechasm.png` | Ragefire Chasm | a fiery cave tunnel with rivers of glowing lava and jagged black rock |
| `dungeon_ruinsoflordaeron.png` | Ruins of Lordaeron | crumbling white-stone castle ruins overgrown with dark vines under a grey sky |
| `dungeon_wailingcaverns.png` | Wailing Caverns | a lush green cave with twisted roots, glowing pools and mist |
| `dungeon_thedeadmines.png` | The Deadmines | a dark mine tunnel with wooden supports, mine carts and a pirate ship's mast in the distance |
| `dungeon_shadowfangkeep.png` | Shadowfang Keep | a gothic castle on a cliff at night with a pale moon and howling wolf silhouette |
| `dungeon_blackfathomdeeps.png` | Blackfathom Deeps | a sunken temple half under dark water with ancient columns and blue glow |
| `dungeon_thestockade.png` | The Stockade | a stone prison corridor with iron bars and flickering torches |
| `dungeon_excavationsitewetlands.png` | Excavation Site: Wetlands | a dig site in a marshy valley with wooden scaffolds and half-buried stone ruins |
| `dungeon_cityofdalaran.png` | City of Dalaran | a violet-roofed magical city with floating arcane runes and tall spires |
| `dungeon_gnomeregan.png` | Gnomeregan | a cluttered mechanical underground city with gears, pipes and green toxic haze |
| `dungeon_razorfenkraul.png` | Razorfen Kraul | a maze of giant thorny brambles under a red sky |
| `dungeon_scarletmonastery.png` | Scarlet Monastery | a grand red-roofed monastery with crimson banners on a hill |
| `dungeon_razorfendowns.png` | Razorfen Downs | dark thorn mounds with bone totems and cold blue mist |
| `dungeon_uldaman.png` | Uldaman | an ancient titan vault door carved into a mountain, golden glyphs glowing |
| `dungeon_zulfarrak.png` | Zul'Farrak | a sandstone troll temple city in the desert with tall stairs and torches |
| `dungeon_maraudon.png` | Maraudon | a crystal cavern with purple crystals, waterfalls and glowing moss |
| `dungeon_thetempleofatalhakkar.png` | The Temple of Atal'Hakkar | a sunken jungle temple in a swamp with a serpent statue and green mist |
| `dungeon_blackrockdepths.png` | Blackrock Depths | a vast molten dwarven city inside a mountain with forges and lava falls |
| `dungeon_diremaul.png` | Dire Maul | overgrown elven ruins with tall arches and a glowing blue barrier |
| `dungeon_blackrockspire.png` | Blackrock Spire | a jagged black volcanic peak with dragon banners and smoke |
| `dungeon_scholomance.png` | Scholomance | a dark necromantic school building with green lights in the windows on an island |
| `dungeon_stratholme.png` | Stratholme | a burning plague-ridden city with broken gates and green-tinted smoke |
| `dungeon_zulgurub.png` | Zul'Gurub | a jungle troll temple with a giant serpent idol and blood-red sky |
| `dungeon_ruinsofahnqiraj.png` | Ruins of Ahn'Qiraj | desert ruins of insect-shaped stone pillars under a dusty orange sky |
| `dungeon_onyxiaslair.png` | Onyxia's Lair | a huge volcanic cave with dragon eggs and a scorched floor |
| `dungeon_moltencore.png` | Molten Core | a cavern of molten rock with lava pools and towering fire elementals' silhouettes |
| `dungeon_blackwinglair.png` | Blackwing Lair | a dark draconic fortress hall with black dragon banners and red light |
| `dungeon_templeofahnqiraj.png` | Temple of Ahn'Qiraj | a towering insectoid temple gate with glowing purple runes in the desert |
| `dungeon_naxxramas.png` | Naxxramas | a dark floating necropolis in a green-black sky with ghostly lights |

## Delivery
1. Save each PNG with the exact name above into `C:\Users\Administrator\Dev\OAR\art\incoming\`.
2. Tell Claude "art is in". Claude runs `python tools/art.py`, deploys, and asks
   for a full game restart (new files only load on a restart).
