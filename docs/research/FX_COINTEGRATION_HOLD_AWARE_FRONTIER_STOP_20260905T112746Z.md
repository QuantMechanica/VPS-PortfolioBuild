# FX cointegration hold-aware frontier stop

Recorded: 2026-09-05T11:27:46Z (13:27 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `8a483f555864abd7204c882e0127a1e2ac636528`

## Outcome

No new card, EA, basket manifest, registry row, or Q02 row was created. The
frozen 66-pair discovery frontier is already fully represented, and both
preferred anchors have later logical-basket Q02 PASS receipts. The one apparent
manifest omission, `QM5_13020`, is intentionally single-symbol under its
approved card and SPEC, so converting it into a basket would change the
strategy and duplicate the exhausted single-symbol funnel.

The non-duplicate fallback is the already-open `QM5_12507` EURUSD/GBPUSD H1
cointegration basket. Its unique logical Q02 remains pending, unclaimed, attempt
zero, priority-tagged, basket-manifest-bound, and fixed-risk. It is already the
governed continuation; appending or force-claiming another row would not advance
the funnel safely.

## Hold-aware correction

The current state corrects the runnable classification in the 06:35 UTC paced
audit. `QM5_12778` work item
`24acc5d4-3e34-526e-a7a8-12640a2e759f` still has
`q09_activation_state=RUNNABLE_BOUND` in its payload, but that field is not the
claimability authority. `work_item_holds` has an active
`NEWS_CALENDAR_TIMESTAMP_DEFECT` hold, updated at
2026-09-05T06:28:12Z, and the canonical claim-order query excludes the row.
The hold says to wait for the calendar repair. It was not released.

This matters operationally: auditing only the raw work-item row can label a
held campaign runnable. For dispatch decisions, the canonical hold-filtered
claim order is authoritative.

## Concrete existing fallback

`QM5_12507` is scan rank 24 across both signs and trades the structural
EURUSD/GBPUSD relationship. Its current state is:

- logical symbol `QM5_12507_EURUSD_GBPUSD_COINTEGRATION_H1`;
- Q02 work item `547c4fd3-f3fd-4c59-b9dc-654e96521251`;
- pending, unclaimed, attempt zero, canonical claim-order rank 141;
- `priority_track=true` from the governed 2026-08-30 handoff;
- prior authenticated Q01 PASS with 632 observed leg trades;
- `RISK_FIXED=1000`, `RISK_PERCENT=0`;
- basket manifest `framework/EAs/QM5_12507_pair-coint-z/basket_manifest.json`.

The claim-order head currently contains the fresh Q02 seeds for the broader
existing FX baskets `QM5_10718` and `QM5_10717`. Rewriting the 12507 payload to
masquerade as a fresh requalification seed would falsify lineage. Direct
terminal targeting while the factory owns the queue would bypass the paced
fleet.

## Capacity and safety

Five one-second whole-host CPU samples were `81.446%`, `79.900%`, `83.134%`,
`80.487%`, and `75.444%` (average `80.082%`, maximum `83.134%`). The explicit
97% ceiling did not bind. Seven active work items were observed; factory
terminal processes were present on T3, T4, T6, and T9, with ten terminal worker
slots alive. The slot audit found no duplicate workers or orphan terminal
processes.

No queue, hold, priority, claim, terminal, tester, portfolio-admission,
portfolio-KPI, Q08-contribution, portfolio-gate, T_Live-manifest, live/deploy,
or AutoTrading state was changed. Unrelated dirty-worktree changes were
preserved.

The ordinary paced fleet retains ownership of the existing 12507 Q02. Revisit
12778 only after the governed news-calendar repair is published and the exact
hold is explicitly released. Do not infer claimability from a payload field and
do not enqueue a duplicate.

Machine-readable companion:
`artifacts/fx_cointegration_hold_aware_frontier_stop_20260905T112746Z_board_advisor.json`.
