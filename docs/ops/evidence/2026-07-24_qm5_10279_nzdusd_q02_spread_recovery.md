# QM5_10279 NZDUSD Q02 Infrastructure Recovery

**Observed:** 2026-07-24T18:38:31Z

**Branch:** `agents/board-advisor`

**Outcome:** `REPAIRED_AND_REQUEUED_PENDING_CPU_CAPACITY`

## Non-duplicate diversity selection

The approved-card build backlog did not contain a higher-priority feasible
diversity build at selection time:

- `QM5_20062` forex was already claimed by another paced worker.
- `QM5_1457` rates lacked a DWX rates/bond input.
- `QM5_1459` required unavailable lumber history.
- `QM5_20058` copper was already blocked because `XCUUSD.DWX` was absent.
- `QM5_20061` DAX was active elsewhere and would not improve the
  index/metal/energy concentration.

The next mission priority was therefore used: recover a diverse built EA stuck
at Q02 for infrastructure reasons. `QM5_10279_whc-roc-ma` is an approved,
low-frequency D1 momentum/trend strategy whose card explicitly permits major
FX `.DWX` symbols. It uses fixed ROC(12), SMA(10/30), and ATR(14) mechanics,
has an expected frequency of about eight trades per year per symbol, and
contains no ML, adaptive parameters, grid, or martingale. Its R1 record is
`PASS` against the exact public `whchien/ai-trader` repository and
`ROCMAStrategy` source file. `NZDUSD.DWX` adds forex exposure absent from the
current certified/survivor concentration.

The farm claim was created before editing:

```text
agent_task: 6527fee2-6903-4ae6-a8de-8366480323d1
claimed_by: codex:agents/board-advisor
ea/symbol:  QM5_10279 / NZDUSD.DWX
```

The guarded transaction confirmed no other open Q02 row for this EA/symbol and
no competing open agent task.

## Infrastructure repair

The historical Q02 row had exhausted two attempts as `INFRA_FAIL` with
`summary_missing_retries_exhausted`. The prior review also identified a
file-scoped execution defect and stale build: the EA had no mandatory spread
guard.

The repair:

- adds `strategy_max_spread_points=80`;
- blocks new entries when the current positive spread exceeds that cap;
- preserves zero-spread synthetic history behavior;
- documents the execution guard in `SPEC.md`;
- rebuilds the `.ex5`; and
- refreshes the build hash in all eleven generated backtest setfiles.

This is execution hygiene, not a change to the card's alpha mechanics.

The farm's deterministic auto-commit pump preserved the repaired target paths
on this branch in commit `2b476617079ae3266839fe5e5fb66904234b5590`.

## Build evidence

```text
python framework/scripts/validate_spec_doc.py framework/EAs/QM5_10279_whc-roc-ma
PASS: 1/1

python tools/strategy_farm/compile_ea.py --ea-label QM5_10279_whc-roc-ma --force --json --fail-on-error
COMPILED: 0 errors, 0 warnings

powershell -ExecutionPolicy Bypass -File framework/scripts/build_check.ps1 -EALabel QM5_10279_whc-roc-ma -Strict -SkipCompile
PASS: failures=0, warnings=0
```

Artifacts:

```text
compile log: C:\QM\repo\framework\build\compile\20260724_183248\QM5_10279_whc-roc-ma.compile.log
build check: D:\QM\reports\framework\21\build_check_20260724_183314.json
MQ5 SHA256:  714813b31223879ddca70bab94070aefd12c74ba90195340e3ea0ff35df30c32
EX5 SHA256:  8abee383bb25eaa5807a553d884700f6699a6d6c81e9276bc61d65be1f51a2c5
build hash:  6eaa525d4d6894c06c20f4b1ca51fa7790271d0da86f5532c54a060acf29fb24
```

The NZDUSD setfile remains deterministic fixed risk:

```text
qm_magic_slot_offset=10
RISK_FIXED=1000
RISK_PERCENT=0
PORTFOLIO_WEIGHT=1
```

EA ID `10279` and NZDUSD magic `102790010` were already allocated and active;
no registry row was changed.

## Q02 handoff

The existing failed work item was reopened in place; no new work item was
inserted:

```text
work_item:           7222c820-5537-454f-a605-13984b2904d7
phase:               Q02
symbol/timeframe:    NZDUSD.DWX / D1
state at handoff:    pending
attempt_count:       0
window:              2017.01.01 through 2022.12.31
history registry:    2017 through 2024 on T1-T10
effective minimum:   30 trades (5/year over 6 years)
risk mode:           RISK_FIXED
repair reason:       mandatory_spread_guard_and_stale_ex5_rebuild
```

Before mutation, the SQLite state was copied and passed `PRAGMA quick_check`:

```text
D:\QM\strategy_farm\state\backups\farm_state_before_qm5_10279_nzdusd_q02_requeue_20260724T183830Z.sqlite
```

## CPU-ceiling stop

At the guarded requeue, six factory terminals were visible (`T1`, `T2`, `T6`,
`T7`, `T8`, and `T10`), below the seven-process ceiling. The canonical
saturation scheduler was then run read-only:

```text
python -m framework.scripts.mt5_saturation_scheduler \
  --sqlite D:/QM/reports/pipeline/mt5_queue.db \
  --dispatch-state D:/QM/reports/pipeline/dispatch_state.json \
  --dry-run
```

It reported:

```json
{"available_slots_after":0,"available_slots_before":0,"dry_run":true,"duplicate":0,"invalid":0,"no_capacity":0,"queued_scanned":0,"scheduled":0,"status":"ok"}
```

The Q02 row is therefore left pending for normal paced dispatch. No manual
smoke, dispatcher tick, pipeline phase, MT5 launch, or backtest was run.

## Safety boundary

`T_Live` was excluded from capacity checks and was not controlled. AutoTrading,
live setfiles, the deploy manifest, portfolio gate, portfolio-admission state,
and Q08 contribution artifacts were not touched.
