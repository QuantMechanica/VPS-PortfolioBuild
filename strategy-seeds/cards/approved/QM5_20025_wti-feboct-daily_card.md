---
ea_id: QM5_20025
slug: wti-feboct-daily
strategy_id: GORSKA-KRAWIEC-WTI-CAL-2015_S01
source_id: GORSKA-KRAWIEC-WTI-CAL-2015
status: APPROVED
created: 2026-07-21
created_by: Research+Development
strategy_type_flags: [calendar-seasonality, month-of-year, symmetric-long-short, atr-hard-stop, time-stop, low-frequency]
target_symbols: [XTIUSD.DWX]
timeframes: [D1]
ml_required: false
g0_status: APPROVED
q01_status: PASS
pipeline_phase: Q02
---
# WTI February-October Daily Rotation

## Hypothesis
Trade the published WTI month contrast: long each February D1 session and
short each October session, resetting risk at the next D1 boundary.

## Source citations
- Primary tier A: Gorska & Krawiec (2015), DOI 10.22630/PRS.2015.15.4.54,
  Tables 4-5 (February-October z=2.27121).

## Rules and parameters
- New February D1 bar: BUY once. New October D1 bar: SELL once.
- Consume the day before entry gates; close at next D1 or after one stale day.
- ATR(20) stop 2.75, spread cap 2500 points.
- RISK_FIXED=1000, RISK_PERCENT=0, weight 1. No sweep.
- No TP, trailing, scale, grid, martingale, ML, or external feed.

## Risk
The primary risks are continuous-CFD basis, post-publication decay, broker
month/session mapping, gaps, and repeated exposure within eligible months.
Q02 must reject on governed cadence, PF, drawdown, or determinism criteria.

## Non-duplicate and framework alignment
Existing WTI month cards hold month-scale packages; weekday cards use weekday
state. This carrier uniquely uses two signed month states with daily resets.
No-trade locks symbol/D1/slot/parameters; entry maps month to direction;
management closes next-D1; close uses framework/stop/Friday paths.

## Safety
Q02 only. No live set, AutoTrading, T_Live, manifest, or portfolio-gate change.
