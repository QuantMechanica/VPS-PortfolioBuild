---
ea_id: QM5_13206
slug: ftmo-account-governor
type: risk_controller
source_id: FTMO-RUNTIME-GOVERNOR-V2
source_citation: "FTMO, Trading Objectives (FTMO Challenge: 2-Step) and How do I withdraw my reward?, official pages retrieved 2026-07-17"
target_symbols: [ACCOUNT_WIDE]
period: TIMER_200MS
expected_trades_per_year_per_symbol: 0
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: BUILD_TEST
last_updated: 2026-07-17
g0_approval_reasoning: "OWNER-authorized safety-controller build and delegated technical release. V2 adds exact signed Phase-1, Verification, and Funded policies for the 100k FTMO 2-Step book. Compile and T1-T5 fault testing only; deployment remains fail-closed behind client wiring, parity, bootstrap reconciliation, and an OWNER-signed manifest."
---

# FTMO 2-Step Account Governor V2

## Scope

No-trade account-wide risk controller for the 100,000 USD FTMO 2-Step lifecycle. It implements challenge-bound persistent state, Europe/Prague day boundaries, central entry locks, target capture for both evaluation phases, risk scaling, and retrying liquidation for an exact signed magic whitelist. It does not create alpha and grants no strategy deployment right.

## Official source contract

Official FTMO pages retrieved 2026-07-17:

- Trading Objectives: https://ftmo.com/en/trading-objectives/
- Reward timing: https://ftmo.com/en/faq/how-do-i-withdraw-my-profits/

For FTMO Challenge: 2-Step, the official page specifies 10% Phase-1 and 5% Verification targets, 5% Maximum Daily Loss calculated from the 00:00 CE(S)T balance, 10% static Maximum Loss, four Trading Days in each evaluation phase, and no time limit. The Reward page states that a claim can be requested on the 14th or a later day after the first trade on the specific FTMO Account, with positions and pending orders closed.

## Immutable policies

Only these exact allowlisted IDs are accepted:

- `FTMO_2S_P1_100K_V2`
- `FTMO_2S_P2_100K_V2`
- `FTMO_2S_FUNDED_100K_V2`

Each has its own embedded fingerprint. The signed deploy manifest must provide the exact ID; an empty, misspelled, or mutated policy fails initialization. Official 5%/10% thresholds remain encoded, while the book deliberately uses tighter internal entry, liquidation, and total-loss limits.

## Mechanical contract

- Dry-run, invalid-account, empty-policy, and missing-state defaults fail closed.
- Persistent state is namespaced under the V2 state prefix; V1 state cannot be reused.
- Lock is durable before order deletion or position-close operations.
- Foreign magics are never modified and make every wired client fail closed.
- Seqlock client heartbeat, singleton lease, and policy-fingerprint mismatch fail closed.
- Phase 1 and Verification capture the target only when equity reaches it and complete only when balance is at target, the governed account is flat, and four opening days are recorded.
- Funded mode has no profit target or minimum-day objective and never target-locks.
- No ML, online adaptation, martingale, grid, discretionary input, or freely configurable loss limit.

## Release boundary

Build and T1-T5 integration testing are approved. Paid-Challenge or FTMO-Account deployment is not approved until every launched sleeve consumes the V2 client snapshot, the four-day completion edge case is signed off, MQL/Python golden parity and T1-T5 fault tests pass, the bootstrap is independently reconciled, and an OWNER-signed deploy manifest exists. Agents do not toggle AutoTrading.
