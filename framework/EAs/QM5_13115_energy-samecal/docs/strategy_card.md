---
ea_id: QM5_13115
slug: energy-samecal
type: strategy
strategy_id: KELOHARJU-RETSEAS-2016_XTI_XNG_S01
source_id: KELOHARJU-RETSEAS-2016
status: APPROVED
created: 2026-07-10
created_by: Research
last_updated: 2026-07-10
g0_status: APPROVED
source_citation: "Keloharju, Linnainmaa, and Nyberg (2016), Return Seasonalities, Journal of Finance 71(4), 1557-1590, DOI 10.1111/jofi.12398."
source_citations:
  - type: peer_reviewed_paper
    citation: "Keloharju, Matti; Linnainmaa, Juhani T.; and Nyberg, Peter (2016). Return Seasonalities. The Journal of Finance 71(4), 1557-1590."
    location: "Commodity evidence and construction in Sections 5.4.3-5.6 and Tables 8-9; DOI https://doi.org/10.1111/jofi.12398; complete open NBER version https://www.nber.org/system/files/working_papers/w20815/w20815.pdf"
    quality_tier: A
    role: primary
sources:
  - "[[sources/KELOHARJU-RETSEAS-2016]]"
concepts:
  - "[[concepts/same-calendar-month-seasonality]]"
  - "[[concepts/energy-relative-value]]"
  - "[[concepts/seasonal-risk-premium]]"
indicators:
  - "[[indicators/month-end-close]]"
  - "[[indicators/cross-sectional-rank]]"
  - "[[indicators/atr]]"
strategy_type_flags: [atr-hard-stop, time-stop, signal-reversal-exit, symmetric-long-short, news-blackout]
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
primary_target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
markets: [commodities, energy, crude_oil, natural_gas]
single_symbol_only: false
logical_symbol: QM5_13115_ENERGY_SAMECAL_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "One market-neutral monthly energy package after warm-up; estimate 10-12 completed packages/year before Q02 validation."
expected_trades_per_year_per_symbol: 11
expected_pf: 1.05
expected_dd_pct: 22.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
review_focus: "Adds market-neutral energy calendar-risk-premium exposure to the XAU/SP500/NDX/XNG book; realized orthogonality is unclaimed until Q09."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [basket_execution, friday_close, magic_schema, risk_mode_dual, cfd_futures_basis]
g0_approval_reasoning: "Mission-directed G0 2026-07-10: R1 peer-reviewed Journal of Finance source with complete open NBER text and explicit crude-oil/natural-gas commodity panel; R2 locked monthly same-calendar-month energy rank plus deterministic V5 basket exits; R3 native registered XTI/XNG D1; R4 no ML/banned/external/grid/martingale; pre-allocation dedup CLEAN."
---

# XTI/XNG Same-Calendar-Month Energy Seasonality

## Hypothesis

Expected commodity risk premia can recur in the same calendar month because
physical demand, storage, hedging, and capital-allocation pressures are
seasonal. Keloharju, Linnainmaa, and Nyberg document a cross-sectional
same-calendar-month effect across 24 commodity futures, explicitly including
crude oil and natural gas. This card tests a constrained energy carrier: buy
the energy leg with the higher historical return in the current calendar month
and short the lower-ranked leg.

The package is market-neutral by construction and adds a calendar-risk-premium
driver rather than another outright XNG pullback or broad metal/index signal.
That makes low correlation plausible, not proven; Q09 is the only portfolio
orthogonality judge.

## Source And Evidence Boundary

The primary source is the peer-reviewed 2016 *Journal of Finance* article,
DOI `10.1111/jofi.12398`; the complete NBER version was read end to end. The
paper states: "We document similar return seasonalities in anomalies,
commodities, international stock market indices, and at the daily frequency."

Its commodity strategy ranks a broad futures cross-section by average
same-calendar-month returns over prior history, with at least five years of
data, then holds high-ranked commodities long and low-ranked commodities short
for one month. The source's marginal diversified commodity result is not
imported as a QM expectation. A two-leg continuous-CFD port has materially less
diversification and different roll/basis economics.

## Concept And Non-Duplicate Decision

On the first tradable `XTIUSD.DWX` D1 bar of each broker month, reconstruct the
same calendar month's completed return for XTI and XNG in prior years. Average
the synchronized yearly relative returns:

`seasonal_score = mean(return_XTI(year, month) - return_XNG(year, month))`.

- Positive score: buy XTI and sell XNG.
- Negative score: sell XTI and buy XNG.
- Missing or insufficient history: remain flat.

This differs mechanically from:

- `QM5_12733_xti-xng-xmom`, which ranks recent momentum.
- `QM5_12840_xti-xng-rspread`, which fades a short-horizon return z-score.
- `QM5_12850_xti-xng-vcb`, which trades a volatility-contraction breakout.
- `QM5_13089_xti-xng-carry`, which ranks broker carry/swap.
- `QM5_13113_energy-mom-ivol`, which requires momentum and residual-volatility
  rank agreement.
- Fixed-direction WTI/XNG month cards, which do not rerank the two assets from
  rolling same-calendar-month history.
- `QM5_12567_cum-rsi2-commodity`, which uses RSI pullback logic and no
  market-neutral energy rank.

Pre-allocation repository dedup verdict: `CLEAN` for slug `energy-samecal`,
strategy ID `KELOHARJU-RETSEAS-2016_XTI_XNG_S01`, and the complete monthly
energy-rank mechanic.

## Markets And Timeframe

- Logical basket: `QM5_13115_ENERGY_SAMECAL_D1`.
- Host/traded slot 0: `XTIUSD.DWX` D1.
- Traded slot 1: `XNGUSD.DWX` D1.
- Expected frequency: 10-12 completed paired packages/year after warm-up.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`, split equally across the two legs.
- Runtime data: native MT5 D1 OHLC, ATR, spread, broker calendar, and position
  state only.

## Rules

- Evaluate only on the first new `XTIUSD.DWX` D1 bar of a broker month.
- Copy a bounded D1 history for XTI and XNG.
- For each prior year in `strategy_history_years`, locate the last completed
  D1 close of the current calendar month and the immediately preceding month.
- Require synchronized positive closes for both legs and compute each log
  monthly return.
- Require at least `strategy_min_history_years` synchronized samples.
- Average `return_XTI - return_XNG` across those samples.
- If the average is positive, open BUY XTI plus SELL XNG.
- If the average is negative, open SELL XTI plus BUY XNG.
- No entry on an exact numerical tie, invalid arithmetic, excessive spread,
  invalid ATR, an existing package, or a month already attempted.
- Allocate half the fixed package-risk budget to each leg and place a frozen
  per-leg ATR hard stop.

## Exit Rules

- Close both legs on the first tradable D1 bar of the next broker month, then
  rerank and allow one new package.
- Close both legs if the package exceeds `strategy_max_hold_days=35`.
- If either hard stop removes one leg, flatten the orphaned leg immediately.
- Close an unexpected package side or invalid magic composition.
- Friday close is disabled to preserve the source's one-month holding period.

## Filters And Trade Management

- Exact host guard: `XTIUSD.DWX`, D1, magic slot 0.
- Parameter, history, arithmetic, ATR, volume-step, and spread checks fail
  closed.
- One two-leg package per EA; no re-entry after a stop within the same month.
- No take-profit, trailing stop, break-even move, partial close, scale-in,
  grid, martingale, pyramiding, or adaptive PnL rule.
- Framework kill switch and news entry compliance remain authoritative.

## Parameters To Test

| parameter | default | authorized range | role |
|---|---:|---|---|
| `strategy_history_years` | 10 | [5, 10] | bounded prior same-month sample |
| `strategy_min_history_years` | 5 | [5] | source minimum-history requirement |
| `strategy_history_bars` | 3000 | [1800, 3000] | bounded D1 reconstruction buffer |
| `strategy_atr_period_d1` | 20 | [14, 20, 30] | per-leg hard-stop volatility estimate |
| `strategy_atr_sl_mult` | 3.5 | [2.5, 3.5, 5.0] | frozen per-leg stop distance |
| `strategy_max_hold_days` | 35 | [35] | stale guard around monthly reset |
| `strategy_xti_max_spread_pts` | 1500 | [1000, 1500, 2500] | XTI entry spread cap |
| `strategy_xng_max_spread_pts` | 3000 | [2000, 3000, 4500] | XNG entry spread cap |
| `strategy_deviation_points` | 20 | [10, 20, 50] | basket order deviation |

The same-calendar-month definition, relative rank, monthly rebalance, two-leg
long/short package, five-sample minimum, and no same-month re-entry are locked.
Changing to recent momentum, fixed month directions, z-scores, carry, RSI, or
single-leg trading requires a new card and full rerun.

## Author Claims

The paper documents commodity return seasonality in a diversified futures
cross-section and reports weak correlation between commodity seasonality and
equity seasonality strategies. Neither claim validates this two-leg DWX port.
Q02 and later gates are the only QM evidence.

## Initial Risk Profile

- `expected_pf: 1.05` is a conservative queue-ordering prior, not evidence.
- `expected_dd_pct: 22.0` reflects energy gaps, leg-stop asymmetry, and the
  narrow two-asset cross-section.
- Risk class: high because source breadth is reduced from 24 futures to two
  CFDs and local history is shorter than the source's preferred 20 years.
- Source is silent on V5 sizing; backtests use `RISK_FIXED=1000`.

## Strategy Allowability Check

- [x] R1 reputable: peer-reviewed *Journal of Finance* article with DOI and
  complete open NBER text; commodity panel explicitly includes crude oil and
  natural gas.
- [x] R2 mechanical: fixed completed-month return reconstruction, historical
  same-month average, deterministic relative rank, monthly reset, ATR stops.
- [x] R3 testable: registered XTIUSD.DWX and XNGUSD.DWX D1 only.
- [x] R4 compliant: no ML, banned indicator, external runtime feed, adaptive
  fit, grid, martingale, pyramiding, or more than one package.
- [x] Expected frequency exceeds the five-trades/year Q02 floor.
- [x] Basket manifest and logical-symbol setfile required so Q02 judges the
  combined package rather than standalone legs.

## Framework Alignment

- no_trade: exact host/slot, parameter domains, monthly gate, synchronized
  history, arithmetic, spread, ATR, and lot guards.
- trade_entry: monthly same-calendar-month XTI/XNG relative rank and one
  equal-risk two-leg package.
- trade_management: month reset, 35-day stale close, wrong-side and orphan-leg
  repair.
- trade_close: package flatten through V5 close helpers; per-leg broker ATR
  stops remain active intramonth.

## Risk And Safety Boundary

The build creates one `RISK_FIXED` logical-basket backtest setfile only. It does
not create or modify a live setfile, `T_Live`, AutoTrading, deploy manifest,
T_Live manifest, portfolio gate, portfolio admission, or portfolio KPI code.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-10 | initial source-backed energy same-calendar-month basket | Q02 | ENQUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-10 | APPROVED by mission directive | this card |
| Q01 Build Validation | 2026-07-10 | PENDING | `artifacts/qm5_13115_build_result.json` |
| Q02 Baseline Screening | 2026-07-10 | PENDING | paced-fleet work item after build record |
