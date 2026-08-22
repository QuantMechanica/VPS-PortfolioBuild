# OWNER-DEC-GATECONTRACT implementation evidence

- Date: 2026-08-22
- Router task: `d31e82d9-ad50-4829-a826-ad938c753115`
- Branch: `agents/board-advisor`
- Scope: Q01 smoke waiver, Q08 fixed-parameter N/A, Q10 recency cohort

## Delivered contracts

### Q01

`farmctl._q01_smoke_admission` now admits Q02 only after a real Q01 smoke PASS
or a `deferred_p2_smoke` record carrying explicit tester-fleet saturation
evidence. Missing smoke data, generic headless/framework deferrals, and
unsupported outcomes fail closed. Zero trades remain blocking. The admission
basis is copied into each created Q02 payload for auditability.

The schema plus build and review prompts use the same narrow wording.

Decision: `decisions/2026-08-22_q01_smoke_saturation_waiver.md`.

### Q08

The existing fixed-parameter behavior is ratified without code or threshold
change. Q08.5/Q08.7 `NOT_APPLICABLE` requires authoritative structural proof,
stays sub-gate-only and non-punitive, and cannot override a computed failure.

Decision: `decisions/2026-08-22_q08_fixed_parameter_not_applicable.md`.

### Q10

The recency policy switch is enabled with an automatic cohort boundary at
`work_items.created_at >= 2026-09-01T00:00:00Z`. `farmctl` transports that
immutable timestamp to the runner and refuses a Q10 command without it.
Pre-cutoff rows remain shadow-only.

For post-cutoff base PASS rows, trailing-24-month PF below 1.0 or half-vs-half
decline at or above 40% produces Q10 FAIL. Insufficient evidence remains
`UNKNOWN` and a window older than nine months becomes `STALE_WINDOW`; both keep
the base verdict but set a deployment blocker. No historical row is regraded.

Decision: `decisions/2026-08-22_q10_recency_cohort_activation.md`.

## Documentation closure

`docs/ops/GATE_CONTRACTS_2026-08-22.md` is the current repository mirror. The
matrix artifact `2026-08-21_gate_decision_doc_code_test_matrix_draft.md` is now
marked ratified and binds each contested point to its decision, documentation,
code, and tests. The G: Company Reference Vault was unavailable to this headless
session, so no Vault file was mutated or inferred.

## Focused verification

```text
python -m pytest -q \
  tools/strategy_farm/tests/test_zero_trade_prevention.py \
  tools/strategy_farm/tests/test_p2_full_dwx_fanout.py \
  tools/strategy_farm/tests/test_basket_work_items.py \
  tools/strategy_farm/tests/test_dwx_history_range_filter.py \
  framework/scripts/tests/test_q08_davey_subgates.py \
  framework/scripts/tests/test_q10_recency.py \
  framework/scripts/tests/test_q10_confirmation.py \
  tools/strategy_farm/tests/test_phase_runner_process_lineage.py

191 passed in 14.02s
```

No terminal, backtest, live-trading control, gate threshold, or pipeline row was
changed by this task.
