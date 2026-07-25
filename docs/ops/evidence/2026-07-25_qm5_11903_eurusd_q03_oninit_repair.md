# QM5_11903 EURUSD Q03 terminal-local infrastructure repair

- UTC handoff: `2026-07-25T08:30:45.455362+00:00`
- Branch: `agents/board-advisor`
- Mission unit: priority-2 diverse-instrument funnel recovery
- EA: `QM5_11903_lawler-supply-demand-zones-20-dma-h1`
- Symbol / period: `EURUSD.DWX` / H1
- Strategy: structural supply/demand-zone retest with a 20-DMA trend filter
- Approved card:
  `D:\QM\strategy_farm\artifacts\cards_approved\QM5_11903_lawler-supply-demand-zones-20-dma-h1.md`
- Coordination task: `1b1b97b9-a0f5-4243-bf7c-a93beceb0d51`
- Known-good Q02 work item: `1711f39f-a0cf-4425-bcce-7f4f45ac1503`
- Latest failed Q03 work item: `7967b022-9c66-4b74-8606-336252cf7d74`
- Q03 replacement work item: `551eb5cb-fedd-4ca8-b746-1c23f3475fc7`

## Selection

The diversity-first build candidates were unavailable or already owned: the
rates and lumber cards require absent data, the DAX card adds another index,
and the available forex/energy build work was already claimed by other paced
agents. QM5_11903 was therefore selected under mission priority 2. It is an
approved, reputable-source, non-ML FX card and had a real Q02 PASS, but no
economic Q03 or Q04 verdict.

## Diagnosis

The EURUSD Q02 evidence is:

`D:\QM\reports\work_items\1711f39f-a0cf-4425-bcce-7f4f45ac1503\QM5_11903\20260724_213033\summary.json`

On T2, Model 4 run 02 initialized and completed with 141 trades, PF 1.11,
net profit 8,739.39, and 16.84% drawdown over 2018-07-02 through 2022-12-31.
Its execution identity was stable and evidence-bound:

- MQ5 SHA-256:
  `106ea1d65020aeab8c70b04b2317552a7d223f36bdf81d0d49e67952ed259f30`
- EX5 SHA-256:
  `8f80936dc1d808821a5f3699d6df81fe0e2a3c5f1bb15c0fdb1e938ae780ccf1`
- EURUSD setfile SHA-256:
  `1aa1971eb824fca6afcb5a2cf3483d07f863ec74b845a2f89133dc9f4ede5867`

The canonical setfile remains backtest-only fixed risk:
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

Two later Q03 attempts used the same source, binary, setfile, symbol, period,
and Model 4 configuration on T7:

1. `731c9b0a-a72f-4bb0-b036-c009bdf0f4cb` produced four empty reports,
   classified `NO_HISTORY;INCOMPLETE_RUNS`. Every report had zero bars,
   empty expert/symbol fields, and an M0/1970 period shell.
2. `7967b022-9c66-4b74-8606-336252cf7d74` produced the same empty shell,
   classified `ONINIT_FAILED;INCOMPLETE_RUNS`.

The second run's terminal-wide log does not support a strategy OnInit defect.
Immediately before the relevant EURUSD history synchronization error at line
1641, it contains completed GDAXI trades. The empty report and shared T7 log
were therefore contaminated terminal-local evidence, not an economic or
implementation verdict:

`D:\QM\reports\work_items\7967b022-9c66-4b74-8606-336252cf7d74\QM5_11903\20260725_075500\raw\run_01\20260725.log`

The already-attempted Q04 row
`b8b9ee05-907a-4778-a9f2-27b26faf01f4` also has three invalid T7 folds with
the same empty-report signature and no PF or trade observations. It does not
constitute a walk-forward verdict.

## Repair

No strategy source or parameter was changed. The unchanged MQ5 was force
recompiled against the current V5 framework:

- strict compile: PASS, 0 errors, 0 warnings
- compile summary:
  `D:\QM\reports\compile\20260725_082349\summary.csv`
- refreshed EX5 SHA-256:
  `1e7bf1c000c95a908e1b451d911647a0516cf0e949ccf21aea293f70654df004`
- MQ5 and setfile hashes: unchanged
- static build check: PASS, 0 failures, 0 warnings
- build-check report:
  `D:\QM\reports\framework\21\build_check_20260725_082509.json`
- compiled artifact commit:
  `15f4c586f70f0cb6894fa7dc222b8403a5471495`

The deterministic pump committed the refreshed EX5 after the strict compile;
no source or setfile was included in that artifact commit.

## Q03 handoff and collision control

The exclusive farm claim was created before diagnosis. While the repair was in
progress, the standard stranded-infra sweep inserted replacement Q03 row
`551eb5cb-fedd-4ca8-b746-1c23f3475fc7`. The first guarded transaction detected
that new open row and aborted without mutation. No duplicate was inserted.

The existing replacement was then adopted under `BEGIN IMMEDIATE`, while it
was pending and unclaimed. Its payload now:

- binds the refreshed EX5 and unchanged MQ5/setfile hashes;
- preserves the failed-Q03 evidence and known-good Q02 lineage;
- records `alpha_change=false` and `priority_track=true`;
- sets `avoid_terminals=["T7"]`.

Pre-change database backup:

`D:\QM\strategy_farm\state\backups\farm_state_before_qm5_11903_q03_requeue_20260725T082842Z.sqlite`

Both the backup and live database returned `PRAGMA quick_check = ok`. Exactly
one EURUSD Q02-Q04 row was open after handoff. The paced worker subsequently
claimed that row on T1 at `2026-07-25T08:32:15+00:00`; no test was launched
manually.

At the last pre-handoff CPU check, six factory terminals were running, below
the seven-tester ceiling. T_Live, AutoTrading, portfolio gates, deploy
manifests, and live setfiles were not touched.

## Post-handoff result and ceiling stop

The paced T1 retry completed before this unit exited:

`D:\QM\reports\work_items\551eb5cb-fedd-4ca8-b746-1c23f3475fc7\QM5_11903\20260725_083221\summary.json`

All four attempts returned `NO_HISTORY;INCOMPLETE_RUNS`, with empty
expert/symbol fields, zero bars, and M0/1970 report shells. The summary binds
the refreshed EX5 and unchanged MQ5/setfile hashes listed above and records
`oninit_failure_detected=false`. This disproves stale EX5 and EA OnInit as the
current blocker. It also broadens the diagnosis beyond T7: the remaining fault
is shared/custom-symbol history synchronization or tester context.

`python tools/strategy_farm/cache_audit.py --ea QM5_11903` confirms
EURUSD.DWX H1 source history for 2017-2026 and existing 2024 tester-cache
coverage on T1, T2, T3, T4, T6, T7, and T9. The row was left terminal as
`INFRA_FAIL`; no economic verdict was inferred.

At `2026-07-25T08:37:26+00:00`, seven factory testers were active on T1, T2,
T3, T4, T7, T9, and T10. That is the binding CPU ceiling, so no second requeue,
manual smoke, cache mutation, or tester launch was attempted. The coordination
task was closed to `RECYCLE` for a later capacity-safe recovery using the
existing row and evidence.
