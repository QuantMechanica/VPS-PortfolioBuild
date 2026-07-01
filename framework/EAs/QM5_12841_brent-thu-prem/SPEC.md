# QM5_12841_brent-thu-prem - Strategy Spec

**EA ID:** QM5_12841
**Slug:** `brent-thu-prem`
**Source:** `QUAY-WTI-DOW-2019_BRENT_S01`
**Author of this spec:** Codex
**Last revised:** 2026-07-01

## 1. Strategy Logic

This EA implements a low-frequency Brent crude-oil weekday sleeve on
`XBRUSD.DWX`. On each new D1 bar it buys only when the current broker-calendar
D1 bar is Thursday, using a hard ATR stop. It exits on the next non-Thursday
D1 bar or after a one-calendar-day stale-position guard.

This is not a duplicate of the WTI Thursday premium build because it uses the
Brent benchmark. It is also not XNG, XAU/XAG, XTI/XNG, WTI/FX, WTI event,
WTI expiry, WTI month, or commodity RSI logic.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_atr_period` | 20 | 14-30 | ATR period for the hard stop |
| `strategy_atr_sl_mult` | 2.25 | 1.5-3.0 | ATR hard-stop distance multiplier |
| `strategy_max_hold_days` | 1 | 1-2 | Calendar-day stale-position guard |
| `strategy_entry_dow` | 4 | 4 | MQL5 Thursday day-of-week value |
| `strategy_max_spread_points` | 1200 | 800-1800 | Brent entry spread cap |

## 3. Symbol Universe

- `XBRUSD.DWX` - Brent crude-oil CFD proxy, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 40-52 before Q02 history/spread filters.
- Typical hold: one D1 bar.
- Regime preference: source-backed Brent Thursday calendar premium.
- Risk mode for Q02 backtests: `RISK_FIXED`.

## 6. Source Citation

Quayyum, H. A., Khan, M. A. M. and Ali, S. M. "Seasonality in crude oil
returns", Soft Computing 24, 7857-7873 (2020), DOI
https://doi.org/10.1007/s00500-019-04329-0.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, portfolio gate, or AutoTrading setting is
touched by this build.
