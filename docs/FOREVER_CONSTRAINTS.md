# WoW Forever: what the client allows

WoW Forever runs Classic-style game data on the modern (Midnight-era) client. Some facts below come from addon authors and community reports in November 2026, not from Blizzard documentation. Each row has a status. **Reported** means "design for it, verify before relying on it". Update the status column as Phase 0 and later phases confirm or refute rows, and copy measured details into PROBE_RESULTS.md.

| # | Constraint | Status | How we verify | What it means for the design |
|---|---|---|---|---|
| C1 | TOC `## Interface: 16001`, client build 1.60.1.70888 | Confirmed 2026-11-11 (/ride version: iface 16001, build 70888) | P0-06: `/dump select(4, GetBuildInfo())` | Update the TOC to the real number; "out of date" until it matches |
| C2 | Addons live in `World of Warcraft\_forever_\Interface\AddOns` (older reports: `_classic_beta_`) | Confirmed 2026-11-11 | P0-02: find-wow.ps1 lists client folders | find-wow prefers `_forever_`, falls back to `_classic_beta_` |
| C3 | Modern API namespaces exist (C_Map, C_Container, C_AddOns, C_Timer, Settings) alongside Classic-style data | Confirmed 2026-11-11: modern C_ APIs present, most Classic globals (GetSpellInfo, GetItemInfo, GetContainerNumSlots, GetPetHappiness...) missing | P0-08 probe | Use `ns.Compat`, which tries modern then Classic names |
| C4 | SavedVariables were written but not read back on early builds; reported fixed on current builds | Confirmed fixed 2026-11-11 (P0-07: reloads and full restart read back) | P0-07 round-trip test (loads counter) | Gate for all feature work. Fallbacks: Forever Data Protect or ForeverSVBridge style mirror, plus `tools/backup-sv.ps1` |
| C5 | Combat log is off-limits to addons | Confirmed 2026-11-11: even a test RegisterEvent made Blizzard block Outrider and offer to disable it; Events.FORBIDDEN refuses it before the call | P0-08 probe registers `COMBAT_LOG_EVENT_UNFILTERED` in pcall | No damage meters, no kill detection from the log. Use unit events, nameplates, loot and target info |
| C6 | "Secret values": some unit data can be displayed but not compared or computed in restricted contexts (combat) | `issecretvalue` exists; 2026-11-11 in-combat sample: target and nameplate GUID, name, classification and family were all readable (no secrets seen yet) | P0-08 `Probe:Units()` once out of combat, once in combat | Wrap reads in `Compat.Readable`; treat secrets as unknown; never branch logic on them in combat |
| C7 | Protected frames cannot be created, moved, shown or hidden in combat | Standard WoW rule | Built-in | `ns.Combat:Run`, secure button pools made out of combat |
| C8 | Every protected action needs a hardware event (key press or click); no automation | Standard WoW rule + ToS | Built-in | Each press does what a normal macro could do, nothing more. Secure buttons and macros only; nothing fires from timers or events. Advice never acts |
| C9 | Rares do not show as vignettes | Reported | P0-08 probe of `C_VignetteInfo`; P2 field test | Rare detection from nameplates, target, mouseover, and guild reports |
| C10 | Exact positions are only available for yourself and party/raid members | Standard WoW rule | Built-in | Friend and guild locations need opt-in sharing over addon messages (P8) |
| C11 | Addon messages work on GUILD, PARTY, RAID, WHISPER; CHANNEL is disabled on Classic clients; trial and veteran accounts cannot send | Reported | P8-01 send/receive test with a second player | No global "everyone with the addon" network. Sharing is guild/party scoped |
| C12 | NPC GUIDs carry a zone UID that identifies the layer (as LayerTracker uses) | Confirmed 2026-11-15: sightings carry layers 1, 8, 11 and 13 read from NPC GUIDs (task audit) | P2-07: compare zoneUID across mobs and after a layer change | Layer-aware sightings and respawn windows |
| C13 | Learning a new spell rank does not upgrade the button on your bars; `/cast Spell` without a rank casts the highest | Community-confirmed for Forever (Kami-Labs macro guide, 2026); RankCheck logs it in game | P4-06 test after a trainer visit | Rank-check scanner; library macros use rank-less `/cast` |
| C14 | Mulgore (and possibly other zones) was redrawn about 43% larger | Reported; cities measured 2026-11-15: the Orgrimmar (1454) and Thunder Bluff (1456) maps match Classic within about 1 map unit (Nazgrel, Kamari, Tal; interact captures vs Warcraft Wiki) | P3-11: outdoor Mulgore (1412) and Durotar (1411) still to capture | City coordinates from Classic sources may be used with verified = false; never import Classic coordinates for outdoor Mulgore unless re-verified |
| C15 | Forever adds Merchant's Favor and Waylaid Crates; one auction house per ruleset, faction and region; modern AH interface | Reported | P5-08 and P5-05 in game | Favor tracker; AH code written against the modern C_AuctionHouse API, Classic API as fallback |
| C16 | Macros: 255 characters per macro; account and per-character slot limits | Standard WoW rule | P0-08 records `MAX_ACCOUNT_MACROS`, `MAX_CHARACTER_MACROS` | Validator rejects long macros; installer checks free slots |
| C16b | One spell attempt per macro press (and re-sending `/cast !Auto Shot` on every press appeared to restart the shot: Gary saw the reload animation repeat, 2026-11-12; Fight now starts Auto Shot once per pull with a castsequence) (and `/castsequence reset=target` alone did not re-arm reliably: Mark 3 of 16 fights, and a reset=N timer never runs out while the key is spammed: Mark 3 of 14 fights with reset=30/target, measured 2026-11-12, so once-per-pull lines use reset=combat/target): a /cast line that casts, or is refused for a real reason (Target too close, Out of range), ends the press; only "Spell is not ready yet" (cooldown or global cooldown) falls through to the next line. Macros cannot see range | Measured on Gary's client 2026-11-12: 12 fights, Auto Shot refused 22x too close while Raptor Strike below it was tried 4x; Serpent Sting below Auto Shot tried once in 12 fights | High | Hunter Fight/Strike: once-per-target spells first, cooldown spells next, always-usable spell last; ranged and melee on two keys |
| C17 | New files or TOC changes are read only at client start; `/reload` re-reads existing files | Standard WoW behavior | Built-in | deploy.ps1 tells Gary when a full restart is needed |
| C18 | SavedVariables are written to disk only on /reload, logout or exit | Standard WoW behavior | Built-in | Every test step ends with /reload before Claude reads logs |
| C19 | Per-addon object caps: Frame 10000, Texture 40000, FontString 5000, Font 300, Animation 5000, AnimGroup 2000, Timer 500 | Seen in client General.log 2026-11-11 ("LimitedLuaResources: Addon capacity ...") | Re-read General.log after a session with Outrider loaded | Pools for frames and rows (ScrollList virtualized, toast and button pools); never create a timer per item. Watch the Timer cap in /ride perf (P1-11) |

## Things we deliberately do not do

- Read or write files outside our folder from the addon (WoW forbids file I/O anyway).
- Parse the combat log, even if a build allows it again, until Blizzard says it is intended.
- Automate fishing, selling, posting or anything else without a key press per action. "Sell junk" is a button Gary clicks; double-click fishing uses an override binding that still needs his click.
- Scrape websites at runtime. Data packs are built offline and shipped as Lua.

## Class spell changes reported by community guides (unverified, 2026-11-11)

From Rankedboost's WoW Forever class macro pages, gathered for the P4-08 macro packs. Low confidence until seen in game; the packs avoid these spells for now.
- Warrior: Tactical Mastery is a level 14 trainer passive; Berserker Rage at 30; Thunder Clap 6 s cooldown; Retaliation and Shield Wall 15 min; Victory Rush at 20.
- Rogue: new Poised passive and Shank strike.
- Warlock: Curse of Agony renamed Bane of Agony (own slot); Dark Pact and Curse of Shadow removed.
- Druid: Innervate, Rebirth and Remove Curse usable in Moonkin; Faerie Fire (Feral) talent gone; Nature's Grasp trained at 10; Roots indoors; new Revive at 12.
- Shaman: Fire Nova Totem removed (Fire Nova spell at 12); Totemic Call and Totemic Recall added; imbues last 60 min.
- Paladin: Judgement no longer consumes the Seal; Divine Shield shares a cooldown with Divine Protection; Holy Strike at 6.
- General (Kami-Labs): a spell alone on an action bar does not move to a newly trained rank (RankCheck covers this).

## Talents (research 2026-11-16, not yet probed)
warcraft.wiki.gg lists Forever 1.60.1 under the modern talent functions (C_ClassTalents, C_Traits), and not under the Classic ones (GetTalentInfo, GetNumTalentTabs). The Talents module tries the modern functions first and falls back to the Classic ones, logging which it used and the whole tree at login. Probe entries were added under P6.

## Macros: `/castsequence ...,null` does not hold (measured 2026-11-21)
The Classic trick `/castsequence reset=combat X,null` (cast X once, then the line does nothing until the reset) does **not** hold on Forever. Gul's paladin fight log: Seal of Righteousness was cast again on every press (25 tries in a 15 s fight, 7 casts), the sequence wrapped back to the Seal after its "null" step. Fixed for the paladin with a sequence of real spells (`Seal, Judgement, Judgement, Judgement`: it waits on Judgement's cooldown and seals again about every 30 s).
Druid fixed the same way on 2026-11-22: `Moonfire(,Insect Swarm),Wrath,Wrath,Wrath` (from 30 `...,Starfire,Starfire`), Demoralizing Roar on Ctrl in Bear. **All classes fixed 2026-11-22** (tools/fight_plan_fixes.lua for the plans, ClassFight/HunterFight for the fallbacks): DoT lines became sequences padded with the filler and moved last (cooldowns above them); the hunter loop parks on Arcane Shot; once-in-a-while spells went to a modifier (Battle Shout Alt, totems and Power Word: Shield Ctrl, Wing Clip and Hamstring Shift); the wand filler went to Shift. Lava Burst was removed on Forever (Nov 3 notes); Swiftmend no longer consumes HoTs. Not yet measured class by class: check each class's fight log.

## Addon textures: 2 MB draws black (measured 2026-11-23)

A 32-bit TGA of 1024x512 (2 MB) loads (the texture reports a file id, shown, alpha 1) but draws black on Forever 1.60.1; 1024x256 (1 MB) page headers draw fine. A 2048-wide painting drew black on 2026-11-21 too. Keep every addon image at 1 MB or less (1024x256, 512x512 or smaller): the Home hero halves were cut to 1024x256 and the Macros tree backdrop halved to 512x256. tools/art.py SPECS follow this. Confidence: high (Home painting black, then shown after the cut, Gary 2026-11-23).
