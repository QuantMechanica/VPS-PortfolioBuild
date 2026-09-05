# FX cointegration paced RAM-ceiling stop

Recorded: 2026-09-05T14:49:15Z (16:49 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `80a577273df55b6797d318f7034f06314cd57862`

## Outcome

No new Card or EA was created because the frozen 66-pair discovery frontier
remains fully represented. `QM5_12532` and `QM5_12533` both retain logical
basket Q02 PASS receipts and therefore have no current ONINIT or NO_HISTORY
repair priority.

The concrete existing fallback remains `QM5_12507` on the structural
EURUSD/GBPUSD H1 cointegration relationship. Its unique current logical Q02
row is already fixed-risk, priority-bound, pending, unclaimed, and attempt
zero. It ranked 147 in the canonical hold-filtered claim order. Appending a
second row or forcing this row ahead of the paced fleet would be duplicate or
out-of-order work.

The canonical claim-order leaders were the existing FX baskets `QM5_10718`
and `QM5_10717`. The drain ledger classifies the first row as requiring a
44 GB reservation plus the 14 GB floor. Only 28.469 GB of physical memory was
free after the fleet expanded to nine active work items, so no FX basket was
admissible during this wake. The head row remained pending and unclaimed after
one paced claim interval.

## Preserved Q02 binding

- EA: `QM5_12507_pair-coint-z`
- Relationship: `EURUSD.DWX` / `GBPUSD.DWX`
- Logical symbol: `QM5_12507_EURUSD_GBPUSD_COINTEGRATION_H1`
- Work item: `547c4fd3-f3fd-4c59-b9dc-654e96521251`
- State: pending, unclaimed, attempt zero, no verdict
- Risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`
- Manifest: `framework/EAs/QM5_12507_pair-coint-z/basket_manifest.json`

The source, binary, logical setfile, and manifest hashes are unchanged from
the authenticated Q01 PASS lineage. The Q01 receipt observed 632 leg trades.

## Capacity evidence

The final five one-second whole-host CPU samples were 79.592%, 79.299%,
74.845%, 80.189%, and 85.071% (average 79.799%, maximum 85.071%). The explicit
97% CPU ceiling did not bind. The binding condition was paced RAM admission:
28.469 GB free versus 58 GB required for the claim-order head.

Nine canonical work items were active. The existing `QM5_10069` Q10_NEWS run
still occupied the multi-symbol lane on T8 while eight other farm items were
active. No terminal, tester, worker, claim, queue, priority, hold, or verdict
state was changed.

This is a decision delta from the 13:33Z stop: host CPU recovered below the
hard ceiling, but the governed basket drain remained non-winnable on RAM as
the ordinary fleet filled additional slots. The paced fleet retains ownership
of `QM5_10718`, then `QM5_10717`, then the lower-ranked `QM5_12507` fallback.

## Safety

No portfolio-admission, portfolio-KPI, Q08-contribution, portfolio-gate,
T_Live-manifest, live/deploy, AutoTrading, Strategy Card, EA, registry,
setfile, basket manifest, or runtime queue state was changed.

Machine-readable companion:
`artifacts/fx_cointegration_paced_ram_ceiling_stop_20260905T144915Z_board_advisor.json`.
