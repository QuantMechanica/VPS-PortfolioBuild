# Independent Survivor-Lever Critique — 2026-08-12

## Mandate and independence boundary

This is an independent, adversarial second opinion. It uses primary house decisions,
operating rules, gate specifications, and first-order experiment receipts. It does not
use another analyst's survivor-optimization synthesis. No EA, set file, factory row,
terminal, or process was changed.

The decision rule is deliberately hostile to improvement stories: first ask how each
idea can manufacture an in-sample gain, then admit only designs whose falsification and
trial accounting survive that attack.

## Executive verdict

| Lever | Verdict | Why it survives or dies |
|---|---|---|
| Locked-parameter ports to additional symbols | **PURSUE** | It is already the ratified survivor playbook, creates a genuinely different carrier without adding fitted EA parameters, and directly targets the book's orthogonality bottleneck. A failed port dies without refitting. |
| Portfolio-level marginal-contribution / challenger swap | **PURSUE** | It optimizes the object that matters—the book—without rewriting a proven signal. Admission still needs sealed incumbent comparison and OWNER review. |
| Evidence-led time-exit repair | **PURSUE_CONDITIONAL** | House evidence validates only the narrow “mechanical time ceiling amputates later winners” class. It does not validate generic exit tinkering. |
| Multi-timeframe entry refinement | **PURSUE_CONDITIONAL** | Potentially improves execution while preserving the parent signal, but only if the lower-timeframe rule is preregistered and tested as one challenger, not mined across trigger/timeframe combinations. |
| Day-of-week / pattern permission filter | **DEPRIORITIZE** | Easy to fit, removes observations, threatens the frequency floor, and usually changes exposure rather than creates edge. Allow only a source-derived, preregistered calendar mechanism as a new challenger. |
| Smaller stop loss | **DEPRIORITIZE** | One visible scalar hides a full change in loss frequency, position-size geometry, gap exposure, and trade path. Existing MAE evidence did not justify hand-editing the one sleeve with a weak tightening hint. |
| Take-profit re-optimization | **DEPRIORITIZE** | A target sweep can select random extrema in MFE. No house evidence establishes generic TP truncation as the survivor bottleneck; the validated exit class is time-exit amputation. |
| Time-range breakout + FVG combination entry | **REJECT** as survivor optimization | It is a new conjunctive strategy with an interaction-heavy rule surface, not a bolt-on optimization. If independently sourced and fully specified, it may enter as a new card, never as a rescue of a survivor. |

The order is therefore: **port first; portfolio-evaluate second; run only diagnosed,
single-mechanism challengers third.** Do not launch a broad survivor tuning campaign.

## Binding house evidence

1. Q02 requires at least five trades per year per symbol; below-floor EAs retire even
   when headline PF is strong. The legitimate route is a separately specified
   higher-frequency card, not a gate exception
   (`C:/QM/repo/docs/ops/OPERATING_RULES_2026-07-03.md:8-12`).
2. The ratified survivor-port rule locks parameters; a failed port dies as a port and is
   not refitted (`C:/QM/repo/docs/ops/OPERATING_RULES_2026-07-03.md:30-32`).
3. The current bottleneck is orthogonal return streams, not raw survivor count; research
   steering must favor distinct driver classes rather than more index/metal swing
   mean-reversion variants
   (`C:/QM/repo/docs/ops/OPERATING_RULES_2026-07-03.md:99-105`).
4. Q09 correlation rejection triggers a challenger-versus-incumbent book comparison,
   never an automatic swap (`C:/QM/repo/docs/ops/OPERATING_RULES_2026-07-03.md:14-18`).
5. Portfolio-first doctrine explicitly parks drawdown failures for sealed-book marginal
   contribution, while PF/frequency failures remain terminal; comparison is OOS,
   inverse-vol capped, and includes Sharpe, maximum drawdown, worst day, regime
   correlation, and minimum contribution
   (`C:/QM/repo/decisions/2026-07-19_DL-082_portfolio_first_admission_and_gate_recalibration.md:46-56`).
6. The calibrated portfolio evaluator admits at regime correlation no higher than 0.15,
   rejects from 0.40, uses a Sharpe-delta epsilon of 0.020, and an annual contribution
   floor of 0.06%; Sharpe delta must not be the sole admission signal
   (`C:/QM/repo/decisions/2026-07-20_DL-083_marginal_eval_threshold_calibration.md:11-27`).
7. Q08 computed neighborhood breaches and computed PBO failures remain hard merit
   failures; missing/unverifiable tooling evidence is an infra state, not an invented
   merit verdict
   (`C:/QM/repo/decisions/2026-07-25_q08_tooling_invalid_is_infra.md:74-87`).
8. Calendar-denominated structural anchors are not tuning knobs, but genuinely tuned
   session/week windows must obtain plateau evidence in Q03
   (`C:/QM/repo/decisions/2026-07-15_q08_neighborhood_calendar_params.md:23-38`).
9. The Q07 rule still kills any losing seed; bounded dispersion is tolerated only when
   the worst seed clears the ratified floor
   (`C:/QM/repo/decisions/2026-07-25_q07_second_axis_worst_seed_pf.md:26-42`).
10. House exit forensics split time-ceiling changes from stop-width stories. Time-exit
    challengers require a new EA identity and a full Q02-to-Q08 cascade before portfolio
    comparison (`C:/QM/repo/docs/research/EXIT_SURGERY_SCAN_2026-07-04.md:500-520`).
    MAE then rejected the generic “stop too tight” thesis for all three tested sleeves;
    even the weak tightening hint on one sleeve was not sufficient for a live hand edit
    (`C:/QM/repo/docs/research/EXIT_SURGERY_TIER_B_MAE_VERDICT_2026-07-06.md:27-48`).

## Lever-by-lever kill tests

### A. Day-of-week / pattern trade permission — DEPRIORITIZE

**How to kill it.** Fit the permission mask on realized trade PnL. With the five normal
trading weekdays, an unrestricted on/off search already has `2^5 - 1 = 31` non-empty
masks before adding a pattern definition. Picking the best mask conditions on noise,
reduces sample size, and makes every downstream confidence estimate optimistic unless all
31 attempted masks enter the trial count. A pattern slot adds at least its lookback,
state definition, direction mapping, and enable/disable choice. Combining slots multiplies
rather than merely adds the search surface.

The filter also attacks the wrong constraint for FTMO-style dense sleeves: the operating
rule's prop target is approximately 25 trades per year per symbol
(`C:/QM/repo/docs/ops/OPERATING_RULES_2026-07-03.md:106-113`), while the universal Q02
floor is five (`C:/QM/repo/docs/ops/OPERATING_RULES_2026-07-03.md:8-12`). A permission
gate can only reduce the parent's opportunity count.

**What could survive.** One externally motivated calendar state—fixed before looking at
the survivor's day-level returns—may be tested as a new challenger. It must use closed
bars, server-time normalization, and a single deterministic rule. “Find profitable days”
is rejected; “the source mechanism operates only in a specified session/day” is testable.

**Degrees-of-freedom cost.** High: five binary day decisions plus every pattern slot and
interaction. Treat every evaluated mask/slot combination as an attempted strategy for
DSR/PBO/FDR accounting, including discarded runs.

### B. Smaller stop loss — DEPRIORITIZE

**How to kill it.** A smaller nominal stop can cosmetically reduce per-trade loss under
fixed-lot backtests while increasing stop frequency. Under percentage-risk sizing it can
increase volume and gap sensitivity. It therefore changes both the exit and the exposure
map; it is not a free drawdown reduction.

The relevant house experiment used complete MAE coverage and a loser-MAE/stop sanity
anchor. It found that winners and losers separated early for two sleeves, while the third
had too little winner density near the stop boundary to justify widening; its slight
tightening hint remained in-sample and was explicitly left to a sanctioned sweep
(`C:/QM/repo/docs/research/EXIT_SURGERY_TIER_B_MAE_VERDICT_2026-07-06.md:10-16,21-42`).
That evidence rejects a generic stop-surgery campaign in either direction.

**What could survive.** A sleeve-specific preregistered stop challenger only after an
MAE/MFE boundary-density study on a development sample predicts both recovered/cut trades
and risk-normalized economics. The test set must use `RISK_FIXED > 0` and
`RISK_PERCENT = 0`; live sizing is evaluated separately and never inferred from a fixed-lot
DD improvement.

**Degrees-of-freedom cost.** Nominally one scalar; effectively higher because stop width
interacts with size, entry volatility, trailing logic, break-even logic, and target in R.
Only one preregistered challenger value is acceptable after diagnosis.

### C. Take-profit re-optimization — DEPRIORITIZE

**How to kill it.** Sweep targets until historical MFE produces the best PF. That selects
an order statistic from the same trades used to claim improvement and ignores trades whose
path would change after earlier exits. Re-optimizing TP independently of stop width also
changes reward/risk geometry and may turn a robust plateau into a point solution.

**What could survive.** Only a pre-existing MFE pile-up immediately beyond the current TP,
confirmed on a development period and expressed as one mechanical alternative. A full
path-dependent rerun—not arithmetic relabeling of exits—is mandatory. No generic house
precedent currently elevates TP surgery; the validated exit precedent is time-ceiling
amputation (`C:/QM/repo/docs/research/EXIT_SURGERY_TIER_B_MAE_VERDICT_2026-07-06.md:44-48`).

**Degrees-of-freedom cost.** One scalar per target tested, plus interaction with stop,
trail, partial exits, and time stop. All tested targets count as trials.

### D. Multi-timeframe entry refinement — PURSUE_CONDITIONAL

**How to kill it.** Search lower timeframes, trigger families, thresholds, validity
windows, and retry rules on the same parent signals. The resulting “better entry” may
simply skip losing parent opportunities after seeing their outcome. It can also repaint if
the higher-timeframe bar is not closed, or use future lower-timeframe information when
aligning timestamps.

**Survival contract.** Freeze each D1/H4 parent signal at its closed-bar timestamp. Before
opening the holdout, choose exactly one lower-timeframe trigger, one validity window, and
one missed-entry rule from market mechanics—not survivor PnL. Report both:

- opportunity-level conversion: parent signals, filled signals, skipped signals;
- trade-level economics: PF, drawdown, trade count, costs, delay, and slippage.

The challenger loses if its gain comes mainly from silently deleting parent losses, if it
falls below the Q02 frequency floor, or if a timestamp audit finds look-ahead. Parameters
denominated in real calendar/session structure may be structural; genuinely tuned bars or
periods must carry Q03/Q08 neighborhood evidence
(`C:/QM/repo/decisions/2026-07-15_q08_neighborhood_calendar_params.md:23-38`).

**Degrees-of-freedom cost.** High unless frozen: timeframe, trigger family, threshold,
validity window, and retry behavior are separate choices. Permit one preregistered tuple.

### E. Time-range breakout + FVG — REJECT as survivor optimization

**How to kill it.** Add an FVG confirmation after observing which breakout trades lost,
then tune gap timeframe, displacement rule, minimum gap, fill definition, expiry, direction,
and range interaction. This is a conjunctive classifier with sparse cells and substantial
interaction freedom. It will usually improve in-sample PF by deleting observations while
making the causal source of any gain unknowable.

**Disposition.** This is not the same strategy with a modest execution repair. If a primary
source supplies a complete, deterministic, non-repainting rule and an ex-ante mechanism,
submit it as a distinct Strategy Card with its own trial lineage. It must not inherit the
survivor's gate status or be called a repair. Otherwise reject.

### F. Locked-parameter ports — PURSUE

**Why the kill attempt fails.** A carrier search can still overfit by trying many symbols
and publishing only winners. The house rule solves only the parameter-rescue part, so the
remaining multiplicity must be explicit.

**Protocol.** Pre-register the carrier list using market-mechanism fit and portfolio need,
hash the parent binary and strategy inputs, change only symbol/broker-normalization fields,
and run every listed carrier. Publish failures. No direction flip, threshold repair, or
symbol-specific parameter fit. A failed carrier is terminal as a port, exactly as the
ratified playbook requires
(`C:/QM/repo/docs/ops/OPERATING_RULES_2026-07-03.md:30-32`). Count every attempted carrier
in family-wise DSR/PBO/FDR evidence. Prioritize carriers expected to reduce regime
correlation, because orthogonality—not another same-driver sleeve—is the declared bottleneck
(`C:/QM/repo/docs/ops/OPERATING_RULES_2026-07-03.md:99-105`).

**Degrees-of-freedom cost.** Zero fitted EA parameters when done correctly. Symbol choice
is still a selection trial, so multiplicity rises with every carrier tested.

## Further levers

### G1. Diagnosed time-exit amputation — PURSUE_CONDITIONAL

Require a monotone hold-time result plus a mechanical ceiling that demonstrably closes
the later-winning population. Pre-register one ceiling change. This is the sole survivor
exit class with favorable house precedent; stop-width stories were explicitly separated
and rejected (`C:/QM/repo/docs/research/EXIT_SURGERY_SCAN_2026-07-04.md:500-520` and
`C:/QM/repo/docs/research/EXIT_SURGERY_TIER_B_MAE_VERDICT_2026-07-06.md:44-48`). It is a
new EA/version, never a live edit.

### G2. Portfolio marginal contribution and redundancy pruning — PURSUE

Do not demand that each sleeve maximize standalone PF. Compare the unchanged candidate
against the sealed incumbent book at capped inverse-vol weight, with ΔSharpe, ΔMaxDD,
worst day, regime correlation, and operational contribution jointly reported. Apply the
DL-083 thresholds and never use ΔSharpe alone
(`C:/QM/repo/decisions/2026-07-20_DL-083_marginal_eval_threshold_calibration.md:11-27`).
This can improve the portfolio by adding a modest orthogonal sleeve or removing a redundant
one without data-mining the EA.

### G3. “No-change” incumbent benchmark — PURSUE as mandatory control

Every experiment needs the exact incumbent binary/set as a contemporaneous control. The
challenger must beat “do nothing” after all costs and on portfolio marginal contribution.
Passing absolute gates is necessary but not sufficient to replace a proven sleeve; swaps
remain OWNER decisions (`C:/QM/repo/docs/ops/OPERATING_RULES_2026-07-03.md:14-18`).

## Exact anti-overfit re-validation contract

Every admitted lever above follows this contract. A parameter, entry-permission, exit, or
symbol change creates a new candidate lineage; no prior PASS is inherited.

1. **Pre-register and freeze.** Record parent binary/set hashes, hypothesis, exact changed
   fields, carrier/opportunity universe, primary metric, failure rule, and complete trial
   family before reading holdout results. Include failed and abandoned variants in the
   trial count.
2. **Q02 from scratch.** Run the new lineage at fixed risk and enforce economic PF,
   drawdown, and frequency criteria. A permission filter or port below the five-trades/year
   floor dies; no exception (`C:/QM/repo/docs/ops/OPERATING_RULES_2026-07-03.md:8-12`).
3. **Q03 only for declared knobs.** If the idea has a genuine tuning parameter, test the
   preregistered compact neighborhood and choose a plateau representative, never the best
   cell. Structural calendar anchors are documented as structural; genuinely tuned
   calendar/session windows get Q03 plateau evidence
   (`C:/QM/repo/decisions/2026-07-15_q08_neighborhood_calendar_params.md:23-38`).
4. **Q04 OOS walk-forward.** Preserve the anchored development/holdout chronology. Once
   any holdout fold is viewed, the rule and parameter tuple are immutable; a change starts
   another fully counted lineage. The approved gate model defines closed-year OOS folds
   and forbids partial-year substitution
   (`C:/QM/repo/docs/ops/PIPELINE_REWRITE_PROPOSAL_2026-05-23.md:43-51,104-113`).
5. **Q05 and Q06 stress.** Re-run the complete changed trade path under the current cost
   and execution stresses. Do not infer a result from old trades, rescaled stops, or
   filtered rows.
6. **Q07 multiseed.** Use the canonical seed set. Every seed must remain profitable; only
   the ratified bounded-dispersion second axis is allowed
   (`C:/QM/repo/decisions/2026-07-25_q07_second_axis_worst_seed_pf.md:26-42`).
7. **Q08 full statistical suite.** Recompute DSR/FDR, PBO, neighborhood, tail/regime,
   concentration, decay, and chopping evidence from the new lineage. Attempted masks,
   targets, stop values, trigger tuples, and carriers all enter multiple-testing counts.
   A computed neighborhood/PBO failure is terminal; a missing artifact is repaired and
   rerun, never called PASS
   (`C:/QM/repo/decisions/2026-07-25_q08_tooling_invalid_is_infra.md:74-87`).
8. **Q09 news and portfolio.** Re-run mandatory news-blackout/config-lock evidence, then
   compare the challenger to the sealed incumbent book under the same dates, costs,
   weights, and regime partitions. Report both candidate-added and incumbent-replaced
   books; apply DL-083 thresholds. No auto-swap.
9. **Q10 confirmation.** Run the hash-bound, full-history confirmation with the locked
   Q09 configuration. Q10 confirms the candidate; it is not a tuning window.
10. **Incumbent hurdle and release.** Require the challenger to pass its full Q02–Q10
    lineage and the preregistered head-to-head hurdle. Preserve the incumbent if the
    confidence interval spans no improvement, portfolio contribution is weak, or the
    result depends on one regime. Any deployment discussion remains outside this ticket
    and requires the normal OWNER-controlled admission/manifest path.

## Recommendation

Allocate experiments in this order:

1. locked ports selected for missing driver/carrier exposure;
2. unchanged survivors evaluated for marginal portfolio contribution and redundancy;
3. one-at-a-time time-exit or lower-timeframe challengers only where path evidence gives
   a falsifiable mechanism;
4. no broad weekday/pattern, SL, or TP mining;
5. no breakout-plus-FVG “repair”—route a genuinely sourced formulation as a new card.

This ordering minimizes new fitted freedom, attacks the actual portfolio bottleneck, and
keeps the incumbent as the default winner unless a fully independent lineage proves more.
