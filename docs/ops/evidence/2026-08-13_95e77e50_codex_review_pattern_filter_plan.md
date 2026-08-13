# Codex adversarial review — Pattern-Permission-Filter plan

- Router task: `95e77e50-55ec-452e-8945-38c2a701ea83`
- Review date: 2026-08-13
- Reviewed plan: `docs/research/PATTERN_PERMISSION_FILTER_PLAN_2026-08-13.md`
- Reviewed repository revision: `d284fb61d6b4f03f9a028fb504bf7a2f62cd592f`
- Reviewed plan blob: `c7e4eb1abc0c2321d54adf808abf7d491d698394`
- Scope: review only; no EA, framework, registry, queue, terminal, or pipeline mutation
- Verdict: **PLAN_REQUIRES_REVISION_BEFORE_IMPLEMENTATION**

## Executive decision

The plan is directionally sound in three important respects: it correctly identifies that the
trial ledger is not wired into the current DSR/PBO gates; it correctly rejects
`Strategy_NoTradeFilter()` as the generic placement for a new-entry veto; and avoiding an
include from `QM_Common.mqh` can preserve existing fleet binaries. The sampled runtime also
supports approximately 46 hours as an ideal full-fleet lower bound.

It is not yet safe to implement. The current text has blockers in the statistical-family
contract, PBO evidence construction, categorical selection rule, actual pending-order hook,
census binary identity, Q14 sharding/global selection, history validity, and the claimed
offline reconstruction. A census launched from the current plan could either measure the
wrong strategy or select a false winner while appearing ledger-complete.

## Findings

### 1. **BLOCKER — A declared scalar trial count is not the correct DSR/PBO repair** `[F1]`

The factual B3 claim is **verified**. DSR uses the hard-coded
`N_CANDIDATE_STRATEGIES = 369` and a constant dispersion at
`framework/scripts/q08_davey/sub_8_2_dsr_mc_fdr.py:34,134-137`. PBO obtains
`n_configs` from the rows loaded from `scores.csv`, not from an optimization ledger
(`framework/scripts/q08_davey/sub_8_7_pbo.py:100-113`). Therefore
`docs/research/PATTERN_PERMISSION_FILTER_PLAN_2026-08-13.md:159-168` is right about the
missing wire.

The proposed P0 repair at `docs/research/PATTERN_PERMISSION_FILTER_PLAN_2026-08-13.md:185-190`
is nevertheless underspecified and, if interpreted literally, wrong. DSR requires the
dispersion of Sharpe estimates across the selection family and the number of independent or
effective trials; PBO requires the actual configuration-by-slice matrix. Passing the same
`declared_trial_count` scalar into both does not supply either object. See Bailey and López de
Prado, *The Deflated Sharpe Ratio*, sections 3 and 4 and its appendix:
https://www.davidhbailey.com/dhbpapers/deflated-sharpe.pdf.

For a fixed-mode, one-winner-per-sleeve census, seal a distinct `experiment_family_id` and
154 selectable configurations for that sleeve. Count 155 only if OFF is itself eligible to be
selected; otherwise OFF is the paired benchmark, not another searched alternative. The two
determinism runs are replicas of each configuration and must never increase the trial count.
If whitelist and blacklist are both searched, the family is 308 configurations before any
control. Estimate candidate Sharpe dispersion and effective independent trial count from the
complete, correlated candidate return matrix. Keep the parent's upstream selection gate and
the incremental filter-search gate as explicit lineage layers; do not silently compute
`369 + 154`, because the provenance of 369 is only “rough V5 candidate count” and cannot show
whether that would omit or double-count prior searches. Across nine separately selected
sleeves, pre-register a second-stage family correction (for example, BH over valid sleeve-level
p-values if the result is called FDR) rather than pretending that nine unrelated symbols are
one homogeneous Sharpe population.

### 2. **BLOCKER — The current DSR magnitudes are not evidentiary; calibration must precede census** `[F1]`

`sharpe_std_estimate = 1.0` is explicitly a placeholder
(`framework/scripts/q08_davey/sub_8_2_dsr_mc_fdr.py:35-40,134-137`). The runner receives a
portfolio only to count peers and never derives the candidate Sharpe distribution
(`framework/scripts/q08_davey/sub_8_2_dsr_mc_fdr.py:105-137`). Its p-values therefore cannot
be interpreted as calibrated DSR. The source comment expects the current threshold to be too
harsh, but without the distribution the magnitude and even the degree of miscalibration are
unknown. “Document as a limitation” is insufficient for a gate that will decide census
winners.

There are two additional unit/sample defects. `_trade_returns_per_day()` emits only days on
which a trade closed (`framework/scripts/q08_davey/sub_8_2_dsr_mc_fdr.py:45-58`), so rare
filters receive a different observation calendar and omit zero-return days. The code then
annualizes Sharpe with `sqrt(252)` and inserts that annualized value directly into the
finite-sample PSR variance expression
(`framework/scripts/q08_davey/sub_8_2_dsr_mc_fdr.py:61-77,90-100`). The repair should use one
complete sealed daily calendar for every configuration, including zeros; compute per-period
Sharpe, its cross-trial dispersion, and the PSR/DSR variance in consistent units; and annualize
only for display. Also, the advertised FDR layer does not exist: the code explicitly says that
there is no batch BH-FDR pass (`framework/scripts/q08_davey/sub_8_2_dsr_mc_fdr.py:148-150`).

### 3. **BLOCKER — Current PBO construction can mix families and silently delete losing configurations** `[F1]`

The current fallback discovers every completed Q03 PASS/FAIL for an EA/symbol and deduplicates
only by effective setfile hash; it has no card, census, or experiment-family predicate
(`framework/scripts/q08_7_pbo_runner.py:176-210`). It then drops a configuration with no parsed
trades (`:243-257`), derives slice boundaries from the earliest/latest observed trade in the
surviving family (`:260-268`), and drops any configuration/slice with no win or loss
(`:113-126,271-287`). The chosen `n_configs` is merely the surviving dictionary length
(`:336-388`). A restrictive predicate can therefore disappear instead of receiving a losing or
predeclared no-trade score, while unrelated historical Q03 surfaces can enter the family.

PBO for the census needs a sealed exact-membership manifest, fixed DEV calendar slices shared
by all configurations, an explicit score for zero-trade slices, and fail-closed rejection of
missing, extra, duplicate, or unbound configurations. Verify the two replicas, then collapse
them to one configuration row. The declared count should be a completeness assertion against
that matrix, not a numerical “deflator.”

### 4. **BLOCKER — “Winner in two of three thirds” does not replace categorical robustness** `[F2]`

The existing Q15 rule verifies both a 5% plateau and a neighboring numeric setting
(`framework/scripts/q15_freeze_check.py:507-544`). The proposed categorical rule only says
that the winner beats the DEV metric and leads in at least two time-thirds
(`docs/research/PATTERN_PERMISSION_FILTER_PLAN_2026-08-13.md:146-155`). It tests temporal sign
consistency, but not local/semantic sensitivity, precision, or adequate exposure.

Concrete counter-example: a predicate intersects two base entries in the first third, one in
the second, and none in the third; three lucky outcomes can lead two thirds and satisfy the
worded rule. A second predicate can be a near-duplicate whose tiny implementation boundary
change reverses the result, yet temporal thirds never exercise that fragility.

Before ranking, require every candidate to pass pre-registered, outcome-blind eligibility
floors for base entry opportunities, predicate-at-entry matches, and affected-side trades both
overall and in every third. Freeze those floors from a prevalence/power audit before inspecting
performance. Compare a paired delta against the same-window OFF control with a minimum
improvement and a block-aware uncertainty test; retain two-of-three direction consistency only
as an additional check. Where predicates have natural semantic neighbors, predeclare
equivalence/perturbation clusters and require robustness within the cluster rather than treating
an arbitrary enum neighbor as meaningful.

### 5. **BLOCKER — The selection metric and no-change comparison are not specified** `[F2, F7]`

The plan repeatedly says “the metric” without naming its formula, minimum improvement,
trade/exposure floor, tie-break, treatment of invalid/no-trade candidates, or whether drawdown is
a constraint or part of the objective
(`docs/research/PATTERN_PERMISSION_FILTER_PLAN_2026-08-13.md:152-155,202-205`). Q15 only checks
that the card names a MAXIMIZE metric and then ranks its supplied scalar
(`framework/scripts/q15_freeze_check.py:393-398,458-485,528-544`); it does not invent a safe
metric contract.

Freeze one primary DEV objective, minimum improvement over OFF, hard risk/trade eligibility,
and deterministic tie-break before the census. OFF must be run with the same filter-capable
binary, setfile contract, DEV window, and replicas, not borrowed from an older Q10 report. The
FTMO/DXZ drawdown and news requirements remain hard eligibility constraints, not optional
tie-breakers (`docs/ops/EDGE_LAB_CHARTER_2026-05-22.md:22-36`). Without this contract, the
emitter can choose different winners while all current schemas still validate.

### 6. **MAJOR — A “buy-only” or “sell-only” trial has no defined unaffected-side behavior** `[F2, F5]`

The plan counts `77 × 2 directions` but also retains whitelist/blacklist mode
(`docs/research/PATTERN_PERMISSION_FILTER_PLAN_2026-08-13.md:58-60,195-197,209-217`). In the
reference, whitelist mode with no sell predicate sets `allowSell=false`; an ostensibly buy-only
trial therefore blocks the sell side too
(`C:/Users/Administrator/Downloads/QuantRangePRO - vers2/Hyonix/Breakout7/QuantRangePRO - vers2/PatternFilter.mqh:476-523`).

Each ablation must explicitly pass the unaffected direction through unchanged, and the ledger
must bind target direction plus mode. Freeze one mode ex ante or count both. Otherwise the
trial labeled “buy predicate 17” is not an isolated buy-side ablation and the 154-cell surface is
not reproducible.

### 7. **BLOCKER — The proposed outer hook is already too late in QM5_13213 and QM5_13301** `[F3]`

The skeleton diagnosis is correct: `Strategy_NoTradeFilter()` returns before management and
exit processing (`framework/templates/EA_Skeleton.mq5:189-212`), while a conventional
single-request entry is opened at `:238-241`. But both named range-breakout EAs have side effects
inside `Strategy_EntrySignal()`:

- QM5_13213 opens the buy stop internally, prepares the sell stop for the caller, and marks the
  day complete at
  `framework/EAs/QM5_13213_balke-gmt3-range-breakout/QM5_13213_balke-gmt3-range-breakout.mq5:310-317`;
  the caller opens only the returned sell at `:517-521`.
- QM5_13301 does the same at
  `framework/EAs/QM5_13301_balke-minute-range-breakout/QM5_13301_balke-minute-range-breakout.mq5:334-341,543-547`.

An outer veto between the function return and the caller's `QM_TM_OpenPosition` can suppress
the sell but cannot undo the buy already placed. It also permits state mutation before the
decision. Refactor each integration so signal construction is side-effect free and returns both
requests, then apply one side-aware permission decision immediately before every order-placement
call. Update the day/order state only from defined placement outcomes.

### 8. **MAJOR — Pending-order permission lifetime and cancellation are undefined** `[F3]`

QM5_13213 and QM5_13301 place `BUY_STOP`/`SELL_STOP` orders that can rest after the placement
decision
(`framework/EAs/QM5_13213_balke-gmt3-range-breakout/QM5_13213_balke-gmt3-range-breakout.mq5:129-176,267-317`;
`framework/EAs/QM5_13301_balke-minute-range-breakout/QM5_13301_balke-minute-range-breakout.mq5:148-177,289-341`).
Existing lifecycle code later removes the opposite order after a trigger
(`framework/EAs/QM5_13213_balke-gmt3-range-breakout/QM5_13213_balke-gmt3-range-breakout.mq5:320-347`;
`framework/EAs/QM5_13301_balke-minute-range-breakout/QM5_13301_balke-minute-range-breakout.mq5:344-357`).
The plan defines neither whether
permission is latched at placement nor what happens when the closed reference bar/profile
changes while an order is pending.

Define the contract explicitly. Under fail-closed permission semantics, a new reference-bar
decision that forbids a resting direction should remove that direction's pending order (and
invalid data should remove/block both), while never suppressing open-position management or
exits. Test both allowed, buy-only, sell-only, neither, invalid history, day flip while resting,
one placement failure, restart, and opposite-trigger cancellation. A boolean veto at trigger
time alone is ineffective because broker-side pending activation does not call the EA entry
hook.

### 9. **BLOCKER — P3 has no lawful, hash-bound executable subject for the census** `[F4, F7]`

P1 creates only a reusable include; it does not make any of the nine EAs call it. P3 then runs
the census, while P4 defers new EA identities until after selection
(`docs/research/PATTERN_PERMISSION_FILTER_PLAN_2026-08-13.md:192-205,209-241`). Existing
binaries cannot execute the filter, and changing an incumbent EA source/binary in place would
destroy the control identity and lineage behind the “byte-identical fleet” claim at `:45-52`.

Allocate a research-only, non-live census identity (or an equivalently governed harness) before
P3. Bind every result to source SHA, EX5 SHA, setfile SHA, card/family ID, predicate, direction,
mode, and DEV window. Prove default-OFF equivalence to the incumbent before using it as the
control. If the selected production challenger is compiled differently from the census binary,
repeat equivalence and the selected DEV configuration on the final identity. New identities
also require deterministic EA and magic registry rows; the prior portability design already
states that contract at
`docs/research/CODEX_UNGER_REFERENCE_PORTABILITY_2026-08-12.md:278-287`.

### 10. **MAJOR — The “no schema/setfile change” blast-radius claim is false** `[F4]`

The two proposed inputs are `qm_filter_pattern_enabled` and `qm_pattern_profile`, but
`gen_setfile.ps1` automatically collects only inputs in group `Strategy` or with a
`strategy_*` prefix (`framework/scripts/gen_setfile.ps1:267-280`). Card defaults can rescue
exact matching inputs (`:467-483`); missing-card fallback cannot (`:490-503`). The live invariant
only proves that *some* `strategy_*` line exists (`:505-506`), so unrelated strategy settings can
let a filtered identity pass while both filter values are absent. The extra `Filters` group does
not violate the five required groups in `framework/scripts/build_check.ps1:825-843`, but no
current lint proves this filter contract.

The schema/validator blast radius is also larger than listed:

- Q14 hard-codes its supported levers at `framework/scripts/q14_opt_admission.py:204-228`.
- `opt_card.v1` omits `PREDICATE_ABLATION` at
  `tools/strategy_farm/config/opt_card.v1.schema.json:94-101`.
- The freeze schema repeats that enum and hard-codes
  `enable_input = strategy_opt_enabled` at
  `tools/strategy_farm/config/opt_card_freeze.v1.schema.json:58-79`.
- Q15 itself hard-codes the same enable input and numeric candidate values at
  `framework/scripts/q15_freeze_check.py:43,366-390,575-581,769-774`.

Either use the existing `strategy_opt_enabled` contract and a `strategy_*` profile input, or
generalize the generator, schemas, equivalence evidence, Q15 checks, and filtered-live invariant
together. Preserve default-OFF fail-closed validation. The include alone causes no fleet
recompile; integrating it into new EAs does require the normal identity/registry work.

### 11. **BLOCKER — The proposed card bundling does not fit Q14 or preserve global selection** `[F5]`

Q14 rejects more than 64 trials per card
(`framework/scripts/q14_opt_admission.py:375-424`). Therefore 154 configurations require at
least three cards; the plan's example “one card per direction” still puts 77 in each and fails
the cap (`docs/research/PATTERN_PERMISSION_FILTER_PLAN_2026-08-13.md:202-207`). The current
program also permits only two open cards per parent
(`tools/strategy_farm/config/opt_program.v1.json:9-11`). More fundamentally, Q14 currently
constructs one candidate/card for each parent/lever and has no shard dimension
(`framework/scripts/q14_opt_admission.py:572-616`). Merely raising caps cannot create three
coherent shards.

Q15 validates and selects one winner per card
(`framework/scripts/q15_freeze_check.py:421-544,686`), so naïvely sharding produces three local
winners, not one winner from 154, and understates
multiplicity. Add a sealed logical family spanning shards, deterministic shard IDs in card and
ledger identity, exact union/completeness checks, and one family-level selection after every
shard closes. No shard may independently emit a challenger. If both modes are searched, design
for at least five 64-trial shards rather than three.

### 12. **MAJOR — The arithmetic omits modes and controls; replicas must not become hypotheses** `[F5]`

The stated 2,772 runs are exactly `9 × 77 × 2 directions × 2 replicas`
(`docs/research/PATTERN_PERMISSION_FILTER_PLAN_2026-08-13.md:209-218`). They do not include a
same-binary OFF control. They also do not include whitelist/blacklist mode even though mode is a
profile dimension at `:58-60,195-197`. With both modes searched, the design is 308
configurations per sleeve and 5,544 candidate runs before controls. With one frozen mode, add
the explicitly repeated OFF controls and keep 154 as the statistical trial count; 308 execution
runs are not 308 hypotheses.

The plan must publish one unambiguous equation separating candidate configurations, control
configurations, determinism replicas, retries, and total terminal executions. That same manifest
must drive Q14, the runner, DSR, PBO, Q15, and completeness verification.

### 13. **MAJOR — Forty-six hours is a defensible lower bound, not a paced-fleet forecast** `[F5]`

A read-only sample of one recent complete report for each frozen pair gave these wrapper
durations, measured from the run-directory UTC tag to `summary.json.timestamp_utc`:

| Pair | Minutes | Report |
|---|---:|---|
| QM5_13213 / USDJPY.DWX | 13.59 | `D:/QM/reports/work_items/6d58f343-d5b6-44f8-a35a-9a76990a87ca/QM5_13213/20260805_180018/summary.json` |
| QM5_10706 / GBPUSD.DWX | 5.23 | `D:/QM/reports/work_items/89ab3816-8428-4233-9446-36be8bf31251/QM5_10706/20260806_020516/summary.json` |
| QM5_10692 / NDX.DWX | 9.31 | `D:/QM/reports/work_items/10c85a72-ebea-451a-9b38-82b3c4f6aee7/QM5_10692/20260726_045203/summary.json` |
| QM5_10911 / GDAXI.DWX | 16.48 | `D:/QM/reports/work_items/893458b6-e143-4ef8-8550-903599ee32e5/QM5_10911/20260805_183954/summary.json` |
| QM5_13301 / GDAXI.DWX | 5.17 | `D:/QM/reports/work_items/8ac4c99e-6c0d-4263-af55-785920a129e7/QM5_13301/20260729_103347/summary.json` |
| QM5_11422 / USDCAD.DWX | 5.26 | `D:/QM/reports/work_items/7922733b-c27e-4829-9f21-2c8e1e16e03e/QM5_11422/20260802_230626/summary.json` |
| QM5_10128 / XAUUSD.DWX | 7.87 | `D:/QM/reports/work_items/9903b3e1-5e2a-4292-9c50-5f41e30077a7/QM5_10128/20260726_185102/summary.json` |
| QM5_10145 / XAUUSD.DWX | 9.55 | `D:/QM/reports/work_items/298079e0-d162-5a86-ab2f-530b3f319f22/QM5_10145/20260730_001007/summary.json` |
| QM5_10183 / XAUUSD.DWX | 12.14 | `D:/QM/reports/work_items/d364527c-367d-4fbc-a3f3-5e7924a44510/QM5_10183/20260721_034554/summary.json` |

Mean was 9.40 minutes and median 9.31. At ten continuously available workers, 2,772 runs imply
43.43 ideal fleet-hours, so 46 hours is reasonable only before controls, retries, failures,
emission/report overhead, and ordinary queue sharing. QM5_10911 already needed two attempts in
the sampled wrapper. At four reserved census slots, the same ideal work is about 108.6 hours.

The read-only farm snapshot at 2026-08-13 12:39 CEST contained 851 pending and five active Q02
items, so the plan's 867 is a stale snapshot rather than a durable capacity input. The claimant
orders work only by priority-track, phase, and age
(`tools/strategy_farm/farmctl.py:1026-1144`); there is no experiment-specific lane. Parent-serial
submission still lets a 308-run sleeve consume every eligible worker for roughly 4.8 hours.
Add a queue-native census class with a hard concurrent-claim cap/reserved ordinary capacity and
health/abort gates between sleeves. This can be done without changing terminal configuration.

### 14. **BLOCKER — Fail-closed needs an audited per-predicate history contract, not one lookback** `[F6]`

The reference default is only 22 bars
(`C:/Users/Administrator/Downloads/QuantRangePRO - vers2/Hyonix/Breakout7/QuantRangePRO - vers2/PatternFilter.mqh:33-54,237-263`),
while predicates 90/91 require 100 observations
(`C:/Users/Administrator/Downloads/QuantRangePRO - vers2/Hyonix/Breakout7/QuantRangePRO - vers2/Patterns.mqh:878-902`).
Other guards are also wrong: IDs 77 and 81 declare ten bars but read index 10
(`C:/Users/Administrator/Downloads/QuantRangePRO - vers2/Hyonix/Breakout7/QuantRangePRO - vers2/Patterns.mqh:698-713,758-770`);
ID 82 has no guard while calling ATR(20), ID 83 guards ten while calling ATR(20)
(`C:/Users/Administrator/Downloads/QuantRangePRO - vers2/Hyonix/Breakout7/QuantRangePRO - vers2/Patterns.mqh:774-785`);
and ID 98 guards 20 while reading `bar[20]`
(`C:/Users/Administrator/Downloads/QuantRangePRO - vers2/Hyonix/Breakout7/QuantRangePRO - vers2/Patterns.mqh:989-1015`).
The ATR helper silently divides by the requested period even when fewer terms exist
(`C:/Users/Administrator/Downloads/QuantRangePRO - vers2/Hyonix/Breakout7/QuantRangePRO - vers2/Patterns.mqh:220-230`).
`SafePatternRecognition` validates only a default minimum plus two special cases and collapses
insufficient data to false
(`C:/Users/Administrator/Downloads/QuantRangePRO - vers2/Hyonix/Breakout7/QuantRangePRO - vers2/Patterns.mqh:1044-1075`).

Create and review an exact `required_bars`/required-field table for all 77 predicates. Every
predicate result must be tri-state `FOUND / NOT_FOUND / INVALID`; `INVALID` cannot be represented
as false because false permits trades in blacklist mode. Verify copy count, synchronization,
OHLC integrity, and tick-volume availability for every referenced bar. Use one common effective
DEV start after the maximum warm-up for every candidate and OFF control, so long-lookback
predicates are not compared on shorter exposure. At backtest start with fewer than 100 valid
closed D1 observations, the candidate/family must be ineligible or uniformly outside the
comparison window—not silently treated as “pattern absent.”

### 15. **MAJOR — Mechanical `bar[0]` to `bar[1]` shifting changes some hypotheses** `[F6]`

The closed-bar rule removes repainting, but it does not preserve every reference predicate's
economic timing. For a gap predicate, `bar[0].open` versus the prior high becomes the previous
day's open versus the day before; the decision is now available one session later. The current
D1 open is immutable after session open, whereas gap-and-go predicates that also use the current
close genuinely cannot be known until close. These are different hypotheses, so a universal
index increment cannot inherit the OWNER A/B interpretation
(`docs/research/PATTERN_PERMISSION_FILTER_PLAN_2026-08-13.md:67-71,109-113`).

Document the temporal meaning of every predicate: decision timestamp, last permissible input
timestamp, and whether it is an intentionally lagged reinterpretation. Golden fixtures must
cover session boundaries, gaps, and exact lookback edges. IDs 99/100 currently call
`TimeCurrent()`
(`C:/Users/Administrator/Downloads/QuantRangePRO - vers2/Hyonix/Breakout7/QuantRangePRO - vers2/Patterns.mqh:1018-1034`);
replace wall-clock dependence with the immutable
reference session date and a frozen broker/DXZ timezone and DST contract. Test weekends, DST
transitions, month/quarter boundaries, history synchronization, restart, and invalid-cache
behavior. For ID 98, bind the `.DWX` tick-volume proxy, zero/missing-data behavior, and a minimum
prevalence check.

### 16. **BLOCKER — Entry-vector filtering cannot exactly reconstruct a stateful EA** `[F7]`

The plan claims that fixed cash risk makes offline reconstruction exact except for identified
state coupling (`docs/research/PATTERN_PERMISSION_FILTER_PLAN_2026-08-13.md:228-237`). Fixed
risk removes one sizing feedback, not position occupancy, daily counters, cooldowns, pending
orders, opposite-order cancellation, kill-switch/equity state, or future signal eligibility.

Concrete counter-example from QM5_13213: the base run places both stops
(`framework/EAs/QM5_13213_balke-gmt3-range-breakout/QM5_13213_balke-gmt3-range-breakout.mq5:310-317`);
a buy trigger then removes the sell stop
(`framework/EAs/QM5_13213_balke-gmt3-range-breakout/QM5_13213_balke-gmt3-range-breakout.mq5:320-347`).
If a filter
had suppressed the buy placement, the sell could remain and trigger later. Dropping the buy from
the base trade log cannot create that counterfactual sell, and logging predicates only on base
entry bars misses signals hidden while the base position is open. Equality for one predicate or
one sleeve does not prove equality for the next predicate because each changes the subsequent
state path.

Treat reconstruction only as a diagnostic. It may replace real runs only if a deterministic
state-transition replay consumes all raw candidate signals/order events and is proven equivalent
for every EA and every candidate configuration—which is effectively another backtest engine.
Otherwise run the full census; do not promote evidence reconstructed by deleting base trades.

### 17. **MAJOR — Any composed profile is a new searched interaction** `[F7]`

The plan moves from single-predicate ablations to one or two compiled profiles per sleeve
(`docs/research/PATTERN_PERMISSION_FILTER_PLAN_2026-08-13.md:22-26,239-242`) without saying
whether a profile is exactly one winning predicate or a composition. If two individually good
predicates are combined, their conjunction/disjunction can change frequency and state paths; it
is not validated by either univariate result. Choosing the best combination after reading the
census is another search family.

Freeze each promoted profile's composition rule before evaluating it, add every composed
candidate to a separately declared DEV interaction family, count it in multiplicity, and require
its own same-binary OFF comparison before sealed OOS. If profiles will always contain exactly one
predicate, state and enforce that constraint instead.

## Required plan changes before implementation

1. Define the sealed family hierarchy, mode/control/configuration/replica arithmetic, complete
   daily return matrix, calibrated DSR, exact-family PBO, and program-level multiplicity policy.
2. Define the DEV objective, minimum improvement, exposure/fire eligibility, categorical
   robustness, and global selection across card shards.
3. Introduce a governed census binary identity and hash/lineage manifest before any census run.
4. Replace the universal outer veto with side-effect-free, per-order permission integration and
   a pending-order lifecycle contract for every EA shape.
5. Enumerate the complete schema, Q14/Q15, setfile, registry, and lint blast radius; prove
   default-OFF equivalence.
6. Publish an audited 77-row temporal/history contract and the corresponding positive, negative,
   boundary, insufficient-history, restart/cache, and parity fixtures.
7. Add logical-family sharding and a queue-native concurrency lane; keep reconstruction
   diagnostic-only unless full state equivalence is proven.

No census should be enqueued until findings 1–5, 7, 9, 11, 14, and 16 are resolved in the plan
and their acceptance tests are explicit. This review makes no pipeline or strategy-performance
verdict.
