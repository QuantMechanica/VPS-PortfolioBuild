# QM5_12812_xng-month-orb - Strategy Spec

**EA ID:** QM5_12812
**Slug:** `xng-month-orb`
**Source:** `EIA-XNG-MONTH-ORB-2026`
**Author of this spec:** Codex
**Last revised:** 2026-06-30

## 1. Strategy Logic

This EA implements a low-frequency natural-gas month-opening range breakout on
`XNGUSD.DWX`. On each new D1 bar, it uses the first five completed D1 bars of
the current calendar month as the opening range. A later close above that range
opens a long position; a later close below that range opens a short position.
Both sides require ATR-normalized range sanity, SMA trend confirmation, and a
strong close location.

The strategy is intentionally not a duplicate of the existing XNG family:
season/storage/event/weekend/squeeze/52-week/momentum and XTI/XNG basket
sleeves all use different timing, data lineage, or entry logic.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_opening_days` | 5 | 3-7 | First completed D1 bars used to define the monthly opening range |
| `strategy_atr_period` | 20 | 14-30 | ATR period for range filter, stop, and target |
| `strategy_trend_period` | 80 | 50-120 | SMA trend confirmation |
| `strategy_min_open_range_atr` | 0.60 | 0.45-0.80 | Minimum opening range as ATR multiple |
| `strategy_max_open_range_atr` | 5.00 | 4.00-6.50 | Maximum opening range as ATR multiple |
| `strategy_entry_buffer_atr` | 0.10 | 0.05-0.15 | ATR buffer beyond opening range for entry confirmation |
| `strategy_min_close_location` | 0.56 | 0.55-0.62 | Close-location threshold inside signal bar range |
| `strategy_atr_sl_mult` | 3.25 | 2.50-4.00 | ATR stop distance multiplier |
| `strategy_atr_tp_mult` | 5.00 | 4.00-6.50 | ATR target distance multiplier |
| `strategy_max_hold_days` | 12 | 8-18 | Calendar-day stale-position guard |
| `strategy_max_spread_points` | 1500 | 1000-2200 | Entry spread cap |

## 3. Symbol Universe

- `XNGUSD.DWX` only, magic slot 0.
- Not designed for `XTIUSD.DWX`, `XAUUSD.DWX`, `XAGUSD.DWX`, index symbols, FX
  symbols, or commodity ratio baskets.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 6-12.
- Typical hold: several D1 bars; capped at 12 calendar days by default and
  closed on month change.
- Regime preference: monthly natural-gas volatility expansion after the opening
  range.
- Risk mode for Q02 backtests: RISK_FIXED.

## 6. Source Citation

U.S. Energy Information Administration, "Natural gas consumption, production
respond to seasonal changes", Today in Energy, 2015-09-24,
https://www.eia.gov/todayinenergy/detail.php?id=22892. Supplements: Crabel,
Toby. *Day Trading with Short-Term Price Patterns and Opening Range Breakout*.
Traders Press, 1990, and CME Group Henry Hub Natural Gas Futures contract
specifications,
https://www.cmegroup.com/markets/energy/natural-gas/natural-gas.contractSpecs.html.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, portfolio gate, or AutoTrading setting is
touched by this build.

## Revision History

| Version | Date | Reason |
|---|---|---|
| v1 | 2026-06-30 | Initial XNG month-opening range breakout build |
