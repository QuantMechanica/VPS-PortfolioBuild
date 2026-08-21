# QM5_20292 FX carry-unwind Q02 enqueue

Date: 2026-08-22 Europe/Berlin
Branch: `agents/board-advisor`
Farm task: `39f7a994-e3ca-42f5-bc5b-9125b71d04cc`

## Outcome

The previously repaired `QM5_20292_fx-carry-unwind` six-cross D1 basket is
now admitted to the governed Q02 queue. Farm work item
`257d153d-a880-4431-8661-e4d736676ecb` was appended for logical symbol
`QM5_20292_FX_CARRY_UNWIND_D1`; the terminal predecessor
`e0afb922-fa1f-4b39-ab6f-ec7c6b757d5d` remains unchanged as
`DRAFT_DEFECT` evidence.

No tester was manually dispatched. The farm task moved from `BLOCKED` to
`PIPELINE`, leaving the normal pump/worker admission controls to claim the new
pending row.

## Selection and capacity recheck

The priority-1 audit found no unclaimed, approved low-frequency diversity card
whose EA and magic rows were already registry-complete. This task was already
reserved to the branch after the source-preserving stale-binary repair in
commit `8ad5cdacbb970c3f8ea338ae003ce6c90c1156fb`; its enqueue had been deferred
only because CPU averaged 99.8%.

Before queue admission, the current `_Total` processor reading was 78% with
eight MT5 terminal/tester processes present. This was below the 97% paced-fleet
ceiling, so the reserved unit was resumed instead of claiming another EA.

## Append-only binding

The canonical command used `farmctl enqueue-backtest` with the exact source
row supplied as both `--from-work-item-id` and `--append-only-rerun-of`.
Farm-side collision checks found no prior successor and no open Q02 identity.
The inserted payload binds:

| Contract | Bound value |
|---|---|
| MQ5 SHA-256 | `845f638d46b66968705f6ee4226d28fd078f699f96425551b0536f4c39481199` |
| EX5 SHA-256 | `614d5b7adb051a4d1a51acbbd78b733ad8ccfcb6fa56aa78835de471a4eb9e6c` |
| Logical set SHA-256 | `8a1cee7c2c76d9dfde076227459bcec07b12138c8ff03bf8c637be95d6ce3d8d` |
| Expert | `QM\\QM5_20292_fx-carry-unwind` |
| Host / period | `AUDCHF.DWX` / D1 |
| Risk | `RISK_FIXED=1000`, `RISK_PERCENT=0` |
| Basket | `AUDCHF.DWX`, `AUDJPY.DWX`, `GBPCHF.DWX`, `GBPJPY.DWX`, `NZDCHF.DWX`, `NZDJPY.DWX` |

The custom-history admission binds 648 approved archive rows across the six
legs under manifest SHA-256
`fe0dd0fdd90dc26b806044c82fd0d7c35af889a96cbd4d79dece9cfdac3aab06`.
The predecessor summary is independently bound at
`D:\QM\reports\work_items\e0afb922-fa1f-4b39-ab6f-ec7c6b757d5d\QM5_20292\20260814_182720\summary.json`
with SHA-256
`9687296ae99f37471a0591058abcd0e6d476a7424922283490c004c96af64ffe`.

## State verification

- New row: Q02, `pending`, attempt 0, unclaimed at handoff.
- Exact append-only successor count: 1.
- Exact open logical Q02 identity count: 1.
- Source row: still `done / DRAFT_DEFECT`, with its original evidence and
  `updated_at=2026-08-14T18:48:37+00:00`.
- Live farm database `PRAGMA quick_check`: `ok`.
- Consistent post-close SQLite backup:
  `D:\QM\strategy_farm\state\backups\farm_state_after_qm5_20292_q02_resume_close_consistent_20260821T220359Z.sqlite`
  (`501dbb0c29aaf760dfc131f5d93d50d65e50bf3f3f07f1f09ed7303fd117c566`,
  `PRAGMA quick_check=ok`).

## Safety boundary

No strategy mechanics, EA source, setfile, registry, historical work item,
portfolio gate, T_Live path, AutoTrading state, deploy manifest, or live
manifest was changed. This unit only completed the deferred, hash-bound Q02
queue handoff for the already repaired diversity sleeve.
