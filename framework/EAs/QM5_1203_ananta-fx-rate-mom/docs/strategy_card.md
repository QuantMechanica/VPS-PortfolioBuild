---
ea_id: QM5_1203
slug: ananta-fx-rate-mom
type: strategy
source_id: afab7a6f-c3c8-51ae-a609-f376744beb8e
g0_status: APPROVED
pipeline_phase: G0
last_updated: 2026-05-18
---

# ANANTA FX Interest-Rate-Differential Momentum

## Quelle
- Source: SSRN Financial Economics Network.
- Source citation: 2014 SSRN abstract 2419243.
- Named source author: Nicolas Georges, "ANANTA: A Systematic Quantitative FX Trading Strategy" (SSRN, 2014).
- Location: abstract and methodology summary: G10 FX strategy using fixed-income signals; simple +1/-1 signal when an interest-rate differential is above/below its moving average; 2-day and 15-day model variants.

## Mechanik
- Target symbols: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, AUDUSD.DWX, NZDUSD.DWX, USDCAD.DWX, USDCHF.DWX.

### Entry
At each scheduled London and New York rate-fix update:
1. Read deterministic local CSV rates for USD, EUR, GBP, JPY, AUD, NZD, CAD, CHF.
2. For each currency-vs-USD tradable leg, compute `rate_diff = local_short_rate - USD_short_rate`.
3. Compute `SMA(rate_diff, 15)` for the long-term source variant.
4. If `rate_diff > SMA(rate_diff, 15)`, target LONG local currency versus USD.
5. If `rate_diff < SMA(rate_diff, 15)`, target SHORT local currency versus USD.
6. Net all country signals into one position per DWX symbol, capped at one position per magic number.

### Exit
- Reverse or flatten at the next scheduled rebalance when the target signal changes sign or becomes unavailable.
- Close any position if the required rates CSV has no fresh observation for that currency for more than 3 business days.

### Stop Loss
- Hard stop at 2.0x D1 ATR(20) from entry.
- Portfolio kill-switch: no new entries for the day after realized open PnL reaches -2R.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` USD per active symbol, with total basket exposure capped at 4R.
- Live: `RISK_PERCENT = 0.25`, same basket cap.
- Equal-weight symbols after signal netting; do not volatility-resize because the source states constant gross exposure.

### Zusaetzliche Filter
- Require at least 30 valid rate-differential observations before first trade.
- External rates must be versioned local CSV inputs; EA must not call a web API.
- P3 sweep: moving average `{2, 5, 15}` days, rebalance `{London only, New York only, both}`.
