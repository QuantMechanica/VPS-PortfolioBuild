# Bounded-array predicate monotonicity — REVIEW

Task `49aa6d17-33be-45c1-8c62-8419480ab965`, priority 77. Implementation is commit `364ec6ded817d945139ae9c788f86ac635b60394` on isolated branch `agents/codex-buffer-monotone-20260906`, based directly on `agents/codex-buildcheck-predicates-20260905` (`23a4cf01b5`). This evidence is committed separately on `agents/board-advisor`. No EA source, binary, worker, compilation queue, pipeline verdict, ML predicate, or live setting was changed.

The bounded-array proof is now monotone by construction for the existing corpus. The unchanged pre-rollout predicate is reproduced as the default finding ceiling; the balanced parser and local interval proof may clear members of that exact set but cannot introduce findings. Full stricter checking is off by default and requires the explicit source marker `qm-build-generation: bounded-arrays-v2`. This provides a declared per-EA rollout boundary for future builds without retroactively tightening legacy EAs.

The improved proof also recognizes a secondary loop counter when the loop condition is re-evaluated before the access and the counter has not changed earlier in the current loop body. It uses the latest successfully checked `ArrayResize` expression as a structural loop bound, which covers arrays resized down to a validated populated count. Unknown, mutated, non-dominating, and unsafe opt-in cases remain fail-closed.

## Acceptance evidence

The SHA-bound frozen fixtures for QM5_41186, QM5_41187, QM5_41188, and QM5_41190 clear all 12 recorded findings: `2+3+4+3 -> 0`. The compound `ArraySize` guard is recognized. The explicitly opted-in genuinely unbounded-growth fixture still fails. The focused acceptance set passed 34 tests, including the full QM5_411xx assertion. The complete build-check group passed all 63 tests in 219.25 seconds.

[The complete sweep table](2026-09-06_buffer_monotonicity/sweep.md) contains before/after counts for every source under canonical `framework/EAs/*/*.mq5`. [The machine-readable receipt](2026-09-06_buffer_monotonicity/sweep.json) preserves every source SHA-256 and exact finding. The collector independently compared the embedded legacy implementation with the frozen baseline implementation from commit `1240b069d5`; parity mismatches were zero.

| Corpus result | Count |
|---|---:|
| EA sources scanned | 4,000 |
| Findings before | 633 |
| Findings after | 410 |
| Findings cleared | 223 |
| New findings | 0 |
| EAs with new findings | 0 |
| Legacy parity mismatches | 0 |

Reproduction commands:

```powershell
$env:QM_BUFFER_TRIAGE_ROOT='C:/QM/repo/docs/ops/evidence/2026-09-05_buffer_bound_family'
python -m pytest tools/strategy_farm/tests/test_buildcheck_predicate_fix.py tools/strategy_farm/tests/test_buffer_bound_family_proposal.py -q --disable-warnings
python -m pytest tools/strategy_farm/tests/test_build_gate_hardening.py tools/strategy_farm/tests/test_buildcheck_predicate_fix.py tools/strategy_farm/tests/test_buffer_bound_family_proposal.py -q --disable-warnings
python C:/QM/repo/docs/ops/evidence/2026-09-06_buffer_monotonicity/collect.py
```

The implementation remains in REVIEW. No compile or pipeline verdict is inferred from static predicate evidence.
