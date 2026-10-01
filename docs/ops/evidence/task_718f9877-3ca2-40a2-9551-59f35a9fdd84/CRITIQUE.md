# QM5_41119: independent critique of the prospective Q08 single-configuration declaration

Task `718f9877-3ca2-40a2-9551-59f35a9fdd84` · critic: Claude Opus (independent of the Codex creator and both Kimi deliveries) · 2026-10-02
Bound facts and hashes: `family_scope_facts.json` (same directory). Read-only: no declaration activated, no card written, no Q08 claim, no provider retry.

## Verdict: **REWORK**

The V2 declaration (`PROPOSED_DECLARATION_V2_NOT_APPROVED.json`, sha `4f1cc911…`) is supported **only at the candidate-internal level**. The `complete=true` and `research_trial_count=0` claims are not supported, so the single-configuration instrument does not fit this candidate.

### What holds (limits accepted)

1. **No candidate-internal optimisation.** The card has one locked baseline. There are 0 matching Factory optimisation rows and 0 ablation-family files. The four compile rows (2 FAIL, then repaired; 2 OK) are implementation repairs. They do not select parameters. Q03–Q07 are prescribed validation, and none of them is a search. Read narrowly as "no parameter search inside QM5_41119", `no_optimization_search=true` is defensible.
2. **Mechanical identity.** All 28 locked parameters, plus the mq5/ex5/setfile/SPEC hashes, match the current build (`verification.json`). This shows the declaration describes the current binary. It says nothing about history.

### Why it fails

3. **A loser-inclusive family exists in Factory evidence.** The chronology does not show this. On 2026-08-22, one serial campaign approved nine XAU/XAG completed-month contrarian ratio cards within about 18 hours: 41103, 41104, 41109, 41110, 41112, 41113, 41116, 41118, 41119 (git add-commits listed in the JSON). They share the pair, D1 data, monthly decision clock, equal-notional `RISK_FIXED` package and first-later-month exit. On 2026-09-26, four of them entered Q02 together:
   - QM5_41104 → Q04 FAIL
   - QM5_41110 → Q07 FAIL
   - QM5_41112 → Q08 FAIL_HARD
   - QM5_41119 → only survivor, Q08 pending

   41119 reaches Q08 because it survived among parallel cousins, which is exactly the multiple-testing that DSR deflates. The single-configuration context then forces `effective_trial_count=1`, `cohort_std_daily=0`, `losers=[]` (`dsr_single_configuration.validate_context`). That would undeflate the result completely while known losers sit in the same database. This is true even though the card predates every sibling result, so no post-hoc parameter selection is alleged.
4. **Pre-card empirical relatives.** The five rolling-ratio relatives (12577, 20157, 20161, 20263, 20268) have Q02 PASS results that predate the card. QM5_20157's Q04 FAIL was also final before the card (2026-07-26), and the card names all five. This does **not** prove they informed 41119's design, and I do not count them as five independent trials. It does make `research_trial_count=0`, a declaration of zero research bites, an affirmative claim the evidence contradicts at family scope.
5. **The chronology artifact is under-scoped and mislabelled.** It says "seven relatives explicitly named by source/card", but the card also names 41110 and 41118, and both are omitted. It also omits every Factory-tested same-campaign sibling (41104, 41110, 41112). Any acceptance built on it inherits that gap.
6. **The `candidate_configuration` unit does not exclude these relatives without postselection.** The contract's own ablation rule (`ABLATION_SEARCH_FAMILY_PRESENT`) already treats sibling configurations as search. Using distinct EA IDs in place of parameter draws changes the label, not the multiple-testing exposure.

### Minimum activation prerequisites (non-circular order)

Q08 PASS is never a prerequisite. The order is: decide the instrument → approve independently → write the card appendix → run fresh claim-time checks → claim.

- **P1. Do not activate any single-configuration declaration for 41119.** If the single-config path is the only Q08 route available, 41119 cannot honestly reach Q08 yet. Park it. Do not relabel it.
- **P2. Governed family-boundary record** (search-history ledger, `hypothesis_family` = XAU/XAG ratio contrarian, D1 data). It must enumerate all nine same-campaign cards plus 41079 and the five rolling relatives, each with its Factory status. The five compile-only cards (41103, 41109, 41113, 41116, 41118) produced no result, so they cannot have informed selection. Record them as declared-untested and count them toward the declared research count. Rebuild the chronology from this record.
- **P3. Loser-inclusive Q08 cohort.** At minimum: 41104, 41110, 41112 and 41119 on the exact Q08 window 2017.01.01–2025.12.31, with effective N ≥ 4 and real dispersion. Do not reuse the Q07 override-window seed exports. If a sibling has no governed exact-window daily series, that is INSUFFICIENT_EVIDENCE, not zero. Whether the pre-card rolling relatives enter the cohort or only the declared count is a ROT gate-contract decision. Either way, they bar a "0".
- **P4. Independent approval** of the P2/P3 instrument by a party other than its author, before the card appendix is written.
- **P5. Fresh claim-time checks:** ledger, build SHA, magic-registry closure currency, window and news-calendar.

### Information-value note (not an economic verdict)

Same-family 41112 is already Q08 FAIL_HARD. The current-rate FTMO financing sensitivity is adverse on all five Q07 paths. Before spending sibling exact-window runs on P3, weigh the expected marginal information. Parking 41119 is a legitimate outcome.
