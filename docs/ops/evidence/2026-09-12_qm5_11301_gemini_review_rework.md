# QM5_11301 Gemini build review rework

Date: 2026-09-12  
Router review task: `efe9876c-ca5d-4405-ae94-65d804e3c715`  
Source build task: `90e1e59d-24cf-4c64-9564-9c78fa247021`  
EA: `QM5_11301_tc-m5-macd1-stoch-ema5-open-close`  
Disposition: REVIEW — defects repaired; governed compile queued and activation-held

## Review of the Gemini artifact

The original build artifact claimed build/compile PASS but used `smoke_result: "deferred"` with no smoke report or explicit governed deferral reason. That is not the accepted smoke taxonomy (`passed`, evidence-backed failure, or `deferred_p2_smoke` under the applicable governed path). It therefore cannot support Q02 admission or an approval.

The prior review's SPEC finding reproduced exactly: the generated SPEC lacked all seven mandatory sections and the `**EA ID:** QM5_NNNN` declaration.

The MQ5 source was reviewed against the approved card. It implements the four closed-bar M5 entry conditions, next-bar submission, 20-pip stop, opposite EMA-close/open crossover exit, approved two-symbol universe, single-position constraint, framework trade-manager calls, and mandatory framework news controls. It contains no raw `OrderSend`, martingale, grid, or ML. The reviewed source is intentionally byte-unchanged at SHA-256 `5a4b0e87cb4c7f4f84b1928bb9ac31fc54827aa8f64f427e96a6bd563905151e`.

## Repair

- Replaced the incomplete SPEC with the canonical seven-section card-fidelity contract (`c6dd93914b`).
- Added Codex-owned tests for source mechanics/guardrails, fixed-risk setfiles, registered magic slots, timeframe, and SPEC structure.
- Registered an exact-source, compile-only authority (`e223cc6c5b`); it grants no smoke, Q02, pipeline, live, or cross-EA permission.

The original build result remains immutable. Its honest successor disposition is `smoke_result: deferred_p2_smoke` with reason `compile_only_rework_has_no_q01_authority`; this is a deferral, not a smoke PASS.

## Verification

- `python -m pytest -q framework/EAs/QM5_11301_tc-m5-macd1-stoch-ema5-open-close/docs/test_qm5_11301_review_rework.py` -> 3 passed.
- `python framework/scripts/validate_spec_doc.py framework/EAs/QM5_11301_tc-m5-macd1-stoch-ema5-open-close` -> PASS.
- Focused compile source-repair tests -> 4 passed.
- Both backtest sets use `RISK_FIXED=1000`, `RISK_PERCENT=0`; magic slots 0/1 match active registry rows 113010000/113010001.

## Governed compile

`farmctl enqueue-compile` accepted work item `a47ea7ad-8731-443c-8c40-9b1c86b0737f` under authority `router_review_ea:efe9876c-ca5d-4405-ae94-65d804e3c715:QM5_11301`.

It is pending under `COMPILE_EA_WORKER_ROLLOUT_PENDING`. The activation hold was not bypassed, so this review does not claim a fresh compile PASS. No Q01/Q02 task was enqueued and no pipeline verdict is asserted. The task remains in REVIEW for Claude+OWNER close-out after the governed worker consumes the compile item.

