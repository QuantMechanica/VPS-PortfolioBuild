---
ea_id: QM5_1226
slug: psaradellis-oil-channel
type: strategy
source_id: afab7a6f-c3c8-51ae-a609-f376744beb8e
sources:
  - "[[sources/ssrn-financial-economics-network]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/breakout]]"
indicators:
  - "[[indicators/channel-breakout]]"
  - "[[indicators/atr-stop]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-19
g0_approval_reasoning: "Psaradellis-Laws-Pantelous-Sermpinis 2019 European Journal of Finance (SSRN 2832600 named-author URL) crude-oil Donchian channel breakout R1-R4 all PASS: 55D entry / 20D exit / 3xATR(20) stop deterministic, P3 bounded sweep {20,55,100}x{10,20,55}x{2.0,3.0,4.0}, XTIUSD.DWX native CFD port, no ML"
---

# Psaradellis Crude-Oil Channel Breakout

## Quelle
- Source: [[sources/ssrn-financial-economics-network]]
- URL: https://ssrn.com/abstract=2832600
- Named source authors: Ioannis Psaradellis, Jason Laws, Athanasios A. Pantelous, and Georgios Sermpinis, "Performance of Technical Trading Rules: Evidence from the Crude Oil Market" (European Journal of Finance, 2019).
- Location: SSRN abstract states that the paper applies the Sullivan et al. technical-rule universe to WTI crude oil and USO, including filter rules, moving averages, support/resistance rules, channel breakouts, and on-balance-volume averages.

## Mechanik

### Entry
1. Trade `XTIUSD.DWX` on D1.
2. Compute Donchian-style channel high/low from the prior 55 D1 bars.
3. If flat and `Close > highest_high(55)[1]`, open LONG at next D1 open.
4. If flat and `Close < lowest_low(55)[1]`, open SHORT at next D1 open.

### Exit
- Close LONG if `Close < lowest_low(20)[1]`.
- Close SHORT if `Close > highest_high(20)[1]`.
- Reverse only after the D1 close confirms the opposite 55-bar breakout.

### Stop Loss
- Hard stop at `3.0 * ATR(D1, 20)`.
- Optional trailing stop at `2.5 * ATR(D1, 20)` after trade reaches `+2R`.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` USD.
- Live: `RISK_PERCENT = 0.25`.

### Zusätzliche Filter
- Require 120 D1 bars before first signal.
- P3 sweep: entry channel `{20, 55, 100}`, exit channel `{10, 20, 55}`, ATR stop `{2.0, 3.0, 4.0}`.
- Note: source's empirical conclusion is cautious; this card tests the oil-specific channel-breakout family, not an assumed guaranteed edge.

## Concepts (was ist das für eine Strategie)
- [[concepts/trend-following]] - primary
- [[concepts/breakout]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | UNKNOWN | Verifiable SSRN URL, named university authors, and peer-reviewed European Journal of Finance publication. |
| R2 Mechanical | UNKNOWN | Channel breakout, channel exit, ATR stop, sizing, and sweeps are deterministic. |
| R3 Data Available | UNKNOWN | WTI/USO source ports directly to `XTIUSD.DWX` crude-oil CFD. |
| R4 ML Forbidden | UNKNOWN | Fixed technical rule; no ML, online learning, grid, martingale, or PnL-adaptive parameter changes. |

## Pipeline-Verlauf
- G0: 2026-05-18, PENDING, awaiting QB verdict.

## Verwandte Strategien
- [[strategies/QM5_1217_zarattini-donchian-ensemble]] - multi-market Donchian ensemble, not oil-specific.
- [[strategies/QM5_1157_plastun-oil-autumn]] - crude-oil seasonality rather than breakout trend.

## Lessons Learned (während Pipeline-Lauf)
- (noch keine)

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Änderung `pipeline_phase` aktualisieren + `last_updated`.*
