---
ea_id: QM5_10947
slug: zuck-24h-cont
type: strategy
source_id: 21ef3dfd-fac6-5d5d-b9a0-5ba447992f94
source_citation: "Gregory Zuckerman, The Man Who Solved the Market: How Jim Simons Launched the Quant Revolution, Portfolio/Penguin, 2019, ISBN 9780735217980."
sources:
  - "[[sources/zuckerman-man-who-solved-market]]"
concepts:
  - "[[concepts/daily-continuation]]"
  - "[[concepts/short-term-momentum]]"
indicators:
  - "[[indicators/prior-day-return]]"
  - "[[indicators/atr]]"
target_symbols: [EURUSD.DWX, USDJPY.DWX, GBPUSD.DWX, XAUUSD.DWX, NDX.DWX, WS30.DWX]
period: D1
strategy_type_flags: [n-period-max-continuation, time-stop, atr-hard-stop, symmetric-long-short]
g0_status: APPROVED
expected_trades_per_year_per_symbol: 180
last_updated: 2026-05-22
r1_track_record: PASS
r1_reasoning: "Single source_id present; published book with title, ISBN, official author page, and specific source location satisfies lineage requirement."
r2_mechanical: PASS
r2_reasoning: "Prior D1 return vs ATR fraction threshold, symmetric long/short entry, 24h time exit, and ATR stop are all fully deterministic rules."
r3_data_available: PASS
r3_reasoning: "All target symbols (EURUSD, USDJPY, GBPUSD, XAUUSD, NDX, WS30) are DWX OHLC instruments requiring no external data."
r4_ml_forbidden: PASS
r4_reasoning: "Fixed return threshold and ATR parameters, no ML, no adaptive sizing, one position per magic."
pipeline_phase: G0
g0_approval_reasoning: "R1 source book+official link; R2 deterministic prior-day continuation with ATR threshold/stop/time exit and daily cadence plausible; R3 DWX OHLC symbols testable; R4 fixed symmetric rules no ML/grid/martingale."
---

# Zuckerman Twenty-Four-Hour Continuation

## Quelle
- Source: Gregory Zuckerman, "The Man Who Solved the Market", Portfolio/Penguin, 2019, ISBN 9780735217980.
- Official author page: https://www.gregoryzuckerman.com/the-books/the-man-who-solved-the-market/
- Source location: Laufer short-term effects section; public mirror lines 3603-3608 state that previous day's trading often predicted the next day's activity, termed the "twenty-four-hour effect".

## Mechanik

### Entry
- At the start of each new trading day, compute prior D1 return: `ret1 = close_D1[1] / close_D1[2] - 1`.
- If `ret1 > +0.25 * ATR(14,D1) / close_D1[2]`, BUY at market.
- If `ret1 < -0.25 * ATR(14,D1) / close_D1[2]`, SELL at market.
- No trade if absolute prior-day move is below threshold.

### Exit
- Exit at the next daily close or after 24 hours, whichever is implementable first in the framework.
- Emergency SL = `1.25 * ATR(14,D1)` from entry.

### Stop Loss
- Initial SL = `1.25 * ATR(14,D1)`.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.

### Zusaetzliche Filter
- Skip Friday entries in baseline to avoid weekend hold; P3 may test Friday inclusion.
- Skip if current spread > 10% of ATR(14,H1).
- One position per magic; no pyramiding.

## Parameters To Test
```yaml
- name: trigger_atr_frac
  default: 0.25
  sweep_range: [0.10, 0.25, 0.40]
- name: atr_stop_mult
  default: 1.25
  sweep_range: [0.8, 1.25, 1.75]
- name: hold_hours
  default: 24
  sweep_range: [12, 24, 36]
```

## Author Claims
- The source identifies a "twenty-four-hour effect" in which prior-day trading often predicted the next day's activity.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Book title, ISBN, author page, and source location are provided. |
| R2 Mechanical | UNKNOWN | Narrative effect is formalized as one-day return continuation with fixed threshold, stop, and time exit. |
| R3 DWX-testbar | PASS | Uses only DWX OHLC bars; available on FX, gold, and index CFDs. |
| R4 No ML | PASS | Fixed return threshold and time exit; no adaptive parameters or multi-position stacking. |

## R3
Primary P2 basket: EURUSD.DWX, USDJPY.DWX, GBPUSD.DWX, XAUUSD.DWX, NDX.DWX, WS30.DWX.

## Framework Alignment
```yaml
modules_used:
  no_trade:
    used: true
    notes: "Friday skip and spread cap"
  trade_entry:
    used: true
    notes: "prior D1 return continuation"
  trade_management:
    used: false
    notes: "no trailing or partials"
  trade_close:
    used: true
    notes: "24-hour time exit plus ATR emergency stop"
hard_rules_at_risk: []
at_risk_explanation: |
  Standard one-position-per-magic and Friday-close compatible in baseline.
```

## Pipeline-Verlauf
- G0: 2026-05-22, PENDING.

## Lessons Learned
- TBD during pipeline run.
