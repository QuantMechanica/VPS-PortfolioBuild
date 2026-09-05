# Buffer-bound family triage and predicate-fix proposal — REVIEW

Task: `258d8fa0-bcf4-4c84-a8ed-b483ce12f460`, priority 76. Diagnostic tests: commit `1240b069d5` on `agents/codex-buffer-bound-20260905`. This follows the task's **false-positive branch: predicate-fix proposal with tests, no predicate change applied**. Evidence is committed only in the canonical checkout on `agents/board-advisor`.

All **12 recorded buffer findings across QM5_41186/41187/41188/41190 are false positives on bounded local patterns**. These findings concern the static checker's inability to prove array indices; they do not establish a buffer growing with tester history. The arrays are allocated to fixed, validated strategy counts within the calculation. Successful MetaEditor compilation is separately recorded in all four original compile receipts (zero errors and warnings). Their final build-check/queue verdicts remain COMPILE_FAIL; this diagnostic does not promote them.

[The original triage manifest](2026-09-05_buffer_bound_family/triage.json) binds work-item IDs, source hashes, compile receipts, build-check report hashes and exact findings. The four [frozen source fixtures](2026-09-05_buffer_bound_family/fixtures/) are copies of those sources. All five original source and build-report hashes, including the separately classified QM5_41193, were rechecked unchanged during this cycle.

## Per-EA source proof

Line anchors below refer to the exact `.mq5` filename and SHA recorded in the manifest and frozen fixtures.

| EA | Findings | Source evidence and bound | Classification |
|---|---:|---|---|
| QM5_41186 | 2 | `QM5_41186_xtixng-median-runs-rv.mq5:202` admits endpoint count 13; `:745` allocates the endpoint arrays with failure checks. The reverse index at `:835` is guarded against both arrays at `:836`–`:839` before the reported `:840` access. `:871` allocates 12 signs; `:926` refuses any sign count other than 12; `:933` iterates 1..11, so both `signs[index]` and `signs[index-1]` at `:935` are in 0..11. | Bounded; compound-guard parsing and count-equality propagation are missing. |
| QM5_41187 | 3 | `QM5_41187_xauxag-mks-rv.mq5:201` admits endpoint count 12. The reverse-index access at `:840` follows explicit bounds at `:836`–`:839`. Arrays allocated at `:870`–`:874` have 12 elements. In insertion sort, `:883` constrains outer index to 1..11; `:887` starts cursor at index−1; `:888` checks cursor>=0 before reading it and `:892` only decrements it. Every read at `:888`/`:890`/`:891` and every cursor+1 write stays in 0..11. The final cursor may be −1 only after the loop, where cursor+1 is zero. | Bounded; compound guards and descending cursor induction are unsupported. |
| QM5_41188 | 4 | `QM5_41188_xtixng-mrepmedian-rv.mq5:183` admits 13 endpoints; allocations are at `:736`–`:746`. The reported month-count write `:804` follows explicit checks `:800`–`:803`. For the `:868` access, pivot and other are each 0..12 (`:851`, `:857`); lower/upper at `:861`–`:862` choose those values, so both stay in range. Each pivot has 12 slopes (`:848`–`:855`); exact center checks `:888`–`:889` establish indices 5 and 6 before `:891`. Post-loop checks `:903`–`:907` establish 13 pivot medians before `:908`–`:910`. | Bounded; compound guards, bounded ternary values, median constants and equality propagation are unsupported. |
| QM5_41190 | 3 | `QM5_41190_xtixng-mtheilsen-rv.mq5:182` admits 13 endpoints. `:710` initializes month count to zero; `:765` tests it below 13; one matched endpoint is stored at `:802`, then the count increments and the inner scan breaks at `:806`–`:810`. Allocation failures are rejected at `:739`–`:748`. At `:843`–`:845`, i is 0..11 and j is i+1..12, bounding both accesses at `:852`. The pair count expression at `:721` is 13×12/2=78. `:861` checks that exact populated size; `:870`–`:874` establish median indices 38 and 39, both below 78. | Bounded; while-loop count induction, symbolic strict-subset bounds and median constants are unsupported. |

The finite-index tests enumerate every possible outer/cursor position for the 12- and 13-element sorts, every pivot/other pair, all 78 Theil–Sen pairs, and both sets of median centers. They do not change or simulate trading signals.

QM5_41193 is a **different predicate finding**, `EA_ML_FORBIDDEN`, triggered by the identifier `weights[` at the source lines recorded in the manifest. Lines 840–846 show deterministic fractional-difference coefficient recurrence, not evidence of a trained model. This is not a buffer finding and the buffer proposal must not suppress it or alter the no-ML rule. Its existing verdict is retained for separate predicate review.

[The latest-neighbor census](2026-09-05_buffer_bound_family/successor_census.json) covers QM5_41186..QM5_41199. It finds the same four unresolved buffer-failure EAs; QM5_41189 is pending without a compile result; QM5_41193 has the different finding; the other neighbors have COMPILE_OK receipts. Pending work is not assigned a hypothetical pipeline verdict.

## Predicate-fix proposal for review

The current implementation is `tools/strategy_farm/build_gate_hardening.py:433` (`_prior_bound_guard`), `:461` (`_loop_proves_bound`) and `:516` (`check_indicator_buffer_bounds`). The guard uses `[^)]*` across conditions containing `ArraySize(...)`, so it cannot reliably parse nested parentheses. The loop proof recognizes only a narrow forward `for` header and matching textual bound. It does not derive the finite bounds shown above.

The proposed change is a restricted, fail-closed local proof pass, with these acceptance conditions:

1. Parse balanced condition parentheses and boolean operators. An OR-connected failure arm such as `i >= ArraySize(a)` is a bound only when every such unsafe case exits before access. A guard inside an unrelated branch, an AND-qualified unsafe arm, or a guard followed by an index/allocation mutation is not proof.
2. Track only verified successful local allocations and dominating integer facts. Propagate exact equality from fail-fast `!=` guards, validated constant counts and simple integer arithmetic. Invalidate facts on assignment, alias escape, resize or unknown side effects.
3. Recognize monotone forward loops, one-increment-per-outer-iteration month scans, and descending insertion-sort cursors. Prove lower and upper bounds, including cursor+1 after termination; do not accept a loop merely because a bound variable appears in its header.
4. Derive intervals for ternary choices between bounded operands and constant median indices. Check all array accesses, including offset expressions; never skip a complex index merely because it is not a bare identifier.
5. Retain failure/unknown handling where proof is unavailable. Do not rename an EA, insert redundant source guards, exempt a family by ID/hash, weaken the check globally, or infer that a failure is a memory leak from the predicate name alone.

This is a reviewable implementation proposal, **not an installed or completed replacement predicate**. The diagnostic tests reproduce the present defect; future predicate implementation must additionally make all frozen bounded fixtures clear this check while refusing unsafe and non-dominating-guard controls. The original gate remains active throughout.

## Verification and queue disposition

**14 diagnostic/proof tests passed.** Four reproduce the exact 12 reported findings against SHA-bound fixtures; one demonstrates the compound-ArraySize parsing defect; finite-domain tests verify the family bounds; three unsafe controls still fail the existing predicate; a correctly guarded CopyBuffer control passes it. These results establish the classification and proposal evidence, not a new build-check PASS.

Reproduce from the isolated branch:

```powershell
$env:QM_BUFFER_TRIAGE_ROOT = 'C:/QM/repo/docs/ops/evidence/2026-09-05_buffer_bound_family'
python -m pytest tools/strategy_farm/tests/test_buffer_bound_family_proposal.py -q --disable-warnings
```

No EA source fix is justified by these findings, so no source-repair authority or enqueue-compile apply/dry-run is manufactured. The task's source-repair/compile-successor path applies to a real source defect; this delivery uses its alternative predicate-proposal path. No EA source, binary, predicate, queue row, gate criterion or verdict was changed. Main integration remains a Claude/OWNER close-out; the artifact stays in REVIEW.
