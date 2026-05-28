---
ea_id: QM5_1217
slug: zarattini-donchian-ensemble
type: strategy
source_id: afab7a6f-c3c8-51ae-a609-f376744beb8e
sources:
  - "[[sources/ssrn-financial-economics-network]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/breakout]]"
indicators:
  - "[[indicators/donchian-channel]]"
  - "[[indicators/realized-volatility]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-18
g0_approval_reasoning: "R1 SSRN URL and named SFI paper source; R2 deterministic Donchian ensemble entries/exits; R3 crypto trend concept ported to DWX FX/metal/index basket; R4 fixed rules, no ML/adaptive PnL/grid/martingale."
---

# Zarattini-Pagani-Barbon Donchian Ensemble Trend

## Quelle
- Source: [[sources/ssrn-financial-economics-network]]
- URL: https://ssrn.com/abstract=5209907
- Named source authors: Carlo Zarattini, Alberto Pagani, and Andrea Barbon, "Catching Crypto Trends; A Tactical Approach for Bitcoin and Altcoins" (Swiss Finance Institute Research Paper No. 25-80, 2025).
- Location: SSRN abstract describes an ensemble that aggregates multiple Donchian-channel trend models with different lookbacks, plus volatility-based position sizing.

## Mechanik

### Entry
1. Trade a DWX trend basket: `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `XAUUSD.DWX`, `GER40.DWX`, `NDX.DWX`.
2. On each D1 close, compute Donchian signals for lookbacks `{20, 55, 100}`.
3. For each lookback, score `+1` if `Close > highest_high(lookback)[1]`, `-1` if `Close < lowest_low(lookback)[1]`, else keep that lookback's prior score.
4. Aggregate score = average of the three lookback scores.
5. If flat and aggregate score >= `+0.34`, open LONG at next D1 open.
6. If flat and aggregate score <= `-0.34`, open SHORT at next D1 open.

### Exit
- Close LONG if aggregate score <= 0.
- Close SHORT if aggregate score >= 0.
- Reverse only after the D1 close confirms the opposite threshold.

### Stop Loss
- Hard stop at 2.5x D1 ATR(20).
- If stopped, wait for a fresh opposite-or-same aggregate threshold after at least 5 D1 bars.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` USD per active symbol, max 4R total basket exposure.
- Live: `RISK_PERCENT = 0.25`, max 4R total basket exposure.
- Optional P3 variant: volatility target using 20-day realized volatility; fixed target only, no PnL-adaptive resizing.

### Zusätzliche Filter
- Require at least 120 D1 bars before first signal.
- Source crypto rotation is ported to DWX FX/metal/index trend basket because crypto is not a primary DXZ instrument.
- P3 sweep: lookback sets `{20/55/100, 10/50/200, 25/75/150}`, aggregate entry threshold `{0.34, 0.67}`.

## Concepts (was ist das für eine Strategie)
- [[concepts/trend-following]] - primary
- [[concepts/breakout]] - secondary

## R1–R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | UNKNOWN | SSRN URL is verifiable and names Zarattini/Pagani/Barbon plus Swiss Finance Institute working-paper attribution. |
| R2 Mechanical | UNKNOWN | Donchian lookbacks, vote aggregation, entry thresholds, and exits are deterministic. |
| R3 Data Available | UNKNOWN | Crypto source is ported to DWX FX/metal/index instruments under relaxed R3. |
| R4 ML Forbidden | UNKNOWN | Fixed channel ensemble and fixed volatility target; no learning, adaptive PnL parameters, grid, or martingale. |

## Pipeline-Verlauf
- G0: 2026-05-18, PENDING, awaiting QB verdict.

## Verwandte Strategien
- [[strategies/QM5_1126_mop-tsmom]] - time-series momentum without Donchian breakout voting.
- [[strategies/QM5_1020_williams-vol-bo]] - single-rule volatility breakout trend following.

## Lessons Learned (während Pipeline-Lauf)
- (noch keine)

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Änderung `pipeline_phase` aktualisieren + `last_updated`.*
