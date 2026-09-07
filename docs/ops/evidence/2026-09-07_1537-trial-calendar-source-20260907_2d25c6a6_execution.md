# Execution record — OWNER-DEC-1537-TRIAL-CALENDAR-SOURCE-20260907 = YES (option A)

- Receipt: `2d25c6a6-5594-454d-9c0c-4a55dccbf494` (OWNER via chat 2026-09-07 ~09:55Z: "Dec 1537: Ja"; recorded by the Orchestrator with card + plan binding).
- Execution task (Claude lane): `0ad8aaff-724b-542d-be25-f8c08fe6b38f` (mode APPLY_AND_VERIFY).
- Boundary: calendar v2 = v1 rows byte-identical + new monthly rows 2025-01..2026-09 for the XAG host from native Darwinex D1 (all 37 universe symbols via the governed T_Export lane) under the identical ranking contract, declared source per row; new sha, preset re-pin as a new set version, FTMO demo install with receipt + OWNER re-attach; monthly refresh rule; M13 manifest addendum. No T_Live, no AutoTrading, no Q-gate change, factory EX5 untouched.

## Steps
1. Codex ticket (high): T_Export D1 download + export of the 37 symbols (receipt), builder extension with per-row source declaration, calendar v2 + manifest, preset re-pin (append-only set version), demo install (Common/Files + presets) with receipt and the 3-line OWNER instruction, refresh rule, sibling audit (21505 and other calendar/plan-driven sleeves).
2. After integration: verify sha chain, demo install, OWNER re-attach → EA logs MONTHLY_SLEEVE_STATE ready=true for 202609.
3. OPEN_ITEMS + M13 manifest + Vault; task → REVIEW → independent acceptance → APPROVED.

## Progress 2026-09-07 10:40Z — step 1 delivered (Codex b2b405b0 APPROVED, e5d7330a41)

- Native Darwinex D1 for 37/37 symbols via T_Export (receipt BE8DE77C…); calendar v2 (sha EB9AE48A…) = v1 byte prefix + 21 XAG rows 2025-01..2026-09 with declared source per row; ranking contract unchanged; September row ready (rank 0, valid 37, top-3 XAGUSD/XNGUSD/XTIUSD).
- Demo staged: EX5 16D66A0F installed (factory 142A019E untouched), v2 in both Common/Files paths, preset `QM5_1537_XAGUSD_D1_live_trial_s20260907-002.set`; M13 addendum; refresh runbook `QM5_1537_MONTHLY_SLEEVE_REFRESH_RUNBOOK_2026-09-07.md` + task JSON (not registered yet).
- Step 2 = OWNER re-attach with the new preset → expect `MONTHLY_SLEEVE_STATE month=202609 ready=true valid_count=37`; then register the monthly refresh task (CEO) and close.

## RESULT 2026-09-07 11:15Z (Claude) — acceptance criteria met on the FTMO demo

- OWNER re-attached QM5_1537 on XAGUSD D1 with preset `QM5_1537_XAGUSD_D1_live_trial_s20260907-002.set` (Experts journal: `removed` / `loaded successfully` 12:54:43 local; OWNER chat 13:0x local "1537 ist bereits mit dem neuen Preset frisch angehängt").
- EA log `MQL5/Files/QM/QM5_1537_ea-1537.log` (demo terminal 81A933A9AFC5DE3C23B15CAB19C63850), 2026-09-07T10:55:37Z: `INIT_OK` followed by `MONTHLY_SLEEVE_STATE {"month":202609,"host":"XAGUSD","host_rank":0,"valid_count":37,"selected":true,"host_vol_pct":65.18,"ready":true,"reject_reason":""}` — calendar v2 (sha EB9AE48A…) is live on the demo; 1537 is no longer inert.
- Calendar v2 rows 2025-01..2026-09 with declared source per row; v1 rows byte-identical (Codex b2b405b0, commit e5d7330a41, verified at review 10:3xZ). Presets/manifest re-pinned append-only; factory EX5 142A019E untouched (demo EX5 16D66A0F). No T_Live, no AutoTrading, no threshold change.
- Monthly refresh: Codex delivered the procedure (runbook `docs/ops/QM1537_MONTHLY_SLEEVE_REFRESH_RUNBOOK_2026-09-07.md`, proposal `config/qm1537_monthly_sleeve_refresh.task.json`, status PROPOSED_NOT_REGISTERED) but no runner that chains export → build → verify → stage. A scheduled task without a runner cannot be registered honestly; the runner + registration script is commissioned as a separate Codex ticket (see OPEN_ITEMS addendum 11:15Z). Until it exists the refresh is a CEO-run of the runbook on the first trading day of October 2026 (calendar row 202609 covers the current month).
- Follow-up already in the queue: other calendar/plan-based sleeves checked by Codex in b2b405b0 (13128 carries its own 2027 FOMC refresh; no other M13/live sleeve has this class).

## Acceptance 2026-09-07 11:33Z — independent (Sonnet) review: ACCEPT, no caveat

Verified read-only against primary evidence: v1 (834,341 B) is an exact byte prefix of v2 (839,381 B); v2 sha256 eb9ae48ab607fa30…; diff = exactly 21 XAGUSD.DWX rows 202501..202609, all `source=native_dwx_d1` in the sources sidecar (3567/3567 rows covered). EA log: `SLEEVE_CALENDAR_INIT` cites calendar_sha256 EB9AE48A…, then `MONTHLY_SLEEVE_STATE` 10:55:37Z month=202609 ready=true valid_count=37 (the 05:32Z/06Z entries before still show `calendar_stale`). Preset s20260907-002 present in MQL5/Presets. Factory EX5 142a019e…, demo EX5 16d66a0f…; e5d7330a41 sets change purely additive (+1 file, no deletions/renames). No T_Live, gate_manifest/*gate* or dxz23_execution_contracts.json path in e5d7330a41 or 8fcc4bf186..HEAD. Runner ticket 447f4995 exists (IN_PROGRESS, codex) — refresh automation honestly reported as not registered. Verdict: **ACCEPT**. Task 0ad8aaff → APPROVED.

## Refresh automation registered 12:22Z (CEO release under OWNER-DEC-1537-TRIAL-CALENDAR-SOURCE-20260907)

- Codex 447f4995 delivered the runner `tools/strategy_farm/qm1537_monthly_sleeve_refresh.py` (592a512530 on agents/board-advisor): September dry run reproduces calendar v2 byte-exactly (sha EB9AE48A…, source sidecar sha C1F3B0A7…, ranking contract unchanged), `dry_run_receipt.json` status PASS; 13 focused tests pass on board-advisor (README claims 19 — the difference is the pre-existing calendar-contract tests counted in Codex's run; not blocking).
- Installer defect found at release: `schtasks /SC MONTHLY /D 1,2,3` is rejected ("Invalid value for /D option"). CEO rewrote the apply path to `Register-ScheduledTask -Xml` with a CalendarTrigger (days 1–3, 05:30 local, months all), principal SYSTEM (same account as the factory terminal workers, which launch terminal64 the same way), working directory `C:\QMepo`, 2 h execution limit, IgnoreNew. Dry run stays print-only; `-Apply` still requires an `OWNER-DEC-*` release id.
- Registered: `QM_MonthlySleeveCalendar_Refresh`, state Ready, next run 2026-10-01 05:30 local; XML export verified (UserId S-1-5-18, Day 1/2/3, WorkingDirectory bytes `C:\QMepo`). The runner stops in REVIEW with an install-candidate receipt and the OWNER 3-line re-attach; it never installs into a terminal, attaches a chart or touches AutoTrading/T_Live/T1–T10.
- Rollback: `schtasks /Delete /TN QM_MonthlySleeveCalendar_Refresh /F` (calendar v2 and preset s20260907-002 stay valid through 2026-09).
