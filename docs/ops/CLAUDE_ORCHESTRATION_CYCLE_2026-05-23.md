# Claude Orchestration Cycle — 2026-05-23

**Last updated:** 2026-05-23T16:30Z (cycle-7)
**Worktree:** agents/claude-orchestration-3

---

## Status: IDLE — no Claude tasks assigned

The deterministic router returned 0 IN_PROGRESS tasks for `claude`. All active
`agent_tasks` are Gemini `research_strategy` / `dropbox-video-extraction` tasks requiring
the `video-analysis` skill that only Gemini holds. 3 tasks are stuck in TODO awaiting
Gemini bandwidth (Gemini at 2/2 capacity). No action available from Claude.

---

## Health (cycle-7, ~16:30Z)

| Check | Status | Detail |
|---|---|---|
| codex_review_fail_rate_1h | **FAIL** | 2/13 system-class FAILs across QM5_10022 + QM5_10034 |
| p_pass_stagnation | **FAIL** | 0 Q03+ PASS verdicts in last 12h — pipeline stuck |
| unenqueued_eas_count | **WARN** | 9 built EAs not yet enqueued for Q02 |
| mt5_worker_saturation | OK | 10/10 terminal_worker daemons alive (T1–T10) |
| mt5_dispatch_idle | OK | 2 pending (low queue) |
| All others (14) | OK | — |

**Changes since cycle-6 (16:15Z):**
- Pump consumed the 938 ready cards from cycle-6 into build tasks; all now building or built
- 21 EAs hit `permanent_blocked_retries_exhausted` on KillSwitch defect (see below)
- 9 newly-built EAs (QM5_10019 etc.) await Q02 enqueue
- INFRA_FAIL wave confirmed on QM5_10005/10717/10718/1099/1056
- 2 system-class code violations identified in QM5_10022 and QM5_10034

---

## Health (cycle-2, ~15:05Z) — archived

| Check | Status | Detail |
|---|---|---|
| mt5_worker_saturation | OK | 10/10 terminal_worker daemons alive (T1–T10) |
| p_pass_stagnation | WARN | 0 Q03+ PASS verdicts ever — normal pre-survivor state |
| All others (17) | OK | — |

**Change from cycle-1 (14:45Z):** MT5 workers came online. OWNER clicked Factory ON
between cycles. Workers are now live and consuming the queue as builds complete.

---

## FRAMEWORK DEFECT — KillSwitch naming collision (ESCALATED)

**Severity:** CRITICAL — now 21 EAs in `permanent_blocked_retries_exhausted` state.
Codex has tried 3 times each and given up. No further auto-retry will occur.

**Root cause:** Both header files define a global variable with the same name:

| File | Line | Declaration |
|---|---|---|
| `framework/include/QM/QM_KillSwitch.mqh` | 23 | `bool g_qm_ks_initialized = false;` |
| `framework/include/QM/QM_KillSwitchKS.mqh` | 48 | `bool g_qm_ks_initialized = false;` |

Both files have correct `#ifndef` include guards, so the error is not double-inclusion —
it is a naming collision. The MT5 compiler rejects the duplicate symbol at link time.
Error string in build records: `"duplicate globals in QM_KillSwitchKS.mqh/QM_KillSwitch.mqh"`.

**Affected EAs (permanent_blocked as of 16:21Z):**

QM5_10000, QM5_10001, QM5_10002, QM5_10003, QM5_10004, QM5_10005, QM5_10006, QM5_10007,
QM5_10009, QM5_10010, QM5_10012, QM5_10013, QM5_10014, QM5_10015, QM5_10017, QM5_10018,
QM5_10020, QM5_10022, QM5_10024, QM5_10025, QM5_10034

(21 EAs total. QM5_10005 also has downstream INFRA_FAIL on Q02 work items due to missing `.ex5`.)

**Required fix (Codex):** Rename `g_qm_ks_initialized` in `QM_KillSwitchKS.mqh` to
`g_qm_ksks_initialized` throughout that file (declaration + all usage sites).
After fix: reset all 21 task statuses from `failed` to `pending` and trigger rebuild.

---

## Pipeline State (cycle-7, ~16:30Z)

| Stage | Count | Notes |
|---|---|---|
| build_ea failed (KillSwitch) | 21 | retries exhausted; permanent_blocked |
| build_ea succeeded (this wave) | ≥11 | QM5_10019/21/23/26/27/28/38/39/41/42/43 + others |
| codex_review PASS | 9 | QM5_10019/21/23/26/27/28/39/41/42 |
| codex_review FAIL (system) | 2 | QM5_10022 (framework_corset), QM5_10034 (framework_corset + forbidden_grep) |
| work_items active | 2 | low queue; MT5 workers 10/10 live |
| work_items unenqueued | 9 | built+reviewed EAs pending Q02 dispatch |
| INFRA_FAIL Q02 | 5 EAs | QM5_10005/10717/10718/1099/1056 |

## System-Class Code Violations (cycle-7)

### QM5_10022 — `rw-dual-mom` — framework_corset FAIL

Codex built code that bypasses the bar-gate abstraction:

- `Strategy_IsMonthlyRebalance` uses direct `iTime` timestamp comparison at lines 65–66
  instead of `QM_IsNewBar`
- `OnTick` calls `Strategy_ExitSignal` before `QM_IsNewBar` at line 260, allowing
  per-tick execution of monthly rebalance logic

**Required fix (Codex):** Gate all bar-level logic through `QM_IsNewBar`; move
`Strategy_ExitSignal` call to after the new-bar check.

---

### QM5_10034 — `rw-pairs-z` — framework_corset FAIL + forbidden_grep FAIL

Codex built an EA with multiple framework violations:

- Direct include of `QM_BasketOrder.mqh` at line 6 — EA include surface must route
  through `QM_Common.mqh`
- `Strategy_OpenPair` calls `QM_BasketOpenPosition` at line 335 — must use
  `QM_TM_OpenPosition`
- Magic resolution uses `QM_MagicChecked` at line 258 — must use `QM_FrameworkMagic`
- `weights[` pattern found at lines 293, 295, 303 — forbidden (ML/weighting logic
  violates "no ML in V5 EAs" hard rule)

**Required fix (Codex):** Replace all four violations. The `weights[]` usage needs
architectural review — if it is a lookup table it must be renamed and justified; if it
is any form of learned weighting it must be eliminated entirely.

---

## Strategy Card Inventory (cycle-7, ~16:30Z)

| Bucket | Count | Notes |
|---|---|---|
| approved_cards | 2172 | +43 since cycle-2 (Codex build wave) |
| ready_approved_cards | 0 | All consumed into build tasks by pump |
| blocked_approved_cards | 2172 | Includes active builds; schema blocker still unmerged |
| draft_cards | 170 | Gemini in-flight Dropbox extraction |
| open build/review tasks | 4 | — |

**Schema blocker (unresolved):** Commit `357f93bf` (relaxed card validator: 10→5 required
body patterns) is on `agents/board-advisor` but not merged to main. OWNER merge required.

**Note on ready_approved_cards = 0:** The 938 ready cards from cycle-6 (16:15Z) were
consumed by the pump into build tasks between cycles. This is expected behaviour — the
pump correctly dispatched them. The 21 KillSwitch-blocked builds are the main concern.

---

## Router Unroutable Tasks

3 TODO `research_strategy` tasks cannot route (Gemini at 2/2 capacity). Self-resolves
when Gemini's in-flight tasks complete.

| Task ID | State |
|---|---|
| `6672fa16` | TODO — no_available_agent |
| `9abf0338` | TODO — no_available_agent |
| `aac25e1f` | TODO — no_available_agent |

---

## QM5_10260 Queue State

`work_items` count = 0. No active work items or agent tasks for QM5_10260.
Q02 TIMEOUT remains unresolved (cieslak-fomc-cycle-idx per-tick computation hangs 1800s).
EA is effectively orphaned — not re-enqueued. No change from prior cycles.

---

## Recommended Actions (Priority Order)

1. **[Codex] Fix KillSwitch naming collision — URGENT (21 EAs blocked)** — rename
   `g_qm_ks_initialized` → `g_qm_ksks_initialized` in `QM_KillSwitchKS.mqh` (all
   declaration + usage sites). After fix: reset all 21 `permanent_blocked` build tasks
   to `pending` and trigger rebuild. This also unblocks QM5_10005's downstream INFRA_FAILs
   (once `.ex5` exists, preflight will succeed).

2. **[Codex] Fix QM5_10034 framework violations** — replace direct `QM_BasketOrder.mqh`
   include, wrong open/magic calls, and eliminate `weights[]` pattern (ML-adjacent — hard
   rule violation). Needs architectural review of what `weights[]` is actually doing before
   re-build.

3. **[Codex] Fix QM5_10022 framework violations** — replace direct `iTime` bar-gate with
   `QM_IsNewBar`; move `Strategy_ExitSignal` call to after new-bar check.

4. **[OWNER] Merge `agents/board-advisor` → main** — unblocks the schema-relaxed validator
   and Q-phase runners. All 2172 approved cards are currently blocked; this is the single
   highest-leverage OWNER action.

5. **[Pump] Enqueue the 9 built+reviewed EAs** — QM5_10019/21/23/26/27/28/39/41/42 are
   built and PASS codex_review but have no Q02 work_items. Pump should dispatch these on
   its next tick; if not, manual `enqueue-backtest` per EA.

6. **[Standing] QM5_10260 perf rework** — cieslak-fomc-cycle-idx needs per-tick
   computation refactor before re-enqueue. Not a strategy rejection.
