# QM5_38005 governed compile and Q02 handoff — 2026-08-29

## Scope

- Router task: `827e3846-438c-4a12-b33a-ba44838037c7`
- Bound build task: `4a54ac9e-165c-4e32-bfd3-f1f94dd9d886`
- EA: `QM5_38005_codetrading-ascending-triangle-breakout`
- Approved card:
  `D:/QM/strategy_farm/artifacts/cards_approved/QM5_38005_codetrading-ascending-triangle-breakout.md`
- Requested operation: governed compile, smoke, and Q02 handoff

## Build preflight

- The card has `g0_status: APPROVED`, `ml_required: false`, H1, and the
  authorized symbols `XAUUSD.DWX`, `SP500.DWX`, and `EURUSD.DWX`.
- `framework/registry/ea_id_registry.csv` has the one active identity row for
  EA ID `38005` and the exact slug.
- `framework/registry/magic_numbers.csv` has active slots 0/1/2 for the three
  card symbols, with magic values `380050000` through `380050002`.
- The canonical MQ5 SHA-256 is
  `060403f50d18d840643941c251bf80a89a0e752b2f56be56dfb6de3e8dfece1f`.
- All three backtest presets retain `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `qm_news_stale_max_hours` remains capped at `336` in the EA source.

## Governed compile result

The build task correctly enqueued COMPILE_EA work item
`8f538072-156a-4b46-9f5f-5004711e1048`. T10 claimed it at
`2026-08-29T11:45:36Z`. During that attempt the governed worker generated the
three hash-bound setfiles and wrote the EX5 at `2026-08-29T11:46:08Z`, but the
worker then hit `database is locked` and returned the row to pending at
`2026-08-29T11:47:59Z` before it could persist a COMPILE_OK receipt.

T2 reclaimed the same row at `2026-08-29T12:00:36Z`. Its mandatory candidate
recheck refused the partial predecessor side effects:

```text
CANDIDATE_RECHECK_REFUSED:EX5_ALREADY_PRESENT;BOUND_SETFILE_HASH_EXISTS
```

The immutable failure evidence is:
`D:/QM/reports/work_items/8f538072-156a-4b46-9f5f-5004711e1048/QM5_38005/COMPILE_EA/compile_evidence.json`.
The row is `failed/COMPILE_FAIL`, `no_gate_verdict=true`, and its evidence names
no compile result or build-check result. The present binary SHA-256 is
`d12d8e3ad7e164f60d2441e106c6aba5fd08688c2d20651805469ae7011130d9`,
but it is not admissible because no governed COMPILE_EA receipt binds that
binary to the source hash.

## Verification

- `validate_build_guardrails.py`: PASS, four files checked, no findings,
  maximum news staleness `336` hours.
- `validate_spec_doc.py`: PASS (1/1).
- `validate_symbol_scope.py --fail-on-leak`: PASS, zero violations.
- `build_gate_hardening.py`: PASS, one source scanned, zero failures and zero
  warnings; all three card symbols are registry-exact.
- Focused EA, setfile-generator, magic-resolver, governed-allocator, and
  host-slot suites: **22 passed**.

These static checks do not replace the missing governed compile receipt and do
not constitute a pipeline verdict.

## Disposition and recovery boundary

`REVIEW_REQUIRED — GOVERNED_COMPILE_RECEIPT_MISSING`.

No Q01 smoke or Q02 work was dispatched. The build skill forbids treating an
unreceipted binary as compile PASS, and Q02 cannot be handed off safely until a
fresh governed COMPILE_EA successor records `COMPILE_OK` for the exact MQ5 and
EX5 hashes.

Recovery must be append-only and evidence-bound to work item
`8f538072-156a-4b46-9f5f-5004711e1048`: preserve the failed row and evidence,
authorize one governed retry that recognizes only its own partial generated
setfiles/EX5 after the SQLite-busy defer, then require a normal COMPILE_OK
receipt before any smoke or Q02 enqueue. Do not delete the binary, clear the
setfile hashes, waive candidate checks, or infer a pipeline verdict from the
static PASS results.

No terminal, AutoTrading setting, live deployment state, active backtest, gate
criterion, or card mechanic was changed during this handoff.
