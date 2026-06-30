# QM5_12833_wti-jpy-confirm - Strategy Spec

**EA ID:** QM5_12833
**Slug:** `wti-jpy-confirm`
**Source:** `EIA-BOJ-WTI-JPY-2026`
**Author of this spec:** Codex
**Last revised:** 2026-06-30

## 1. Strategy Logic

This EA implements a low-frequency structural WTI sleeve on `XTIUSD.DWX`.
Entries are evaluated on the first available D1 bar of a new broker-calendar
week. A long setup requires positive WTI quarterly momentum, positive
`USDJPY.DWX` quarterly momentum as a Japan oil-importer yen-weakness proxy, and
a WTI close above its D1 SMA. A short setup requires negative WTI momentum,
negative `USDJPY.DWX` momentum, and a WTI close below its D1 SMA. `USDJPY.DWX`
is read-only; the EA trades one XTIUSD position per magic.

The strategy is intentionally not a duplicate of `QM5_12814_wti-usd-confirm`:
that EA uses `EURUSD.DWX` as a broad USD proxy, while this build uses
`USDJPY.DWX` for the yen/oil-importer terms-of-trade channel. It is also not
WTI/CAD petro-currency logic, WTI/AUDUSD basket logic, WTI calendar/event
logic, XTI/XNG, energy/metal, XAU/XAG, or XNG RSI logic.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_jpy_proxy_symbol` | `USDJPY.DWX` | fixed | Closed-bar oil-importer FX confirmation symbol |
| `strategy_oil_lookback_d1` | 63 | 42-84 | Completed XTI D1 bars for oil return |
| `strategy_jpy_lookback_d1` | 63 | 42-84 | Completed USDJPY D1 bars for confirmation return |
| `strategy_min_oil_return_pct` | 3.0 | 2.0-5.0 | Minimum absolute XTI return threshold |
| `strategy_min_jpy_proxy_return_pct` | 1.0 | 0.5-1.5 | Minimum same-direction USDJPY return threshold |
| `strategy_trend_period` | 84 | 63-126 | XTI D1 SMA trend filter |
| `strategy_atr_period` | 20 | 14-30 | ATR period for hard stop |
| `strategy_atr_sl_mult` | 3.0 | 2.5-4.0 | ATR hard-stop distance multiplier |
| `strategy_max_hold_days` | 21 | 14-31 | Calendar-day stale-position guard |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

- Host/traded symbol: `XTIUSD.DWX`, magic slot 0.
- Read-only confirmation symbol: `USDJPY.DWX`, D1 closed bars.

## 4. Timeframe

- Base timeframe: D1.
- Confirmation timeframe: D1.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 5-12.
- Typical hold: weekly packages, capped at 21 calendar days by default.
- Regime preference: WTI directional moves confirmed by yen oil-importer FX
  pressure.
- Risk mode for Q02 backtests: RISK_FIXED.

## 6. Source Citation

U.S. Energy Information Administration, "Japan", Country Analysis Brief, URL
https://www.eia.gov/international/analysis/country/JPN.

Bank of Japan, Uchida, S., "Recent Developments in Economic Activity, Prices,
and Monetary Policy", 2026-06-03, URL
https://www.boj.or.jp/en/about/press/koen_2026/ko260603a.htm.

Supplemental: Beckmann, J., Czudaj, R. L., and Arora, V., "The Relationship
between Oil Prices and Exchange Rates", U.S. Energy Information Administration
working paper, June 2017.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, AutoTrading setting, or portfolio gate file is
touched by this build.

## Revision History

| Version | Date | Reason |
|---|---|---|
| v1 | 2026-06-30 | Initial WTI/JPY oil-importer confirmation build |
