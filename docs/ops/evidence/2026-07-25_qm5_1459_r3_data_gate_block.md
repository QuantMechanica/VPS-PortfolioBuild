# QM5_1459 R3 data-gate block

- Date: 2026-07-25
- Agent: `codex:agents/board-advisor`
- Farm task: `08cfd80b-c78c-4527-9143-e650cdc847d1`
- EA: `QM5_1459_as-lumber-gold`
- Result: `BLOCKED`
- Reason code: `r3_missing_lumber_and_ief_dwx_series`

## Decision

The pending build was atomically claimed and changed from `pending` to
`blocked` in `D:\QM\strategy_farm\state\farm_state.sqlite`. No EA was built,
compiled, smoked, or enqueued.

The approved frontmatter is not sufficient for a faithful build because the
card's mechanical rule requires both:

1. generic front-month lumber to compute the 13-week lumber-versus-gold signal;
2. IEF (or an approved intermediate-US-Treasury equivalent) as the defensive
   allocation leg.

Neither lumber nor an IEF/Treasury proxy is present in
`framework/registry/dwx_symbol_matrix.csv`. The card itself records R3 as
`UNKNOWN` and explicitly says those two series require approved external or
custom-symbol data. Substituting an available commodity or equity series would
change the approved strategy mechanics.

## Repository state

- `framework/registry/ea_id_registry.csv` already contains the active
  `1459,as-lumber-gold` identity row.
- No `QM5_1459` rows exist in `framework/registry/magic_numbers.csv`.
- `framework/EAs/QM5_1459_as-lumber-gold/QM5_1459_as-lumber-gold.mq5` is an
  existing inert skeleton whose entry hook always returns `false`.
- No `.ex5`, setfile, or Q02 work item was created by this unit.

## Unblock condition

Research/OWNER must provide validated, registry-approved `.DWX` history for the
lumber signal and Treasury allocation leg, or approve a revised card with
explicit mechanical substitutes. The normal build process can then reserve
magic rows, implement the card, compile, and enqueue Q02.

## Safety

No backtest CPU was consumed. `T_Live`, AutoTrading, the portfolio gate, and
the live manifest were not touched.
