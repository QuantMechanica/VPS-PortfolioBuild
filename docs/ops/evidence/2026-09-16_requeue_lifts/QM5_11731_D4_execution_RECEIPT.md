# Receipt — OWNER-DEC-REQUEUE-LIFT-20260916-D4 EXECUTED — QM5_11731 EURUSD.DWX M5 pilot

- Owner decision id: `OWNER-DEC-REQUEUE-LIFT-20260916-D4` (OWNER package
  `docs/ops/OWNER_DECISION_PACKAGE_D4_D5_2026-09-16.md`, DECISION 4;
  interim delegation `OWNER-DEC-REQUEUE-LIFT-20260916`)
- Operator: `kimi-interim` (D4) · Date (UTC): 2026-09-16
- EA: `QM5_11731` (`QM5_11731_tc-m5-s20-ema3-bb-macd`), 4-symbol universe
  EURUSD/GBPUSD/USDCHF/USDJPY .DWX, all M5
- **Outcome: D4 COMPLETE — authority registered, fresh build identity minted,
  exclusion lifted (hash-bound), EURUSD.DWX M5 canary PASS (pilot a–e CLEAN),
  governed fanout enacted for the remaining 3 symbols. No STOP.**

## 1. Authority registration (append-only, fail-closed)

- Code: `tools/strategy_farm/compile_work_items.py` — new document-bound force-
  rebuild wave `requeue_lift_d4_force_rebuild_allowlist` (hardcoded
  `REQUEUE_LIFT_D4_FORCE_REBUILD_EA_IDS = {"QM5_11731"}` + decision doc
  `OWNER-DEC-REQUEUE-LIFT-20260916-D4_QM5_11731_force_rebuild.md` must both
  agree). Scoped to QM5_11731 only; no generic force-rebuild authority.
- Commit `98207717da` (path-scoped, EX5_COMMIT_GUARD PASS). Test suite
  93/94 green; the single failure is pre-existing (live-DB taxonomy schema,
  fails on unmodified code too).

## 2. Compile row + result

- `farmctl enqueue-compile QM5_11731_tc-m5-s20-ema3-bb-macd --apply`
  → COMPILE_EA work item **`528c42c5-bd83-46d1-ab2c-954cb1669c0b`**, payload
  records `force_rebuild_owner_reference: OWNER-DEC-REQUEUE-LIFT-20260916-D4`,
  waived `['BUILD_TASK_EXISTS','EX5_ALREADY_PRESENT']`.
- Rollout hold released via `release_compile_wave.py --apply
  --work-item-id 528c42c5-…` (bounded; backup sha256 25a46ca1…; lock contention
  retried governed, acquired on attempt 11).
- Worker **T3** claimed 1 s after release; `run_compile_work_item` executed the
  canonical path (gen_setfile ×4 → `build_check.ps1 -Strict`).
- **Result: done/COMPILE_OK at 11:58:27Z** — 0 errors / 0 warnings,
  `build_check.result=PASS` (deterministic `build_gate_hardening` gate ran,
  empty failures/warnings), 4 setfiles generated.
- **New build identity: ex5 sha256 `6e6fbf44…a2849`** (old wave-64 ex5
  `d4c18bdc…e506` preserved — untouched in git history; build task
  `1a17f439-…` never reopened). Append-only lineage: old binary + build task
  remain as historical evidence; the new identity is hash-bound across DB row,
  payload, compile evidence, and worktree.

## 3. Incident during execution (resolved, documented)

At 12:00:23Z — after COMPILE_OK, before intake — an ambient
`clean_repo_worktree.ps1 -RestoreTrackedEx5` sweep (hourly hygiene, run by the
parallel D5 operator activity) reverted the worktree ex5 to the committed
wave-64 bytes. The fresh bytes had been archived pre-restore at
`C:\QM\archive\repo-dirty-20260916T120023Z\tracked-before-restore\…` (sha256
verified = 6e6fbf44…). Bytes restored from that archive; the first
`intake-first-q02 --apply` correctly **refused** (`compile_ex5_sha256_mismatch`)
while the file was stale — the guard worked as designed. After the restore the
intake applied cleanly. Follow-up hazard closed: all 4 Q02 rows are now bound
to the fresh identity at claim time, so the next hourly sweep can no longer
split the lineage. (The worktree ex5 remains intentionally uncommitted per the
EX5_COMMIT_GUARD precedent; old bytes remain git-preserved.)

## 4. Exclusion lift (hash-bound)

- `3f092f0a5029f483da2d25086245ecb53ebe1be79c28245b0451d93b6c45f3f3` (D2A
  after) → `a614bfc2bf587eb8b2a3b2b059b59a9a33af3ea3b472b41e582f3c6c2d68682a`
- Removed ONLY the standalone `QM5_11731` line (166 → 165 lines, verified);
  backup `requeue_excluded_eas.txt.before_D4_lift`; machine record
  `d4_lift_hashes.json`. Lift executed only after the valid fresh build
  identity existed (precondition recorded in the lift record).

## 5. Canary + pilot checks a–e

- `farmctl intake-first-q02 --compile-work-item-id 528c42c5-… --apply`
  → exactly ONE Q02 row **`55d28c4a-75fd-4084-9444-18666b364dc5`**:
  EURUSD.DWX M5, contract `qm-q02-canary-fanout/v1`, canary_index 1,
  cohort_size 4; GBPUSD/USDCHF/USDJPY deferred under
  `q02_deferred_symbols.json`. Receipt at
  `D:\QM\strategy_farm\artifacts\receipts\first_q02_intake\528c42c5…_55d28c4a….json`.
- Claimed by worker **T1** (worker PID 12184, runner PID 15204) 1 s after
  mint; governed re-run handoff to **T4** (terminal PID 15628);
  **done/PASS at 12:17:31Z** (~6 min).
- Final evidence `…\20260916_121346\summary.json` (run_smoke/v2):
  - (a) **data integrity PASS** — custom-history admission ACTIVE (108 archive
    rows), news calendar OK (0 mismatches), expert/setfile hashes verified
    before/after, stable during run.
  - (b) **normal claim** — governed CAS claims by resident workers (T1→T4
    re-run handoff; no failed verdicts; attempt_count 0).
  - (c) **Model-4 Every Real Tick** — `model: 4`, `evidence_class: REAL_TICKS`,
    `model4_log_marker_detected: True`, window 2018.07.02–2022.12.31 (canonical
    Q02 window).
  - (d) **valid evidence** — deterministic, 1 run exit 0, 1,784 trades
    (≥ 25 floor), report.htm 3,753,622 bytes sha256-bound, logger sample
    authenticated, reason_classes ['OK'].
  - (e) **no setup/data failure** — `oninit_failure_detected: False`,
    `log_bomb_detected: False`, `non_ok_attempts: 0`, no INFRA/DATA classes.
- Economics recorded for later gates: net −99,122.99, DD 99.18%, PF 0.65 —
    a legitimate economic signal (poor), not a setup failure. Q02 verdict is an
    integrity PASS; economic gates come later (same precedent as D2A's 11561).

## 6. Fanout (governed mechanism)

- Pilot CLEAN → `sweep_enqueue_built_eas.py --apply --ea QM5_11731
  --max-part2-per-run 0` (dry-run first: 3 promotions, parts 1–2 idle).
- Part-3 decision `RELEASE` (`economic_or_heterogeneous_canary`) promoted
  GBPUSD.DWX / USDCHF.DWX / USDJPY.DWX; rows `5b514f67…` (T10), `bb70676c…`
  (T8), `9e3b0a5a…` (T7) — all claimed within seconds, all bound to ex5
  6e6fbf44…. Deferred-file entry consumed. Fanout verdicts proceed on the
  normal worker path outside this decision's scope.

## 7. State / guardrails attestation

- No old ex5 deleted/un-committed by me; no historical build task reopened; no
  hand-written DB rows; no terminal touched manually.
- Exclusion file now `a614bfc2…`, zero `QM5_11731` references — the pump may
  see the EA, and every Q02 row is a governed one.
- Worktree ex5 left uncommitted per EX5_COMMIT_GUARD precedent
  (41475–41477 pattern); bytes archived at the 12:00 sweep + restorable.

## 8. Commits (path-scoped, agents/board-advisor)

- `98207717da` — authority registration (code + decision doc + registration receipt)
- `b314e812ec` — enqueue/release/lift/intake evidence
- final — this receipt + RECEIPT.md index

## 9. Terminal / PID capture

| Step | Terminal | Worker PID | Runner/Tester PID |
|---|---|---|---|
| COMPILE_EA 528c42c5 | T3 | (resident) | MetaEditor via build_check |
| Q02 canary 55d28c4a | T1 → T4 | T1 = 12184 | T1 runner 15204; T4 tester 15628 |
| Fanout 5b514f67 (GBPUSD) | T10 | resident | — |
| Fanout bb70676c (USDCHF) | T8 | resident | — |
| Fanout 9e3b0a5a (USDJPY) | T7 | resident | — |

## 10. STOP

None. D4 executed to completion within its OWNER conditions. The one incident
(worktree-clean revert) was detected by the governed hash guard, resolved from
the sweep's own archive, and left documented for the operators' hygiene runbook
(scoped sweeps should prefer `--ea` targeting; a fresh uncommitted COMPILE_EA
ex5 is otherwise exposed between compile and Q02 binding).
