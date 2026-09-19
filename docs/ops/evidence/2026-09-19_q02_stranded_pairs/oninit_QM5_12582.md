# QM5_12582 (chan-ng-spring) / XNGUSD.DWX — OnInit root-cause dig

Task: `4216dd75-6430-4ccb-b545-6c6cf6f3fd4b`. Never requeued; no verdict touched.

## Evidence used (real MT5, REAL_TICKS; no fresh run spawned this cycle — see "No fresh
reproduction" below)

- work_item `ae468d0f-2d3c-4595-9d49-6b5b00a25f75`, 2026-09-07 12:15Z, verdict `INFRA_FAIL`.
- `evidence_path`: `D:\QM\reports\work_items\ae468d0f-2d3c-4595-9d49-6b5b00a25f75\QM5_12582\20260907_121520\summary.json`
- `ex5_sha256`: `c6d66c602ce572cea369b92353aba0c6a814476733dbf536e9c3db1673786974` — identical across
  the prior 6+ attempts back to 2026-06-27 (checked in `work_items`), so this is not a
  build-drift flip between attempts.
- `oninit_failure_detected`: `true`.
- Decisive tester-log line (retained in `summary.json.runs[0].tester_log_decisive_lines`,
  raw journal itself already purged by the 2h retention policy):

  ```
  CS  2  14:15:47.277  Tester  tester stopped because OnInit returns non-zero code 1
  ```

## What this line means

`OnInit returns non-zero code 1` is MT5's tester wording for `OnInit()` **executing and
returning `INIT_FAILED` (=1)**. This is different from the `...incorrect input parameters`
wording seen on QM5_10369 (see `oninit_QM5_10369.md`) — that wording is produced when the
tester's own parameter binder rejects the `.set` file before `OnInit()` ever runs. Here,
`OnInit()` ran.

`QM5_12582_chan-ng-spring.mq5:OnInit()` contains exactly one call:
`if(!QM_FrameworkInit(...)) return INIT_FAILED;` — no other check in `OnInit`. So the
rejection happened inside the shared `QM_FrameworkInit` / `QM_FrameworkInitCoreAfterRuntimeStateArmed`
path (`framework/include/QM/QM_Common.mqh`), which has five internal `return false` branches:
`runtime_state_not_armed`, `ea_id_non_positive`, `portfolio_weight_out_of_range`,
`risk_inputs_invalid`, `magic_resolution_failed`.

## Checked, not assumed — ruled out statically

- **Not a source-level hard input pin** (the known `project_qm_inputsvalid_framework_pin_defect_2026-08-20`
  class): `grep -n "QM_InputRequire" QM5_12582_chan-ng-spring.mq5` → 0 hits. The EA does not
  hard-pin `qm_rng_seed`, `qm_stress_reject_probability`, or any framework-owned input.
- **Not a missing/mismatched magic registry row**: `framework/registry/magic_numbers.csv` has
  `12582,chan-ng-spring,0,XNGUSD.DWX,125820000,...,active`, matching the set file's
  `qm_magic_slot_offset=0` and symbol exactly.
- **Not an out-of-range risk/portfolio input**: the deployed set
  (`sets/QM5_12582_chan-ng-spring_XNGUSD.DWX_D1_backtest.set`) declares
  `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1` — all within the validator's
  accepted ranges on paper.
- **Not build drift between attempts**: identical `ex5_sha256` across 6+ independent runs
  since 2026-06-27.

## Not yet determined

Which of the five internal `QM_FrameworkInitCoreAfterRuntimeStateArmed` branches actually
fires cannot be read off disk: no worker-level log survived for this work item
(`D:\QM\strategy_farm\logs\work_item_ae468d0f-....log` does not exist), and the raw MT5
journal (which would carry the `QM_LogEvent(QM_ERROR,"FRAMEWORK_INIT_FAILED",...)` /
`EA_MAGIC_NOT_REGISTERED` / `EA_MAGIC_RESOLUTION_FAILED` Print line) is already purged
(`QM_StrategyFarm_ReportsLogPurge_12h`, 2h retention). `logger_sample_path` in `summary.json`
is `null` for this run.

## No fresh reproduction this cycle — why

The acceptance criterion asks for a governed, non-factory-claim `run_smoke` reproduction.
That was attempted and explicitly **not** completed, for reasons recorded once at the top
level: see `oninit_rootcause_4216dd75.md` §"Why no fresh out-of-claim run was spawned".
XNGUSD.DWX is a Custom-history symbol; the only terminals outside the automated T1–T10
claim fleet (T11/T12) do not carry its privatized `Bases\Custom` data, and this session's
Windows identity (`SYSTEM`, headless scheduled task) cannot use the isolated `DEV1`/`DEV2`
lanes, which require the `QMDev1`/`QMDev2` account SID.

## Classification

**Neither** of the two named buckets fits cleanly:

- Not "source/setfile defect" in the `QM_InputRequire`/hard-pin sense — none exists in this
  source file.
- Not "dead hypothesis / RETIRE" — the registry entry is live, `RISK_FIXED`/`PORTFOLIO_WEIGHT`
  are valid, and a 0-trade `INIT_FAILED` is not an economic (frequency-floor) failure; RETIRE
  does not apply to an unresolved infra predicate.

**Disposition: `UNRESOLVED_REQUIRES_INSTRUMENTED_REBUILD`** — same remediation pattern as the
2026-08-17 precedent (`docs/ops/evidence/2026-08-17_bars_zero_is_oninit_rejection_misclassified_as_infra.md`):
add `QM_LogEvent`/`QM_InputRequire*`-style self-describing predicates to each `return false`
branch inside `QM_FrameworkInitCoreAfterRuntimeStateArmed` (they already exist for
`magic_resolution_failed`, but the log only survives if a fresh run's raw journal or logger
sample is captured before the 2h purge), then re-run once on a real T-slot to capture which
branch actually fires. That is Codex build-lane work (compile + dispatch), not something
resolvable from static source reading. **No requeue performed.**
