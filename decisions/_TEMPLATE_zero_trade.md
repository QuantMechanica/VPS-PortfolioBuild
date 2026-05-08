# ADR: Zero-Trade Allowance — <EA_ID> / <SYMBOL>

date: YYYY-MM-DD
ea_id: <EA_ID>
symbol: <SYMBOL>
phase_scope: <P1 smoke | P2 baseline | P3.5 | P5 | P6 | P7 | P8>
authority: DL-054 Gate 4 (per-symbol zero-trade ADR requirement)
related: <issue ids>, <EA source path>

## Decision

For `<EA_ID>` on `<SYMBOL>` in `<phase_scope>`, `trade_count=0` is accepted as `ZERO_TRADE` for this run context. This is not a `PASS`.

## Cause

- <strategy-level reason for zero trades>
- <why this is expected/known in this phase>
- <what is intentionally not wired or what market condition blocked fills>

## Evidence anchors

- Report path: `<D:/QM/reports/pipeline/.../report.htm>`
- Journal path: `<.../journal.log>`
- Source/config anchor: `<file + function/setting>`

## Boundaries

- ADR applies only to `<EA_ID>/<SYMBOL>` pair.
- Additional symbols require separate ADR files named:
  `decisions/<date>_zero_trade_<EA_ID>_<SYMBOL>.md`
- Remove or supersede this ADR once the zero-trade cause is resolved.
