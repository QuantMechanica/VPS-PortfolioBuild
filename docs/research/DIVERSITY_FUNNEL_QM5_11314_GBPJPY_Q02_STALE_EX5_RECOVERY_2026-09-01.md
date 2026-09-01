# Diversity funnel — QM5_11314 GBPJPY stale-EX5 Q02 recovery

Date: 2026-09-01 UTC (`2026-09-01T18:46:23Z`); 2026-09-01 20:46
Europe/Berlin

Branch: `agents/board-advisor`

Status: one current-binary, append-only Q02 requalification seed is pending as
work item `1dcfcaa3-0021-41ae-a646-52b14c853c92`. No manual dispatch was
requested.

## Capacity gate

The fresh pre-mutation five-sample whole-host CPU window was `75.0%`, `82.0%`,
`89.0%`, `92.0%`, and `86.0%`. Average CPU was `84.8%` and maximum CPU was
`92.0%`; both were below the binding `97%` admission ceiling. Factory testers
were already active on T4 and T7, so this wake only appended queue state and did
not launch another tester.

## Priority-order disposition

The nominal approved build backlog did not contain a collision-free, currently
eligible diversity build:

- the earlier forex handoff `QM5_36005` had already reached an economic Q02
  `FAIL` (`MIN_TRADES_NOT_MET`), so resuming it would bypass its canary;
- the rates and lumber candidates `QM5_1457` and `QM5_1459` remain blocked by
  failed source/data contracts for unavailable rates, bond, and lumber series;
- the remaining current no-EX5 candidates were already represented by governed
  compile work or concurrent fleet edits.

The non-duplicate priority-2 target was therefore
`QM5_11314_tc-m5-7-london-open-box-breakout / GBPJPY.DWX / M5`. Despite its M5
carrier, it is execution-low-frequency: one fixed UTC session window and at
most one trade per day. The signal is structural OHLC only—a previous-hour box
and a completed-bar close beyond its edge—with no trained or banned indicator.
The approved spec cites Thomas Carter's named-author trading-system book and
records the source's R1-R4 decision as all PASS.

## Infrastructure diagnosis and immutable predecessor

Historical work item `f8188bb8-9076-436c-9fc7-4b9d8e651195` remains unchanged
at `done / INFRA_FAIL`. Its immutable farm payload records terminal T7 and
`verdict_reason=run_smoke_fail:ONINIT_FAILED;INCOMPLETE_RUNS`; it is not an
economic strategy verdict. The row predates execution binding and therefore
has null MQ5, EX5, and setfile hashes. Its payload SHA-256 is
`087668f8f22d4bdc91d520e44cde6b44414fa7db99d688dcac68322352c50a92`.
The report path retained by that legacy row is no longer present, so the
diagnosis is anchored to the preserved SQLite payload.

The failed run completed on 2026-07-10. Commit
`f1b1abd677694ebb1bb9f455af52eda8759efafd` subsequently replaced only this
EA's EX5 on 2026-07-14, increasing it from 273,388 to 323,780 bytes. The current
binary generation was therefore unavailable to the predecessor. A same-EA
control, work item `cb9e31ab-c496-4a5a-b568-a34f6b117ee1`, reached Q02 `PASS`
on `GBPUSD.DWX` on 2026-07-10.

The exact GBPJPY pair has no economic Q02/Q03 verdict, terminal-governance
verdict, poison pill, later-phase row, canonical supersession, or competing
pending/active work. The current history contract records GBPJPY coverage from
2017 through 2025, and the new seed carries the ACTIVE custom-history archive
admission for `GBPJPY.DWX`.

## Atomic current-binary Q02 seed

The governed `seed-fresh-q02` path preserved the legacy row, verified the exact
pre-binding source identity, found no competing row, and appended exactly one
Q02 seed:

- new work item: `1dcfcaa3-0021-41ae-a646-52b14c853c92`;
- predecessor: `f8188bb8-9076-436c-9fc7-4b9d8e651195`;
- state at `2026-09-01T18:50:40Z`: `pending`, unclaimed, attempt `0`;
- gate contract: `v4`, with `sh3_enforced=1`;
- MQ5 SHA-256:
  `ab90dac6f341e843aa3c020aa6b0f1a7704883483f9d7f09c97c6de197798761`;
- post-failure EX5 SHA-256:
  `1f8a00bed3760ae93fbcc12226165fe09c9ef9d1c957fd969c74af59daf2b05b`;
- GBPJPY M5 setfile SHA-256:
  `c89cb7ef5060456eb33bf428fdea5695889dfa3dd33208a0eac65f92d1bbca29`;
- risk contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`;
- archive activation SHA-256:
  `61c8c72ccb0cb8038ae6ece7b89aa68f602b1637d8bc6b6c866f38492139134e`;
- OWNER-approved archive manifest SHA-256:
  `fe0dd0fdd90dc26b806044c82fd0d7c35af889a96cbd4d79dece9cfdac3aab06`;
- enqueue event: `fresh_q02_pre_binding_seed_enqueued`
  (`events.id=381670`).

The paced workers own any later claim and tester launch. This wake did not call
`dispatch-tick`, reserve or control a terminal, launch MT5, or run a manual
backtest.

## Dedup correction during candidate selection

Before the final target was selected, the legacy-seed helper accepted a
provisional `QM5_10953 / AUDJPY.DWX` row
(`10ffa8a2-3e3a-4124-9b76-470f93e59286`). A subsequent full pair-history check
found the older economic `MIN_TRADES_NOT_MET` result
`54b1db68-1a77-4688-a174-4de64fa01542`. The provisional row was still pending,
unclaimed, and at attempt zero. It was canonically superseded under the farm's
`work_item_supersedes` contract before dispatch (`events.id=381660` and
`381661`), so both the current claim selector and the database activation
trigger make it unexecutable. No tester touched that row.

## Safety boundary

No EA source, binary, setfile, Strategy Card, registry, resolver, portfolio
gate, portfolio-admission surface, `T_Live`, AutoTrading setting, deploy
manifest, or live manifest was changed. Existing unrelated shared-worktree
changes were preserved and excluded from this commit.

Machine-readable evidence is in
`artifacts/diversity_funnel_qm5_11314_gbpjpy_q02_stale_ex5_recovery_20260901T184623Z_board_advisor.json`.
