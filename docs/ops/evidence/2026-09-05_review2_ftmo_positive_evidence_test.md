# Second independent review — FTMO positive-evidence acceptance test R3

Reviewed file: `docs/ops/OWNER_VORLAGE_2026-09-05_ftmo_positive_evidence_test.md`
Raw SHA-256: `265cd2587837132e79055a56c5c7450cc406902db139b6a2d8f7d4e8f3ac3285`
LF-normalized SHA-256: `9a6c7c43fa7a97198db0e561732ffda4bbe2abda0d1d87d16d48fbdc654ecad3`
Lines: 384
Date: 2026-09-05
Verdict: **FAIL**

The exact R3 bytes match the task-provided digests. R3 closes most of the first review, but it is not safe to ratify yet. One original blocker (F3) is only partially closed, and the concurrently delivered P7a contract creates a new load-bearing inconsistency: R3 would make three C-6 outputs decisive although the versioned contract says they are inert and no admissible estimator exists. The minimal diff below is review guidance only and was not applied.

## F1–F6 closure status

| Finding | Status | Review result |
|---|---|---|
| F1 — P1 lower bar | **CLOSED, with stale narrative** | D.1 requires lower-95 >= 0.80. The delivered P7a contract now makes `lower_95 >= 0.80` the single binding gate and marks point 0.80 non-additive/dominated; the R3 intersection is behaviorally equivalent because the builder enforces `lower <= point`, but “pending P7a” and OQ-1 are no longer current. |
| F2 — DSR multiplicity | **CLOSED** | R3 correctly separates `selection_trial_count` from the 154-cell measurement declaration, preserves fleet `N=369` / `369+c-1`, seals per-identity and read-level multiplicity, and states PASS as rejection of the null at p<0.05. |
| F3 — predeclared power rule | **NOT CLOSED — BLOCKER** | The ESS arithmetic is correct, but R-2 never defines a numeric non-overlap pass criterion. R3 then calls it a binding “floor,” says a single window structurally fails, and requires D.1 to “satisfy” it. That conclusion does not follow from `floor(96/60)=1`: the evaluator's HAC ESS can range above one (and is clamped up to raw n); for p*=0.90 the stated ESS threshold is 35 and 37 rolling starts exist. Either R-2 is diagnostic and must not independently refute, or OWNER must predeclare a numeric non-overlap requirement. |
| F4 — omitted criteria | **CLOSED, with wording finding** | Freshness, execution fidelity, complete MTM, and clean shadow/trial are now explicit D.1 requirements. The eighth rulepack criterion is the separate OWNER purchase gate, correctly kept outside positive-evidence lift; references saying “all eight ... in D.1” should say “seven evidence criteria, with the eighth retained as the separate purchase ceremony.” |
| F5 — seal dependency surface | **PARTIAL — HIGH** | Items 1–14 add evaluator, prepared config, cost input, lineage/multiplicity inputs, calendar, and resolved choices. Since P7a landed, the evaluator and builder now import `ftmo_probability_contract.py` and its versioned JSON, and builder correlation decisions consume `portfolio_correlation.py` V4 Layer A. Those new executable/contract dependencies are absent from the seal. The listed hashes for the four modified engines are also pre-P7a bytes. |
| F6 — current-branch citations | **NOT CLOSED — HIGH** | The receipt/rulepack/DSR anchors are good, but the statement that all anchors are current at `5bac8eaccb` is no longer true at branch tip `f68ce8f338`. P7a shifted builder/timebox/MC/first-passage lines and changed their bytes. R3 already requires seal-time re-verification; it now needs that re-verification before ratification as well because operative D.1 citations are stale. |

## New blocker — C-6 estimator gates contradict P7a

The delivered versioned contract and loader are now the live code dependency:

- `tools/strategy_farm/config/ftmo_probability_contract.v1.json:20` — breach upper-95 is `INERT_UNTIL_C6_ENGINE_OWNER_APPROVED`; MC breach is only a lower bound and no upper-bound estimator is specified.
- `...:21` — P2 conditional and joint are `INERT_UNTIL_C6_ENGINE_OWNER_APPROVED`; no joint-credit formula is specified.
- `tools/strategy_farm/portfolio/ftmo_probability_contract.py:117-120` — the loader refuses any v1 contract that activates either C-6 gate.
- `tools/strategy_farm/portfolio/ftmo_timebox_eval.py:1479-1485` — results publish those inert statuses and say the outputs cannot pass or fail until C-6 approval.

R3 §D, however, becomes operative after only OQ-2a/OQ-2b and then requires breach upper-95, P2 conditional, and joint thresholds as decisive D.1 conjuncts (`OWNER_VORLAGE...:265,273-274`). The current engine still credits only the P1 bootstrap lower bound; it does not produce admissible C-6 bounds. Therefore R3 is presently unevaluable and would assign decisive meaning contrary to the contract. §D must remain inert until the C-6 method is OWNER-scoped, implemented, and approved, or the acceptance test must be versioned after an OWNER decision that lawfully changes that status.

This is not a request to design the missing estimator. No method or threshold is proposed here.

## F3 arithmetic and logic audit

The R-1 table is arithmetically correct under its stated formula, using ceiling rounding:

| p* | bar 0.80 | bar 0.70 |
|---:|---:|---:|
| 0.82 | 1,418 | 40 |
| 0.85 | 196 | 22 |
| 0.86 | 129 | 19 |
| 0.88 | 64 | 13 |
| 0.90 | 35 | 9 |
| 0.92 | 20 | 6 |
| 0.95 | 9 | 3 |

The optional R-5 table also reproduces exactly: 108/137, 72/89, 42/51, 64/82, and 34/42. Its `z_beta` values remain explicitly OWNER-choice/non-binding. The calendar arithmetic is also correct: the inclusive 2026-01-01 through 2026-04-06 span has 96 calendar days, 68 weekdays, 37 rolling 60-day starts, one non-overlapping 60-day window, and one non-overlapping 90-day gauntlet.

The defect is logical rather than arithmetic. `_hac_effective_sample()` can report more than the count of disjoint windows; R3 itself says the possible range reaches `D-59=37`. Thus “one disjoint window” does not prove HAC ESS < 9, 20, or 35. If R-1 alone binds, the actual sealed HAC ESS decides. If R-2 is also a hard floor, its threshold and relationship to ESS_min must be stated before results.

## New predeclared-item checks

- **OQ-6 roster gap: confirmed.** `D:/QM/strategy_farm/artifacts/oos_2026_confirmation_v1/campaign_plan.json` declares 55 runs (`live_count=24`, `frontier_count=31`) over 50 distinct EA/symbol pairs. `QM5_11910/NZDUSD.DWX` is absent. The file declares `diagnostic_non_admission=true` and `diagnostic_single_window=true`.
- **OQ-7 cost class: confirmed, citations shifted.** The campaign declares `cost_profile=DXZ_CANONICAL_REAL_TICKS_V1`. Current timebox code defines the accepted class at line 54, validates its cost attestation at 707-708, refuses raw DXZ at 1307-1308, and requires the explicit cost-adjusted declaration at 1310-1312. R3's old `:50/:686-693/:1286-1290` anchors no longer hit those statements.
- **Evaluator-drift precedent: confirmed historically.** The round-one hash was superseded by the dated FTMO cost-schema loader change, demonstrating why source bytes must be sealed. P7a has now changed the evaluator again; current LF SHA-256 is `c3b2fcd8f00aa28293c67384efff9faa606b8cdb4a4d892356a49b66607c3d20`.

## Citation audit — 68 target anchors sampled

The review machine-checked 68 target anchors/ranges, exceeding the required 40. A range counts as one target citation, not one per physical line.

| Surface | Targets checked | Result |
|---|---:|---|
| Receipt rows (`:8,:13,:16,:18,:20,:24,:28`) | 7 | 7 correct |
| Rulepack/provider (`:24,:151-160,:458-463,:464-469,:470-475,:476-481,:482-487,:488-493,:494-499,:500-505`, plus each parameter line `:156,:462,:468,:474,:480,:486,:492,:498,:504`) | 19 | 19 correct |
| DSR engine (`:22,:32,:33,:34,:38,:39,:40-46,:47,:54,:78-79,:93-100,:103-143,:149-150,:161-176,:182-186,:200-210,:225-228,:243-245`) | 18 | 18 correct |
| Lineage/census/fund/counter (`emit_q16_lineage.py:16-21,:179-187,:212`; its test `:112-119`; `opt_census.py:36`; `fund_score.py:94-103`; `book_build_guard.py:28,:235-239`) | 8 | 7 correct, counter refusal shifted to `:236-239` |
| Concentration/tail config (`:3,:5,:7-11,:14-17,:34-35`) | 5 | 5 correct |
| Current evaluator/builder/diagnostics representative anchors (`build_book_ftmo.py:53,:54,:75-77,:471-472`; `ftmo_timebox_eval.py:50,:72,:74,:90,:93-99,:105,:686-693,:927-953,:1126,:1286-1290`; MC `:79-81`; first-passage `:263,:371-377,:405-421`) | 11 | 0 current after P7a; the semantic statements mostly survive at new locations, except the C-6/P7a status conflict above |

Representative current replacements:

| R3 anchor | Current location / result |
|---|---|
| `build_book_ftmo.py:53/:54` | FUND_SCORE/P1 are now `:58/:59-61`; P1 is imported from the versioned contract. |
| builder correlation/weight/unit `:75-77` | Now `:82-91`; all are contract-derived. |
| timebox horizons `:72/:74`, design `:90`, bootstrap `:93-99` | Now `:79/:81`, `:97`, and `:100-106`. |
| timebox shared-day floor `:105` | Now contract-derived at `:116-118`. |
| timebox HAC `:927-953`, reported `:1126` | Now `:948-974`, reported later in the shifted result structure. |
| cost/raw-DXZ `:50/:686-693/:1286-1290` | Now `:54/:707-708/:1307-1312`. |
| `ftmo_p1_mc.py:79-81` | Shifted and now contract-bound/diagnostic-only. |
| `challenge_firstpassage.py:263` and later blocks | Shifted by the new contract/diagnostic header. |

Current engine digests that differ from R3's table:

| File | Working-copy SHA-256 | LF/git-blob SHA-256 |
|---|---|---|
| `build_book_ftmo.py` | `cb08951a7a37c0c77b7e7030b34bf686fc88a11ee5022f3a19540f982fe39617` | `f371632eeaca5e6bb5b6136680339349ae19ce40c46c68364b6fed9b76ff99d8` |
| `ftmo_timebox_eval.py` | `7282d2b62696b5cfa721e58bcf0867e000e5a9fa3faee459ef3fe35a7e20913e` | `c3b2fcd8f00aa28293c67384efff9faa606b8cdb4a4d892356a49b66607c3d20` |
| `ftmo_p1_mc.py` | `b4ae4f49d39dd60825201db86011e0a81ac560f2c88988e142abaa0b4605044b` | `a4a0a841377083b60bbd5e6da0269920ee395ac3fc452fcbb853c500a559f928` |
| `challenge_firstpassage.py` | `9eeb0609470495c86d5df18c843fc3b55579e3a0f8b453e0774abcc3bf5d8e33` | `7ff679d6b5afb0d1c440e3fd5c4061ea2e648177110d9d564cd04d543a824cee` |

The rulepack file digest remains `298ef1285eca49ea7f010ebc0a9353b5a821fccb40a025be129f5ca5314fd992`, and its embedded provider snapshot digest remains `c199b8f5f528cce5a93f4751f63394de63e5fe832483ac9c4b9d0314732d2905`.

## Minimal corrective diff — not applied

```diff
--- a/docs/ops/OWNER_VORLAGE_2026-09-05_ftmo_positive_evidence_test.md
+++ b/docs/ops/OWNER_VORLAGE_2026-09-05_ftmo_positive_evidence_test.md
@@ §C.4 R-2 and §D.1
-R-2 is a binding non-overlap floor; the single 96-day window structurally fails every ESS_min row.
-... p1_hac.effective_n >= ESS_min ... and the sealed span satisfies R-2 ...
+R-2 is a conservative diagnostic cross-check only; it does not substitute for or independently override the measured HAC ESS. Remove the claim that one disjoint window proves failure of every ESS_min row.
+... p1_hac.effective_n >= ESS_min ...
+[If OWNER instead wants a hard disjoint-window floor, state its numeric predicate and authority before any result is opened.]
@@ §D inert condition
-§D is INERT until BOTH parts of OQ-2 are resolved.
+§D is INERT until OQ-2a/OQ-2b are resolved AND the C-6 breach/P2/joint estimator is method-specified, implemented, and OWNER-approved under the versioned probability contract.
@@ §D.1 / terminology
-all eight rulepack go_criteria in D.1
+the seven evidence criteria in D.1; the eighth criterion remains the separate signed OWNER purchase ceremony and is never implied by positive-evidence-met
@@ §E seal
+Seal `tools/strategy_farm/config/ftmo_probability_contract.v1.json`, `tools/strategy_farm/portfolio/ftmo_probability_contract.py`, and the V4 Layer-A producer `portfolio_correlation.py`, with their exact LF digests and contract version.
+Recompute all engine hashes and line anchors from the post-P7a tree; replace the pre-P7a values.
@@ OQ status
-OQ-1 / P7a pending; intersection applies until delivery.
+P7a implementation delivered at f68ce8f338: binding P1 gate is lower_95 >= 0.80; point >= 0.80 is non-additive/dominated. Retire OQ-1 after OWNER confirms the delivered contract status.
```

## Disposition

Keep receipt row 18 `PENDING`. Do not open an acceptance result. Amend R3 to close the operational R-2 ambiguity, bind the delivered P7a dependencies, align §D with C-6 inertness, and refresh current anchors/hashes; then run a third exact-byte review before OWNER ratification.
