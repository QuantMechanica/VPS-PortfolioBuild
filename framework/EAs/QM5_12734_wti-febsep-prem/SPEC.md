# QM5_12734_wti-febsep-prem - Strategy Spec

**EA ID:** QM5_12734
**Slug:** `wti-febsep-prem`
**Source:** `ARENDAS-OIL-SEASON-2018`
**Author of this spec:** Codex
**Last revised:** 2026-06-28

## 1. Strategy Logic

This EA implements the source-defined February-September crude-oil seasonal
window on `XTIUSD.DWX`. On each new D1 bar it permits a long entry only when
the current broker-calendar month is February through September. It exits when
the season ends, by a bounded stale-position guard, by per-trade ATR hard stop,
or by the V5 Friday-close module.

This is intentionally not a duplicate of the existing WTI family: March/April/
August single-month premiums, October/November fades, weekday seasonality,
broad EIA demand seasonality, WPSR continuation/fade/pre-event, refinery
maintenance, hurricane-season breakout, OPEC event-window breakout, expiry
breakout, oil/gas ratio, medium-term reversal, and time-series momentum all
use different information sets or timing.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_start_month` | 2 | 2 | Start of the source seasonal window |
| `strategy_end_month` | 9 | 9 | End of the source seasonal window |
| `strategy_atr_period` | 20 | 14-30 | ATR period for the hard stop |
| `strategy_atr_sl_mult` | 3.0 | 2.0-5.0 | ATR stop distance multiplier |
| `strategy_max_hold_days` | 10 | 5-15 | Calendar-day stale-position guard |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

- `XTIUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 25-35 after Friday-close segmentation.
- Typical hold: several D1 bars, usually bounded by Friday close.
- Regime preference: WTI February-September seasonal premium.
- Risk mode for Q02 backtests: RISK_FIXED.

## 6. Source Citation

Arendas, P., Tkacova, A. and Bukoven, M., "Seasonal patterns in oil prices and
their implications for investors", Journal of International Studies, URL
https://www.jois.eu/files/12_547_Arendas%20et%20al.pdf.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, portfolio gate, or AutoTrading setting is
touched by this build.
