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

## Delivery
1. Save each PNG with the exact name above into `C:\Users\Administrator\Dev\OAR\art\incoming\`.
2. Tell Claude "art is in". Claude runs `python tools/art.py`, deploys, and asks
   for a full game restart (new files only load on a restart).
