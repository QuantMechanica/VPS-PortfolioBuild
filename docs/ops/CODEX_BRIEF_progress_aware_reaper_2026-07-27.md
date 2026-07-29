# Codex brief — the Q02 reaper kills runs that are working. Make it progress-aware.

Date: 2026-07-27
Priority: highest. This may be the single largest throughput defect in the factory.

## The contradiction

`tools/strategy_farm/farmctl.py:224` sets

```python
"Q02": 45,     # one backtest per symbol; H1 full-history runs typically 5-20 min
```

while the work-item logs for the same runs record `timeout_seconds=7200` — a sanctioned
**two-hour** inner budget. **The outer reaper is tighter than the inner one and fires
first**, so the inner net never gets the chance to distinguish a hang from a slow run.

The 45-minute value has a documented origin (comment at `farmctl.py:217-223`): it was
tightened from six hours on 2026-05-23 after a hang incident, *because* the inner
`run_smoke.ps1 -TimeoutSeconds 1800` layer had failed silently and the outer layer was the
only safety net. That reasoning was sound at the time. The inner budget has since moved to
7,200 s, and the outer net was never revisited.

## The evidence that it is killing good work

`docs/ops/evidence/2026-07-27_fresh_infra_fail_diagnosis.md`, three of five cases:

- `49ab260f` QM5_9940/SP500: advanced 10 → 21 → 26 → 34 → 37 → 38 → 39 → **42%** over 40
  minutes, then was killed and replaced on T2 at 15:58:17. Its six-month prescreen had
  already **passed with 26 trades**.
- `b0af005d` QM5_10485/USDJPY: advanced 7% → **37%** between 19:12 and 19:52, then
  replaced at 19:53:59. Its prescreen **passed with 621 trades**.
- `93077cce` QM5_10591/GBPJPY: 0% for 15 minutes, 2% at ~45 minutes — genuinely slow, and
  a separate capacity question, but still killed while progressing.

All exited with `timed_out=False` and no report. Extrapolating the first two, a full run
needs roughly 90-100 minutes: the budget is about half of what the work takes.

Two of today's measurement tasks died the same way — the timer-fidelity control aborted at
19% and the vintage-check reproduction could not complete. This is not a rare edge.

## What to do

1. **Make the reaper progress-aware.** Kill on *absence of forward progress*, not on
   elapsed wall time. MT5 writes percentage progress to the terminal log
   (`D:/QM/mt5/T*/logs/<date>.log`), which is how the diagnosis above reconstructed these
   runs. A run that has advanced within the last N minutes is working and must not be
   reaped; one that has not is a hang and should be reaped **faster** than 45 minutes.
   That is strictly better than any fixed budget in both directions.
2. **Make the outer net looser than the inner net, never tighter.** Whatever fixed
   ceiling remains must be at least the sanctioned inner `timeout_seconds`. An outer net
   that pre-empts the inner one cannot distinguish anything.
3. **Preserve the 2026-05-23 protection.** The original incident was terminals stuck for
   an hour with a silently-failed inner layer. A progress-aware reaper handles that case
   better — no progress for N minutes is exactly what a hang looks like — but say
   explicitly how your design covers it, and keep an absolute ceiling as a backstop.
4. **Quantify the historical share.** This is the part that may reframe a lot: the
   dominant historical failure is `summary_missing_retries_exhausted` — 43,422 rows —
   which is precisely what a run killed mid-progress produces. Determine, from terminal
   logs and work-item logs, **what fraction of that graveyard shows forward progress at
   the moment it was killed.** Do not guess; if the logs no longer exist for older rows,
   say so and bound what is knowable.
5. Check the other phases for the same inversion. Q02 is where it was found; Q03-Q10 have
   their own budgets in the same table and their own inner timeouts.

## What NOT to do

- Do NOT simply raise 45 to 120 and call it fixed. That reintroduces the hang exposure the
  value was set to prevent and leaves the design still blind to whether work is happening.
- Do NOT requeue anything. 814 pairs are already in flight and will benefit automatically
  once the reaper stops killing them.
- Do NOT weaken the inner `run_smoke` timeout to compensate.

## Constraints

- The reaper is throughput-critical. Any change must **fail open** — if progress cannot be
  determined, do not kill a run that is inside its inner budget. MT5 saturation is the
  factory's primary metric and a reaper that stops reaping hangs is as bad as one that
  reaps good work.
- Log every reap decision with its reason and the progress evidence. Silent reaping is how
  this went unnoticed for two months.
- Do NOT run `Factory_OFF.ps1` or `Factory_ON.ps1`. T5 is disabled; never `C:/QM/mt5/T_Live`.
- Add a regression test.
- Commit with explicit pathspecs.

## Deliverable

`docs/ops/evidence/2026-07-27_progress_aware_reaper.md`: the mechanism, the change, how the
2026-05-23 hang case stays covered, the historical-share number from step 4, the test, and
whether the same inversion exists in other phases.
