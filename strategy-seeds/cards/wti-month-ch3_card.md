---
strategy_id: SZAKMARY-WTI-MCH3-2010
source_id: SZAKMARY-WTI-MCH3-2010
ea_id: QM5_20008
slug: wti-month-ch3
status: DRAFT
created: 2026-07-19
created_by: Research
last_updated: 2026-07-19
g0_status: PENDING
source_citation: "Szakmary, Shen and Sharma (2010), Trend-following trading strategies in commodity futures: A re-examination, Journal of Banking & Finance 34(2), 409-426, DOI 10.1016/j.jbankfin.2009.08.004."
source_citations:
  - type: academic_paper
    citation: "Szakmary, A. C., Shen, Q. and Sharma, S. C. (2010). Trend-following trading strategies in commodity futures: A re-examination. Journal of Banking & Finance, 34(2), 409-426."
    location: "Section 3 monthly channel rules; DOI https://doi.org/10.1016/j.jbankfin.2009.08.004; full author manuscript https://www.researchgate.net/profile/Andrew-Szakmary/publication/267715955_Price_Momentum_and_Trading_Volume_In_Commodity_Futures_Markets/links/556dae9d08aeccd7773d7aca/Price-Momentum-and-Trading-Volume-In-Commodity-Futures-Markets.pdf"
    quality_tier: A
    role: primary
sources:
  - "[[sources/SZAKMARY-WTI-MCH3-2010]]"
concepts:
  - "[[concepts/commodity-trend-following]]"
  - "[[concepts/month-end-price-channel]]"
indicators:
  - "[[indicators/month-end-close]]"
  - "[[indicators/price-channel]]"
  - "[[indicators/atr]]"
strategy_type_flags: [trend, price-channel, monthly-rebalance, time-stop, symmetric-long-short, atr-hard-stop]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
primary_target_symbols: [XTIUSD.DWX]
target_symbols: [XTIUSD.DWX]
single_symbol_only: true
period: D1
expected_trade_frequency: "Source-tested L=3 monthly channel; local DWX cadence precheck found 65 signals over 2018-2025, approximately 8.21 completed trades/year."
expected_trades_per_year_per_symbol: 8
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q00
review_focus: "Falsify the source-exact three-month month-end channel on the WTI CFD proxy; cadence is prechecked, but futures-to-CFD basis, costs, WTI-specific efficacy and realized book correlation are unproven."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [friday_close, risk_mode_dual, cfd_futures_basis, low_frequency]
---

# WTI Monthly Three-Month Close Channel

## Hypothesis

Commodity trends can persist at monthly horizons because physical supply and
demand adjust slowly. The source tests that persistence with a sparse channel:
the latest completed month-end value must set a new high or low relative to the
prior `L` month ends. This card uses the source's shortest tested horizon,
`L=3`, on WTI to add direct crude-oil exposure that is structurally different
from the certified XAU, SP500, NDX and XNG sleeves.

## Source And Evidence Boundary

The sole source lineage is Szakmary, Shen and Sharma (2010),
"Trend-following trading strategies in commodity futures: A re-examination",
*Journal of Banking & Finance* 34(2), 409-426, DOI
https://doi.org/10.1016/j.jbankfin.2009.08.004, together with the complete
author-uploaded predecessor manuscript that states the rule. Section III uses
completed monthly unit values, `L={3,6,9,12}`, a flat state inside the prior
channel, and one-month holding periods.

The study supplies broad commodity-futures evidence rather than a guaranteed
WTI result. The target is a continuous Darwinex CFD rather than the paper's
rolled nearby-futures unit-value series. No paper return, Sharpe ratio or
transaction-cost estimate is treated as evidence for this carrier.

## Concept And Non-Duplicate Decision

On the first tradable `XTIUSD.DWX` D1 bar of a broker month, reconstruct the
four latest distinct completed month-end closes:

`C0 = just-completed month`, and `C1, C2, C3 = its three predecessors`.

- BUY for the new month when `C0 > max(C1,C2,C3)`.
- SELL for the new month when `C0 < min(C1,C2,C3)`.
- Stay flat otherwise.

The old monthly package is always closed before the new signal is evaluated;
if the direction repeats, the source's one-month holding design still renews
the package rather than carrying the old trade indefinitely.

No exact card or EA uses this XTI mechanic. It is distinct from:

- `QM5_13100_wti-dmac16`, which compares a month end with a six-month mean and
  2.5% band, then holds an unchanged state across months.
- `QM5_1226_psaradellis-oil-channel`, a daily 55/20 high-low channel.
- `QM5_12844_commodity-trend-crude`, a daily Donchian-20 plus ADX and trail.
- `QM5_12780_wti-52w-anchor`, a 252-D1 anchor plus 63-D1 confirmation.
- `QM5_12810_wti-month-orb`, the first five daily bars' opening range.
- `QM5_12616_tsmom-9m-commodity-xtiusd`, 3/9-month return agreement.

The automated and manual collision searches found no XTI monthly-close versus
prior-three-month-close-extrema rule. The verdict is `NO_EXACT_OR_MECHANIC_DUPLICATE`.

## Markets And Timeframe

- Target symbol: `XTIUSD.DWX` only, magic slot 0.
- Host and signal timeframe: D1.
- Decision cadence: first D1 bar of each broker-calendar month.
- Expected frequency: 8 completed packages/year. A read-only parse of local
  2018-2025 D1 history found 65 signals, or 8.21/year; Q02 is authoritative.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.
- Runtime data: native MT5 D1 closes, ATR, spread, calendar, deal history and
  position state only.

## Rules

The following entry, exit, filter and lifecycle rules are the complete
authorized baseline. Anything not stated here is out of scope.

## 4. Entry Rules

- Evaluate only once on the first new `XTIUSD.DWX` D1 bar of a broker month.
- Reconstruct `strategy_channel_months + 1` distinct completed month-end
  closes from a bounded D1 history scan, newest first.
- Default `strategy_channel_months=3`; set `C0=closes[0]` and calculate the
  maximum and minimum across `closes[1..3]` only.
- BUY when `C0` is strictly above that maximum.
- SELL when `C0` is strictly below that minimum.
- Do not enter on equality or while `C0` lies inside the channel.
- Require valid history, prices and ATR, acceptable spread, no open same-magic
  package after renewal, and no earlier entry deal in the current broker month.
- Place a frozen `4.0 * ATR(20)` D1 hard stop; no take-profit.

## 5. Exit Rules

- On the first tradable D1 bar of the next broker month, close the prior
  package before evaluating the new channel state, even if direction repeats.
- Close if a position reaches `strategy_max_hold_days=35` as a stale guard.
- The broker hard stop remains active within the month.
- No intramonth channel exit, opposite daily breakout, target profit, trailing
  stop, break-even move or discretionary exit.

## 6. Filters (No-Trade Module)

- Exact host guard: `XTIUSD.DWX`, D1, magic slot 0.
- Parameter, history, price, arithmetic, ATR and spread checks fail closed.
- Zero modeled `.DWX` spread is valid; only a genuinely wide positive spread
  blocks entry.
- Framework kill switch and news-entry compliance remain authoritative.

## 7. Trade Management Rules

- One position per magic and at most one entry package per broker month.
- A current-month position or current-month entry deal blocks restart re-entry.
- No scale-in, partial close, grid, martingale, pyramiding, adaptive parameter,
  external feed, banned indicator or ML.
- Friday close is disabled to preserve the source's one-month holding period;
  the broker hard stop, next-month renewal and 35-day stale guard remain active.

## Parameters To Test

| parameter | default | source/card range | role |
|---|---:|---|---|
| `strategy_channel_months` | 3 | [3, 6, 9, 12] | source-tested prior-month channel length; Q02 baseline is 3 |
| `strategy_history_bars` | 180 | [140, 180, 260, 400] | bounded D1 month-end reconstruction |
| `strategy_atr_period` | 20 | [14, 20, 30] | V5 frozen hard-stop estimate |
| `strategy_atr_sl_mult` | 4.0 | [3.0, 4.0, 5.0] | frozen hard-stop distance |
| `strategy_max_hold_days` | 35 | [35] | stale guard around monthly renewal |
| `strategy_max_spread_points` | 1500 | [1000, 1500, 2500] | WTI entry spread cap |

The channel comparison, strict inequality, completed month-end sampling, flat
inside state, one-month holding and monthly renewal are locked. Q02 uses `L=3`.
The other source horizons are predeclared only for later phase variants, never
an unconstrained fit. A daily channel, continuous state hold, close-location
filter, ADX, moving average, seasonality or event gate requires a new card.

## Initial Risk Profile

- `expected_pf: 1.01` is a conservative queue-ordering prior, not evidence.
- `expected_dd_pct: 30.0` reflects WTI gaps, false breakouts and CFD/futures
  basis risk.
- Risk class: high.
- The paper does not use this broker ATR stop. V5 fixed-risk sizing needs a
  deterministic server-side stop; its effect must be tested rather than
  attributed to the source.

## Kill Criteria

- Retire at Q02 if realized frequency is below five completed trades/year.
- Fail on zero trades, invalid month-end reconstruction, repeated `OnInit`
  failure, nondeterministic reruns, risk-mode mismatch or unacceptable PF/DD.
- Do not shorten the lookback below three, add daily breakouts, convert the flat
  state into a hold state, or widen the strategy after a poor baseline.
- Treat rolled-futures versus DWX-CFD basis and realized book correlation as
  falsification risks, never as waiver grounds.

## Strategy Allowability Check

- [x] R1 reputable: one peer-reviewed Journal of Banking & Finance source
  lineage with DOI and a complete author-uploaded manuscript.
- [x] R2 mechanical: fixed completed-month closes, strict prior-three extrema,
  flat state, monthly renewal, ATR stop and stale guard.
- [x] R3 testable: registered `XTIUSD.DWX` D1 data is available; local signal
  cadence is 8.21/year.
- [x] R4 compliant: no ML, banned indicator, external runtime feed, adaptive
  fit, grid, martingale or pyramiding.
- [x] Expected frequency exceeds the five-trades/year Q02 floor.
- [x] Exact and mechanic dedup searches are clean.

## Framework Alignment

- no_trade: exact WTI/D1/slot, parameter, price, history, spread, monthly deal
  and one-position guards.
- trade_entry: source-defined latest month end versus the prior-three month-end
  extremes, with a frozen V5 ATR hard stop.
- trade_management: close every monthly package at renewal and enforce the
  35-day stale guard before the entry-news gate.
- trade_close: `QM_TM_ClosePosition(..., QM_EXIT_STRATEGY)` plus broker stop.

`hard_rules_at_risk`:

- `friday_close`: disabled only for the source-aligned one-month hold.
- `risk_mode_dual`: the build creates only a RISK_FIXED backtest setfile.
- `cfd_futures_basis`: source uses rolled futures; equivalence is not assumed.

## Risk And Safety Boundary

The build may create one `RISK_FIXED` WTI backtest setfile only. It must not
create or modify a live setfile, `T_Live`, AutoTrading, deploy manifest,
T_Live manifest, portfolio gate, portfolio admission or portfolio KPI code.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-19 | initial source-backed WTI monthly CH3 build | Q00 | DRAFT |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-19 | PENDING OWNER-directed R1-R4 approval | this card |
| Q01 Build Validation | - | pending | - |
| Q02 Baseline Screening | - | pending enqueue | - |
