---
ea_id: QM5_13089
slug: xti-xng-carry
type: strategy
strategy_id: KOIJEN-CARRY-2018_XTI_XNG_S03
source_id: KOIJEN-CARRY-2018
source_citation: "Koijen, R. S. J., Moskowitz, T. J., Pedersen, L. H. and Vrugt, E. B. (2018). Carry. Journal of Financial Economics, 127(2), 197-225. DOI https://doi.org/10.1016/j.jfineco.2017.11.002; NBER working paper https://www.nber.org/papers/w19325."
source_citations:
  - "Koijen, R. S. J., Moskowitz, T. J., Pedersen, L. H. and Vrugt, E. B. (2018). Carry. Journal of Financial Economics, 127(2), 197-225."
sources:
  - "[[sources/KOIJEN-CARRY-2018]]"
concepts:
  - "[[concepts/carry]]"
  - "[[concepts/energy-relative-carry]]"
indicators:
  - "[[indicators/broker-swap]]"
  - "[[indicators/rolling-return]]"
  - "[[indicators/atr]]"
strategy_type_flags: [market-neutral-basket, carry-ranking, energy-relative-value, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
primary_target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
markets: [commodities, energy]
timeframes: [D1]
logical_symbol: QM5_13089_XTI_XNG_CARRY_D1
single_symbol_only: false
period: D1
expected_trade_frequency: "Weekly XTI/XNG carry-spread package; estimate 30-52 paired entries/year after weekday, spread, carry, adverse-drift, and framework filters."
expected_trades_per_year_per_symbol: 42
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-09
expected_pf: 1.08
expected_dd_pct: 20.0
risk_class: high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [friday_close, magic_schema, risk_mode_dual]
g0_approval_reasoning: "R1 PASS peer-reviewed carry source; R2 PASS deterministic cross-energy broker-swap carry ranking, 12M adverse-return guard, weekly D1 rebalance, ATR hard stops, time exit, and carry-rank flip exit; R3 PASS XTIUSD.DWX and XNGUSD.DWX available in the V5/DWX universe; R4 PASS no ML/grid/martingale/external runtime data."
---

# XTI/XNG D1 Carry Spread

See `artifacts/cards_approved/QM5_13089_xti-xng-carry.md` and
`framework/EAs/QM5_13089_xti-xng-carry/docs/strategy_card.md` for the approved
card body, implementation notes, Q01 evidence, and Q02 queue status.

