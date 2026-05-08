# ADR: Zero-Trade Allowance — QM5_1017 / AUDUSD.DWX

date: 2026-05-05
ea_id: QM5_1017
symbol: AUDUSD.DWX
phase_scope: P1 smoke (scaffold validation)
authority: DL-054 Gate 4 (per-symbol zero-trade ADR requirement)
related: QUA-750, framework/EAs/QM5_1017_chan_pairs_stat_arb/QM5_1017_chan_pairs_stat_arb.mq5

## Decision

For `QM5_1017` scaffold smoke on `AUDUSD.DWX`, a zero-trade outcome is expected and valid as a scaffold-stage result. This row must not be labeled `PASS`; it is a documented `ZERO_TRADE` outcome under DL-054 G4.

## Cause

- Entry path is intentionally inert in scaffold phase.
- In `Strategy_EntrySignal`, reason strings may be set but function returns `false` unconditionally (no order placement path enabled yet).
- Two-leg execution and synchronized position management are not wired in this scaffold revision.

## Evidence anchors

- EA source: `framework/EAs/QM5_1017_chan_pairs_stat_arb/QM5_1017_chan_pairs_stat_arb.mq5`
- Entry gate behavior: `Strategy_EntrySignal(...)` final `return false;`
- Lifecycle context: `framework/EAs/QM5_1017_chan_pairs_stat_arb/CHECKLIST.md` (`READY_FOR_CTO_REVIEW`)

## Boundaries

- This ADR is symbol-specific (`AUDUSD.DWX`) and does not auto-apply to other symbols.
- Future symbols require their own `decisions/<date>_zero_trade_QM5_1017_<symbol>.md` file if `trade_count=0`.
- When executable entry/exit legs are implemented, this ADR should be reviewed and retired if no longer applicable.
