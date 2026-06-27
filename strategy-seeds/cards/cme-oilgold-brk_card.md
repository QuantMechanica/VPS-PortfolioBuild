---
ea_id: QM5_12605
slug: cme-oilgold-brk
type: strategy
source_id: CME-OIL-GOLD-RATIO-2024
source_citation: "CME Group. Through the Lens of Gold. 2024. URL https://www.cmegroup.com/articles/2024/through-the-lens-of-gold.html"
sources:
  - "[[sources/CME-OIL-GOLD-RATIO-2024]]"
concepts:
  - "[[concepts/oil-gold-ratio]]"
  - "[[concepts/market-neutral-basket]]"
indicators:
  - "[[indicators/donchian-channel]]"
  - "[[indicators/atr]]"
strategy_type_flags: [pair-spread-breakout, market-neutral-basket, atr-hard-stop, channel-exit, low-frequency]
target_symbols: [XTIUSD.DWX, XAUUSD.DWX]
logical_symbol: QM5_12605_XTI_XAU_BRK_D1
period: D1
expected_trade_frequency: "D1 oil/gold ratio channel-breakout basket; estimate 4-10 spread packages/year."
expected_trades_per_year_per_symbol: 7
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-06-27
g0_approval_reasoning: "R1 PASS CME exchange source; R2 PASS deterministic D1 oil/gold ratio breakout and channel exit; R3 PASS XTIUSD.DWX and XAUUSD.DWX available; R4 PASS no ML/grid/martingale/external data."
expected_pf: 1.12
expected_dd_pct: 20.0
---

# CME Oil/Gold Ratio Breakout

See `strategy-seeds/cards/approved/QM5_12605_cme-oilgold-brk_card.md` for the
canonical approved card body.
