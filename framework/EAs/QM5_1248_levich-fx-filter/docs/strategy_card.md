---
ea_id: QM5_1248
slug: levich-fx-filter
type: strategy
source_id: afab7a6f-c3c8-51ae-a609-f376744beb8e
g0_status: APPROVED
pipeline_phase: G0
last_updated: 2026-05-19
---

# Levich-Thomas FX Percent-Filter Rule

## Quelle

- Source: `sources/ssrn-financial-economics-network`
- URL: ssrn.com/abstract=226734
- Named source author: Richard M. Levich and Lee R. Thomas, "The Significance of Technical Trading-Rule Profits in the Foreign Exchange Market: a Bootstrap Approach" (NBER Working Paper, 1991).

## Mechanik

### Entry

1. Trade major DWX FX pairs: `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `USDCHF.DWX`.
2. On closed bars, maintain a reference range since the last signal.
3. If flat and `Close >= last_low * (1 + 0.005)`, open LONG at the next eligible bar.
4. If flat and `Close <= last_high * (1 - 0.005)`, open SHORT at the next eligible bar.

### Exit

- Reverse condition closes the current position.
- For P2 safety, the implementation uses close-first behavior; the opposite side can enter on the next eligible bar.

### Stop Loss

- Hard stop at `2.0 * ATR(timeframe, 48)` from entry.

### Position Sizing

- P2 baseline: `RISK_FIXED = 1000` USD per trade.
- Live: `RISK_PERCENT = 0.25`.

### Zusätzliche Filter

- Trade only Sunday 23:00 through Friday 18:00 broker time.
- Skip if spread exceeds `2.5x` the symbol's 20-day median spread for the signal hour.
- P3 sweep: filter threshold `{0.25%, 0.5%, 1.0%}`, timeframe `{H1, H4, D1}`.

## Concepts

- `filter-rule`
- `fx-trend-following`
