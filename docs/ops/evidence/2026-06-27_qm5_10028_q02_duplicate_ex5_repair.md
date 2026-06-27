# QM5_10028 Q02 Duplicate EX5 Repair

Date: 2026-06-27
Agent: codex-board-advisor
Branch: agents/board-advisor

## Scope

Repair one diverse, built-but-stuck Q02 candidate:

- EA: `QM5_10028_rw-risk-premia`
- Symbols requeued: `SP500.DWX`, `WS30.DWX`, `XTIUSD.DWX`
- Failure class: `INFRA_FAIL`
- Preflight reason: `duplicate_ex5`

## Diagnosis

Q02 preflight failed before consuming an MT5 slot because the EA directory contained two `.ex5` files:

- `QM5_10028_rw-risk-premia.ex5`
- `QM5_10028_rw-risk-premia_v2.ex5`

The worker preflight accepts only the canonical binary named after the EA directory. The stale `_v2` binary was removed from the active farm checkout, leaving only `QM5_10028_rw-risk-premia.ex5`.

## Validation

Static/build validation completed without running a tester smoke or backtest:

- `python framework/scripts/validate_spec_doc.py framework/EAs/QM5_10028_rw-risk-premia`: PASS
- `powershell -NoProfile -ExecutionPolicy Bypass -File framework/scripts/build_check.ps1 -EALabel QM5_10028_rw-risk-premia`: PASS
- Compile result inside `build_check`: PASS, 0 errors, 0 warnings

The compile refreshed the canonical `.ex5`, and `build_check` stamped the RISK_FIXED setfiles with concrete build hashes.

No Q02 smoke was launched from this repair because the MT5 dispatch pool was already near its active-worker ceiling.

## Farm DB Update

Claim recorded in `D:/QM/strategy_farm/state/farm_state.sqlite`:

- `manual_repair:QM5_10028:Q02:duplicate_ex5`

The following work items were reset from failed `INFRA_FAIL` to pending:

- `315bec58-b01d-4364-8cf5-680f9364b206` - `SP500.DWX`
- `4b46a26d-8e17-417b-911d-b09575f45e0d` - `WS30.DWX`
- `5f21669e-5100-4685-af4a-2edd749d2555` - `XTIUSD.DWX`

Each row now has `status='pending'`, `verdict=NULL`, `attempt_count=0`, `evidence_path=NULL`, and `claimed_by=NULL`.
