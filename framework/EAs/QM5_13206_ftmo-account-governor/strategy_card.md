---
ea_id: QM5_13206
slug: ftmo-account-governor
type: risk_controller
source_id: FTMO-RUNTIME-GOVERNOR-V1
source_citation: "FTMO, Trading Objectives, 2-Step rules, https://ftmo.com/en/trading-objectives/, retrieved 2026-07-13"
target_symbols: [ACCOUNT_WIDE]
period: TIMER_200MS
expected_trades_per_year_per_symbol: 0
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: BUILD_TEST
last_updated: 2026-07-13
g0_approval_reasoning: "OWNER-authorized safety controller build. Approval permits compile and T1-T5 testing only; deploy remains fail-closed behind account, whitelist, client-wiring, parity, and signed-manifest gates."
---

# FTMO Account Governor

## Scope

No-trade risk controller for a dedicated FTMO 2-Step account. It implements a
central entry lock, equity-room scaling, Prague-day state, and retrying
liquidation for a signed magic whitelist. It does not create alpha and does not
grant any strategy deployment right.

## Mechanical Contract

- Dry-run and invalid-account defaults.
- Persistent account/policy-scoped state.
- Lock is durable before order operations.
- Foreign magics are excluded.
- Client heartbeat and policy mismatch fail closed.
- No ML, adaptation, martingale, grid, or discretionary input.

## Release Boundary

Build and T1-T5 integration testing are approved. Paid-Challenge deployment is
not approved until the book itself is strict-gate ready and the deploy package
is OWNER-signed.
