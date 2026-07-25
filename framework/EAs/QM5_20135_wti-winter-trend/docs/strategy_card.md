---
ea_id: QM5_20135
slug: wti-winter-trend
type: strategy
strategy_id: BURAKOV-MOP-WTI-WINTER-TREND-2026_S01
source_id: BURAKOV-MOP-WTI-WINTER-TREND-2026
status: APPROVED
g0_status: APPROVED
created: 2026-07-25
created_by: Research+Development
last_updated: 2026-07-25
source_authors: "Dmitry Burakov, Max Freidin, Yuriy Solovyev; Tobias J. Moskowitz, Yao Hua Ooi, Lasse Heje Pedersen"
strategy_mechanic: november-may-wti-monthly-252d-return-sign-trend
source_citation: "Burakov, Freidin and Solovyev (2018), The Halloween Effect on Energy Markets; Moskowitz, Ooi and Pedersen (2012), Time Series Momentum."
source_citations:
  - type: peer_reviewed_open_access_paper
    citation: "Burakov, D., Freidin, M. and Solovyev, Y. (2018). The Halloween Effect on Energy Markets: An Empirical Study. International Journal of Energy Economics and Policy 8(2), 121-126."
    location: "Methods, alternative-two West Texas November-May partition, and WTI results; https://www.econjournals.com/index.php/ijeep/article/view/6092"
    quality_tier: B
    role: seasonal_regime
  - type: peer_reviewed_journal_paper
    citation: "Moskowitz, T. J., Ooi, Y. H. and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "Own-past-return-sign momentum across futures; DOI https://doi.org/10.1016/j.jfineco.2011.11.003"
    quality_tier: A
    role: directional_mechanic
sources:
  - "[[sources/BURAKOV-MOP-WTI-WINTER-TREND-2026]]"
concepts:
  - "[[concepts/wti-winter-regime]]"
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/seasonal-trend-interaction]]"
indicators:
  - "[[indicators/rolling-return]]"
  - "[[indicators/atr]]"
strategy_type_flags: [time-series-momentum, calendar-seasonality, seasonal-regime-gate, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [commodities, energy, crude_oil]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
period: D1
timeframes: [D1]
expected_trade_frequency: "One monthly package in each November-May broker month after warm-up; seven eligible decisions/year, with exact-zero or invalid-history states flat."
expected_trades_per_year_per_symbol: 7
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
review_focus: "Falsify whether a source-backed WTI winter regime changes the payoff and book overlap of slow own-price trend enough to add direct crude-oil exposure rather than another index/metal return stream."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [low_frequency, friday_close, risk_mode_dual, enhancement_doctrine, cfd_futures_basis, portfolio_correlation]
g0_approval_reasoning: "OWNER commodity/energy sleeve mission: R1 PASS two peer-reviewed governed source lineages; R2 PASS fixed November-May gate plus completed 252-D1 return-sign direction, monthly renewal, frozen ATR stop, stale exit, and restart-safe attempt state; R3 PASS registered XTIUSD.DWX D1; R4 PASS deterministic native MT5 data only with no ML, banned indicator, external feed, grid, martingale, scale-in, or pyramiding; deterministic dedup CLEAN plus manual neighbor resolution."
---

# QM5_20135 WTI Winter-Regime Time-Series Momentum

## Hypothesis

WTI has a source-documented November-May seasonal regime, while
time-series-momentum research identifies an instrument's own trailing-return
sign as a structural directional state. Trading the 252-D1 WTI return sign
only inside that winter regime may produce a direct crude-oil return stream
whose information clock differs from the certified XAU, SP500, NDX, and XNG
book.

This is a falsifiable interaction hypothesis, not a decorrelation or
profitability claim. Q02 must establish basic economics and frequency; the
unchanged downstream portfolio gate alone may measure realized book overlap.

## Source Traceability

The approved composite packet
`strategy-seeds/sources/BURAKOV-MOP-WTI-WINTER-TREND-2026/source.md`
preserves both parent lineages.

Burakov, Freidin, and Solovyev define an alternative-two West Texas winter
interval from the last October close through the following last May close.
Moskowitz, Ooi, and Pedersen supply the own-past-return-sign momentum
mechanic. Neither source tests their conjunction, a Darwinex continuous CFD,
monthly fixed-risk renewal, an ATR stop, or QM portfolio behavior. Those are
explicit QM hypotheses.

No external source is read at runtime. The EA uses only registered
`XTIUSD.DWX` D1 OHLC, ATR, broker calendar, executable quotes, spread,
positions, deal history, and V5 framework state.

## Non-Duplicate Decision

The deterministic pre-allocation check scanned 4,192 EA-registry rows and 376
research cards and returned `CLEAN` for slug `wti-winter-trend`, strategy ID
`BURAKOV-MOP-WTI-WINTER-TREND-2026_S01`, and mechanic
`November-May 252-D1 return-sign monthly WTI trend package`.

Manual semantic review resolved the closest systems:

- `QM5_12603_wti-tsmom12m` trades the 252-D1 return sign year-round and has no
  seasonal entry gate or forced June season exit.
- `QM5_20015_wti-halloween-winter` is unconditional long-only November-May;
  it does not read price direction.
- `QM5_20046_wti-halloween-ls` maps season directly to position direction and
  has no trailing-return signal.
- `QM5_12576_eia-wti-season` uses different refined-product demand months,
  SMA(84), 21-D1 ROC confirmation, and Friday flattening.
- `QM5_20052_xng-seas-trend` uses natural gas, Suenaga's two volatility
  windows, a 126-D1 horizon, and a two-percent deadband.
- `QM5_12963_wti-winter-exhaust` is a short-only price-stretch exhaustion
  fade, not slow symmetric trend.
- `QM5_12567_cum-rsi2-commodity` is a two-day oscillator pullback with a
  short multiday lifecycle.

The new information state is the load-bearing conjunction of the WTI
November-May calendar regime and the completed 252-D1 own-return sign. Removing
either component produces an already-built parent mechanic, so neither may be
ablated from the baseline.

## Markets, Timeframe, and Cadence

- Host and target: exact `XTIUSD.DWX`.
- Timeframe: D1.
- Magic slot: 0; allocated magic `201350000`.
- Decision clock: first tradable D1 bar of each broker month.
- Active entry months: November, December, January, February, March, April,
  and May.
- Flat months: June through October.
- Expected cadence: seven completed packages/year after warm-up. Exact-zero
  momentum or unavailable data stays flat.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.

## Rules

The following rules are the complete authorized baseline. A different month
window, return horizon, deadband, direction map, stop, holding clock, or retry
policy requires a new card.

## 4. Entry Rules

1. Require exact `XTIUSD.DWX`, D1, magic slot 0, and every baseline input
   locked to the values below.
2. Evaluate entries only on the first tradable D1 bar of a new broker month.
3. Close an older package before the new decision. If the close is incomplete,
   consume the month and remain flat.
4. Require the current broker month to be November-May. June-October is a
   forced flat state.
5. Before history, signal, spread, quote, stop, news, or order gates, persist
   the broker `YYYYMM` as consumed. A rejection, restart, stop, or blocked gate
   cannot retry that month.
6. Reject when an entry deal or EA-owned position already exists for the
   current broker month.
7. Read completed D1 closes at shifts 1 and 253 and compute
   `ln(Close[1] / Close[253])`.
8. Buy when the log return is strictly positive; sell when it is strictly
   negative; remain flat only on exact equality or invalid data. There is no
   baseline magnitude threshold.
9. Require completed D1 ATR(20), a non-negative spread no greater than 1,500
   points, and a valid executable market price.
10. Attach a frozen hard stop `4.0 * ATR(20)` from the executable entry price,
    normalized through V5 stop rules. There is no take-profit.

## 5. Exit Rules

1. Close an EA-owned package at the first D1 bar of the next broker month
   before evaluating a replacement.
2. Close immediately when the current broker month is June-October.
3. Close after 35 elapsed calendar days as a stale-position guard.
4. The frozen broker hard stop remains active throughout the package.
5. Framework kill-switch closures remain authoritative. Friday close is
   deliberately disabled because the source-aligned package spans weekends.

Lifecycle exits run before entry-only news handling. A blocked renewal must
not leave the prior month's package open.

## 6. Filters (No-Trade Module)

- Fail closed for the wrong symbol, timeframe, slot, unlocked input, invalid
  calendar key, missing D1 history, non-positive close, invalid logarithm,
  unavailable ATR, negative/excess spread, invalid executable quote, invalid
  normalized stop, consumed month, same-month deal, or owned position.
- Lock the news temporal and compliance axes OFF for Q02. No external calendar
  dependency is needed for the monthly structural signal.
- Require `qm_friday_close_enabled=false`.
- Runtime may not read a futures curve, inventory, COT, refinery, EIA, OPEC,
  volume, open interest, CSV, API, analyst forecast, or other external signal.

## 7. Trade Management Rules

- One position for magic `201350000` and one consumed decision per broker
  month.
- Close-before-renew on every monthly boundary, even when the return sign is
  unchanged.
- Maintain the original server-side stop; never trail or move it.
- No profit target, partial close, break-even move, retry, scale-in, reversal
  inside a month, grid, martingale, pyramid, random path, adaptive fit, or
  discretionary override.
- Restart recovery uses the terminal-persistent consumed-month marker plus
  position/deal history. Future-dated stale marker state is cleared at
  initialization for deterministic historical runs.

## Parameters to Test

| parameter | default | authorized values | role |
|---|---:|---|---|
| `strategy_first_active_month` | 11 | [11] | first winter-regime month |
| `strategy_last_active_month` | 5 | [5] | final winter-regime month |
| `strategy_momentum_lookback_d1` | 252 | [252] | completed own-return horizon |
| `strategy_min_abs_return_pct` | 0.0 | [0.0] | source-sign baseline; no deadband |
| `strategy_atr_period` | 20 | [20] | completed D1 risk estimator |
| `strategy_atr_sl_mult` | 4.0 | [4.0] | frozen catastrophe-stop distance |
| `strategy_max_hold_days` | 35 | [35] | stale guard around monthly renewal |
| `strategy_max_spread_points` | 1500 | [1500] | WTI entry spread ceiling |

There is no baseline parameter sweep. The season gate and 252-D1 sign are
jointly load-bearing.

## Author Claims

The Burakov paper reports historical WTI winter/summer differences under its
alternative-two calendar partition. The MOP paper reports time-series
momentum across futures. Neither claims that this interaction, this CFD
carrier, these risk controls, or this portfolio objective is profitable.

No source return, hit rate, profit factor, drawdown, trade count, or
correlation estimate is imported as a QM expectation.

## Initial Risk Profile

- `expected_pf: 1.01` is a conservative queue-order prior only.
- `expected_dd_pct: 30.0` reflects WTI gaps, long and short trend exposure,
  monthly leverage reset, financing, and futures/CFD basis risk.
- Expected frequency is seven eligible packages/year after warm-up.
- Risk class is high.
- Gridding, scalping, pyramiding, and ML are false.

## Kill Criteria

- Retire on zero trades or fewer than five completed packages/year on average.
- Fail on any entry outside November-May, missing close-before-renew behavior,
  a direction inconsistent with the completed 252-D1 sign, same-month retry,
  position surviving into June, hold beyond 35 days, missing hard stop,
  invalid risk mode, nondeterminism, or any governed PF/DD failure.
- Do not rescue failure by changing the season, lookback, sign threshold,
  direction, stop, hold, spread cap, retry policy, or risk mode after results.
- Later gates must reject the sleeve if its realized return stream does not
  diversify the certified book. No correlation waiver is authorized.

## Risk

Q02 uses exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Position sizing uses executable distance to the frozen
ATR stop. WTI gaps, continuous-CFD roll/basis, financing, monthly opening
spreads, short-side tail risk, sparse annual packages, and source-sample decay
are first-order kill risks.

## Strategy Allowability Check

- [x] R1: two peer-reviewed named-author source lineages with durable
  repository review records.
- [x] R2: fixed calendar gate, completed return sign, monthly attempt state,
  hard stop, stale exit, and forced season exit.
- [x] R3: registered `XTIUSD.DWX` D1 history route and native V5 data only.
- [x] R4: deterministic calendar/OHLC/ATR arithmetic; no ML, banned indicator,
  external signal, grid, martingale, scale-in, or pyramiding.
- [x] Dedup: deterministic CLEAN plus manual parent/neighbor differentiation.

## Framework Alignment

- no_trade: exact host/D1/slot, locked-input, history, arithmetic, spread,
  quote, stop, consumed-month, and owned-position guards.
- trade_entry: November-May monthly boundary, persisted attempt, completed
  252-D1 return sign, symmetric market direction, and frozen ATR stop.
- trade_management: close at next month, outside season, or 35-day stale
  boundary before entry-only news handling.
- trade_close: framework position close plus broker hard stop and kill switch.

## Safety Boundary

This approval covers one card, deterministic registries, EA build, strict
compile, one `RISK_FIXED` backtest setfile, and one paced Q02 enqueue. It does
not authorize a live setfile, AutoTrading, `T_Live`, a deploy or T_Live
manifest, portfolio admission, a portfolio-gate change, portfolio KPIs, or a
correlation waiver.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-25 | initial source-backed WTI winter-regime trend card | G0 | APPROVED |
| v1 | 2026-07-25 | strict compile and targeted build validation complete | Q01 | PASS |
| v1 | 2026-07-25 | paced baseline handoff; no manual backtest launched | Q02 | ENQUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-25 | APPROVED | this card |
| Q01 Build Validation | 2026-07-25 | PASS | `docs/ops/evidence/2026-07-25_qm5_20135_wti_winter_trend_build_q02_enqueue.md` |
| Q02 Baseline Screening | 2026-07-25 | ENQUEUED | work item `063e9d6c-8a54-461a-8113-a3f098e3e5e7`; same evidence |
