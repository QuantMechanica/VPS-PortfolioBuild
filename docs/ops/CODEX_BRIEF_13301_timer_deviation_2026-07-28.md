# Codex brief — simulate 13301's tick-trailing on a 1s timer; measure the deviation

Date: 2026-07-28
Priority: highest, directly behind the in-flight ownership fix (08e241e2).

## OWNER's reframe, verbatim, and what it changes

> "Tick-Trailing können wir ja mit einem 1s Timer simulieren, bestimm die Abweichung
> zwischen Tick Trailing und onTimer Auslösung, wenn sie im Rahmen ist, reicht das für
> Backtests aus (sauber alles dokumentieren, wir bauen hier ja nur Lösungen, um
> backzutesten, nicht live zu handeln! Der Live Handel würde je mit jeweils 1 EA pro
> Symbol realisiert werden um das Buch abzubilden (also in diesem Fall 3 EAs). Also
> probier das nochmal!"

This corrects the B3 decision's frame. 13301 was rejected as "per-tick-trailing →
undeployable" — but deployability of the JOINT EA is irrelevant: **live is one gated
EA per symbol on its own chart with real OnTick.** The joint EA is a backtest-only
measurement instrument. Its requirement is therefore not bit-identity for per-tick
sleeves but a **measured, documented, acceptable deviation**. 13301 comes back as the
slot-2 candidate — matching the book the 0.641 estimate actually described — with
13108 as fallback if the deviation is out of bounds.

## The measurement

Build a **timer-simulated 13301 variant** and measure it against the gated original:

1. **The variant**: standalone QM5_13301 with its trailing/exit management driven by a
   1-second OnTimer instead of OnTick. Entry logic untouched (it is bar-gated
   already). Nothing else changed. Name it unmistakably as a backtest-only
   measurement variant. RECON A established OnTimer runs on SIMULATED time in the
   tester (one fire per simulated second at 1s), so this is well-defined.
2. **Both arms same vintage**: compile the gated 13301 and the timer variant serially
   in one session, same include tree, both SHA256 recorded. The 0.914741 fiasco came
   from cross-vintage comparison — do not repeat it.
3. **Run both through the governed queue** with staged EX5 (the contract is live),
   full common window, Model 4, GDAXI.DWX.
4. **Report the deviation on two levels**:
   - trade level: match decomposition (exact / same-entry-shifted-exit /
     different-entry / extra / missing) with the extended comparator;
   - economic level: net P&L, trade count, med60, |wDay|, wDD_p90, FUND_SCORE for
     both arms, with deltas absolute and relative.
5. **Also sweep coarser intervals if cheap** (5s, bar-close) so we know the shape of
   the curve, but 1s is the decision point.

## The acceptance criterion — propose, do not decide

OWNER's words: "wenn sie im Rahmen ist". Propose a concrete bound and justify it,
e.g.: every FUND_SCORE component within ±10% relative, no new single-day loss beyond
the gated arm's worst day, and shifted exits explainable by the 1s quantisation
(median shift ≤ a few seconds of simulated time). Present the measured numbers
against the proposed bound and leave the accept/reject as a one-line OWNER decision.
Do not silently accept.

## Documentation duty (OWNER: "sauber alles dokumentieren")

The deliverable must state, in one place a future session can rely on:
- the joint EA is a BACKTEST-ONLY instrument; live = one gated EA per symbol (3 EAs
  for this book);
- which sleeves in the joint EA are exact (host runner via OnTick; timer-safe
  satellites) and which are timer-simulated with what measured deviation;
- the implication: joint-run results carry the documented deviation as a known error
  bar, and any live decision references the gated per-symbol EAs, never the joint
  instrument.

## Sequencing

The ownership fix (08e241e2) must land first — without it no satellite stream can be
harvested at all. The 0.999125 runner-invariance diagnosis from that task also stands.
Slot-2 13108 wiring may proceed as fallback. The 3-sleeve run happens only after: the
ownership fix lands, this deviation is measured, and OWNER picks 13301-timer or 13108
on the numbers.

## Constraints

- Serial compiles; SHA256 per arm; staged-EX5 governed items only.
- Do NOT modify the gated QM5_13301 — the variant is a separate artifact.
- Do NOT run Factory_OFF/ON; never T5, never T_Live; no re-imports.
- Explicit pathspecs; evidence over claims; NOT ESTABLISHED over inference.

## Deliverable

`docs/ops/evidence/2026-07-28_13301_timer_deviation.md` with both SHAs, the trade and
economic deviation tables, the interval curve if run, the proposed acceptance bound,
and the one-line decision teed up for OWNER.
