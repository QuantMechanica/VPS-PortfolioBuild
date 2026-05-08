# ADR: Zero-Trade Allowance — QM5_1017 / NZDCHF.DWX

date: 2026-05-05
ea_id: QM5_1017
symbol: NZDCHF.DWX
phase_scope: P1/P2 scaffold validation
authority: DL-054 Gate 4 (per-symbol zero-trade ADR requirement)
related: QUA-750, framework/EAs/QM5_1017_chan_pairs_stat_arb/QM5_1017_chan_pairs_stat_arb.mq5

## Decision

For QM5_1017 on $s, zero trades are currently expected in scaffold-stage dispatches and must be classified as ZERO_TRADE (not PASS) under DL-054.

## Cause

- Strategy_EntrySignal(...) currently returns alse unconditionally.
- Two-leg synchronized execution/management is intentionally not wired in this scaffold revision.

## Evidence anchors

- Source: ramework/EAs/QM5_1017_chan_pairs_stat_arb/QM5_1017_chan_pairs_stat_arb.mq5
- Gate logic: ramework/scripts/dl054_gates.py (has_zero_trade_adr, gate4_trade_evidence)

## Boundaries

- Applies only to QM5_1017/NZDCHF.DWX.
- Remove or supersede after executable entry/exit path is implemented and validated.
