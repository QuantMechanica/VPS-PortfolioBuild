# Treasure Phase 2A checkpoint — restart recovery and diagnostic evidence gates

Date: 2026-09-01  
Router task: `2e0bc944-0f47-47e2-b6c2-e7b83db89147`  
Operator: Codex on `agents/board-advisor`

## QM5_20004 restart recovery

The old `QM5_20004` identity and all historical Q04–Q06 evidence were left
untouched. Governed allocation created the new NDX-only identity
`QM5_41272_turn-of-month-index-long-restart-r1`, magic `412720000`.

The faithful port changes only inherited-position reconstruction. On
initialization it calls `QM_TM_HeldPeriodsForMagic`, whose framework
implementation reads `POSITION_TIME` and counts actual D1 transitions. Missing
history fails initialization; an inherited position is never assigned today's
day key as though it opened today. The source retains exit day 3, SMA(50),
ATR(20) × 3, fixed risk 1000, percent risk 0, news ceiling 336 hours, and the
original Friday-close settings.

Verification:

- restart regression: 4 tests PASS;
- compile-work-item regression suite: 60 tests PASS (64 combined);
- build guardrails: PASS, zero findings;
- allocator result: one active row, zero status-aware magic collisions;
- source commit: `4b6a595755da54a807b117de30b777fd5b3f9de0`;
- conformance-repair commit: `991ac586df202e86dfde5ad692cb3146198dd2f4`.

The first governed COMPILE_EA row
`8784ae52-96aa-4c03-97b5-424edc9ea3ad` compiled with zero MetaEditor errors
and warnings, then correctly failed the current Q01 build check on a missing
explicit MAE hook and an unannotated structural prior-close read. Its receipt
is immutable. The repair adds `QM_FrameworkTrackOpenPositionMae()` and the
reviewed `perf-allowed` annotation; no mechanic changed. Append-only repair row
`85c6de75-0080-45dc-b128-6e6a3910f047` is source-hash bound to
`47579844c327c1aee22986fef9c3170a1fcc973926c9908ec0c91d27b5d5d442`.
Its exact rollout hold was released through the governed one-item utility at
`2026-09-01T16:17:58Z`. At this checkpoint it remains pending for a resident
compiler. Therefore build review and Q02 are deliberately not claimed or
seeded; Q02 remains behind the required independent review.

## QM5_13022 bounded diagnostic classification and cost

This is a reproducible harness/resource catastrophe, not an economic or
strategy verdict. Multiple immutable Q02 summaries bind the same source
(`5a730180...`), EX5 (`9c3f2fbc...`), setfile (`a5ef3219...`), symbol, and
window while reporting `LOG_BOMB` with no OnInit failure. News-calendar state
was fresh.

Observed journal costs include 80.5 GB, 9.84 GB, 21.9 GB, and 50.45 GB: at
least **162.69 GB of journal output** across four bounded attempts. The cited
runs consumed approximately 36, 18, 35, and 44 minutes respectively, at least
**133 terminal-minutes**. The last retained native report contains 368,325,473
ticks, 1,163 D1 bars, 100% real-tick history, and zero trades. A new launch was
not duplicated: work item `10d0fe72-12aa-4b6d-a03d-4b1b55c5ba75` is already
pending, and its payload still grants a two-hour timeout. Launching another
row or silently rewriting that pending row would violate the bounded and
append-only requirements. Classification: **HARNESS/RESOURCE DEFECT,
INFRA_KILLED; strategy verdict unavailable**.

## Zero-trade recovery triage

No historical row or verdict was edited. The canonical append-only command
was exercised against each exact predecessor and failed closed before enqueue.

| EA | Retained proof | Append-only refusal | Classification |
|---|---|---|---|
| QM5_20035 | Native MT5 report plus compressed `summary.json.gz`; report has 0 trades. Current source/EX5 still match the original build receipt. | `stale_pass_source_binding_missing_or_invalid` (`expected_mq5_sha256` absent in the legacy row) | Harness/provenance setup defect; entry layer unresolved, not a genuine strategy verdict. |
| QM5_20132 | Native MT5 report and Step-22 receipt bind EX5 `c9dd6d5...`, setfile `a30bd3bc...`, XNG M30; both historical summary bundles were deleted. | `q02_rerun_source_evidence_missing` | Evidence-retention/harness defect; entry layer unresolved. |
| QM5_20134 | Native MT5 report and Step-22 receipt bind EX5 `edb1fc85...`, setfile `9a43f110...`, XTI M30; both historical summary bundles were deleted. | `q02_rerun_source_evidence_missing` | Evidence-retention/harness defect; entry layer unresolved. |

All three sources contain terminal-persistent attempt state, but the retained
evidence has no bounded reject-reason marker stream. Consequently it would be
false precision to label any particular filter as the first failed entry gate.
No threshold or mechanic was changed, and no strategy FAIL/ZERO_TRADES verdict
is inferred from missing diagnostics.

## Boundary and continuation

- No census program, T_Live setting, AutoTrading setting, or running backtest
  was touched.
- No Q02 row for QM5_41272 exists yet.
- No diagnostic rerun row was appended because the evidence gate refused it;
  the refusals are the durable setup diagnosis, not a reason to bypass the
  gate.
- Safe continuation is: resident COMPILE_EA completion → independent build
  review → reviewed Q02 seed; separately, an OWNER-reviewed raw-report recovery
  binding or restored original summaries is required before the three
  append-only diagnostic reruns can lawfully enter the queue.
