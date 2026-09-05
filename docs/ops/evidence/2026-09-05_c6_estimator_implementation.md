# C-6 estimator implementation — REVIEW, INERT

Task `ae041465-0f24-4c37-a6b2-c90773974228`. Code commit `74bec63a18341b325a79b2f14716037706f71828`, isolated branch `agents/codex-c6-estimator-20260905`. OWNER method receipt: `871cf325-3961-41b3-9543-e9b1477448e2`. No activation, provider purchase, terminal operation, pipeline verdict write, or sealed contract edit occurred.

The implementation adds a read-only sibling estimator and a lazy timebox hook. When both existing contract flags are `INERT_UNTIL_C6_ENGINE_OWNER_APPROVED`, the hook does not import the estimator, inspect its inputs or add a result field. A complete valid timebox result was compared against the original module at `c65450df1f52c75e485037d26e654c127ebf60d4`: **5,220 bytes identical**, including an invalid C-6 binding deliberately supplied to the new API. See [baseline_comparison.json](2026-09-05_c6_estimator_implementation/baseline_comparison.json).

## Implemented method

- Full account M5 interval minima, including observed open P&L, are replayed in chronological order. Monetary changes use integer cents; strict target and loss comparisons use exact rational thresholds imported from the existing rulepack. Loss is checked before each M5 endpoint target. P1 is at most 60 Prague days, P2 starts the next day with initial balance reset and at most 30 days. Four distinct position-opening days and a flat position/order inventory are required for each target. Only complete 90-day observation horizons enter the estimator.
- Source blocks contain 60 contiguous Prague days. Their start/end inventories must be flat; overnight positions inside a block are retained. Blocks are sampled uniformly with replacement, with common account paths preserving cross-candidate coincidence. Monetary changes rebase additively. Seed 20260802, default 2,000 replicas, minimum 100, alpha .05 and two-sided percentile endpoints come from the existing probability contract. The adopted Vorlage specifies **only 60 days**, so the implemented worst-of is across that MBB result and the exact guard; no additional block lengths were invented.
- Every complete rolling start is evaluated in each replica. Conditional credit is zero when that replica has no P1 pass; such replicas are retained. The direct joint rate is checked against P1 times conditional P2 in every replica.
- The exact guard uses nonoverlapping 90-day gauntlets from the first sealed Prague day, with Clopper–Pearson tail .025. Breach credit is max(MBB upper, exact upper); P1, conditional P2 and joint lower credits are min(MBB lower, exact lower). A planted observed breach remains in the exact guard even when bootstrap draws look optimistic. No-breach upper bounds are positive.
- Sample flags use 36 disjoint breach gauntlets, 23 **P1-pass denominators** for conditional P2, and 9 joint gauntlets. The adopted Vorlage's derivation explicitly uses the conditional denominator, despite abbreviated task wording “23 P2 passes.” Below any floor the result is LOW_SAMPLE and cannot satisfy all gates. Threshold values remain .10/.85/.65 from the existing contract.

Implementation anchors in the isolated branch: `tools/strategy_farm/portfolio/ftmo_c6_estimator.py:150` (input admission), `:321` (phase replay), `:399` (confidence envelope), `:414` (MBB and fixed-origin census), `:459` (activation guard); `ftmo_timebox_eval.py:1494` (inert hook and composition binding). The [implementation.patch](2026-09-05_c6_estimator_implementation/implementation.patch) preserves the exact reviewed change independently of checkout state.

## Input contract and admission boundary

Every binding is an absolute file path plus SHA-256. The caller supplies an expected seal hash; mutable database references, relative paths, changed bytes, duplicate JSON keys and nonfinite money are refused. A closed-P&L file receives an explicit `CLOSED_PNL_*_INADMISSIBLE` reason.

`qm.ftmo-c6-sealed-trace/v1` contains `sealed: true`, `manually_repaired_samples: false`, first/last sealed Prague dates, and bindings to `profile`, `telemetry` and `reconciliation`. The telemetry file is the existing `qm.ftmo-trial-telemetry.m5/v1` report, with its raw source binding. The estimator validates raw rows with the existing reader, checks exact account/trial/server/currency identity and permitted book magics, rebuilds the compacted report and requires exact equality, then rechecks the raw hash for movement during replay.

`qm.ftmo-c6-exact-profile/v1` contains trial/account/server/currency/book identity, initial balance, fixed risk, zero percent risk, the predeclared maximum sampling gap, `timebox_config_sha256`, and bindings for binary/set manifests, costs, collector code, estimator config and rule snapshot. Initial account size must match the existing rulepack. The estimator configuration must exactly match the existing bootstrap contract. Binary and set manifests (`qm.ftmo-c6-binary-manifest/v1`, `qm.ftmo-c6-set-manifest/v1`) name the same unique candidate ids, the same book, and hash-bound candidate files. Set rows additionally name unique positive magics, and their actual fixed/percent risk settings are verified. Unknown account positions/orders are refused.

`qm.ftmo-c6-reconciliation/v1` binds raw, compacted and profile hashes, records PASS for account identity, positions, orders, balance, costs, swap, margin, openings and continuity, and supplies exact complete day boundaries and a hash-bound opening receipt file. Every boundary specifies day, exact anchor timestamp/balance, end balance and position/order counts at both ends. Raw midnight samples must agree; every M5 interval must exist, including 276-interval spring DST and 300-interval autumn DST days. One final exact midnight sample proves the end boundary; it is not credited as another day. Cropped ranges, lagged midnight anchors and silent offset search are refused.

Opening receipts use `qm.ftmo-c6-opening-receipts/v1`, bind the profile hash and list unique deal ids, position ids, account, magic, `entry: IN`, and UTC timestamps. A count of profitable days or trade exits is not an opening receipt. Cost/margin reconciliation and these opening receipts are **additional sealed evidence inputs**; the current raw collector and compactor do not themselves produce or authenticate a full reconciliation package. The reviewed seal is the trust boundary for those attestations. No real account trace was claimed admissible in this task.

Reproducible synthetic input construction lives in `tools/strategy_farm/tests/test_ftmo_c6_estimator.py::sealed_fixture`. Synthetic fixtures explicitly declare their artificial account/code and their sampling cadence; they are not trial proof. Production inputs must seal their actual cadence and identities before results are examined.

## Fixtures and focused verification

**52 tests passed in 12.95 seconds** across the new C-6 suite, existing telemetry, timebox evaluator and probability contract tests. Direct script invocation of both CLI help paths also passed. [verification.json](2026-09-05_c6_estimator_implementation/verification.json) records commands, commit and artifact hashes.

| Fixture | Result |
|---|---|
| Target exactly +10%, fourth opening day | No pass; +1 cent passes |
| Daily floor exactly -5% | No breach; -1 cent breaches |
| Planted open-P&L trough followed by recovery | Breach retained, including full 90-day raw→M5→estimator replay |
| Loss after both phases completed | Excluded from that completed gauntlet |
| P2 reset | Starts next Prague day at initial capital |
| No P1 passes | Every replica retained, conditional/joint credit zero |
| Zero breaches, 2 disjoint units | Upper = `1 - .025^(1/2)`; LOW_SAMPLE |
| Perfect counts around floors 36/23/9 | Exact feasibility boundaries verified on both sides |
| Known Bernoulli path generator, true breach probability .20 | 40/200 observed; exact interval [0.1468944882, 0.2622263646] contains .20; tolerance .06 |
| Synthetic 50/50 safe/hazard cohort | Observed disjoint rate .5; conservative MBB/exact envelope |
| Forged M5 minimum, raw drift, identity mismatch, missing margin reconciliation, serial-dependence refutation, changed origin | ABSTAIN |
| Candidate file tamper / rehashed percent-risk set | Hash refusal / fixed-risk contract refusal |
| Inactive hook / wrong-book active-hook fixture | No input access and byte parity / ABSTAIN_COMPOSITION_BINDING |

Detailed numerical outputs are in [fixture_results.json](2026-09-05_c6_estimator_implementation/fixture_results.json). These fixtures establish implementation behavior; they do not establish empirical bootstrap coverage for a real trading regime. Point-envelope compaction was checked against uncompressed replay over randomized paths and rebases. It preserves record minima, flat record highs and opening-day transitions to reduce repeated M5 work; its cache is bounded.

## Exact future activation switch — not applied

Both `/probability/gates/breach/enforcement_status` and `/probability/gates/two_phase/enforcement_status` must be `OWNER_APPROVED_ACTIVE` in a **future OWNER-versioned, validated contract**. Partial or unknown activation is refused. The current V1 loader intentionally rejects active values, and V1 text is sealed: editing the two strings in today's file is not a supported activation. A future OWNER card must authorize the new contract version, its loader acceptance, independent review of this commit and the sealed reconciliation producer/input package. There is no environment-variable bypass.

After that separate change, the evaluator's new arguments are `--c6-seal <absolute path>` and `--expected-c6-seal-sha256 <sha>`. The seal must match the evaluated timebox config hash, selected composition id and candidate ids. An active LOW_SAMPLE/ABSTAIN result blocks as ABSTAIN_C6; an active estimate missing the existing thresholds blocks as FAIL_C6. Existing book-ready restrictions continue to apply. Until then, these arguments have no output or input-access effect. The standalone sibling CLI is a diagnostic only and always reports `decision_eligible: false`.

## Limits retained in REVIEW

The minimum is of terminal-observed tick/timer samples, not an exchange-tick completeness proof. Targets are evaluated at M5 endpoints after checking the interval minimum. The CP guard's independence/exchangeability assumption for nonoverlapping gauntlets must be defended by sealed reconciliation; material serial dependence causes abstention. Resampling needs flat stitch boundaries. Any required challenge/phase start with inherited inventory causes whole-estimate abstention, rather than dropping unfavorable starts or inventing an initial lifecycle. Thus overnight positions can exist inside an admitted block, but traces whose required reset states are nonflat are not yet admissible; state-matched replay would need separate review.

No multi-year production-runtime benchmark or real-trial probability claim is made. The 36-gauntlet breach floor alone requires 3,240 complete days even with zero observed breaches. This code is ready for independent review, and remains inert.
