# Build-gate hardening for the 2026-08-21 review cohort

Date: 2026-08-21
Router task: `19aa9da2-d916-4358-b583-7ae5a6c8e41b`
Scope: mechanical pre-review checks only; no EA, setfile, registry, queue, terminal,
or pipeline verdict was changed.

## Result

`build_gate_hardening.py`, which is already called by scoped
`build_check.ps1 -EALabel`, now has four additional fail-loud checks:

- `EA_Q08_MAE_HOOK_MISSING`: framework-managed `OnTick` lacks the explicit current-
  template `QM_FrameworkTrackOpenPositionMae()` lifecycle hook.
- `EA_ENTRY_DOUBLE_NEW_BAR_GATE`: two top-level `if` conditions consume the same
  `QM_IsNewBar` key before a canonical entry call, allowing the first call to starve the
  second permanently.
- `EA_TRADE_REQUEST_UNINITIALIZED`: a bare `MqlTradeRequest` reaches `OrderSend`, or a
  bare `QM_EntryRequest` reaches entry without zero-init or a mechanically complete
  seven-field initializer.
- `EA_INDICATOR_BUFFER_UNBOUNDED`: a dynamic numeric/`CopyBuffer` target is indexed
  without a loop bound tied to its resize/count, a `CopyBuffer` result check, or an
  explicit `ArraySize` guard.

Each check has a passing and failing fixture. The fixtures also cover cached new-bar
results, a properly zeroed `MqlTradeRequest`, a fully initialized `QM_EntryRequest`,
braced and braceless bounded loops, resize-count aliases, `ArraySize`, and checked
`CopyBuffer` results.

## Exact failed-review cohort rerun

Every command used the production wrapper with an exact `-EALabel`; `-SkipCompile` was
set, so no MetaEditor/terminal process was started. The remaining skip switches isolate
this static hardening layer from unrelated gates.

| EA | New pre-review result | Mechanical catches |
|---|---|---|
| QM5_12612 | FAIL | missing MAE hook |
| QM5_12920 | FAIL | missing MAE hook |
| QM5_12921 | PASS | none — rejected-card authority, January-bar selection, and symbol scope remain reviewer questions |
| QM5_12922 | PASS | none — restart reconstruction and news-deferral state semantics remain reviewer questions |
| QM5_12939 | FAIL | missing MAE hook; duplicate same-key new-bar gate; incomplete entry request (`expiration_seconds`) |
| QM5_12940 | FAIL | missing MAE hook; duplicate same-key new-bar gate; incomplete entry request (`expiration_seconds`); unbounded `k1[s]` access |
| QM5_12943 | FAIL | missing MAE hook |
| QM5_12944 | FAIL | missing MAE hook |

Thus **6 of the 8 review failures now stop before review**. The two intentional passes are
the semantic/card class the task explicitly reserved for human review.

As a calibration check, QM5_12923, QM5_12927, QM5_12928, and QM5_12938 produce no D7-D10
failure. Two other rows that had been approved in the 14-build closeout, QM5_12924 and
QM5_12925, do lack the explicit current-template MAE hook and are now caught by D7; this
is the same objective lifecycle requirement, not a widened semantic heuristic. Their
existing task states were not altered.

## False-positive boundary

- D7 applies only when a parsed `OnTick` is demonstrably framework-managed.
- D8 requires two same-key, top-level `QM_IsNewBar` calls in `if` conditions before an
  entry anchor. Cached results, different symbol/timeframe keys, and nested branch-local
  calls do not match.
- D9 accepts zero-init/aggregate-init and accepts a `QM_EntryRequest` initializer that
  assigns all seven contract fields. It does not guess that an arbitrary helper fully
  initializes `MqlTradeRequest`.
- D10 does no broad symbolic execution. It accepts exact resize/count bounds, one-level
  constant aliases, safe additive capacity, braceless loops, `ArraySize`, and checked
  `CopyBuffer` counts; it fails only when those local proofs are absent.

## Verification

- `python -m pytest tools/strategy_farm/tests/test_build_gate_hardening.py -q`
  -> `12 passed in 91.33s`.
- `python -m py_compile tools/strategy_farm/build_gate_hardening.py` -> PASS.
- `git diff --check` on implementation, tests, and this evidence -> PASS.
- Eight scoped production-wrapper reruns: six expected FAIL, two expected PASS, matching
  the table above.

## Deliberate non-coverage

These static gates do **not** decide whether an exit, entry rule, symbol universe,
calendar transition, or other strategy mechanic matches the Strategy Card. Card
divergence remains a Codex reviewer responsibility. A clean D7-D10 result is not a card-
fidelity verdict and must never be represented as one.
