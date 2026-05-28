---
ea_id: QM5_1167
slug: qp-inflation-gold-bond
type: strategy
source_id: 7ede58dd-d184-5099-9d48-7a65de230853
g0_status: APPROVED
pipeline_phase: G0
last_updated: 2026-05-18
g0_approval_reasoning: "R1 PASS Quantpedia title attribution; R2 PASS deterministic CPI-regime plus momentum entry/exit; R3 PASS testable on XAUUSD.DWX with local CPI/Treasury proxy and flat non-gold state; R4 PASS fixed non-ML one-position rule."
---

# Quantpedia Inflation Gold Bond Timing

## Quelle
- Source: Quantpedia encyclopedia, "Using Inflation Data for Systematic Gold and Treasury Investment Strategies"
- Named source author: Cyril Dujava, Quant Analyst, Quantpedia.
- Location: "Final Model Trading Strategy" and "Conclusions".

## Mechanik

### Entry
At each monthly rebalance after CPI release lag is known:
1. Read point-in-time CPI/inflation regime from a versioned local CSV.
2. Compute 12-month momentum for XAUUSD.DWX and the Treasury proxy series.
3. If inflation is accelerating and XAUUSD.DWX momentum is positive, open or maintain LONG XAUUSD.DWX.
4. If inflation is decelerating and the Treasury proxy momentum is positive, do not trade XAUUSD.DWX; record `BOND_SIGNAL_ON` for research reporting only unless a broker-routable bond/rates CFD is confirmed.

### Exit
- Close XAUUSD.DWX when the accelerating-inflation plus positive-gold-momentum condition is no longer true at monthly rebalance.
- If no tradeable bond/rates proxy exists, the non-gold state is cash/flat.

### Stop Loss
- XAUUSD.DWX hard stop at 5.0x D1 ATR(20) from entry.
- Monthly signal exit remains mandatory.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` USD on the active tradeable leg.
- Live: `RISK_PERCENT = 0.25`.

### Zusaetzliche Filter
- EA must use local, versioned macro input files only; no live web/API calls.
- Use only data available after publication lag; no current-month CPI lookahead.
- Optional P3 variant if a rates CFD exists: trade the bond/rates proxy during decelerating-inflation positive-trend months.
