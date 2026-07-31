# Book3 sealed-validation design — Codex adversarial review R1

Date: 2026-07-31  
Reviewed design: `docs/research/FTMO_BOOK3_SEALED_VALIDATION_DESIGN_2026-07-31.md`  
Review mode: read-only; no backtest, requeue, database write, Factory action, or sealed evaluation

## Verdict

**Agreement: 62%. R2 required.**

The design has the right safety primitives — predeclared inputs, content hashes, fail-closed costs, a conservative multi-position MAE bound, explicit censoring, and no silent `FAIL_SOFT` promotion. It does not yet support its central claim of a selection-sealed, event-complete proof:

1. the proposed seal is created after the entire historical holdout and Book3 composition were already observed;
2. the stated 1,143 / 291 / 548 inputs are hash-bound per-run streams, not the current durable Q08 aggregates;
3. `venue_cost_model.json` has no FTMO swap rates for any Book3 symbol and only an indicative XAU commission number;
4. the 102 overlapping starts are treated without a frozen dependence/ESS contract;
5. an open/close timeline plus lifetime MAE is a conservative bound, not an event-complete shared-equity trace, and the required money/cost fields and CE(S)T anchor arithmetic are underspecified; and
6. the requested window ends at “last complete month”, but the bound streams end in December 2025 while the last complete month on the review date is June 2026.

Per the brief, the implementation threshold is 90%. `book3_sealed_eval.py` and tests were therefore **not** implemented in this round, and no sealed method was run.

## 1. Selection leakage and seal semantics

### Critical finding: the historical holdout cannot be retroactively sealed

The existing evaluator already records the controlling fact:

```text
selection_sealed_before_strategy_choice: false
selection_bias_debt: all three EAs were already observed or selected using the 2018-2025 vintage
```

The composition process used a 15-sleeve pool, tested 165 unordered runner-plus-2/3-satellite sets on its IS portion, retained 35 Q09-passing sets, and published OOS results for every retained set. Book3 (`9936+10145+13108`) was rank 17 in that published table and was selected later under deployment/timer-safety constraints. Thus the OOS outcomes were available before Book3 was locked. Calling the next JSON “attempt #1” does not erase that exposure.

Honest consequences:

- A run over the existing 2018–2025 bytes must remain `HISTORICAL_DIAGNOSTIC_NOT_SELECTION_SEALED` and cannot lift the selection-sealed blocker.
- The historical search ledger has a lower bound of **165 composition candidates**, not one. The 35 passing sets and within-set permutation search must also be recorded. Other earlier Book variants make the full research-family count larger; if it cannot be reconstructed, record `n_trials: UNKNOWN_LOWER_BOUND_165` rather than `1`.
- Declaring trial count is necessary but does not make a previously inspected holdout unseen. A multiplicity adjustment can temper a descriptive claim; it cannot restore a sealed claim.
- Re-running composition selection “IS-only” now on the same split also does not restore blindness, because the method and deployability choice were developed after OOS exposure.
- A genuine attempt #1 needs prospective bytes that did not exist at seal time, or an independent untouched data source/account. The exact-profile Free Trial/shadow is the cleanest prospective route. Until then, the historical tool can be valuable, but only as a conservative diagnostic.

There is also a boundary error. The original composition IS ended **2022-09-15** and its OOS began **2022-09-16**. The proposed `2022-09-01` boundary overlaps the selection sample by 15 days. Even for a descriptive rerun, the earliest consistent boundary is 2022-09-16.

### Seal workflow required in R2

Separate the workflow into two commands and commits:

1. `prepare-seal` may read only explicitly truncated IS inputs and emits exact multipliers, optimizer identity, search space, tie-breaker, trial ledger, stream identities, explicit evaluation start/end, and simulator commit.
2. After independent implementation review, `evaluate` receives an expected seal SHA-256 on the command line, verifies it before opening any holdout stream, verifies every stream hash, and then evaluates once.

A sibling `.sha256` file alone is not an authority boundary because both files can be replaced together. Bind the seal blob to a committed Git object and require the expected digest from the reviewed handoff/receipt.

## 2. Statistical review

### Primary CI method

Use a **moving-block bootstrap**, not Newey–West, as the primary interval. First-passage pass/breach/censor outcomes are bounded, nonlinear, and phase-dependent; a normal/HAC interval on 102 binary outcomes is a weaker approximation. Newey–West is useful only as a sensitivity check and as one ESS diagnostic.

Do not bootstrap sleeves independently and do not multiply sleeve windows. Resample the one merged Book3 Prague-day/event vector and recompute both phases for each bootstrap path. Blocks must start and end at an all-sleeves-flat state so a multi-day position is never cut or fabricated.

Freeze block selection using IS only:

- compute a deterministic autocorrelation-length candidate over both the joint realized-PnL series and the pessimistic-low series, using a predeclared lag/search rule;
- set the target block length to `max(20 CE(S)T calendar days, IS-derived candidate)`; 20 is the already-used diagnostic floor;
- extend each target endpoint forward to the first all-sleeves-flat boundary; and
- seal the resulting target length, algorithm version, and sensitivity lengths (half and double the target) before holdout access.

The design's current phrase “block length from significant autocorrelation lag” is not executable: it leaves series choice, significance rule, maximum lag, isolated-significance handling, and flat-boundary behavior open until after data are seen.

### Overlapping starts and ESS

The 102 starts are 102 dependent views of one common 2024–2025 book path, not 102 independent Bernoulli trials. The existing diagnostic reports median two-phase completion of 187 days for the scenario behind the 81.37% headline (159 days for the official 1x scenario). Against roughly 731 calendar days, a geometric sanity check is only about **3.9 median-length non-overlapping horizons**, before allowing for longer tails. That is not a formal ESS, but it proves that `n=102` is not a defensible precision claim.

R2 must report all of:

- raw overlapping starts and outcomes;
- a deterministic greedy non-overlapping-start count;
- HAC ESS of the ordered outcome indicator, with the bandwidth frozen from IS; and
- the moving-block-bootstrap interval from the joint series.

For a diagnostic ESS, use the Bartlett-weighted form
`ESS = N / (1 + 2 * sum((1-k/(K+1))*rho_k, k=1..K))`, clipped to `[1,N]`, and publish `K` and the autocorrelations. This does not replace the bootstrap CI.

Even under the false independence assumption, 83 passes in 102 starts gives a two-sided 95% Wilson lower bound of **72.73%** (one-sided 95%: **74.25%**), already below 80%. Dependence can only make the honest uncertainty materially wider. A lower-bound threshold of 80% is therefore a likely refutation on these data, which is acceptable under the honesty clause, but the design should state this power limitation before running.

### Censoring and start set

“Censoring reported” is insufficient. Pin the common start set as simultaneous-account-flat CE(S)T days with at least one new Book3 position, and pin one of these rules before evaluation:

- gate-conservative: every right-censored start is a non-pass; or
- exclude starts lacking a predeclared minimum follow-up, determined without their outcome.

The existing diagnostic uses the first rule. It should remain the default. One start produces one book outcome; it must never produce three sleeve observations.

The proposed 80% CI-lower-bound criterion is also different from the earlier Book3 preregistration (phase-1 lower bound 70%, joint two-phase point estimate 65%). It may be added as a stricter supplemental Book3 seal gate, but it must be labelled as such and ratified by OWNER; it must not silently redefine Q08 or `challenge_ready`.

## 3. Event-trace review

### What the MAE construction can prove

For each interval, this quantity is a valid lower bound if its operands are complete and consistently costed:

```text
pessimistic_equity = realized_balance_at_event
                     + sum(minimum_lifecycle_floating_PnL of every position open at event)
```

Each actual open-position PnL is at least its own lifetime minimum, so summing all minima simultaneously is deliberately physically impossible but conservative. Applying the same minimum on every CE(S)T day crossed by a multi-day position is conservative as well. A start may be certified only when this lower bound remains above both official floors; realized close-only balance is appropriate for target recognition.

That is a `CONSERVATIVE_LIFETIME_MAE_BOUND`, not an “event-complete trace”: `mae_acct` does not locate the MAE timestamp, and the inputs have only open/close events. R2 should change the label. A bound can still be a sufficient no-breach proof, but it does not reproduce actual shared equity.

### Missing executable details

R2 must pin these semantics:

- actual close field is `time`, not `close_time`; timestamps are UTC epoch seconds and must be converted with `ZoneInfo("Europe/Prague")`, including both DST transitions;
- position lifetime is a half-open event interval with deterministic ordering for equal timestamps; every crossed Prague calendar day is represented;
- official daily floor is `midnight_balance - 0.05 * initial_capital`, not a fixed-offset UTC bucket and not an equity-reset heuristic; total floor is `0.90 * initial_capital`;
- full-lifecycle rows require `money_basis=FULL_POSITION_LIFECYCLE_ACTUAL_V1`, finite component reconciliation, and entry commission included in the pessimistic MAE treatment. `mae_acct` itself is framework floating PnL and does not contain all lifecycle costs;
- target is recognized only while flat/after the relevant closes, minimum trading-day rules are applied, phase transition/reset semantics are explicit, and right-censored outcomes never become passes;
- FTMO cost replacement must say which existing stream components are removed and which FTMO commission/swap components are inserted, to prevent double counting;
- swap accrual is allocated to the actual CE(S)T rollover days, including the sealed triple weekday; and
- margin needs side, volume, entry/mark price, contract size, calculation mode, and conversion rate. The four fields listed in Component 2 are insufficient.

The proposed leverage diagnostic is also wrong for the named **Swing** profile. The 2026-07-30 official-provider snapshot records `leverageSwing` of 30 for USDJPY and 15 for both XAUUSD and USOIL.cash, whereas the design lists standard-like 1:100 / 1:50 / 1:30 values and omits oil's category. Use the hash-bound provider rows and profile-specific leverage; do not hard-code the current sentence.

## 4. Read-only prechecks

### A. Expected per-run streams and `entry_time`

The hash-bound native streams from the existing evaluation manifest all parse without error and have 100% `entry_time`, `time`, and `mae_acct` coverage.

| Rung | Path | Rows | `entry_time` | Entries on/after 2022-09-01 UTC | SHA-256 |
|---|---|---:|---:|---:|---|
| R0 9936/USDJPY | `D:\QM\reports\work_items\1e9a2b35-e92b-585f-9bf4-b8dee0a95c27\q08_trades_9936_USDJPY_DWX.timer_v2.jsonl` | 1,143 | 1,143 (100%) | 496 | `1593ee930e1550236f1c851805d3a71ccdb4c2a244de6994b3dbbf4bf450f7ff` |
| R1 10145/XAUUSD | `D:\QM\reports\work_items\298079e0-d162-5a86-ab2f-530b3f319f22\q08_trades_10145_XAUUSD_DWX.timer_v2.jsonl` | 291 | 291 (100%) | 141 | `cba8eac2aab23b68c6846ac7848e7da818cc4608912a9dd83e4f89e75d4af425` |
| R2 13108/XTIUSD | `D:\QM\reports\work_items\2c92e30e-df68-51fe-b1f8-d90901f43dc8\q08_trades_13108_XTIUSD_DWX.timer_v2.jsonl` | 548 | 548 (100%) | 253 | `136cc04da36b766572843cd496a3770aca694d2eb279f389be4cc2d36ca72179` |

Each bound `summary.json` has one OK run with exactly the same 1,143 / 291 / 548 trade count. Current bytes match the stream hashes in `evaluation_manifest.json`; that manifest itself matches SHA-256 `fdd26cc9d794c8420ab2f2914aa147f60dc3bdc3a7c4df8bd3c05d2ad91081ab`. The existing receipt records `native_stream_reconciliation: PASS`.

The three maximum close timestamps are 2025-12-30, 2025-12-30, and 2025-12-30 respectively. Therefore `[2022-09-01, last complete month]` is not satisfiable on 2026-07-31: June 2026 data are absent. Pin an explicit end no later than 2025-12-30 for a historical diagnostic, or obtain new hash-bound data for a prospective test.

### B. Durable aggregate versus per-run provenance

The Q08 aggregates point to different streams:

| Sleeve | Latest Q08 verdict | Aggregate-linked rows | Aggregate stream SHA-256 | Relationship to 1,143/291/548 input |
|---|---|---:|---|---|
| 9936/USDJPY | FAIL_SOFT | 1,252 | `ba08c8f4bd69e6f296f3d55c58b12aabd4ff4cca9786a4ff1f4c49cd296f4474` | different count and bytes |
| 10145/XAUUSD | PASS | 314 | `b7828167b02d8440ce1956be570f13e56a95b0e26730b776f28086e10bb79c2d` | different count and bytes |
| 13108/XTIUSD | FAIL_SOFT | 553 | `5a5418b391a3a194041f8f851536a2f3080cd5c4b794590db3399ba17700f3f5` | different count and bytes |

The current durable aggregate files do have 100% `entry_time` and `mae_acct`, but they are legacy-shaped and do not carry side, entry/exit price, or full-lifecycle component fields needed by the proposed FTMO cost and margin calculations. Only the 9936 aggregate currently binds `portfolio_stream.content_sha256`; the two older aggregates are count-only lineage.

The 1,143 / 291 / 548 inputs are durable, immutable **per-run evidence copies**, bound to their exact summaries, reports, receipts, and staged evaluation manifest. They are not the aggregate streams named by the latest Q08 artifacts. R2 must choose one contract explicitly:

- use the per-run evidence set and seal its full manifest/report/summary lineage; or
- publish new aggregate artifacts that point to those exact bytes and pass the trade-count/hash doctrine.

Path convention or equal-looking filenames are not evidence. Mixing the recent per-run count with the current aggregate label is a setup mismatch.

### C. `venue_cost_model.json`

Checked file: `C:\QM\repo\framework\registry\venue_cost_model.json`, SHA-256 `7dfafe53749e5c45be0cb37568b6e3491c109f546fafaf799f6ea82efdb688d7`.

| Symbol | FTMO commission in registry | FTMO swap in registry | Result |
|---|---|---|---|
| USDJPY | flat USD 5 per round-trip lot | `swap_note: null`; no long/short rate | missing swap |
| XAUUSD | percent-notional model with USD 20.37/lot labelled **indicative** | `swap_note: null`; no long/short rate | exact commission field and swap missing |
| XTIUSD | commission-free, USD 0 | `swap_note: null`; no long/short rate | missing swap |

The registry explicitly says swap is open for all symbols, and `build_joint_sim_manifest.py` independently documents that this registry “carries no swap points.” The design's fail-closed cost precondition therefore fails today.

The separate official-provider snapshot `docs/ops/evidence/2026-07-30_ftmo_book3_symbol_cost_snapshot.json` (SHA-256 `7eab3bf8c97373fcb44e36aca39dd679fbd3e093783cd6eacd9cb171190b3280`) contains dated USDJPY, XAUUSD, and USOIL.cash commission and swap values. R2 may name and hash this snapshot as a separate required input, subject to its age/profile/contract normalization. It must not claim those values came from `venue_cost_model.json`, and applying one current swap snapshot over 2018–2025 must be labelled a fixed current-terms counterfactual rather than historical realized swap.

## 5. Answers to the five open questions

1. **CI method:** moving-block bootstrap of the single joint Prague-day/event vector, with full path re-evaluation. Newey–West is sensitivity/ESS only. Freeze the IS-only block rule described above, use all-sleeves-flat block boundaries, report half/double-length sensitivity, raw starts, greedy non-overlap count, and HAC ESS. Never use 102 as an independent `n`.

2. **Boundary:** 2022-09-01 is not acceptable. It overlaps the original selection IS through 2022-09-15, the OOS was later inspected, and the streams stop in December 2025. R2 has 253 trades entering on/after 2022-09-01, so the raw trade count is adequate for a descriptive trace, but it does not establish independent start count or CI power. Use 2022-09-16 only for an explicitly unsealed historical diagnostic; use a post-seal future boundary for a genuine sealed claim.

3. **Multiplier source:** no located IS artifact pins three unequal Book3 multipliers. The existing composition artifact pins equal weights, and the bound standalone manifest pins `base_risk_fixed=1000` for each sleeve. The only defensible no-search baseline is therefore per-sleeve multiplier 1.0, with phase-2 0.75 treated as a separate policy parameter if that scenario is intended. Any unequal multiplier requires a pre-seal IS-only optimizer whose code, truncated input hashes, complete grid/search count, objective, constraints, and deterministic tie-break are all sealed. It still cannot make the already-viewed historical OOS unseen.

4. **Provenance:** R1/R2 (and R0) 1,143 / 291 / 548 streams are per-run evidence copies, not the current Q08 aggregate streams. They have strong manifest/summary/report lineage and exact trade-count matches, so they are usable if the seal explicitly chooses the per-run-evidence contract. The durable aggregates contain 1,252 / 314 / 553 rows and different hashes.

5. **XTIUSD swap:** no. `venue_cost_model.json` has FTMO XTIUSD commission-free USD 0 but no swap long/short values. The dated official-provider snapshot has USOIL.cash `swapLong=4.22`, `swapShort=-26.8` points and the 1000-to-100 contract normalization, but it is a separate artifact and must be explicitly adopted, hash-bound, and interpreted.

## 6. Other design contradictions to close

- A function that reads mutable `farm_state.sqlite` is not a pure function of `(seal JSON, stream files)`. Put exact Q08 evidence artifacts and hashes in the seal. Make a live DB check a separately labelled advisory snapshot, or bind a read-only DB snapshot as an explicit input; do not let mutable DB state change the statistical verdict.
- Component 1 says raw +10%/+5% targets, while the 81.37% headline came from capture buffers and a 0.75x Phase-2 policy surrogate. Pin official and internal-policy scenarios separately; do not compare unlike contracts.
- Component 2 cannot both claim event completeness and rely only on lifetime MAE. Use the conservative-bound label and preserve the exact-event blocker unless the bound's sufficient-proof conditions all pass.
- Component 4's four input fields cannot support cost replacement or margin. Require the full lifecycle-v1 schema used by the 1,143 / 291 / 548 streams.
- Exact-profile Free Trial/shadow remains out of scope, so even a successful historical bound cannot clear all four blockers listed in the design's opening. Final status must remain `NO_GO` / `strict_qualification: UNVERIFIED` until that separate OWNER-authorized evidence exists.

## R2 acceptance conditions

R2 can reach the implementation threshold when it:

1. labels existing-history results as unsealed diagnostics and defines a genuinely prospective seal route;
2. replaces `n_trials=1` with the reconstructed research-family ledger (at least 165 historical compositions);
3. pins exact start/end dates, common-flat start eligibility, censoring, scenario, multiplier, phase transition, and block/ESS rules;
4. chooses one stream provenance contract and binds every report/summary/receipt/hash needed by it;
5. names the actual cost snapshot, money replacement arithmetic, rollover allocation, Swing leverage, and missing-data refusal;
6. labels the MAE output as a conservative lower-bound trace and specifies full lifecycle/CE(S)T event arithmetic; and
7. removes mutable live DB state from the statistical verdict inputs.

No pipeline, gate, `challenge_ready`, live, Factory, terminal, set-file, or account state was changed by this review.
