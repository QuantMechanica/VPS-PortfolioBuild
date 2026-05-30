# QM5_1079_as-ivy-taa - Strategy Spec

**EA ID:** QM5_1079
**Slug:** `as-ivy-taa`
**Source:** `2df06de7-6a3a-5b06-9e6d-446d1a01fab9`
**Author of this spec:** Codex
**Last revised:** 2026-05-26

## 1. Strategy Logic

This EA mechanises the Allocate Smartly / Faber Ivy Portfolio tactical overlay as a V5 single-symbol sleeve. On the first execution bar after a completed month, it compares the latest closed monthly close with the 10-month simple moving average of monthly closes. If close is above SMA10, the sleeve is risk-on and the EA opens or holds a long position. If close is at or below SMA10 at the next monthly evaluation, the EA exits to cash/flat.

## 2. Parameters

| Parameter | Default | Meaning |
|---|---:|---|
| `strategy_sma_months` | 10 | Monthly SMA lookback from the source rule. |
| `strategy_min_monthly_bars` | 12 | Minimum monthly history before trading. |
| `strategy_atr_period_d1` | 20 | D1 ATR period for the V5 protective stop. |
| `strategy_atr_sl_mult` | 4.0 | ATR multiple for the initial safety stop. |
| `strategy_take_profit_rr` | 0.0 | Optional RR take-profit; 0 disables TP. |
| `strategy_max_spread_points` | 5000 | Strategy spread guard; 0 disables it. |

## 3. Symbol Universe

Registered build slots:

| Slot | Symbol | Sleeve role |
|---:|---|---|
| 0 | `SP500.DWX` | US equity proxy; backtest-only custom symbol caveat from card. |
| 1 | `NDX.DWX` | US equity deploy-validation substitute. |
| 2 | `WS30.DWX` | US equity deploy-validation substitute. |
| 3 | `GDAXI.DWX` | International equity / Europe index proxy. |
| 4 | `XAUUSD.DWX` | Commodity proxy. |
| 5 | `XTIUSD.DWX` | Commodity proxy. |

REIT and bond sleeves from the original Ivy portfolio are intentionally flat/cash until OWNER/CTO assigns DWX-safe proxies. US equity and commodity substitute symbols are separate proxy sleeves; portfolio construction must avoid double-counting substitutes in the same basket manifest.

## 4. Risk Model

Backtest sets use `RISK_FIXED=1000` and `RISK_PERCENT=0`. Sleeve set files use `PORTFOLIO_WEIGHT=0.2` to reflect the original equal 20% sleeve allocation. Live promotion must switch to percent risk per V5 ENV rules.

## 5. Implementation Notes

The source strategy has no intramonth stop. The EA adds only a framework-compatible catastrophic ATR stop so `QM_RiskSizer` can size positions against finite risk. No trailing, break-even, pyramiding, partial exits, news override, or additional entry filters are added.

## Revision History

| Version | Date | Reason |
|---|---|---|
| v1 | 2026-05-26 | Initial V5 build from APPROVED card. |
