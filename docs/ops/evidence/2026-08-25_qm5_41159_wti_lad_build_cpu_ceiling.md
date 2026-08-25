# QM5_41159 WTI LAD-trend build and CPU-ceiling handoff

Date: 2026-08-25

Branch: `agents/board-advisor`

Status: `SOURCE_READY_COMPILE_NOT_ENQUEUED_CPU_CEILING`

## New energy sleeve

`QM5_41159_wti-lad-tr` is a new low-frequency direct-WTI structural trend
candidate. At the first executable D1 boundary of a broker month, it selects
the latest `XTIUSD.DWX` close in each of the immediately prior thirteen
consecutive broker months and transforms those closes to log prices. It
enumerates all 78 pairwise slope breakpoints. For each breakpoint it uses
residual index 6 as the median intercept and sums the thirteen absolute
residuals. It retains every slope whose loss is within the fixed `1e-12`
tolerance of the minimum and uses the ordinary median retained slope. Positive
buys, negative sells, and exact zero consumes the month flat.

The implementation permits one consumed attempt per month and one position.
It locks `RISK_FIXED=1000`, a frozen `3.5*ATR(20,D1)` hard stop, no target,
next-month exit, and a forty-day stale repair. News and Friday close are OFF.
It uses no ML, banned signal indicator, external series, optimizer output,
scale-in, grid, martingale, or pyramid.

The estimator is not the existing WTI endpoint, OLS, global Theil-Sen, or
nested repeated-median logic. On fixed log-price levels
`[0,.02,0,0,-.06,-.09,-.05,-.05,.03,.06,-.02,-.03,.05]`, exact LAD is
negative `-0.002`, while Theil-Sen, repeated median, OLS, and the endpoint
slope are all positive. The candidates therefore take opposite sides on the
same valid state.

Direct WTI is economically distinct from the certified XAU, SP500, NDX, and
XNG carriers, but this is only a diversification hypothesis. Q09 alone may
decide realized portfolio correlation.

## Governed source and identity

- Source approval and pre-allocation dedup: `06d083b2d`.
- Bounded reputable-source packet: `0e6dcaf73`.
- EA-ID reservation: `4bbf7dda3`.
- OWNER-authorized G0 card: `f2a985b03`.
- Build-directory scaffold: `9220888e8`.
- Magic row, deterministic resolver regeneration, and EA-local card binding:
  `cc5bb48e0`.
- EA source, SPEC, independent reference suite, and one fixed-risk backtest
  setfile: `992e83f4071348fd88d9cc3ce5691871ec99aded`.

Identity is `QM5_41159`, strategy ID
`MOP-KOENKER-BASSETT-WTI-LAD-TREND-2026_S01`, symbol `XTIUSD.DWX`, D1, and
magic `411590000`. MQ5 SHA-256 is
`bb516e5603b4965a6fe08302f7e983074f741160038596c88958c0e2d1c21732`.
Canonical pre-allocation dedup was clean across 4,658 EA registry rows, 1,311
cards, and 45 Strategy Wiki nodes.

## Deterministic verification before the stop

- approved-card schema lint: PASS, zero missing sections and zero ML hits;
- G0 card lint: PASS;
- independent monthly LAD reference suite: PASS, 10/10;
- fixed opposite-sign estimator counterexample: PASS;
- `validate_spec_doc.py`: PASS, 1/1;
- `validate_build_guardrails.py`: PASS, two files and zero findings;
- `validate_symbol_scope.py --fail-on-leak`: `SINGLE_SYMBOL_OK`, zero
  violations;
- approved and EA-local card copies are byte-identical;
- exactly one `.set` file exists, with `environment: backtest`,
  `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

The independent fixtures cover strict positive, negative, and zero direction;
78 breakpoint enumeration; residual-median intercepts; absolute-loss
minimization; deterministic tied-minimizer median; invalid-package rejection;
thirteen consecutive completed month ends; year rollover; latest-close
selection; current-month exclusion; endpoint freshness; entry grace;
consume-before-gate behavior; and lifecycle repair.

## Binding CPU stop

Before any compile or Q02 mutation, a fresh five-sample whole-host
`Processor(_Total)` window returned `93.36, 96.94, 100.00, 88.86, 98.44`
percent (average 95.52%, maximum 100.00%). The maximum exceeds the governed
`CPU_MAX_LOAD_PERCENT=97.0`; the configured resume threshold is 90.0%. The
same read-only snapshot found seven path-anchored `terminal64.exe` and seven
path-anchored `metatester64.exe` processes under `D:\QM\mt5`, across T2, T3,
T4, T6, T7, T8, and T9.

The mission requires stopping when the backtest CPU ceiling is hit. Therefore
no direct compile, governed compile enqueue, tester dispatch, terminal claim,
backtest, or Q02 enqueue was attempted. Read-only final checks found no EX5
and zero work items for EA 41159. Q02 cannot be enqueued without a current
strict zero-error/zero-warning compile and hash-bound EX5. The approved card
therefore remains at `pipeline_phase: Q01`, `q01_status: NOT_BUILT`, and
`q02_status: NOT_ENQUEUED_Q01_PENDING`.

Machine-readable evidence is
`artifacts/qm5_41159_cpu_ceiling_20260825.json`.

## Governed continuation

After sustained CPU recovery below 90%, run exactly one strict source-fresh
compile for `QM5_41159_wti-lad-tr`. Only a compile PASS with a hash-bound EX5
permits build review and one D1 `RISK_FIXED` Q02 enqueue. Do not dispatch a
terminal as part of the enqueue handoff.

No portfolio gate, `T_Live` manifest, `T_Live` file, AutoTrading state,
terminal process, live/demo/shadow/stress/optimization preset, deploy state,
existing EA, gate threshold, correlation verdict, or portfolio verdict was
changed.
