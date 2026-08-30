# Q09 REQUAL-8 serial execution — pair 1 retry-2 capacity block

Date: `2026-08-30T15:08:49Z`

Router task: `1b57e398-3709-44b3-a53a-21e20fdb5d7b`

OWNER decision: `OWNER-DEC-Q09HOLD-REQUAL-8-20260829`

Approved manifest: `docs/ops/evidence/2026-08-30_8709bc0f_q09_requal8_manifest.json`
(`0b6845c941314f9c2f754b0897bd66fd1f4daa0220921726f2d51ef0e72a76f2`)

## Verdict

`TRANSIENT_BLOCK_NO_CAPACITY_AND_DIRTY_REWORK_GUARD`.

This single-pass continuation retried only pair 1. The governed smoke
dispatcher refused before launching an EA, so no active tester was interrupted:

```text
Terminal resolution returned no terminal. status=no_capacity error_code=none message=No message.
```

The immediately preceding `farmctl.py mt5-slots` census at
`2026-08-30T15:05:35+00:00` showed all scheduled workers `T1` through `T10`
alive, active tester processes on `T2`, `T6`, `T7`, `T9`, and `T10`, and an
additional active custom-history reservation on `T5`. The exact command was:

```text
run_smoke.ps1 -EALabel QM5_41215_pre-fomc-drift-ndx-requal8 -Symbol NDX.DWX -Year 2024 -Terminal any -Period H1 -SetFile .../sets/requal8_repair_1b57e398_r2/QM5_41215_pre-fomc-drift-ndx-requal8_NDX.DWX_H1_backtest.set -MinTrades 1 -SmokeMode
```

This is fresh, measured saturation evidence, but it is not retroactively
written into generation 0's immutable build result. The normal bounded rework
preparer must archive that result, create generation 1 with a new attempt token,
and bind the saturation evidence to that generation. It could not do so safely
in this cycle because the canonical checkout had 220 unrelated dirty entries.
The requalification EA, its repair setfile, the manifest, and the scoped
build-control files were clean. The task did not reset, commit, or otherwise
absorb unrelated operator work, and it did not bypass the dirty-build guard.

## Immutable pair-1 build state

| Artifact | SHA-256 |
|---|---|
| Manifest | `0b6845c941314f9c2f754b0897bd66fd1f4daa0220921726f2d51ef0e72a76f2` |
| MQ5 | `2d71477c309689649df9036e4890b8260f7506c75d4a15636bf507aa1c2cdd7f` |
| EX5 | `bbef2fb82ab20d216ce6f44f87d810168ff945069c9642379a5d16970ed547a5` |
| Bound backtest setfile | `6b032b6e118c66c0338fa3520c7f90d39cc6df14d1038b48a113afdac251b970` |

- Build task `471b4139-415d-41dc-833d-5bae378e6ced` remains `blocked`,
  generation 0.
- Mechanical review `06caffcf-84d4-47f4-a487-d69534db1a73` remains the
  historical generation-0 `FAIL`; it was not overwritten or self-approved.
- Claude final review `597bdc4b-4fb8-4cd5-b5f6-307d6b963d4e` remains pending
  and is not treated as approval.
- The setfile still binds `RISK_FIXED=1000` and `RISK_PERCENT=0`; the EA's
  fail-closed `qm_news_stale_max_hours` remains at the enforced ceiling of 336.

## Append-only and serial verification

- SQLite `PRAGMA quick_check`: `ok`.
- Q02 rows for `QM5_41215` through `QM5_41222`: `0`.
- All eight manifest holds remain active on pending Q10 work items, with no
  claimant, verdict, release timestamp, or release note.
- Pairs 2–8 (`QM5_41216` through `QM5_41222`) still contain only
  `docs/strategy_card.md`; serial pair 2 was not started.
- Protected `QM5_41162` `OPT_CENSUS` remains 1,085 rows: 288 done, 1 active,
  and 796 pending. Its already-running program was not cancelled, reprioritized,
  superseded, reused, or interrupted.
- No Q02 seed was appended and no Q09 hold was released.

## Safe continuation

After the canonical dirty-build guard admits the bounded retry, prepare build
generation 1 through the normal rework path, bind this measured
`status=no_capacity` evidence (or a real passing smoke) to that exact generation,
require mechanical review `PASS`, then obtain independent Claude final-review
approval. Only after both reviews may the manifest-bound pair-1 Q02 seed be
appended and verified, followed by release of hold
`aa80274f-fb46-4432-b47e-6fb2bf28c9a2` with the exact decision-bound note.
Pair 2 remains forbidden until pair 1 completes.

Verdict: `TRANSIENT_BLOCK_NO_CAPACITY_AND_DIRTY_REWORK_GUARD`; zero seeds,
zero releases, zero historical mutation, and zero protected-program interruption.
