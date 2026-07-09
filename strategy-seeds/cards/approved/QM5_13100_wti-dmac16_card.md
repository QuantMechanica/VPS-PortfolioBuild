---
ea_id: QM5_13100
slug: wti-dmac16
type: strategy
strategy_id: SZAKMARY-WTI-DMAC16-2010
source_id: SZAKMARY-WTI-DMAC16-2010
created: 2026-07-09
created_by: Research
last_updated: 2026-07-09
source_citation: "Szakmary, Shen and Sharma (2010), Trend-following trading strategies in commodity futures: A re-examination, Journal of Banking and Finance 34(2), 409-426, DOI 10.1016/j.jbankfin.2009.08.004."
source_citations:
  - type: academic_paper
    citation: "Szakmary, A. C., Shen, Q. and Sharma, S. C. (2010). Trend-following trading strategies in commodity futures: A re-examination. Journal of Banking and Finance, 34(2), 409-426."
    location: "Methodology: monthly dual-moving-average crossover rules; DOI https://doi.org/10.1016/j.jbankfin.2009.08.004"
    quality_tier: A
    role: primary
  - type: official_exchange_page
    citation: "CME Group. WTI Crude Oil Futures."
    location: "https://www.cmegroup.com/markets/energy/wti-crude-oil-futures.html"
    quality_tier: A
    role: supplement
sources:
  - "[[sources/SZAKMARY-WTI-DMAC16-2010]]"
concepts:
  - "[[concepts/commodity-trend-following]]"
  - "[[concepts/monthly-neutral-band]]"
  - "[[concepts/dual-moving-average]]"
indicators:
  - "[[indicators/month-end-close]]"
  - "[[indicators/simple-moving-average]]"
  - "[[indicators/atr]]"
strategy_type_flags: [trend-filter-ma, signal-reversal-exit, atr-hard-stop, symmetric-long-short, news-blackout]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [commodities, energy, crude_oil]
single_symbol_only: true
logical_symbol: QM5_13100_WTI_DMAC16_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "Monthly 1/6-month DMAC state changes; estimate 1-5 entries/year before Q02 validation."
expected_trades_per_year_per_symbol: 3
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
expected_pf: 1.08
expected_dd_pct: 25.0
risk_class: high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [friday_close, enhancement_doctrine]
g0_approval_reasoning: "Mission-directed G0 approval 2026-07-09: R1 PASS peer-reviewed commodity-futures trend paper plus official CME WTI reference; R2 PASS source-defined monthly 1/6 moving-average state with a 2.5% neutral band, ATR hard stop, and deterministic band/reversal exits; R3 PASS XTIUSD.DWX available; R4 PASS no ML/grid/martingale/external runtime feed."
---

# WTI Monthly 1/6 DMAC Neutral-Band Trend

## Hypothesis

Commodity trends can persist at multi-month horizons because supply and demand
adjust slowly while market participants rebalance over time. This EA tests the
source's monthly dual-moving-average rule on `XTIUSD.DWX`, taking WTI exposure
only when the latest month-end close is more than 2.5% away from its six-month
mean and staying flat in the neutral zone.

The target is a sparse crude-oil sleeve for a book concentrated in XAU, SP500,
NDX, and XNG. WTI exposure is economically distinct from those certified
sleeves, but Q02 and later portfolio gates must reject it if the CFD port does
not survive costs or remains materially correlated with the existing book.

## Source

- Primary: Szakmary, A. C., Shen, Q. and Sharma, S. C. (2010),
  "Trend-following trading strategies in commodity futures: A re-examination",
  *Journal of Banking & Finance*, 34(2), 409-426, DOI
  https://doi.org/10.1016/j.jbankfin.2009.08.004.
- Supplement: CME Group, "WTI Crude Oil Futures", URL
  https://www.cmegroup.com/markets/energy/wti-crude-oil-futures.html.

The paper supplies the trading-rule lineage and the selected 1/6-month, 2.5%
band parameterization. CME establishes WTI benchmark exposure. No source
performance number is treated as an expected result for this CFD port.

## Concept

On the first D1 bar of each new broker-calendar month, reconstruct the six most
recent completed month-end closes. The latest month-end close is the one-month
short value. The arithmetic mean of all six month-end closes is the long value.

- Long state: `short_value > long_mean * (1 + 0.025)`.
- Short state: `short_value < long_mean * (1 - 0.025)`.
- Flat state: short value remains inside or on the band.

Hold an existing position while its state remains unchanged. Close on a flat
state and close/reverse on an opposite state. The V5 port adds only an ATR hard
stop for deterministic fixed-risk sizing.

## Rules

Trade only `XTIUSD.DWX` on a D1 host and evaluate only on the first new D1 bar
of a broker-calendar month. Read the six latest completed MN1 closes, treat the
newest as the short value, and compare it with their six-value arithmetic mean.
Hold or enter long above the 2.5% upper band, hold or enter short below the 2.5%
lower band, and flatten inside the band. Close/reverse at a monthly state flip;
every new entry carries a frozen ATR hard stop and no take-profit.

## Non-Duplicate Boundary

- `QM5_1110_unger-crude-ma-crossover`: M15 SMA(30/140) cross with a five-session
  cap; this card samples monthly endpoints, uses a six-month mean and a 2.5%
  stand-aside band, and can hold across months.
- `QM5_12603_wti-tsmom12m`: uses the sign of a 252-D1 return; no monthly moving
  average or price-relative band.
- `QM5_12616_tsmom-9m-commodity-xtiusd`: requires 3/9-month return agreement;
  this rule is one-month value versus a six-month average.
- `QM5_12711_commodity-tsmom-dual-6-12`: aligns 6/12-month returns rather than
  testing the source's 1/6 moving-average band.
- `QM5_12780_wti-52w-anchor`: trades proximity to annual highs/lows with a
  63-D1 confirmation; this rule has no annual extreme.
- `QM5_12844_commodity-trend-crude` and other Donchian/Turtle builds: channel
  extremes and ADX are absent here.
- `QM5_13049_xti-1w-mom-vol`: weekly one-week return and low-volatility gate;
  neither is used here.
- `QM5_12567_cum-rsi2-commodity`: no RSI or two-day cumulative pullback signal.
- No WPSR, OPEC, COT, refinery, production, storage, roll, expiry, weekday,
  month-of-year, XTI/XNG, WTI/Brent, oil/metal, or external-feed logic is used.

## Markets And Timeframe

- Target: `XTIUSD.DWX` only.
- Host and signal timeframe: D1.
- Decision cadence: one evaluation at each broker-calendar month transition.
- Expected frequency: approximately 1-5 entries/year before Q02 validation.
- Backtest risk mode: `RISK_FIXED`.

## Entry Rules

- Evaluate only after `QM_IsNewBar()` on `XTIUSD.DWX` D1.
- Require the current D1 bar and prior completed D1 bar to belong to different
  broker-calendar months.
- Collect exactly `strategy_long_months` distinct completed month-end closes,
  newest first, using D1 history only.
- `short_value = newest completed month-end close`.
- `long_mean = arithmetic mean of the completed month-end close sample`.
- Long if `short_value > long_mean * (1 + strategy_band_pct / 100)`.
- Short if `short_value < long_mean * (1 - strategy_band_pct / 100)`.
- Do not enter inside or on the neutral band.
- Do not enter if this magic already holds the target state, if the same month
  was already accepted, or if spread exceeds `strategy_max_spread_points`.
- Place a frozen ATR(`strategy_atr_period`) hard stop at
  `strategy_atr_sl_mult` from entry; no take-profit.

## Exit Rules

- At the next monthly evaluation, close a long if the state becomes flat or
  short.
- At the next monthly evaluation, close a short if the state becomes flat or
  long.
- If the state reverses and the close succeeds, allow one opposite entry on
  that same new-bar evaluation.
- Broker hard stop remains active between monthly evaluations.
- No fixed profit target, daily crossover, trailing stop, or time exit.
- Friday close is explicitly disabled: the source requires month-to-month
  holding, and forced weekly flattening would replace the source rule.

## Filters

- Wrong symbol/timeframe, nonzero magic slot, invalid parameters, incomplete
  monthly history, open same-direction position, duplicate month, and excessive
  spread reject entry.
- Standard V5 kill switch and news entry blackout remain active.
- Runtime is Darwinex-native only: OHLC, ATR, spread, broker calendar, and
  framework state.

## Trade Management Rules

- One position per magic/symbol.
- No pyramiding, scale-in, partial close, break-even move, grid, martingale, or
  adaptive sizing.
- Monthly band state is the sole strategy-management signal.

## Parameters To Test

- name: strategy_long_months
  default: 6
  sweep_range: [3, 6, 9, 12]
- name: strategy_band_pct
  default: 2.5
  sweep_range: [1.25, 2.5, 3.75, 5.0]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 4.0
  sweep_range: [3.0, 4.0, 5.0]
- name: strategy_max_spread_points
  default: 1500
  sweep_range: [1000, 1500, 2500]

The four source DMAC horizons pair 3/6/9/12 months with 1.25/2.5/3.75/5.0%
bands respectively. P3 must test those as paired source variants, not as an
unconstrained Cartesian optimization. Q02 uses only the 1/6/2.5% card default.

## Author Claims

"all parameterizations of the dual moving average crossover and channel
strategies that we implement yield positive mean excess returns net of
transactions costs" (Szakmary, Shen and Sharma, 2010, abstract)

"WTI is the go-to measure for the world oil price." (CME Group, WTI product
page)

## Initial Risk Profile

- expected_pf: 1.08.
- expected_dd_pct: 25.
- expected_trade_frequency: approximately 1-5 entries/year.
- risk_class: high because WTI gaps, roll/basis differences, and long-lived
  false trends can defeat the monthly signal before the next state change.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] Mechanical: fixed month-end sampling, six-month arithmetic mean, 2.5%
  band, symmetric state rules, and ATR hard stop.
- [x] Reputable source: peer-reviewed Journal of Banking & Finance paper plus
  official CME benchmark reference.
- [x] Testable: `XTIUSD.DWX` exists in the local DWX symbol universe.
- [x] No ML, adaptive PnL fitting, grid, martingale, pyramiding, or external
  runtime feed.
- [x] Friday-close exception documented: disabled to preserve the source's
  month-to-month position state; the exception is backtest-only at this stage.
- [x] Non-duplicate: source-defined monthly 1/6 DMAC neutral band, not another
  WTI daily crossover, return-sign, multi-horizon return, channel, RSI, event,
  or calendar-seasonality rule.

## Risk

Q02 uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, and one
`XTIUSD.DWX` D1 backtest setfile. The EA has no live setfile and does not touch
`T_Live`, AutoTrading, deploy manifests, the T_Live manifest, portfolio
admission, or the portfolio gate.

## Framework Alignment

- no_trade: enforce XTI D1, slot 0, valid source parameters, complete monthly
  history, spread cap, one-position, and one-entry-per-month constraints.
- trade_entry: reconstruct month-end closes and map the 1/6-month 2.5%-band
  state into a long or short market request with an ATR hard stop.
- trade_management: at a month transition, retain matching exposure, flatten
  neutral exposure, and close exposure opposed to the new state.
- trade_close: band-neutral and band-reversal exits through
  `QM_TM_ClosePosition`; broker ATR stop remains the intramonth backstop.

## Hard Rules At Risk

- `friday_close`: disabled by card authorization because weekly flattening is
  incompatible with a monthly holding rule. Any later live consideration must
  re-review this explicit exception.
- `enhancement_doctrine`: changing the monthly horizon or band changes entry
  evidence and requires a full rerun; only the paired source variants listed
  above are predeclared.

## Falsification

Reject or recycle if Q02 produces too few trades for the scaled low-frequency
floor, fails PF/DD gates, or shows that the DWX CFD history cannot reproduce the
monthly endpoint rule. Do not promote if later portfolio evidence shows high
correlation with the XAU/SP500/NDX/XNG book instead of distinct WTI exposure.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-09 | initial source-exact WTI monthly DMAC build | Q02 | PENDING |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-09 | APPROVED | this card |
| Q01 Build Validation | 2026-07-09 | PASS | `artifacts/qm5_13100_build_result.json` |
| Q02 Baseline Screening | 2026-07-09 | PENDING | work item `7e88f78a-e0e9-4d3e-adb0-8d2a124c8f1b` |
