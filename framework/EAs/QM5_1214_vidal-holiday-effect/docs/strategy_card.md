---
ea_id: QM5_1214
slug: vidal-holiday-effect
type: strategy
source_id: afab7a6f-c3c8-51ae-a609-f376744beb8e
g0_status: APPROVED
pipeline_phase: G0
last_updated: 2026-05-18
---

# Vidal-Garcia Holiday Effect Index Window

Approved build copy of `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1214_vidal-holiday-effect.md`.

## Mechanik

- For `SP500.DWX`, `NDX.DWX`, and `WS30.DWX`, open LONG at the open of the last full trading day before a U.S. market holiday.
- For `GER40.DWX`, open LONG at the open of the first full trading day after a major German/Euronext holiday.
- Skip holidays with a missing calendar row, unscheduled closure, or fewer than 4 H1 bars in the intended hold window.
- U.S. pre-holiday leg exits at the final tradable bar before the holiday closure.
- European post-holiday leg exits at the end of the first full trading day after the holiday.
- Hard stop at 1.3x H1 ATR(20).
- No re-entry for the same holiday window.

## Position Sizing

- Backtest default: `RISK_FIXED=1000`.
- Live default: `RISK_PERCENT=0.25`.
- Max calendar exposure is handled by one symbol slot per chart and portfolio-weighted setfiles.

## P3 Variants

- U.S. leg close-only variant: `strategy_us_close_only=true`.
- Europe pre+post two-day variant: `strategy_eu_prepost_two_day=true`.

## Live Caveat

`SP500.DWX` is not broker-routable. If research passes only on `SP500.DWX`, T6 deploy needs parallel validation on `NDX.DWX` or `WS30.DWX`.
