---
ea_id: QM5_1249
slug: hsu-carry-stop
type: strategy
source_id: afab7a6f-c3c8-51ae-a609-f376744beb8e
g0_status: APPROVED
pipeline_phase: G0
last_updated: 2026-05-19
---

# Hsu-Taylor-Wang FX Carry With Fixed Stop

## Source

- Source: SSRN Financial Economics Network
- URL: ssrn dot com slash abstract=3158101
- Named source author: Po-Hsuan Hsu, Mark P. Taylor, Zigan Wang, "The Out-of-Sample Performance of Carry Trades" (2019).

## Mechanics

### Entry

1. Trade DWX major carry pairs with available monthly short-rate CSV: `AUDJPY.DWX`, `NZDJPY.DWX`, `GBPJPY.DWX`, `USDJPY.DWX`, `AUDUSD.DWX`, `NZDUSD.DWX`.
2. On the first trading day of each month, compute each pair's interest-rate differential from a deterministic monthly rates CSV.
3. Open LONG pairs where base-currency rate minus quote-currency rate ranks in the top 2 and is positive.
4. Open SHORT pairs where base-currency rate minus quote-currency rate ranks in the bottom 2 and is negative.

### Exit

- Rebalance monthly; close pairs that leave the top/bottom 2 or whose differential crosses zero.
- Close immediately on fixed stop-loss hit.

### Stop Loss

- Fixed stop at `2.5 * ATR(D1, 20)` from entry.
- After a stopped trade, do not re-enter the same symbol until the next monthly rebalance.

### Position Sizing

- P2 baseline: `RISK_FIXED = 1000` USD per active pair.
- Live: `RISK_PERCENT = 0.25` per active pair.

### Additional Filters

- If the monthly rates CSV is missing or stale, stay flat.
- Optional P3 filter: block new carry entries when basket realized volatility over 20 D1 bars exceeds its 252-day 80th percentile.
- P3 sweep: rank count `{1, 2, 3}`, ATR stop `{2.0, 2.5, 3.0}`, rebalance `{monthly, quarterly}`.

## Build Notes

- Local copy is URL-sanitized for build-check compliance.
- No ML, online learning, martingale or unbounded grid.
