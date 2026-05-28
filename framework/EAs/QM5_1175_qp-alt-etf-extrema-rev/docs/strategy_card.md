---
ea_id: QM5_1175
slug: qp-alt-etf-extrema-rev
type: strategy
source_id: 7ede58dd-d184-5099-9d48-7a65de230853
sources:
  - "[[sources/quantpedia-encyclopedia]]"
concepts:
  - "[[concepts/mean-reversion]]"
  - "[[concepts/cross-sectional-reversal]]"
indicators:
  - "[[indicators/rolling-high-low]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-18
g0_approval_reasoning: "Quantpedia Belobrad 2024 alt-ETF extrema reversal port; R1 named author and Jegadeesh 1990 JF DOI underlying lit PASS; R2 rolling N-day high SHORT / N-day low LONG with one-day D1 exit plus ATR(14)*1.5 stop deterministic PASS; R3 source DBMF/MNA/PBP/WTMF ETFs unavailable but relaxed R3 allows porting."
---

# Quantpedia Extrema Reversal Basket

## Quelle

- Source: [[sources/quantpedia-encyclopedia]] - Quantpedia 2024 "Evaluating Reversal Potential in Niche Alternative ETFs"
- URL: quantpedia.com/evaluating-reversal-potential-in-niche-alternative-etfs/
- Named author: David Belobrad, Junior Quant Analyst, Quantpedia (2024).
- Underlying short-term reversal literature includes Jegadeesh 1990 "Evidence of predictable behavior of security returns", Journal of Finance vol 45, DOI: doi.org/10.1111/j.1540-6261.1990.tb05117.x.
- Location: "Long on Low & Short on High Strategy - Multiple Assets" section.

### Bar Period

- Signals and stops computed on D1 close bars; one-day holding period.

### Target Symbols

- Port basket: NDX.DWX, WS30.DWX, GDAXI.DWX, UK100.DWX, XAUUSD.DWX, XTIUSD.DWX.

## Mechanik

### Entry

On each completed D1 bar:

1. Define a fixed test basket of DWX instruments.
2. For each instrument, compute rolling N-day high and rolling N-day low using completed closes. Default `N = 10`; parameter sweep: 5, 10, 20.
3. If close equals the N-day high, open a one-day SHORT position in that instrument.
4. If close equals the N-day low, open a one-day LONG position in that instrument.
5. Allocate equal risk across all active signals for that day. If an instrument is simultaneously at high and low because of insufficient history, skip it.

### Exit

- Close each position at the next D1 close.
- If the extrema condition persists at the next close, reopen/extend as a fresh one-day position.

### Stop Loss

- Per-position stop: 1.5x ATR(14) from entry.
- Portfolio safety: do not open new signals if aggregate open risk would exceed `RISK_FIXED = 1000` in P2 baseline.

### Position Sizing

- P2 baseline: split `RISK_FIXED = 1000` USD equally across all active signals.
- Live: split `RISK_PERCENT = 0.25` equally across all active signals.

### Zusaetzliche Filter

- Source used DBMF, MNA, PBP, and WTMF niche ETFs; DWX implementation is a port of the extrema-reversal rule to liquid CFD proxies.
- Require at least N+5 valid D1 bars per instrument.
- Do not trade through major scheduled symbol closures; no martingale or averaging.
