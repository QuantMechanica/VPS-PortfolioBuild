# QM5_12507 FX cointegration Q02 CPU-ceiling stop

Recorded: 2026-09-05T13:33:45Z (15:33 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `05872bef7db1b8ad07898eb030c3b66d34ff77c5`

## Outcome

The concrete fallback pair is the existing `QM5_12507` EURUSD/GBPUSD H1
cointegration basket. Its unique logical Q02 remains correctly enqueued,
unclaimed, attempt zero, fixed-risk, and priority-marked. No duplicate row was
created and no tester was started because the explicit 97% host-CPU ceiling
bound during preflight: one of five one-second samples reached **99.903%**.

The frozen 66-pair scan remains fully represented by 123 approved identities
and 123 matching EA directories, with no approved unbuilt identity. The two
preferred anchors do not require Q02 repair: `QM5_12532` has logical Q02 PASS
and later Q04 PASS/Q05 FAIL, while `QM5_12533` has logical Q02 PASS and later
Q04 FAIL. A new card, build, or Q02 seed would therefore duplicate governed
work.

## Existing pair selected

- EA: `QM5_12507_pair-coint-z`
- Relationship: `EURUSD.DWX` / `GBPUSD.DWX`
- Logical symbol: `QM5_12507_EURUSD_GBPUSD_COINTEGRATION_H1`
- Q02 work item: `547c4fd3-f3fd-4c59-b9dc-654e96521251`
- State: pending, unclaimed, attempt zero, no verdict, no active hold
- Risk contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`
- Basket manifest: `framework/EAs/QM5_12507_pair-coint-z/basket_manifest.json`
- Observed canonical claim rank: 153 of 10,779 claimable rows

The governed claim-order head was `QM5_10718` and `QM5_10717`, both existing
priority Q02 baskets. An unrelated multi-symbol `QM5_10069` Q10_NEWS campaign
was active on T8, so basket serialization also remained in force. Reordering
or force-claiming 12507 would bypass the paced fleet.

## Capacity stop

Five one-second whole-host CPU samples were `99.903%`, `81.475%`, `83.314%`,
`86.629%`, and `94.704%` (average `89.205%`, maximum `99.903%`). Free physical
memory was 37.027 GB and eight work items were active. The maximum sample
crossed the mission's 97% hard ceiling, so preflight stopped before any queue
or terminal mutation.

No card, EA, registry, queue, priority, hold, claim, terminal, tester,
portfolio-admission, portfolio-KPI, Q08-contribution, portfolio-gate,
T_Live-manifest, live/deploy, or AutoTrading state was changed.

Machine-readable receipt:
`artifacts/fx_cointegration_qm5_12507_cpu_ceiling_stop_20260905T133345Z_board_advisor.json`.

## Resume contract

After CPU returns below 97% and the active multi-symbol lane clears, let the
ordinary paced worker consume the already-priority-bound logical Q02. Do not
append a duplicate or manually bypass canonical claim order.
