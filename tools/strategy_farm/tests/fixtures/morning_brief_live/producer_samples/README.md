# WS-E2 producer-output conformance samples

These are **byte-level conformant samples of the actual producer outputs** that
`morning_brief.live_status()` consumes. They exist so `test_producer_samples_
conformance` proves a *fresh valid producer file renders GREEN/RED by its own
content* (not the invented schemas round-1 was rejected for).

| File | Producer | Provenance |
|---|---|---|
| `wse1_alarm_all_ok.json` | WS-E1 `T_Live_Watchdog` (`Live_Alarm_State.ps1`) | verbatim from `D:\QM\reports\ultracode_20260726\wse1\samples\sample_all_ok.json` |
| `wse1_alarm_tlive_missing.json` | WS-E1 | verbatim from `wse1\samples\sample_tlive_missing.json` |
| `wse1_alarm_both_missing.json` | WS-E1 | verbatim from `wse1\samples\sample_both_missing_reboot_suppressed.json` |
| `wse1_alarm_maintenance.json` | WS-E1 | verbatim from `wse1\samples\sample_maintenance.json` |
| `wse3_deployment_contract_red.json` | WS-E3 `verify_live_deployment_contract.py` | derived from `wse3\live_run_state.json` (the real RED run), per-sleeve arrays trimmed; every top-level field + `summary` + `disk_profile` scalars are the producer's exact bytes |
| `wse3_deployment_contract_green.json` | WS-E3 | same producer schema; only the verdict-bearing scalars flipped to an all-clean GREEN case (no real GREEN capture exists) |

**Only normalization applied:** line endings CRLF→LF on the WS-E1 (PowerShell
`ConvertTo-Json`) files — the identical normalization git performs on commit
(repo `core.autocrlf=true`, no `.gitattributes` override for `*.json`). All field
names, values, enums and structure are the producers' exact output. The readers
are line-ending agnostic (`json.loads` / `read_text(utf-8-sig)`), so this does not
affect the proof.

Top-level schemas asserted (see repo `docs/ops/evidence/2026-07-26_wse22/state_contracts_v1.md`):
- **WS-E1 alarm:** `schema_version, generated_utc, author, watchdog_status,
  maintenance, reboot_suppressed, any_alarm, sessions{T_LIVE,FTMO}`.
- **WS-E3 deployment contract:** `overall_status, generated_utc, summary,
  disk_profile, runtime, findings, tool, version, trigger`.
