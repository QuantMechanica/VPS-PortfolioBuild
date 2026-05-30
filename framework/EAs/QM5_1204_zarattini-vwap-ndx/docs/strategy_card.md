---
ea_id: QM5_1204
slug: zarattini-vwap-ndx
type: strategy
source_id: afab7a6f-c3c8-51ae-a609-f376744beb8e
concepts:
  - intraday-trend
  - vwap
indicators:
  - vwap
  - session-clock
g0_status: APPROVED
pipeline_phase: G0
last_updated: 2026-05-18
---

# Zarattini-Aziz VWAP Trend Trading Port to NDX

## Quelle

- Source: SSRN Financial Economics Network
- Source citation: Carlo Zarattini and Andrew Aziz, "Volume Weighted Average Price (VWAP) The Holy Grail for Day Trading Systems" (SSRN, 2023, revised 2025).
- Location: abstract states a VWAP-based day-trading strategy that goes long when price is above VWAP and short when price is below VWAP, tested on QQQ/TQQQ.

## Mechanik

### Entry

On `NDX.DWX` M5 bars during the configured US index cash session:

1. Compute session VWAP from the start of the cash session using tick volume as the deterministic MT5 proxy.
2. If flat and `Close(M5) > session_VWAP`, open LONG at the next M5 open.
3. If flat and `Close(M5) < session_VWAP`, open SHORT at the next M5 open.
4. If already positioned and price crosses the opposite side of VWAP, reverse only after the current bar closes on the opposite side.

### Exit

- Close LONG when an M5 bar closes below session VWAP.
- Close SHORT when an M5 bar closes above session VWAP.
- Flatten all positions 5 minutes before the configured cash-session close.

### Stop Loss

- Initial stop at 1.2x M15 ATR(20).
- If VWAP exit occurs first, VWAP exit takes precedence.

### Position Sizing

- P2 baseline: `RISK_FIXED = 1000` USD.
- Live: `RISK_PERCENT = 0.25`.
- Source tests QQQ/TQQQ; this card ports to unlevered `NDX.DWX` only.

### Zusätzliche Filter

- Trade only when at least 30 minutes of current-session bars exist to stabilize VWAP.
- Skip full holidays and early closes unless the session calendar confirms enough bars remain for entry.
- P3 sweep: timeframe `{M5, M15}`, VWAP source `{tick_volume, equal_bar_volume}`, stop multiplier `{1.0, 1.2, 1.5}`.

## Pipeline-Verlauf

- G0: 2026-05-18, PENDING, awaiting QB verdict.
