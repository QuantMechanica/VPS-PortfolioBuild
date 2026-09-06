# Q04 native-report economic classification — REVIEW

Task: `51e0a47b-bae2-4922-bdc5-39565c5ec127`

Mode: dry-run/read-only. No stored verdict, threshold, queue row, terminal, or worker state was changed.

## Outcome

The proposed Q04 change is on isolated branch `agents/codex-q04-minfrades-label-20260906`, commit `c68c63f33ef60cf583679b4ad0c40bb24503e552`.

When the attributed deal stream and EA self-report are absent, Q04 now accepts native metrics only if `run_smoke` latched an `OK` report and the report still exists. This proves the tester completed and routes the result to the existing economic `FAIL` verdict. It cannot earn `PASS` because venue-cost attribution is unavailable. Invalid, missing, or unlatched reports stay fail-closed as infrastructure.

The 30-day production replay scanned 198 terminal Q04 `INFRA_FAIL` rows. 160 would reclassify, all 160 to the existing `FAIL` verdict; 30 of those carry `MIN_TRADES_NOT_MET`. Stored verdict changes applied: **0**.

The owner-highlighted QM5_1371 rows reclassify as follows:

| Work item | Symbol | Stored | Dry-run replay |
|---|---|---|---|
| `ba02b041-f84f-4b6b-a628-35df931b8dab` | GBPAUD.DWX | INFRA_FAIL | FAIL |
| `3ca734af-38a3-4b1f-a547-ac679d7f687d` | GBPJPY.DWX | INFRA_FAIL | FAIL |
| `159388a8-ccd3-44d7-944d-9bed35398a55` | GBPCAD.DWX | INFRA_FAIL | FAIL |
| `bc2fbbad-b554-479e-9091-7d2ba2801141` | NZDCHF.DWX | INFRA_FAIL | FAIL |

The first GBPAUD folds carry `STRATEGY_MIN_TRADES_NOT_MET`; the remaining completed-report-only folds carry `STRATEGY_NATIVE_REPORT_ONLY_NO_ATTRIBUTED_STREAM`. Both are existing economic failure paths, so future rows no longer satisfy the stranded-infrastructure sweep's `verdict='INFRA_FAIL'` selector.

## Verification

- `python -m pytest framework/scripts/tests/test_q04_walkforward.py -q`
- Result: `33 passed in 0.33s`
- Replay tool: `tools/strategy_farm/audit_q04_economic_replay.py --days 30`
- Machine-readable full replay table: `docs/ops/evidence/2026-09-06_q04_native_report_economic_replay.json`
- Replay artifact records `stored_verdict_changes_applied: 0`.

## Vorlage

No new taxonomy label or OWNER threshold decision is required. The proposal reuses Q04 `FAIL`, preserves all current PF/min-trade thresholds, and keeps report-invalid cases in the infrastructure lane. Close-out remains OWNER/Claude-controlled; this artifact and implementation are intentionally left in REVIEW.
