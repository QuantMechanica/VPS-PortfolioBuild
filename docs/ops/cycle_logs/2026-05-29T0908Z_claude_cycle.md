# Claude Orchestration Cycle — 2026-05-29T0908Z

## Status: IDLE — no IN_PROGRESS tasks

## Router

```
run --min-ready-strategy-cards 5 --max-routes 5 → no_routable_task
route-many --max-routes 5                       → no_routable_task
list-tasks --agent claude                        → []
```

All agents at running=0. No new routes created.

**Blocked reservoir:** 2674 approved cards, all blocked (ready_approved_cards=0). Research
replenishment frozen (`generic_research_replenishment_frozen_edge_lab_primary_2026-05-22`).
4 gemini tasks in APPROVED, 2 in REVIEW (not claude's; left untouched per protocol).

---

## farmctl health

| Check | Status | Value |
|---|---|---|
| codex_review_fail_rate_1h | OK | 0/0 |
| pump_task_lastresult | OK | 0 |
| mt5_dispatch_idle | OK | 325 pending, 5 active |
| active_row_age | OK | 0 rows beyond timeout |
| codex_zero_activity | OK | 1 codex active |
| quota_snapshot_fresh | OK | claude=36s, codex=35s |
| codex_auth_broken | OK | 0 errors |
| disk_free_gb | OK | D: 50.5 GB |
| cards_ready_stagnation | OK | 0 |
| ablation_grandchildren | OK | 0 |
| zerotrade_rework_backlog | OK | 0 |
| mt5_worker_saturation | **WARN** | 9/10 (T1 missing) |
| source_pool_drained | **WARN** | 9 pending sources |
| p2_pass_no_p3 | **FAIL** | 127 items (pump §10c backlog) |
| unbuilt_cards_count | **FAIL** | 786 cards awaiting build |
| unenqueued_eas_count | **FAIL** | 17 reviewed EAs with no Q02 work_items |
| p_pass_stagnation | **FAIL** | 0 P3+ PASS — **FALSE POSITIVE** (see below) |

**p_pass_stagnation false positive:** farmctl health checks for legacy `P3`/`P4` phase keys
but the DB now stores `Q03`/`Q04`. Direct DB query confirms **700 Q03 PASS in last 12h**
(latest 2026-05-29T08:59:43). This check will always report FAIL until health.py is updated
to use Q-keys.

---

## QM5_10260 Queue State

| Phase | Status | Verdict | Count |
|---|---|---|---|
| Q02 | done | FAIL | 7 |
| Q02 | done | INFRA_FAIL | 15 |
| Q02 | done | PASS | 3 |
| Q02 | failed | INFRA_FAIL | 1 |
| Q03 | done | PASS | 102 |
| Q04 | failed | INFRA_FAIL | 102 |

Note: 102 Q04 INFRA_FAIL for QM5_10260 are from the pre-fix dispatcher (used `--out-prefix`
→ argparse error → exit 2 → INFRA_FAIL). These were dispatched before the dispatcher-args
fix (a8c1da38). Current dispatcher uses `--report-root` (correct).

---

## Q04 Gate — Root Cause Confirmed

**Active Q04 runs** (5 items dispatched 08:51–09:04 UTC) complete as FAIL:
- `exit_code=0` (run_smoke succeeds, MT5 terminal runs OK)
- `pf_net=null, trades=0` (EA does NOT write `Common\Files\QM\q04_sim\<ea_id>_<symbol>.json`)
- Each fold: ~3.5 min elapsed, 1 OOS year backtest, EA ignores `InpQMSimCommissionPerLot`

**Evidence:** `D:\QM\reports\work_items\a72cd7c3-...\QM5_10559\Q04\EURUSD.DWX\aggregate.json`
```json
{"verdict": "FAIL", "reason": "F1:pf_net=None;F2:pf_net=None;F3:pf_net=None",
 "folds": [{"id":"F1","exit_code":0,"pf_net":null,"trades":0,"status":"FAIL"},
           {"id":"F2","exit_code":0,"pf_net":null,"trades":0,"status":"FAIL"},
           {"id":"F3","exit_code":0,"pf_net":null,"trades":0,"status":"FAIL"}]}
```

**Overall Q04 tally (all-time):**
- PASS: 0
- FAIL (strategy/infra gap): 43 (new dispatcher, EA doesn't write result)
- INFRA_FAIL: 3864 (old dispatcher `--out-prefix` argparse error)
- Active now: 5 items

**Fix:** Codex task f308fe3f — add `InpQMSimCommissionPerLot` input + `Common\Files` write
to EA framework template, recompile all EAs, run 1 MT5 calibration. Until deployed, all
Q04 items will FAIL and consume ~10-11 min of MT5 slot time per item (3 folds × ~3.5 min each).

**OWNER note:** Q04 is consuming MT5 capacity without producing results. Recommend:
1. Expedite Codex task f308fe3f (EA commission mechanism)
2. Consider whether Q04 items should be paused until fix is deployed (requires OWNER decision)

---

## Pipeline Throughput

| Phase | Pending | Active | Notes |
|---|---|---|---|
| Q02 | 249 | — | Healthy backlog |
| Q03 | 73 | — | 700 PASS in last 12h |
| Q04 | 3 | 5 | All active → FAIL (commission gap) |

Q02 → Q03 pump backlog: 24 EAs with Q02 PASS awaiting Q03 enqueue.

---

## Blockers Summary (no change from prior cycle)

| Blocker | Owner | Status |
|---|---|---|
| Q04 commission mechanism | Codex (f308fe3f) | Needs EA framework patch + recompile |
| p_pass_stagnation health check | Codex | false positive — update P3/P4 → Q03/Q04 keys |
| T1 worker missing | OWNER | WARN only; 9/10 workers active |
| Headless git push (PAT) | OWNER | PAT refresh needed for push |

---

## Next recommended action

Nothing actionable for Claude this cycle. Primary bottleneck is Codex task f308fe3f (Q04
commission mechanism). Once deployed and validated, the Q04 gate will produce real PF-net
verdicts and the pipeline can advance past Q04 for the first time.
