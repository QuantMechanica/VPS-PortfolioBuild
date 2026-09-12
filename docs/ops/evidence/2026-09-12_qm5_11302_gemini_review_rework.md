# QM5_11302 Gemini build review rework

Date: 2026-09-12
Router review task: `dfc248dc-ce63-4b55-bbfb-1ff701db0d91`
Source build task: `5dc30880-b500-4eda-9cca-783b9c000fc6`
EA: `QM5_11302_tc-m5-bb-stoch-extreme-reversal`
Disposition: REVIEW — defects repaired; governed compile queued and activation-held

## Review of the Gemini artifact

The original build artifact claimed build/compile PASS but used `smoke_result: "deferred"` with no smoke report or governed deferral reason. That value is outside the accepted smoke taxonomy and cannot support Q02 admission or approval. The prior SPEC finding also reproduced: the generated SPEC lacked the seven mandatory sections and the `**EA ID:** QM5_NNNN` declaration.

The MQ5 source was reviewed against the approved card. It implements the closed-bar BB(20,2) breach, Stochastic(5,3,3) extreme, three-bar higher-high/lower-low trend test, following pullback candle, fixed 20-pip stop and 10-pip target, three-symbol universe, single-position constraint, framework trade-manager calls, and mandatory framework news controls. It contains no raw `OrderSend`, martingale, grid, or ML. The source is intentionally byte-unchanged at SHA-256 `f5d4a48ec06728e5cda79d1a08ebf9702d99dbacb67625ad77b9e8857eeb4863`.

## Repair and verification

- Replaced the incomplete SPEC with the canonical seven-section card-fidelity contract (`670bcaad55`).
- Added Codex-owned tests for mechanics/guardrails, fixed-risk setfiles, magic slots, timeframe, and SPEC structure.
- Registered exact-source compile-only authority (`30ea193712`); it grants no smoke, Q02, pipeline, live, or cross-EA permission.
- Focused EA tests: 3 passed.
- `validate_spec_doc.py`: PASS.
- Focused compile source-repair tests: 4 passed.
- All three backtest sets use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and slots 0–2.

The immutable original result is not rewritten. Its honest successor smoke disposition is `deferred_p2_smoke` with reason `compile_only_rework_has_no_q01_authority`; this is not a smoke PASS.

## Governed compile

`farmctl enqueue-compile` accepted work item `63571c00-38cb-4343-8d6d-22b597bb226c` under the review authority. It is pending under `COMPILE_EA_WORKER_ROLLOUT_PENDING`. The hold was not bypassed, no Q01/Q02 work was enqueued, and no historical pipeline verdict was altered.

RESULT: REVIEW_READY_SPEC_AND_SMOKE_SCHEMA_REPAIRED_COMPILE_ACTIVATION_HELD
