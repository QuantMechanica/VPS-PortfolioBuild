---
ea_id: QM5_12742
slug: nnfx-configurable-engine
type: strategy
source_id: nnfx-vp-canonical-2026-06-12
sources:
  - "[[sources/no-nonsense-forex]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/indicator-stack-confirmation]]"
  - "[[concepts/atr-risk]]"
indicators:
  - "[[indicators/supertrend]]"
  - "[[indicators/ssl-channel]]"
  - "[[indicators/aroon]]"
  - "[[indicators/schaff-trend-cycle]]"
  - "[[indicators/qqe]]"
  - "[[indicators/fisher-transform]]"
  - "[[indicators/hull-ma]]"
  - "[[indicators/atr]]"
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "VP / No Nonsense Forex published algorithm (same canonical source as QM5_12534). This is a systematic combo-search engine over the V5-LEGAL NNFX component pool, not a new edge claim."
r2_mechanical: PASS
r2_reasoning: "Deterministic engine: each NNFX slot (baseline/C1/C2/volume/exit) selected by an input enum from the legal component pool; entry window + ATR proximity gate tunable; closed-bar D1/H4. No optimization-in-EA."
r3_data_available: PASS
r3_reasoning: ".DWX D1/H4 history for FX majors + gold/silver/indices/energy; no external data."
r4_ml_forbidden: PASS
r4_reasoning: "Fixed-parameter indicator selection; no ML, no in-EA optimization, no martingale; ATR-bounded risk."
pipeline_phase: G0
expected_trades_per_year_per_symbol: 25
expected_pf: 1.30
expected_dd_pct: 12
last_updated: 2026-06-28
g0_approval_reasoning: "G0 2026-06-28 Claude (OWNER hypothesis: single-pair NNFX is not dead; the right combination was never tested). The NNFX audit found only a small number of full-stack builds were tested out of a large legal combo space, and that cadence starvation can be a full-stack AND-gate artifact rather than intrinsic to the indicators. This engine systematically tests the under-explored lean-combo space, prioritizing cost-friendly instruments. Decisive gates are Q04 walk-forward, then Q08 cost/edge quality."
---

# NNFX Configurable Engine (systematic legal-combo search)

## Purpose

One parameterized NNFX EA whose every slot is selectable by input enum, so setfile grids can sweep the V5-legal combo space. It tests the OWNER hypothesis that leaner, faster NNFX combinations may survive where prior strict baseline+C1+C2+volume full stacks starved cadence.

## Build spec

Generalize prior NNFX full-stack entry logic into selectable slots. Reuse existing legal components where available:

- `nnfx_baseline`: KIJUN, HMA, T3, ALMA, MCGINLEY, ZLSMA, EMA.
- `nnfx_c1`: SUPERTREND, SSL, AROON, VORTEX, STC, QQE, FISHER.
- `nnfx_c2`: OFF, VORTEX, AROON, TRIX.
- `nnfx_volume`: ATR_EXPANSION, ADX_RISING, CMF, WAE.
- `nnfx_exit`: PSAR, C1_FLIP, KIJUN_RECROSS, CHANDELIER.
- `nnfx_entry_window_bars`: default 7.
- `nnfx_proximity_atr_mult`: default 1.0.
- Stop: 1.5 ATR.
- Partial: half close at 1 ATR, then breakeven.
- Default timeframe: D1; H4 allowed by input.

## Grid plan

Cadence-prioritized corner: baseline in HMA, ZLSMA, T3, ALMA; C1 in STC, QQE, FISHER, SUPERTREND, AROON; volume in ATR_EXPANSION, ADX_RISING; exit in PSAR, C1_FLIP; C2 OFF.

Instruments: XAUUSD, XAGUSD, NDX, SP500, GDAXI, WS30, XTIUSD, XNGUSD first, then EURUSD, GBPUSD, USDJPY, AUDUSD. Target cadence is 15-40 trades per year per symbol.

## Acceptance

Q02 gross plus trade floor, then Q04 walk-forward, then Q08 cost and edge quality. The certified book is mean-reversion heavy, so any surviving NNFX trend combo is a high-value uncorrelated diversifier.
