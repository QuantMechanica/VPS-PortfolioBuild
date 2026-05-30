---
ea_id: QM5_1245
slug: urquhart-gold-intraday-ma
type: strategy
source_id: afab7a6f-c3c8-51ae-a609-f376744beb8e
sources:
  - "[[sources/ssrn-financial-economics-network]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/intraday-technical-analysis]]"
indicators:
  - "[[indicators/moving-average]]"
  - "[[indicators/atr-stop]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-19
g0_approval_reasoning: "Urquhart-Batten-Lucey-McGroarty-Peat 2015 SSRN 2652637 'Does Technical Analysis Beat the Market? - HF Trading in Gold and Silver' - named academic authors + verifiable SSRN URL (R1 PASS); deterministic SMA(20) cross SMA(160) M15 entry + crossback exit + 48-bar max-hold + 2.0xATR(96) hard stop + 07:00-22:00 session."
---

# Urquhart Gold Intraday Moving-Average Rule

## Quelle

- Source: [[sources/ssrn-financial-economics-network]]
- URL: ssrn.com/abstract=2652637
- Named source author: Andrew Urquhart, Jonathan A. Batten, Brian M. Lucey, Frank McGroarty, Maurice Peat, "Does Technical Analysis Beat the Market? - Evidence from High Frequency Trading in Gold and Silver" (2015).
- Location: SSRN abstract states that the paper tests intraday technical trading rules in gold and silver using three popular moving-average rules, and that longer-history parameter combinations were more successful for gold.

## Mechanik

### Entry

1. Trade `XAUUSD.DWX` on M15.
2. Compute `fast_ma = SMA(Close, 20)` and `slow_ma = SMA(Close, 160)`.
3. If flat and `fast_ma` crosses above `slow_ma` on a closed M15 bar, open LONG at the next bar.
4. If flat and `fast_ma` crosses below `slow_ma` on a closed M15 bar, open SHORT at the next bar.

### Exit

- Close LONG when `fast_ma` crosses below `slow_ma`.
- Close SHORT when `fast_ma` crosses above `slow_ma`.
- Close any open trade after 48 M15 bars if no opposite cross has occurred.

### Stop Loss

- Hard stop at `2.0 * ATR(M15, 96)` from entry.
- Optional P3 trailing stop: `1.5 * ATR(M15, 96)` after +1R unrealized profit.

### Position Sizing

- P2 baseline: `RISK_FIXED = 1000` USD per trade.
- Live: `RISK_PERCENT = 0.25`.

### Zusätzliche Filter

- Trade only 07:00-22:00 broker time to avoid the lowest-liquidity gold hours.
- Skip first 30 minutes after high-impact USD news if a deterministic news table is available.
- P3 sweep: fast MA `{10, 20, 40}`, slow MA `{120, 160, 240}`, max hold `{32, 48, 64}` M15 bars.

## Concepts

- [[concepts/trend-following]] - primary
- [[concepts/intraday-technical-analysis]] - secondary

## Pipeline-Verlauf

- G0: 2026-05-18, PENDING, awaiting QB verdict.
