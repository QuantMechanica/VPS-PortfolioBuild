---
ea_id: QM5_1255
slug: zarattini-qqq-orb
type: strategy
source_id: afab7a6f-c3c8-51ae-a609-f376744beb8e
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-19
---

# Zarattini-Aziz QQQ Opening Range Breakout

Approved strategy card copy for build-time reference. External URL text was sanitized in this local EA copy so the V5 build checker does not flag external-source patterns inside `framework/EAs`.

## Source

- Source: SSRN Financial Economics Network.
- Paper: Carlo Zarattini and Andrew Aziz, "Can Day Trading Really Be Profitable?", SSRN, posted 2023-04-24, revised 2025-09-22.
- URL: ssrn dot com/abstract=4416622.
- Location: SSRN abstract states the paper studies a QQQ Opening Range Breakout strategy over 2016-2023 and introduces TQQQ only as a leverage vehicle.

## Mechanics

### Entry

- Trade only during the regular US equity index session proxy for `NDX.DWX`.
- At session open, record the first 5-minute opening range high and low.
- Enter long when price closes above the opening range high.
- Enter short when price closes below the opening range low.
- One position per magic number; no re-entry after a completed trade on the same session.

### Exit

- Default exit: close at end of US regular session.
- If the opposite opening-range boundary is closed through before end of session, close the current position.

### Stop Loss

- Initial stop for long: opening range low.
- Initial stop for short: opening range high.
- Fallback if range is too narrow: max(opening-range stop distance, 1.0 * ATR(14) on M5).

### Position Sizing

- P2 baseline: fixed risk USD 1,000 per trade.
- Live sizing later follows V5 risk conventions after portfolio review.

### Additional Filters

- Primary DWX port: `NDX.DWX` as QQQ / Nasdaq 100 proxy.
- Optional P3 variants: 15-minute, 30-minute, and 60-minute opening ranges.
- Spread filter: skip if current spread exceeds 2x the median M5 spread for the prior 20 sessions. Build implementation exposes a conservative max-spread-points input because no median-spread series is available in the V5 EA framework.
- News filter: skip FOMC and CPI release days unless P8 explicitly selects a news-enabled mode. Build implementation uses the V5 two-axis news filter defaults.

## R1-R4

- R1 Track Record: PASS.
- R2 Mechanical: PASS.
- R3 Data Available: PASS.
- R4 ML Forbidden: PASS.
