# QM5_12538 GBPJPY D1 Q02 requalification

Date: 2026-08-22
Branch: `agents/board-advisor`
Farm claim: `agent_tasks.id=1c0783e8-0307-4c16-9873-d168e9c83f34`

## Outcome

One append-only Q02 work item was created for the unexercised repaired-binary
lane `QM5_12538_nnfx-canonical-stack2-st-vortex` / `GBPJPY.DWX` / `D1`:

- new work item: `c55771f5-41d7-4a11-b059-aa8cb1724359`
- state at handoff: `pending`
- enqueue path: `farmctl.seed-fresh-q02`
- historical source row preserved: `03d67e34-bad7-4d80-91a9-255f2b5aa133`
- source verdict: `INFRA_FAIL`
- source reason: `run_smoke_fail:NO_HISTORY;INCOMPLETE_RUNS`
- source evidence: `D:\QM\reports\work_items\03d67e34-bad7-4d80-91a9-255f2b5aa133\QM5_12538\20260626_065450\summary.json`

This is a diversity/funnel-throughput unit, not a new build. The approved card
is a nine-pair, closed-bar D1 FX trend sleeve sourced from the public No
Nonsense Forex methodology and community-vetted fixed components. It has R1-R4
PASS, fixed parameters, and no ML, optimizer, grid, or martingale mechanics.
GBPJPY is an authorized card symbol with active registry slot 8 / magic
`125380008`.

## Non-duplicate basis

Commit `ceb93147596d5b90836935bf23287fd6fd385d9e` repaired the recurrent Q02
`ACTIVE_TIMEOUT` implementation defect by caching the unchanged D1 indicator
state once per completed bar. That repair preserved the card mechanics and
passed strict compile and build checks, but its paced-fleet turn stopped at the
CPU ceiling before broad FX requalification.

The repaired EX5 subsequently received Q02 observations on EURUSD and EURJPY.
No GBPJPY work item was bound to the repaired EX5 before this enqueue; the
GBPJPY history consisted only of infrastructure outcomes against predecessor
builds. The new row therefore exercises a distinct instrument lane without
duplicating a current-binary test.

## Immutable execution identity

| Artifact | SHA-256 / value |
| --- | --- |
| MQ5 | `061a979cb6fc1ac5f681b7faeb82c686fab29643e304ffd4d44f4d280a8bcaf2` |
| EX5 | `0157749c0fc7e8ead324238468b2489b45b641f32e5a2b24be25dff300f4cd20` |
| GBPJPY D1 setfile | `5826fe906bc47b8b4a99aa9fb32f1fe3a69fb0d6e0f906f7766b5bcff52f05e1` |
| Expert | `QM\QM5_12538_nnfx-canonical-stack2-st-vortex` |
| Symbol / period | `GBPJPY.DWX` / `D1` |
| Test window | `2018.07.02` - `2024.12.31` |
| Risk | `RISK_FIXED=1000`, `RISK_PERCENT=0` |

The public identity-binding command required the current canonical EX5 hash and
recorded the current MQ5, EX5, setfile, symbol, period, dates, and fixed-risk
inputs in the new work-item payload. No source, binary, setfile, threshold,
registry, or framework file changed in this turn.

## Capacity and safety

The immediate pre-enqueue check observed one test terminal/metatester and five
CPU samples averaging 75.48%, below the prior paced-fleet stop observations of
88.7% and 97.94%. The command only appended the pending row; it did not launch a
tester manually.

No T_Live or FTMO process was stopped or modified. AutoTrading, the portfolio
gate, the T_Live manifest, and deploy manifests were not touched.

## Next deterministic action

The normal farm pump may claim work item
`c55771f5-41d7-4a11-b059-aa8cb1724359`. Its eventual Q02 report is the first
valid evidence for the repaired binary on GBPJPY and remains subject to the
ordinary economic gate; this enqueue is not a strategy PASS.
