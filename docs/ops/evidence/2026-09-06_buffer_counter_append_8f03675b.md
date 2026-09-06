# Counter-indexed buffer bound proof — REVIEW

Router task `8f03675b-de8c-45a7-9386-6dd7a947012f`, priority 88. The implementation is commit `835bcf065a63ba1617df3e05dc6ec464dd9efa85` on isolated branch `agents/codex-buffer-counter-proof-20260906`, based directly on `agents/board-advisor` commit `eca677c1219c0d12febc074f540bf7fc1e480348`. This evidence is committed separately on `agents/board-advisor`. No EA source, `.ex5`, registry, setfile, worker, compile queue, pipeline verdict, live setting, AutoTrading state, or terminal process was changed.

## Result

`EA_INDICATOR_BUFFER_UNBOUNDED` now recognizes a narrow counter-indexed append proof. The counter must have a dominating reset to zero, remain monotone, and be incremented exactly once after the access in the relevant loop body. The access is accepted only when one of these local capacity facts also holds:

- a checked `ArrayResize(buffer, counter + 1)` dominates the access;
- the counter itself is guarded below the dominating resize cap; or
- a canonical ascending `0 .. cap-1` or descending `cap-1 .. 0` loop can execute no more than `cap` times, with no nested loop around the access and no loop-cursor rewrite.

Assignments, decrements, multiple increments, pre-access increments, nested-loop amplification, non-dominating resizes, later capacity mutations, and resize caps smaller than the iteration budget remain unproved. The existing legacy-to-candidate intersection remains in force.

## Verification

The full bounded-array/build-gate group passed:

```powershell
$env:QM_BUFFER_TRIAGE_ROOT='C:/QM/repo/docs/ops/evidence/2026-09-05_buffer_bound_family'
python -m pytest tools/strategy_farm/tests/test_build_gate_hardening.py tools/strategy_farm/tests/test_buildcheck_predicate_fix.py tools/strategy_farm/tests/test_buffer_bound_family_proposal.py tools/strategy_farm/tests/test_buffer_counter_append_proof.py -q
# 74 passed in 206.04s
```

The new regression file contains frozen negative reproductions derived from all five wave-2 failures and QM5_41340, plus positive unsafe controls for a too-small resize cap, a pre-access increment, and multiple increments. A checked per-append resize fixture is also covered.

[The complete corpus table](2026-09-06_buffer_counter_append_8f03675b/sweep.md) and [machine-readable receipt](2026-09-06_buffer_counter_append_8f03675b/sweep.json) compare the exact parent implementation with the candidate over every canonical `framework/EAs/*/*.mq5` source. [The collector](2026-09-06_buffer_counter_append_8f03675b/collect.py) is reproducible and asserts both the subset invariant and the six named clearances.

| Corpus result | Count |
|---|---:|
| EA sources | 4,004 |
| Findings before | 410 |
| Findings after | 282 |
| Findings cleared | 128 |
| EAs improved | 112 |
| EAs fully cleared | 96 |
| New findings | 0 |
| EAs with new findings | 0 |

The receipt contains the complete explicit `improved_eas` and `fully_cleared_eas` lists. Required targets all moved to zero: `QM5_20233`, `QM5_20248`, `QM5_20256`, `QM5_20257`, `QM5_20258`, and `QM5_41340`.

## Wave-2 authority rows eligible for OWNER release after integration

Each row below failed only because of `EA_INDICATOR_BUFFER_UNBOUNDED`, and its `candidate_recheck.source_repair_authority` is bound to `ce03756f-7fad-4bd4-aa57-561551851604` for the named EA. Their exact sources are zero-finding under the candidate. This is a release list, not a compile enqueue or pipeline verdict.

| EA | Held/failed work-item row | Authority |
|---|---|---|
| `QM5_20233` | `800b4d97-b680-4a74-b913-ff5a564b6124` | `router_ops_issue:ce03756f-7fad-4bd4-aa57-561551851604:QM5_20233` |
| `QM5_20248` | `32135b34-eca6-49de-9843-c1636863e510` | `router_ops_issue:ce03756f-7fad-4bd4-aa57-561551851604:QM5_20248` |
| `QM5_20256` | `40244414-86e9-4792-bf7c-766c1ab20d42` | `router_ops_issue:ce03756f-7fad-4bd4-aa57-561551851604:QM5_20256` |
| `QM5_20257` | `0a276f74-76f5-4e90-b7c0-c2ce91438d75` | `router_ops_issue:ce03756f-7fad-4bd4-aa57-561551851604:QM5_20257` |
| `QM5_20258` | `d206db8e-a1b9-4bee-b6d3-1be183411300` | `router_ops_issue:ce03756f-7fad-4bd4-aa57-561551851604:QM5_20258` |

The implementation and this evidence remain in `REVIEW`; no self-approval or transition to `PIPELINE` is implied.
