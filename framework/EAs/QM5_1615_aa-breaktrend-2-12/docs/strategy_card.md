---
ea_id: QM5_1615
slug: aa-breaktrend-2-12
expected_trades_per_year_per_symbol: 12
type: strategy
source_id: ede348b4-0fa7-5be1-baa8-09e9089b67b7
sources:
  - "[[sources/alpha-architect-blog]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/time-series-momentum]]"
indicators:
  - "[[indicators/momentum]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-19
g0_approval_reasoning: "R1 source URL/title present; R2 fixed 2/12-month momentum entry and monthly flip/flat exit; R3 testable on DWX CFDs incl SP500.DWX backtest-only with T6 caveat; R4 fixed non-ML one-position rules."
---

# Alpha Architect Breaking-Bad-Trends 2-12 Momentum Blend

## Quelle
- Source: [[sources/alpha-architect-blog]]
- Page / Timestamp: Larry Swedroe, "Breaking Bad Momentum Trends", 2024-03-15, https://alphaarchitect.com/momentum-trends/

## Mechanik

Swedroe summarizes Goulding, Harvey, and Mazzoleni's framework that partitions return history into Bull, Correction, Bear, and Rebound states using agreement or disagreement between slow and fast momentum signals. This draft uses fixed two-month and 12-month signals and a non-adaptive state map: fast signal after Rebound, slow signal after Correction, and the common sign when the signals agree.

### Entry
- Evaluate on the final completed MN1 bar.
- Compute `Slow = sign(Close(1) / Close(13) - 1)` using 12-month trailing return.
- Compute `Fast = sign(Close(1) / Close(3) - 1)` using 2-month trailing return.
- State map:
  - Bull: `Slow > 0` and `Fast > 0`; target long.
  - Bear: `Slow < 0` and `Fast < 0`; target short.
  - Correction: `Slow > 0` and `Fast < 0`; target long using the slow signal.
  - Rebound: `Slow < 0` and `Fast > 0`; target long using the fast signal.
- Open or flip to the target direction at monthly rebalance.
- Baseline DWX symbols: SP500.DWX, NDX.DWX, WS30.DWX, GDAXI.DWX, XAUUSD.DWX, USOIL.DWX, EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX.

### Exit
- Rebalance monthly.
- Close or reverse when the target direction changes.
- Flat if either momentum signal is exactly zero.

### Stop Loss
- Initial SL = 3.0 x ATR(20,D1).
- Time stop: monthly target flip.

### Position Sizing
- P2-baseline: `RISK_FIXED = 1000`.
- T6-live: `RISK_PERCENT = 0.5`.

### Zusätzliche Filter
- One position per symbol/magic.
- Minimum 15 completed monthly bars.
- Skip new entries when D1 spread exceeds 2.5 x 20-day median spread.

## Concepts (was ist das für eine Strategie)
- [[concepts/trend-following]] - primary
- [[concepts/time-series-momentum]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Full Alpha Architect URL with named author Larry Swedroe and publication date. |
| R2 Mechanical | PASS | Fixed 2-month/12-month momentum state rules and deterministic monthly target direction. |
| R3 Data Available | PASS | Uses only OHLC-derived monthly returns on DWX CFDs; SP500.DWX caveat below. |
| R4 ML Forbidden | PASS | Fixed state map and lookbacks; no online optimization, no adaptive parameter selection, no grid or martingale. |

## R3
Source summarizes futures and equity-index trend-following evidence. DWX port applies the same two-horizon state rule to index, commodity, gold, and FX CFDs.

Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Pipeline-Verlauf
- G0: PENDING (Batch 11 draft 2026-05-19)
- P1: -
- P2: -

## Verwandte Strategien
- [[strategies/QM5_1601_aa-tsrev-double]] - related trend/reversal combination.
- [[strategies/QM5_1588_aa-tsmom-vol12]] - related time-series momentum card.

## Lessons Learned (während Pipeline-Lauf)
- TBD
