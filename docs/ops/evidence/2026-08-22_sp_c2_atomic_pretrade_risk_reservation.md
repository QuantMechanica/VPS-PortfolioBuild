# SP-C2 atomic pre-trade account-risk reservation — implementation evidence

Date: 2026-08-22  
Router task: `d735bcd5-10d5-4a08-be95-d0d70d7d778b`  
Disposition: `IMPLEMENTED_FOR_REVIEW`; live activation remains OWNER-blocked

## Code-slot adjudication

The task's cited
`tools/strategy_farm/config/target_rulepacks/FTMO_2S_100K_SWING_V1.json`
line 458 is a deployment-boundary marker:

```text
"runtime_integration": "NOT_IMPLEMENTED"
```

It is not a risk-budget execution slot. The file was inspected read-only,
remains Git-clean, and currently hashes to
`c7c8cc5312552576dd6af118599d5404e68b9e279a9be679dcba8021ec4b8686`.
Its 2.5% total-open-stop-risk guardrail remains
`PROPOSED_FOR_CALIBRATION`.

The real common send boundary is
`framework/include/QM/QM_TradeContext.mqh`. It is the only
`OrderSend(...)` owner under `framework/include/QM`, so standard entries,
basket entries, and grid entries cannot bypass the new reservation while using
the framework.

## Implemented contract

`QM_AccountRiskReservation.mqh` adds a fail-closed account/challenge-scoped
critical section:

1. A terminal-global compare-and-swap lease serializes exposure-opening
   requests before the first broker submission.
2. While holding the lease, the code enumerates every `PositionsTotal()` /
   `PositionGetTicket()` row and every `OrdersTotal()` / `OrderGetTicket()` row.
   There is no magic-number inclusion filter: manual and foreign-magic exposure
   counts.
3. Remaining position risk is repriced from current mark to the actual broker
   SL with `OrderCalcProfit`; pending-order and proposed-order risk use entry to
   actual SL. Missing/invalid stops, unpriceable symbols, inventory count drift,
   configuration drift, or a busy lease reject the new order.
4. Pending orders are treated as already reserved exposure. Market requests
   add the allowed-deviation price movement conservatively before calculating
   proposed risk.
5. The lease is held across synchronous `OrderSend` and both governed transient
   retry branches. It is released only after the send path resolves. A crash
   leaves a conservative 120-second fail-closed lease; the successor rescans
   broker truth before admitting another request.
6. A projection over the bound money cap emits
   `ACCOUNT_RISK_ORDER_BLOCKED` / `ACCOUNT_RISK_OVER_BUDGET` with existing,
   requested, projected, and cap money values. Accepted reservations emit
   `ACCOUNT_RISK_ORDER_RESERVED`. Entry and basket callers preserve the distinct
   account-risk rejection class rather than mislabelling it as a broker error.

Risk-reducing closes, partial closes, and pending-order removals remain outside
the entry reservation so a busy/uncertain budget can never prevent exposure
reduction.

The atomicity boundary is all compliant EAs in one MT5 terminal. A future
deploy manifest must bind the FTMO challenge to exactly one execution terminal;
cross-host or multi-terminal trading on the same login is not authorized by
this implementation.

## Activation boundary

The feature is integrated but dormant by default. A V3 runtime contract can
activate it only when all of the following are true:

- target is FTMO and the existing account governor is required;
- policy ID is exactly `FTMO_2S_100K_OPEN_STOP_RISK_V1`;
- a syntactically valid policy SHA-256 is bound;
- account anchor is exactly USD 100,000;
- cap is positive and no greater than 2.5%;
- `account_stop_risk_owner_ratified=true`; and
- runtime sizing is `RISK_PERCENT` outside the tester.

Tester activation or `RISK_FIXED` activation fails initialization. Legacy and
existing V3 contracts default to `account_stop_risk_reservation_required=false`.
Therefore this change does not ratify the proposed 2.5% number, alter a setfile,
or activate anything on a live account. OWNER must ratify/hash-bind the policy
and separately authorize any compile/deploy ceremony.

## Three-EA evidence and edge coverage

The deterministic oracle artifact is
`docs/ops/evidence/2026-08-22_sp_c2_three_ea_reservation.jsonl`. It is explicitly
labelled `DETERMINISTIC_UNIT_ORACLE_NOT_LIVE`:

```text
EA_1: existing 0 + request 1000 = 1000 <= 2500 -> RESERVED
EA_2: existing 1000 + request 1000 = 2000 <= 2500 -> RESERVED
EA_3: existing 2000 + request 1000 = 3000 > 2500 -> BLOCKED
```

An actual three-thread barrier test starts the three intents concurrently and
proves exactly two accept, exactly one receives `ACCOUNT_RISK_OVER_BUDGET`, and
retained exposure never exceeds the cap. Additional unit cases prove:

- aggregation includes magic `0`, unregistered magic `999`, positions, and
  pending orders;
- an order ending exactly at USD 2,500 is allowed and the next USD 0.01 is
  rejected;
- an uncovered/unpriced position blocks rather than contributing zero; and
- a broker-rejected order releases its lease/reservation, so no phantom risk is
  retained.

## Focused verification

```text
python -m pytest -q tools/strategy_farm/tests/test_account_risk_reservation.py -p no:cacheprovider
9 passed in 0.55s

python -m pytest -q \
  tools/strategy_farm/tests/test_entry_execution_policy_static.py \
  tools/strategy_farm/tests/test_basket_order_helper_static.py \
  -p no:cacheprovider
16 passed, 2 subtests passed in 0.68s

python -m pytest -q <five directly relevant runtime-contract tests> \
  tools/strategy_farm/tests/test_ftmo_governor_wiring.py \
  -p no:cacheprovider
11 passed in 0.74s

rg -n "\\bOrderSend\\s*\\(" framework/include/QM -g "*.mqh"
only QM_TradeContext.mqh (initial send plus two governed retry sites)

git diff --check -- <SP-C2 explicit pathspecs>
PASS (line-ending notices only)
```

No MetaTrader terminal, MetaEditor, live order, setfile, T_Live, or AutoTrading
state was touched. No pipeline verdict is claimed. Because compile/deploy is a
separate governed OWNER step and the numeric policy is still unratified, this
artifact remains in REVIEW.
