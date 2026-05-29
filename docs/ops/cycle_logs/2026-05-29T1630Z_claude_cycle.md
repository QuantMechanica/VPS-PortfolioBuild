# Claude Orchestration Cycle Log — 2026-05-29T1630Z

## Status: COMPLETE — no IN_PROGRESS tasks; no routes created

---

## 1. farmctl health

Overall: **FAIL** (1 fail, 1 warn, 18 ok)

| Check | Status | Detail |
|---|---|---|
| `unbuilt_cards_count` | FAIL | 661 approved cards lack `.ex5` + auto-build task |
| `source_pool_drained` | WARN | 9 pending sources (threshold 10) |
| `mt5_worker_saturation` | OK | 10/10 terminal workers alive (T1–T10) |
| `mt5_dispatch_idle` | OK | 362 pending, 5 active, 6 fresh work_item logs |
| `p2_pass_no_p3` | OK | 0 pending promotion |
| `p_pass_stagnation` | OK | 60 Q03+ PASS in last 6h |
| `codex_zero_activity` | OK | 1 codex, 10 pending |
| `disk_free_gb` | OK | D: 30.2 GB free |
| `quota_snapshot_fresh` | OK | codex=41s, claude=41s |
| `codex_auth_broken` | OK | no 401 errors; auth_age=4.5h |

`unbuilt_cards_count` FAIL (661) is a known chronic condition — pump auto-build bridge emits 2 tasks/cycle. Not a factory emergency; throughput healthy.

---

## 2. Agent Router Status

- `agent_router.py run --min-ready-strategy-cards 5 --max-routes 5` → exit 0, no routes created
- `agent_router.py route-many --max-routes 5` → **no_routable_task**
- `agent_router.py list-tasks --agent claude --state IN_PROGRESS` → **empty []**

Active agents: Codex 1 IN_PROGRESS (ops_issue `9a8a422f`), Gemini 0 running.

---

## 3. QM5_10260 Queue State

Confirmed **eliminated at Q04**. Evidence:
- NDX.DWX: 1 `done/FAIL` Q04 item; remaining ~50 rows are `failed/INFRA_FAIL` (parameter sweep rows from grid_NNN setfiles — expected pattern)
- WS30.DWX: 1 `done/FAIL` Q04 item; same INFRA_FAIL sweep pattern

All work_items are terminal. No pending or active rows. Memory confirmed accurate.

---

## 4. SIGNIFICANT: Commission Fix `f308fe3f` Recycled — New Root Cause

The Q04 commission fix task (priority 5) moved to **RECYCLE** at 08:09Z with Codex's verdict:

> "RECYCLE: Crash fix (run_smoke.ps1 param not declared) confirmed done (commit 121da873). Commission still [$0] — groups file approach does NOT apply to .DWX Custom symbols. 3 verified backtests: Net==GP+GL to the cent."

**Third root cause discovered**: `.DWX` are Custom symbols not governed by `Darwinex-Live_real.txt`. The standard tester groups file mechanism does not apply to custom symbols. Commission application requires the **`CustomSymbolSetDouble SYMBOL_TRADE_COMMISSION`** MT5 API.

**Additional bugs found during investigation**:
- **Bug #6**: `-Expert` param passed with bare EA filename instead of `QM\<dir>` path (affects Q04/Q05/Q07 phases)
- **Bug #7**: `-Period` hardcoded to H1 — M15-timeframe EAs get 0 trades because no H1 bars match

**Current implication**: All Q02/Q03/Q04 PASSes remain gross-of-costs. Q04 commission gate has never successfully applied commissions.

**Required next scope** (new ops_issue needed):
1. Set `.DWX` custom symbol commission via `CustomSymbolSetDouble SYMBOL_TRADE_COMMISSION` (MT5 script or MQL5 API call before backtest)
2. Fix Expert path bug #6 (`QM\<dir>` prefix)
3. Fix Period hardcode bug #7 (read from card/work_item)
4. One calibration fold verifying commission deducted (Net < Gross)

Evidence at: `docs/ops/Q04_FIFTH_ROOT_CAUSE_commission_mechanism_2026-05-29.md` (canonical C:/QM/repo, commit fcecc833)

**OWNER note**: This is the fifth root cause identified for Q04. No new ops_issue task was auto-created for the follow-on scope; Codex or OWNER should create one to advance the fix.

---

## 5. Open APPROVED Tasks (Unassigned)

| ID | Title | Priority | Status |
|---|---|---|---|
| `43ca200e` | Fix Q08 aggregate.py sys.path parents[2]→[3] | 10 | APPROVED, unassigned |
| `af9d128a` | Q08 Davey trade log path design choice | 15 | APPROVED, unassigned — likely stale (fix verified 14:30Z) |

Router did not route either to Claude this cycle. Both require `ops/code/repo_edit` capabilities → Codex domain. Previous cycle already flagged `af9d128a` as potentially stale; OWNER should close it.

---

## 6. No Task Work Performed

No IN_PROGRESS tasks assigned to Claude this cycle. No artifacts produced. No router updates made.

---

## Recommended Actions

1. **OWNER/Codex**: Create new ops_issue for commission fix follow-on scope (CustomSymbolSetDouble + Bug #6 Expert path + Bug #7 Period hardcode + calibration)
2. **OWNER**: Close stale `af9d128a` Q08 design-choice task (implementation already done at commit 5e574572)
3. **Codex (via router)**: Pick up `43ca200e` aggregate.py parents[2]→[3] commit + push to main
4. **Factory**: Healthy — 60 Q03+ PASSes in 6h, all 10 workers alive, 362 pending work items
