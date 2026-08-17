# The vintage question is not answerable from surviving evidence — which is an argument *for* (b), and for widening it to 91

Option (b) was accepted: re-run the non-rich pool pairs so 3.4 computes the intraday path in full.
The plan was to run a vintage probe first, because a recompile is not known to be behaviour-neutral
(the 2026-07-28 bisect saw 72 shifted exits and never established the causal boundary).

**Measured: that probe cannot be run on any pool pair. The "before" arm no longer exists and cannot
be reconstructed.** This records why, and what follows from it.

## Three independent losses, all on the same pair

Probe target was QM5_11421 / EURUSD — 91 trades, D1, Q08 PASS, unambiguous directory, and a known
binary drift (sealed `03455d53…` vs current `9dd7facd…`).

**1. The vintage binary is gone.** Every surviving copy is the current one:

| location | sha | date |
|---|---|---|
| `framework/EAs/…/QM5_11421_….ex5` | `9dd7facd1da7e2c6` | 2026-08-05 |
| `D:\QM\mt5\T1\MQL5\Experts\QM\…` | `9dd7facd1da7e2c6` | 2026-08-05 |
| `D:\QM\mt5\T10\MQL5\Experts\QM\…` | `9dd7facd1da7e2c6` | 2026-08-05 |
| `D:\QM\mt5\DEV1\MQL5\Experts\QM\…` | `05b61d0453302a1f` | 2026-07-13 |
| **sealed in the Q04 evidence** | **`03455d533ffbf1cc`** | 2026-07-26 |

The T1–T10 deployments are overwritten in place on each deploy, so they are not an archive. The
same held for QM5_9936, whose 330,340-byte vintage is likewise gone.

**2. The binary cannot be recompiled, because nothing records what produced it.** The sealed Q04
aggregate carries `ex5_path`, `ex5_sha256`, `setfile_path`, `setfile_sha256`,
`aggregate_identity_sha256` — and **no source commit and no MQ5 hash**. There is no way to check
out the state that yields `03455d53…`.

(The *current* work-item contract does better: `isolated_work_item_runner.py:1699-1713` binds
`compile_source_commit` and `expected_mq5_sha256`. That is a forward fix, not a retrospective one.)

**3. The setfile moved too.** Sealed `303aa04c3b4479a1…`, current `373138c771cefb9d…`. So a
current-vs-archived stream comparison differs in **at least two** variables, and any divergence is
unattributable. The EA directory also carries `310a0bb12 mnt043: adopt staged 386151841 binaries
for admission requalification` since the evidence date — the binary swap is documented, its
provenance is not.

## What follows

**The vintage question, open since 2026-07-27, is not answerable for pool pairs.** Not for want of
tester capacity — the 07-27 attempt failed on a terminal, and the 07-28 plan asked for a staging
capability that has since been built — but because the comparison's baseline arm no longer exists
in any reconstructable form. That is a finding, not a blocker to route around, and it should stop
further attempts to price the probe.

**This argues for (b) rather than against it.** If the archived streams cannot be authenticated
against current-tree behaviour, they cannot serve as the basis for book numbers either — which is
verbatim the concern the 07-27 check said it could not discharge. (b) regenerates them under a
binding that *is* recorded, and so resolves the problem instead of inheriting it.

**But (b) should cover 91, not 79.** The 12 "rich" pool pairs were excluded because their schema is
already complete. Schema completeness is not authentication: their streams carry the same
unrecorded binding as the other 79. Mixing 12 archived-but-rich streams with 79 freshly regenerated
ones would build a book spanning two vintages, one of which cannot be verified — precisely the
defect (b) is meant to remove. The marginal cost is 12 runs on a 79-run job.

**One measurement is still worth taking, and it needs no baseline: determinism.** Run the same
current binary and setfile twice and compare the streams. It is a precondition for every comparison
downstream — if the tester is not bit-reproducible, then no stream comparison anywhere in 3.3/3.4
means what it appears to mean. Two runs, no vintage required, and it is the one piece of the
original probe that survives.

## Forward fix, cheap and durable

Seal `compile_source_commit` and `mq5_sha256` into phase evidence, not only into the live work-item
binding. Today binary provenance is a **Q04-only** property (`ex5_sha256`), and even there it is a
hash with no reconstruction path. Recording the commit turns "which binary produced this verdict"
from unanswerable into a `git checkout`.

## Corrections to my own reporting this round

**A fourth substring-match error.** I attributed 10 newly enqueued QM5_1673 rows to a
`q02_infra_repair` task found via `payload_json LIKE '%1673%'`. That task is **QM5_11673**. There is
no second enqueue path in evidence; the rows came from the regular sweep, whose batches sit exactly
one hour apart (19:52:58 → 20:52:58).

The underlying finding stands and is cleaner for it: **the sweep enqueued 10 fresh Q02 rows for
QM5_1673 one hour after I held one of its rows**, while its `build_ea` review (`977c8c04`) is still
open and no `review_ea` has ever completed for it. Four are already running. The hold covered one
row; the next sweep tick added ten. That is the documented 1.11 gap — holds are a tourniquet, the
gate in the sweep is the repair — demonstrated at scale inside an hour.

## Evidence

- sealed evidence: Q04 aggregate for QM5_11421/EURUSD, 2026-07-26T20:08:52, schema keys listed above
- binary census: `framework/EAs/`, `D:\QM\mt5\{T1,T10,DEV1}\MQL5\Experts\QM\`
- forward binding: `tools/strategy_farm/isolated_work_item_runner.py:1690-1713`
- prior attempts: `docs/ops/evidence/2026-07-27_evidence_vintage_check.md`,
  `docs/ops/evidence/2026-07-28_vintage_bisect.md`
- continues `docs/ops/evidence/2026-08-17_option_b_sequencing_the_vintage_probe_is_now_possible.md`
  and `docs/ops/evidence/2026-08-17_ea_id_directory_ambiguity_and_probe_target.md`
