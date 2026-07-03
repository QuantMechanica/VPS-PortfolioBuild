# QM5_12982_brent-sep-prem - Strategy Spec

**EA ID:** QM5_12982
**Slug:** `brent-sep-prem`
**Source:** `ARENDAS-OIL-SEASON-2018`
**Author of this spec:** Codex
**Last revised:** 2026-07-03

## 1. Strategy Logic

This EA implements a low-frequency structural Brent crude-oil sleeve on
`XBRUSD.DWX`. It isolates the September terminal segment of the
February-September oil-seasonality window described in the Arendas et al.
source. The rule is deliberately simple: enter long on each broker-calendar
September D1 bar, then flatten on the next D1 bar, outside September, by max-hold
guard, Friday close, or ATR hard stop.

This is not a duplicate of `QM5_12961_wti-sep-prem`, which tests the WTI
benchmark. It is also separate from `QM5_12981_brent-febsep-prem`, which tests
only the first tradable D1 bar of every month in the broad February-September
source window. This EA tests daily September exposure on the Brent route only.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_entry_month` | 9 | fixed | Broker-calendar September gate |
| `strategy_atr_period` | 20 | 14-30 | ATR stop period |
| `strategy_atr_sl_mult` | 2.25 | 1.5-3.0 | Stop distance multiplier |
| `strategy_max_hold_days` | 1 | 1-2 | Calendar-day stale-position guard |
| `strategy_max_spread_points` | 1200 | 800-1600 | Brent entry spread cap |

## 3. Symbol Universe

- `XBRUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 18-22 before framework filters.
- Typical hold: one D1 bar.
- Regime preference: September Brent terminal-month crude-oil seasonality.
- Risk mode for Q02 backtests: RISK_FIXED.

## 6. Source Citation

Arendas, P., Tkacova, D. and Bukoven, J., "Seasonal patterns in oil prices and
their implications for investors", Journal of International Studies, 11(2),
180-192, DOI 10.14254/2071-8330.2018/11-2/12, URL
https://www.jois.eu/files/12_547_Arendas%20et%20al.pdf.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, AutoTrading setting, or portfolio gate file is
touched by this build.
