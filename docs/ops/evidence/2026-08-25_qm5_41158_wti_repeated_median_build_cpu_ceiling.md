# QM5_41158 WTI repeated-median build and CPU-ceiling handoff

Date: 2026-08-25

Branch: `agents/board-advisor`

Status: `SOURCE_READY_COMPILE_NOT_ENQUEUED_CPU_CEILING`

## New energy sleeve

`QM5_41158_wti-repmedian-tr` is a new low-frequency direct-WTI structural
trend candidate. At the first executable D1 boundary of a broker month, it
selects the latest `XTIUSD.DWX` close in each of the immediately prior
thirteen consecutive broker months. For each month-end pivot it constructs
twelve forward-oriented log-price slopes to the other pivots, takes the even
median at indexes 5 and 6, then takes index 6 from the thirteen sorted pivot
medians. It follows the strict repeated-median sign for one broker month.
Exact zero or malformed state consumes the month flat.

The implementation has one consumed attempt per month, one position, fixed
`RISK_FIXED=1000`, a frozen `3.5*ATR(20,D1)` hard stop, no target, next-month
exit, and a forty-day stale repair. News and Friday close are OFF. It uses no
ML, banned signal indicator, external series, optimizer output, scale-in,
grid, martingale, or pyramid.

The mechanic is not the existing global Theil-Sen WTI estimator. The
canonical dedup checker returned only the expected fuzzy neighbor
`QM5_20271_wti-theilsen-tr`. On fixed log-price levels
`[0,.01,.06,.11,.14,.13,.11,.12,.09,.04,.02,.05,.10]`, the global 78-slope
Theil-Sen median is positive `0.0015555555555555557`, while this nested
repeated median is negative `-0.004500000000000001`; the candidates take
opposite sides on the same valid state.

WTI is economically distinct from the certified XAU, SP500, NDX, and XNG
carriers, but this is only a diversification hypothesis. Q09 alone may decide
realized portfolio correlation.

## Governed source and identity

- Source approval and pre-allocation dedup: `eda96a83f`.
- Bounded reputable-source packet: `63e202e9c`.
- EA-ID reservation: `5426d995f`.
- OWNER-authorized G0 card: `0577388b5`.
- Build-directory scaffold: `598a3e322`.
- Magic row and deterministic resolver regeneration: `01097b584`.
- EA-local approved-card binding: `740d5b9bf`.
- EA source, SPEC, independent reference suite, and one fixed-risk backtest
  setfile: `affba73b94e21ad88dd8cead81f2d941450eab26`.

Identity is `QM5_41158`, strategy ID
`MOP-SIEGEL-WTI-REPMEDIAN-TREND-2026_S01`, symbol `XTIUSD.DWX`, D1, and
magic `411580000`. MQ5 SHA-256 is
`4685AE045106DCE1973FF66AFC681DE04BB0B96ED09DBE0A20187BC038F53769`.

## Deterministic verification before the stop

- approved-card schema lint: PASS, zero missing sections and zero ML hits;
- G0 card lint: PASS;
- independent monthly repeated-median reference suite: PASS, 10/10;
- fixed opposite-sign Theil-Sen counterexample: PASS;
- `validate_spec_doc.py`: PASS, 1/1;
- `validate_build_guardrails.py`: PASS, two files and zero findings;
- `validate_symbol_scope.py --fail-on-leak`: `SINGLE_SYMBOL_OK`, zero
  violations;
- approved and EA-local card copies are byte-identical;
- exactly one `.set` file exists, with `environment: backtest`,
  `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

The reference fixtures independently verify strict positive/negative/zero
direction, thirteen pivot groups, twelve slopes per pivot, all 156 grouped
observations, pair duplication across endpoint pivots, inner indexes 5/6,
outer index 6, log-close transformation, invalid-package rejection, thirteen
consecutive month ends, year rollover, latest-close selection, current-month
exclusion, missing-month and freshness failure, both supported label
conventions, entry grace, consume-before-gate behavior, and lifecycle repair.

## Binding CPU stop

Before any compile or Q02 mutation, a fresh five-sample whole-host
`Processor(_Total)` window returned `97.36, 93.08, 81.84, 92.29, 92.98`
percent (average 91.51%, maximum 97.36%). The maximum exceeds the governed
`CPU_MAX_LOAD_PERCENT=97.0`; the configured resume threshold is 90.0%. The
same read-only snapshot found five path-anchored `terminal64.exe` and four
path-anchored `metatester64.exe` processes under `D:\QM\mt5`.

The mission requires stopping when the backtest CPU ceiling is hit. Therefore
no direct compile, governed compile enqueue, tester dispatch, terminal claim,
backtest, or Q02 enqueue was attempted. Read-only final checks found no EX5
and zero work items for EA 41158. Q02 cannot be enqueued without a current
strict zero-error/zero-warning compile and hash-bound EX5. The approved card
therefore remains at `pipeline_phase: Q01`, `q01_status: NOT_BUILT`, and
`q02_status: NOT_ENQUEUED_Q01_PENDING`.

Machine-readable evidence is
`artifacts/qm5_41158_cpu_ceiling_20260825.json`.

## Governed continuation

After sustained CPU recovery below 90%, run exactly one strict source-fresh
compile for `QM5_41158_wti-repmedian-tr`. Only a compile PASS with a
hash-bound EX5 permits build review and one D1 `RISK_FIXED` Q02 enqueue. Do
not dispatch a terminal as part of the enqueue handoff.

No portfolio gate, `T_Live` manifest, `T_Live` file, AutoTrading state,
terminal process, live/demo/shadow/stress/optimization preset, deploy state,
existing EA, gate threshold, correlation verdict, or portfolio verdict was
changed.
