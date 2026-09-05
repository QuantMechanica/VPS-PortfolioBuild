# Build-check predicate proposal — REVIEW, revision required

Task `abd0a457-1941-49d7-8e0c-5025e90b424d`. Isolated branch `agents/codex-buildcheck-predicates-20260905`, commit `23a4cf01b5a8758adc98ab8e9bf117a898b868ed`, based on triage commit `1240b069d540d611cd6e92c2e4e115ec743844a1`. Evidence only is committed on agents/board-advisor. No EA sources, workers, compilation queue, or verdicts were changed.

The four frozen fixtures clear their 12 recorded buffer findings; the exact original QM5_41193 SHA clears all eight ML-identifier findings. The implementation is a review candidate, **not acceptance-ready**: the requested all-green full suite is not achieved. The corpus expansion must be resolved before integration.

| Frozen EA | Original buffer findings | Proposed buffer findings | Original ML findings | Proposed ML findings |
|---|---:|---:|---:|---:|
| QM5_41186 | 2 | 0 | 0 | 0 |
| QM5_41187 | 3 | 0 | 0 | 0 |
| QM5_41188 | 4 | 0 | 0 | 0 |
| QM5_41190 | 3 | 0 | 0 | 0 |
| QM5_41193 | 0 | 0 | 8 | 0 |

## Implementation and verification

Balanced conditions, dominating fail-fast facts, successful local allocation checks, finite arithmetic/ternary intervals, forward counters and descending insertion-sort cursors supplement the structural predicate. Nested brackets remain balanced. Facts expire on relevant mutations and unknown effects. Loop proofs check the initial lower bound, unit step and counter stability. No EA identity or source hash grants an exemption. The ML scan recognizes model includes and learning operations; a deterministic weights array or a comment/string example is insufficient.

**61 tests passed; one full-suite corpus assertion failed.** The 32 focused tests include every frozen buffer fixture, compound conditions, nested loops, mutated/negative loop counters, unknown calls, unsafe offsets, genuinely unbounded growth, deterministic coefficients, ML imports, online learning and ONNX operations. Existing synthetic positive build-gate fixtures remain green. Exact output is in [verification.json](2026-09-05_buildcheck_predicate_fix/verification.json).

The failing `test_qm5_411xx_sources_have_no_unbounded_numeric_buffers` assumes the entire evolving corpus has zero findings. The unchanged baseline fails that assertion with 47 findings; the candidate has 70. Baseline evidence is frozen separately. The test was neither weakened nor suppressed.

## Corpus effect and adoption blocker

The read-only canonical sweep covers 3987 EA source files: 634 buffer findings before and 1091 after, with 471 changed EA rows. The actual PowerShell ML scan across EA/framework roots changes 11 findings to 0; eight of the former are the frozen 41193 coefficient references. All original paths, hashes and findings are preserved in [sweep.json](2026-09-05_buildcheck_predicate_fix/sweep.json); [the complete before/after table](2026-09-05_buildcheck_predicate_fix/sweep.md) lists every changed EA.

The increase is material. Enforcing the proposal to inspect complex offsets and reject unproven lower bounds exposes old unchecked accesses and additional unsupported proof patterns. These new findings are **unproven accesses**, not established memory defects; clearing them by skipping expressions or exempting EA families would contradict the proposal. Broader proof coverage or a separately reviewed rollout boundary is required. This packet does not request changing any EA or retrying compilation to hide the issue.

The four target predicates would clear, but no build or pipeline PASS is inferred. The current queue dispositions remain authoritative. REVIEW verdict: **NEEDS_REVISION_CORPUS_EXPANSION**.

## Reproduction

Run the tests on the isolated branch with `QM_BUFFER_TRIAGE_ROOT=C:/QM/repo/docs/ops/evidence/2026-09-05_buffer_bound_family`. The read-only collector executes baseline and proposed buffer predicates on the same captured source bytes and extracts the real PowerShell forbidden-scan function for both ML scans. The original 41193 raw source is also preserved as a deterministic gzip to retain its exact hash across Git line-ending conversion.
