# QM5_11205 FX build repair and Q02 enqueue — 2026-08-05

## Outcome

`QM5_11205_ft-adx-smas` is now a current-framework, compile-clean EA with
fixed-risk H1 setfiles for its full approved four-symbol universe. The governed
`record-build` transition created three priority-track Q02 work items. The
fourth symbol, `USDJPY.DWX`, was preserved in the farm's staged-deferred file by
the three-symbol cohort limiter; that limiter was not bypassed.

No manual MT5 backtest, T_Live action, portfolio-gate mutation, or live-manifest
change was performed.

## Selection and dedup guard

- The initial `QM5_11561` fallback was rejected before commit or enqueue: it is
  listed in `requeue_excluded_eas.txt` as a greater-than-100-trades/year FX EA,
  and the research inventory identifies four copies of the same Singh strategy.
- A strict farm-state scan found no low-frequency diverse Q02/Q03 INFRA failure
  that was both unclaimed and free of an existing Q02 PASS, later strategy
  verdict, or pending recovery row.
- `QM5_11205` was the highest-quality genuine uncompiled FX card remaining with
  an active EA identity and complete magic allocation. It had no `.ex5`, no
  work items, and one terminal historical build failure.
- The nearby `QM5_11199_ft-fadxsma` is not the same implementation: it uses the
  separate `FAdxSmaStrategy.py` source, SMA(12/48), bidirectional entries, and an
  ADX 30 regime. `QM5_11205` is the cited `AdxSmas.py` long-only SMA(3/6), ADX
  25 strategy with its own conjunctive source exit and 10 percent target.

The approved card is
`D:/QM/strategy_farm/artifacts/cards_approved/QM5_11205_ft-adx-smas.md`.
Its R gates are APPROVED / PASS / PASS / PASS / PASS, its expected frequency is
80 trades/year/symbol, and its source is the commit-pinned Gert Wohlgemuth
`AdxSmas.py` implementation in `freqtrade-strategies`.

## Compile repair and framework refresh

Historical build task `090cdc98-ea8f-47a7-8b4e-19d85f2c1a9e` failed because
MQL5 rejected `(void)broker_time` in `Strategy_NewsFilterHook`.

The repair removed that obsolete cast and brought the existing strategy hooks
onto the current skeleton contract:

- Q08 MAE sampling is the first `OnTick` statement;
- Friday close, position management, and rule exits run before the news entry
  gate;
- `QM_EntryRequest` is deterministically zero-initialized;
- the approved SMA/ADX entry, ATR stop, source target, and exit mechanics were
  not changed.

The exact approved card is also copied under the EA's `docs/` directory.

## Build evidence

| Check | Result | Evidence |
|---|---|---|
| SPEC validator | PASS | `python framework/scripts/validate_spec_doc.py framework/EAs/QM5_11205_ft-adx-smas` |
| Strict static gate | PASS, 0 failures, 0 warnings | `D:/QM/reports/framework/21/build_check_20260804_225746.json` |
| Strict compile | PASS, 0 errors, 0 warnings | `C:/QM/repo/framework/build/compile/20260804_225709/QM5_11205_ft-adx-smas.compile.log` |
| Compile summary | PASS | `D:/QM/reports/compile/20260804_225709/summary.csv` |
| Build task | done | `2ca4e54f-6977-4672-bd56-da7a393715cc` |
| Build result SHA-256 | recorded | `997f60d09f0dd2246a5878d476d561a0ba956ae835d0d0d3baed559bedfc6446` |

Artifact SHA-256 bindings:

| Artifact | SHA-256 |
|---|---|
| MQ5 | `eb88e986178d36a566c6d468b449892dbda33d91c2555bfb394c58511cc1d645` |
| EX5 | `fc46b83aebc2e9829c5802545d4cad6f98d8eeed08fd1b1a799022f3e271bd9c` |
| EURUSD set | `ac943c2d23c995f21af2dcc0dfa9add2c6350d8e3433e1e699a8b0e928c0963d` |
| GBPUSD set | `e2f92412abe760c38616ac1a115f72f6da094f60fe721588c77336e2712a8d60` |
| USDJPY set | `699e7b20f89a0f73a9ed8d994a5117b2ef5a67f9628a120eb38e85fce095b449` |
| XAUUSD set | `0b90eee17aedcc3e5a55ca6a784d11e9d63a4b8c3f1dfc474f5e46ef86711ce6` |

Every setfile is `H1`, `backtest`, `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Magic slots 0-3 bind EURUSD, GBPUSD, USDJPY, and XAUUSD
to bases `112050000` through `112050003`.

The governed build skill is build-only and does not run backtests. A
path-anchored, T_Live-excluding process scan found three of seven paced factory
terminals active immediately before handoff. The build result therefore records
`deferred_p2_smoke`; the user-authorized Q02 rows are the first CPU-bearing
validation.

## Q02 handoff

All rows were inserted by `record_build_result.auto_q02` at
`2026-08-04T22:59:02+00:00`, with `priority_track=true`, attempt 0, and no
claimant at confirmation.

| Symbol | Work item | State |
|---|---|---|
| EURUSD.DWX | `4edf4e08-0491-4a84-bc6e-98ede05eae8d` | pending |
| GBPUSD.DWX | `28afed4c-d29b-47eb-8158-1dba7bb33308` | pending |
| XAUUSD.DWX | `8c0bc240-4734-48bf-aa82-5b09e8e82772` | pending |
| USDJPY.DWX | staged-deferred by cohort limiter | not force-enqueued |

The USDJPY setfile is durably recorded in
`D:/QM/strategy_farm/state/q02_deferred_symbols.json` with the build task ID and
cohort size 4, so a later capacity-aware promotion can advance it without a
rebuild.
