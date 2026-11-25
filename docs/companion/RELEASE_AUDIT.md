# Release privacy and license audit (OI08-13)

**Checked by Claude on the release package contents** (`tools/package.ps1` and `tools/curseforge.ps1`, the file lists in the zip):

| Check | Result |
|---|---|
| Personal logs or SavedVariables in the package | None: the packages take `addon/Outrider` and the data addons only. `WTF`, `backups`, `dist`, `tools/local.json` and `companion/config.json` are never included. |
| Credentials | None in the repo (`security_check.py`, `test_no_secrets_in_the_repo_tree`). |
| Data licenses | The QuestieDB-derived packs ship with GPLv3 text and `LICENSE-DATA.txt` (README, D20). Classic sources are labelled in-pack. |
| Assets | Art is the owner's own (`docs/ART_REQUESTS.md`). No Blizzard art is extracted. Icons are referenced by in-game path. |
| Naming | "Outrider". No Blizzard or competitor names in the title. |
| Public claims | The README says the planning and learning features aren't checked in game yet. Lesson sources are listed as unverified. |

**Owner to confirm (blocks distribution of the new features until done):**
- the name;
- the scope of the legal review for the QuestieDB historical-contributor caveat;
- that the new features may ship marked unverified.
