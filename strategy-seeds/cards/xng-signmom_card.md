---
strategy_id: PAPAILIAS-RSM-2021_XNG_S01
source_id: PAPAILIAS-RSM-2021
ea_id: QM5_13116
slug: xng-signmom
status: APPROVED
created: 2026-07-10
created_by: Research
last_updated: 2026-07-10
g0_status: APPROVED
source_citation: "Papailias, Liu, and Thomakos (2021), Return Signal Momentum, Journal of Banking & Finance 124, 106063, DOI 10.1016/j.jbankfin.2021.106063."
source_citations:
  - type: paper
    citation: "Papailias, Fotis; Liu, Jiadong; and Thomakos, Dimitrios D. (2021). Return Signal Momentum. Journal of Banking & Finance 124, Article 106063."
    location: "Sections 2.1, 2.2, 4.1-4.2; Equation 7; Equation 10; Tables 1-2 and G.1-G.3; DOI https://doi.org/10.1016/j.jbankfin.2021.106063; accepted manuscript https://pureadmin.qub.ac.uk/ws/files/229452162/RSM_011220.pdf"
    quality_tier: A
    role: primary
sources:
  - "[[sources/PAPAILIAS-RSM-2021]]"
concepts:
  - "[[concepts/return-sign-persistence]]"
  - "[[concepts/natural-gas-trend]]"
indicators:
  - "[[indicators/month-end-close]]"
  - "[[indicators/atr]]"
strategy_type_flags: [momentum, time-stop, symmetric-long-short, atr-hard-stop]
markets: [commodities, energy, natural_gas]
timeframes: [D1]
primary_target_symbols: [XNGUSD.DWX]
target_symbols: [XNGUSD.DWX]
single_symbol_only: true
period: D1
expected_trade_frequency: "One renewed XNG position per broker month after warm-up; approximately 12 completed trades/year before Q02 validation."
expected_trades_per_year_per_symbol: 12
expected_pf: 1.05
expected_dd_pct: 25.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
review_focus: "Adds a natural-gas sign-persistence trend driver that is mechanically opposite to the book's QM5_12567 long-only RSI pullback; realized portfolio orthogonality remains a Q09 question."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
hard_rules_at_risk: [friday_close, risk_mode_dual, cfd_futures_basis]
---

# XNG Return-Sign Momentum

## Hypothesis

Monthly return direction can persist even when return magnitude is noisy. The
source estimates that persistence by counting positive monthly returns, rather
than by summing their magnitudes. This card ports that structural sign process to
natural gas, an explicit source instrument, so the edge is not another RSI
pullback, price breakout, seasonality window, inventory event, or conventional
12-month magnitude-momentum rule.

## Source And Evidence Boundary

The primary source is the peer-reviewed 2021 *Journal of Banking & Finance*
paper "Return Signal Momentum," DOI
https://doi.org/10.1016/j.jbankfin.2021.106063. The complete accepted manuscript,
including Appendices A-I, was read. It tests 55 futures, including 24 commodities;
natural gas is explicitly listed in Table 1 and Appendix C.

The author claim extracted verbatim is: "A new type of momentum based on the
signs of past returns is introduced." (abstract, manuscript page 1). The source's
diversified futures performance is not a performance claim for `XNGUSD.DWX`.

## Concept And Non-Duplicate Decision

On the first tradable `XNGUSD.DWX` D1 bar of each broker month, reconstruct the
last 13 completed month-end closes. Convert the 12 intervening monthly returns to
binary signs and calculate:

`positive_probability = non_negative_months / 12`.

- If `positive_probability >= 0.40`, hold long XNG for the new month.
- Otherwise, hold short XNG for the new month.

This is mechanically different from:

- `QM5_12567_cum-rsi2-commodity`: long-only two-day RSI pullback below SMA(200),
  typically held no more than five D1 bars.
- `QM5_12804_xng-tsmom12m-atr`: direction is the sign of one cumulative
  252-D1 return and includes an ATR-percent corridor.
- `QM5_12895_xng-6m-reversal`: fades six-month return magnitude.
- `QM5_13101_xng-1w-mom-vol`: trades one-week magnitude momentum.
- `QM5_13105_xng-idnr4-brk` and `QM5_13110_xng-svol-brk`: price/volatility
  breakouts.
- Fixed-month, storage, COT, production, LNG, ratio, and carry cards: their
  signals come from calendar ownership, event/fundamental state, another asset,
  or broker carry rather than the distribution of XNG monthly return signs.

Pre-allocation repository dedup verdict: `CLEAN` for slug `xng-signmom`, strategy
ID `PAPAILIAS-RSM-2021_XNG_S01`, and the fixed monthly sign-probability mechanic.

## Markets And Timeframe

- Target symbol: `XNGUSD.DWX`.
- Host and signal timeframe: D1.
- Signal cadence: first D1 bar of each broker-calendar month.
- Expected frequency: approximately 12 completed positions/year after warm-up,
  above the Q02 floor of five trades/year/symbol.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.
- Runtime data: native MT5 D1 closes, ATR, broker spread, broker calendar, and
  position state only.

## Entry Rules

- Evaluate only on the first new `XNGUSD.DWX` D1 bar of a broker month.
- Copy a bounded completed-D1 history and retain the most recent completed close
  for each distinct broker-calendar month.
- Require `strategy_lookback_months + 1` valid month-end closes.
- For each of the 12 completed monthly returns, assign `1` when the return is
  non-negative and `0` when negative, matching Equation 7.
- Set `positive_probability = positive_count / strategy_lookback_months`.
- BUY when probability is greater than or equal to
  `strategy_positive_threshold=0.40`; otherwise SELL.
- Require a valid ATR, acceptable spread, no existing same-magic position, and no
  prior attempt in the current broker month.
- Place a frozen `3.5 * ATR(20)` hard stop; no take-profit.

## Exit Rules

- On the first tradable D1 bar of the next broker month, close the prior position
  before evaluating the renewed signal.
- Close if the position exceeds `strategy_max_hold_days=35` as a stale guard.
- The broker hard stop remains active within the month.
- No sign flip, intramonth return, RSI, target-profit, or discretionary exit.

## Filters And Trade Management

- Exact host guard: `XNGUSD.DWX`, D1, magic slot 0.
- Parameter, history, close, arithmetic, ATR, and spread checks fail closed.
- One position per EA magic; no same-month re-entry after a stop.
- No trailing stop, break-even move, partial close, scale-in, grid, martingale,
  pyramiding, time-varying threshold, optimization at runtime, external feed, or
  ML.
- Framework kill switch and news entry compliance remain authoritative.
- Friday close is disabled to preserve the source's one-month holding period.

## Parameters To Test

| parameter | default | source/card range | role |
|---|---:|---|---|
| `strategy_lookback_months` | 12 | [12] | source formation window |
| `strategy_positive_threshold` | 0.40 | [0.30, 0.40, 0.50] | fixed source thresholds; no adaptive threshold |
| `strategy_history_bars` | 500 | [400, 500, 650] | bounded D1 month-end reconstruction buffer |
| `strategy_atr_period` | 20 | [14, 20, 30] | V5 hard-stop volatility estimate |
| `strategy_atr_sl_mult` | 3.5 | [2.5, 3.5, 5.0] | frozen hard-stop distance |
| `strategy_max_hold_days` | 35 | [35] | stale guard around monthly reset |
| `strategy_max_spread_points` | 3000 | [2000, 3000, 4500] | XNG entry spread cap |

The monthly binary-sign definition, equal weighting, non-negative sign rule,
12-month default, fixed threshold, monthly renewal, and no same-month re-entry are
locked. Changing to magnitude momentum, an adaptive threshold, daily signs, a
breakout, RSI, event data, or calendar-direction ownership requires a new card.

## Initial Risk Profile

- `expected_pf: 1.05` is a conservative queue-ordering prior, not evidence.
- `expected_dd_pct: 25.0` reflects XNG gap risk and the paper's warning that
  natural gas is the highest-volatility series in its panel.
- Risk class: high.
- The source uses portfolio volatility scaling and no per-trade broker stop. The
  V5 carrier uses `RISK_FIXED=1000` plus a frozen ATR hard stop so loss sizing is
  auditable without importing the paper's 40% portfolio-volatility target.

## Kill Criteria

- Retire at Q02 if realized frequency is below five trades/year.
- Fail on zero trades, invalid month-end reconstruction, repeated `OnInit`
  failure, non-deterministic reruns, or risk-mode mismatch.
- Do not widen thresholds, shorten the 12-month lookback, add an intramonth
  trigger, or sweep outside this card after a poor baseline.
- Treat source-futures versus DWX-CFD roll/basis mismatch as a falsification risk,
  not as justification for a waiver.

## Strategy Allowability Check

- [x] R1 reputable: peer-reviewed Journal of Banking & Finance paper, DOI and
  complete institutional-repository accepted manuscript.
- [x] R2 mechanical: fixed completed-month binary signs, equal-weight
  probability, fixed threshold, monthly renewal, and deterministic ATR stop.
- [x] R3 testable: registered `XNGUSD.DWX` D1 history is available across T1-T10.
- [x] R4 compliant: no ML, banned indicator, external runtime feed, adaptive fit,
  grid, martingale, or pyramiding.
- [x] Expected frequency exceeds the five-trades/year Q02 floor.
- [x] Repository dedup check is clean before EA-ID allocation.

## Framework Alignment

- no_trade: exact host/slot, parameter domain, monthly attempt, bounded history,
  arithmetic, spread, ATR, and one-position guards.
- trade_entry: source-defined 12-month positive-sign probability and fixed 0.40
  threshold, with V5 fixed-risk ATR stop.
- trade_management: next-month rollover and 35-day stale close.
- trade_close: framework close helper and broker ATR stop.

`hard_rules_at_risk`:

- `friday_close`: disabled only to preserve the peer-reviewed one-month holding
  period; monthly and stale exits plus the hard stop remain active.
- `risk_mode_dual`: the build creates only a RISK_FIXED backtest setfile.
- `cfd_futures_basis`: source uses rolled futures while Q02 uses a continuous
  Darwinex CFD; no equivalence is assumed.

## Implementation Notes

- target_modules.no_trade: exact XNG/D1/slot plus fail-closed input and history
  validation.
- target_modules.entry: bounded D1 month-end extraction, 12 binary monthly signs,
  fixed probability threshold, ATR hard stop.
- target_modules.management: month reset, stale close, no same-month re-entry.
- target_modules.close: `QM_TM_ClosePosition(..., QM_EXIT_STRATEGY)` plus broker
  stop.
- estimated_complexity: small.
- estimated_test_runtime: one XNG D1 Q02 baseline.
- data_requirements: standard native DWX history.

## Risk And Safety Boundary

The build may create one `RISK_FIXED` XNG backtest setfile only. It must not create
or modify a live setfile, `T_Live`, AutoTrading, deploy manifest, T_Live manifest,
portfolio gate, portfolio admission, or portfolio KPI code.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-10 | initial source-backed XNG return-sign momentum build | Q01 | PENDING |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-10 | APPROVED by mission directive | this card |
| Q01 Build Validation | TBD | PENDING | TBD |
| Q02 Baseline Screening | TBD | PENDING | TBD |
