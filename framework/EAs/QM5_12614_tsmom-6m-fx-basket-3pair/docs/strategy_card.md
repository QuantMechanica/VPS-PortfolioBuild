---
ea_id: QM5_12614
slug: tsmom-6m-fx-basket-3pair
type: strategy
source_id: e5a3f925-5a9e-513d-9e70-5c7c70fa0e59
sources:
  - "[[sources/aqr-moskowitz-ooi-pedersen-time-series-momentum-2012]]"
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX]
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/basket-diversification]]"
  - "[[concepts/equal-vol-weighting]]"
  - "[[concepts/trend-following]]"
indicators:
  - "[[indicators/lookback-return]]"
  - "[[indicators/realized-volatility]]"
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Single source_id (e5a3f925) referencing Moskowitz-Ooi-Pedersen JFE 2012 with direct AQR URL; no secondary sources claimed."
r2_mechanical: PASS
r2_reasoning: "Entry is sign(close_pair[0] > close_pair[126]) per slot with 20-day rolling vol weighting; monthly trigger; 3 bounded magic slots; fully deterministic."
r3_data_available: PASS
r3_reasoning: "EURUSD.DWX, GBPUSD.DWX, and USDJPY.DWX are all live-tradable Darwinex instruments."
r4_ml_forbidden: PASS
r4_reasoning: "Rolling stddev vol-scaling is price-history only (not PnL-adaptive); three magic numbers enforce 1-position-per-magic; no martingale."
pipeline_phase: G0
expected_trades_per_year_per_symbol: 8
last_updated: 2026-06-29
g0_approval_reasoning: "R1 PASS single MOP/JFE source_id+URL; R2 PASS deterministic monthly 126D return-sign per FX slot with ATR stop and 3 bounded magics, basket cadence supports >=2 trades/yr/slot; R3 PASS EURUSD/GBPUSD/USDJPY.DWX; R4 PASS no ML/PnL-adaptive sizing/martingale."
expected_pf: 1.15
expected_dd_pct: 22.0
---

# TSMOM 6-Month Sign Momentum — FX 3-Pair Basket (EURUSD + GBPUSD + USDJPY)

## Quelle

- Source: [[sources/aqr-moskowitz-ooi-pedersen-time-series-momentum-2012]]
- Paper: Moskowitz, Ooi & Pedersen (2012). "Time series momentum." *Journal of Financial
  Economics*, 104(2), 228–250.
- URI: https://www.aqr.com/insights/research/journal-article/time-series-momentum
- Key reference: Section III — TSMOM at h=6 months; Section IV — diversification across
  multiple FX instruments dramatically increases Sharpe ratio.

## Mechanik

The 6-month intermediate lookback window is tested in the paper and shows strong significance
across FX pairs (Table 2). Applying this to 3 distinct major FX pairs with independent equal-vol
weighting captures the paper's core finding that diversification across multiple TSMOM positions
is the primary source of portfolio-level edge. Each pair runs as an independent slot within a
single EA (3 magic numbers), allowing the framework to track and risk-manage each position
independently.

Target symbols: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX.

### Entry

On first bar of each calendar month, for each of the 3 FX pairs (EURUSD, GBPUSD, USDJPY):

```
lookback_bars = 126    // D1 bars ≈ 6 months
vol_window    = 20     // 20-day trailing vol for slot sizing

// Per-slot signal
signal[pair] = close_pair[0] > close_pair[lookback_bars] ? +1 : -1

// Per-slot sizing: equal volatility contribution
// realized_vol[pair] = stddev(log returns, 20 bars) × sqrt(252)
// pair_lot = base_lot × (target_pair_vol / realized_vol[pair])
// where target_pair_vol = 0.10 / 3 ≈ 0.033 (each pair targets 1/3 of total risk)
// Cap pair_lot scaling at 2.0×
```

Magic number allocation (1-pos-per-magic):
- Slot 1: EURUSD → magic = ea_id × 10000 + 1
- Slot 2: GBPUSD → magic = ea_id × 10000 + 2
- Slot 3: USDJPY → magic = ea_id × 10000 + 3

Each slot independently opened/closed based on its own signal.

### Exit

Monthly rebalance per slot. Hard SL applies per slot intra-month.

### Stop Loss

Per slot, ATR-based: SL = entry_price ± ATR(14, D1) × 3.0.
Applied independently per pair at each slot's entry price.

### Position Sizing

RISK_FIXED = $1000 for backtest baseline (total across all active slots).
Per-slot: risk_per_slot = RISK_FIXED / active_slots. With 3 slots always active: risk = $333/slot.
Vol-scaling applied per slot using the 20-day realized vol to weight slot sizes toward
lower-vol pairs (equal risk contribution).

### Zusätzliche Filter

- Monthly trigger: `Month(Time[0]) != Month(Time[1])`
- Each slot checked independently at the monthly trigger
- News filter: standard QM news-blackout per active slot pair
- Spread filter per pair: skip entry if spread > 3× median spread for that pair

## Basket EA Notes

This is a multi-symbol basket EA. Per current factory policy, multi-symbol EAs are
serialized to ≤1 active in the farm at a time (claim_atomic registry). This does not
affect the strategy's correctness — only throughput time to backtest. Codex should
implement with 3 independent slot-management loops, one per pair.

## Concepts

- [[concepts/time-series-momentum]] — primary; 6-month lookback variant
- [[concepts/basket-diversification]] — secondary; independent per-pair signals
- [[concepts/equal-vol-weighting]] — sizing to equalize risk contribution per pair
- [[concepts/trend-following]] — tertiary

## R1–R4 Bewertung

| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Named AQR authors, peer-reviewed JFE 2012, direct URL |
| R2 Mechanical | PASS | Fully mechanical: sign(close[0] vs close[126]) per pair; 3-slot basket; vol-equal sizing |
| R3 Data Available | PASS | EURUSD, GBPUSD, USDJPY all live-tradable DWX instruments at Darwinex |
| R4 ML Forbidden | PASS | Deterministic; rolling stddev indicator only; 3 positions bounded by 3 slots; no martingale |

## Pipeline-Verlauf

- G0: 2026-06-27, PENDING — drafted from MOP (2012) Section III & IV, batch 1

## Verwandte Strategien

- [[strategies/QM5_12611_tsmom-12m-fx-sign-eurusd]] — 12m signal on single EURUSD (no basket)
- [[strategies/QM5_12615_tsmom-12m-cross-asset-basket]] — cross-asset basket with 12m signal

## Trade Frequency Note

Per slot (pair): ~8 direction-change events/year at 6-month lookback.
Across 3 pairs total: ~24 signal events/year, but positions are independent so factory
throughput counts each pair's test individually. Expected_trades_per_year_per_symbol: 8.

## Commission Risk

FX commission at DXZ is high (~$45/trade per QM cost model 2026-06-26). Monthly rebalancing
(~8 trades/year/pair) partially compensates. This card is at HIGHER commission risk than
the index/commodity cards — Q04 will stress this net. The diversification benefit from 3
uncorrelated pairs is the key thesis: EURUSD+GBPUSD+USDJPY have different dollar, euro,
and sterling dynamics that reduce correlation even when all are "trending."

## Lessons Learned

*(populate during pipeline runs)*
