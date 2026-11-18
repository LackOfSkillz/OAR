# QuestieDB-derived datapacks: public redistribution review (2026-11-18)

**Decision status (updated 2026-11-18): Gary Mix explicitly chose GPLv3 for original Outrider and authorized publication of derived data and quest packs. Rights/provenance review is still required; no generated local pack files have yet been uploaded to this repository.**

Gary raised the possibility of committing the generated QuestieDB-based data packs to the public OAR repository. The upstream repository is public and has a GPLv3 license document, but its *own license expressly flags unresolved historic contributor rights*. Do not turn a license file into a blanket assurance that all the source data may be redistributed.

## Verified sources
- QuestieDB LICENSE.md: https://github.com/Questie/QuestieDB/blob/master/LICENSE.md
- QuestieDB GPL-3.0 full text: https://github.com/Questie/QuestieDB/blob/master/gpl-3.0.md
- QuestieDB provenance: https://github.com/Questie/QuestieDB/blob/master/PROVENANCE.md
- Questie parent LICENSE.md: https://github.com/Questie/Questie/blob/master/LICENSE.md

QuestieDB states (paraphrased) that historical Questie contributions were imported and may not all have GPLv3 contributor consent. The team permits copies on GPLv3 terms but cannot guarantee all third-party rights. In doubt it says to treat unclear portions as all-rights-reserved. These are **real and unresolved** limitations, not a routine GPLv3 condition.

## Current OAR state verified 2026-11-18
- Root `LICENSE` and `LICENSE.md` were absent from `main` at the time of this review.
- `README.md` says QuestieDB-derived packs ship with GPLv3 and attribution, but Outrider's own license is an open choice.
- `docs/DECISIONS.md` D10 originally chose private, ignored data packs; Q3 still explicitly notes the historic-contributor caveat and an undecided Outrider license.
- `.gitignore` excludes `private/` and tools create `private/Outrider_Data_*`.
- QuestieDB-derived release packs appear described as publicly distributed already. Check **actual release ZIPs** for the complete GPL text, rights notices, corresponding source, source version and per-pack provenance. README assertions do not establish ZIP contents.

## Before moving copies to the public repo

1. Confirm which upstream files/rows and corrections each generated pack draws upon, and check their per-file or per-directory notices. `LICENSE.md` prioritizes local notices.
2. Resolve or explicitly obtain a rights assessment of the upstream historical-contributor uncertainty. Asking QuestieDB maintainers for a clarification on the intended Forever data scope and preferred attribution is prudent; maintainers cannot waive other authors' rights.
3. Make an explicit project-owner decision for Outrider's **own** software license; do not silently apply GPLv3 to the entire OAR repo. Separate, independently licensed data addons may be treated distinctly, but assess combined-work obligations.
4. If publishing GPL-covered data, preserve the license text unmodified, original copyright/source notices, your modifications, source revision, provenance, and generated corresponding source/scripts; ensure recipients receive the GPL freedoms and source offer where applicable.
5. Reconcile `README.md`, D10, Q3, the installer/build packaging, `--deploy` flags, and the release distribution so they all tell the same truth.
6. Keep Questie branding/logos out of Outrider; attribution by accurate source name is appropriate.
7. Validate that generated files do not contain user/private captured coordinates, names, chat, or personal SavedVariables; only publish reproducible source-derived data.
8. Verify actual game/client pack load and test coverage after relocation.

**Safer interim approach:** keep the generated packs in `private/` while publishing original Outrider code, the conversion tooling and this rights audit. Alternatively, rely on QuestieDB's supported public API as an optional installed dependency until redistribution rights are reviewed.

This document is an engineering provenance checklist, **not legal advice**.

## Owner decision recorded (2026-11-18)

Gary Mix elected to publish the quest and other QuestieDB-derived data packs publicly, and selected GPL-3.0-only for original Outrider source. `LICENSE` and `COPYRIGHT.md` now exist at the repository root. This changes the earlier **owner decision**, but does not extinguish any independent third-party copyrights or historical-contributor uncertainty. The source build outputs currently live on Gary's Windows machine under `private/` and were not attached or made accessible through the GitHub repository; no absent generated data has been represented as committed. Import these only from the actual local outputs with provenance and corresponding licenses after reviewing source provenance.
