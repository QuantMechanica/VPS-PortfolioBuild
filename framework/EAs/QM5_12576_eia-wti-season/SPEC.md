# QM5_12576_eia-wti-season - Strategy Spec

**EA ID:** QM5_12576
**Slug:** `eia-wti-season`
**Source:** `EIA-WTI-SEASON-2024`
**Author of this spec:** Codex
**Last revised:** 2026-06-26

## 1. Strategy Logic

This EA implements a low-frequency structural WTI sleeve on `XTIUSD.DWX`.
On the first new D1 bar of each calendar month, it maps the active month to a
seasonal direction: long during the U.S. gasoline driving-season window plus
the winter distillate support window, short during the early autumn shoulder
months, and flat in neutral months. Entry requires the prior closed D1 close to
confirm direction versus SMA(84) and a 21-bar close-to-close momentum filter.
Risk is controlled with a fixed ATR(20) * 3.5 hard stop.

The strategy is intentionally not a duplicate of `QM5_12567_cum-rsi2-commodity`:
it does not use RSI or short-horizon pullback logic. It also differs from the
existing XNG seasonal sleeve because the traded structure is petroleum refined
product demand seasonality rather than natural-gas heating/power demand.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_trend_period` | 84 | 63-168 | D1 SMA confirmation period |
| `strategy_momentum_period` | 21 | 10-42 | D1 close-to-close momentum lookback |
| `strategy_atr_period` | 20 | 14-30 | ATR stop period |
| `strategy_atr_sl_mult` | 3.5 | 2.5-5.5 | Stop distance multiplier |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

- `XTIUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 4.
- Typical hold: weeks to months.
- Regime preference: WTI seasonal demand and trend alignment.
- Risk mode for Q02 backtests: RISK_FIXED.

## 6. Source Citation

U.S. Energy Information Administration, "Gasoline price fluctuations", Energy
Explained, URL https://www.eia.gov/energyexplained/gasoline/price-fluctuations.php.
Supplemental EIA references in the card document heating-oil and diesel demand
drivers used only for structural lineage.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest or `T_Live` file is touched by this build.
