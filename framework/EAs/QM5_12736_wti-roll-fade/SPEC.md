# QM5_12736_wti-roll-fade - Strategy Spec

**EA ID:** QM5_12736
**Slug:** `wti-roll-fade`
**Source:** `CFTC-ETF-ROLL-WTI-2014`
**Author of this spec:** Codex
**Last revised:** 2026-06-28

## 1. Strategy Logic

This EA implements a low-frequency structural WTI roll-pressure sleeve on
`XTIUSD.DWX`. On each new D1 bar, it permits a short entry only during broker
trading days 5 through 9 of the current calendar month. The prior completed D1
bar must have a negative close-to-close return of at least the configured
threshold and must close below SMA(`strategy_trend_period`). The position is
flattened when the roll window ends, the month changes, price recovers above
the SMA, or the fixed max-hold guard is reached.

The strategy is intentionally not a duplicate of the existing WTI family:
month-of-year sleeves, weekday effects, WPSR, hurricane, refinery, OPEC,
CME-expiry breakout, CAD/oil breakout, medium-term commodity momentum, and
XTI/XNG relative baskets all use different timing or information sets. This EA
uses an early-month ETF roll-pressure window with D1 downside confirmation.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_roll_start_trading_day` | 5 | 4-6 | First broker D1 trading day eligible for entry |
| `strategy_roll_end_trading_day` | 9 | 8-10 | Last broker D1 trading day eligible for entry |
| `strategy_min_down_return_pct` | 0.10 | 0.05-0.20 | Minimum prior D1 downside confirmation |
| `strategy_trend_period` | 20 | 14-30 | SMA period for trend gate/recovery exit |
| `strategy_atr_period` | 20 | 14-30 | ATR period for the hard stop |
| `strategy_atr_sl_mult` | 2.50 | 2.0-3.0 | ATR stop distance multiplier |
| `strategy_max_hold_days` | 5 | 3-7 | Calendar-day stale-position guard |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

- `XTIUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 6-10.
- Typical hold: 1-5 D1 bars.
- Regime preference: confirmed downside pressure during the early-month crude
  ETF roll window.
- Risk mode for Q02 backtests: RISK_FIXED.

## 6. Source Citation

Mou, Y., "Predatory or Sunshine Trading? Evidence from Crude Oil ETF Rolls",
CFTC Office of the Chief Economist, URL
https://www.cftc.gov/sites/default/files/idc/groups/public/@economicanalysis/documents/file/oce_predatorysunshine0314.pdf.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, portfolio gate, or AutoTrading setting is
touched by this build.
