---
ea_id: QM5_20099
slug: wti-samecal
type: strategy
strategy_id: KELOHARJU-RETSEAS-2016_XTI_S02
source_id: KELOHARJU-RETSEAS-2016
status: APPROVED
g0_status: APPROVED
created: 2026-07-24
created_by: Research+Development
last_updated: 2026-07-24
source_citation: "Keloharju, Linnainmaa, and Nyberg (2016), Return Seasonalities, The Journal of Finance 71(4), 1557-1590, DOI 10.1111/jofi.12398."
source_citations:
  - type: peer_reviewed_paper
    citation: "Keloharju, Matti; Linnainmaa, Juhani T.; and Nyberg, Peter (2016). Return Seasonalities. The Journal of Finance 71(4), 1557-1590."
    location: "Commodity construction in Sections 5.4.3-5.6 and Tables 8-9; DOI https://doi.org/10.1111/jofi.12398; complete NBER version https://www.nber.org/system/files/working_papers/w20815/w20815.pdf"
    quality_tier: A
    role: primary
sources:
  - "[[sources/KELOHARJU-RETSEAS-2016]]"
concepts:
  - "[[concepts/same-calendar-month-seasonality]]"
  - "[[concepts/energy-seasonal-risk-premium]]"
indicators:
  - "[[indicators/month-end-close]]"
  - "[[indicators/arithmetic-mean]]"
  - "[[indicators/atr]]"
strategy_type_flags: [calendar-seasonality, same-calendar-month, time-series-sign, symmetric-long-short, monthly-rebalance, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
period: D1
primary_target_symbols: [XTIUSD.DWX]
target_symbols: [XTIUSD.DWX]
single_symbol_only: true
expected_trade_frequency: "After the five-year same-month warm-up, one WTI package at each broker-month boundary; approximately 10-12 completed packages/year."
expected_trades_per_year_per_symbol: 11
expected_pf: 1.03
expected_dd_pct: 25.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
q01_status: PENDING
q02_status: NOT_QUEUED
review_focus: "Falsify the absolute-sign single-WTI translation after its five-year warm-up; the source proves only a broad cross-sectional effect, and Q09 alone may judge realized book correlation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [friday_close, risk_mode_dual, cfd_futures_basis, long_history_warmup, source_port_reduction, portfolio_correlation]
g0_approval_reasoning: "OWNER commodity-sleeve mission: R1 PASS peer-reviewed Journal of Finance source and complete reviewed NBER text; R2 PASS locked prior-year same-calendar WTI return average, absolute sign, monthly renewal, ATR stop and stale guard; R3 PASS registered XTI D1 carrier with a disclosed five-year warm-up; R4 PASS native deterministic arithmetic only, no ML/banned/external/grid/martingale logic. Dedup helper found only the expected XTI/XNG relative-rank sibling; manual exact-mechanic review found no single-WTI absolute same-calendar-average-sign carrier."
---

# WTI Same-Calendar-Month Seasonal Sign

## Hypothesis

Physical demand, storage, hedging and capital-allocation pressures can recur in
the same calendar month. Keloharju, Linnainmaa and Nyberg document a
same-calendar-month effect across a 24-commodity futures cross-section that
explicitly includes crude oil. This card tests whether WTI's own historical
return for the upcoming calendar month contains a persistent directional sign
on the Darwinex continuous CFD.

The carrier is an adaptive calendar rule, not a fixed January/February/etc.
direction and not a recent-return trend indicator. Direct WTI exposure is
economically different from the certified XAU/SP500/NDX/XNG book, but realized
decorrelation is unclaimed until the governed portfolio phase.

## Source And Evidence Boundary

The sole lineage is the peer-reviewed 2016 *Journal of Finance* article and its
complete 57-page NBER version, which was reviewed end to end in the durable
source packet. The paper ranks a broad commodity cross-section by average
same-calendar-month returns over prior history, requires at least five years,
and buys high-ranked assets while selling low-ranked assets for one month.

This card is a deliberately narrower time-series translation. It compares
WTI's historical same-calendar average with zero, not with other commodities.
The source does not report this one-CFD absolute-sign portfolio, Darwinex
performance, or a post-2011 result. The reduction in breadth, futures/CFD
basis, limited local history, rolls, financing, gaps and costs are binding Q02
kill risks rather than performance claims.

## Concept And Non-Duplicate Decision

At the first tradable D1 bar of each broker month, reconstruct WTI's completed
return for that same calendar month in each available prior year:

`r(year, month) = ln(month_end_close / prior_month_end_close)`.

Average up to ten prior observations and require at least five. Buy WTI when
the average is positive and sell WTI when it is negative. Close and recompute
at the next month boundary.

The deterministic dedup helper found one expected fuzzy sibling,
`QM5_13115_energy-samecal`. Manual review resolves it as non-identical:

- `QM5_13115` compares XTI with XNG and requires two opposing, jointly managed
  legs; this card compares only WTI with zero and forbids an XNG leg.
- Fixed WTI month cards hard-code selected month directions; this card
  recomputes all month directions from prior same-month history.
- WTI TSMOM EAs use one contiguous recent-return horizon; this carrier samples
  only matching calendar months across separate years.
- `QM5_1276_chan-monthly-stock-seasonal` uses one approximate prior-year stock
  return rather than a five-to-ten-year exact-calendar WTI average.
- `QM5_12567_cum-rsi2-commodity` is an RSI pullback and shares no signal state.

The exact slug, strategy identity, EA ID, single-symbol information object and
entry/exit mechanic are new. Related formation data does not imply a
decorrelation waiver.

## Markets And Timeframe

- Host and traded symbol: `XTIUSD.DWX`, D1, magic slot 0.
- Decision cadence: first genuine D1 bar of each broker calendar month.
- Formation: up to ten prior returns for the same calendar month, minimum five.
- Expected cadence after warm-up: 10-12 completed monthly packages/year.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.
- Runtime data: native MT5 D1 OHLC, ATR, spread, broker calendar, deal history
  and framework state only.

## rules

- On a new broker-month D1 boundary, close any prior-month position before
  considering new risk.
- Reconstruct exact completed month ends; current-month prices never enter the
  seasonal estimate.
- Average valid WTI same-calendar log returns across the prior ten years and
  require at least five observations.
- Positive average means BUY; negative average means SELL; an exact numerical
  tie or invalid history remains flat.
- Consume one monthly attempt before news, spread or order submission. A
  restart, stop, news block or rejected order cannot retry that month.
- Use one frozen `3.5 * ATR(20)` hard stop, no take-profit and no same-month
  re-entry.
- Close at the next month boundary or after 35 calendar days, whichever acts
  first.

## 4. Entry Rules

1. Require exact `XTIUSD.DWX` D1 host, slot 0 and all locked inputs.
2. Act only when the current and previous D1 bars have different broker-month
   keys.
3. Persist the current month attempt before fallible entry gates.
4. Copy at most 3000 completed D1 bars and locate the last completed close for
   the target month and its immediately preceding month in each prior year.
5. Require at least five valid observations from the bounded ten-year window.
6. Compute the arithmetic mean of the valid log returns.
7. Stay flat when the absolute mean is at most `1e-12`; otherwise BUY for a
   positive mean or SELL for a negative mean.
8. Require nonnegative spread no greater than 1500 points and valid completed
   `ATR(20)`.
9. Place a normalized frozen stop `3.5 * ATR(20)` from the executable price.
   Fixed-risk lot sizing remains framework-owned.

## 5. Exit Rules

- Close on the first D1 bar belonging to a later broker month, before all
  new-entry and news gates.
- Close after 35 calendar days if the expected month boundary is unavailable.
- Broker hard stop and framework kill switch remain authoritative.
- Friday close is disabled because a one-month source-aligned hold must span
  weekends; this is not a live authorization.

## 6. Filters (No-Trade Module)

- Fail closed outside the exact symbol, timeframe, magic slot or locked input
  contract.
- Reject insufficient or malformed history, nonpositive closes, invalid log
  arithmetic, invalid ATR/price/point metadata and excessive spread.
- Framework news compliance can block new risk only. It cannot delay monthly,
  stale, hard-stop or kill-switch exits.
- No futures curve, inventory, volume, open interest, COT, API, CSV, weather,
  analyst forecast or discretionary runtime input is permitted.

## 7. Trade Management Rules

- One position per registered magic and one consumed attempt per broker month.
- No same-month re-entry after a fill, stop, close, rejection, news block or
  restart.
- No take-profit, trailing stop, break-even move, partial close, scale-in,
  grid, martingale, pyramid, adaptive PnL fit or random path.
- Position lifecycle exits run before entry-news checks on every new D1 bar.

## Parameters To Test

| parameter | locked value | role |
|---|---:|---|
| `strategy_history_years` | 10 | bounded prior same-month window |
| `strategy_min_history_years` | 5 | source minimum |
| `strategy_history_bars` | 3000 | D1 reconstruction buffer |
| `strategy_atr_period` | 20 | completed-bar stop estimator |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 35 | stale monthly-package guard |
| `strategy_max_spread_points` | 1500 | WTI entry spread cap |

No baseline parameter sweep is authorized. Changing the formation statistic,
minimum history, sign threshold, cadence, symbol or adding a second leg creates
a new strategy.

## Author Claims

The source documents commodity return seasonality in a diversified futures
cross-section. It does not claim that this single-WTI absolute-sign translation
is profitable or uncorrelated with the QM portfolio.

## risk

Q02 uses exactly `RISK_FIXED=1000`, `RISK_PERCENT=0` and
`PORTFOLIO_WEIGHT=1`. The primary risks are the five-year warm-up, only
2017-present local CFD history, a single asset replacing a broad rank, source
sample ending in 2011, futures/CFD construction, monthly gaps, financing and
direction persistence. Retire on zero trades, fewer than five completed
packages/year after warm-up, wrong-month or duplicate entries, look-ahead,
nondeterminism, risk-mode mismatch, governed PF/DD failure or later
correlation rejection. Do not rescue failure with a threshold, recent-return
filter or fixed favorable-month list.

## Strategy Allowability Check

- [x] R1: one peer-reviewed Journal of Finance source ID with a complete,
  reviewed open working paper.
- [x] R2: fixed calendar estimator, sign, entry, exit, stop, state and risk.
- [x] R3: registered `XTIUSD.DWX` D1 route; warm-up limitation disclosed.
- [x] R4: native deterministic arithmetic, one position per magic, no ML,
  banned indicator, external feed, grid or martingale.
- [x] Expected post-warm-up cadence exceeds the five-trades/year Q02 floor.
- [x] Expected fuzzy sibling manually resolved; no exact mechanic exists.

## Framework Alignment

- no_trade: exact host/slot/input contract, monthly boundary, history,
  arithmetic, ATR and spread gates.
- trade_entry: historical same-calendar WTI average sign and frozen ATR stop.
- trade_management: month-boundary and 35-day stale close before entry gates.
- trade_close: framework close helper, broker stop and kill-switch ownership.

## Safety Boundary

This approval covers the card, deterministic registry allocation, build,
strict compile, one `RISK_FIXED` backtest setfile and one paced Q02 enqueue. It
does not authorize a live setfile, AutoTrading, T_Live, deploy/T_Live
manifests, portfolio admission, portfolio-gate changes or correlation waivers.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-24 | initial source-backed WTI same-calendar carrier | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-24 | APPROVED under OWNER mission; R1-R4 PASS | this card |
| Q01 Build Validation | - | PENDING | `framework/EAs/QM5_20099_wti-samecal/` |
| Q02 Baseline Screening | - | NOT QUEUED | paced fleet after strict build |
