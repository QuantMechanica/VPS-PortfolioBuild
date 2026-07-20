---
strategy_id: SZAKMARY-XNG-MCH3-2010
source_id: SZAKMARY-XNG-MCH3-2010
ea_id: QM5_20014
slug: xng-month-ch3
status: APPROVED
created: 2026-07-20
created_by: Research
last_updated: 2026-07-20
g0_status: APPROVED
source_citation: "Szakmary, Shen and Sharma (2010), Trend-following trading strategies in commodity futures: A re-examination, Journal of Banking & Finance 34(2), 409-426, DOI 10.1016/j.jbankfin.2009.08.004."
source_citations:
  - type: academic_paper
    citation: "Szakmary, A. C., Shen, Q. and Sharma, S. C. (2010). Trend-following trading strategies in commodity futures: A re-examination. Journal of Banking & Finance, 34(2), 409-426."
    location: "Section III monthly channel rules and commodity table entry NG; DOI https://doi.org/10.1016/j.jbankfin.2009.08.004; full author manuscript https://www.researchgate.net/profile/Andrew-Szakmary/publication/267715955_Price_Momentum_and_Trading_Volume_In_Commodity_Futures_Markets/links/556dae9d08aeccd7773d7aca/Price-Momentum-and-Trading-Volume-In-Commodity-Futures-Markets.pdf"
    quality_tier: A
    role: primary
sources:
  - "[[sources/SZAKMARY-XNG-MCH3-2010]]"
concepts:
  - "[[concepts/commodity-trend-following]]"
  - "[[concepts/month-end-price-channel]]"
indicators:
  - "[[indicators/month-end-close]]"
  - "[[indicators/price-channel]]"
  - "[[indicators/atr]]"
strategy_type_flags: [trend, price-channel, monthly-rebalance, time-stop, symmetric-long-short, atr-hard-stop]
markets: [commodities, energy, natural_gas]
timeframes: [D1]
primary_target_symbols: [XNGUSD.DWX]
target_symbols: [XNGUSD.DWX]
single_symbol_only: true
period: D1
expected_trade_frequency: "Monthly L=3 channel with a conservative prior of 6 completed entry packages/year; Q02 must measure the actual DWX cadence."
expected_trades_per_year_per_symbol: 6
expected_pf: 1.01
expected_dd_pct: 35.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
review_focus: "Falsify the source-defined three-month month-end channel on the Natural Gas CFD proxy; frequency, costs, gap behavior, expectancy and realized correlation to the certified book are unproven."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [friday_close, risk_mode_dual, cfd_futures_basis, low_frequency, portfolio_correlation]
g0_approval_reasoning: "APPROVED under the 2026-07-20 OWNER commodity-sleeve mission: Tier-A single-source lineage; source-defined L=3 monthly close channel and one-month renewal; registered XNG D1 cache; deterministic, ML-free, one position per magic, and materially different from QM5_12567."
---

# Natural Gas Monthly Three-Month Close Channel

## Hypothesis

Commodity trends can persist at monthly horizons because physical supply and
demand adjust slowly. The source tests that persistence with a sparse channel:
the latest completed month-end value must set a new high or low relative to the
prior `L` month ends. This card uses the shortest source-tested horizon,
`L=3`, on Natural Gas as a second XNG sleeve with a signal horizon and payoff
direction that differ from the certified short-horizon RSI pullback.

This is a diversification candidate, not a correlation claim. Q02 and later
portfolio analysis must measure realized overlap with XNG, XAU, SP500 and NDX.

## Source And Evidence Boundary

The sole source lineage is Szakmary, Shen and Sharma (2010),
"Trend-following trading strategies in commodity futures: A re-examination",
*Journal of Banking & Finance* 34(2), 409-426, DOI
https://doi.org/10.1016/j.jbankfin.2009.08.004, together with the complete
author-uploaded predecessor manuscript that states the rule. The manuscript's
commodity table explicitly includes Natural Gas. Section III uses completed
monthly unit values, `L={3,6,9,12}`, a flat state inside the prior channel, and
one-month holding periods.

The study supplies broad commodity-futures evidence rather than a guaranteed
Natural Gas result. The target is a continuous Darwinex CFD rather than the
paper's rolled nearby-futures unit-value series. No paper return, Sharpe ratio
or transaction-cost estimate is treated as evidence for this carrier.

## Concept And Non-Duplicate Decision

On the first tradable `XNGUSD.DWX` D1 bar of a broker month, reconstruct the
four latest distinct completed month-end closes:

`C0 = just-completed month`, and `C1, C2, C3 = its three predecessors`.

- BUY for the new month when `C0 > max(C1,C2,C3)`.
- SELL for the new month when `C0 < min(C1,C2,C3)`.
- Stay flat on equality or while `C0` is inside the prior channel.

The old monthly package is always closed before the new signal is evaluated;
if direction repeats, the source's one-month holding design renews the package
instead of carrying the old trade indefinitely.

Repository-wide card, EA and source searches found no XNG implementation of
this completed-month mechanic. `QM5_20008_wti-month-ch3` is the disclosed WTI
carrier of the same source rule, so the verdict is
`NEW_XNG_CARRIER_MECHANIC_COMBINATION`, not a globally new signal family.

It is materially different from the incumbent and nearest XNG designs:

- `QM5_12567_cum-rsi2-commodity` uses cumulative RSI(2), a 200-day trend
  filter and a short pullback lifecycle rather than monthly price continuation.
- `QM5_12804_xng-tsmom12m-atr` uses a 12-month return sign plus ATR corridor.
- `QM5_13116_xng-pred12m` uses a 12-month probability threshold.
- `QM5_20013_xng-2m-contr` fades the prior two-month return.
- Daily channels and event-window cards use daily extrema or event calendars,
  not four distinct completed month-end closes with one-month renewal.

## Markets And Timeframe

- Target symbol: `XNGUSD.DWX` only, magic slot 0.
- Host and signal timeframe: D1.
- Decision cadence: first D1 bar of each broker-calendar month.
- Expected frequency: 6 completed entry packages/year as a conservative prior;
  Q02 is authoritative and must kill the card below five/year.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.
- Runtime data: native MT5 D1 closes, ATR, spread, calendar, deal history and
  position state only.

## 4. Entry Rules

- Evaluate only once on the first new `XNGUSD.DWX` D1 bar of a broker month.
- Reconstruct exactly four distinct completed month-end closes from a bounded
  180-D1-bar history scan, newest first.
- Set `C0=closes[0]`; calculate the maximum and minimum across `closes[1..3]`.
- BUY when `C0` is strictly above that maximum.
- SELL when `C0` is strictly below that minimum.
- Do not enter on equality or while `C0` lies inside the channel.
- Require valid history, prices and ATR, spread no greater than 3000 points, no
  open same-magic package after renewal, and no earlier entry deal in the
  current broker month.
- Place a frozen `4.0 * ATR(20)` D1 hard stop; no take-profit.

## 5. Exit Rules

- On the first tradable D1 bar of the next broker month, close the prior
  package before evaluating the new channel state, even if direction repeats.
- Close if a position reaches `strategy_max_hold_days=35` as a stale guard.
- The broker hard stop remains active within the month.
- No intramonth channel exit, opposite daily breakout, target profit, trailing
  stop, break-even move or discretionary exit.

## 6. Filters (No-Trade Module)

- Exact host guard: `XNGUSD.DWX`, D1, magic slot 0.
- All strategy parameters are locked to the card baseline; history, price,
  arithmetic, ATR and spread checks fail closed.
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

| parameter | default | authorized baseline | role |
|---|---:|---:|---|
| `strategy_channel_months` | 3 | 3 | source-tested prior-month channel length |
| `strategy_history_bars` | 180 | 180 | bounded D1 month-end reconstruction |
| `strategy_atr_period` | 20 | 20 | V5 frozen hard-stop estimate |
| `strategy_atr_sl_mult` | 4.0 | 4.0 | frozen hard-stop distance |
| `strategy_max_hold_days` | 35 | 35 | stale guard around monthly renewal |
| `strategy_max_spread_points` | 3000 | 3000 | XNG entry spread cap |

The completed-month comparison, strict inequality, flat inside state,
one-month holding and monthly renewal are locked. The paper's other channel
horizons are not authorized variants of this card. A daily channel, continuous
state hold, RSI, moving average, seasonality or event gate requires a new card.

## Initial Risk Profile

- `expected_pf: 1.01` is a conservative queue-ordering prior, not evidence.
- `expected_dd_pct: 35.0` reflects Natural Gas gaps, false breakouts and
  futures/CFD basis risk.
- Risk class: high.
- The paper does not use this broker ATR stop. V5 fixed-risk sizing requires a
  deterministic server-side stop; its effect must be tested rather than
  attributed to the source.

## Kill Criteria

- Retire at Q02 if realized frequency is below five completed trades/year.
- Fail on zero trades, invalid month-end reconstruction, repeated `OnInit`
  failure, nondeterministic reruns, risk-mode mismatch or unacceptable PF/DD.
- Do not shorten the lookback, add daily breakouts, convert the flat state into
  a hold state, or widen the strategy after a poor baseline.
- Treat rolled-futures versus DWX-CFD basis and realized book correlation as
  falsification risks, never as waiver grounds.

## Strategy Allowability Check

- [x] R1 reputable: one peer-reviewed Journal of Banking & Finance source
  lineage with DOI and a complete author-uploaded manuscript.
- [x] R2 mechanical: fixed completed-month closes, strict prior-three extrema,
  flat state, monthly renewal, ATR stop and stale guard.
- [x] R3 testable: registered `XNGUSD.DWX` D1 cache covers 2017-2026; no
  external runtime data is required.
- [x] R4 compliant: no ML, banned indicator, external runtime feed, adaptive
  fit, grid, martingale or pyramiding.
- [x] The card prior is 6 trades/year and is explicitly falsifiable at Q02.
- [x] XNG mechanic dedup searches are clean; the WTI family carrier is disclosed.

## Framework Alignment

- no_trade: exact XNG/D1/slot, locked parameter, price, history, spread,
  monthly-deal and one-position guards.
- trade_entry: latest completed month end versus the prior-three month-end
  extremes, with a frozen V5 ATR hard stop.
- trade_management: close every monthly package at renewal and enforce the
  35-day stale guard before the entry-news gate.
- trade_close: `QM_TM_ClosePosition(..., QM_EXIT_STRATEGY)` plus broker stop.

`hard_rules_at_risk`:

- `friday_close`: disabled only for the source-aligned one-month hold.
- `risk_mode_dual`: the build creates only a `RISK_FIXED` backtest setfile.
- `cfd_futures_basis`: source uses rolled futures; equivalence is not assumed.
- `portfolio_correlation`: diversification is an objective to test, not a G0
  assertion and not grounds to touch the portfolio gate.

## Risk And Safety Boundary

The build may create one `RISK_FIXED` XNG backtest setfile only. It must not
create or modify a live setfile, `T_Live`, AutoTrading, deploy manifest,
T_Live manifest, portfolio admission or the portfolio gate.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-20 | initial source-backed XNG monthly CH3 build | Q02 | G0 approved; build/Q02 pending |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-20 | APPROVED under OWNER commodity-sleeve mission | this card |
| Q01 Build Validation | 2026-07-20 | pending | `artifacts/qm5_20014_build_result.json` |
| Q02 Baseline Screening | 2026-07-20 | pending enqueue | paced fleet; no manual dispatch |
