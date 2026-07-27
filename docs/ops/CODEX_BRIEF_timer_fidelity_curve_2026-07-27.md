# Codex brief — measure how much fidelity a timer actually costs. Build it and measure.

Date: 2026-07-27
Priority: highest. OWNER: "wie hoch ist die Abweichung tatsächlich? Bau und miss das!"

## The unmeasured claim

The exit-cadence recon established that QM5_9936 manages its `+1R` two-bar-swing trailing
stop **per tick** (`framework/EAs/QM5_9936_ff-range-breakout-gmt3-h1/…mq5`, see
`docs/ops/evidence/2026-07-27_sleeve_exit_cadence.md` §1). From that, the plan concluded
that no timer reproduces it at `match_rate == 1.0`, and the design retreated to a hybrid
with the runner left on `OnTick`.

**That conclusion was never measured.** "Not exactly 1.0" spans everything from 0.999 to
0.85, and those are completely different answers:

- at ~0.999 the timer is a practical substitute and the whole book can go on one timer;
- at ~0.85 the runner genuinely cannot join a timer-driven EA and the hybrid stands.

OWNER wants the number. Produce the curve, not an opinion.

## The experiment

Measure `match_rate` of a **timer-driven** QM5_9936 against the **tick-driven** QM5_9936,
as a function of timer interval.

1. **Build a timer-driven variant of 9936 only.** Same strategy, same parameters, same set
   file, same entry logic. The single change is that the exit/trailing management runs from
   `OnTimer` at interval `N` instead of from `OnTick`. Name it clearly as a measurement
   variant, backtest-only. Do not "improve" anything while porting — any other change
   contaminates the measurement.

2. **CONTROL DISCIPLINE — this is the part that failed last time.** The previous fidelity
   number (0.914741) was meaningless because it compared a **July-14** binary
   (`a1de7a7b…`) against a **July-27** compile (`c29da61f…`) — execution-identity drift,
   two different programs (`docs/ops/evidence/2026-07-27_joint_ea_fidelity_diagnosis.md`).
   Both arms here MUST be compiled from the same source vintage, in the same session, on
   the same framework include tree. Record both `.ex5` SHA256 values in the report. If you
   cannot establish that the two arms are the same program apart from the timer change,
   the numbers mean nothing and you must say so instead of publishing them.

3. **Sweep the interval.** At minimum: 100 ms, 500 ms, 1 s, 5 s, 60 s, and one interval at
   the bar period. RECON A established that `OnTimer` runs on **simulated** time at ~10
   fires per simulated second for a 100 ms timer, and that its cost is `O(bars)` not
   `O(fires)` for real work — so a fine interval is affordable
   (`docs/ops/evidence/2026-07-27_ontimer_tester_semantics.md`). Note the timestamp
   resolution limit recorded there: all fires within one model second report the same
   second, which may itself bound the achievable match.

4. **Report the curve**: interval → `match_rate`, plus the mismatch decomposition at each
   point. Categorise as the diagnosis did: same entry / same volume / shifted exit, versus
   different entry, versus extra or missing trades. A curve that is flat in entries and
   only degrades in exits is the expected shape — confirm or refute it.

5. **Quantify the economic size, not just the match rate.** A 2% exit-timing difference
   that costs nothing is different from one that changes the P&L. Report the difference in
   total net P&L, in `wDD_p90`, and in FUND_SCORE between the two arms at each interval.
   **This is what actually decides the question** — a 0.97 match rate with identical
   FUND_SCORE is a pass for our purposes; a 0.99 match rate that moves FUND_SCORE
   materially is not.

## Constraints

- Reserve a terminal first (`farmctl.py reserve-terminal <T> --by codex --minutes <n>
  --reason "timer fidelity curve"`) and release it when done. **Never T5** (disabled) and
  never `C:/QM/mt5/T_Live`. Check `farmctl.py mt5-slots` first; ~2,000 items are queued
  behind you, so do not squat.
- Do NOT run `Factory_OFF.ps1` or `Factory_ON.ps1`. Do NOT re-import `.DWX` history.
- Do NOT modify the gated `QM5_9936` EA — it holds gate evidence. The timer variant is a
  separate, clearly-named artifact.
- Do NOT tune the timer variant to raise the match rate. Measuring the cost is the whole
  point; closing the gap by adjustment destroys the measurement.
- RISK_FIXED in the backtest sets. Builds serial. Commit with explicit pathspecs.

## Deliverable

`docs/ops/evidence/2026-07-27_timer_fidelity_curve.md`: both `.ex5` SHA256 values and the
proof they are the same program apart from the timer, the interval→match_rate curve, the
mismatch decomposition at each point, the P&L / `wDD_p90` / FUND_SCORE deltas, and a plain
answer to OWNER's question — **how big is the deviation actually, and does it matter.**
