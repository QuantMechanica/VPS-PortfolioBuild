---
ea_id: QM5_1207
slug: bbadx-index-skew
type: strategy
source_id: afab7a6f-c3c8-51ae-a609-f376744beb8e
concepts:
  - volatility-breakout
  - trend-strength-filter
indicators:
  - bollinger-bands
  - adx
g0_status: APPROVED
pipeline_phase: G0
last_updated: 2026-05-18
g0_approval_reasoning: "R1 PASS SSRN URL/title/authors; R2 PASS deterministic BB+ADX entry and mean/timeout/stop exits; R3 PASS testable on GER40.DWX/DWX indices; R4 PASS fixed rules no ML/grid/martingale."
---

# Bollinger Band Breakout With ADX Index Filter

## Source

- SSRN abstract 2230499.
- Named source authors: Lim Kai Jie Shawn, Tilman Hisarli, Ng Shi He, "The Profitability of a Combined Signal Approach: Bollinger Bands and the ADX" (SSRN / International Federation of Technical Analysts Journal, 2014).
- The source describes a Bollinger-band trading rule across CAC, DAX, FTSE, HSI, KOSPI, and Nikkei large-cap indices, with ADX combined-signal evidence and positively skewed tactical-trade distributions.

## Mechanics

### Entry

At each `GER40.DWX` D1 close:

1. Compute Bollinger Bands using `SMA(20)` and `2.0 * stdev(20)`.
2. Compute `ADX(14)`.
3. Long breakout entry: if `Close > upper_band` and `ADX(14) >= 20`, open LONG at the next D1 open.
4. Short breakout entry: if `Close < lower_band` and `ADX(14) >= 20`, open SHORT at the next D1 open.
5. If `ADX(14) < 20`, do not open new trades even if a band is crossed.

### Exit

- LONG: close when D1 close returns below `SMA(20)` or after 5 trading days, whichever comes first.
- SHORT: close when D1 close returns above `SMA(20)` or after 5 trading days, whichever comes first.

### Stop Loss

- Initial stop at opposite Bollinger band at entry, capped at 3.0x D1 ATR(20).
- If stop cap is hit before mean/timeout exit, close immediately via broker stop.

### Position Sizing

- P2 baseline: `RISK_FIXED = 1000` USD.
- Live: `RISK_PERCENT = 0.25`.
- Primary symbol is `GER40.DWX`; P2 may also test `UK100.DWX` and `JPN225.DWX`.

### Additional Filters

- Require 60 D1 bars before first trade.
- Skip entries on full-holiday and early-close sessions where the framework/session data prevents trading.
- P3 sweep: ADX threshold `{15, 20, 25}`, Bollinger width `{1.5, 2.0, 2.5}`, max hold `{3, 5, 10}` days.
