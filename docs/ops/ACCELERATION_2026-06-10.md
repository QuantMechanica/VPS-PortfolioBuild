# Factory Acceleration — 2026-06-10 (Claude, OWNER-directed)

OWNER directive: "Codex max to 6, Claude max to 4. Do the rest as well. Bigger
VPS not possible. A job should delete not-needed logs. Check reboot/RDP
robustness. Update documents. Suggest gate acceleration."

## Audit findings (evidence-first)

| Finding | Number | Evidence |
|---|---|---|
| Approved cards | 2,634 | `D:\QM\strategy_farm\artifacts\cards_approved` |
| Built with .ex5 | 1,113 | `C:\QM\repo\framework\EAs` scan |
| Built but ZERO backtests ever | 371 | `claude_sweep_enqueue_2026-06-10.json` |
| Cards stuck at r_gate_not_pass | **1,212** | `claude_prime_builds_2026-06-10.json` |
| Unconsumed auto-r-eval inbox files | 1,323 | `D:\QM\strategy_farm\codex_inbox` (consumer dead since 2026-05-17/20) |
| Build-eligible unbuilt cards | 227 | same |
| Build failures last 7d | 163 (83 compile, 45 smoke-contention false) | tasks DB scan |
| Dead .log on D: | **475 GB** (445 work_items + 70 smoke) | reports_log_purge.log 2026-06-10T21:08–21:10Z |

**Root cause of "half the cards not coded":** the pump queues R-gate
evaluations as `auto-r-eval-*.md` files into `codex_inbox`, but the
goal-bridge consumer died 2026-05-17 and the DB-path replacement never covered
R-evals. 1,212 approved cards therefore never became build-eligible.

**Root cause of "built but never tested":** Q02 auto-enqueue only fires on the
build-task completion path; 371 EAs built outside it (primed/older vintages)
never entered the pipeline — including the 2026-06-09 force-build edge cohort
QM5_1049/1047/1085.

## Changes applied tonight

1. **Parallelism (OWNER numbers):** `claude_parallel.txt` = 4 (immediately);
   `QM_ClaudeParallel_RestoreOnReset` now restores 4. `codex_parallel.txt`
   stays 1 until the Codex weekly reset (quota at 100%);
   `QM_CodexParallel_RestoreOnReset` retargeted to **2026-06-11 03:35 local**
   (after the 01:28 UTC quota reset) and now writes **6**.
2. **Sweep-enqueue** (`tools/strategy_farm/sweep_enqueue_built_eas.py`,
   task `QM_StrategyFarm_SweepEnqueue_Hourly`): wave 1 enqueued **1,694 Q02
   items** (built-never-tested EAs, strategy-priority order, edge cohort
   flagged `priority_track`) + **64 stranded INFRA_FAIL re-runs**
   (29×Q02, 34×Q03, 1×Q08). Queue-ceiling 7,000 keeps the build-backpressure
   soft limit (8,000) free; the hourly task tops up the remaining ~139 EAs as
   the queue drains, then no-ops. Evidence:
   `D:\QM\reports\state\claude_sweep_enqueue_2026-06-10.json`.
3. **R-eval drain lane** (`tools/strategy_farm/r_eval_drain.py`, task
   `QM_StrategyFarm_REvalDrain_15min`): batches of 12 UNKNOWN cards per
   headless Sonnet spawn, updates R1–R4 frontmatter in place per
   `processes/qb_reputable_source_criteria.md`, archives the matching inbox
   files, quota-guarded at 85% (Claude weekly + Sonnet weekly), lock-file +
   IgnoreNew. Test batch: 12/12 evaluated, reasoning spot-checked
   (QM5_10061). Drains ~1,212 cards in ≈25 h, feeding the build lane.
   Log: `D:\QM\reports\state\r_eval_drain.jsonl`.
4. **Build priming** (`claude_prime_builds_2026-06-10.py`, one-shot): 86
   build_ea tasks created in priority order (141 of the 227 eligible were
   rejected by prebuild validation — card defects: 30
   `expected_trades_per_year_per_symbol_missing`, ~100
   `entry_frequency_implausible`; these need card remediation, not builds).
   Evidence: `D:\QM\reports\state\claude_prime_builds_2026-06-10.json`.
5. **farmctl fixes** (this commit):
   - `SMOKE_CONTENTION_MARKERS` + `MAX_SMOKE_INFRA_RETRIES=3`: a codex-review
     FAIL carrying `METATESTER_HUNG` / `REPORT_MISSING` / "smoke report
     missing" is factory-contention infra, not a code finding — it now gets a
     bounded free rework retry instead of burning the 2-attempt budget into a
     permanent block (45/163 of last week's build failures).
   - `MAX_AUTO_CREATED_BUILDS_PER_PUMP` 1 → 3 (keep the pending pool fed at
     codex_parallel=6).
   - Amnesty scan for already-exhausted contention victims found **0 needing
     reset** (48 had their .ex5 built anyway → covered by sweep-enqueue; 3
     already pending). Evidence:
     `D:\QM\reports\state\claude_contention_amnesty_2026-06-10.json`.
6. **Disk (OWNER: "job to delete not-needed logs"):** the job existed
   (`reports_log_purge.ps1`, 12h cadence, 48h retention) but was mistuned —
   at ~1,500 work items/day, 48h of MT5 tester journals = 300–900 GB. D: was
   at **7 GB free** tonight. Retuned to **6h retention, every 3h,
   multi-root** (now also covers `D:\QM\reports\smoke`). Reclaimed **475 GB**
   (D: 7 → 452 GB free). `.log` journals hold no trades/metrics/config; all
   evidence (summary.json, report.htm, .set, .csv) is untouched.
   `QM_StrategyFarm_TesterCachePurge` (3h, <80 GB trigger) unchanged.

## Reboot / RDP robustness (verified, no action needed)

- **VPS reboot:** AutoAdminLogon=1 (qm-admin) → `QM_StrategyFarm_FactoryON_AtLogon`
  runs `Factory_ON.ps1` → factory up without OWNER. All controller lanes
  (Pump/Tick/Router/Orchestrations/QuotaPull/purges + tonight's two new tasks)
  are SYSTEM time-triggered → boot-persistent.
- **RDP window closed (disconnect):** `QM_TSCon_Console_OnDisconnect`
  (EventID 24) reattaches the console so GUI terminals keep a desktop.
- **Workers die or wedge:** `QM_StrategyFarm_FactoryWatchdog_15min` respawns
  via the console-session launcher; dispatch-stall detection + tscon
  escalation (only on disconnected sessions) hardened 2026-06-09.
- `QM_StrategyFarm_TerminalWorkers_AT_STARTUP` is **intentionally disabled**
  (session-0 cannot spawn visible terminals); `Factory_ON.ps1` is the designed
  path. Old runbook note "check AT_STARTUP after reboot" is obsolete.
- **Remaining gap:** a full *sign-out* of qm-admin (vs. closing/disconnecting
  RDP) kills the console session until the next reboot. OWNER: disconnect,
  never sign out. (Watchdog cannot CreateProcessAsUser without any session.)

## Expected effect

- Backtest queue: 5,317 → ~7,000 pending, prioritized (deep phases first,
  priority_track cohort at the head). Throughput stays 8-core-bound
  (~1,300–1,800 items/day) — the queue is now fed with *already-built* EAs
  instead of idling on an artificially starved frontier.
- Build lane: 86 primed tasks now + Codex back at 6-parallel after tonight's
  reset + Claude lane at 4 → plausibly 150–300 builds/day vs. ~60.
- R-gate wall: dissolves over ~25 h; eligible cards flow to the build queue
  continuously (FAIL verdicts are also progress — they keep weak cards out).

## Risks / watch

- R-eval at Sonnet quality: strict-FAIL instructed; spot-check
  `r_eval_drain.jsonl` samples tomorrow. Guard pauses the lane at 85% quota.
- Disk burn scales with queue depth; with 6h retention the standing log mass
  is ~40–110 GB. Watch `reports_log_purge.log` for a few days.
- `QM_StrategyFarm_ReportsLogPurge_12h` task name is now misleading (runs 3h).
- 141 prebuild-rejected cards need card remediation (frequency frontmatter) —
  candidate for a Codex ops_issue.

## Gate-acceleration suggestions → see OWNER report (proposals only, no gate changes made)
