# DL-089 Wave 1 batch 2 unstall: force-rebuild classifier + compile-timeout diagnosis

Router task: `05084e43-581e-40e3-9f0c-1c5b002849de` (claude, ops_issue)
Branch: `agents/board-advisor`
Context: `docs/ops/evidence/2026-08-22_execution_contract_requal_flag_crosscheck.md`,
`docs/ops/evidence/2026-08-21_compile_ea_pipeline_251b9724.md`,
`docs/ops/evidence/2026-08-21_dl089_wave1_batch1.md`,
`docs/ops/evidence/2026-08-21_dl089_wave1_batch2_partial.md`.

DL-089 Wave 1 batch 2 has been stalled at 5/21 EAs since 2026-08-21: the governed
`COMPILE_EA` queue (`251b9724`) only admits candidates with **no existing `.ex5`**,
but every DL-089 EA is live-deployed and therefore already has one.

## Part A: COMPILE_EA classifier force-rebuild allowlist

Commit `b2e5ce3ce` (`tools/strategy_farm/compile_work_items.py`,
`tools/strategy_farm/tests/test_compile_work_items.py`):

- `dl089_force_rebuild_allowlist(repo_root)` fail-closed intersects a hardcoded
  16-id set (`DL089_FORCE_REBUILD_EA_IDS`) with the live
  `framework/registry/owner_priority_tracks.json` rows carrying the exact
  `owner_reference: OWNER_DECISION_2026-08-21_DL-089_LIVE_BOOK_REQUALIFICATION`.
  An OWNER revocation in the registry turns the bypass back off with no code
  change; the hardcoded id alone is never sufficient (tested).
- `classify_candidate(..., force_rebuild_ea_ids=...)` waives exactly
  `EX5_ALREADY_PRESENT`, `WORK_ITEMS_EXIST`, `BOUND_SETFILE_HASH_EXISTS`, and
  `BUILD_TASK_EXISTS` for authorized ids only. Every structural guard (EA-ID
  registry active, active magic rows present, resolvable timeframe, no open
  `COMPILE_EA` row for the same EA) still applies unconditionally to this cohort
  and to everyone else — this is not a general `.ex5`-overwrite path.
- `enqueue_compile_eas` now also bypasses its apply-time `WORK_ITEMS_EXIST_AT_APPLY`
  race-guard for force-rebuild-authorized candidates, and stamps the resulting
  payload with `force_rebuild: true`, the owner_reference, and the exact list of
  waived reasons, so the audit trail survives on the work-item row itself.
- `run_compile_work_item`'s claim-time candidate recheck also resolves the
  allowlist fresh (not from the enqueue-time payload), so a mid-flight OWNER
  revocation still fails the row closed before any compile runs.

Tests: `tools/strategy_farm/tests/test_compile_work_items.py` — 12 passed (3 new:
bypass-with-registry-entry, fail-closed-without-registry-entry,
never-waives-structural-guards). Adjacent regression suite (`test_include_mirror`,
`test_pattern_fixture_harness_dispatch`, `test_terminal_worker_atomic_claim`,
`test_farmctl_scope_audit_isolation`, `test_build_guardrails`): 108 passed.
`python -m py_compile` clean on both changed files.

**Shared-checkout note:** while this change was in progress, a concurrent session
(codex, router task `1fb9943f-1b87-4515-b2b4-f5ca3ffb56f8`, "COMPILE_EA worker
rollout") independently added an unused `FORCE_REBUILD_OVERRIDE_REASONS` constant
to the same file. It was left in place uncommitted-then-committed as-is (no name
collision, not wired into any function) for that session to reconcile — it was not
removed or edited by this task, since doing so risked discarding live in-flight
work in a shared, unisolated checkout.

## Part B: compile_one.ps1 120s timeout — root cause

The batch-2 stall (`b2bf2460`) hit `compile_one.ps1 timeout after 120s` via
`python tools/strategy_farm/compile_ea.py --ea-id 10919 --force`. Read of both
scripts:

- `compile_ea.py:315` hardcodes `subprocess.run(cmd, ..., timeout=120)` around its
  own direct `pwsh.exe compile_one.ps1` invocation. This is the **only** place a
  120-second ceiling exists anywhere in the compile path.
- `compile_one.ps1` itself has no internal timeout.
- `build_check.ps1` (`Invoke-CompileGate`, line ~248) calls
  `& $ResolvedCompileScriptPath @compileParameters` as a direct in-process
  PowerShell invocation — again no internal timeout of its own.
- The governed `COMPILE_EA` worker (`run_compile_work_item` in
  `compile_work_items.py`) calls `build_check.ps1` with
  `subprocess.run(..., timeout=1800)` — 15x the ad-hoc tool's budget — and this is
  exactly the path `251b9724`'s own evidence names as the sanctioned live-factory
  route (`compile_one.ps1`/`build_check.ps1` refuse ad-hoc compiles while any
  terminal is live and name `farmctl.py enqueue-compile` as the alternative).

**Conclusion: no change to `compile_one.ps1` or `build_check.ps1` was made.** The
120s ceiling lives exclusively in `compile_ea.py`, the deprecated ad-hoc wrapper
that `251b9724` built `COMPILE_EA` to replace for exactly this scenario. Raising
that hardcoded budget would resurrect a path the system already moved off of;
routing the 16 EAs through the governed queue (Part A) gives them the existing
1800s budget for free. This matches recommendation (a) from the crosscheck
evidence and answers recommendation (b) by explaining why the timeout was never a
`compile_one.ps1` defect.

## Enqueue: 16 EAs, activation-hold regime matching 251b9724

`compile_work_items.enqueue_compile_eas` invoked for the exact 16 remaining
Wave-1 labels (resolved against `framework/EAs/` directory names; `QM5_13301` has
two on-disk directories, `magic_numbers.csv`/`ea_id_registry.csv` both bind the
active row to `balke-minute-range-breakout`, so that is the label used):

`QM5_1556_aa-zak-mom12`, `QM5_1567_demark-td-reverse-sequential-h4`,
`QM5_10919_grimes-overshoot`, `QM5_10939_grimes-context-pb`,
`QM5_11132_tm-cum-rsi2`, `QM5_11165_weiss-rsi-ma`,
`QM5_11421_ohlc-daily-squeeze-reversal-d1`, `QM5_11708_anon-market-squeeze-d1`,
`QM5_12567_cum-rsi2-commodity`, `QM5_12778_edgelab-audusd-eurjpy-cointegration`,
`QM5_12969_usdjpy-gotobi-nakane-fix`, `QM5_12989_grimes-nested-pb-v2`,
`QM5_13117_eurgbp-audjpy`, `QM5_13128_pre-fomc-drift-ndx`,
`QM5_13213_balke-gmt3-range-breakout`, `QM5_13301_balke-minute-range-breakout`.

Result: `requested_count=16, eligible_count=16, enqueued_count=16, refused_count=0`.
All 16 rows verified directly in `work_items`/`work_item_holds`:

- `status='pending'`, `verdict=NULL` on every row (no gate verdict, per contract).
- Hold `COMPILE_EA_WORKER_ROLLOUT_PENDING`, `active=1`, `release_on_restart=1` on
  every row — the identical activation-hold regime `251b9724` used for its
  original 82-row batch. Nothing was released; these 16 join the same held queue
  and require the same governed release-on-restart ceremony before any worker can
  claim them.
- Payload on every row carries `force_rebuild: true`,
  `force_rebuild_owner_reference: OWNER_DECISION_2026-08-21_DL-089_LIVE_BOOK_REQUALIFICATION`,
  and the per-EA waived-reason list (`EX5_ALREADY_PRESENT`, `WORK_ITEMS_EXIST`,
  `BOUND_SETFILE_HASH_EXISTS`, and `BUILD_TASK_EXISTS` where applicable),
  `risk_contract: {RISK_FIXED: 1000.0, RISK_PERCENT: 0.0}`.
- No duplicate: none of the 16 had a pre-existing `COMPILE_EA` row before this run
  (checked immediately before enqueue).

No T_Live binary, chart, setfile, or AutoTrading state was touched. No
`terminal64.exe` was started. No active backtest was interrupted. This enqueue
only inserts held, pending database rows — the held queue does not compile
anything until a separate, governed release step runs.

## Remaining scope for OWNER/next continuation

- The 16 rows are held, not released. Releasing them (and confirming the resident
  terminal-worker fleet all runs the reviewed `COMPILE_EA`-aware code, and that
  the R11 utility-phase exemption already live in `repair.py` holds under real
  load) is governed rollout work, not performed here.
- Task `1fb9943f` (codex) is independently working the broader COMPILE_EA
  rollout/release-wave mechanism; whoever releases the hold should reconcile
  against that session's own in-flight changes to this same file first.
