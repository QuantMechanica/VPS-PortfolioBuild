# DL-036 Checklist - QM5_1017 chan-pairs-stat-arb

- timestamp_utc: 2026-05-05T17:15:12Z
- compile_pass: True
- errors_zero: True
- warnings_zero: True
- compile_log: C:\QM\repo\framework\build\compile\20260501_090243\QM5_1017_chan_pairs_stat_arb.compile.log
- card_ref: strategy-seeds/cards/chan-pairs-stat-arb_card.md
- review_gate: DL-036
- state: CTO_CONFIRMATION_COMPLETE
- cto_confirmation_utc: 2026-05-05T21:14:00Z
- cto_confirmation: Card §7/§12 two-slot-per-pair convention confirmed for QM5_1017.
- cto_evidence:
  - card: strategy-seeds/cards/chan-pairs-stat-arb_card.md (§7 Trade Management Rules; §12 hard_rules_at_risk one_position_per_magic_symbol)
  - ea_impl: framework/EAs/QM5_1017_chan_pairs_stat_arb/QM5_1017_chan_pairs_stat_arb.mq5 (qm_magic_slot_offset leg-1, slot+1 leg-2 at lines 10, 45-46)
  - registry_formula: framework/registry/magic_numbers.csv + framework/include/QM/QM_MagicResolver.mqh (magic = ea_id * 10000 + symbol_slot)
  - zero_trade_adr_count: decisions/*_zero_trade_QM5_1017_<SYMBOL>.md = 36 files present
- heartbeat_2026-05-05T21:00Z_ceo_redirect_ack: confirmed no gap between Card §7/§12 requirement and implementation; two-slot-per-pair is ratified via slot N + slot N+1 convention for ea_id 1017.

