# QM5_20062 EURUSD Q03 NO_HISTORY recovery

Date: 2026-09-04 UTC / 2026-09-05 Europe/Berlin

Branch: `agents/board-advisor`

Status: one exact-binary, append-only Q03 infrastructure rerun is active as
work item `1d6de524-13e0-4bec-8c61-9b8836879840`. The scheduled fleet claimed
it on T6; this paced wake did not call dispatch or control a terminal.

## Selection and capacity

The fresh five-sample whole-host CPU window measured `63.68%`, `58.69%`,
`61.16%`, `60.79%`, and `39.26%`: average `56.72%`, maximum `63.68%`. Both
were strictly below the `97%` admission ceiling.

No collision-free eligible priority-1 diverse build remained. Rates and
lumber backlog cards fail R3, the uncompiled market-neutral rows already have
governed compile work pending, and the remaining unclaimed no-EX5 rows are WTI
variants. `QM5_20062_kats-eu-macisar / EURUSD.DWX / D1` was therefore the
highest-value priority-2 continuation. It is a low-frequency structural FX
strategy sourced from Markos Katsanos, *Intermarket Trading Strategies*
(Wiley, 2008), with approximately 12 expected trades per year and no ML.

## Diagnosis and immutable lineage

Q02 work item `36bfac85-63e2-46a7-9f35-8ae583252d2f` is immutable `PASS`.
Its Q03 successor `0108e4d5-2d2d-49e4-8458-5434dd8f34d4` is immutable
`INFRA_FAIL`, not an economic failure: its recorded reason is
`run_smoke_fail:NO_HISTORY;INCOMPLETE_RUNS`. The current MQ5, EX5, and setfile
hashes exactly match both sealed rows:

- MQ5: `c245bdc262f7d4c8ce0e70171ea852919765eb299a278eaab4b607c2a0b78424`
- EX5: `68d54999a025cb1b95692f0702055a4acc18c28061ce61087728c37c279994d2`
- setfile: `c4c05dbc0a377b27ed3cabe7465dbc5e130d03ec4dfcd2b2511b577db9877000`

The canonical backtest preset remains `RISK_FIXED=1000`, `RISK_PERCENT=0`,
and `PORTFOLIO_WEIGHT=1`. Immediately before the claim there were zero open
work items and zero open agent claims for the EA.

## Farm mutation

Agent task `02e733f4-e3e4-48a7-9477-d55704b7ef38` claimed the exact recovery
under key
`q03-infra-recovery:QM5_20062:0108e4d5-2d2d-49e4-8458-5434dd8f34d4`.
After a race recheck showed only that claim and no open work item, the
canonical `enqueue-backtest` path appended one Q03 successor. Farm event
`384540` records `q03_exact_identity_enqueued`.

The new row is gate-contract `v4`, `sh3_enforced=1`, priority-tracked, and
bound to the current MQ5/EX5/setfile hashes. It carries ACTIVE custom-history
archive admission for `EURUSD.DWX` and the full `2018-07-02` through
`2022-12-31` Q03 window. The two predecessor rows were not changed.

## Safety boundary

No EA source, binary, setfile, card, registry, resolver, gate criterion,
portfolio surface, deploy manifest, live manifest, T_Live state, or
AutoTrading setting changed. No manual dispatch, process action, worker action,
or terminal action was performed. Existing unrelated shared-worktree changes
were preserved and excluded from the commit.

Machine-readable evidence is in
`artifacts/diversity_funnel_qm5_20062_q03_infra_requeue_20260904T223342Z_board_advisor.json`.
