# Scheduled-task triage: 6 recurring failures + stale task_monitor sidecar + WAL checkpoint starvation

- **Task ID:** 05035f17-f0a7-4823-9bb4-dc10ad01f532 (claude, ops_issue, priority 60)
- **Commissioned by:** claude-orchestrator 2026-08-24 Factory-CEO-Session
- **Evidence source:** `farmctl health` 2026-08-24T14:11Z + WAL observation 16:23 local
- **Generated:** 2026-08-24, claude-orchestration-3 (headless single-pass cycle)

## Summary table

| Task/finding | Root cause | Disposition |
|---|---|---|
| `QM_StrategyFarm_Dashboard_Hourly` | `ModuleNotFoundError: rebaseline_census` (transitive import bug) | **FIXED** |
| `QM_StrategyFarm_PipelineState` | Same root cause as above | **FIXED** (same fix) |
| `QM_StrategyFarm_PortfolioReport` | Unhandled `BookBuildRefused` from a correct fail-closed guard | **FIXED** (graceful handling) |
| WAL checkpoint starvation (459MB WAL) | `pump_maintenance()` had no explicit checkpoint step | **FIXED**, live-verified: 437MB → 0 |
| `QM_StrategyFarm_PlausibilityScan` (killed@time-limit) | Script itself is fast (~2.5 min); large WAL was the likely aggravator | **Addressed via the WAL fix above**; no script change needed |
| `QM_StrategyFarm_MailboxSourceIntake_Daily` | Requires an active interactive/console session for `qm-admin`; currently disconnected | **Known-benign** — VPS session-state, not code |
| `QM_StrategyFarm_FactoryON_AtLogon` | Same interactive-session dependency (by design, per the Factory-interactive-visible-mode decision) | **Known-benign** — VPS session-state, not code |
| `QM_EvidenceCohortWatch_Daily_0420` (exit 3) | Exit 3 is the tool's documented "LOSS OBSERVED" signal, working as designed | **Known-benign** for the scheduler; underlying finding (280 missing evidence roots) escalated separately, §6 |
| `task_monitor` sidecar (181 min stale at evidence time) | Correlated with a dead-PID pump lock stalling the pump cycle the sidecar refresh rides on | **Transient, self-resolved** — 38 min old at investigation time, well under the 90-min WARN threshold |

## 1. `QM_StrategyFarm_Dashboard_Hourly` + `QM_StrategyFarm_PipelineState` — FIXED

Both run different entrypoints (`tools/strategy_farm/dashboards/render_dashboards.py`,
`scripts/build_pipeline_state.py`) that transitively import
`tools/strategy_farm/operator_surfaces.py` → `tools/strategy_farm/backfill_planner.py`.
`backfill_planner.py` had a bare `import rebaseline_census as census` — a same-directory
sibling module, not a package member. When invoked as a dotted package import (as both
of these entrypoints do — `from tools.strategy_farm import gate_manifest,
operator_surfaces`), only the repo root sits on `sys.path`, so the bare import raised
`ModuleNotFoundError: No module named 'rebaseline_census'`, reproduced directly:

```
python scripts/build_pipeline_state.py
Traceback (most recent call last):
  ...
  File "C:\QM\repo\tools\strategy_farm\backfill_planner.py", line 30, in <module>
    import rebaseline_census as census
ModuleNotFoundError: No module named 'rebaseline_census'
```

**Fix:** `tools/strategy_farm/backfill_planner.py` now inserts its own directory onto
`sys.path` before the bare import (matching the established pattern already used by
`agy_governor.py` and several `farmctl.py` sites — `sys.path.insert(0,
str(Path(__file__).resolve().parent))`), so the import resolves the same way whether
the module is run standalone or imported through the package.

**Verification (live, direct runs of the actual failing entrypoints):**
```
python scripts/build_pipeline_state.py                              -> exit 0
python tools/strategy_farm/dashboards/render_dashboards.py          -> exit 0 ("ea_metrics refreshed: 53690 upserts, 8067 unchanged")
```

## 2. `QM_StrategyFarm_PortfolioReport` — FIXED

```
python tools/strategy_farm/portfolio/portfolio_periodic_report.py
Traceback (most recent call last):
  ...
  File "...\book_build_guard.py", line 228, in require_book_build_allowed
    raise BookBuildRefused(result)
tools.strategy_farm.book_build_guard.BookBuildRefused: BOOK_BUILD_REFUSED:
qualified_pairs_below_minimum: 0 < 25; owner_order_missing: venue=dxz
order_dir=C:\QM\repo\decisions (qualified_pairs=0, distinct_eas=0, strategy_families=0)
```

The book-build guard is correctly, deliberately fail-closed — there is genuinely no
live book to report on yet (0 qualified pairs, no OWNER order). That is not a defect.
The defect is that `portfolio_periodic_report.py`'s `main()` never caught this
exception, so an entirely expected "not ready yet" condition surfaced as an unhandled
scheduled-task failure — even though the script already has graceful handling for
every *other* non-"ok" report status (an `else: print(f"portfolio report: {status}
...")` branch a few lines further down that this exception bypassed entirely).

**Fix:** `main()` now catches `book_build_guard.BookBuildRefused` around the
`build_report()` call and prints the same kind of informational line the script
already prints for other incomplete-report cases, then returns 0. The guard itself —
its thresholds, its fail-closed behavior — is completely untouched; only the caller's
error handling changed.

**Verification:**
```
python tools/strategy_farm/portfolio/portfolio_periodic_report.py
portfolio report: book_build_refused (qualified_pairs_below_minimum: 0 < 25;
owner_order_missing: venue=dxz order_dir=C:\QM\repo\decisions; qualified_pairs=0)
[exit 0]
```
New test `test_main_handles_book_build_refused_gracefully` in
`tools/strategy_farm/tests/test_portfolio_periodic_report.py` (constructs a real
`BookBuildRefused` via the module-under-test's own bound `book_build_guard` reference
— needed because `portfolio_periodic_report.py` resolves `book_build_guard` via
either a dotted or bare import depending on `__package__`, and a naive fresh import in
the test would construct a *different* module object / exception class than the one
`except` actually matches against). `python -m pytest -q
tools/strategy_farm/tests/test_portfolio_periodic_report.py` → **3 passed**.

## 3. WAL checkpoint starvation — FIXED, live-verified

`D:\QM\strategy_farm\state\farm_state.sqlite-wal` was **458,910,352 bytes (≈437MB)**
at investigation time and actively growing. `pump_maintenance()` (the hourly
maintenance command) ran `ea_metrics` refresh, a zero-trade census, and an online
`.backup()` snapshot — but **never issued a WAL checkpoint**. SQLite's implicit
PASSIVE auto-checkpoint (default ~1000-page threshold) cannot fully truncate while any
other connection holds an open read snapshot, and with ~10 `terminal_worker` daemons
plus assorted readers hitting this one DB nearly continuously, it evidently never gets
a clean window.

**Fix:** added `_wal_checkpoint(root)` to `tools/strategy_farm/farmctl.py`, called
from `pump_maintenance()` and included in its return dict under `"wal_checkpoint"`.
It opens a short-`busy_timeout` connection (same 750ms farm-wide policy as every other
connection — `sqlite_busy.BUSY_TIMEOUT_MS`, no long-blocking-stall doctrine), issues
`PRAGMA wal_checkpoint(PASSIVE)` then `PRAGMA wal_checkpoint(TRUNCATE)`, and reports
before/after WAL byte size. Both modes are non-blocking for writers by SQLite design;
a busy/blocked TRUNCATE just reports `busy=true` and makes partial progress rather
than raising.

**Live verification (real production DB, via `farmctl.py pump-maintenance` — the
exact command the scheduled task already runs hourly, nothing ad hoc):**
```
python tools/strategy_farm/farmctl.py pump-maintenance
"wal_checkpoint": {
  "before_wal_bytes": 458910352,
  "after_wal_bytes": 0,
  "reclaimed_bytes": 458910352,
  "passive": {"busy": false, "checkpointed_pages": 10308, "log_pages": 10308},
  "truncate": {"busy": false, "checkpointed_pages": 0, "log_pages": 0}
}
```
Confirmed on disk: `farm_state.sqlite-wal` is now 0 bytes.

New tests in `tools/strategy_farm/tests/test_pump_maintenance_wal_checkpoint.py` (4
tests): a synthetic WAL with real content is checkpointed and shrinks; a missing DB is
handled non-fatally; the checkpoint body issues only `PRAGMA`/read statements (never
`work_items` or an `INSERT`/`UPDATE`/`DELETE`); `pump_maintenance()`'s return dict
carries the new key without touching `dispatch_performed`/`verdicts_changed` (still
both `False`, per the function's own documented contract). `python -m pytest -q
tools/strategy_farm/tests/test_pump_maintenance_wal_checkpoint.py` → **4 passed**.
Adjacent `test_maintenance_control.py` re-verified: **39 passed**.

**Rollback:** the call is additive and self-contained (one line added to
`pump_maintenance()`'s body plus the new helper function); removing both restores the
exact prior implicit-only checkpoint behavior.

## 4. `QM_StrategyFarm_PlausibilityScan` (killed@time-limit, result 267014) — addressed via §3, no script change

`ExecutionTimeLimit` is configured at 15 minutes (`PT15M`); result code `267014`
(`0x41306`) is Task Scheduler's own "terminated for exceeding the execution time
limit" signal. Timed a real, direct run against the current (post-checkpoint) DB:
**143 seconds (~2.4 minutes)**, well under the 15-minute limit, and the script has no
internal timeout/kill logic of its own (`grep` for timeout/kill in
`plausibility_scan.py` returns nothing) and opens its SQLite connection with no
explicit busy handling (`sqlite3.connect(DB)`, no `timeout=`). A ~437MB WAL forces
every reader to reconstruct current state through a much larger log before it can
answer a query, which is a plausible (though not incident-reproduced, since I cannot
retroactively force the historical WAL-bloat conditions) explanation for why a
normally-2.4-minute scan could occasionally cross a 15-minute ceiling on a bad day.
Rather than touching the scan's logic — which is not itself slow — this is addressed
by the WAL checkpoint fix in §3, which will keep the WAL from re-bloating to that
scale going forward (checkpointed hourly by `pump_maintenance` from now on). If
`PlausibilityScan` is still observed hitting the time limit after the WAL fix has had
a few cycles to prove itself, that would indicate a different, deeper cause worth a
follow-up ticket — not something to guess at further right now.

## 5. `QM_StrategyFarm_MailboxSourceIntake_Daily` + `QM_StrategyFarm_FactoryON_AtLogon` — known-benign, VPS session state

Both depend on an active interactive session for `qm-admin`:

- `FactoryON_AtLogon` runs with `LogonType: Interactive, UserId: qm-admin`, triggered
  by a logon event. Its last recorded result, `2147946720` = `0x800710E0` =
  *"The operator or administrator has refused the request"* — the classic Task
  Scheduler error when the configured interactive session isn't actually available at
  trigger time.
- `MailboxSourceIntake_Daily` runs as SYSTEM but its action is
  `run_in_console_session.ps1 -TargetUser qm-admin`, which uses
  `WTSGetActiveConsoleSessionId` + `WTSQueryUserToken` to launch the real script
  *inside* qm-admin's session on the active console. If that session has no user
  token to duplicate, the launch fails (result `1`).

Checked live VPS session state (`query session`, `WTSGetActiveConsoleSessionId`):

```
 SESSIONNAME       USERNAME                 ID  STATE   TYPE        DEVICE
>services                                    0  Disc
 console                                     2  Conn
                   qm-admin                  3  Disc
 rdp-tcp                                 65536  Listen

WTSGetActiveConsoleSessionId() = 2
```

The active **console** session (id 2, the one `run_in_console_session.ps1` targets)
currently has **no user logged in** — it's sitting unattended. `qm-admin`'s actual
session (id 3) exists but is **disconnected** (an RDP session not currently
connected), not the active console. Both tasks are working exactly as designed; they
simply require `qm-admin` to be actively on the console (or the autologon session to
match) to succeed, and right now it isn't. This is standing VPS session/autologon
state — memory record `feedback_factory_interactive_visible_mode_2026-05-23`
documents that `FactoryON_AtLogon`'s interactive design is deliberate (Factory must
run visible in an OWNER session, not headless SYSTEM), so **no code fix is proposed**;
this is flagged as known-benign for the scheduler's purposes, with the concrete
session-state cause on record for whoever next RDPs in. No VPS session/autologon
reconfiguration was attempted — that is an infrastructure change outside this task's
scope and this agent's authority.

## 6. `QM_EvidenceCohortWatch_Daily_0420` (exit 3) — known-benign scheduler signal, but escalating the underlying finding

```
EXIT CODES (from the script's own docstring)
    0  no loss observed
    3  LOSS OBSERVED -- at least one baselined root disappeared
```

Exit 3 is a deliberate, documented alert code — the "task failure" the scheduler
records is the tool correctly doing its job. Re-ran it live:

```
COHORT_CHECK watched=1205 intact=925 file_missing=280 root_missing=0
COHORT_CHECK RESULT=LOSS_OBSERVED -- evidence deletion is ONGOING, not historical.
[exit 3]
```

**This is not a scheduled-task defect, but it is a real and significant standing
finding that deserves its own attention separate from this triage: 280 of 1205
watched baselined evidence roots (23%) have disappeared, and the tool's own docstring
already documents this as part of a larger, still-unexplained pattern (~35,900
verdicts farm-wide whose backing `summary.json` provably existed at grading time and
is now gone, with the deleting mechanism actively searched for and not yet found as
of this tool's authorship).** No further investigation was performed here — that is a
distinct, larger forensic task, not a "fix this scheduled task" task. Recommend
routing as its own priority ticket rather than letting it sit inside an exit-code
footnote.

## 7. `task_monitor` sidecar staleness — transient, self-resolved

The evidence source cited "task_monitor-Sidecar 181min alt" (181 minutes old) as of
the 14:11Z snapshot. Checked live: `D:\QM\reports\state\task_monitor_health.json` has
`"checked_at": "2026-08-24T17:00:05Z"`, ~38 minutes old at investigation time —
comfortably under the health check's own 90-minute WARN threshold
(`health.py:138`). No `task_monitor` daemon process is currently running (it is
invoked periodically, not resident), so the sidecar refreshes on its own cadence
rather than continuously. The file's own most recent content is itself informative —
its top finding was `pump_task_lastresult: pump_task.lock held by dead PID 37560, age
1348s; pump cycles no-op until the 1200s stale threshold clears it` — a stale pump
lock that would self-clear at the 1200s (20-minute) threshold, plausibly explaining a
temporary refresh gap that has since closed. No code change is proposed; if this
recurs and does not self-resolve within its own documented staleness window, that
would be a separate, real ticket.

## 8. Artifacts

- Fixes: `tools/strategy_farm/backfill_planner.py`,
  `tools/strategy_farm/portfolio/portfolio_periodic_report.py`,
  `tools/strategy_farm/farmctl.py` (`_wal_checkpoint`, `_wal_file_size`,
  `pump_maintenance`).
- Tests: `tools/strategy_farm/tests/test_pump_maintenance_wal_checkpoint.py` (new),
  `tools/strategy_farm/tests/test_portfolio_periodic_report.py` (extended).
- This document.
- `artifacts/evidence_cohort_baseline.json` picked up one new observation row from the
  live `evidence_cohort_watch.py` run in §6 (the tool's own normal, designed
  behavior — it always appends an observation on `--check`; nothing was deleted or
  rewritten).

## 9. Not done

- No scheduled task was deleted (constraint honored).
- No VPS session/autologon/RDP configuration was changed (§5) — flagged for OWNER
  attention, not acted on.
- No investigation was launched into the underlying evidence-deletion mechanism (§6)
  — recommended as a separate ticket, not absorbed into this one.
