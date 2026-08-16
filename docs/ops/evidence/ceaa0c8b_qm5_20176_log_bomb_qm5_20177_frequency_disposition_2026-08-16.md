# QM5_20176 log-bomb repair and QM5_20177 frequency disposition

Date: 2026-08-16 (Europe/Berlin)

Router task: `ceaa0c8b-0d37-4f5d-a029-891efe5ea90c`

Branch: `agents/board-advisor`

Disposition: REVIEW. `QM5_20176` is repaired, compiled, guardrail-clean, and has one append-only GBPUSD Q02 successor pending. `QM5_20177` is retired at its current approved mechanics after six terminal Q02 frequency-floor failures. No pipeline verdict is asserted for the pending successor.

## QM5_20176 root cause

The terminal GBPUSD Q02 source row is `14d7de3e-25fc-42fd-b769-9ce63772341b`. Its bound `run_smoke/v2` summary reports `LOG_BOMB,INCOMPLETE_RUNS`; the worker killed the tester journal at 0.66 GB while its observed growth rate exceeded the 1,500 MB/min guard (about 1,689 MB/min). The execution identity was stable and bound the pre-repair EX5 SHA-256 `8f9daac1b7818a0f0daaf3ce497fea4e025a08c543aa50f7b3bdaed4eb02ce92`.

The sibling USDJPY Q02 run completed and exposed the actual flood in its exact logger sample:

- evidence: `D:/QM/reports/work_items/cf3b93a4-d228-4563-bd3b-148a759fa26c/QM5_20176/20260816_170202/summary.json`
- structured events: 1,598,636
- logger bytes: 622,547,519
- repeated event: successful `TM_MODIFY` from Stage-1 `QM_TM_TrailATR`
- completed result: 47 trades, confirming that the flood was an execution/logging defect rather than an entry-path failure

`Strategy_ManageOpenPosition()` ran per tick. While profit remained below the Stage-2 threshold, every favorable price increment generated a slightly tighter ATR stop, one trade modification, and one `TM_MODIFY` event. The existing half-point improvement check prevented identical prices but did not bound distinct tick-by-tick targets.

## QM5_20176 repair

The EA now deduplicates trail submissions by the exact key `(position ticket, last closed H4 bar time, trailing stage)`:

- the opposite full-stack market exit remains evaluated every tick;
- Stage 1 can submit at most one ATR trail per ticket and closed H4 bar;
- Stage 2 can submit at most one PSAR trail per ticket and closed H4 bar;
- a Stage 1 to Stage 2 transition remains eligible inside the same H4 bar because stage is part of the key;
- entries, signal thresholds, risk inputs, news blackout, and Friday-close behavior are unchanged.

Files:

- `framework/EAs/QM5_20176_hopwood-ts5-standalone-h4-r1-recovery/QM5_20176_hopwood-ts5-standalone-h4-r1-recovery.mq5`
- `framework/EAs/QM5_20176_hopwood-ts5-standalone-h4-r1-recovery/SPEC.md`
- rebuilt `framework/EAs/QM5_20176_hopwood-ts5-standalone-h4-r1-recovery/QM5_20176_hopwood-ts5-standalone-h4-r1-recovery.ex5`

## Verification and append-only handoff

Build guardrails:

```text
python tools/strategy_farm/validate_build_guardrails.py framework/EAs/QM5_20176_hopwood-ts5-standalone-h4-r1-recovery
verdict=PASS
files_checked=7
max_news_stale_hours=336
findings=[]
```

Compile:

```text
python tools/strategy_farm/compile_ea.py --ea-id 20176 --force --json --fail-on-error
verdict=COMPILED
compile_one_errors=0
compile_one_warnings=0
symbol_scope_verdict=SINGLE_SYMBOL_OK
compile_log=C:/QM/repo/framework/build/compile/20260816_184626/QM5_20176_hopwood-ts5-standalone-h4-r1-recovery.compile.log
```

Rebuilt EX5 SHA-256:

```text
f92b2a3b26405741b3a477dc49b3ea7dbc634d1ba75ca0c5140c22dfde4fa6e3
```

The guarded append-only Q02 command preserved the terminal LOG_BOMB source and created exactly one current-binary successor:

| Field | Value |
|---|---|
| Historical row | `14d7de3e-25fc-42fd-b769-9ce63772341b` (`done/INFRA_FAIL`) |
| Successor row | `899fb1b4-3532-4cac-9f28-40485ea8c448` |
| Symbol / phase | `GBPUSD.DWX / Q02` |
| Initial successor state | `pending`, unclaimed, verdict/evidence null |
| Risk contract | setfile validated by build guardrails; `RISK_FIXED > 0`, `RISK_PERCENT = 0` |

The successor is left to normal `pump/dispatch-tick` ownership. No MT5 terminal was launched manually and no active backtest was interrupted. Its eventual verdict must come only from its row-bound pipeline evidence.

## QM5_20177 six-symbol frequency sweep

All six terminal Q02 summaries bind the same repaired source SHA-256 `db86cdc4d03721e67945784716a53f7c6b25f6461f723c27d6790560ab719d6a` and EX5 SHA-256 `1a2f22d4edc56afdbabd403bda0bc330c0667f7c3e859b9dc3f7c5689d5e1f09`; every summary reports stable execution identity.

| Symbol | Work item | Trades | Binding minimum | Terminal verdict |
|---|---|---:|---:|---|
| `EURUSD.DWX` | `cd946f00-aa75-4d11-b119-1cd2a2e51d90` | 8 | 25 | `FAIL / MIN_TRADES_NOT_MET` |
| `GBPUSD.DWX` | `ba38e217-fc92-4265-8678-f6c910f898e8` | 6 | 25 | `FAIL / MIN_TRADES_NOT_MET` |
| `USDJPY.DWX` | `c7f7a083-837c-470e-9501-fec5eb566f28` | 8 | 25 | `FAIL / MIN_TRADES_NOT_MET` |
| `XAUUSD.DWX` | `90c7c269-8038-4c9c-8bbf-e8747bf4ea32` | 6 | 25 | `FAIL / MIN_TRADES_NOT_MET` |
| `WS30.DWX` | `a0c57304-3d83-4e02-a414-3561736f0eb5` | 14 | 25 | `FAIL / MIN_TRADES_NOT_MET` |
| `NDX.DWX` | `cd2f56fd-ae3f-4ab0-a875-fbc77c09dc66` | 0 | 10 | `ZERO_TRADES / MIN_TRADES_NOT_MET` |

The implementation already contains the prior recovery fixes for the wired time-symmetry tolerance and the measured CD-relative time stop. With mechanics now card-conformant, the all-symbol failure is an economic cadence result, not an implementation or setup defect.

## QM5_20177 decision

Retire the current `QM5_20177_carney-ab-cd-pattern-h4-r1-recovery` mechanics from further pipeline churn under the binding floor of at least five completed packages per year. No Q02 rerun, downstream enqueue, parameter search, or silent tolerance widening is authorized.

A lower-timeframe or wider-symmetry-tolerance version would materially change the approved mechanics. It may proceed only as a new OWNER-approved Strategy Card variant with a new identity and fresh predeclared parameters; this task does not propose or approve that variant.

No EA registry or magic row is deleted by this review artifact. The six terminal Q02 rows already prevent downstream progression, and their pipeline evidence remains the canonical disposition record.

## Safety boundary

- no `T_Live` or AutoTrading change;
- no manual `terminal64.exe` start;
- no active T1-T10 backtest interruption;
- no change to `qm_news_stale_max_hours` (remains 336);
- no pipeline verdict manufactured for the pending QM5_20176 successor;
- no main or `C:/QM/worktrees/cto_main` mutation.
