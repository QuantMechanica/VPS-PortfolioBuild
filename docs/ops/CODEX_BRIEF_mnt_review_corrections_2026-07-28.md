# CODEX BRIEF — MNT Review Corrections + Chain 003→002→004 Kickoff (2026-07-28)

**From:** Claude (operation lead) · **Review basis:** 8-agent read-only verification of your MNT-001..042 maintenance audit, run 2026-07-28 21:20–21:50 against `farm_state.sqlite`, `D:\QM\reports`, T_Live logs, scheduled tasks, repo and vault. Full review: vault `Maintenance/Review Claude 2026-07-28.md` — **you cannot read G: from the headless lane (SYSTEM has no G: mount)**, so every fact you need is inlined below. Do not attempt vault writes; deliver page updates as repo files (WP-A).

**Overall verdict on your audit:** substantially excellent — nearly every numeric claim reproduced exactly. The corrections below are root-cause and scope fixes, all evidence-bound.

---

## WP-A — Correct six MNT pages (deliver as repo files, Claude mirrors to vault)

Write full replacement page bodies to `docs/ops/mnt_page_updates_2026-07-28/MNT-0NN.md` (same structure as your originals: Problem / Lösungsvorschlag / Akzeptanzkriterien, German). Keep your authorship line, add `Korrigiert nach Review Claude 2026-07-28`. Required changes:

### MNT-001 (KS baselines)
- Root cause of the 11 hash mismatches is missing from the page: **two divergent baseline directories**. EAs load from `C:\QM\mt5\T_Live\MT5_Base\MQL5\Files\QM\baselines` (54 files, all regenerated 2026-07-25 11:41); `health.py::chk_ks_baseline_dormancy` binds expected hashes to `C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\Common\Files\QM\baselines` (mtimes 07-20..07-25). Solution step 3 must reconcile these to ONE source of truth.
- Add acceptance criterion: `live_book_pulse.json` (schema v2) currently reports verdict=OK while KS is 0/24 dormant — the pulse must surface a KS-baseline metric; a green pulse over a dead kill switch is a monitoring hole.

### MNT-002 (live supervisor)
- Contract drift confirmed (3.659 `start_blocked_task_contract` cycles; drift = `QM_T_Live_AtLogon`/`QM_FTMO_AtLogon` AllowDemandStart=True vs expected false, `QM_Live_MT5_SessionSupervisor` trigger_count=2 vs expected 1; see `T_Live_Watchdog.ps1` contract lines ~315–387). **But the theory is insufficient:** a second watchdog (`live_supervisor_watchdog.log`) is NOT contract-blocked and has issued 666 successful `Start-ScheduledTask` kicks — the heartbeat (`D:\QM\reports\state\live_session_supervisor.json`, last_checked 2026-07-26T15:34Z, age ~52h) never refreshed. A started supervisor writes no heartbeat: the engine dies after start or the start is a 0x800710E0 queue no-op. The page needs step 0: root-cause why a started supervisor produces no heartbeat (see WP-B.1). Fixing only the contract will likely not meet your own acceptance criterion.

### MNT-017 (Q05/Q06 stress provenance)
- Count correction: not 14 — **18 identical (ea,symbol) pairs across 13 EAs, all Q06 verdict=PASS** (KPIs byte-identical incl. net_profit to the cent; exemplar QM5_1116/EURJPY pf=1.08, trades=679, net 30052.25 in both runs).
- **Root cause is EA-side, not runner-side:** offending EAs never declare `qm_stress_reject_probability` as an input (QM5_1116: 8-positional-arg `QM_FrameworkInit`, no stress/seed inputs) → MT5 silently ignores the injected set key. Baskets have a second bypass in `QM_BasketOrder.mqh` (inert until recompile --force). Counter-example proving the wiring works when present: QM5_10440 (input declared line 30, passed at FrameworkInit arg 14) shows real stress effect. Hash/seed binding stays right, but the remedy is **rebuild offenders with the wired input** — say so explicitly.
- Add retroactive scope: 13117 and 12778 (Track B baskets) and 1567 are already promoted/live on this vacuous evidence; the page currently only gates future runs.

### MNT-018 (Q07 seed auth)
- The proposed fail-closed `SEED_AUTH_FAIL` path **already exists** (WP-10): QM5_1116/EURJPY already terminated INFRA_FAIL with `seed_evidence_missing:...:effective=None` (work_item b37c01d6, all five seeds identical 679 trades). Detection is not the gap.
- The real gap is the stamped legacy: **23 Q07-PASS rows with variance_pct=0.00** (~20 sleeves), **105 of 243 Q07-PASS rows (43%) with no aggregate.json on disk**, and **QM5_13128/NDX (LIVE, magic_numbers.csv:14958) whose only Q07 row is a parse_error backfill stamp** (work_item 37308752, source=parse_error, pf/trades NULL, payload `backfill: requal_wave_20260717` — no run ever happened). Priority is inverted: the page names QM5_1116 (not in the book) and omits 13128 + 1567/EURUSD (live).
- Step 3 ("rerun with unchanged binaries") is **unfulfillable in principle** for offenders: the binary lacks the `qm_rng_seed` input (default 42 hardcoded via `QM_Common.mqh:128`), so an unchanged-binary rerun reproduces `effective=None` forever. The control cohort must include rebuilt binaries. Cross-reference the new pages MNT-043 (fleet recompile) and MNT-044 (retro re-adjudication) — both exist in the vault ledger since today.

### MNT-019 (T5 A/B probe)
- The A/B design has no valid control arm: instrumented QM5_20096 shows `BarsCalculated=-1` with valid handles **identically on T2, T3 and T10** (healthy terminals; STRATEGY_DIAG logs, e.g. h_sma=10/h_sto=11, bc=-1, bars=2366+) and **never ran on T5 at all**; your designated control QM5_11144 is itself in the BarsCalculated cohort with **zero PASS anywhere in the DB** (Q02: 6×INFRA_FAIL, 3×ZERO_TRADES, 1×FAIL, 4×None). A "healthy PASS vs T5 FAIL" split cannot be constructed.
- Rewrite the probe: pick a control EA with PROVEN positive BarsCalculated (e.g. QM5_11912 or QM5_20102 — the only cohort members with Q02 passes), and expect the outcome to be branch 4 (shared framework path). Prime suspect: `QM_Indicators.mqh` handle-cache (`QM_IndicatorsRegister/Lookup` registering a not-ready handle; wrappers are built-ins iMA/iStochastic, lines ~270–278, 444). The T5 whole-instance-rebuild branch is unlikely to ever trigger.

### MNT-040 (status aggregator)
- The page's suspected culprit is half wrong: `pipeline_state.json` (`scripts/build_pipeline_state.py`, source=work_items) already models stage correctly (exposes latest_pass_phase; QM5_10035→Q04, QM5_10002→Q03, no bug). The defective aggregator is **`farmctl.py::pipeline_view`** (the `farmctl pipeline` CLI, ~line 2151, overwrite loop ~2200–2235): reads only the legacy `tasks` table ORDER BY created_at, last-created-wins, and is structurally blind to ~94% of canonical gate evidence (793 backtest_q03 task rows vs 12.717 Q03 work_items). 121 EAs currently affected; airtight example QM5_10035 (current_stage=build_failed despite later Q03 PASS wi 9067e667). Point the fix at pipeline_view; also fix its latent type bug (ea_review payload verdict sometimes str, `.get` chain assumes dict).

### Minor folds (one line each, into the respective update files if you touch them; otherwise list them in the evidence doc as acknowledged):
- MNT-003: acceptance query must filter `Principal.LogonType=Interactive` — raw `0x800710E0` matches 8–9 tasks (SYSTEM tasks show the code transiently while State=Running).
- MNT-004: watchdog doesn't just alarm — it actively relaunches the parked terminal (consecutive_relaunch_failed=37); second observer `ftmo_trial_pulse.json` (ALARM every 30 min, equity snapshot 4.9d stale) and failing `QM_FTMO_AtLogon` (0x2) must be covered; the fix must flip the baked-in `expected_ftmo_profile`/maintenance fields, not add a parallel file.
- MNT-006/008: acceptance criteria must pin invariants/queries, not absolute integers (242/221 drifted to 251/230 during audit, delta constant 21 = 18 ZT + 3 INV; the 35 is exact only at cold-cache cap 3); `valid_zero` routes to the RETIRE/frequency-floor lane, not retry; 446 legacy `phase='P2'` rows are invisible to the check.
- MNT-007: `requeue_stranded_infra.py` already exists (the missing piece is a health invariant + automation); Q04 is growing (1106→1550 groups in 3 days); Q08 "infra-only" is 35/40 `phase_runner_invalid_report` → reclassify INVALID, never requeue.
- MNT-009/-010: the 832 are a closed legacy window (07-14/15); evidence backfill should cover the full corpus (99.4% of INFRA rows lack evidence_path while report_root/log_path sit in payload and exist on disk); MNT-010's "all children terminal" is only well-defined after MNT-009 migrates NULL-verdict children — sequence 009→010.
- MNT-012: cards are internally contradictory (frontmatter r3=PASS vs body table R3=UNKNOWN) — fix frontmatter+G0 logic; 20062's .ex5 lives in `C:\QM\repo\framework\EAs\...`, not the factory tree.
- MNT-013: the heterogeneity justification is refuted — all 445 are currently R-gate-READY (`not_build_ready=0`); keep the preflight as guardrail, fix the rationale.
- MNT-015/-016: define the measurement window (calendar-day 3150 vs rolling-24h 5741); lifetime 296.667 rows = ~92% of the events table; taxonomy contamination is bidirectional (274 INFRA→strategy AND 15 FAIL + 56 INVALID→infra; 13 PASS rows still carry `verdict_reason=run_smoke_fail:...`) and the invariant must cover `verdict_reason`, plus the INFRA_FAIL status split (8377 done + 44874 failed).
- MNT-021: register needs self-dedup first (11132/SP500 triple, 10715/USDJPY double). MNT-036: pin probation start = **2026-07-13** (EA first-log 06:28–06:36Z; 07-19 anchor would miss the review by 6 days). MNT-041: the "cap: T5" suffix misattributes quarantine as RAM throttle and the check stays OK/green — design capacity must drive check STATUS (WARN), not a detail suffix.

## WP-B — Chain 003→002→004 kickoff (branch-only; NO live system mutation from headless)

1. **Root-cause the supervisor no-heartbeat** (new step 0 of MNT-002): why does a started `QM_Live_MT5_SessionSupervisor` write no `live_session_supervisor.json`? Inspect the task action + supervisor entry script for the known PS5.1 stderr-trap class (EAP=Stop + 2>&1 terminates tasks; fix pattern = pythonw direct), 0x800710E0 queue semantics, and G:-dependency at startup. Deliver a written diagnosis with log/code line evidence.
2. **Per-task disposition matrix for the seven 0x800710E0 tasks:** SYSTEM-eligible (AgyGovernor, CodexFleetPacer, GeminiOrchestration_15min, MailboxSourceIntake_Daily, WorkerDedupe) vs interactive-required (T_Live_AtLogon, Live_MT5_SessionSupervisor — MT5 GUI in session 3; these CANNOT move to SYSTEM). For each: target principal, LogonType, trigger set, G:/desktop dependencies, fallback.
3. **Change package, not change execution:** before/after task XML exports, rollback XML, and an idempotent apply script (to be run by Claude/OWNER in the interactive session). You do NOT modify scheduled tasks, do NOT start/stop tasks, do NOT touch T_Live or AutoTrading.
4. **MNT-004 park-awareness in code:** implement the expected-state contract in the watchdog/pulse sources (uptime watchdog + `ftmo_trial_pulse` + alarm-state writer): tri-state RUNNING/PARKED/MAINTENANCE with review expiry, `PARKED+OFF=OK`, `RUNNING+OFF=ALARM`, stop the relaunch loop for PARKED, single escalated alarm after N identical contract failures. Flip the baked-in FTMO expectation; unit-test the state table.

## Constraints

- Work in your worktree/branch only (DL-065: codex=branch-only). Explicit pathspec commits.
- No Factory_OFF/ON, no scheduled-task mutation, no process kills, never T5 activation, never T_Live/AutoTrading, no `.DWX` re-imports.
- Evidence over claims: every asserted fact carries a path/query/log line.
- G: is unavailable in your lane — all vault-bound content is delivered as repo files.

## Deliverables

1. `docs/ops/mnt_page_updates_2026-07-28/MNT-001|002|017|018|019|040.md` — full corrected page bodies (German).
2. `docs/ops/evidence/2026-07-28_mnt_review_corrections.md` — WP-B diagnosis (step 1), disposition matrix (step 2), acknowledgment/positions on the minor folds.
3. Change package under `tools/ops/task_contract_fix_2026-07-28/` (XML before/after/rollback + apply script, unexecuted).
4. Code changes for WP-B.4 on your branch with tests.

Set the task to REVIEW with artifact paths; I close-review substantively. Priority: this precedes new feature work; backtests are never throttled by this.
