# Archive growth, memory and loading time (review OI01-R06)

The owner's data preservation override means collected data is never thrown away. Old rows move from
capped working stores into `Outrider_DB.global.archive` (Core/Archive.lua). This note covers how fast
that grows, what it costs, how it is measured, and how it can later leave SavedVariables without
losing anything.

## What grows, and roughly how fast

These are estimates from row shapes and cadence. They are not measurements; the measured numbers
come from the perf rows below, after Gary plays. Size is the SavedVariables text, about 25 bytes
of key and syntax overhead per field.

| Dataset | When rows reach the archive | Entry size (est.) | Rate (est.) |
|---|---|---|---|
| prices (daily lows) | each item's 15th day back, once per scanned item per day | ~150 B | full scan of ~5,000 items: up to ~0.75 MB per scanning day after day 14. **The largest by far.** |
| priceHistory | tracked items past 120 days or 720 rows | ~150 B | ~300 items x up to 24/day: up to ~1 MB/day at the extreme; ~50 KB/day for typical use |
| trail | past 800 dots per map | ~130 B | one dot per 7 yards walked once a map is full: ~0.1 MB per hour of travel in a full map |
| sightings, spawnLog, deaths, quest diary, fights, ledgers, chat... | past each cap | 150-400 B | small: KB per play session |

## Memory and loading time

WoW parses all of `Outrider.lua` at login and holds it in addon memory. A rough rule is that the
Lua table in memory is 2-3x the text size. Parse time is about 1-2 s per 10 MB on a typical PC,
**to be measured on Gary's PC**. The client has no hard size limit, but loading and logout (when the
file is written) slow down as it grows. A full scan every day would push the file into tens of MB
within months.

## How it is measured (self-collecting)

- Every logout (or /reload) the perf row in `Outrider_DB.global.perfRuns` records `runtime.archiveRows`,
  memory before and after GC, and the boot `initMs` (time in our load step, which includes the
  SavedVariables-dependent setup).
- `tools/backup-sv.ps1` prints the file it copies; its size over time is the text-size curve.
- Budget proposal for owner review: warn in the Status page when the SavedVariables text passes 20 MB
  or `initMs` passes 2000 ms. Warn only; nothing is deleted.

## Lossless off-load design (future; nothing built yet)

This is compatible with D16 and D18. Nothing reads game memory or the screen, nothing touches the
game while it runs, and the only file the companion writes inside the game folder is
`Advisor\Advice.lua` (D16).

1. After logout, the companion reads `WTF\...\Outrider.lua` read-only, as it already does for snapshots.
2. It appends every archive entry it hasn't seen to an append-only local store outside the game
   folder, for example `companion/data/archive/*.jsonl`. Entries are keyed by the stable entry `id`
   (`session:counter`, added in this fix), and the file is fsynced.
3. It reads the store back and checks every copied entry byte for byte against the source.
4. Only then does it write the list of confirmed ids into the data-only `Advice.lua` (D16; no code,
   just a table), with a checksum per id.
5. At the next login, Outrider moves an entry out of SavedVariables only if its id and checksum are
   in that confirmed list. Without the companion, or if anything doesn't match, everything stays
   in SavedVariables.
6. Outrider can show archived history by asking the companion for it (an existing paste-code path)
   or by reading a summary the companion writes into the same data file.

Owner approval is needed before step 5 is built, because it is the first time saved rows would leave
SavedVariables (to a confirmed external copy). Until then the archive only grows, as decided.
Original observations are never compacted or summarised in place of the rows themselves.
