# Error guide

Start with **Settings, Fix problems**. Each check says what's wrong and what you can do yourself. **Copy the list** leaves out your name, realm and gold, so it can go in a bug report.

| Code | What it means | What to do |
|---|---|---|
| `quest_prerequisite` | The plan left a quest out because it needs an earlier one | Do the earlier quest first, or skip it |
| `stale_route` | A stop on your route is on a map the game doesn't know now (often after an update) | `/ride route clear` and set it again |
| `macro_rank` | A macro was written for spells that changed (respec, new rank) or names a rank | Update it on the Macros page (preview, then install) |
| `unsupported_api` | The probe found game functions missing on this client | Nothing: those features stay off. Run `/ride probe` again after a game update |
| `role_mismatch` | Your role is set to one your class can't play | Pick a role on the Class page |
| `missing_pack` | A data pack is missing, or an outside pack was set aside (no license or evidence class) | Reinstall Outrider, or use a pack with a license |
| `module_off` | The planner reads from a module that's switched off | Switch it on on the Modules page, or ignore it |
| "Couldn't check ..." | The check itself failed; this is a fault, not "all fine" | `/ride errors`, then report it |

Other places to look:
- **`/ride errors`:** Outrider's recent Lua errors.
- **`/ride status`:** modules, saved settings and errors.
- **The Plan page's "Why":** what limits the plan (gold, faction, prerequisites).
