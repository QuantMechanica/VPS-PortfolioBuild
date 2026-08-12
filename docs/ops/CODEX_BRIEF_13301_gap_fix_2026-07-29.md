# Codex brief — fix the session-gap miss in the 13301 timer variant, re-measure

Date: 2026-07-29
Priority: highest. OWNER decided: "Session Lücke reparieren und neu messen!"

## The measured defect

Deviation measurement tick vs 1s-timer (report-parsed, both arms PASS runs of
2026-07-28, evidence in the session record):

- 551 tick trades vs 282 timer trades; 137 exact, 145 same-entry/shifted-exit,
  **269 tick-only (49%)**, 0 timer-only.
- Exit shifts: median 1 s, p90 11 s — the 1s quantisation itself is excellent —
  but **max 82,163 s (~23 h)**.
- Net -49.9%; the missing trades cascade from the long-shifted exits: 13301 holds
  one position at a time, so a late exit blocks the next entry and shifts the whole
  sequence.

## The mechanism to fix

In the tester, OnTimer advances with SIMULATED time, which only moves while ticks
flow. Around a session gap (GDAXI overnight):

- the day's FINAL tick arrives (e.g. 22:00:00.7); the next timer fire would be due
  ~1 s later in sim time, which never comes before the gap;
- the per-tick original manages on that final tick and exits;
- the timer variant misses exactly that final tick, holds through the gap, and
  exits on the next morning's first fire — hours late. From there the
  single-position cascade produces the 49%.

## The fix — a catch-up call in OnTick, nothing else

In the variant's OnTick (framework/EAs/QM5_13301_timer-measurement/…mq5:78-93),
add a management catch-up: if >= 1 second of SIMULATED time has passed since the
last management run, execute the same management path the timer executes
(Strategy_ManageOpenPosition + QM13301_CloseOnStrategyExit), then update the
last-run stamp the timer also uses.

Properties this must keep:
- management still runs AT MOST once per simulated second (the 1s cadence is the
  thing being measured - do not tighten it);
- the final tick before a gap now always gets a management pass (the stamp is
  older than 1 s by then), and the first tick after a gap likewise;
- entries stay exactly as they are (bar-gated on OnTick);
- outside gaps, behaviour is identical: while ticks are dense the timer fires
  first and the OnTick catch-up finds the stamp fresh and does nothing.

Do NOT touch the gated QM5_13301 original, the framework, or the timer interval.

## Re-measure

1. Recompile the fixed variant; SHA256 recorded. The tick arm's PASS run of
   2026-07-28 19:27 stands as reference (its binary unchanged, report durable) -
   re-run ONLY the timer arm through the governed queue, staged EX5, priority
   track, avoid-T3, same window/model/set.
2. HARVEST DISCIPLINE, new: immediately after the run completes, copy the
   FILE_COMMON stream Common/Files/QM/q08_trades/13301_GDAXI_DWX.jsonl into the
   work-item evidence dir as q08_trades_13301_GDAXI_DWX.timer_v2.jsonl - the last
   measurement lost the tick arm's stream to truncation by the next run and had to
   be reconstructed from report.htm.
3. Produce the same two tables (trade decomposition, economic metrics incl.
   FUND_SCORE) against the tick reference, same methodology (report-parse the tick
   arm identically or reuse the recorded numbers: 551 trades, net 72,892.18,
   med60 1.763, |wDay| 1.853, wDDp90 5.019, FUND_SCORE 0.351).
4. State plainly whether the only-tick bucket collapsed. If a residual remains,
   decompose WHERE (still gap-adjacent? somewhere new?).

## Constraints

- Governed queue, staged EX5, serial compile, SHA256; avoid T3.
- Do NOT run Factory_OFF/ON; never T5, never T_Live; no re-imports.
- Explicit pathspecs; the variant file and evidence doc only.

## Deliverable

docs/ops/evidence/2026-07-29_13301_timer_v2_deviation.md with the tables and the
collapsed-or-residual verdict, teed up for OWNER's im-Rahmen decision.
