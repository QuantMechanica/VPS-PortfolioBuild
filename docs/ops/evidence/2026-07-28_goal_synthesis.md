# Goal synthesis — the FTMO backtest EA and its P(pass) answer

**Date:** 2026-07-28 (~14:00 UTC, live-verified against `farm_state.sqlite` and the tree)
**Author:** Claude (board-advisor worktree) — day's handover
**Goal (OWNER, verbatim):** *"Ziel ist, dass der FTMO Backtest EA endlich gefahren werden
kann und wir sehen, ob er das Bestehen einer Challenge wahrscheinlicher macht!"*

Every finding below names the concrete thing between NOW and a completed 3-sleeve joint
measurement with a P(pass) answer. Not a general audit.

---

## 1. THE ANSWER

**It does not exist yet, and today it moved further away, not closer — for a good reason.**

The preregistered verdict (`2026-07-28_measurement_preregistration.md` §7) needs a *paired*
P(pass) on two arms extracted from **one** joint run: Arm R (runner-alone, slot-0 substream)
vs Arm B (composed book). Today only Arm R is measured; Arm B **cannot be measured yet.**

- **Arm R is done and clean.** Fresh-vintage, truncated common window (2018-07-02..2025-12-31),
  1× (the only deployable sizing): first-passage **P(pass) = 85.1%** full window (972/135/35
  pass/breach/censored, ESS 21, 95% band [69.9, 100.3] — wide, and a lower bound because
  censored counts as fail), **71.8%** on the OOS split
  (`2026-07-28_goal_implementation.md:182-192`;
  `tools/strategy_farm/portfolio/recompute_runner_alone_baseline.py`).
- **Arm B is blocked at the instrument, not the analysis.** The 2-sleeve de-risk run (9936 +
  10145, item `c0192be6`, done/PASS, T1, account net 204,018 / PF 1.35) **failed its admission
  gate**: the joint EA cannot emit a harvestable, faithful satellite in a single-symbol tester
  (`2026-07-28_multisym_steps23_EXECUTED.md`). Zero satellite `TRADE_CLOSED` rows reach the
  q08 stream the P(pass) machinery consumes.

**The exact gate that stops the answer** (`multisym_steps23 §3.1`): a **design contradiction
in the joint EA itself.** To keep the runner byte-identical the EA deliberately stays out of
basket mode (`QM5_20181…mq5:280-283`), but `QM_FrameworkOwnsMagicSymbol` only recognises a
foreign-symbol satellite as owned *in* basket mode or via a registered magic-context the
satellite never gets (`QM_Common.mqh:400-429`, esp. `:414-415`). So the satellite's 149 real
XAUUSD fills are excluded from the q08 emitter and never scored. Runner-fidelity-by-avoiding-
basket-mode and satellite-harvest-via-ownership are, as the framework is written, mutually
exclusive. This is the single highest-leverage fix for OWNER's goal.

**The single next action:** one Codex-lane build pass on the one `QM5_20181.mq5` + one
recompile that fixes all five defects at once (`multisym_steps23 §5`): register each
satellite's `(magic, symbol)` context so it is owned without basket mode (§3.1);
enter on the first open tick, not a fixed 01:00 `OnTimer` fire (§3.2); restore or document
runner invariance (§2); wire the FW1 news filter into the satellite (§3.3); and wire slot-2 =
13108 (§5.5). Then re-run the 2-sleeve (now harvestable) + a fresh 10145 reference, gate
fidelity in isolation, run the 3-sleeve, and hand the per-magic streams to the paired
first-passage estimator.

**The preregistered honest expectation, stated in advance:** outcome **(C) indistinguishable.**
At 1× — the only sizing `QM_Common.mqh:182` permits — the runner alone already carries ~85%
first-passage. Every prior (pool 1-2 orders short of challenge-grade edge; single-vs-shared
already "indistinguishable"; +13 pp point estimate inside its own band) says the composed book
raises the point estimate ~10-15 pp but not resolvably at ESS ~9-21
(`measurement_preregistration.md §0-1, §8`). We have not *earned* even (C) yet — one build pass
stands between now and any Arm-B number.

**One reframe OWNER must absorb:** the old "35.7% at 3×, 44% breach" single-account figure is a
**3×-under-a-self-imposed-60/30-deadline artifact.** FTMO removed the max trading period in
2024 (Codex-verified, task `9b7c6aaf`). Under the *actual* rule — first passage, no deadline —
leverage is pure variance and 1× is optimal, and the runner alone is ~85% likely to pass, not
36%. The 60/30 sprint at 1× is 3.06% (`goal_implementation.md:194-197`): that KPI is the wrong
one and must not anchor the verdict.

---

## 2. THE VINTAGE QUESTION — f0301ecf EXONERATED

**Resolved. The prop-firm include is NOT the cause of the drift.**

Both probe arms ran (staging contract da0183209/41372ec98 is what made this possible):
- parent `f0301ecf^` (commit `c0918247`, staged EX5 sha `f46b73c7…`) → item `9f79065c`,
  **done/PASS** 10:44Z;
- child `f0301ecf` (canonical tip) = the fresh standalone `588af557`, **done/PASS**.

Event-stream diff of the two loggers (10,961 rows each): only **2** differing lines, both the
news-calendar snapshot (`NEWS_TESTER_CALENDAR_SELFTEST`, `NEWS_CALENDAR_LOADED`), zero code.
**Trade-event multiset symmetric difference = 0** over 8,951 trade events
(`goal_implementation.md:54-66`; `goal_blocker_chain.md §B0`). Static reading agrees: default
`prop_phase=OFF` returns allow/true (`vintage_bisect.md:67`).

**Therefore the fresh-vs-archive divergence (archive 1,252 → fresh 1,143 trades; 72 shifted
exits + ~25 entry diffs; exact/larger = 0.915136 on the true common window) is archived-vintage
news-calendar drift, not the prop wrapper.** The archived sleeve stream
(`…/sleeve_streams/QM/q08_trades/9936_USDJPY_DWX.jsonl`, 1,252 rows) is stale-calendar. FUND_SCORE
0.409 (archived) → 0.363 (fresh), −11%, is drift + the unequal start window, not a code
regression (`vintage_bisect.md:82-94`). **Do not revert any framework commit; do not
regenerate all sleeves on this evidence** — the drift is calendar vintage, correctly contained
by taking every baseline from the fresh run itself.

**Residual caveat (honest):** the earlier "0.835463" number the STATE brief carried was an
invalid whole-archive-vs-fresh comparison; the valid common-window figure is 0.915136
(`vintage_bisect.md:1-24`). Multiple different numbers for "the same" comparison were in flight
today — that itself was a symptom the question was under-controlled until the event-diff closed it.

---

## 3. THE FACTORY — what the three structural fixes changed in 12h

| fix | measurable 12h effect | still bleeding |
|---|---|---|
| **Progress-aware reaper** (`371a7dc0`, `farmctl.py:4951-5114`) | **This is why the joint measurement exists at all.** Step-1 ran 54 min (21:28→22:22); the old 45-min Q02 wall would have reaped it. Step-1, the probe, and step-2 all completed. 150-min basket budgets now survive. Day-over-day done ~doubled (yday 376 full day → today 396 by 13:24Z ≈ 29/hr) — confounded by diurnal + queue, not purely the reaper. | — |
| **Age escalation** (`a4bea4483`) | **Instrumented, not yet biting on outcomes.** 2,097/2,440 pending rows carry nonzero age credit (max 9 wk), but the 16-week Q02↔priority-Q08 parity threshold has not been crossed by any row, so *what gets claimed* is unchanged so far (`goal_implementation.md:147-160`). | the oldest rows still wait; effect materializes only past 16 wk |
| **EX5 staging** (da0183209/41372ec98) | **This is why f0301ecf is exonerated.** The parent arm ran as a distinct immutable binary (pre==post==required SHA held on step-2, `60ee13b7…`). Without it the probe could not have run against the active factory. | — |

**Still bleeding, quantified (today through 13:24Z, 481 processed):** INFRA_FAIL ≈ **24%**
(85 failed-exhausted + 31 done-but-infra = 116/481) — down from the 43% root-cause era
(MEMORY 07-26) but a quarter of the fleet is still burned on infra, not verdicts. ZERO_TRADES
**61** today (dead EAs consuming slots). Queue **2,431 pending**, draining ~30/hr → **weeks** of
backlog even before the FTMO items. Lifetime 47,457 failed vs 54,070 done. And the goal-critical
bleed: the satellite-harvest design contradiction (§1) — no amount of throughput fixes the
inability to *measure* a satellite.

---

## 4. STANDING OWNER DECISIONS NOW DUE

1. **Confirm slot-2 = 13108** (timer-safe, deployable) vs a conscious choice to measure a
   non-deployable 13301 variant. **Volume:** one line; gates the Codex B1 build.
   **Cost:** the deployable book tops out at OOS FUND_SCORE **0.527** (rank-17 9936+10145+13108),
   not the 0.641 headline — because 0.641 was measured on a per-tick standalone 13301 the
   `OnTimer(1)` runner cannot reproduce (`goal_blocker_chain.md §B3-decision`;
   `20181_repair.md:51-65`). Recommendation: **13108.**

2. **Authorize the Codex 5-in-1 build pass** (§1 / `multisym_steps23 §5`). **Volume:** one
   `.mq5`, one recompile, new ex5 SHA. **Cost:** Codex-lane build time. This is THE critical
   path — nothing about Arm B measures without it, and step-2 proved the current binary cannot
   do it. It is not on this workflow's lane.

3. **Strategic — is the full joint measurement worth the terminal spend?** **Volume:** re-run
   2-sleeve + fresh 10145 reference + 3-sleeve = ~3-4 governed priority runs, **~1.5-4 h**
   terminal (cheap; priority-track admits in 20-40 min each). **Cost/benefit:** runner-alone is
   already ~85% first-passage at 1×; the composed book is preregistered to add ~10-15 pp,
   *below* what ESS ~9-21 can resolve. The measurement is worth running only because it is cheap
   and the **continuous mechanism metric** (FUND_SCORE/speed) can resolve *direction* where the
   binary bit cannot. **The honest handover:** this measurement is exactly the "significantly
   better results" gate that would un-park FTMO (OWNER 07-26), and the prior says it will most
   likely return (C) — i.e. deploy the runner alone, the composed book is not a demonstrated
   improvement. Decide whether to spend the ~1.5-4 h to *prove* that cleanly, or accept the
   preregistered (C) now.

---

## 5. WHAT THIS WORKFLOW GOT WRONG OR LEFT UNDONE — unsparing

1. **It declared step-2 a minutes-to-2h freebie and the runner "invariant by construction," then
   the run falsified both.** `goal_blocker_chain.md §B2` said the 2-sleeve run "needs no source
   change… enqueue now," and listed "runner fidelity ✓" as a non-blocker. The run found the
   satellite **un-harvestable** and runner invariance **0.999125** (one 2020-08-11 4.12-lot exit
   flipped +1401 → −714 by enabling the satellite). Both were **statically knowable** from
   `QM_Common.mqh:400-429` + the 20181 source before spending a governed priority slot. The
   design contradiction is baked into the F3 "isolation" decision the repair doc *celebrated*.
   We burned a slot to discover what a careful source trace would have shown.

2. **The workflow's own docs are internally inconsistent.** `goal_implementation.md` (13:00)
   reads as if step-2 "ENQUEUED, admits in minutes… the joint run measures whether Arm B clears
   the bar." `multisym_steps23` (later) says step-2 FAILED and step-3 must NOT proceed. A reader
   taking the earlier doc at face value would think the measurement was imminent. It is not.

3. **The runner-invariance attribution is not airtight.** It rests on the probe's symdiff-0
   rather than a same-07-28-vintage runner-alone `TRADE_CLOSED` stream, which was **not
   harvested** even though the probe run existed. A clean attribution was available and not taken
   (`multisym_steps23 §2`, self-flagged).

4. **Step-2 was doomed to be inconclusive on fidelity from the start** and the workflow only saw
   it afterward: the fresh 10145 reference the fidelity gate requires was never enqueued. Even
   had the satellite been harvestable, there was nothing to compare it against. The sequencing
   (reference build first) was wrong.

5. **The true critical path did not move.** The Codex 5-in-1 build has not landed; the 3-sleeve
   set, the joint-run harvest split, and the paired first-passage estimator are all still
   unbuilt. This workflow produced a correct *diagnosis* and a correct *preregistration* — the
   one thing that will not be relitigated — but zero of the code that actually produces Arm B.

**Credit where due:** `measurement_preregistration.md` fixed KPI (first-passage), sizing (1×),
pairing (both arms from one run), confound gates, and verdict thresholds *before* any scoring,
and correctly predicted (C). The vintage question is closed. The instrument defect is precisely
located. What remains is a build, not a mystery.

---

## Evidence index

- The answer / step-2 admission failure: `docs/ops/evidence/2026-07-28_multisym_steps23_EXECUTED.md`
  (§3.1 un-harvestable, §3.2 34 market-closed drops + 149 vs 314, §2 invariance 0.999125, §5 fix list)
- Runner-alone anchor 85.1%/71.8%: `docs/ops/evidence/2026-07-28_goal_implementation.md:182-197`;
  `tools/strategy_farm/portfolio/recompute_runner_alone_baseline.py`
- Preregistered verdict form + honest prior (C): `docs/ops/evidence/2026-07-28_measurement_preregistration.md` §0-1,§6-8
- Vintage exoneration: `docs/ops/evidence/2026-07-28_goal_blocker_chain.md` §B0;
  `2026-07-28_goal_implementation.md:34-66`; `2026-07-28_vintage_bisect.md`
- Staging/probe contract: `docs/ops/evidence/2026-07-28_ex5_staging_and_probe_result.md`; da0183209, 41372ec98
- Reaper / age escalation: `docs/ops/evidence/2026-07-27_progress_aware_reaper.md`;
  `docs/ops/evidence/2026-07-27_age_escalation.md`
- Slot-2 = 13108 decision: `goal_blocker_chain.md §B3-decision`; `2026-07-27_20181_repair.md:51-65`
- Live DB (read-only, `farm_state.sqlite`, max updated_at 2026-07-28T13:24:57Z): `c0192be6`/`9f79065c`/`588af557`
  all done/PASS; 2,431 pending / 9 active; today 396 done / 85 failed (all INFRA_FAIL) + 31 done-but-INFRA;
  done verdicts PASS 143 / FAIL 154 / ZERO_TRADES 61
- 1× cap wiring: `framework/include/QM/QM_Common.mqh:179-182`
