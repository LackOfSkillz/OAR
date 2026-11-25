# Provider security and privacy review (OI08-08)

A manual review of `companion/outrider_companion`, backed by tests. Nothing here runs a command a model asks for, and nothing lets a model choose a file.

| Risk | What is in place | Evidence |
|---|---|---|
| SSRF and redirects | The local provider allows loopback hosts only unless `allowRemote`; a non-loopback host also needs HTTPS and auth. A URL with a path, query, credentials or fragment is refused. Redirects are refused (`_NoRedirect`). Cloud URLs are fixed constants. | `test_url_rules`, `test_redirect_refused`, `test_tls_and_offline` |
| TLS | Cloud calls use HTTPS with default certificate checks. Plain HTTP to a LAN host is a development-only override (`allowInsecureLan`). | `test_tls_and_offline` |
| Secrets | Keys live in Windows Credential Manager (`Outrider/...`), never in config or logs. Status never shows a key. The repo is scanned for secrets. | `test_status_never_shows_keys`, `test_no_secrets_in_the_repo_tree`, `tools/security_check.py` |
| File paths | The only write is data-only `Advisor/Advice.lua` (and XP60's, policy-gated). `cli.py export` refuses paths under WTF or Interface. SavedVariables reads refuse symlinks, files over 20 MB and files that change while read. | `test_companion_writes_only_where_allowed`, `test_export_never_writes_inside_the_game_folder` (OI08-03) |
| Running text | Neither the companion nor the addon runs text: no eval, no loadstring, no shell. | `test_companion_never_runs_text_or_a_shell`, `test_addon_never_runs_strings_or_acts_alone` |
| Prompt injection | Snapshot text is cleaned and length-capped, then sent as JSON data. Model replies are parsed as one JSON object; unknown candidate ids are dropped; a prose or multi-object reply falls back to Outrider's own picks. Outrider's own caveats are kept even when the model sends many limits (fixed in OI08-07). | `test_prompt_injection_stays_data`, `test_poisoned_reply_is_cut_down`, `test_prose_reply_falls_back`, `test_caveats_survive_a_flood_of_model_limits`, `test_multiple_json_objects_and_malformed_json_fall_back` |
| Budget | Cloud calls need `cloudConsent` and pass the daily token cap (100 000 by default); over the cap, no call is made. | `test_cap_blocks_and_records`, `test_over_cap_falls_back_without_calling` |
| Data minimised | Names are removed from model context; passports carry an opaque character id, with sensitive fields off by default. | `test_names_removed_and_text_cleaned`, `Passport` tests in `test_phase8.py`, `passport_spec` |
| Capture | No screen capture, input simulation or memory reading anywhere (static scan). | `test_no_capture_input_or_memory_access_anywhere` |

**Residual risks (accepted):**
- A local model server the player runs is trusted as much as the player trusts it.
- A cloud provider sees the context that was previewed.
