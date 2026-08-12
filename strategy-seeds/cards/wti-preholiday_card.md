---
ea_id: QM5_20048
slug: wti-preholiday
type: strategy
strategy_id: QADAN-AHARON-EICHEL-2019_WTI_HOL_S01
source_id: QADAN-AHARON-EICHEL-2019
status: APPROVED
g0_status: APPROVED
created: 2026-07-22
created_by: Research+Development
last_updated: 2026-07-22
strategy_type_flags: [calendar-seasonality, holiday-effect, low-frequency, atr-hard-stop, time-stop]
target_symbols: [XTIUSD.DWX]
period: D1
expected_trades_per_year_per_symbol: 8
pipeline_phase: Q02
review_focus: "Adds a holiday-sentiment WTI return driver, not another index/metal swing rule; retire if post-publication decay or CFD timing/costs erase it."
source_citations:
  - type: academic_paper
    citation: "Qadan, M.; Aharon, D. Y.; Eichel, R. (2019). Seasonal patterns and calendar anomalies in the commodity market for natural resources. Resources Policy 63, 101435."
    location: "Highlights; Sections 1 and 3; Table 1 and holiday-result appendix; https://doi.org/10.1016/j.resourpol.2019.101435"
    quality_tier: A
    role: primary
g0_approval_reasoning: "OWNER commodity-sleeve mission: R1 peer-reviewed Resources Policy paper; R2 deterministic eight-holiday WTI D1 carrier; R3 XTIUSD.DWX registered; R4 no ML, banned indicators, grid, martingale, or runtime external feed."
expected_pf: 1.05
expected_dd_pct: 18.0
---

# WTI Pre-Holiday Sentiment Sleeve

## Hypothesis

Qadan, Aharon and Eichel test 25 calendar anomalies on NYMEX natural-resource
futures from 1986 through July 2018 and report abnormal returns around joyful
U.S. holidays, with several effects stronger after commodity financialization.
This card tests the transparent carrier: buy WTI on the last tradable D1 session
before each of eight recurring U.S. exchange holidays and flatten on the next D1
session. It is a low-frequency calendar/sentiment edge, not RSI, trend, inventory,
expiry, weekday, month-of-year, ML, or an index/metal return stream.

The paper does not publish a Darwinex-CFD trading backtest. Holiday-to-broker-day
mapping, ATR risk, spread control, and the one-session exit are explicit QM
mechanizations. Post-publication decay is a foregrounded kill risk.

## Rules

- Host and only symbol: `XTIUSD.DWX`, D1, magic slot 0.
- Holidays: observed New Year's Day, Presidents Day, Good Friday, Memorial Day,
  observed Independence Day, Labor Day, Thanksgiving, and observed Christmas.
- On the final weekday session before a listed holiday, open one long package at
  the first tradable D1 tick. Weekend gaps are handled by selecting the last
  weekday with no intervening weekday before the holiday.
- Consume at most one attempt per holiday date; never retry or pyramid.
- Initial hard stop: frozen ATR(20) * 3.0; maximum spread 1,200 points.
- Close on the first subsequent D1 bar, or after four calendar days fail-safe.
- Framework kill switch and news controls remain active. Friday-close is disabled
  because Friday is sometimes the pre-holiday session; the strategy exit is
  authoritative.

## Parameters to test

- `strategy_atr_period=20`, declared range `[14,20,30]`.
- `strategy_atr_sl_mult=3.0`, declared range `[2.0,3.0,4.0]`.
- `strategy_max_spread_points=1200`, declared range `[800,1200,1800]`.
- Holiday set, direction, entry/exit timing, and one-attempt rule are locked.

## Frequency, risk, and kill criteria

Expected density is eight packages/year before broker/news/spread exclusions,
above the binding five-trades/year Q02 floor. Backtests use `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

Retire for fewer than five completed packages/year, wrong holiday mapping,
duplicate attempts, nondeterminism, risk-mode mismatch, post-cost gate failure,
or later portfolio correlation rejection. The source's 1986-2018 futures sample,
post-publication decay, CFD/futures basis, holiday gaps, and recent-regime stability
are explicit falsification risks; no gate is changed by this card.

## Framework alignment

- no_trade: exact symbol/timeframe/slot, input, spread, history, and metadata guards.
- trade_entry: deterministic pre-holiday calendar gate and fixed-risk ATR long.
- trade_management: first-subsequent-bar exit plus four-day stale guard.
- trade_close: broker ATR stop and strategy time exit.

No live set, deploy manifest, T_Live action, AutoTrading action, or portfolio-gate
change is authorized.
