# Q09 REQUAL-8 serial execution — pair 1 retry-3 guard block

Date: `2026-08-30T16:07:58Z`

Router task: `1b57e398-3709-44b3-a53a-21e20fdb5d7b`

OWNER decision: `OWNER-DEC-Q09HOLD-REQUAL-8-20260829`

Approved manifest: `docs/ops/evidence/2026-08-30_8709bc0f_q09_requal8_manifest.json`
(`0b6845c941314f9c2f754b0897bd66fd1f4daa0220921726f2d51ef0e72a76f2`)

## Verdict

`TRANSIENT_BLOCK_DIRTY_REWORK_GUARD_PERSISTS`.

This single-pass continuation inspected only serial pair 1. The two prior
committed `status=no_capacity` receipts remain sufficient measured-saturation
evidence for the OWNER-ratified Q01 smoke waiver, so this cycle did not consume
another tester slot or launch another smoke. The evidence cannot be written
retroactively into immutable build generation 0. The normal rework preparer
must archive generation 0, mint generation 1 and a new attempt token, and bind
the capacity evidence to that exact generation.

That normal path remains fail-closed because the canonical checkout is dirty
with work owned by other lanes. The exact read-only dirty guard reported:

- branch `agents/board-advisor`, HEAD
  `90bcf16b94dd3e966e81df33ca9ff39b7793a95c` at the census;
- `total_count=225` dirty entries;
- `generated_count=200` ignored build products;
- `count=25` blocking entries: `other=19`, `tracked_ea_source=5`, and
  `framework_registry=1`;
- `override=false` and `blocked=true`.

None of the pair-1 EA, manifest, prior pair-1 receipts, or scoped build-control
paths was dirty. This task did not set `QM_ALLOW_DIRTY_REPO_BUILDS`, commit or
reset another lane's work, invoke the rework preparer behind its guard, or edit
the runtime database.

The two existing durable saturation receipts are:

- `docs/ops/evidence/2026-08-30_1b57e398_q09_requal8_pair1_review_block.md`
  (capacity retry committed by `4067c3d05`);
- `docs/ops/evidence/2026-08-30_1b57e398_q09_requal8_pair1_retry2_block.md`
  (second capacity receipt committed by `cc51ca2cb`).

## Immutable pair-1 state

| Item | Current evidence |
|---|---|
| Build task | `471b4139-415d-41dc-833d-5bae378e6ced`, `blocked`, generation 0, `codex_review_rework=false` |
| Mechanical review | `06caffcf-84d4-47f4-a487-d69534db1a73`, immutable generation-0 `FAIL` |
| Independent review | `597bdc4b-4fb8-4cd5-b5f6-307d6b963d4e`, pending; no verdict |
| Compile work item | `1e748215-fa24-4a0a-9216-f443d5b3ade4`, `COMPILE_OK`, build check `PASS` |
| Manifest SHA-256 | `0b6845c941314f9c2f754b0897bd66fd1f4daa0220921726f2d51ef0e72a76f2` |
| MQ5 SHA-256 | `2d71477c309689649df9036e4890b8260f7506c75d4a15636bf507aa1c2cdd7f` |
| EX5 SHA-256 | `bbef2fb82ab20d216ce6f44f87d810168ff945069c9642379a5d16970ed547a5` |
| Bound setfile SHA-256 | `6b032b6e118c66c0338fa3520c7f90d39cc6df14d1038b48a113afdac251b970` |

The bound backtest setfile still has `RISK_FIXED=1000` and `RISK_PERCENT=0`.
The EA still has `qm_news_stale_max_hours=336`; the fail-closed ceiling was not
weakened.

## Append-only and serial verification

- SQLite `PRAGMA quick_check`: `ok`.
- Q02 rows for `QM5_41215` through `QM5_41222`: `0`.
- All eight decision-bound Q09/Q10_NEWS work items remain `pending`, with
  `claimed_by=NULL` and `verdict=NULL`; zero holds were released.
- Pairs 2–8 remain card-only: each successor directory contains only
  `docs/strategy_card.md`.
- Protected `QM5_41162` `OPT_CENSUS` remains exactly 1,085 rows: 295 done and
  790 pending at the census. This task did not cancel, reprioritize, supersede,
  reuse, or interrupt any row.
- The MT5 census found normal workers on T1–T10 and active factory tests on T2,
  T3, T6, and T10. No terminal, reservation, process, or active test was
  stopped or altered.
- No EA source, EX5, setfile, historical receipt, Q02 row, hold row, or
  protected-program row was changed in this cycle.

## Safe continuation

After an independently clean canonical-tree window exists, use the normal
bounded rework path to create build generation 1 and bind either committed
measured-saturation receipt (or a real passing smoke) to that exact generation.
Then require a fresh mechanical Codex review `PASS` and an independent Claude
final-review approval. Only after both approvals may pair 1 append exactly one
manifest-bound Q02 seed, verify it, and release hold
`aa80274f-fb46-4432-b47e-6fb2bf28c9a2` with the decision-bound note. Pair 2
remains forbidden until pair 1 completes.

Verdict: `TRANSIENT_BLOCK_DIRTY_REWORK_GUARD_PERSISTS`; zero seeds, zero
releases, zero historical mutation, and zero protected-program interruption.
