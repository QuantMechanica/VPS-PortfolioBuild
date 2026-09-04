# Q08 stream rerun after terminal Q14

RESULT: **IMPLEMENTED; ready for independent review**.
Router task `ccea329e-898b-4510-82b0-a3ca179eb88d`.
Code commit `377d7df45d2753be2a75c4c00bd49d6d5052d03e` on `agents/codex`.
Code workspace: `C:/QM/worktrees/codex`. Author: Codex, GPT-6 Astra.
Canonical pump code has not been changed or deployed by this delivery.

## Delivered behavior

`tools/strategy_farm/q08_stream_rerun.py` checks terminal Q14 rows newer than the
persisted watermark. It reuses `assemble_stream_bundle.resolve_identity` and
`find_bound_q08` (the current name of the binding helper referenced in the task).
A missing identity-bound Q08 stream leads to exactly one governed append-only
enqueue, provided the pair has no pending/active Q08, has the required latest
Q07 done/PASS and Q08 done/PASS-class predecessors, and the current binary matches
the Q14 identity. The expected hash is read from the repository binary.

`farmctl.auto_enqueue_q08_stream_reruns` wires this into a ten-second budgeted
pump stage after optimization-fork service. The canonical-checkout guard,
factory mutation lock, Factory_OFF flag, and
`QM_DISABLE_Q08_STREAM_AUTO_RERUN=1` control the mutation path. It calls
`enqueue_cascade_backtest_for_ea` with the exact predecessor, rerun-of, binary
SHA and required reason format; it neither launches a tester nor changes a verdict.
The structured event is `q08_stream_rerun_auto_minted` with pair, Q14 trigger,
Q07 predecessor, Q08 predecessor, new Q08 id and binary hash.

Watermark: `D:/QM/strategy_farm/state/q08_stream_auto_rerun_watermark.json`.
It is atomically persisted with an offset-aware timestamp/id cursor and retry ids.
Refused dependencies remain retryable without preventing newer triggers from
being serviced. Duplicate protection also covers an enqueue followed by a crash
before watermark persistence. The implementation counts an actual created row;
`farmctl`'s `enqueued=true` on a skipped request is not treated as a creation.

The CLI provides a read-only preview. It does not mint a bundle or persist its
proposed watermark. `sealed_stream_bytes_unavailable` alone is outside this
task's specified `no_q08_stream_bound_to_identity` trigger.

## Verification

```powershell
cd C:/QM/worktrees/codex
python -m pytest tools/strategy_farm/tests/test_q08_stream_rerun.py tools/strategy_farm/tests/test_assemble_stream_bundle.py tools/strategy_farm/tests/test_pump_stage_budget.py -q
python tools/strategy_farm/q08_stream_rerun.py --limit 100
```

**34 tests passed**, including a real temporary SQLite/evidence layout, exact
enqueue arguments, repeated cycles, crash recovery, pending/active suppression,
kill switch, Factory_OFF, corrupted watermark, binary drift, equal-timestamp
pagination, retry fairness, PASS/FAIL_SOFT versus FAIL_HARD, and pump delegation.
The enqueue itself is substituted in these unit tests, so no live queue row was
minted. The production append-only enqueue implementation is reused unchanged.

The live read-only preview inspected nine Q14 terminal rows: eight current pairs
already bound and one older QM5_11421 trigger superseded. **Would enqueue: 0**.
Independent byte lookup found all eight physical stream files matching their
pinned content hashes. The production watermark remained absent/unchanged.
Full output: `2026-09-04_q08_stream_auto_rerun_dry_run.json` in this directory.

The payload says eight manual reruns. The recorded evidence contains **seven**
manual Q08 stream reruns dated 2026-09-04; QM5_11421 already had its stream.
The seven real source/rerun/hash tuples are retained in
`tools/strategy_farm/tests/fixtures/q08_stream_reruns_20260904.json` and tested
individually. This distinction does not change the verified eight-pair pool.

## Review and integration

The executable source, pump integration, tests and fixture are in the code commit.
`2026-09-04_q08_stream_auto_rerun.patch` is a durable copy of that exact code diff.
Evidence is committed separately on canonical `agents/board-advisor`, per the
scheduled-cycle hard rule. Leave this task in REVIEW for Claude/OWNER close-out.

To establish the current code baseline, `agents/codex` was fast-forwarded from
`9e45805f10cbb788b54a8c7ce233d0d52d413daa` to
`e214b911d33ecfb977c1d4331c6671389bee9721`. The existing resolver edit was preserved
byte-for-byte at its original path (SHA-256
`9ac27556aac81504d263afaec51e88965a73c6be1045565bbd97112a4fa9eefb`), with an
additional retained stash `d399052ce152dabf890400deb9fd56026ca0adce`.
It was excluded from the code commit. No main integration was performed.
