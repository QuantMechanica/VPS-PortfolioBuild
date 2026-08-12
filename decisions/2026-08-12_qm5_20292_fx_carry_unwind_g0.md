# QM5_20292 FX Carry-Unwind Basket G0 Authorization

Date: 2026-08-12

Authority: OWNER diversity and funnel-throughput mission delivered to Codex on
the `agents/board-advisor` branch.

## Decision

Authorize one V5 Strategy Card reconciliation, deterministic EA allocation,
non-live build, strict compile/Q01 validation, and one paced Q02 enqueue for
`QM5_20292_fx-carry-unwind`.

On the first tradable `AUDCHF.DWX` D1 bar of each broker week, measure a
seven-major global-FX stress ratio from completed daily returns. When the
cross-sectional median ratio is at least 1.50, rank six CHF/JPY crosses by
positive broker-swap cash per unit of ATR risk and open the opposite side of
the top two carry directions. Split one fixed-risk package equally, close the
whole package when stress falls to 1.10, after five completed D1 bars, on the
standard Friday rail, or immediately if a leg becomes orphaned.

This authorization does not pre-approve efficacy, certification, realized
decorrelation, portfolio admission, deployment, or live use.

## Priority And Collision Evidence

The farm's approved diverse build backlog had no eligible FX, crypto, rates,
or non-XNG energy ticket: the diverse rows were excluded, permanently failed,
missing unavailable data, or already overlapped by another agent. The apparent
diverse Q02-Q03 infrastructure candidates had already reached later phases or
were strategy failures rather than infrastructure faults. The governed
66-pair FX cointegration frontier is explicitly complete and duplicate-guarded.

The farm claim `new-edge:fx-carry-unwind` was acquired atomically before
allocation. The governed allocator then reserved `QM5_20292` for strategy ID
`SRC04_S11b`. No existing EA directory, registry row, open work item, or open
task owned this slug or strategy ID at claim time.

## Source Boundary

The approved source is Kathy Lien (2015), *Day Trading and Swing Trading the
Currency Market*, 3rd edition, Wiley, Chapter 18, pages 153-160. The complete
bounded extract is recorded at
`strategy-seeds/sources/SRC04/raw/ch17-20_fundamental.txt`, lines 71-455.

The source identifies the structural direction: risk aversion forces crowded
positive-carry positions to unwind, benefiting lower-rate funding currencies
such as CHF and JPY. It does not supply this implementation's realized-FX-
volatility threshold, broker-swap rank, ATR normalization, package lifecycle,
or performance claim. Those are pre-registered QM translation choices and Q02
must falsify them on governed data.

## Locked Mechanical Rule

- Signal universe: `EURUSD.DWX`, `GBPUSD.DWX`, `AUDUSD.DWX`, `NZDUSD.DWX`,
  `USDJPY.DWX`, `USDCHF.DWX`, and `USDCAD.DWX`.
- Target universe and slots: `AUDCHF.DWX`/0, `AUDJPY.DWX`/1,
  `GBPCHF.DWX`/2, `GBPJPY.DWX`/3, `NZDCHF.DWX`/4, and `NZDJPY.DWX`/5.
- For each signal symbol, calculate 21 completed log returns and annualized
  realized volatility. Divide by the median of its prior 252 completed rolling
  21-day volatilities. Require five valid ratios and take their median.
- Entry stress is `>= 1.50`; exit stress is `<= 1.10`.
- Convert comparable positive broker swap through its declared MT5 swap mode
  into account-currency cash per lot per ordinary rollover day. Divide by the
  cash value of `ATR(20,D1)` for one lot. Unsupported, zero, non-finite, or
  incomparable metadata makes that target ineligible; no price-momentum,
  policy-rate, or static-direction fallback is authorized.
- Rank by carry efficiency descending with symbol as deterministic tie-break.
  Open the reverse of the top two favorable carry sides.
- Persist the weekly attempt before history, stress, swap, spread, quote,
  sizing, or order checks. Never retry within the same broker week.
- Each leg receives half of `RISK_FIXED=1000` stop risk and a frozen
  `2.5 * ATR(20,D1)` hard stop. Close the whole package on stress hysteresis,
  after five D1 bars, on Friday close, or on orphan/malformed state.

## Reputable-Source And Allowability Decision

- R1: PASS. Named long-standing FX author, Wiley book, precise chapter/page
  boundary, OWNER-approved SRC04 intake, and complete bounded local extract.
- R2: PASS. Weekly clock, return windows, median aggregation, thresholds, swap
  conversion boundary, rank, direction, atomic entry, risk, stops, and exits
  are deterministic.
- R3: PASS. All thirteen `.DWX` symbols are in the deterministic symbol matrix.
  Native `AUDCHF.DWX` and `AUDJPY.DWX` provide at least two possible broker-
  metadata targets; every target still proves comparable swap at runtime and
  fails closed otherwise.
- R4: PASS. Price arithmetic, broker metadata, deterministic ranks, and ATR
  safety stops only; no trained output, banned signal indicator, external
  runtime feed, grid, martingale, scale-in, or pyramiding.
- Low frequency: PASS. One consumed package opportunity per broker week, only
  in an elevated global-volatility state.

## Non-Duplicate Decision

- `QM5_1127_menkhoff-carry-fxvol-filter` harvests ordinary carry only when
  global volatility permits risk. This rule trades only high-stress states and
  reverses current broker carry.
- `QM5_13023_ftq-audjpy-riskoff-short` is a fixed single-pair SMA/Donchian
  short. This rule has no trend or breakout input and ranks six crosses into an
  atomic two-leg package.
- `QM5_1193_qp-stress-usd-rebound` keys from index/oil declines and expresses
  USD rebound. This rule reads neither index nor energy and expresses CHF/JPY
  funding-currency repatriation.
- `QM5_10027`, `QM5_1091`, `QM5_10885`, and `QM5_1249` are positive-carry
  harvesters. This rule never enters the favorable carry side.
- The governed 66-pair cointegration cohort uses residual convergence and is
  complete; this rule uses neither a pair residual nor a mean-reversion score.

The high-stress breadth state, live broker carry rank, opposite direction,
weekly consumed attempt, and atomic two-leg package are jointly load-bearing.
Verdict: `CLEAN_STRUCTURAL_FX_EDGE_AFTER_MANUAL_REVIEW`.

## Allocation, Kill, And Safety Boundary

- EA ID: `QM5_20292`;
- strategy ID: `SRC04_S11b`;
- intended magics: `202920000` through `202920005` in the target order above;
- retire if fewer than two targets expose comparable positive carry, pooled
  history yields fewer than two entries per year per target, the stress state
  degenerates, atomic repair fails, Q04 after-cost PF is below 1.0, or later
  evidence establishes material incumbent overlap; and
- do not rescue failure with static carry directions, price momentum, policy
  rates, a single fixed pair, or relaxed stress thresholds.

Only one logical `RISK_FIXED` backtest setfile is authorized. Manual backtests,
stress/optimization setfiles, live/demo/shadow artifacts, `T_Live`,
AutoTrading, deploy manifests, T_Live manifests, portfolio-gate edits, and
portfolio admission are excluded. If the farm is at its backtest CPU ceiling,
record the stop and do not enqueue or run a test.
