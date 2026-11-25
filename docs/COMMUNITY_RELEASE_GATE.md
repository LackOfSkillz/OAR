# Community release gate (OI06-08)

**Status: design only. No server, no network code, nothing deployed.** Outrider's hard rule 10 holds: nothing leaves the player's PC except addon messages over GUILD, PARTY, RAID or WHISPER, for features the player switched on. Any external service needs the owner's separate, written authorisation first.

## What works today (offline, manual)

1. **Export.** The player turns on world-observation sharing (it is off by default), previews, then exports. The export needs the preview's token. It carries only kind, subject id, map, coordinates rounded to 0.001, layer, build, method and precision. It never carries names, account, chat, gold, bags or the walking trail, and leaves realm out unless the player ticks it. (`Intelligence/Contribute.lua`)
2. **Hand-over.** The player gives the text to whoever builds packs, by any means they choose (file, message). Outrider never sends it.
3. **Import into a queue.** The text is decoded without running code. Size, shape and each row's schema are checked, and duplicates are dropped. Each row waits as "pending".
4. **Moderation.** Each row is approved or rejected by hand. Nothing pending is ever used.
5. **Build.** A deterministic pack is made from approved rows (sorted; the same input gives the same hash). It is not publishable until rights are reviewed. Every build is kept, so a rollback is choosing an earlier one.
6. **Use.** An outside pack is registered with a manifest: license, revision, flavor, build and evidence class. One without a license or evidence class is quarantined. Classic data is labelled and never counts as verified. A pack older than a rule's minimum build is outdated. (`Intelligence/World.lua`)

## A future online submission service (blocked until authorised)

Before any of this is built, each point needs an owner decision and a policy and legal review:

| Topic | Requirement |
|---|---|
| Consent | Per-submission, explicit, revocable; default off; a plain preview of exactly what goes. |
| Authentication | An account or key per contributor, never the game account; no character names required. |
| Rate limits | A per-contributor cap on submissions and size; a server-side cap matching `Contribute.MAX_ROWS` and `MAX_TEXT`. |
| Moderation | The same queue model: pending, approved or rejected by a person; provenance kept per row. |
| Deletion | A contributor can withdraw their rows. Withdrawn rows leave future builds; past builds are re-made. |
| Data kept | Only the exported fields; no IP logs beyond abuse handling, with a stated retention period. |
| Licensing | Contributors agree to a stated license before submitting. Packs ship with that license in the manifest. |
| Policy | A Blizzard UI and add-on policy review: no game automation, no paid features tied to game data, nothing that reads game memory or the screen. |
| Security | Imports are decoded as data only (Serialize never runs code); size and depth limits; no executable content. |

Until that review passes, the workflow stays offline and manual, and no network code is added to the addon or the companion.
