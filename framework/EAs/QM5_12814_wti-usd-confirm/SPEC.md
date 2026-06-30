# QM5_12814_wti-usd-confirm - Strategy Spec

**EA ID:** QM5_12814
**Slug:** `wti-usd-confirm`
**Source:** `EIA-OIL-USD-FX-2017`
**Author of this spec:** Codex
**Last revised:** 2026-06-30

## 1. Strategy Logic

This EA implements a low-frequency structural WTI sleeve on `XTIUSD.DWX`.
Entries are evaluated on the first available D1 bar of a new broker-calendar
week. A long setup requires positive WTI quarterly momentum, positive
`EURUSD.DWX` quarterly momentum as a broad USD-weakness proxy, and a WTI close
above its D1 SMA. A short setup requires negative WTI momentum, negative
`EURUSD.DWX` momentum as a broad USD-strength proxy, and a WTI close below its
D1 SMA. `EURUSD.DWX` is read-only; the EA trades one XTIUSD position per magic.

The strategy is intentionally not a duplicate of the WTI/CAD family:
`QM5_12607` uses USDCAD petro-currency confirmation, while `QM5_12609` and
`QM5_12722` are WTI/CAD baskets. This build uses broad USD confirmation through
EURUSD and trades only WTI. It is also not a WTI calendar/event sleeve, WPSR,
OPEC, refinery, hurricane, roll, expiry, ratio basket, RSI pullback, or XNG
logic.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_usd_proxy_symbol` | `EURUSD.DWX` | fixed | Closed-bar USD proxy confirmation symbol |
| `strategy_oil_lookback_d1` | 63 | 42-84 | Completed XTI D1 bars for oil return |
| `strategy_usd_lookback_d1` | 63 | 42-84 | Completed EURUSD D1 bars for USD-proxy return |
| `strategy_min_oil_return_pct` | 3.0 | 2.0-5.0 | Minimum absolute XTI return threshold |
| `strategy_min_usd_proxy_return_pct` | 1.0 | 0.5-1.5 | Minimum same-direction EURUSD return threshold |
| `strategy_trend_period` | 84 | 63-126 | XTI D1 SMA trend filter |
| `strategy_atr_period` | 20 | 14-30 | ATR period for hard stop |
| `strategy_atr_sl_mult` | 3.0 | 2.5-4.0 | ATR hard-stop distance multiplier |
| `strategy_max_hold_days` | 21 | 14-31 | Calendar-day stale-position guard |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

- Host/traded symbol: `XTIUSD.DWX`, magic slot 0.
- Read-only confirmation symbol: `EURUSD.DWX`, D1 closed bars.

## 4. Timeframe

- Base timeframe: D1.
- Confirmation timeframe: D1.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 6-14.
- Typical hold: weekly packages, capped at 21 calendar days by default.
- Regime preference: WTI directional moves confirmed by broad USD
  weakness/strength.
- Risk mode for Q02 backtests: RISK_FIXED.

## 6. Source Citation

Beckmann, J., Czudaj, R. L., and Arora, V., "The Relationship between Oil
Prices and Exchange Rates", U.S. Energy Information Administration working
paper, June 2017, URL
https://www.eia.gov/workingpapers/pdf/oil_exchangerates_61317.pdf.

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
| v1 | 2026-06-30 | Initial WTI oil-dollar confirmation build |
