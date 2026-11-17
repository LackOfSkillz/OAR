# GPT art package: batch 3, dungeons and raids

The Dungeons page shows each dungeon as a card with its picture (a key icon until
this art arrives). There are 30 pictures in two sheets of 15, pasted into GPT one
at a time. Each sheet is an even 5 x 3 grid with the file name under every
picture, the way the batch 2 sheet came out. That's what Claude's slicer reads.

## How to do it

1. Open a new ChatGPT image chat.
2. Paste **Prompt A** (below) exactly as written. Download the image.
3. In the same chat, paste **Prompt B**. Download that image too.
4. Save them in `C:\Users\Administrator\Dev\OAR\art\incoming\` as `sheet_dungeons_a.png` and
   `sheet_dungeons_b.png`.
5. Tell Claude "dungeon art is in".

If GPT draws fewer than 15 pictures, changes the order, or leaves out the
labels, say: "Redo it: exactly 15 tiles, 5 columns by 3 rows, in the numbered
order, file name printed under each one." If it still won't, ask for each
picture alone with "One picture only, square, 1024x1024:" plus that row's
description, and save it under its file name.

## What Claude does with them

```
python tools/slice_sheet.py art/incoming/sheet_dungeons_a.png --grid 5x3 dungeon_thehallofthanes,dungeon_ragefirechasm,dungeon_ruinsoflordaeron,dungeon_wailingcaverns,dungeon_thedeadmines,dungeon_shadowfangkeep,dungeon_blackfathomdeeps,dungeon_thestockade,dungeon_excavationsitewetlands,dungeon_cityofdalaran,dungeon_gnomeregan,dungeon_razorfenkraul,dungeon_scarletmonastery,dungeon_razorfendowns,dungeon_uldaman
python tools/slice_sheet.py art/incoming/sheet_dungeons_b.png --grid 5x3 dungeon_zulfarrak,dungeon_maraudon,dungeon_thetempleofatalhakkar,dungeon_blackrockdepths,dungeon_diremaul,dungeon_blackrockspire,dungeon_scholomance,dungeon_stratholme,dungeon_zulgurub,dungeon_ruinsofahnqiraj,dungeon_onyxiaslair,dungeon_moltencore,dungeon_blackwinglair,dungeon_templeofahnqiraj,dungeon_naxxramas
python tools/art.py
```

---

## Prompt A (paste exactly)

> Create one landscape image, 1536x1024, that is a sheet of 15 game icons laid
> out as an exact grid of 5 columns and 3 rows. Every cell is the same size.
> Each cell holds one square picture with a thin dark border, and directly
> under the picture the file name in small plain white sans-serif text (the
> only text in the image). Separate the cells with plain black gutters. Fill
> the cells left to right, top to bottom, in this exact order:
>
> 1. dungeon_thehallofthanes.png: a great dwarven stone hall with carved pillars and a stone throne lit by braziers
> 2. dungeon_ragefirechasm.png: a fiery cave tunnel with rivers of glowing lava and jagged black rock
> 3. dungeon_ruinsoflordaeron.png: crumbling white-stone castle ruins overgrown with dark vines under a grey sky
> 4. dungeon_wailingcaverns.png: a lush green cave with twisted roots, glowing pools and mist
> 5. dungeon_thedeadmines.png: a dark mine tunnel with wooden supports and a mine cart, a pirate ship's mast far behind
> 6. dungeon_shadowfangkeep.png: a gothic castle on a cliff at night under a pale moon, a wolf silhouette on the rocks
> 7. dungeon_blackfathomdeeps.png: a sunken temple half under dark water, ancient columns, a blue glow
> 8. dungeon_thestockade.png: a stone prison corridor with iron bars and flickering torches
> 9. dungeon_excavationsitewetlands.png: a dig site in a marshy valley, wooden scaffolds around half-buried stone ruins
> 10. dungeon_cityofdalaran.png: a violet-roofed magical city with tall spires and floating arcane runes
> 11. dungeon_gnomeregan.png: a cluttered mechanical underground city of gears and pipes in green toxic haze
> 12. dungeon_razorfenkraul.png: a maze of giant thorny brambles under a red sky
> 13. dungeon_scarletmonastery.png: a grand red-roofed monastery with crimson banners on a hill
> 14. dungeon_razorfendowns.png: dark thorn mounds with bone totems in cold blue mist
> 15. dungeon_uldaman.png: an ancient carved vault door in a mountainside, golden glyphs glowing
>
> Each picture: the place as a small dramatic scene, centered, filling most of
> its square, on a dark blue-black vignette background (lighter in the middle).
> Painted dark-fantasy game art, deep blue-teal shadows with warm gold highlights,
> soft rim lighting, high detail, no text inside the pictures, no logos, no
> watermark. All 15 in the same style and lighting so they look like one set.

## Prompt B (paste exactly)

> Make a second sheet exactly like the first: one landscape image, 1536x1024,
> 15 game icons in an exact grid of 5 columns and 3 rows, every cell the same
> size, a thin dark border on each square picture, the file name in small plain
> white sans-serif text directly under it (the only text), plain black gutters,
> filled left to right, top to bottom, in this exact order:
>
> 1. dungeon_zulfarrak.png: a sandstone troll temple city in the desert with tall stairs and torches
> 2. dungeon_maraudon.png: a crystal cavern with purple crystals, a waterfall and glowing moss
> 3. dungeon_thetempleofatalhakkar.png: a sunken jungle temple in a swamp, a serpent statue, green mist
> 4. dungeon_blackrockdepths.png: a vast molten dwarven city inside a mountain, forges and lava falls
> 5. dungeon_diremaul.png: overgrown elven ruins with tall arches and a glowing blue barrier
> 6. dungeon_blackrockspire.png: a jagged black volcanic peak with dragon banners and smoke
> 7. dungeon_scholomance.png: a dark necromantic school on an island, green light in the windows
> 8. dungeon_stratholme.png: a burning plague-ridden city behind broken gates, green-tinted smoke
> 9. dungeon_zulgurub.png: a jungle troll temple with a giant serpent idol under a blood-red sky
> 10. dungeon_ruinsofahnqiraj.png: desert ruins of insect-shaped stone pillars under a dusty orange sky
> 11. dungeon_onyxiaslair.png: a huge volcanic cave with dragon eggs on a scorched floor
> 12. dungeon_moltencore.png: a cavern of molten rock with lava pools and towering fiery shapes
> 13. dungeon_blackwinglair.png: a dark draconic fortress hall with black dragon banners in red light
> 14. dungeon_templeofahnqiraj.png: a towering insect-like temple gate with glowing purple runes in the desert
> 15. dungeon_naxxramas.png: a dark floating necropolis in a green-black sky with ghostly lights
>
> Same picture style as the first sheet: the place as a small dramatic scene,
> centered, on a dark blue-black vignette background. Painted dark-fantasy game
> art, deep blue-teal shadows with warm gold highlights, soft rim lighting, high
> detail, no text inside the pictures, no logos, no watermark.

---

## Rules for every future package

- Original art only: no Blizzard logos, no WoW characters, no text inside the pictures.
- Sheets: 1536x1024, an even grid (5x3 for 15), file name under each picture, black gutters.
- Single pictures: 1024x1024, square, opaque, one subject centered on the dark vignette.
- The shared style line goes at the end of every prompt.
