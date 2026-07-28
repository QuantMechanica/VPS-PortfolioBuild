# Adversarial review — the FTMO joint-book P(pass) "answer" (2026-07-28)

**Date:** 2026-07-28 (verified against `farm_state.sqlite` harvest artifacts, the two
probe logger streams, the fresh/archive q08 streams, and the step-2 account-equity
stream — never against the prose of the documents under review)
**Author:** Claude (board-advisor worktree) — ADVERSARY on the answer
**Reviewed:** `2026-07-28_measurement_preregistration.md` (409a3986b),
`2026-07-28_multisym_steps23_EXECUTED.md` (the executed close-out), `2026-07-28_goal_implementation.md`
(the runner-alone anchor), `2026-07-27_multisym_step1_EXECUTED.md`.

---

## Overarching finding — read before the five points

**The document the task names — `docs/ops/evidence/2026-07-28_ftmo_book_answer.md` — does
not exist, in this worktree or any branch (`git ls-tree -r` over all `agents/*`, `main`,
`origin/main`: no hit). There is no completed joint-book P(pass) answer to adversarially
attack, because the measurement it presupposes was never completed.** The most recent
executed artifact (`2026-07-28_multisym_steps23_EXECUTED.md`, 15:26) reports the opposite of
a completed answer:

- **Step 2 (2-sleeve de-risk) FAILED its admission gate.** The joint EA cannot produce a
  harvestable, faithful satellite in a single-symbol tester: zero satellite `TRADE_CLOSED`
  rows reach the q08 stream (framework design conflict — runner-fidelity-by-avoiding-basket-
  mode is mutually exclusive with satellite-harvest-via-ownership, `steps23_EXECUTED.md`
  §3.1). **Arm B cannot be formed** — not even a 2-sleeve Arm B.
- **Step 3 (3-sleeve) is BLOCKED** on a Codex build that has not landed (the 20181 source
  wires only ONE satellite, `…20181….mq5:284`).

So the honest status is: **OWNER's question — does the composed book make passing more
likely? — is UNANSWERED by measurement.** The only P(pass) number that exists is the
**runner-ALONE anchor** (first-passage 85.1% at 1×), plus a *preregistered prior* that the
joint book will land in outcome **(C) "indistinguishable."** Everything below reviews the
artifacts that WERE produced. Every numeric claim I could recompute, I recomputed; all held.
The single largest risk to the answer is not a miscomputed number — it is that the answer
does not yet exist and the STATE brief presents a rosier picture than the executed reality.

---

## Point 1 — Was the preregistration followed exactly? **N/A → the paired comparison never ran; the executed pieces are faithful; one pre-warned deviation is real**

The preregistration governs a **paired** comparison (Arm R = slot-0 substream vs Arm B =
all-slots substream of **one** joint run, truncated window, 1×, first-passage primary,
identical censoring, `preregistration.md` §2). **That comparison was never executed** — there
is no Arm B (Overarching finding). No post-hoc choice "voided the comparison" because there
is no completed comparison to void. Specifically:

- **Faithful (CONFIRMED for what ran):** window `2018.07.02..2025.12.31` (tester-floored,
  pre-2018-07-02 NOT ESTABLISHED); 1× sizing; first-passage as PRIMARY KPI + 60/30 as
  SECONDARY (`goal_implementation.md` Item 5 output matches the prereg KPI hierarchy, no
  post-hoc KPI switch); staged-EX5 governed run (pre==post==required sha `60ee13b7…`,
  `summary.json`). The estimator is copied verbatim from `challenge_firstpassage.outcomes()`
  (`recompute_runner_alone_baseline.py:70-132`).
- **Real deviation the prereg explicitly pre-warned against:** §2.1 states *"Do NOT run a
  separate standalone-9936 job for Arm R (that reopens the vintage gap…)."* The executed
  Arm-R anchor was computed **from the standalone 588af557 stream**, not a joint run's slot-0
  substream (`recompute_runner_alone_baseline.py:29`, `goal_implementation.md` Item 5). It was
  justified by the step-1 **1.000000** runner-invariance — but step-2 then measured invariance
  at **0.999125** (not 1.0) once a satellite is enabled (Point 2). So the standalone proxy is
  **not** identical to the true joint slot-0; the exact gap the prereg banned the standalone
  route to avoid materialised as a 1-trade exit shift. **Minor and currently moot** (no Arm B
  exists to pair against), but it is the specific pre-warned deviation, and it means the 85.1%
  anchor rests on a stream that is 0.999125-, not 1.0-, equivalent to the book's runner.

**Verdict: CONFIRMED faithful for the executed baseline design; the core paired measurement
was not run; one prereg-pre-warned deviation (standalone Arm-R proxy) is real but immaterial
until Arm B exists.**

## Point 2 — Are the fidelity gates' claimed match rates real? **CONFIRMED (recomputed from the streams)**

Recomputed independently with `compare_joint_replay.py` on the harvested streams (SHAs first
verified against the docs: step-2 runner `d8d3733b…`, reference `352b9e3e…` — both match):

- **Step-2 runner-invariance = 0.999125**, 1142/1143 exact, `same_entry_same_volume_shifted_exit=1`
  — reproduced to the digit. The one mismatch: `entry=1597138045 close=1597161153 net=-713.84
  vol=4.12`, i.e. **2020-08-11** (intraday-flat), reference paired `+1401.16`, Σnet delta
  `2115.00` = exactly `1401.16-(-713.84)`. Matches `steps23_EXECUTED.md` §2 to the cent.
- **Fresh-vs-archive = 0.835463**, 1046 exact / 1252 — reproduced (`step1_EXECUTED.md:51`).
- Step-1 runner **1.000000** is documented in `step1_EXECUTED.md:50` (the pre-step-2 runner
  the step-2 gate used as its 1.0 reference).

The claimed match rates are real. The satellite-fidelity gate is correctly reported as
**CANNOT COMPUTE** (no satellite stream exists), not silently passed. **CONFIRMED.**

## Point 3 — Is ESS / minimum-detectable-difference honestly applied? **PARTIALLY CONFIRMED — the framing and conclusion are honest; the reported baseline band carries a real false-precision artifact**

- **Prereg framing is honest.** §1 pre-declares outcome (C) as expected, states the paired
  binary test is near-degenerate at ESS≈12 (discordant pairs <1–2), that unpaired is
  hopeless (<27 pp unreachable), and that a positive verdict needs a true effect ≥~20 pp —
  above every prior. This is the correct, self-critical read.
- **The executed baseline band overstates precision.** Reproduced runner-alone 85.1% band =
  **[69.9, 100.3]** at ESS=21 — the **upper bound exceeds 100 %**, an impossible probability.
  The Wald normal approximation is inappropriate at p≈0.85 / ESS≈9–21 (it spills past 100 %
  at *every* plausible ESS: 9→108.4, 12→105.3, 14→103.8, 21→100.3); a bounded method
  (Wilson/Jeffreys) is required. Moreover ESS=21 is the **passer-median deflator** (n ÷
  median-days-to-pass = 1142/52), which the prereg §2.7 explicitly tells the Answer agent
  **not** to use for the headline (*"conservative deflator … ESS ≈ 9–14, not the passer-median
  ESS 25"*). At the prereg's own conservative ESS≈12 the band is wider still. So the single
  P(pass) band OWNER would see is **narrower than the prereg's own conservatism standard and
  numerically impossible at the top.**
- **Favorable-framing note:** the "runner alone already carries ~85 %" headline uses the
  **full-window** (85.1%) figure; the later-starts OOS split is **71.8%**
  (`goal_implementation.md` Item 5). Both are reported, but the rosier one is the headline.
- **The narrative conclusion does NOT overstate:** it lands on (C)/underpowered and never
  claims the joint book helps.

**Verdict: PARTIALLY CONFIRMED.** The honesty the prereg demands is present in the framing
and the conclusion; the "correct point estimate sold with false precision" pattern the task
warns of **is** present in the reported 85.1% band (>100 % upper bound + passer-median ESS),
and should be reissued with a bounded interval at the conservative ESS before any number
reaches OWNER.

## Point 4 — Breach direction (true equity vs MAE proxy): **CONFIRMED from the equity stream itself**

The direction claim — *"the MAE proxy over-predicts daily breaches → the reported pass rates
are too LOW → real ≥ proxy"* (`2026-07-27_joint_vs_python_model_validation.md:108-109`) — was,
on 07-27, **asserted from bounds only**: that same doc says the true-equity comparison
*"cannot be performed"* and is *"NOT ESTABLISHED (run not executed)"* / *"UNTESTABLE without
the run"* (`:12-14,83,260`). The step-2 run finally produced a **true account-equity stream**
(`step2_equity_20181_USDJPY_DWX.jsonl`, 309,018 bars, per-bar + intraday-low, per-magic
floating). Tested directly:

- The true account equity **never** fell below **98,105.55** → max total drawdown **1.89 %**
  (vs the −10 % cap); worst single-day drawdown **2.17 %** (vs the −5 % cap). The realised
  path is nowhere near the barriers.
- Isolating the runner floating (`fl` magic 201810000) over 1,142 runner trade-days and
  comparing the per-day MAE proxy (Σ `mae_acct` on the close-day, exactly what the estimator
  charges) against the **true intraday floating low**: proxy strictly **more pessimistic on
  705 days, equal on 437, more optimistic on 0**. The direction **never flips.** Proxy runner
  daily-breach days = 0; true = 0.

The direction claim holds, and for the first time it rests on the equity stream rather than a
bound. **Caveat honestly stated:** the only equity stream that exists is the **2-sleeve
account** run; I isolated the runner via `fl`, so this validates the runner's proxy inside
the composed run (runner trade-fidelity 0.999125), **not** a standalone-runner equity path
(which does not exist). The 85.1% anchor's daily-breach channel is therefore, if anything,
a slight under-estimate — consistent with the claim. **CONFIRMED.**

## Point 5 — Vintage caveat clear? Does the unresolved f0301ecf change the conclusion? **CONFIRMED — f0301ecf is now resolved non-causal; vintage handling is clean; the conclusion is unchanged**

- **f0301ecf resolved NON-CAUSAL, recomputed from artifacts.** The two staged-EX5 probe
  loggers — parent `f0301ecf^` (`9f79065c…/…/logger_sample.jsonl`) vs child `f0301ecf`
  (`588af557…/…/logger_sample.jsonl`), 10,961 rows each — differ in **exactly 2 lines after
  dropping wall-clock keys, both the news-calendar snapshot** (`NEWS_TESTER_CALENDAR_SELFTEST`
  matches 34109 vs 34107; `NEWS_CALENDAR_LOADED` hash 932D45E5… vs E7B48081…, modified
  2026.07.28 vs 2026.07.27). **Trade-event multiset symmetric difference = 0** over 7,221
  trade events per arm (2478 ENTRY_ACCEPTED + 2492 TM_OPEN + 413 TM_CLOSE + 1838 TM_MODIFY).
  The prop-firm include has **zero execution effect**; the 72 shifted exits + 25 entry diffs
  are **news-calendar vintage drift**, not the wrapper. The task STATE's "probe DEFERRED
  behind the USDJPY lock" is **superseded** — the parent arm already ran (`9f79065c` DONE
  10:20→10:44) and is signed off. **The unresolved probe is resolved, and it removes a
  suspected confound rather than changing the conclusion.**
- **The "0.915136 vs 0.835463 unsettled" flag (`preregistration.md` §4a) is a false alarm.**
  Both rest on the **identical 1046 exact matches**: 1046/1143 = 0.915136 (matched ÷ fresh
  rows), 1046/1252 = 0.835463 (matched ÷ max/archive rows, the script's denom). It is a
  denominator convention, **not** evidence the vintage question is unsettled.
- **Method deviation (minor):** the prereg §6.1 asked for `compare_joint_replay.py` on the two
  arms' **q08 TRADE_CLOSED** streams; the parent arm's q08 stream was overwritten in volatile
  FILE_COMMON, so an **event-stream diff** was substituted (`goal_implementation.md` Item 1).
  Defensible — TRADE_CLOSED is derived from those same ENTRY/TM_OPEN/TM_CLOSE events — and I
  reconfirmed symdiff 0.
- **Vintage labelling is clean:** the baseline is explicitly "fresh 588af557 vintage"; the
  window explicitly NOT-ESTABLISHED pre-2018-07-02; and the prereg correctly **forbids**
  interpreting any joint number against the archived-vintage 0.641. Since no Arm-B number
  exists, the residual vintage risk is contained.

**Verdict: CONFIRMED.**

---

## Summary table

| # | Adversarial point | Verdict | Load-bearing evidence |
|---|---|---|---|
| — | A completed joint-book P(pass) answer exists | **REFUTED** | no `*ftmo_book_answer*` in any branch; `steps23_EXECUTED.md` §Bottom line: step-2 FAILED, step-3 BLOCKED |
| 1 | Preregistration followed exactly | **N/A / faithful-for-what-ran** | paired comparison never executed; Arm-R-from-standalone is the pre-warned §2.1 deviation, now 0.999125-not-1.0 |
| 2 | Fidelity match rates real | **CONFIRMED** | recomputed 0.999125 (1142/1143), 0.835463 (1046/1252); SHAs `d8d3733b…`/`352b9e3e…` match |
| 3 | ESS/MDD honestly applied | **PARTIALLY CONFIRMED** | framing+conclusion honest; band [69.9, **100.3**] impossible + passer-median ESS narrower than prereg's conservative 9–14 |
| 4 | Breach direction (true equity vs MAE proxy) | **CONFIRMED** | 309,018-bar equity: true DD 1.89% total / 2.17% daily; proxy more-pessimistic 705d / equal 437d / optimistic **0d** |
| 5 | Vintage caveat + f0301ecf | **CONFIRMED** | probe loggers symdiff 0 over 7,221 trade events, 2 news-only line diffs; 0.915/0.835 = same 1046 matches |

## Bottom line for OWNER's goal

The numbers that were produced are **sound and reproduce exactly**; the analysis is honest
about being underpowered. But the goal — *"sehen, ob er das Bestehen einer Challenge
wahrscheinlicher macht"* — is **not yet answered**: the composed book's P(pass) is unmeasured
because the joint EA cannot yet emit a harvestable satellite (`steps23_EXECUTED.md` §3.1).
The single highest-leverage next step is the Codex-lane fix that registers each satellite's
`(magic,symbol)` context so the q08 emitter harvests its closes — until then no multi-symbol
joint run can be measured at the per-sleeve level, and the "answer" remains the runner-alone
85.1% (which should be reissued with a **bounded** CI at the conservative ESS, Point 3).

## Reproduction commands (all read-only; no terminal, no state mutation, T5/T_Live untouched)

```
# Point 2 — runner invariance
python tools/strategy_farm/compare_joint_replay.py \
  --joint  D:/QM/reports/work_items/c0192be6-.../harvest_steps23/step2_runner_20181_USDJPY_DWX.jsonl \
  --gated  D:/QM/reports/work_items/588af557-.../QM5_9936/20260727_215505/q08_trades_9936_USDJPY_DWX.fresh.jsonl
# -> match_rate 0.999125

# Point 2/5 — fresh vs archive (same --gated swapped for the sleeve_streams archive)
#   -> matched 1046 ; 1046/1143=0.915136 ; 1046/1252=0.835463

# Point 3 — baseline reproduces 0.8511 / ESS 21 / band [69.9,100.3]
python tools/strategy_farm/portfolio/recompute_runner_alone_baseline.py

# Point 4 — true-equity vs MAE-proxy breach direction (scratch script, logic in this doc)
#   step2_equity_20181_USDJPY_DWX.jsonl: min equity 98,105.55 ; proxy-more-pessimistic 705 / equal 437 / optimistic 0

# Point 5 — f0301ecf event-diff over the two probe loggers
#   9f79065c vs 588af557 logger_sample.jsonl: 2 line diffs (news only) ; trade-event symdiff 0
```
