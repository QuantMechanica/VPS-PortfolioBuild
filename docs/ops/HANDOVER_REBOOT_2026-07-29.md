# Emergency reboot handover — 2026-07-29

OWNER lost RDP access; VPS must be restarted. This document is the recovery map,
written from the still-live Claude session and pushed off-box before the reboot.

## What is durably saved

- Repo: everything committed and PUSHED to origin `agents/board-advisor`
  (`08fff811d` and this commit). All evidence docs, briefs, EAs, and the
  timer-variant gap fix (`08caa4187`) are off-box on GitHub.
- The farm DB (`D:/QM/strategy_farm/state/farm_state.sqlite`), reports on `D:`,
  and the Claude memory directory
  (`C:/Users/Administrator/.claude/projects/C--QM-repo/memory/`) live on disk and
  survive a reboot.

## In flight at reboot time (dies with the reboot, how to resume)

| item | state | resume |
|---|---|---|
| Codex task `49aeb2bc` — 13301 session-gap re-measure | IN_PROGRESS | lease goes stale after reboot; `agent_router.py route-many` re-dispatches. The gap-fix itself is already committed (`08caa4187`); only the timer-arm re-run + tables remain |
| Codex task `3fbc789c` — MNT round 4 | IN_PROGRESS | same lease-stale re-route |
| Codex task `3d5647ad` — router priority-ASC inversion + lane-death cleanup | TODO | routes normally |
| Factory queue (~2,300 pending) | survives in DB | workers resume via AT_STARTUP task |
| Any active backtests | killed by reboot | their work items retry through the normal queue |

## Post-reboot checklist (order matters)

1. **T_Live first.** The autostart chain was FIXED 2026-07-26 (incl. the news
   PS5.1 bug `e95efa9c1`) and should bring the live terminal up on its own.
   Verify from the T_Live log — live status ALWAYS from the log. DXZ 4000090541.
2. **Terminal workers**: scheduled task `QM_StrategyFarm_TerminalWorkers_AT_STARTUP`
   respawns them. If the fleet is wedged (terminal64 instant-exits, launch_fault):
   `Factory_OFF.ps1` then `Factory_ON.ps1 -NoPause` from an admin, VISIBLE
   session — a worker-only restart does not fix that class.
3. **Factory ON convention**: factory runs in OWNER's interactive session,
   visible mode, after login.
4. **THE CODEX LANE WILL NOT SELF-REVIVE.** Its 15-min orchestration task is in
   the interactive-queue-death class (`0x800710E0`, MNT-003). After login,
   relaunch by hand from `C:\QM\repo`:
   `pythonw.exe "C:\QM\repo\tools\strategy_farm\run_agent_orchestration_task.py" --agent codex --max-sessions 1`
   then verify `D:/QM/strategy_farm/state/lane_codex_heartbeat.json` refreshes,
   then `python tools/strategy_farm/agent_router.py route-many --max-routes 3`.
5. **News calendar**: the 05:30 task refreshes the `D:` source; verify the
   Common\Files copies are current (<336 h) — a stale copy is a hard init failure
   for every news-enabled EA (`QM_Common.mqh:204` returns false).
6. **Reserved terminals**: `farmctl.py mt5-slots`; release stale reservations
   with `release-terminal <T>`.
7. **Claude**: start a fresh session in `C:\QM\repo`. The memory index loads
   automatically and points here.

## Where the FTMO measurement stands (for the next session)

- **Joint EA QM5_20181**: runner fidelity **1.000000** (1,143/1,143 vs fresh
  standalone); satellite 10145 harvest WORKS (425 rows) after the ownership
  opt-in fix, but its fidelity gate FAILED pending investigation (`b4eb6cff`:
  0/425 matched vs 291 standalone — H1 ATR/news/timing defects named in the
  port). That investigation is an open item.
- **13301 timer simulation**: tick 551 vs timer-v1 282 trades — 49% cascade loss
  via the session-gap miss (final tick before a gap never got a management pass;
  single-position cascade). OWNER decided: fix and re-measure. The fix is
  committed (`08caa4187`, catch-up management in OnTick gated on >=1 s simulated
  time); the re-measure run and the two deviation tables are the open item, and
  OWNER's "im Rahmen" decision waits on them.
- **Vintage**: fresh-vs-archive true-overlap match 0.915136 (the earlier 0.8355
  was a window artifact); 72 shifted exits + ~25 entry diffs real; causal commit
  NOT ESTABLISHED; staged-EX5 probe pair (f0301ecf^ vs f0301ecf) was queued,
  deferred by a USDJPY lock. FUND_SCORE fresh 0.363 vs archived 0.409 — archived
  numbers (0.641 composition) must not be presented as current-tree.
- **Runner-alone anchor, fresh vintage**: first-passage **85.1%** at 1x.
- **Standing OWNER decisions**: the joint EA is a BACKTEST-ONLY instrument; live
  deployment = one gated EA per symbol (3 EAs). 13301 stays the slot-2 candidate
  pending the post-fix deviation tables; 13108 remains the built fallback.
