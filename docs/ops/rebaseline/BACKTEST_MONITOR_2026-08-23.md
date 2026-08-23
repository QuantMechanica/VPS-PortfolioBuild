# Backtest Factory Monitor — 2026-08-23

**Author:** Claude (Orchestrator, board-advisor worktree) · **Scope:** read-only monitoring.
**Window:** last 24h (cutoff 2026-08-22T10:03Z → now 2026-08-23T10:08Z).
**Constraint:** no requeue, no verdict mutation, no factory toggle, no T_Live.
State DB: `D:/QM/strategy_farm/state/farm_state.sqlite`.

---

## 1 · Factory health snapshot

- **Live terminals:** 9/10 running `terminal64.exe` (T1–T6, T8, T9, T10). Path-anchored via
  `farmctl mt5-slots`; `C:/QM/mt5/T_Live` and FTMO Global Markets excluded (both present,
  not counted). `duplicate_terminal_workers={}`, `orphaned_terminal_processes=[]`.
- **No stale claims.** In the first snapshot T6/T9 showed `active` in DB with no process for a
  few seconds; a re-check showed both with live `terminal64.exe` — they were mid-cell
  (terminal64 is transient per cell), not wedged.
- **No FACTORY_OFF flag**, `disabled_terminals.txt` empty. Factory is saturating.
- **Disk D:** 134.7 GB free of 1024 GB. Below the 150 GB purge no-op line (so
  `tester_cache_purge` is active) and well above the 80 GB LowWater — healthy.
- **No stale pump lock.** No `pump_task.lock` present; the `last_manual_pump_*.json` files are
  May artifacts, not a live lock.
- **Heartbeats fresh** (all < 13 min at 10:08Z): `lane_claude` 10:00:12, `lane_codex`
  10:00:03, `lane_gemini` 09:55:10, `health.json` checked 10:06:54Z (farm_health OK).

### Active work_items (status=active), 2026-08-23

| Phase | ea_id | symbol | terminal | claimed (updated_at) | proc |
|---|---|---|---|---|---|
| Q09_NEWS | QM5_12855 | XTIUSD.DWX | T5 | 09:07Z | yes |
| Q09_NEWS | QM5_12849 | XTIUSD.DWX | T2 | 09:09Z | yes |
| Q09_NEWS | QM5_1537 | XAGUSD.DWX | T4 | 09:10Z | yes |
| Q09_NEWS | QM5_21505 | XAGUSD.DWX | T9 | 09:15Z | yes |
| Q09_NEWS | QM5_10146 | AUDUSD.DWX | T3 | 09:19Z | yes |
| Q09_NEWS | QM5_12823 | USDJPY.DWX | T8 | 09:24Z | yes |
| Q07 | QM5_11182 | XAUUSD.DWX | T1 | 09:58Z | yes |
| Q04 | QM5_12924 | NDX.DWX | T6 | 10:01Z | yes |

(DB-wide status: done 59602, failed 48739, pending 3268, active 8.)

---

## 2 · Finished last 24h — phase × verdict

| Count | Phase | Verdict | Class |
|---|---|---|---|
| **80** | COMPILE_EA | COMPILE_FAIL | **INFRA / factory bug** |
| 50 | OPT_CENSUS | MEASURED | ok |
| 11 | COMPILE_EA | COMPILE_OK | ok |
| 8 | Q02 | INFRA_FAIL | infra (ONINIT_FAILED/BARS_ZERO) |
| 5 | Q02 | PASS | ok |
| 4 | Q09_NEWS | REVIEW_REQUIRED | manual (expected) |
| 2 | Q04 | FAIL | economic |
| 2 | Q09_NEWS | INFRA_FAIL | infra (transient) |
| 2 | Q07 | INFRA_FAIL | infra (transient/retry) |
| 1 | Q06 | PASS / 1 FAIL | ok / economic |
| 1 | Q05 | PASS | ok |
| 1 | Q09_PORTFOLIO | FAIL_PORTFOLIO | economic |

COMPILE_EA fail rate in the window = **80 / 91 = 87.9%** (worse than the 46.7% baseline in the
brief). This is the dominant and actionable class. Economic FAILs (Q04/Q06/Q09_PORTFOLIO) are
normal and terminal — not defects.

---

## 3 · Triage table (top 3 error classes)

| Class | Count | Root cause | Evidence path | Proposed fix | Who |
|---|---|---|---|---|---|
| **COMPILE_EA → COMPILE_FAIL** | 80 (80 distinct EAs, IDs span QM5_9983…10367) | **FACTORY BUG.** MetaEditor compiles against the *roaming* MetaQuotes profile for the claimed terminal, and the roaming compile profiles for **T6, T7, T9 (and DEV1)** have an **incomplete MT5 standard library**: top-level `Object.mqh` missing on all four; the whole `Trade/` subdir missing on T6/T9/DEV1. Every V5 EA includes `<QM/QM_Common.mqh>` → `<Trade/Trade.mqh>`, so the include chain breaks at the top and cascades (58–78 errors of `declaration without type` / `undeclared identifier QM_FrameworkInit` — all downstream of one missing include). The QM include-mirror (`include_mirror.py`) is purely additive and never restores the standard library. Failures track terminal assignment, not EA source (proof: 80 different EAs across the whole ID range, not one bad template). | `D:\QM\reports\work_items\c74de048-…\QM5_1607\COMPILE_EA\compile_evidence.json` → log `C:\QM\repo\framework\build\compile\20260822_103756\QM5_1607_aa-mom-tol-band.compile.log` (`QM_Common.mqh(4,10): error 106: file 'Include\Trade\Trade.mqh' not found`). T7 case: `…\993c18da-…\QM5_1611\…` → `…20260822_103930\QM5_1611…compile.log` (`Trade.mqh(6,10): error 106: file 'Include\Object.mqh' not found`). Profile scan: E082C3FA(T6) Obj- Trade-, 62611A74(T9) Obj- Trade-, AC9F706B(T7) Obj- Trade+, 28E47E87(DEV1) Obj- Trade-. | (a) Restore the full standard MQL5 `Include` (loose `Object.mqh`, `StdLibErr.mqh`, and `Trade/`, `Arrays/`, `Indicators/`, `Expert/` …) into the 4 broken roaming profiles from a known-good profile (e.g. `AE0A37E2…`=T1, Obj+/Trade+), then re-run one canary compile per terminal via `retry_compile_recheck_canary.py`. (b) Harden: add a pre-compile stdlib presence check (assert `Object.mqh` + `Trade/Trade.mqh` in the compile Include root) that fail-closes with `STDLIB_MISSING` and self-heals, so an incomplete profile never re-emits 80 EA-level COMPILE_FAILs. (c) Interim: exclude T6/T7/T9 from COMPILE_EA dispatch until (a) done. | **codex** |
| **Q02 → INFRA_FAIL** | 8 rows / 2 EAs (QM5_12947, QM5_12948, both EURUSD.DWX) | **EA-defect candidate (not economic).** `reason_classes=["ONINIT_FAILED","INCOMPLETE_RUNS"]`, per-run `failure=ONINIT_FAILED`, `invalid_report_reasons=["BARS_ZERO","ONINIT_FAILED"]`. `.ex5` was pre-dispatch sha-verified and stable, so this is an OnInit *runtime* rejection, not a build/deploy gap. Fits the known INPUTSVALID framework-pin class (EA pins seed/stress/news in OnInit → deterministic INFRA-labelled death) or an EURUSD-specific input/symbol issue. | `D:\QM\reports\work_items\e4352c34-48fe-4d93-b3fa-83fc11be5b55\QM5_12948\20260822_103421\summary.json` (`runs[].failure=ONINIT_FAILED`, `oninit_failure_detected=true`). | Inspect QM5_12947/12948 `OnInit` and input wiring (grep each strategy input against use-sites; check for pinned seed/stress/news). Do **not** blind-requeue (memory: `ONINIT_FAILED nie blind requeuen`). Classify EA-defect vs EURUSD data before any rerun. | **codex** |
| **Q09_NEWS / Q07 → INFRA_FAIL** | 2 + 2 | **Transient infra, re-runnable.** Q09 (QM5_11294 XAUUSD): `run_smoke exited 1 without a fresh run_smoke summary or cell receipt` + `Q09 claimed-terminal exit wait timed out after 180s for D:\QM\mt5\T2; terminal64 pids still active`. Q07 (QM5_11182 XAUUSD): phase runner respawned repeatedly and is **currently re-running active on T1** (self-retry in progress). No economic verdict destroyed. | Q09: `D:\QM\strategy_farm\logs\work_item_b2468d2e-92a5-4fd8-a6ae-29967da0ca08.log`. Q07: `D:\QM\strategy_farm\logs\work_item_362f1793-5f71-48ec-9c34-680484edac1b.log`. | Let self-retry clear (Q07 already active). If it does not, append-only re-enqueue (`enqueue-backtest --append-only-rerun-of`) — GRÜN. Consider raising the 180 s claimed-terminal-exit-wait when the host is saturated (9 terminals) — the wait timed out while pids were still alive, i.e. a slow-exit under load, not a wedge. | claude (monitor) / codex (timeout tune) |

---

## 4 · Concrete bugs to fix

1. **BUG-1 (P0, factory):** Roaming MetaEditor compile profiles for **T6, T7, T9, DEV1** have
   an incomplete MT5 standard library (`Object.mqh` missing on all; `Trade/` missing on
   T6/T9/DEV1). Cause of all 80 COMPILE_FAIL in 24h. This is the single actionable factory
   defect. → **codex**: restore stdlib into the 4 profiles + add a fail-closed stdlib-presence
   preflight in the compile path so it can never re-emit EA-level COMPILE_FAIL again.
   *(Repair itself is GRÜN infra — but per this task's read-only mandate it is only proposed
   here, not executed.)*
2. **BUG-2 (P1, EA/data):** QM5_12947 & QM5_12948 EURUSD Q02 `ONINIT_FAILED` / `BARS_ZERO`.
   → **codex**: OnInit + input-wiring inspection; do not blind-requeue.
3. **BUG-3 (P2, infra tuning):** Q09 selection 180 s claimed-terminal-exit-wait times out
   under 9-terminal load while pids are still alive (slow exit, not a wedge). → **codex**:
   evaluate raising the exit-wait budget under saturation. Q07 11182 already self-retrying —
   monitor only.

## 5 · Not defects (for the record)

- Economic FAILs: Q04 (2), Q06 (1), Q09_PORTFOLIO (1) — terminal by contract, expected.
- Q09_NEWS REVIEW_REQUIRED (4) — manual gate output, expected.
- OPT_CENSUS MEASURED (50), COMPILE_OK (11), Q02/Q05/Q06 PASS — healthy throughput.
- T6/T9 momentarily processless in first snapshot — transient per-cell, confirmed running.

## 6 · Actions taken

None — read-only monitoring per task. Nothing requeued, no verdict rows touched, no factory
toggle. Fixes above are proposals for the Codex lane; BUG-1 should be commissioned first.
