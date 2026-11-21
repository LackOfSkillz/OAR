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

## Batch 4 (premium UI, 2026-11-18)

Gary: "make every page look high end premium". This batch is for GPT to make in one go. Drop the PNGs into `art/incoming/` with these exact names, then Claude runs `python tools/art.py`. Anything not delivered keeps its current game art, so the images can arrive in any order.

**Shared style line, at the end of every prompt:**
> Painted dark-fantasy game art, deep blue-teal shadows with warm gold highlights, soft rim lighting, high detail, no text, no logos, no watermark.

**Rules (same as before):**
- Original art only: no Blizzard logos, no WoW characters, no lettering.
- PNG at the size GPT offers; the tool crops and scales.

### 4a. Page pictures (the pages still on game icons)
**1024x1024, opaque.** Same recipe as Batch 2:
- one object, centered, in three-quarter view;
- on a dark vignette background (deep blue-black, lighter in the middle);
- filling about 75% of the canvas;
- no frame or border.

Shown at 52x52 beside the page title.

| File | Object |
|---|---|
| `page_whatnow.png` | An open leather-bound journal with a brass compass resting on it and a quill, a faint gold glow from the pages |
| `page_quests.png` | A rolled parchment scroll with a red wax seal and a golden exclamation-shaped charm hanging from its ribbon |
| `page_fishing.png` | A wooden fishing pole with a red-and-white bobber and a glinting silver fish leaping beside it |
| `page_census.png` | A brass spyglass lying on a map with a few small carved pawn figures |
| `page_people.png` | Two crossed guild banners on a short pole, one blue and one gold, fabric slightly waving |
| `page_alts.png` | Three small framed portraits of different-looking adventurers in silhouette, hung side by side on a dark wall |
| `page_status.png` | A glowing blue-and-gold crystal orb on an ornate brass stand, faint runes circling it |

### 4b. Section hero banners
**1536x1024, opaque.** One per sidebar group. Only a 4:1 strip is used (the tool crops it), behind the page title at the top of every page in that group.
- Keep the **left third calm and dark**: the title sits there.
- Very dark overall, so gold text reads on top.

| File | Scene |
|---|---|
| `header_explore.png` | A winding road through dusky hills toward distant mountains, a lone signpost on the right, a faint gold glow on the horizon |
| `header_character.png` | An armour stand with a leather hunter's cloak and a longbow beside a weapon rack, lit by a warm lantern on the right, in a dark stone room |
| `header_town.png` | A cobbled market square at dusk: stalls with awnings, hanging lanterns and a well, warm windows on the right side |
| `header_social.png` | A long tavern table seen from the side, tankards and candles, guild banners hanging above, the right side warmer and busier |
| `header_outrider.png` | A brass astrolabe and clockwork gears on a dark workbench, blueprints underneath, soft gold light from the right |

### 4c. Map pin glyphs
**1024x1024, TRANSPARENT background.** Shown tiny (14–20 px) on the world map and minimap, so they must read at that size.
- One bold, simple symbol per pin.
- Gold metal with a dark outline.
- Filling about 70% of the canvas, centred, no circle behind it (Outrider draws the coloured ring).

**Prompt for every pin:**
> A single bold [SYMBOL] icon in polished gold metal with a thick dark outline, flat front view, simple readable silhouette for a tiny map marker, centered on a fully transparent background, no circle or frame behind it. Painted dark-fantasy game art, warm gold highlights, no text, no logos, no watermark.

| File | [SYMBOL] |
|---|---|
| `pin_vendor.png` | coin pouch with a drawstring |
| `pin_repair.png` | crossed hammer and anvil |
| `pin_trainer.png` | open book with a small flame above it |
| `pin_flight.png` | spread-winged gryphon in flight, side view |
| `pin_inn.png` | foaming tankard |
| `pin_mail.png` | sealed envelope |
| `pin_bank.png` | small iron-banded treasure chest |
| `pin_auction.png` | auctioneer's gavel |
| `pin_stable.png` | horseshoe |
| `pin_spirit.png` | glowing angel wing (pale blue-white instead of gold) |
| `pin_ammo.png` | bundle of three arrows |
| `pin_rare.png` | snarling beast skull (silver with a red glow instead of gold) |
| `pin_questgiver.png` | exclamation mark in the shape of a gold banner pin |
| `pin_turnin.png` | question mark in the shape of a gold banner pin |
| `pin_objective.png` | crosshair target with four short ticks |
| `pin_herb.png` | three-leaf herb sprig (green-gold) |
| `pin_ore.png` | chunk of ore with a pickaxe (copper-gold) |
| `pin_fish.png` | leaping fish (silver-blue) |
| `pin_dungeon.png` | stone archway gate with a portcullis |
| `pin_note.png` | pushpin through a small parchment note |
| `pin_cluster.png` | three overlapping small gold coins stacked (used for "+5 more here") |

### 4d. Ornaments and empty states

| File | Ask GPT for | Background | Prompt |
|---|---|---|---|
| `ornament_divider.png` | 1536x1024 | transparent | A thin horizontal ornamental divider line in polished gold filigree, a small diamond in the centre, tapering to points at both ends, spanning the full width and very thin (about 6% of the height), centred vertically on a fully transparent background. Painted dark-fantasy game art, warm gold highlights, no text, no logos, no watermark. |
| `ornament_corner.png` | 1024x1024 | transparent | A single ornate gold filigree corner flourish for the top-left corner of a frame: two thin lines meeting at a right angle with a small leaf scroll, in the top-left quarter of the canvas, the rest fully transparent. Painted dark-fantasy game art, warm gold highlights, no text, no logos, no watermark. |
| `empty_quiet.png` | 1536x1024 | opaque | A quiet campfire at night beside a bedroll and a sleeping wolf, small in the middle of a very dark scene. Used when a page has nothing to do. Plus the shared style line. |
| `empty_search.png` | 1536x1024 | opaque | A brass spyglass on a rock pointing at a dark empty horizon with a few stars. Used when a search finds nothing. Plus the shared style line. |
| `empty_nodata.png` | 1536x1024 | opaque | An open, mostly blank journal with a quill waiting in an inkpot, by candlelight. Used when Outrider hasn't collected data yet. Plus the shared style line. |

**Order if GPT can't do all at once:** 4c (map pins; the map is the most cluttered screen), then 4b (banners), then 4a, then 4d.

## Batch 5 (Feed and Money cards, 2026-11-19 tour)

**Delivered and installed 2026-11-20.** All 13 in style; every requested picture is now in (170 installed, 0 missing).

The page tour showed the Feed using a blue cross and plain envelopes, and both
Money cards using the same loot bag. These replace them. Same as the step
pictures: one object centered, three-quarter view, on a dark vignette background
(deep blue-black, lighter in the middle), filling about 75% of the canvas, no
frame. Ask GPT for 1024x1024; final size 128x128, opaque. Add the shared style
line at the end of each. Outrider picks them up automatically after
`python tools/art.py` and a full game restart; until then it keeps the game icons.

### 5a. Feed (one per kind of pop-up)

| File | Object |
|---|---|
| `feed_rare.png` | a hunter's spyglass lying on a map, a faint silver star glinting in its lens |
| `feed_upgrade.png` | a steel chest piece on a stand with a glowing green upward arrow beside it, brighter and newer-looking than `kind_gear` |
| `feed_reward.png` | a small wooden quest-reward chest, lid open, soft gold light spilling out |
| `feed_ammo.png` | a leather quiver of arrows with one arrow half drawn, a few loose arrows in front |
| `feed_errand.png` | a merchant's scale with a coin on one pan and a worn boot on the other |
| `feed_tip.png` | a folded parchment note with a small brass compass resting on it |

### 5b. Money (one per way of earning)

| File | Object |
|---|---|
| `money_mob.png` | grey vendor junk (a cracked fang, a torn pelt scrap, a dull ring) spilling from a cloth sack, a few coins among it |
| `money_skin.png` | a skinning knife lying on a stack of tanned leather hides |
| `money_herb.png` | a bundle of fresh herbs tied with twine, one glowing flower on top |
| `money_ore.png` | chunks of copper and silver ore beside a miner's pick |
| `money_cloth.png` | folded bolts of linen and wool cloth, a needle and thread on top |
| `money_craft.png` | a leatherworker's bench: a half-stitched leather piece, an awl and thread |
| `money_fish.png` | two fresh fish on a wooden plank beside a coiled fishing line and a red-and-white bobber |

## Batch 6 (the Macros page skill tree, 2026-11-19)

The Macros page is now laid out like the talent window: your keys on top, then
a tree of macros by level band, one column for every build of your class and
one per talent tree. These pictures dress it. Until they're delivered, Outrider
uses the spell's own icon (once you know the spell) or a game icon. Drop them in
`art/incoming/`, run `python tools/art.py`, and fully restart the game.

### 6a. Your keys (6 files, 1024x1024, final 128x128, opaque)
Big square buttons at the top of the page. Each: a single bold emblem centered on
a dark vignette, like an action-bar ability, readable at 54 pixels. Add the
shared style line.

| File | Emblem |
|---|---|
| `macro_key_fight.png` | two crossed blades with a gold spark where they meet |
| `macro_key_pull.png` | a thrown dagger and an arrow flying side by side toward the viewer |
| `macro_key_strike.png` | a single gauntleted fist striking, a burst of gold light at the knuckles |
| `macro_key_heal.png` | an open hand with a soft golden glow rising from the palm |
| `macro_key_pet.png` | a wolf's head in profile, alert, with a faint gold collar |
| `macro_key_reach.png` | a glowing hammer of light flying forward, trailing gold |

### 6b. Macro kinds (11 files, 1024x1024, final 128x128, opaque)
Shown greyed out for macros whose spell you haven't learned yet, so they must
read well desaturated. Same style as the keys.

| File | Emblem |
|---|---|
| `macro_combat.png` | a sword point-down with a small gold flame on the blade |
| `macro_control.png` | a chain wrapped around a raised fist |
| `macro_defensive.png` | a round shield with a gold rim, a crack across it |
| `macro_utility.png` | a leather pouch with a small compass beside it |
| `macro_heal.png` | a green-gold leaf cradling a drop of light |
| `macro_pet.png` | a paw print glowing faintly gold |
| `macro_rare.png` | a silver star above a hunter's eye |
| `macro_burst.png` | an hourglass cracking open with gold light pouring out |
| `macro_break.png` | a broken iron shackle, pieces flying apart |
| `macro_recover.png` | a campfire with a small kettle steaming beside it |
| `macro_trap.png` | an open iron bear trap half hidden in grass |

### 6c. Tree background (1 file, 1536x1024, final 1024x512, opaque)
`macro_tree.png`: a dark, quiet backdrop for the tree, shown at 35% behind the
icons. Faint carved stone panel with three subtle vertical channels (like a
talent window), very low contrast, darker at the edges. No figures, nothing busy.

### 6d. Build emblems (27 files, 1024x1024, final 64x64, transparent)
A tiny emblem beside each build's column name, one per talent tree of every
class. Simple bold silhouette in gold on a transparent background, readable at
16 pixels: no fine detail. File name: `spec_<class>_<tree>.png`.

| Class | Files and emblem |
|---|---|
| Druid | `spec_druid_balance` crescent moon and star · `spec_druid_feral` cat paw with claws · `spec_druid_resto` sprouting seed |
| Hunter | `spec_hunter_bm` boar head · `spec_hunter_mm` drawn bow · `spec_hunter_sv` crossed knife and trap |
| Mage | `spec_mage_arcane` arcane rune circle · `spec_mage_fire` flame · `spec_mage_frost` snowflake |
| Paladin | `spec_paladin_holy` radiant sun · `spec_paladin_prot` shield with a cross · `spec_paladin_ret` winged hammer |
| Priest | `spec_priest_disc` shield of light · `spec_priest_holy` rising sun with rays · `spec_priest_shadow` shadowy eye |
| Rogue | `spec_rogue_assassination` dripping dagger · `spec_rogue_combat` two crossed swords · `spec_rogue_subtlety` hooded face in shadow |
| Shaman | `spec_shaman_elemental` lightning bolt · `spec_shaman_enhancement` fist wreathed in wind · `spec_shaman_resto` water droplet |
| Warlock | `spec_warlock_affliction` skull with green smoke · `spec_warlock_demonology` horned demon head · `spec_warlock_destruction` falling burning rock |
| Warrior | `spec_warrior_arms` greatsword · `spec_warrior_fury` two axes crossed · `spec_warrior_prot` tower shield |

Batch 6 is 45 pictures in all; the keys (6a) matter most, then the build emblems.

## Batch 6 redo (2026-11-19 review of the 69-picture delivery)

Installed from that delivery: all page pictures, step pictures, emblem, header,
the six key pictures, the tree background and the build emblems (the nine below
stay in until their replacements come). Please redo these 20.

### 6b again: the 11 macro-kind icons (wrong style)
The delivered ones are flat clip-art (smooth gold vector shapes). They must be
**painted, exactly like the six `macro_key_*.png` pictures from the same
delivery**: a real, textured, lit object with depth, a dark blue-teal vignette
behind it, warm gold rim light, three-quarter view. Give GPT one of the key
pictures as the style reference ("in the same painted style as this image").
Not flat, not a vector icon, no outline shapes. 1024x1024, final 128x128, opaque.
Same objects as before:

| File | Object |
|---|---|
| `macro_combat.png` | a sword point-down with a small gold flame running along the blade |
| `macro_control.png` | a heavy iron chain wrapped around a raised gauntleted fist |
| `macro_defensive.png` | a round battered shield with a gold rim and a crack across it |
| `macro_utility.png` | a leather pouch with a small brass compass resting beside it (not a padlock) |
| `macro_heal.png` | a green-gold leaf cradling a glowing drop of light |
| `macro_pet.png` | a glowing gold paw print pressed into dark earth |
| `macro_rare.png` | a silver star shining above a hunter's narrowed eye |
| `macro_burst.png` | an hourglass cracking open with gold light pouring out |
| `macro_break.png` | a broken iron shackle, the two halves flying apart |
| `macro_recover.png` | a small campfire with a dented kettle steaming beside it |
| `macro_trap.png` | an open iron bear trap half hidden in grass |

### 6d again: 9 build emblems
The rest are right. Rules again: **one bold gold silhouette only** (the same
gold as the others), transparent background, no second colour, readable at 16
pixels, and each one different from every other emblem.

| File | Problem | Emblem wanted |
|---|---|---|
| `spec_warrior_arms.png` | the same dagger as Rogue Assassination | a two-handed greatsword, broad blade, long grip, point down |
| `spec_warrior_prot.png` | same plain shield as Priest Discipline | a tall rectangular tower shield with rivets |
| `spec_priest_disc.png` | same plain shield as Warrior Protection | a glowing sphere (bubble of light) with rays |
| `spec_priest_shadow.png` | purple, not gold | an eye with shadow tendrils, all gold |
| `spec_shaman_resto.png` | blue, not gold | a water droplet, all gold |
| `spec_shaman_enhancement.png` | teal arcs | a fist wreathed in wind lines, all gold |
| `spec_warlock_affliction.png` | grey and green | a skull with smoke curling up, all gold |
| `spec_warlock_demonology.png` | grey | a horned demon head, all gold |
| `spec_warlock_destruction.png` | grey and orange | a falling burning meteor, all gold |

Batch 5 (6 Feed and 7 Money pictures) is still to come as well.

## Batch 6 redo 2: match the gold (2026-11-19)

**Delivered and installed 2026-11-19.** All 9 match the shaded gold of the other 18.

The 9 redone build emblems have the right shapes, but they are a flat mustard
gold, while the other 18 have a shaded gold: lighter on top, darker below, a
thin darker outline and a soft highlight. Please redo these 9 with **the same
shapes as the redo**, in **that shaded gold**. Give GPT one of the first-round
emblems (for example `spec_druid_balance.png`, `spec_rogue_combat.png` or
`spec_paladin_holy.png`) as the style reference: "the same shaded gold, outline
and highlight as this image". One colour only (gold), transparent background,
1024x1024, final 64x64.

| File | Shape (keep the redo's) |
|---|---|
| `spec_priest_disc.png` | a glowing sphere with rays; make it a round bubble with a bright rim, not a sun, so it differs from Paladin Holy |
| `spec_priest_shadow.png` | an eye with shadow tendrils below |
| `spec_shaman_enhancement.png` | a raised fist with wind lines on both sides |
| `spec_shaman_resto.png` | a water droplet |
| `spec_warlock_affliction.png` | a skull with smoke curling up |
| `spec_warlock_demonology.png` | a horned demon head |
| `spec_warlock_destruction.png` | a falling burning meteor |
| `spec_warrior_arms.png` | a two-handed greatsword: make the blade broad and the grip long, so it can't be read as a dagger |
| `spec_warrior_prot.png` | a tall tower shield with rivets |

## Batch 7: auction house header (2026-11-20)

The redesigned shopping window beside the auction house opens with a painted
header strip, like the hub's page headers. One picture, same style line as the
rest (painted dark fantasy, deep blue-teal shadows, warm gold highlights, soft
rim light, no text, no logos). 4:1 wide strip, artwork centred: deliver
2048x512 (or 1024x256), opaque.

| File | Picture |
|---|---|
| `header_auction.png` | A grand auction hall at dusk: a long auctioneer's counter of dark wood with brass scales, stacked crates, bolts of cloth, potions on a shelf and a hanging lantern; gold coins on the counter catching the light; an arched window with a blue evening sky behind. Keep the left third darker and calmer (the emblem and title sit there) and the right edge quiet (the gold amount sits there). |

## Batch 8: Journey page (2026-11-20)

The Journey page is rebuilt to read at a glance: steps 1-2-3, three "best
picks" picture cards, and a "Your trip" card. Two pictures, same style line as
the rest (painted dark fantasy, deep blue-teal shadows, warm gold highlights,
soft rim light, no text, no logos).

| File | Size | Picture |
|---|---|---|
| `kind_zone.png` | 1024x1024, opaque, like the other `kind_*` pictures | A wide landscape seen from a hilltop: rolling green hills, a winding road, a small village with smoke from chimneys, mountains in the distance at dusk. The "Best zone for your level" card. |
| `journey_empty.png` | 2048x1024 (2:1), transparent or dark vignette background | An open traveller's map on a wooden table, a brass compass on it, and a glowing gold arrow drawn across the map toward a small marked spot. Shown in "Your trip" before anything is picked. |

## Batch 9: profession pictures (2026-11-20) — DELIVERED and installed 2026-11-20

The Professions page now has a card per profession saying what to do next.
One picture per profession, like the `kind_*` pictures: 1024x1024, opaque, one
object centred in three-quarter view on the dark vignette background (deep
blue-black, lighter in the middle), filling about 75%, no frame. Same style
line as the rest (painted dark fantasy, deep blue-teal shadows, warm gold
highlights, soft rim light, no text, no logos).

| File | Picture |
|---|---|
| `prof_cooking.png` | A cast-iron pan over a small campfire, a steak sizzling, a wooden spoon beside it |
| `prof_firstaid.png` | A rolled linen bandage and a small corked red potion on a cloth |
| `prof_fishing.png` | A wooden fishing pole with a red-and-white bobber and a fish on the line |
| `prof_leatherworking.png` | A curved leather-cutting knife on a piece of tanned leather with stitching |
| `prof_tailoring.png` | A spool of thread, a needle and a folded bolt of purple cloth |
| `prof_blacksmithing.png` | A hammer resting on an anvil with a glowing orange ingot |
| `prof_engineering.png` | A brass gear, a wrench and a small copper gadget with a spring |
| `prof_alchemy.png` | Two glass flasks, one green and one blue, with a curl of vapour |
| `prof_enchanting.png` | A glowing violet rod over a small pile of shimmering dust |
| `prof_herbalism.png` | A hand trowel beside a freshly picked herb with its roots |
| `prof_mining.png` | A miner's pick stuck in a rock with a vein of copper ore |
| `prof_skinning.png` | A skinning knife on a folded wolf pelt |

## Batch 10: new sidebar groups and trainer pins (2026-11-20)

The sidebar was regrouped (World, Character, Professions, Gold, Social). Three
groups are new and borrow another group's banner until their own arrives; the
Map and places page has two new trainer tiles. Same style line as the rest
(painted dark fantasy, deep blue-teal shadows, warm gold highlights, soft rim
light, no text, no logos).

### Section hero banners
**1536x1024, opaque**, like `header_explore` (only a 4:1 strip across the
middle is used, behind the page title). Keep the **left third calm and dark**
(the title sits there); very dark overall so gold text reads on top.

| File | Scene |
|---|---|
| `header_world.png` | A wide view from a cliff over a world map come to life: forests, a river, a distant city and mountains under a dusky sky, a faint gold glow where the road meets the horizon on the right |
| `header_professions.png` | A craftsman's workshop: an anvil with a glowing ingot, an alchemy table with flasks, a loom with cloth and a fishing pole by the door, lit warm from the right |
| `header_gold.png` | A merchant's counting table: neat stacks of gold coins, an open ledger, brass scales and a small treasure chest, lantern light from the right |

### Map pin glyphs
**1024x1024, TRANSPARENT background**, like `pin_trainer`: one bold simple
symbol in polished gold metal with a thick dark outline, about 70% of the
canvas, centred, no circle behind it (Outrider draws the ring). Must read at
14-20 px.

| File | Symbol |
|---|---|
| `pin_weaponmaster.png` | a sword and an axe crossed over a small round shield |
| `pin_pettrainer.png` | a paw print with a small open book above it |

Still waiting from earlier batches: Batch 7 `header_auction.png`, Batch 8
`kind_zone.png` and `journey_empty.png`.

