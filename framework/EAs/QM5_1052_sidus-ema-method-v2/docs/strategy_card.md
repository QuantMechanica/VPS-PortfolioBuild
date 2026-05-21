---
ea_id: QM5_1052
slug: sidus-ema-method-v2
type: strategy
source_id: 6e967762-b26d-59a3-b076-35c17f2e7c36
sources:
  - "[[sources/forexfactory-trading-systems]]"
concepts:
  - "[[concepts/moving-average-crossover]]"
  - "[[concepts/trend-following]]"
indicators:
  - "[[indicators/ema]]"
  - "[[indicators/wma]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-16
g0_approval_reasoning: "ForexFactory Sidus method v2 (named handle + Sidus_method_v.2.mq4 indicator file) R1-R4 all PASS — WMA cross gated by EMA tunnel, FX majors, fixed periods no ML"
expected_trades_per_year_per_symbol: 500
---

# QM5_1052 Sidus Method v2 (4-EMA / WMA Confluence)

## Quelle
- Primary: ForexFactory Trading Systems forum — "Sidus method v2" by user
  `Sidus`. The Sidus indicator and method circulated heavily on FF and was
  later mirrored on BabyPips and earlystart's MT4 indicator archive.
- URL: https://www.forexfactory.com/ — search "Sidus method" in the Trading
  Systems subforum (forum 71). The associated MT4 indicator file is
  `Sidus method v.2.mq4`, an artifact of the original FF thread.
- Author: FF handle `Sidus` (anonymous handle, but specific named identity on
  FF with attributable post history — R1 PASS under relaxed criteria).

## Mechanik

The Sidus method uses two EMA pairs as a "tunnel" plus a short-term WMA cross
for trigger:

- Slow tunnel: EMA(18), EMA(28)
- Fast trigger: WMA(5), WMA(8)
- Reference: LWMA(50) for higher-TF bias (optional).

### Entry
- LONG: ALL of
  1. WMA(5) crosses ABOVE WMA(8) on most recent closed bar
  2. WMA(5) AND WMA(8) both ABOVE EMA(18) AND EMA(28) tunnel at signal bar
  3. EMA(18) ABOVE EMA(28) (slow-tunnel is in uptrend)
- SHORT: mirror.

### Exit
- Reverse signal: opposite-direction WMA(5)/WMA(8) cross closes the position.
- Optional fixed take-profit at Risk:Reward 1.5 (P3 sweep target).

### Stop Loss
- Initial SL: opposite side of EMA(28) with `SL_Buffer_Points` buffer
  (default 20 pts).
- Alternative for P3 sweep: ATR(14) × 1.5.

### Position Sizing
- `RISK_FIXED = $1000` for P2 (HR4).
- `RISK_PERCENT = 0.5%` for live.

### Filters
- Spread cap 20 pts.
- Session filter (P3 sweep): London + NY overlap.
- News filter hook (off by default in P2).

## Concepts
- [[concepts/moving-average-crossover]] — primary
- [[concepts/trend-following]] — secondary

## R1–R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Specific FF handle (`Sidus`), specific named strategy with archived indicator file (`Sidus method v.2.mq4`). Per relaxed 2026-05-15 R1: anonymous-but-named FF handles with linked source pass. |
| R2 Mechanisch | PASS | Entry rule = WMA(5)/WMA(8) cross gated by EMA(18)/EMA(28) tunnel position. Exit = reverse cross. Unambiguous; Codex fills SL/sizing defaults. |
| R3 DWX-testbar | PASS | FX-major-favored. P2 basket: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, AUDUSD.DWX, EURJPY.DWX. |
| R4 No ML | PASS | Fixed-period MAs only, no ML, no adaptive params, no grid. 1-pos-per-magic compatible. |

All four PASS expected — G0 APPROVE eligible.

## Pipeline-Verlauf
- G0: 2026-05-16 — drafted from ForexFactory batch 2

## Implementation Notes for Codex (P1)
- DWX symbols for P2: **EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, AUDUSD.DWX,
  EURJPY.DWX** (5 majors).
- Timeframe: H1 default (Sidus thread shows H1/H4 working best). M30 alt.
- Detect WMA cross via prior-bar relative position (no per-tick scan):
  `wma5[1] <= wma8[1] && wma5[0] > wma8[0]` for bullish cross at bar open.
- All MA reads via `iMA` with `MODE_LWMA` / `MODE_EMA` buffers, cached.

## Verwandte Strategien
- Adjacent: any EMA-tunnel system (e.g. Vegas Tunnel QM5_1053).
- Differentiator: Sidus uses 4 MAs (tunnel + trigger) vs Vegas's 2-EMA tunnel.

## Lessons Learned (während Pipeline-Lauf)
- *(populated as pipeline progresses)*
