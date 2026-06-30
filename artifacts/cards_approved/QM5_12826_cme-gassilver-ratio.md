---
ea_id: QM5_12826
slug: cme-gassilver-ratio
type: strategy
source_id: CME-GAS-SILVER-RELVAL-2026
source_citation: "CME Group. Henry Hub Natural Gas Futures Overview. URL https://www.cmegroup.com/markets/energy/natural-gas/natural-gas.html; CME Group. Silver Futures Overview. URL https://www.cmegroup.com/markets/metals/precious/silver.html"
sources:
  - "[[sources/CME-GAS-SILVER-RELVAL-2026]]"
concepts:
  - "[[concepts/natural-gas-silver-ratio]]"
  - "[[concepts/market-neutral-basket]]"
indicators:
  - "[[indicators/zscore]]"
  - "[[indicators/atr]]"
strategy_type_flags: [pair-spread-zscore, market-neutral-basket, atr-hard-stop, mean-reversion-exit, low-frequency]
target_symbols: [XNGUSD.DWX, XAGUSD.DWX]
logical_symbol: QM5_12826_XNG_XAG_RATIO_D1
period: D1
expected_trade_frequency: "D1 natural-gas/silver ratio z-score basket; estimate 5-10 spread packages/year."
expected_trades_per_year_per_symbol: 7
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-06-30
g0_approval_reasoning: "R1 PASS CME exchange product source packet for Henry Hub Natural Gas and Silver futures; R2 PASS deterministic D1 natural-gas/silver log-ratio z-score basket with ATR stops and mean-reversion exit; R3 PASS XNGUSD.DWX and XAGUSD.DWX available; R4 PASS no ML/grid/martingale/external runtime data."
expected_pf: 1.10
expected_dd_pct: 22.0
---

# CME Natural Gas / Silver Ratio Reversion

See `strategy-seeds/cards/cme-gassilver-ratio_card.md` for the canonical card.
