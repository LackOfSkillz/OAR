# Release test and rollback (OI08-14)

**No publish in this phase.** CurseForge needs the owner's request.

**Run at the exact SHA (see the OI08-GATE packet):**
- **Full suite:** `tools/test.ps1 -RequirePython`, which includes the Lua specs, companion tests, quality, deps and security.
- **Contract fixtures:** `tools/contract_fixtures.ps1` regenerates `snapshot_v2`, which carries the version.
- **Package twice, then compare SHA-256:** `tools/package.ps1` run two times; the zip hashes must match.

**Old data migration:** covered by the archive, retention and migration specs: a store from another schema is archived whole before a new one starts.

**Disable flags:** every new feature has an off switch (`docs/FEATURE_FLAGS.md`). With the planner off and the recorder off, the addon behaves as 0.5.0 (the `activity` and `hub` specs build every page either way).

**No provider:** the companion works with no model set (deterministic picks; `test_no_model_is_deterministic`).

**Adverse transport:** malformed, oversized, wrong-character and stale codes are refused (`world_spec`, `expedition_spec`, `test_corrupt_code_refused`, passport tests).

**Rollback:**
1. Close the game.
2. Restore the previous addon zip into `Interface\AddOns`, or `git checkout <previous tag>` and `tools/deploy.ps1`.
3. Restore SavedVariables with `tools/backup-sv.ps1 -Restore <stamp>` if needed.
4. The companion's rollback is in `docs/companion/PACKAGING.md`.
