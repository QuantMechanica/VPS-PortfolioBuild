---
ea_id: QM5_1182
slug: qp-ecb-d0-dax-short
type: strategy
source_id: 7ede58dd-d184-5099-9d48-7a65de230853
concepts:
  - calendar-effect
  - intraday-reversal
indicators:
  - ecb-calendar
  - session-window
g0_status: APPROVED
pipeline_phase: G0
last_updated: 2026-05-17
g0_approval_reasoning: "R1 URL+author cited; R2 deterministic ECB D0 session-open short to same-day close exit; R3 GER40.DWX DAX proxy testable; R4 fixed rules no ML/grid/martingale."
---

# Quantpedia ECB Announcement-Day DAX Fade

## Source

- Source: Quantpedia encyclopedia, "Uncovering the Pre-ECB Drift and Its Trading Strategy Applications"
- Retrieved 2026-05-17.
- Named author: Cyril Dujava, Quantpedia.
- Location: Results / D0 open-to-close discussion for DAX and STOXX 50.

## Mechanics

### Entry

On each confirmed ECB press-conference trading day `D0`:

1. At the regular cash-session open proxy for `GER40.DWX`, open SHORT `GER40.DWX`.
2. Require the `D-1` pre-ECB drift window to have closed; do not carry a position from QM5_1181 into this card.
3. Skip if the scheduled ECB announcement time cannot be mapped to the broker session calendar.

### Exit

- Close at the regular cash-session close proxy on `D0`.
- Safety exit: close at D1 close if intraday session mapping fails after entry.

### Stop Loss

- Initial stop: 1.5x ATR(20) converted from D1 ATR to intraday points.
- Hard time stop: same-day close, regardless of PnL.

### Position Sizing

- P2 baseline: `RISK_FIXED = 1000` USD.
- Live: `RISK_PERCENT = 0.25`.

### Additional Filters

- Requires ECB press-conference calendar and broker-to-CET session mapping.
- Optional P3 variants: skip when `D0` opens with a gap larger than 1.0x ATR(20).
- This is a short-only announcement-day fade, not the D-1 long pre-drift.

## Concepts

- calendar-effect
- intraday-reversal
