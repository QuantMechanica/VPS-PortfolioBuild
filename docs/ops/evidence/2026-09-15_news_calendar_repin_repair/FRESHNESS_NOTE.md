# FRESHNESS NOTE — news-calendar repin repair package (2026-09-15_news_calendar_repin_repair)

**Verdict: CONFIRMED-CURRENT** (re-verified 2026-09-16 ~17:10Z by Kimi interim, task `e1c-followup`, read-only)

The human applier can apply the package as written. Every guard input was re-verified against
live bytes today; nothing drifted since preparation (2026-09-15T21:11Z).

## Re-verified values (exact, for the applier)

| Check | Patch binding | Live value today | Result |
|---|---|---|---|
| Registry file hash | `current_raw_file_sha256 a95fd02cd98b20bac63a325434a35ad7faa979df5331bf7b7e715fb5340c605d` (prepared_registry_patch.json → registry) | sha256(`framework/registry/dxz23_execution_contracts.json`) = `a95fd02cd98b20bac63a325434a35ad7faa979df5331bf7b7e715fb5340c605d` | MATCH (file still byte-identical to git HEAD `76dca44dab`; no working-tree drift) |
| Receipt chain tail | receipt `000016` (`000016_d8683b53…a6738c.json`, declared `receipt_sha256 3e78681ed28a08aa6aa896a1f8719627a88707a479e60017f3dba0a6b29e4773`, created 2026-09-15T02:47:15Z) | `D:/QM/reports/news_calendar/repin_receipts/` max sequence is still 000016 (no 000017 minted); file present; declared `receipt_sha256` == patch binding; chain link 000015 → 000016 verified (`previous_receipt_sha256` matches receipt 15's declared sha) | TAIL UNCHANGED |
| Read-only guard check | step 1 of the apply instructions | `python docs\ops\evidence\2026-09-15_news_calendar_repin_repair\verify_patch_readonly.py` run today → `{"status": "PASS", "ok": true, "fields_checked": 38, "failures": [], "other_divergent_fields": 0, "registry_sha256": "a95fd02c…605d"}` | PASS |
| Apply/verify commands | `verify_patch_readonly.py`, then `apply_registry_patch.py`, then `tools\strategy_farm\news_calendar_repin.py verify` (expected REFUSED until the scheduled refresh mints 000017) | both scripts present at the documented paths and run with the documented CLI; `news_calendar_repin.py verify` today → `{"ok": false, "status": "REFUSED", "error": "receipt tail does not match current news_calendar_2015_2025.csv: sha256"}` — exactly the documented pre-heal state (tail = 02:47Z calendar `8744295a…16a46`, live CSV = `c48ad8b4…c134`) | EXACT |

## Calendar bytes relevant to the heal (unchanged since preparation)

- Live primary `D:\QM\data\news_calendar\news_calendar_2015_2025.csv` sha256
  `c48ad8b4bf667001ef7204d37f5420504f853ac25aa6f0a70152b3d743a1c134` (== the value receipt 000017 will bind).
- Live secondary `forex_factory_calendar_clean.csv` sha256 `e15b6fe1f80f2f6a82a612f16ef7aaf6b9cc450d3eba1c3a94690ceee2f3b935`.
- Tainted pinned bundle `q09cal-20150101-20260809-0bb19b5bb9790b76/events.csv` sha256
  `86b2c0b595fd6011a2fe64b7da07f933e755294136a16f584d75389b66c56ce1` (taint config entry unchanged; E1-C follow-up work today did not touch this package's inputs).

## One clarification for the applier (not a drift)

The receipt file's RAW byte sha256 (`abaf2fa79c13…f47702`) is not the value the patch binds — the
chain binds the receipt's DECLARED `receipt_sha256` (`3e78681e…e4773`, recorded inside the file),
which matches. The minter's canonicalization differs from raw-bytes hashing; receipt 15→16 linkage
was verified via the declared shas. This is expected, not staleness.

## Apply sequence (unchanged from `prepared_registry_patch.md`)

1. `python docs\ops\evidence\2026-09-15_news_calendar_repin_repair\verify_patch_readonly.py` → PASS.
2. `python docs\ops\evidence\2026-09-15_news_calendar_repin_repair\apply_registry_patch.py` → APPLIED / 38 fields.
3. Do NOT hand-run `record`; let the scheduled `QM_NewsCalendar_Refresh` mint receipt 000017
   (binding primary `c48ad8b4…c134` / secondary `e15b6fe1…3b935`).
4. Then `python tools\strategy_farm\news_calendar_repin.py verify` → ok:true. Chain self-healed.

Committing the patched registry remains the OWNER's call (kein AI-Commit), naturally together
with receipt 000017's attestation.
