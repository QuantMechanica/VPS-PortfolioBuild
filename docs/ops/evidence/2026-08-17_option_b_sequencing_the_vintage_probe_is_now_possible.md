# Option (b) accepted — and its first step is the vintage probe that has been blocked since 2026-07-28

OWNER chose **(b)**: re-run all 79 non-rich pool pairs so 3.4 computes the intraday path in full
rather than on a 12-pair sample.

This records what (b) collides with, why the collision is now resolvable, and the order the work
has to run in. Nothing has been rebuilt, re-run or enqueued.

## (b) is not just a re-run — a rebuild is required, and a rebuild is not known to be neutral

The stream emitter lives in the EA (`framework/include/QM/QM_Common.mqh:1717`), so a sleeve only
gains `side` / `entry_price` if its EA is **recompiled against the current framework** and Q08 is
re-run. Re-running the old binary re-emits the old schema.

A recompile is not assumed behaviour-neutral, and that is not caution — it is measurement.
`docs/ops/evidence/2026-07-28_vintage_bisect.md` observed **72 shifted exits** on QM5_9936 between
binaries, and closed with the causal boundary **NOT ESTABLISHED**. Its decision is explicit and has
never been retracted:

> Do **not** revert a framework commit on this evidence: the causal boundary is not measured.
> Do **not** regenerate all sleeves yet either: that would spend tester capacity before
> distinguishing a 9936-local prop wrapper from a shared-framework change.

**(b) executed directly is exactly the action that decision forbids.** The 07-27 attempt to settle
it never completed — the control run died at 19% and the reserved terminal was reclaimed.

## The blocker has been cleared since

07-28 named the reason it could not proceed: there was no governed way to stage a chosen EX5 to a
claimed terminal and verify it around the run. It asked for

> a task-scoped EX5 staging path plus required SHA-256, copied atomically to the claimed terminal
> only after the work item is claimed … The worker must verify the staged EX5 SHA-256 immediately
> before and after the run.

**That capability now exists**, and is stricter than requested. `isolated_work_item_runner.py`
carries `staged_ex5_path` / `staged_ex5_sha256` in the work-item payload and fail-closes on three
independent comparisons against the compile manifest (`:1690-1697`):

- staged EX5 **path** vs compile result
- staged EX5 **SHA-256** vs compile result
- source **MQ5 SHA-256** vs compile result

and the binding additionally carries `compile_source_commit` (`:1699-1713`), so a probe arm is
pinned to a git boundary, not merely to a binary.

**The A/B that was impossible three weeks ago is runnable today.**

## Therefore the order

1. **Vintage probe — 2 runs.** One EA, two arms: the archived vintage binary and a current
   rebuild, identical setfile, window, model, calendar seed, magic and terminal harness, each arm
   pinned by `staged_ex5_sha256` + `compile_source_commit`. Compare the trade streams: match rate,
   same-entry/shifted-exit, extra/missing trades, net P&L delta.
2. **Then the 79**, with the answer in hand:
   - **streams match** → the rebuilds are behaviour-neutral, the existing Q02–Q10 verdicts stand,
     and (b) is what it looked like: 79 Q08 re-runs for the stream schema alone.
   - **streams diverge** → the 79 EAs' verdicts were earned by binaries that no longer exist, and
     (b) is not a re-stream but a **revalidation of the pool**. That is a materially larger number
     and OWNER should see it before it is spent, not after.

Two runs against 79 is the cheapest possible way to learn which of those two worlds we are in, and
it discharges the 07-28 decision instead of overriding it.

## Independent finding: 69 of 91 pool pairs have no binary provenance at all

Measured across the 2.2 pool, comparing the current `.ex5` against the binary recorded in each
pair's newest sealed evidence:

| | pairs |
|---|---:|
| binary unchanged since the evidence was sealed | 19 |
| **drifted** — current `.ex5` differs from the recorded one | **3** |
| **no binary SHA recorded in the evidence at all** | **69** |
| sum | 91 (control: equals pool size) |

Drifted: `10706:GBPUSD` (fac91bc4… → 7b287687…), `11421:EURUSD` (03455d53… → 9dd7facd…),
`13301:GDAXI` (08e55289… → 64d71b74…).

**Positive control:** 19 pairs match exactly, so the comparison discriminates rather than
reporting drift for everything.

The 69 are not a lookup failure — verified by opening their newest evidence directly. Their
aggregates carry **no `ex5`-related SHA key whatsoever** (`sha-keys present: []` for Q05, Q06, Q08,
Q02; Q09_PORTFOLIO carries only `destination_sha256` / `evidence_content_sha256`). All 22
resolvable pairs resolved from **Q04**, which is the only phase whose aggregate records
`ex5_sha256`.

**So binary provenance is a Q04-only property.** For three-quarters of the pool, the sealed
evidence cannot say which binary produced it — which means the vintage question is not merely
unanswered for them, it is unanswerable from the evidence as it stands. This is independent of (b):
it also bears on 2.2's screening criterion that the pool must contain no superseded rows, since a
row whose binary is unknown cannot be checked for supersession either.

## Evidence

- emitter: `framework/include/QM/QM_Common.mqh:1717`
- probe capability: `tools/strategy_farm/isolated_work_item_runner.py:1690-1713`, `:3818`, `:4519`
- prior decision: `docs/ops/evidence/2026-07-28_vintage_bisect.md` (§ Decision and bill),
  `docs/ops/evidence/2026-07-28_vintage_probe_f0301ecf.md` (§ Required unblock),
  `docs/ops/evidence/2026-07-27_evidence_vintage_check.md` (incomplete control run)
- existing response to a changed binary: hold code `ARTIFACT_BINDING_CONTENT_CHANGED`, 3 active,
  applied today 09:04–09:07 ("the old row cannot authenticate the repaired implementation")
- prior art for accounting a recompile: `tools/strategy_farm/apply_ks_vintage_bill.py`,
  schema `qm.mnt043_044.recompile_vintage_bill.proposed.v1`
- pool: `artifacts/pool_union_20260817.json`, 91 members
- continues `docs/ops/evidence/2026-08-17_point_2_3_exits_are_present_direction_is_the_gap.md`
