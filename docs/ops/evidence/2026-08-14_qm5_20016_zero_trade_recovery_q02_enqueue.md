# QM5_20016 zero-trade recovery and Q02 enqueue

Date: 2026-08-14

Branch: `agents/board-advisor`

## Outcome

`QM5_20016_xti-xng-mon-rv` is an OWNER-approved, D1, low-frequency
market-neutral energy pair sourced from Hoelscher, Mbanga and Nelson (2017).
The bound Q02 run was a valid real-tick run but produced no entry attempts
because the EA treated Darwinex's prior-date energy D1 session label as the
broker calendar day. The approved Monday decision was therefore unreachable.

The implementation now uses a primed `QM_IsNewBar()` edge and the current
broker day for the Monday decision and attempt key. D1 timestamps remain only
as synchronized-history anchors through `QM_ReadBar`. Directions, weekday,
equal-notional package, joint `RISK_FIXED=1000` budget, 3 ATR stops, spread
limits and exits are unchanged.

The build task `45b03eb8-039c-4f1e-a6df-2b2a3a50ea8c` was claimed atomically,
recorded `done`, and auto-enqueued one append-only logical-basket Q02 item:
`9fa974d1-c38e-489b-b9a3-dd371e7e542f`.

## Farm coordination

- Claim key:
  `manual:codex:agents/board-advisor:QM5_20016:q01-build-rework-q02-handoff:20260814T072440Z`
- Claim owner: `codex:agents/board-advisor`
- Pre-claim backup:
  `D:/QM/strategy_farm/state/backups/farm_state_before_qm5_20016_build_claim_20260814T072440Z.sqlite`
- Pre-record backup:
  `D:/QM/strategy_farm/state/backups/farm_state_before_qm5_20016_record_build_20260814T074318Z.sqlite`
- Governed build result:
  `D:/QM/strategy_farm/artifacts/builds/45b03eb8-039c-4f1e-a6df-2b2a3a50ea8c.json`
  (`SHA256 562cf1743dd233932efe2a6dbe265605f39316f261cf552c0a4e6abc3132a753`)

No pending or active Q02 item existed for this EA when it was claimed or when
the new item was inserted.

## Bound failed run

Evidence:
`D:/QM/reports/work_items/bbc9f4ec-3ad3-48c4-9a6b-c5bed5c01716/QM5_20016/20260725_080939/summary.json`
(`SHA256 1f932476c6e4bf5a993abcee1f6428a941a6e8bf8eaa80e4dab2de125badc6da`).

The run proves the harness and initialization layers:

- model 4 real ticks, D1, 2018-07-02 through 2024-12-31;
- source and T10-deployed EX5 hashes matched and stayed stable;
- source and deployed setfile hashes matched and stayed stable;
- `OnInit` succeeded, both basket symbols warmed, and no log bomb occurred;
- the exact-byte logger sample contained 2,007 events: 1,675
  `EQUITY_SNAPSHOT`, 322 `FRIDAY_CLOSE`, and initialization/shutdown events;
- it contained no entry-attempt or order events and the report had zero trades.

The first failing layer is therefore the entry hook, not history availability,
tester setup, initialization or order execution.

## Minimal same-lineage repair

- Removed raw `iTime` entry/lifecycle reads from the EA.
- Primed the framework new-bar tracker in `OnInit`, preventing a mid-session
  restart from manufacturing an opening event.
- Evaluated the card's Monday decision and persisted attempt day from
  `TimeCurrent()` on the genuine D1 new-bar tick.
- Kept XTI/XNG alignment fail-closed with bounded `QM_ReadBar` checks for the
  current and completed D1 bars.
- Added bounded registered `ENTRY_ATTEMPT`, `ENTRY_REJECTED`,
  `ENTRY_SIGNAL_FIRE`, and `ENTRY_ACCEPTED` events so the next run identifies
  the exact entry layer.
- Closed both legs if a newly opened pair cannot establish a valid joint entry
  timestamp; basket atomicity remains fail-closed.

## Validation

- Build guard: `PASS` for numeric EA ID `20016` and label
  `QM5_20016_xti-xng-mon-rv`.
- Strategy-card validator: `PASS`.
- Embedded and approved card SHA256 values match:
  `cd94bf2d4d5ae2c9a0d7aab1fad2d6bdfe8d677bf200d92b74cc58f6be09d6dd`.
- Strict build check: `PASS`, zero failures and zero warnings.
  Report:
  `D:/QM/reports/framework/21/build_check_20260814_073416.json`.
- Single strict compile: `PASS`, zero errors and zero warnings.
  Log:
  `C:/QM/repo/framework/build/compile/20260814_073437/QM5_20016_xti-xng-mon-rv.compile.log`.
- Repaired MQ5 SHA256:
  `756b5118114a716dc7ea7e745efe8064fa525d83d689aad5599848d6691840ed`.
- Repaired EX5 SHA256:
  `8ddea9e259a0216fdff32022a43cd9588fb6f281a8b354e58afcba0d10e8d8f1`.
- Backtest setfile remains `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.

## Capacity-gated recovery smoke

The capacity scan found only T3 and T5 running Q02 jobs, below the paced-fleet
CPU ceiling. T1 was selected as a free recovery slot. The tester did not
launch: `run_smoke.ps1` resolved T1 and its mandatory custom-history admission
then refused before expert deployment.

Read-only audit `1ee9a267319d4bea03c105978827c99d0eb1f8ec406c80f83a59bdd6d24f8126`
returned `FAIL_CLOSED`, with `MANIFEST_ARCHIVE_FILE_MISSING` and
`TERMINAL_MANIFEST_INCOMPLETE` findings across T1, T2, T6, T7 and T9. Global
custom-history containment had automatically re-engaged at
2026-08-14T07:30:38Z. No alternate terminal was tried because the audit is a
fleet-wide isolation result, not a T1 capacity collision.

The supported build outcome is therefore `deferred_p2_smoke`. The governed
Q02 item remains `pending` and carries the logical basket, synchronized
2018-01-02 through 2024-12-31 window, USD 100,000 tester deposit,
`RISK_FIXED=1000`, and both traded symbols. Normal workers may proceed only
after their existing history-isolation gate passes.

| EA | Bound run | Root cause | Repair | Compile | Entry events | Trades | Remaining gaps |
|---|---|---|---|---|---:|---:|---|
| QM5_20016 | Q02 `bbc9f4ec-3ad3-48c4-9a6b-c5bed5c01716` | prior-date energy D1 label made broker-Monday entry unreachable | primed framework new-bar edge plus broker-day decision; D1 labels retained for synchronization | PASS, 0 errors/0 warnings | old run: 0; repaired proof deferred pre-launch | old run: 0; repaired proof deferred pre-launch | clear custom-history isolation, then execute queued same-bound Q02 |

## Safety

No tester was launched, no terminal was stopped, and no live preset,
AutoTrading state, `T_Live` file, deploy manifest, portfolio gate, portfolio
admission artifact or portfolio KPI was changed.
