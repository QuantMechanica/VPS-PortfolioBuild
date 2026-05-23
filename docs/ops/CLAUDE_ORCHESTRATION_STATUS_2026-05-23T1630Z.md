# Claude Orchestration Status 2026-05-23T16:30Z

Status: IDLE — no IN_PROGRESS claude tasks; system-class codex failures flagged

## Router outcome

- `agent_router.py status` — 2 Gemini tasks IN_PROGRESS, 3 TODO (unrouted), 0 Claude tasks.
- `agent_router.py run --min-ready-strategy-cards 5 --max-routes 5` — research replenishment
  frozen (`generic_research_replenishment_frozen_edge_lab_primary_2026-05-22`); 0 ready approved
  cards (2172 approved, all blocked by schema blocker on agents/board-advisor). One TODO task
  could not route (`no_available_agent`).
- `agent_router.py route-many --max-routes 5` — same: 1 unroutable task.
- `agent_router.py list-tasks --agent claude` — returned empty; nothing to process.

All 3 TODO tasks require `source_discovery` capability (Gemini-only). Gemini is at 2/2 capacity
and cannot accept more. Tasks will auto-route when a Gemini slot frees.

## Health snapshot

`farmctl health` overall: **FAIL** (2 FAILs, 1 WARN)

| Check | Status | Detail |
|---|---|---|
| `codex_review_fail_rate_1h` | **FAIL** | 3/13 FAILs in 1h; 2 EAs with system-class failures |
| `p_pass_stagnation` | **FAIL** | 0 Q03+ PASS verdicts in 12h — structural, no Q03+ items |
| `unenqueued_eas_count` | WARN | 9 reviewed EAs without Q02 work_items (pump will enqueue) |
| `mt5_worker_saturation` | OK | 10/10 workers alive |
| `mt5_dispatch_idle` | OK | 2 pending (low queue) |

### System-class codex review failures — requires Codex rework

**QM5_10034** (`rw-pairs-z`) — FAIL on `framework_corset` + `forbidden_grep`
- EA directly includes `QM_BasketOrder.mqh` instead of going through `QM_Common.mqh`
- Opens via `QM_BasketOpenPosition` instead of `QM_TM_OpenPosition`
- Magic resolution uses `QM_MagicChecked` instead of `QM_FrameworkMagic`
- `forbidden_grep`: `weights[` pattern at lines 293, 295, 303
  - **Flag for OWNER**: `weights[]` in a cross-sectional RV EA could be legitimate basket
    weighting or a stealth ML artifact. Codex must determine the pattern before rework.
    Hard Rule 14 bans ML inside EAs; if this is coefficient-trained weights it must be removed.
- Evidence: `D:\QM\strategy_farm\artifacts\verdicts\codex_review_a57953a5-a367-4dae-a211-5bf82578cb35.json`

**QM5_10022** (`rw-dual-mom`) — FAIL on `framework_corset`
- `Strategy_IsMonthlyRebalance` uses direct `iTime` timestamp gate instead of `QM_IsNewBar`
- `OnTick` calls `Strategy_ExitSignal` before `QM_IsNewBar` — monthly rebalance logic runs
  per tick, not per new bar
- Evidence: `D:\QM\strategy_farm\artifacts\verdicts\codex_review_1c4590a2-4a67-4713-939f-adcea3c458d3.json`

Both EAs need Codex `code` + `repo_edit` tasks. Not routable to Claude.

### p_pass_stagnation — structural, not an incident

All pipeline EAs are at Q02 (backtests active or just enqueued). There are no Q03+ items in
the queue; the check is expected to FAIL at this stage. This is not a factory outage.
Active Q02 backtests: QM5_10019, QM5_10020, QM5_10021 (all running at time of cycle).

## QM5_10260 queue state

`farmctl work-items --ea QM5_10260` → 0 items. Confirmed empty — the full TIMEOUT washout
from the 2026-05-22 triage (37 symbols all hit 1800s). Not a strategy rejection; the EA
has not been re-enqueued since the TIMEOUT diagnosis. Requires OWNER decision: either
schedule a performance rework task for Codex or formally close the EA.

## Ongoing INFRA_FAILs (not new this cycle)

- **QM5_10005**: `ex5_missing` — KillSwitch naming defect (g_qm_ks_initialized double-defined)
  prevents compilation. Tracked in memory. Awaiting Codex rename in QM_KillSwitchKS.mqh.
- **QM5_10717 + QM5_10718**: Q02 `NO_REAL_TICKS` + `INCOMPLETE_RUNS` — basket EAs failing
  determinism check. `model4_log_marker_detected=false`. May indicate real-tick data not
  loading for these symbols/periods. Tracked in memory. Assign Codex investigation.
- **QM5_1056 + QM5_1099**: Isolated symbol INFRA_FAILs (AUDNZD, CADCHF, CADJPY) mixed with
  strategy-level FAILs — normal Q02 washout pattern; not system-class.

## Schema blocker (persistent)

2172 approved cards blocked; fix commit 357f93bf on `agents/board-advisor` NOT on `main`.
OWNER must merge board-advisor to main to unblock the 938 new cards and the remaining
1223 old corpus. Ready approved cards = 0.

## Next recommended actions (for OWNER / router)

1. **Merge `agents/board-advisor` → `main`** to unblock 2172 cards (schema fix 357f93bf).
2. **Codex tasks needed**:
   - QM5_10034: framework_corset + forbidden_grep rework (audit `weights[]` first)
   - QM5_10022: QM_IsNewBar migration + OnTick ordering fix
   - QM5_10005: KillSwitch rename (g_qm_ks_initialized in QM_KillSwitchKS.mqh)
   - QM5_10717/QM5_10718: investigate NO_REAL_TICKS on D1 EURUSD
3. **QM5_10260**: OWNER decision — schedule Codex perf rework or close.
