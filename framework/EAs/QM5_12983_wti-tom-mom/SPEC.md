# QM5_12983_wti-tom-mom - Strategy Spec

**EA ID:** QM5_12983
**Slug:** `wti-tom-mom`
**Source:** `VANHEMERT-MOMTOM-2014_XTI`
**Author of this spec:** Codex
**Last revised:** 2026-07-03

## 1. Strategy Logic

This EA implements a low-frequency WTI turn-of-month momentum sleeve on
`XTIUSD.DWX`. On each D1 bar inside the broker-calendar turn-of-month window,
it measures a fixed completed-D1 return lookback and trades in that direction.
The EA allows at most one entry per turn-of-month cycle, where first-days of a
new month belong to the previous month-end cycle.

The strategy is intentionally not a duplicate of WTI month-of-year premia/fades,
weekly/monthly ORB, EIA/WPSR/OPEC/Cushing/refinery/hurricane events, roll or
expiry effects, WTI/FX or Brent/WTI baskets, XTI/XNG spreads, 6-month reversal,
12-month carry/TSMOM, or `QM5_12567` cumulative-RSI commodity pullback logic.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_tom_pre_days` | 2 | 1-3 | Calendar days at month-end included in the turn window |
| `strategy_tom_post_days` | 3 | 1-3 | Calendar days at month-start included in the turn window |
| `strategy_momentum_lookback_days` | 63 | 42-126 | Completed D1 return lookback |
| `strategy_min_momentum_pct` | 4.0 | 2.5-6.0 | Minimum absolute return before entry |
| `strategy_atr_period` | 20 | 14-30 | ATR period for stop and target |
| `strategy_atr_sl_mult` | 2.5 | 2.0-3.0 | ATR hard-stop distance |
| `strategy_atr_tp_mult` | 3.0 | 2.0-4.0 | ATR profit-target distance |
| `strategy_max_hold_days` | 6 | 3-8 | Stale-position time exit |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

- `XTIUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Bar gating: `QM_IsNewBar()`.
- Multi-timeframe references: none.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 6-12 before framework filters.
- Typical hold: one to six D1 bars, bounded by the turn window and max hold.
- Risk mode for Q02 backtests: `RISK_FIXED`.

## 6. Source Citation

Van Hemert, Otto. "The MOM-TOM Effect: Detecting the Market Impact of CTA
Trading." SSRN, 2014. URL:
https://papers.ssrn.com/sol3/papers.cfm?abstract_id=2515900.

Moskowitz, Tobias J., Yao Hua Ooi and Lasse Heje Pedersen. "Time Series
Momentum." Journal of Financial Economics, 104(2), 2012. URL:
https://w4.stern.nyu.edu/facdir/lpederse/papers/TimeSeriesMomentum.pdf.

CME Group. "WTI Crude Oil futures product overview." URL:
https://www.cmegroup.com/markets/energy/crude-oil/light-sweet-crude.html.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, portfolio gate, or AutoTrading setting is
touched by this build.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-03 | Initial build from card | Enqueue Q02 |
