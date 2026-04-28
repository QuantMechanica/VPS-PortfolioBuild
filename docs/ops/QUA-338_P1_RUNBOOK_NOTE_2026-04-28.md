# QUA-338 P1 Runbook Note (Pre-Implementation)

Issue: QUA-338 (`SRC02_S01` chan-pairs-stat-arb)
Date: 2026-04-28

Purpose: pre-stage expected setfile/input field names for Pipeline-Operator P2/P3 once EA scaffold is unblocked and implemented.

## Status

- EA implementation is still blocked pending `ea_id` allocation for `SRC02_S01`.
- This note captures the intended parameter surface from the approved card so downstream P2/P3 wiring is deterministic.

## Expected Input Groups (V5)

- `QuantMechanica V5 Framework`
- `Risk`
- `News`
- `Friday Close` (default disabled for this strategy per approved waiver)
- `Strategy`

## Expected Strategy Inputs (Setfile Keys)

- `pair_symbol_1` (default candidate: `AUDUSD.DWX`)
- `pair_symbol_2` (default candidate: `NZDUSD.DWX`)
- `cadf_gate_enabled` (bool)
- `cointegration_significance` (double; card default 0.05)
- `training_lookback` (int; card default 252)
- `ols_hedge_lookback` (int; default align to `training_lookback` unless overridden)
- `entry_z` (double; card default 2.0)
- `exit_z` (double; card default 1.0)
- `ou_halflife_cap_days` (int; card default 30)
- `time_stop_multiplier` (double; card default 1.0)
- `allow_reversal_same_bar` (bool; expected false for initial scaffold)

## Pair/Magic Notes for Implementation

- EA must maintain two-leg notes explicitly in source comments:
  - primary leg magic slot = `qm_magic_slot_offset`
  - hedge leg magic slot = `qm_magic_slot_offset + 1`
- Both magics derive via `QM_Magic(qm_ea_id, slot)` only.
- No hand-computed magic constants.

## Next Action After Unblock

1. CTO/CEO allocate `ea_id` in `framework/registry/ea_id_registry.csv`.
2. Development implements `framework/EAs/QM5_<ea_id>_chan_pairs_stat_arb/QM5_<ea_id>_chan_pairs_stat_arb.mq5`.
3. Run strict compile (`framework/scripts/compile_one.ps1 -EAPath <mq5> -Strict`).
4. Post compile log + `.ex5` artifact paths for CTO review handoff.
