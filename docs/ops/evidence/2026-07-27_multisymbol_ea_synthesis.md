# Multi-symbol joint EA — synthesis for OWNER (2026-07-27)

Branch `agents/board-advisor` · `C:\QM\repo` · Author: Claude.
Scope: read-only synthesis of the whole 2026-07-27 multi-symbol joint-EA effort — the
first OnTick attempt (QM5_20180) and OWNER's OnTimer correction (QM5_20181). No EA,
framework, set, manifest, gate row, or T_Live state was touched writing this. Every
load-bearing claim carries a `file:line`, a stream path, or a command.

Sources read in full: the plan (`2026-07-27_multisymbol_timer_ea_plan.md`); RECON A
(`…_ontimer_tester_semantics.md`) and RECON B (`…_sleeve_exit_cadence.md`); the machinery
recon (`…_multisymbol_machinery_recon.md`) and tester recon (`…_mt5_multisymbol_tester_recon.md`);
the adversarial review (`…_joint_backtest_ea_adversarial_review.md`); the verdict
(`…_joint_backtest_verdict.md`); the executed run (`…_joint_backtest_run_EXECUTED.md`); the
fidelity diagnosis (`…_joint_ea_fidelity_diagnosis.md`); the Python-model validation
(`…_joint_vs_python_model_validation.md`); the Q09 composition (`…_runner_satellite_composition.md`);
the Q09 correlation wall (`…_q09_correlation_wall.md`); the FTMO campaign state
(`…_ftmo_campaign_state_after_remediation.md`); and the shipped `QM5_20181` EA + `SPEC.md`.

---

## Bottom line, up front

OWNER's correction was **conceptually right and it broke the wrong conclusion** — OnTimer
genuinely decouples a non-host sleeve from the chart symbol's tick stream, which the prior
"no host makes heterogeneous sleeves faithful" verdict had implicitly treated as the end of
the road. But the correction **has not yet been carried to a single admitted sleeve**, and
along the way it surfaced a hard limit OWNER's one-line instruction did not anticipate: the
one sleeve that carries the entire return — the 9936:USDJPY runner — manages its exits **per
tick**, and no timer of any interval reproduces a per-tick trailing stop at `match_rate == 1.0`.
So the design that actually got built is a **hybrid**, not "OnTimer instead of OnTick": the
runner stays on OnTick, and only the timer-safe damping satellites go on OnTimer. That hybrid
is sound on paper and the OnTimer mechanics are empirically proven — but the build reached only
the runner scaffold, and its Step-1 fidelity replay **did not complete**. As of this writing,
**zero sleeves are admitted at 1.0 by either approach**, and no joint run has ever produced the
real intraday equity path the whole exercise exists to capture.

---

## 1. Did it work? — yes/no per step, with the numbers

Two instruments were built today. Neither reached a passing fidelity gate.

### Effort A — QM5_20180 (OnTick joint, the first attempt) — **FAILED, then invalidated**

| Step | What happened | Verdict |
|---|---|---|
| Design (3 sleeves: 9936+13213+**10848 XAUUSD**, host USDJPY) | adversarial review C1–C4 | **REFUTED for the gold sleeve** |
| Cut to USDJPY-only (9936+13213) | survives the review | build sanctioned |
| Build + compile | `0 errors, 0 warnings` (`…_joint_backtest_verdict.md:57-59`) | OK |
| Sleeve-0 replay run (T9, 17m 07s) | `match_rate = 0.914741` (1148 matched / 1255 joint / 1252 gated) | **FIDELITY FAIL** (need 1.0) — `…_joint_backtest_run_EXECUTED.md:13-27` |
| Fidelity diagnosis of the 0.914741 | invalid control | **NUMBER IS UNINTERPRETABLE** |

The adversarial review verdict was correct and load-bearing: in an MT5 multi-currency test
`OnTick` fires **only on the chart (host) symbol's ticks** (`…_adversarial_review.md:45-52`),
so a non-host sleeve that manages positions per tick (10848's continuous high-water-mark trail,
`:51-66`) is computed from foreign prices sampled at the wrong times — "10848 in the joint run
is not 10848" (`:71`). Its finding C3: **"no host assignment makes all three sleeves faithful"**
(`:96-112`). This is the conclusion OWNER later corrected — and the review was right *for
per-tick management*; it simply did not consider driving the sleeves off a model-time timer
instead of host ticks.

The USDJPY-only cut then **ran** (this is the one real backtest of the day) and **failed** its
own sleeve-0 gate at 0.914741. The fidelity diagnosis is the important part: that 0.914741 is
**not a valid fidelity test**. The gated 9936 reference was a **July-14** binary (exe SHA
`a1de7a7b…`), while QM5_20180 was compiled **July-27** (exe SHA `c29da61f…`) —
**execution-identity drift**, two different compiled programs
(`…_joint_ea_fidelity_diagnosis.md:68-97`). Of the 107 apparent mismatches, **77 were SAME
entry, SAME volume, SHIFTED exit** (25 exits exactly +3600 s later, 4 at +7200 s) — the
fingerprint of a management/execution-path change, not a signal-logic failure (`:44-59`). The
broad claim "a gated sleeve cannot be reproduced outside its own EA" is **NOT ESTABLISHED**; the
narrow claim "this cross-vintage replay reproduces it" is **refuted** (`:164-167`). Net: 20180
proved nothing except that its control was built wrong.

### Effort B — QM5_20181 (OnTimer joint, OWNER's correction) — **INCOMPLETE at Step 1**

| Step | Plan | State today |
|---|---|---|
| 0 — scaffold + magic slots | warm 3 symbols, sampler on OnTick+OnTimer | folded into Step 1 |
| 1 — runner 9936 (host, OnTick) | admit at `match_rate == 1.0` vs standalone 9936 | **BUILT + COMPILED, replay NOT COMPLETED** |
| 2 — satellite 10145:XAUUSD (OnTimer, timer-safe) | harness validator | **NOT STARTED** |
| 3 — satellite-2 (13301 GDAXI vs 12969 USDJPY, measurement-gated) | keep 13301 on OnTimer only if its trail never binds | **NOT STARTED** |

The EA exists and compiles: `QM5_20181_ftmo-joint-multisym-timer.ex5` (376,520 B, 2026-07-27
19:08), registry row `20181,…,backtest-only` (`framework/registry/ea_id_registry.csv:4240`),
sets `…_H1_backtest.set` + `…_H1_replay_runner.set`. The Step-1 replay was **launched** —
`D:/QM/reports/joint_20181/control_9936/QM5_9936/20260727_171318/raw/run_01/tester.ini` exists —
but that `tester.ini` is the **only** file under `joint_20181/`: no `summary.json`, no
`report.htm`, no harvested stream in `harvest/` or `s0_runner/`, and **no comparator output**.
The router task list confirms it: "reserve terminal, run both EAs sequentially, harvest Q08
streams" is `in_progress` and "diff with `compare_joint_replay.py`; write step1 evidence doc" is
`pending`. **No `match_rate` was produced for the OnTimer runner.** Steps 2 and 3 were never
reached.

**Answer to "did it work":** No — not to a passing gate, by either route. The OnTick attempt
failed at 0.914741 and that number was then shown to be meaningless. The OnTimer attempt is
built to the runner and stalled before its first fidelity measurement. **No sleeve has been
admitted at `match_rate == 1.0`.** This is not a working book; it is a validated design with an
unfinished first step.

---

## 2. Does OnTimer actually decouple a sleeve from the chart symbol's tick stream?

**Yes. This is the one thing that was empirically settled today, and it vindicates OWNER's
core proposition.** RECON A ran a real probe on terminal T2 (Model 4, `USDJPY.DWX` host,
`XAUUSD.DWX` secondary) and measured it directly:

- `OnTimer` fires on **simulated model time, not wall-clock**: `EventSetMillisecondTimer(100)`
  fired **2,591,989** times over **259,196** simulated seconds = **10.0001 fires per simulated
  second**, while the whole 3-day test computed in **0.614 s** of wall time
  (`…_ontimer_tester_semantics.md:19-26,78-83`). A wall-clock 100 ms timer would have fired ~6
  times. Model-time cadence is proven, not assumed.
- The timer is **not slaved to host ticks**: `OnTimer` fired **610 times before the first
  `OnTick`**, and the two streams thereafter interleave by model time
  (`…_ontimer_tester_semantics.md:151-159`). A non-host symbol's completed bars are readable
  from inside `OnTimer` with **zero look-ahead** (0 violations across all 3,960 logged events,
  `:137-146`), provided the symbol is history-warmed first (`QM_BasketWarmupHistory`, `:130-136`).

So a **timer-safe, closed-bar-deterministic** sleeve (like 10145:XAUUSD) can be driven on its
own schedule regardless of when the host symbol ticks. OWNER was right that this makes
heterogeneous multi-symbol joint testing possible, and right that it defeats the earlier
"impossible" reading.

**But the decoupling has a hard boundary OWNER's one-liner did not cover.** Simulated
`TimeCurrent()` is second-resolution and timer fires land on model-time intervals that **never
align with tick timestamps** (`…_ontimer_tester_semantics.md:33-36,89-97`). A **per-tick
trailing stop** — evaluated on live BID/ASK on every tick — therefore **cannot be reproduced at
`match_rate == 1.0` by a timer of any interval**. RECON B established that the 9936:USDJPY
runner carries exactly such a stop (`+1R 2-bar-swing trailing stop triggered PER TICK`,
`…_sleeve_exit_cadence.md:23-27,80-97`), and so does 13301:GDAXI (`:106-123`). Only 10145:XAUUSD
is timer-safe (no per-tick management, closed-D1 exit, `:131-148`).

The consequence, and the honest deviation from OWNER's instruction: **the runner was NOT put on
OnTimer.** The shipped SPEC says so plainly — "The runner is NOT timer-driven — where the task's
'OnTimer-driven loop' framing conflicts with the exit-cadence recon, the recon wins"
(`QM5_20181…/SPEC.md`). The design uses OnTimer for what it is good at (decoupling the timer-safe
satellites and sampling account equity every model-second) and keeps OnTick for what needs it
(the runner's per-tick trail, byte-faithful because on the host chart it sees the identical tick
stream). **OnTimer decouples cadence — proven; it does not rescue per-tick exit fidelity — also
proven.** OWNER's correction works for the dampers, not for the return engine.

---

## 3. What does the joint run show that stream-stitching could not?

**As of now: nothing — because no joint run ever produced an equity path.** This is the single
most important deliverable and it is absent on both efforts. QM5_20180 stopped at the sleeve-0
fidelity fail, so every joint measurement is explicitly **NOT ESTABLISHED** — realised
correlation, true account-equity path, observed max daily loss, observed max drawdown, and the
`EQUITY_LOW` −5% breach count are each listed NOT ESTABLISHED
(`…_joint_backtest_run_EXECUTED.md:110-119`). QM5_20181's runner replay did not complete (§1).
**The observed intraday equity path does not exist yet.**

What *was* measured — from the existing per-trade Q08 streams, i.e. exactly the stream analysis
the joint run was meant to transcend — bounds the proxy error and answers the direction question:

For the `{9936, 13213}` book (both USDJPY, both **100% intraday-flat**,
`…_joint_vs_python_model_validation.md:65-70`), the −5% **daily** MAE proxy is **pessimistic** —
it over-predicts breaches. Counting days that trip the −5,000 daily cap at each per-sleeve
leverage (`…_joint_vs_python_model_validation.md:92-100`):

| per-sleeve leverage | proxy (Σ day-MAE) | max-concurrent-MAE | realised endpoint |
|--:|--:|--:|--:|
| 1.0 | 0 | 0 | 0 |
| **1.5 (operating)** | **1** | 1 | 1 |
| 2.0 | 7 | 7 | 7 |
| 3.0 | 506 | 502 | 410 |
| 5.0 | 901 | 901 | 609 |

The proxy-vs-tightest-bound gap is **≤6 days out of 1621 (0.4%), and 0 at leverage ≤ 2**
(`…_joint_vs_python_model_validation.md:104-111`). **Direction: the real −5% daily breach count
is LOWER than the Python model assumed** (the model is pessimistic), **so on that channel the
reported pass rates were marginally too LOW — the real numbers are marginally better.**
**Magnitude: negligible** — at the operating leverage the daily cap trips on **one day in eight
years** (`:113-119`), so it is essentially inactive; the account's real killer is the **−10%
total** streak, which the model computes largely from **exact realised P&L**, not the proxy.

Two cautions that keep this from being good news:

1. This is a **bound from the streams, not a reading off a real equity curve.** The residual
   between the max-concurrent bound and the *true tick path* — the thing only a joint equity
   export settles — is still **NOT ESTABLISHED** (`…_joint_vs_python_model_validation.md:121-126`).
   The negligible-error result holds only because these two sleeves are intraday-flat and
   near-collinear (r = 0.905, 269 bit-identical trades, `:32-33,182-184`); it does **not**
   generalise to the target book's satellites (10145:XAUUSD and 13301:GDAXI are **not**
   intraday-flat, and the XAUUSD MAE lower bound is unbounded across day boundaries —
   `…_ftmo_campaign_state_after_remediation.md:139-144`).
2. The narrow "too low" on the daily channel does **not** set the sign of the week's headline
   pass rates. Those are too **HIGH** for larger, unrelated reasons (§4): the 1× risk clamp, the
   "touch = pass" simplification, the multi-day MAE model that discards entry time for the XAUUSD
   legs, UTC-vs-broker-day bucketing, and an adaptively-reused holdout
   (`…_ftmo_campaign_state_after_remediation.md:99-113,139-163`). So: the daily-MAE proxy is
   pessimistic by a negligible amount; the campaign's reported pass rates are optimistic by a
   material amount. The joint run was supposed to replace that whole stack of assumptions with
   one real equity path. It has not.

---

## 4. Where the FTMO book stands (one paragraph you can act on)

There is no book on the table that is simultaneously Q09-admitted, deployable at its assumed
leverage, and measured at ≥80% pass. The **deploy-manifest book** (13213/USDJPY, 10848/XAUUSD,
10553/XAUUSD, 13036/GDAXI) is worse than any headline: the framework **hard-clamps every leg to
1% of equity (1× backtest size)** — the 4/4/8/8 manifest sizing is fiction the framework silently
discards (`…_ftmo_campaign_state_after_remediation.md:16-28,86-98`), the two 8× legs are
**structurally impossible** (override ceiling is 5.0, `:66`), and **all four legs carry Q09
FAIL_PORTFOLIO** (`:88-93`); the manifest book at its forced 1× has **never been simulated** and
is strictly worse than the already-below-target 79.5% (itself a *different*, optimistic book).
Meanwhile the genuinely better composition — the Q09-admitted **runner+satellite** book
`{9936:USDJPY, 10145:XAUUSD, 13301:GDAXI}` (OOS FUND_SCORE 0.487 → 0.641, OOS wDD p90 9.29% →
3.46%, `…_runner_satellite_composition.md:13,19`) — is the right target, but the joint EA that
would measure its *real* equity path was never successfully run. Actionable: do not start a demo
or a paid challenge today; the deployable numbers are fiction and the good book is unproven.

---

## 5. What is NOT done — and the two standing OWNER decisions

**Not done (the work):**

- **The OnTimer runner Step-1 replay never completed** → no `match_rate`, no admission. Steps 2
  (10145 harness validator) and 3 (13301-vs-12969 measurement gate) never started.
- **The 20180 same-vintage control was designed but never re-run** — so shared-module
  reproducibility (a gated sleeve reproduced inside a joint EA) is **NOT ESTABLISHED**
  (`…_joint_ea_fidelity_diagnosis.md:164-167`).
- **The real joint equity path, the true −5% daily breach count, and the intraday cross-sleeve
  correlation are all NOT ESTABLISHED** — no joint run has produced them.

**What it would take:** pin one commit + one compiler/terminal build + one tick-store image + one
commission group; compile standalone 9936 and QM5_20181 from that one state; run both
**sequentially through the factory phase-runner** (the fleet is saturated — ~2,000 pending — and
the hard rules forbid `Factory_OFF`/holding a worker, so a phase-runner slot is the only
sanctioned path); diff at `match_rate == 1.0`; then add 10145 as the harness proof; then run the
13301 trail-materiality measurement to decide 13301-on-OnTimer vs the 12969 host fallback; then
the full joint run for the real equity path; then re-measure −5% daily / −10% total on that path;
then Q09/Q11 portfolio confirmation.

**Standing decision 1 — the 13301 CHALLENGER_SUPERIOR swap (`corr_eff 0.46765`).** Q09 recorded
`13301:GDAXI` as **CHALLENGER_SUPERIOR** to incumbent **10911:GDAXI**: swapped-book Sharpe
2.8191 vs 2.7761, swapped-book MaxDD 0.2173% vs 0.2479% — both improved, `challenger_superior=true`
(`…_q09_correlation_wall.md:93-116`). The `corr_eff 0.46765` is the **incumbent↔challenger**
correlation, above the 0.40 reject line — which is precisely why this is a **swap, not an add**:
the decision is **replace 10911 with 13301**, not run them side by side. The gate deliberately
leaves `admit=False` and hands it to OWNER; **OWNER approval + manifest protocol are mandatory and
this has not been executed** (`:112-115`). Needs an OWNER yes/no.

**Standing decision 2 — run the completed book on a real (paid) challenge account.**
Recommendation: **not yet.** There is no deployable ≥80% book (§4); FTMO is OWNER-parked pending
"significantly better results"; and even the best OOS book (`9936/10145/13301`) has an unproven
joint equity path. The correct sequencing is to finish the OnTimer instrument, produce the real
equity path for that composition, confirm the −5%/−10% margins on it, and only then bring a
challenge-account go/no-go to OWNER. Buying a challenge seat before the joint run exists would be
paying to discover what the instrument was built to tell us for free.

---

## 6. What this effort got wrong (unsparing — this is the handover)

1. **20180 was run against a control that could not answer the question.** The gated 9936
   reference was a July-14 binary; 20180 was July-27. Comparing them measured execution-identity
   drift, not shared-module extraction (`…_joint_ea_fidelity_diagnosis.md:68-97`). This is
   elementary — pin the control *before* spending a 17-minute reserved-terminal run on it — and it
   cost a T9 hour plus a full re-diagnosis to produce an uninterpretable 0.914741. The one real
   backtest of the day taught us nothing about fidelity.

2. **The design's central fidelity control was structurally blind to the failure that mattered.**
   The 20180 design claimed fidelity was "verified, not asserted" via singleton replay — but that
   replay ran each sleeve *as its own host*, so it could not see the non-host cadence divergence
   that made the gold sleeve unfaithful (`…_adversarial_review.md:79-94`). Confidence outran the
   control; only the adversarial pass caught it, and only barely — an unreviewed ship would have
   produced "a precise-looking equity curve and correlation number for a gold sleeve that is not
   the gated gold sleeve" (`:26-29`).

3. **The design shipped factual errors about its own sleeves.** It claimed 9936/13213 have
   "line-for-line identical `Strategy_*` functions"; in fact 13213 uses **one** evening hour for
   both cancel and close where 9936 uses **two** (cancel 13, close 20), and the "bind the rest to
   9936's defaults" recipe would have mis-set 13213's cancel hour to 13
   (`…_adversarial_review.md:201-211`). The build fixed it; the design as written was wrong.

4. **OWNER's headline goal — cross-asset correlation — was quietly abandoned instead of surfaced.**
   The whole idea started as "run them jointly and get their correlation instantly." The faithful
   version of that is impossible (a non-host per-tick sleeve is measured wrong), and the *only*
   path to a real cross-asset correlation is a separate XAUUSD-hosted run plus cross-run inference
   — i.e. the stream-stitching the joint EA was meant to replace (`…_joint_backtest_verdict.md:92-105`).
   That flat conclusion belonged in the headline; it was buried in an H1 finding.

5. **OWNER's literal instruction ("OnTimer instead of OnTick") was partly unimplementable, and
   the deviation lives in a SPEC footnote instead of a plain sentence to OWNER.** The runner's
   per-tick trail forces it to stay on OnTick; OnTimer is for the satellites only. This is the
   right engineering call and it *confirms* OWNER's deeper point (OnTimer decouples cadence), but
   OWNER should hear plainly that the return engine was not moved to OnTimer and why — not infer it
   from `SPEC.md`.

6. **The single most important deliverable never happened — twice.** A workflow that set out to
   close the equity gap *with a real run* produced, across two instruments and a full day: one
   invalidated 0.914741 and one stalled `tester.ini`. Every joint number remains NOT ESTABLISHED.
   The terminal-exclusivity blocker (saturated fleet, no `Factory_OFF`) was correctly diagnosed and
   the phase-runner named as the answer — repeatedly — but the runs still did not complete. The
   effort spent more words describing the blocker than routing a run through it.

7. **The book was chased before it was chosen.** Enormous machinery (two EAs, two modules, a
   comparator, magic registration, recon ×4) was built around `{9936,13213}` — which the stream
   analysis shows is **worse than the single 9936 sleeve** (28.8% vs 35.7% OOS P(fund), a
   leverage-dilution loss from r=0.9 collinearity, `…_joint_vs_python_model_validation.md:219-234`)
   — and around the manifest book, whose four legs are all Q09 failures clamped to 1×. The genuinely
   better composition (`9936/10145/13301`) was identified correctly but late, and is exactly the one
   the joint instrument has **not** yet been pointed at. The right order was: pick the Q09-admitted
   book first, then build the instrument for it. It ran the other way.

---

## Status / evidence / risk / next step

- **Status.** Two joint EAs built and compiled; **zero sleeves admitted at `match_rate == 1.0`**.
  20180 (OnTick) failed sleeve-0 at 0.914741 and the number was invalidated as a cross-vintage
  control. 20181 (OnTimer) is built to the runner; its Step-1 replay did not complete. No joint
  equity path exists. No T_Live state, factory toggle, or gate row was touched.
- **Evidence.** `framework/EAs/QM5_2018{0,1}_*/` (`.ex5` + sets + SPEC); registry rows 4239–4240;
  streams/summaries under `D:/QM/reports/joint_2018{0,1}/`; the 12 evidence docs listed in the
  header; `tools/strategy_farm/compare_joint_replay.py`.
- **Risk.** Do not extend or generalise either instrument before a pinned same-vintage control
  returns `1.0` — building on an unvalidated instrument compounds unverified fidelity. The
  `backtest-only` router-exclusion for ea_ids 20180/20181 is asserted, not proven against the
  router's selection filter (`…_joint_backtest_verdict.md:266-272`); confirm before leaving them
  standing.
- **Recommended next step.** Finish OnTimer Step 1: route the QM5_20181 runner replay + standalone
  9936 through the factory phase-runner from one pinned build, diff, and write the step-1 evidence
  doc. On `1.0`, proceed to 10145 (Step 2, the harness validator) — **not** to a challenge account,
  and **not** to more sleeves before the runner is exact. Bring OWNER the 13301-for-10911 swap
  decision separately; it does not depend on the joint EA.
