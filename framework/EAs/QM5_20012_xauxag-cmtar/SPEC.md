# QM5_20012_xauxag-cmtar - Strategy Spec

**EA ID:** QM5_20012  
**Slug:** `xauxag-cmtar`  
**Strategy ID:** `MIGHRI-XAUXAG-CMTAR-2018_S01`  
**Source ID:** `MIGHRI-XAUXAG-CMTAR-2018`  
**Last revised:** 2026-07-20

## 1. Strategy Logic

The EA runs one low-frequency XAU/XAG logical basket from an `XAUUSD.DWX`
D1 host chart. On the first tradable host D1 bar of a new broker month it
reconstructs each leg's own final completed D1 close for the latest two
consecutive months, joins the legs by calendar month, and rejects stale or
mismatched endpoints.

The locked source residual is:

`e = log10(XAG) + 0.99823 - 0.71970 * log10(XAU)`.

Only the source's statistically convergent consistent M-TAR regime is
eligible: `e[t-1] - e[t-2] < 0.021`. If the latest residual is above the
execution buffer, the EA buys XAU and sells XAG. If it is below the negative
buffer, the EA sells XAU and buys XAG. The resulting package targets XAU:XAG
dollar notionals of `0.71970:1`, which is a cointegration-elasticity hedge and
not strict dollar neutrality.

Both legs close at the next broker-month boundary before any new package is
evaluated. An ATR hard stop protects each leg, a forty-calendar-day guard
closes stale exposure, and an orphan, duplicate, or same-direction pair is
closed immediately. A terminal-global marker plus owned deal history consumes
the attempt before order submission and prevents same-month re-entry after a
restart, broker rejection, or repaired partial package.

## 2. Parameters

| Parameter | Default | Authorized values | Meaning |
|---|---:|---|---|
| `strategy_source_intercept` | -0.99823 | locked | published silver-on-gold intercept |
| `strategy_source_beta` | 0.71970 | locked | published long-run elasticity; QM applies it to notionals |
| `strategy_mtar_delta_threshold` | 0.021 | locked | published convergent momentum threshold |
| `strategy_entry_abs_residual` | 0.010 | 0.000, 0.010, 0.020 | cost-aware absolute residual buffer |
| `strategy_history_bars` | 120 | locked | bounded D1 month-end reconstruction buffer |
| `strategy_max_endpoint_gap_days` | 10 | locked | latest completed endpoint age cap; leg timestamps must match exactly |
| `strategy_atr_period_d1` | 20 | 14, 20, 30 | completed-D1 ATR period |
| `strategy_atr_sl_mult` | 4.0 | 3.0, 4.0, 5.0 | per-leg frozen stop multiple |
| `strategy_max_hold_days` | 40 | 35, 40 | stale package guard |
| `strategy_xau_max_spread_pts` | 1500 | 1000, 1500, 2500 | XAU entry spread cap |
| `strategy_xag_max_spread_pts` | 500 | 300, 500, 800 | XAG entry spread cap |
| `strategy_max_hedge_error_pct` | 20.0 | 10.0, 20.0, 30.0 | post-rounding elasticity-notional error cap |
| `strategy_deviation_points` | 20 | locked | paired-order deviation |

The equation, log base, monthly cadence, threshold direction, residual fade
directions, opposite-leg package, and elasticity hedge are load-bearing.

## 3. Symbol Universe

- `XAUUSD.DWX`: host and traded magic slot 0.
- `XAGUSD.DWX`: foreign traded magic slot 1.
- Logical tester symbol: `QM5_20012_XAU_XAG_CMTAR_D1`.

Standalone XAU or XAG tests are invalid. Both registered magics must be owned
by the kill switch, and Q02 evaluates the package rather than either leg.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Host timeframe | D1 |
| Source observation | completed broker-calendar month end |
| Signal cadence | first tradable host D1 bar of each new month |
| Maximum cadence | one consumed attempt per broker month |
| Q02 window | 2018.07.02 through 2024.12.31 |

Current open bars never enter the residual. Both legs must share the exact D1
endpoint timestamp in each joined month. Missing consecutive months,
foreign-leg lag, or an endpoint older than ten days fails closed.

## 5. Expected Behaviour

| Metric | Expectation before Q02 |
|---|---|
| Packages per full year | approximately 6-10; retire below five |
| Typical holding period | one source month |
| Maximum holding period | 40 calendar days |
| Market exposure | opposite precious-metal legs, elasticity hedged |
| Drawdown profile | medium-high due to XAG gaps, relation drift, costs, and legging |

The source contains no trading backtest. A public futures proxy only supports
queue plausibility; synchronized Darwinex Q02 is the authority for density,
costs, performance, and survival. Diversification is an objective, not a
certification claim.

The generic tester reports two leg trades per completed package. Its automatic
Q02 floor of 35 report trades is therefore not the card's density verdict. The
five-package/year kill rule requires at least 35 completed paired packages
(approximately 70 completed leg trades) across the seven Q02 year labels, and
must be checked from paired magic/reason/month evidence.

## 6. Source Citation

Mighri, Z. A. and Al Saggaf, M. I. (2018), “Gold - Silver Nexus: A Threshold
Cointegration Approach,” *International Journal of Economics and Financial
Issues* 8(5), 210-219. The complete official paper is recorded at
`strategy-seeds/sources/MIGHRI-XAUXAG-CMTAR-2018/source.md`.

The paper's table values establish monthly sampling, base-10 logged prices,
the silver-on-gold orientation, coefficient `0.71970`, intercept `-0.99823`,
and convergent `delta(e) < 0.021` branch. The signed fade, residual buffer,
monthly close/reopen carrier, joint sizing, stops, and execution controls are
disclosed QM translations because the source does not publish a trading rule.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02 and research backtests | RISK_FIXED | $1,000 combined package stop risk |
| Live | not authorized | no preset or deployment action |

Each leg's full-budget ATR-stop lot capacity is computed independently. The
two rounded-down lot sizes are then solved jointly so their normalized stop
risk sums to no more than one framework budget while their notionals remain
within the configured hedge-error cap. The second leg is submitted only after
the first succeeds; any second-leg failure immediately closes the first.

There is no TP, trailing stop, partial close, scale-in, grid, martingale,
pyramiding, ML, banned indicator, external runtime feed, T_Live preset,
AutoTrading action, portfolio-gate change, or deploy manifest.

## 8. Four-Module Mapping

- **No trade:** exact host/timeframe/slot, fixed source constants, consecutive
  synchronized month ends, freshness, residual buffer, source regime, spread,
  symbol metadata, news, magic, and monthly-attempt guards.
- **Entry:** signed residual fade, opposite XAU/XAG orders, fixed elasticity
  notionals, combined fixed-risk sizing, rounded-hedge validation, frozen ATR
  stops, and partial-package rollback.
- **Management:** every-tick orphan/composition/actual-hedge repair, retrying
  month renewal, forty-day stale guard, persisted attempt recovery, and
  foreign-magic kill-switch ownership.
- **Close:** framework position close plus broker-side hard stops.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-20 | Initial approved build | OWNER commodity-sleeve mission; Q02 only |
