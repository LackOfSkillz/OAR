# OWNER DIRECTIVE: DATA PRESERVATION OVERRIDE

Issued by Gary Mix on 2026-11-24. It takes precedence over the Outrider Engineering Blueprint, the
microtask backlog, the implementation prompt, the review template and earlier development
instructions, across all eight phases and all 124 microtasks.

## Data provenance instructions are withdrawn

Gary's instruction: "belay any directions on data provenance. I don't want to remove or redact any
data we have collected. Ignore all instructions on data provenance in the engineering spec."

The following are void as implementation instructions: OI01-05 (quarantine unclear extracts), OI06-02
(quarantine missing or unlicensed data), OI03-15 (retention caps and reset/delete controls as
automatic deletion), section 4.3 (historical data compaction), section 4.4 (data provenance and
licensing), and OI08-13 (release licensing audit as a removal step).

## Binding rules

- Do not delete, purge, truncate, relocate, overwrite, strip, redact or otherwise remove existing data.
  This covers master datasets, the source repository, local databases, data packs and historical
  records, including data whose provenance or licensing is uncertain.
- "Quarantine" means at most a logical label. It never means physical deletion, destructive
  modification or relocation.
- Refactoring, deduplication, schema migration, optimisation, security review, retention policy and
  release preparation are not permission to destroy collected information.
- Every migration and transformation keeps the original information in recoverable form.
- Aggregates are added next to the original records, never in place of them.
- Where a legal obligation might require removal: stop and escalate to Gary.
- Nothing is intentionally destroyed without separate, explicit authorization from Gary Mix.

Keeping data and permission to redistribute it are separate questions. Provenance notes that
already exist stay as plain records; they are not a to-do list for removal.
