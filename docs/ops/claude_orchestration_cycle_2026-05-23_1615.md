# Claude Orchestration Cycle Report — 2026-05-23 1615

**Cycle time:** 2026-05-23T16:15Z  
**Worktree:** agents/claude-orchestration-2  
**Overall health:** FAIL (2 FAIL, 1 WARN, 16 OK)  
**Claude IN_PROGRESS tasks:** 0

---

## Farm Health Summary

| Check | Status | Detail |
|---|---|---|
| mt5_worker_saturation | OK | 10/10 terminal workers alive (T1–T10) |
| active_row_age | OK | No rows past phase timeout |
| codex_zero_activity | OK | 14 codex tasks, 2 pending |
| disk_free_gb | OK | D: free 154.5 GB |
| pump_task_lastresult | OK | Last pump exit 0 |
| quota_snapshot_fresh | OK | codex=24s, claude=24s |
| **codex_review_fail_rate_1h** | **FAIL** | 2/8 system-class FAILs in last hour — see below |
| **p_pass_stagnation** | **FAIL** | 0 Q03+ PASS verdicts in 12h |
| unenqueued_eas_count | WARN | 5 EAs with no P2 work_items (QM5_10019/21/23/26/27) |
| cards_ready_stagnation | OK | 0 ready; replenishment frozen (schema blocker active) |

**Active terminals:** T1 (smoke: QM5_10035), T3 (smoke: QM5_10024)  
**Gemini:** 2/2 slots IN_PROGRESS (video extraction), 3 tasks TODO (blocked: no capacity)

---

## FAIL 1: codex_review_fail_rate_1h — Real Framework Violations in QM5_10034

**EA:** QM5_10034 (rw-pairs-z) — build status: `blocked`, codex_review `FAIL`  
**Evidence:** `D:/QM/strategy_farm/artifacts/verdicts/codex_review_a57953a5-a367-4dae-a211-5bf82578cb35.json`

Codex's build has genuine framework_corset and forbidden_grep violations — not a smoke infrastructure issue:

| Section | Status | Finding |
|---|---|---|
| framework_corset | FAIL | EA includes `QM_BasketOrder.mqh` directly at line 6; must go through `QM_Common.mqh` |
| forbidden_grep | FAIL | `weights[` pattern found at lines 293, 295, 303 |
| magic_registry | PASS | — |
| build_result | PASS | Compiled clean |
| smoke_sanity | UNKNOWN | Smoke deferred (infra bug — see below) |

**Additional violations (framework_corset):**
- `Strategy_OpenPair` calls `QM_BasketOpenPosition` (line 335) — must use `QM_TM_OpenPosition`
- Magic resolution uses `QM_MagicChecked` (line 258) — must use `QM_FrameworkMagic`
- `weights[]` array pattern = forbidden; signals proportional sizing or soft ML-adjacent logic

**Action required:** Codex rework task for QM5_10034. Three mandatory fixes before re-review:
1. Route includes through `QM_Common.mqh`; remove direct `QM_BasketOrder.mqh` include
2. Replace `QM_MagicChecked` → `QM_FrameworkMagic`; `QM_BasketOpenPosition` → `QM_TM_OpenPosition`
3. Eliminate `weights[]` arrays — if the strategy requires pair weighting it violates fixed-lot rules; reassess design

**Note:** No Claude task was assigned for this; flagged for next Codex routing cycle.

---

## FAIL 2: p_pass_stagnation — 0 Q03+ PASS in 12h

Root causes (pre-existing, all tracked):

1. **KillSwitch naming defect** (memory: `project_qm_killswitch_naming_defect_2026-05-23.md`)  
   QM5_10000 and QM5_10005 remain `build_blocked`. `g_qm_ks_initialized` double-defined in  
   `QM_KillSwitch.mqh` + `QM_KillSwitchKS.mqh`. Codex rename task unmerged.

2. **Edge Lab INFRA_FAIL** (memory: `project_qm_edgelab_infra_fail_2026-05-23.md`)  
   QM5_10717 + QM5_10718 stalled at Q02 on EURUSD.DWX. Cause undiagnosed. No Codex task assigned.

3. **Schema blocker** (memory: `project_qm_schema_blocker_2026-05-23.md`)  
   2161 approved cards blocked (ready_approved_cards=0). `board-advisor` merge pending OWNER action.  
   Replenishment frozen: `generic_research_replenishment_frozen_edge_lab_primary_2026-05-22`.

4. **Active backtest queue thin** — only 2 terminals active (smoke runs), no Q02+ work in queue for  
   pipeline-phase EAs. QM5_10023/26/27 approved but not yet enqueued (pump will handle).

---

## WARN: Unenqueued EAs — Self-Correcting

| EA | ea_review verdict | Status |
|---|---|---|
| QM5_10019 | REJECT_REWORK | Correct — time-filter + RISK_PERCENT fix needed; not a P2 candidate |
| QM5_10021 | REJECT_REWORK | Correct — broker-close stabilization gate + RISK_PERCENT + smoke fix needed |
| QM5_10023 | APPROVE_FOR_BACKTEST | Waiting for pump to create P2 work_items (`needs_p2_smoke_via_pump: true`) |
| QM5_10026 | APPROVE_FOR_BACKTEST | Same — approved 16:13Z, pump next cycle |
| QM5_10027 | APPROVE_FOR_BACKTEST | Same |

WARN is benign for QM5_10023/26/27. The two REJECT_REWORK EAs correctly have no work_items.

---

## Systemic Infrastructure Bug: Smoke Dispatch Failing at Build Stage

**Pattern:** Every recent build produces `build_smoke_framework_error`:  
> `Resolve-DispatchTerminal requires -SetFilePath when -TargetTerminal='any'`

**Affected EAs this cycle:** QM5_10034, QM5_10038, QM5_10039, QM5_10041, QM5_10042  
**Mitigation:** `smoke_result: deferred_p2_smoke` + `needs_p2_smoke_via_pump: true` — smoke runs at P2 instead  
**Impact:** Build-stage smoke validation is effectively disabled. Q01 smoke gate bypassed for all new EAs.  
**Action required:** Codex fix to `Resolve-DispatchTerminal` / build dispatch script to pass `-SetFilePath` correctly when `-TargetTerminal='any'`. This is blocking the Q01 gate.

---

## QM5_10260 Queue State

**work_items count:** 0 (confirmed)  
**Context:** cieslak-fomc-cycle-idx hangs on all 37 symbols at ~1800s (memory: `project_qm5_10260_q02_timeout_2026-05-22.md`). Per-tick full-EMA recompute too slow. No Codex task assigned for perf rework. EA remains stalled. No action this cycle — requires OWNER decision to assign rework or wash.

---

## Gemini Video Extraction Pipeline

**IN_PROGRESS (2/2):**
- Task 47059b7b: "Set Up 1 – Catch A Quick Move.mp4"
- Task 84931317: "Set Up 2 – Fibs Retracements.mp4"

**TODO (3, blocked: Gemini at capacity):**
- Task 6672fa16: "Set Up 3 – 20 MA.mp4" (was mis-routed to Codex, released back)
- Task 9abf0338: "Set Up 4 – Fibs Break Out.mp4"
- Task aac25e1f: "When Do I Trade / How Much I Risk.mp4"

All from `EA - FTMO - Trading Course`. Dropbox extraction continuing normally.  
**Schema blocker remains** — Gemini-produced Strategy Cards will stay blocked at approved (not ready) until board-advisor merges.

---

## Recommended Next Steps (Priority Order)

1. **OWNER: Merge board-advisor branch** — unblocks all 2161 cards; single highest-leverage action
2. **Codex: Fix `Resolve-DispatchTerminal` smoke dispatch bug** — Q01 gate currently bypassed for all new builds
3. **Codex: Rework QM5_10034 (rw-pairs-z)** — three framework_corset fixes required before re-review
4. **Codex: Assign KillSwitch rename task** — unblocks QM5_10000/10005 build chain
5. **OWNER/Codex: Diagnose QM5_10717/10718 INFRA_FAIL** — Edge Lab EAs stalled since initial failure
6. **Codex/OWNER: Decide QM5_10260 fate** — rework or wash; currently holding dead slot

---

*Report generated by claude orchestration cycle. No Claude tasks completed; no T_Live actions taken.*
