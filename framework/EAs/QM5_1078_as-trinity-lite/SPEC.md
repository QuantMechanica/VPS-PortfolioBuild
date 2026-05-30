# QM5_1078_as-trinity-lite - Strategy Spec

**EA ID:** QM5_1078
**Slug:** `as-trinity-lite`
**Source:** `2df06de7-6a3a-5b06-9e6d-446d1a01fab9`
**Author of this spec:** Codex
**Last revised:** 2026-05-26

## 1. Strategy Logic

This EA mechanises the Allocate Smartly / Faber Trinity Portfolio Lite tactical sleeve as a V5 multi-symbol monthly rotation. Each chart instance trades exactly one registered symbol and slot, but it reads the complete six-symbol DWX universe to rank relative momentum.

On the first D1 execution bar after a completed month, the EA computes each asset's composite momentum as the average of 1, 3, 6, and 12 month-end price returns. It selects the top `strategy_concentration_count` assets, then requires the current asset to be above its 10-month SMA. Selected assets above trend are held long; assets outside the rank set or below trend are flat.

## 2. Parameters

| Parameter | Default | Meaning |
|---|---:|---|
| `strategy_concentration_count` | 3 | Number of top-ranked assets eligible for long exposure. |
| `strategy_sma_months` | 10 | Monthly SMA trend filter from the source rule. |
| `strategy_min_monthly_bars` | 14 | Minimum month-end history before trading. |
| `strategy_atr_period` | 20 | D1 ATR period for the V5 protective stop. |
| `strategy_atr_sl_mult` | 6.0 | ATR multiple for the initial catastrophic stop. |
| `strategy_max_spread_points` | 5000 | Spread guard; 0 disables it. |

## 3. Symbol Universe

Registered build slots:

| Slot | Symbol | Sleeve role |
|---:|---|---|
| 0 | `SP500.DWX` | US equity proxy; backtest-only custom symbol caveat from card. |
| 1 | `NDX.DWX` | US growth equity proxy / deploy-validation substitute. |
| 2 | `WS30.DWX` | US blue-chip equity proxy / deploy-validation substitute. |
| 3 | `GDAXI.DWX` | Europe equity proxy. |
| 4 | `XAUUSD.DWX` | Gold proxy. |
| 5 | `XTIUSD.DWX` | Oil proxy. |

## 4. Risk Model

Backtest sets use `RISK_FIXED=1000` and `RISK_PERCENT=0`. The default `PORTFOLIO_WEIGHT=0.333333` represents equal weight across three selected active tactical sleeves. If fewer than three selected assets pass the trend filter, the inactive sleeves remain flat rather than redistributing risk.

## 5. Implementation Notes

The source strategy exits by monthly rotation/trend state rather than an intramonth stop. This build adds only a framework-compatible ATR stop so `QM_RiskSizer` can size finite risk. No trailing, break-even, pyramiding, partial exits, news override, or unapproved filters are added.

The EA is intentionally run on D1 charts to detect completed month transitions from daily bars while using month-end closes for all ranking and SMA calculations.

## Revision History

| Version | Date | Reason |
|---|---|---|
| v1 | 2026-05-26 | Initial V5 build from APPROVED card. |
