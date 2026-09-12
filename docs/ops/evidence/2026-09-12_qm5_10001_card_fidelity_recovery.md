# QM5_10001 card-fidelity recovery

Date: 2026-09-12  
Router task: `27143c34-0501-41b4-82cf-bab05cd82edc`  
EA: `QM5_10001_ff-static-fib-open`  
Disposition: REVIEW — source repaired and governed compile queued; activation remains held

## Evidence and first failed layer

The task diagnosis cited four July Q02 infrastructure failures. A later governed run exists:

- work item `f7a8275f-55d7-5dc2-b62e-464f3330de89`
- `GBPJPY.DWX`, M15, Model 4, 2022-07-01 through 2022-12-31
- evidence: `D:/QM/reports/work_items/f7a8275f-55d7-5dc2-b62e-464f3330de89/QM5_10001/20260907_122512/summary.json`
- valid completed report, stable artifact hashes, successful initialization and news checks
- verdict `ZERO_TRADES`; 165 strategy events, with no entry-attempt or entry-rejection telemetry

This moves the first failed layer from tester infrastructure to implementation/setup. No strategy mechanic was changed to manufacture trades.

## Approved-card fidelity repair

The approved card is `D:/QM/strategy_farm/artifacts/cards_approved/QM5_10001_ff-static-fib-open.md` (`g0_status: APPROVED`). It specifies Tokyo-open static Fibonacci entry mechanics, ATR/trend/momentum filters, risk and the news blackout, but no maximum-spread veto.

The implementation applied a card-absent 35-point maximum-spread filter at the Tokyo-open entry instant. That veto was removed. The repair also adds:

- an own-position guard to prevent a second same-EA position;
- bounded, default-off `ENTRY_ATTEMPT`, `ENTRY_REJECT`, and `ENTRY_SIGNAL` diagnostics for a future governed run.

Entry levels, exits, indicator thresholds, risk, news blackout, and trading horizon are unchanged. `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `qm_news_stale_max_hours=336` remain intact.

Source repair commit: `92aa0abbc7`  
Repaired source SHA-256: `efef85059bb3bb7fd89c32d34bd1ff8868e34a197e9c7125554d711b6c417aa5`

## Verification

- `python -m pytest -q framework/EAs/QM5_10001_ff-static-fib-open/docs/test_static_fib_open_card_fidelity.py` -> 3 passed.
- `python framework/scripts/validate_spec_doc.py framework/EAs/QM5_10001_ff-static-fib-open` -> PASS.
- An ad-hoc `build_check.ps1` attempt was refused by `LIVE_FACTORY_AD_HOC_COMPILE_REFUSED`; no ad-hoc compilation occurred.
- The compile source-repair registration's focused test selection passed 4/4. The full compile-work-item module reached 90/91; its sole failure is the separately assigned PRESCREEN SH-3 fixture mismatch and is not caused by this registration.

## Governed compile disposition

The immutable compile-only authority is `docs/ops/evidence/2026-09-12_qm5_10001_source_repair_authority.json`, registered by commit `4b26908a7a`.

`farmctl enqueue-compile` accepted the exact repaired source under authority `router_q02_infra_repair:27143c34-0501-41b4-82cf-bab05cd82edc:QM5_10001` and created work item `d979e50c-9fe4-4f1b-b85c-4a8d6e823546`.

Current state is `pending` with activation hold `COMPILE_EA_WORKER_ROLLOUT_PENDING`. The hold was not bypassed or released. The existing EX5 and bound setfiles remain unchanged until a governed compile worker is activated.

## Scope and open items

No Q02 work was enqueued: QM5_10001 remains in the requeue-exclusion policy, and this task supplies no authority to change that policy. No pipeline verdict is asserted. No terminal was started or interrupted; T_Live and AutoTrading were not touched.

OPEN ITEMS:

1. The governed COMPILE_EA rollout owner must activate/consume work item `d979e50c-9fe4-4f1b-b85c-4a8d6e823546`.
2. After compile PASS, the OWNER must decide whether to remove the explicit Q02 requeue exclusion and authorize a fresh Model-4 diagnostic run.

