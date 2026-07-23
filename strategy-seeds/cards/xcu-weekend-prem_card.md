---
ea_id: QM5_20053
slug: xcu-weekend-prem
strategy_id: BOROWSKI-LUKASIK-METALS-2017_S02
source_id: BOROWSKI-LUKASIK-METALS-2017
status: DRAFT
created: 2026-07-23
created_by: Research+Development
last_updated: 2026-07-23
g0_status: DRAFT
strategy_type_flags: [calendar-seasonality, weekend-effect, long-only, atr-hard-stop, time-stop, low-frequency]
source_citations:
  - type: academic_paper
    citation: "Borowski, K. and Lukasik, M. (2017), Analysis of Selected Seasonality Effects in the Following Metal Markets: Gold, Silver, Platinum, Palladium and Copper, Journal of Management and Financial Sciences 27, 59-86."
    location: "Sections 4.3 and 5; Tables 5 and 7; https://econjournals.sgh.waw.pl/JMFS/article/download/740/643/"
    quality_tier: B
    role: primary
target_symbols: [XCUUSD.DWX]
period: H1
expected_trade_frequency: "One Friday-close to Monday-open copper position per eligible week; approximately 48 attempts/year before framework filters."
expected_trades_per_year_per_symbol: 48
pipeline_phase: G0
expected_pf: 1.05
expected_dd_pct: 15.0
---

# Copper Weekend Premium

## Source

The single source is the OWNER-approved packet
`strategy-seeds/sources/BOROWSKI-LUKASIK-METALS-2017/source.md`. Borowski and
Lukasik (2017) study calendar effects in gold, silver, platinum, palladium and
copper using a peer-reviewed, open-access paper. The complete paper was
reviewed before this extraction.

## Hypothesis

The source concludes that a weekend effect occurred in copper. This card tests
that claim directly on the Darwinex copper CFD: buy near the broker Friday
close, hold across the weekend, and close at the first Monday H1 boundary.
Unlike the existing XCU Donchian trend, four-week reversal, and commodity
relative-spread builds, the signal is calendar structure rather than price
direction or cross-market valuation.

## Markets And Timeframe

- Host and traded symbol: `XCUUSD.DWX`.
- Timeframe: H1.
- Decision boundary: broker Friday 21:00 H1 bar.
- Exit boundary: first broker Monday H1 bar.
- Runtime data: MT5 broker time, XCU quotes, and D1 ATR only.

## Entry Rules

- Run only on `XCUUSD.DWX` H1 with magic slot 0.
- At the new broker Friday 21:00 H1 bar, consume one attempt for that calendar
  day before news or order submission so restart/rejection cannot create a
  retry.
- Require the entry to occur within five minutes of the bar boundary.
- Require valid trade metadata and spread no greater than 1,000 points.
- BUY one XCU position with a hard stop at `3.0 * ATR(20, D1)`.
- Use the framework fixed-risk lot calculation.

## Exit Rules

- Close at the first new Monday H1 bar after entry.
- Close after four calendar days if the Monday boundary is missed.
- The attached ATR stop remains authoritative.
- Framework Friday close is disabled because weekend exposure defines the
  strategy.

## Filters And Management

- At most one open position for the EA magic.
- Framework kill switch and news guard remain active.
- No retry within the same Friday, pyramiding, grid, martingale, scale-in,
  partial close, trailing stop, external feed, or ML.

## Parameters To Test

All baseline values are locked:

- `strategy_entry_dow = 5`
- `strategy_entry_hour_broker = 21`
- `strategy_entry_grace_minutes = 5`
- `strategy_atr_period_d1 = 20`
- `strategy_atr_sl_mult = 3.0`
- `strategy_max_hold_days = 4`
- `strategy_max_spread_points = 1000`

No baseline parameter sweep is authorized.

## Author Claims

The source reports a statistically detectable copper weekend effect in its
sample. It does not establish persistence on Darwinex CFD boundaries. Spread,
gap, financing, sample age, and broker-time basis may erase the gross effect;
Q02 and later governed gates are the only performance judge.

## Initial Risk Profile

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. No live set or deployment is authorized.

## Strategy Allowability Check

- [x] R1: one approved peer-reviewed source with durable local lineage.
- [x] R2: fixed weekday/hour entry, Monday/time-stop exit, ATR hard stop.
- [x] R3: `XCUUSD.DWX` is registered and used by existing V5 builds.
- [x] R4: deterministic, no ML/grid/martingale, one position per magic.
- [x] Non-duplicate: calendar weekend exposure is distinct from XCU Donchian,
  four-week reversal, XCU/FX or XCU/commodity spreads, XNG cumulative RSI, and
  the directional index/metal book.

## Framework Alignment

- no_trade: host/timeframe/slot, locked-input and spread guards.
- trade_entry: restart-safe Friday 21:00 long entry with ATR stop.
- trade_management: Monday boundary and four-day stale exit.
- trade_close: hard stop plus deterministic time exits.

## Falsification

Reject the build for zero/insufficient valid trades, incorrect broker-boundary
timing, nondeterminism, a risk-mode breach, or failure of governed Q02 and
later PF/DD/correlation gates.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-23 | initial structural copper weekend-premium extraction | G0 | DRAFT |
