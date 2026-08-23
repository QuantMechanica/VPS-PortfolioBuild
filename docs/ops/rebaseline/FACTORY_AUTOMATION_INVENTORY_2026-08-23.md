# Factory Automation Inventory — Pipeline Rebaseline (2026-08-23)

**Author:** Claude (Orchestrator) · **Branch:** `agents/board-advisor` · **Read-only inventory** (no commits, no verdict/queue/factory/T_Live mutation).
**Directive:** vault `03 Pipeline/Pipeline Rebaseline Directive 2026-08-23.md`.
**Active contract:** `tools/strategy_farm/config/gate_manifest.v3.json` (ACTIVE since 2026-08-23; gates Q00..Q16). Thresholds/criteria are **ROT** — not changed here.

This document inventories the automation that must change for the linear three-phase contract. For each component: **path · what it does · gate/phase order it assumes · manifest-loader use · concrete change** for (a) linear renumbering, (b) frontier-first / earliest-gap-first backfill planner, (c) fail-closed book trigger (>=25 + OWNER order artifact), (d) removal of the Q16→Q11 back-edge.

---

## 0 · Executive finding — where the gate order actually lives

The manifest loader (`gate_manifest.py` → `phase_ids.py`) is the *contract of record*, but **the runtime gate-advancement maps are hardcoded and do NOT read it.** Every place that decides "PASS at gate N enqueues gate N+1" carries its own literal table, several still containing legacy `P*` keys. This is the central structural risk of the rebaseline: renumbering the manifest alone changes nothing at runtime.

Authoritative-but-unused contract:
- `tools/strategy_farm/gate_manifest.py:120` `next_by_phase` property (built from each gate's `next` field).
- `tools/strategy_farm/phase_ids.py:64` `PHASE_NEXT = _GATE_MANIFEST.next_by_phase`; `PHASE_ORDER`, `ORDINARY_PHASE_ORDER`, `OPTIMIZATION_PHASE_ORDER`.

Hardcoded runtime advancement tables that shadow it (all in `farmctl.py` unless noted):
| Location | Table | Keys |
|---|---|---|
| `farmctl.py:10034` `PARENT_PROGRESSION_MAP` | Q02→Q03→Q04 (+ legacy P2→P3→P3.5→P4) | mixed Q/P |
| `farmctl.py:280` `SUPPORTED_BACKTEST_PHASES` | `("Q02","Q03","Q04")` | Q |
| `farmctl.py:281` `CASCADE_BACKTEST_PHASES` | `Q04,Q05,Q06,Q07,Q08,Q09_NEWS,Q09_PORTFOLIO,Q10` + P5..P8 | mixed |
| `farmctl.py:21701` `prev_phase_map` (inside `enqueue_cascade_backtest_for_ea`) | reverse cascade Q04←Q02, Q05←Q04 … Q10←Q09_NEWS | mixed |
| `farmctl.py:21717` `phase_prev_verdicts` | which predecessor verdicts license each gate | Q + P |
| `farmctl.py:22622` inline `next_phase_map` in `dispatch_tick` | `{"P2":"P3","P3":"P3.5","P3.5":"P4"}` | **legacy P only** |
| `evidence_cascade_driver.py:44` `PHASES` | `Q02,Q03,Q04,Q05,Q06,Q07,Q08,Q10` (**Q09 omitted**) | Q |
| `invalidate_unprofitable_cascade.py:22` `CASCADE_PHASES` | all legacy `P3..P8` | legacy P only |
| `farmctl.py:4643` `_phase_rank` map incl. `"Q11":"P8"` | ranking, not advancement | mixed |

**Consequence for the rebaseline:** the single highest-leverage change is to **make all of these derive from `phase_ids.PHASE_NEXT` / `ORDINARY_PHASE_ORDER`** (one source), then renumber once in the manifest. Until then, (a) linear renumbering is not a manifest-only edit.

Also note the runtime uses **split Q09** storage phases (`Q09_NEWS`, `Q09_PORTFOLIO`) that do not exist as top-level gate IDs in the manifest (`Q09`). Any linear renumber must preserve this storage/display split (`legacy_policy: READ_AND_MIGRATION_ONLY`).

---

## 1 · Component inventory

### 1.1 `tools/strategy_farm/Factory_ON.ps1`
- **What:** Admin, visible-session factory release. MNT-052 interlock: requires a verified OFF record, drains/validates while interlocked, then one guarded start window. Sources `factory_process_scope.ps1` (v2 guard), self-heals `PSModulePath`. Fail-closed behind the runtime-activation decision (`build_runtime_activation_decision.py`). Never touches T_Live/AutoTrading. Scheduled: `QM_StrategyFarm_FactoryON_AtLogon`.
- **Gate/phase assumptions:** none of the Q-gate numbering; operates at process/flag layer only.
- **Manifest loader:** no.
- **Change needed:** (a) none — gate-agnostic. (b)(c)(d) none. Only indirect: it gates the *activation decision*, which is where a rebaseline "contract version" preflight could be asserted (see 1.3). Leave logic; optionally add a contract-version echo to its start log.

### 1.2 `tools/strategy_farm/Factory_OFF.ps1`
- **What:** Asserts software interlock, drains every autonomous factory/repo/DB mutator; dashboards/health/live telemetry stay up. `-RestoreIntentManifest` param feeds the restore-intent chain. Gate-agnostic.
- **Gate/phase assumptions:** none.
- **Manifest loader:** no.
- **Change needed:** none for (a)-(d). Gate-agnostic.

### 1.3 `tools/strategy_farm/build_runtime_activation_decision.py`
- **What:** Mints the runtime-activation decision consumed by `Factory_ON`. Requires a clean tree (incl. untracked) and a live preparation/restore-intent window (`restore_intent.get("manifest_creation_authorized_after_prerequisites")`, line 160). Companion: `factory_runtime_activation.py`, `factory_restore_intent.py`.
- **Gate/phase assumptions:** none of the Q-numbering; it authorizes *runtime manifest* creation, not gate topology.
- **Manifest loader:** no (does not import `gate_manifest`).
- **Change needed:** (a)-(d) none structurally. Recommended: bind the active `gate_contract_version` (v3 sha256 from `gate_manifest.py` `GateManifest.sha256`) into the decision payload so a factory start records which gate contract it ran under — supports the directive's "jeder Enqueue bindet den neuen Gate-Vertrag" audit requirement.

### 1.4 Pump — `tools/strategy_farm/run_pump_task.py` + `farmctl.py pump`
- **What:** `run_pump_task.py` is the scheduled wrapper (`QM_StrategyFarm_Pump_5min`, every 5 min, `pythonw`); honors `FACTORY_OFF.flag` (line 57), holds `pump_task.lock`, shells `farmctl.py pump`. The pump (`farmctl.py`, entry ~16428/16568) runs `dispatch_tick`, artifact auto-commit, and the promotion cascade drivers:
  - `_promote_q08_soft_fails_to_q09_portfolio` (`farmctl.py:15705`) — Q08 FAIL_SOFT/PASS → Q09_PORTFOLIO (batch ≤10).
  - `_promote_paired_q09_portfolio_passes_to_news` (`farmctl.py:15892`).
  - `_admit_q09_portfolio_passes` (`farmctl.py:15999`) — **already a no-op** ("direct portfolio admission is forbidden"; returns 0).
  - `auto_seal_pending_q09_news` (Q09 autoseal, called at end of the cascade block ~18110).
- **Gate/phase assumptions:** hardcoded Q08→Q09_PORTFOLIO/Q09_NEWS→Q10 promotion logic; the `_admit_q09_portfolio_passes` docstring encodes the OLD portfolio semantics ("Q12 qualification authority").
- **Manifest loader:** no.
- **Change needed:** (a) route promotion targets through `PHASE_NEXT` once the split-Q09 mapping is expressed there. (c) the book/portfolio admission side is already fail-closed at the pump (`_admit_q09_portfolio_passes` returns 0), so no auto-book is emitted here — good; keep it and make the >=25 gate live in the analytic surface (1.9). (d) pump does not itself walk Q16→Q11; nothing to remove here.

### 1.5 `dispatch_tick` — `farmctl.py:22503`
- **What:** Core auto-advance. On a work-item PASS, enqueues the next phase as a NEW pending row if none exists; retries INFRA_FAIL up to a cap; times out stale actives; respects the defect-block-taint guard (`allow_defect_blocked_auto_cascade`).
- **Gate/phase assumptions:** **two** advancement paths: (1) `tasks`-table inline `next_phase_map = {"P2":"P3","P3":"P3.5","P3.5":"P4"}` (`farmctl.py:22622`) — **legacy P-keys only**; (2) work-item path via `PARENT_PROGRESSION_MAP` (Q02→Q03→Q04) and, for Q04+, `enqueue_cascade_backtest_for_ea`.
- **Manifest loader:** no.
- **Change needed:** (a) replace both literal maps with `PHASE_NEXT`-derived lookups; retire the legacy-P inline map (it can only fire for pre-rewrite fixtures). (b) `dispatch_tick` is push-on-PASS, not gap-first — the backfill planner (1.7) is the gap-first surface; keep dispatch_tick as the forward engine but ensure it cannot skip a hole (it already only enqueues the single successor, so it is safe once the map is linear). (d) once Q16 successor is `null` in the manifest, the cascade must not auto-enqueue Q11 from Q16 (see 1.6).

### 1.6 Cascade enqueue — `enqueue_cascade_backtest_for_ea` (`farmctl.py:21621`) and the Q09/Q10 hooks
- **What:** The real Q04→Q10 advancement engine. `prev_phase_map` (`:21701`) and `phase_prev_verdicts` (`:21717`) define, per target gate, the predecessor phase and the predecessor verdicts that license creation. `auto_enqueue_q10_after_q09_result` (`farmctl.py:15587`, called from `terminal_worker.py:3646`) cascades a CONFIG_LOCKED Q09_NEWS to Q10. Q09 aliases are read-only (`Q09` rejected; use `Q09_NEWS`).
- **Gate/phase assumptions:** hardcoded linear-ish chain Q02→Q04→Q05→Q06→Q07→Q08→Q09_NEWS→Q10 (Q03 handled via predecessor-narrowed Q04 path). **No Q10A, no Q14/Q15/Q16, no Q11** in this engine — the optimization fork and portfolio are NOT driven by this cascade.
- **Manifest loader:** no.
- **Change needed:** (a) derive `prev_phase_map` from `PHASE_NEXT` inverse over `ORDINARY_PHASE_ORDER`, keeping the Q09 split as an explicit storage-lane override; keep `phase_prev_verdicts` (verdict policy is ROT criteria, not numbering). (b) this is where "earliest missing prerequisite first" is partially enforced (it only creates gate N from a done+PASS gate N-1), but it does not scan for the *shallowest* hole — that is `evidence_cascade_driver.py` (1.7). (d) confirm nothing here maps a terminal gate to Q11.

### 1.7 `tools/strategy_farm/evidence_cascade_driver.py`
- **What:** The closest existing thing to the directive's **earliest-gap-first per-pair** planner. For each (EA, symbol) it finds the SHALLOWEST phase whose evidence is missing/stale vs the `.ex5` mtime, verifies earlier phases are fresh, and requeues exactly that one gate. Idempotent; snapshot+revert.
- **Gate/phase assumptions:** hardcoded `PHASES = ("Q02","Q03","Q04","Q05","Q06","Q07","Q08","Q10")` (`:44`) — **Q09 is omitted** (a real gap: a pair missing only Q09 will be walked straight past it), and no Q10A, Q14-Q16, Q11.
- **Manifest loader:** no.
- **Change needed:** This is the natural home for the backfill planner. (a) source its `PHASES` from `ORDINARY_PHASE_ORDER` (add Q09_NEWS). (b) extend to emit the directive's dry-run plan artifact: per (EA, Symbol, build-hash, setfile-hash) — highest gate ever, `highest_contiguous_valid_gate`, earliest missing prerequisite, and disposition. Add **frontier-first global ordering** (rank pairs by highest credible frontier, then within a pair walk the earliest hole). It already computes `highest_contiguous_valid_gate` implicitly ("verify every earlier phase is fresh"); expose it. Add append-only + exact-hash-reuse skip (do not requeue evidence whose build/setfile/contract hash is unchanged and contract-equal).

### 1.8 Optimization fork — `bind_q09_run_plan`, `enqueue_head_to_head` (Q14/Q15/Q16)
- **What:**
  - `bind_q09_run_plan` (`farmctl.py:22176`) — writes the sealed Q09 run plan; a Q09_NEWS row is executable only after this binds (`farmctl.py:1359`). This is the CLI `bind-q09-plan`. **Currently a dispatch bottleneck** (see 2, `q09_autoseal_hold_census`: 8× `Q09_AUTOSEAL_BIND_PLAN_FAILED`).
  - `enqueue_head_to_head` (`farmctl.py:24899`) — CLI `enqueue-head-to-head`; builds a Q16 sealed best-settings-vs-baseline+incumbent work item via `framework/scripts/q16_head_to_head.py`; `_q16_dependency_spec`/`_ensure_q16_dependency` (`:24835`/`:24861`) bind the Q10A baseline-full-run + incumbent-Q10 dependencies.
  - Admission (`admit-optimization` / Q14) enters the fork; DL-089 pattern-filter selection cap 3/direction.
- **Gate/phase assumptions:** the fork **`Q14→Q15→Q16→Q11`** — the back-edge. `q16_head_to_head` and the manifest `portfolio_routes` route `Q16 (OPTIMIZED)→Q11` and `Q10 (NOT_OPTIMIZED)→Q11`.
- **Manifest loader:** partial — `gate_manifest.py` exposes `q16_dependencies`, `portfolio_routes`, `portfolio_route(optimized=)`; `enqueue_head_to_head` consumes the q16 dependency spec. This is the **only** advancement code that reads the manifest topology.
- **Change needed:** (d) **removal of Q16→Q11 back-edge under linear numbering:** in the linear three-phase target, Phase 2 (optimization/requalification) is a strictly monotone segment that *terminates* in a requalification verdict; Phase 3 (book) is entered by the fail-closed book trigger, not by a per-EA `next` edge. Concretely: set the terminal optimization gate's `next` to `null` (like Q13 today), drop `portfolio_routes`' `to:Q11` edges as *automatic* routing, and have `enqueue_head_to_head`/admission stop implying a Q11 successor. Q11 becomes reachable ONLY via the book trigger (1.9). (a) renumber the fork into the linear Phase-2 band. Keep DL-089 selection contract (ROT).

### 1.9 Book / portfolio trigger — where >=25 + OWNER order must live
- **What today:** There is **no automatic book build in the pump/cascade.** `_admit_q09_portfolio_passes` is a hard no-op (`farmctl.py:15999`). Eligible candidates are surfaced read-only by the SQL view `portfolio_candidates_eligible` (`q09_news_schema.py:733`), which JOINs a QUALIFIED `candidate_qualifications` row to a Q10 PASS + CONFIG_LOCKED Q09_NEWS. Reporting: `QM_StrategyFarm_PortfolioReport` (`portfolio/portfolio_periodic_report.py`, 6h), `QM_StrategyFarm_PipelineState`, cockpit renderers. Deploy path is manual: `deploy_tlive_book.py` behind OWNER authority.
- **Gate/phase assumptions:** the eligible view counts `(EA, Symbol)` pairs at QUALIFIED (Q10 PASS + Q09_NEWS CONFIG_LOCKED). The **old Q11 auto-trigger at 5 Q10 pairs** referenced in the directive is **not present in current code** — no `>=5` book trigger exists in `farmctl.py`/pump; the directive's "aufgehoben" is already effectively true, but there is also no explicit **>=25 fail-closed guard**.
- **Manifest loader:** the eligible view is schema-level; not manifest-driven.
- **Change needed:** (c) add an explicit **fail-closed book-build guard** that refuses any DXZ/FTMO book construction unless BOTH: (1) `COUNT(portfolio_candidates_eligible) >= 25` under the *final* requalification gate (canonical unit = `(EA, Symbol)`, plus report distinct EAs and strategy families per directive §6), AND (2) a present, signed **OWNER book-build order artifact** (e.g. `decisions/YYYY-MM-DD_book_build_order_{dxz,ftmo}.md`) is verified. Gate `deploy_tlive_book.py` and any Q11 analytic entry behind this predicate; refuse (not skip) below threshold. Add a machine test that book construction under 25 or without the order artifact raises.

### 1.10 Terminal workers — `terminal_worker.py`, `start_terminal_workers.py`
- **What:** Claim work_items, privatize Custom history, run the real tester, self-report, classify. `REAL_PHASE_RUNNER_PHASES` (`farmctl.py:286`) = Q04..Q10 + legacy P. Worker special-cases: `Q02/Q03` single `run_smoke.ps1` child (`:2887`), Q09_NEWS sealed-sidecar requirement (`:2735`), Q09 cell-sharding (`:79`, up to 4 helper terminals), Q02 RAM ceiling (`:167`), and calls `auto_enqueue_q10_after_q09_result` on Q09 completion (`:3646`). Scheduled `QM_StrategyFarm_TerminalWorkers_AT_STARTUP` (+ 5-min re-spawn).
- **Gate/phase assumptions:** hardcoded phase sets Q02..Q10 (+P aliases); Q09_NEWS-specific handling; no Q10A/Q14-16/Q11 (fork phases are enqueued by the CLI, then run through the same runner via `REAL_PHASE_RUNNER_PHASES`? — note Q14/Q15/Q16 are NOT in `REAL_PHASE_RUNNER_PHASES`, so head-to-head runs via `framework/scripts/q16_head_to_head.py`, not the standard tester loop).
- **Manifest loader:** no.
- **Change needed:** (a) source phase sets from `phase_ids` (`REAL_PHASE_RUNNER_PHASES`, the Q02/Q03 smoke set, Q09 set) so a renumber propagates. No (b)/(c)/(d) logic lives here beyond the Q09→Q10 cascade call, which follows the cascade map fix (1.6).

### 1.11 Supporting enqueue/sweep automation (assume phase order)
- `sweep_enqueue_built_eas.py` (`QM_StrategyFarm_SweepEnqueue_Hourly`, `--queue-ceiling 7000`): enqueues Q02 for built EAs with zero work_items; `STRANDED_INFRA_PHASES = ("Q02","Q03","Q04","Q07","Q08")` (`:114`); docstring hardcodes Q02/Q03/Q04/Q07/Q08 (`:7`). No manifest. **Change:** source phase sets from `phase_ids`; ensure it respects the frontier/gap plan (do not blindly re-flood Q02).
- `r_eval_drain.py` (`QM_StrategyFarm_REvalDrain_15min`), `farmctl.py repair` (`QM_StrategyFarm_Repair_Hourly` → `repair.py`), `requeue_stranded_infra.py`, `blocked_backlog_retest.py`, `drain_backlog.py`, `unbuilt_cards_disposition.py`: all carry local phase literals. **Change:** audit for legacy-P/hardcoded-Q lists; centralize on `phase_ids`.
- `invalidate_unprofitable_cascade.py:22` `CASCADE_PHASES` = all legacy `P3..P8`. **Change:** migrate to Q-native ordinary chain or confirm it is dead (legacy-only).
- `build_pipeline_state.py` (`QM_StrategyFarm_PipelineState`), cockpit/dashboard renderers, `heartbeat_snapshot.py`, `mission_control_v2_data.py`: read gate order for display; several already import `phase_ids`. **Change:** must show `highest_contiguous_valid_gate` (directive §4/§5), not just max Qxx string; reflect three-phase grouping.

---

## 2 · Concrete change map (by directive requirement)

**(a) Linear renumbering.** Single root cause: gate advancement is hardcoded in ≥8 tables, not read from the manifest. Step 1 = make `PARENT_PROGRESSION_MAP`, `SUPPORTED_/CASCADE_BACKTEST_PHASES`, `prev_phase_map`, `dispatch_tick.next_phase_map`, `evidence_cascade_driver.PHASES`, `terminal_worker`/`sweep` phase sets all derive from `phase_ids.ORDINARY_PHASE_ORDER`/`PHASE_NEXT`. Step 2 = renumber once in `gate_manifest.v*.json`. Preserve the Q09_NEWS/Q09_PORTFOLIO storage split and `legacy_aliases` for historical reads (`gate_contract_version` on each row).

**(b) Backfill planner (frontier-first / earliest-gap-first).** Build on `evidence_cascade_driver.py`: add Q09 to its phase list, emit the per-(EA,Symbol,build-hash,setfile-hash) census + gap matrix (highest ever gate, `highest_contiguous_valid_gate`, earliest missing prerequisite, disposition REUSABLE/RENUMBER_ONLY/MISSING/STALE/INVALID/ECONOMIC_FAIL/NOT_APPLICABLE), global frontier-first ordering with per-pair earliest-hole enforcement, append-only, exact-hash+contract-equal reuse skip, no backfill behind a terminal economic FAIL. Deliver as a governed dry-run plan before any apply.

**(c) Fail-closed book trigger.** Add the >=25-eligible AND OWNER-order-artifact predicate (§1.9). Current state is *permissive-by-absence* (no auto-book, but no hard guard either). `_admit_q09_portfolio_passes` already returns 0; keep it and add the explicit guard in front of `deploy_tlive_book.py` and any Q11 analytic entry, with a machine test that under-25/no-order raises.

**(d) Remove Q16→Q11 back-edge.** Only two places encode it: the manifest (`gates[Q16].next="Q11"` + `extension_topology.portfolio_routes` + `target_sequence` ending `…Q16,Q11`, and `baseline_stage` Q10A→Q09 which is the "Q10A before Q09" ordering the directive rejects), and `enqueue_head_to_head`/`portfolio_route()`. Under linear numbering: terminal optimization gate `next=null`; Q11 (book) reachable only via the fail-closed trigger, not a per-EA edge; drop the `portfolio_routes` auto-`to:Q11` and the Q10A-before-Q09 placement. This is a ROT topology change → OWNER template (directive §7.6), not applied here.

---

## 3 · `farmctl.py health` FAIL items affecting dispatch (run 2026-08-23T10:06Z)

Overall FAIL (13 fail / 13 warn / 42 ok). Dispatch-relevant items:

| Check | Status | Classification | Note |
|---|---|---|---|
| `pump_task_lastresult` | FAIL | **Transient / self-healing bug** | Orphan `pump_task.lock` held by dead PID 21724, age 1399s. Clears itself at the 1200s stale threshold on next cycle; if it persists, delete `D:\QM\strategy_farm\logs\pump_task.lock` after confirming no live pump. Pump no-ops until then → blocks ALL forward dispatch while held. |
| `codex_zero_activity` | FAIL | **Config/backlog (expected here)** | 0 codex build activity in 3h vs 38 pending `build_ea`. Root cause is the dirty tree (below), not a router defect. |
| `codex_auth_broken` / `codex_bridge_heartbeat` | WARN | **Expected artifact of this worktree** | Both report `repo_dirty_build_guard blocked by 15 uncommitted file(s)`. The `agents/board-advisor` working tree has 15 M/?? files → the dirty-guard fail-closes ALL builds. On the canonical checkout this is a real build-lane blocker; here it is expected (do not "fix" by committing on this branch). |
| `unbuilt_cards_count` | WARN | **Backlog** | 269 approved cards await build (238 READY, 24 NEEDS_SOURCE, 7 DATA_BLOCKED); queue saturated behind the dirty-guard. |
| `unenqueued_eas_count` | WARN | **Backlog / dispatch gap** | 6 reviewed-built EAs have no Q02 work_items (QM5_11561, 11731, 12512, 11570, 10050, 12507). `sweep_enqueue_built_eas.py` should pick these up next hourly run unless retry-capped. |
| `q02_stranded_exhausted_pairs` | FAIL | **Backlog (known)** | 270 Q02 pairs with ≥12 INFRA_FAIL, no non-infra terminal disposition, no queued successor. Matches the standing stranded-INFRA cohort; needs governed reclassification, not more Q02 flooding. |
| `q09_sealed_plan_hold_age` | FAIL | **Factory bottleneck (real)** | 9 Q09_NEWS sealed-plan holds >6h (several 122h). Q09 dispatch is head-blocked on `bind-q09-plan`. |
| `q09_autoseal_hold_census` | FAIL | **Factory bug (real)** | 9 active holds; trigger `Q09_AUTOSEAL_BIND_PLAN_FAILED`×8 + `Q09_AUTOSEAL_INCLUDE_CLOSURE_FAILED`×1. The Q09 autoseal/bind-plan path (`bind_q09_run_plan`, `build_q09_include_closure.py`) is failing to seal → Q09 cannot advance to Q10. Directly blocks the frontier the rebaseline wants to complete. |
| `pending_artifact_binding_drift` | FAIL | **Mixed: correct-hold + this-worktree** | 14 CONTENT_CHANGED bindings across 9 pending rows, mostly HELD. This is the fail-closed guard doing its job (artifact bytes changed vs the pending row's bound hash). Several rows (QM5_1401 etc.) are held because *this branch* modified their `.mq5`; that subset is expected. The append-only rebaseline contract must bind build+setfile hash on enqueue precisely to keep this guard meaningful. |
| `work_item_phase_age_slo` / `pending_tail_age` / `agent_task_aging_slo` / `agent_task_state_stranded` | FAIL/WARN | **Backlog (expected under drain directive)** | Large aged Q02/Q03 tails and PIPELINE/RECYCLE/APPROVED limbo; consistent with the "drain everything through the gates" state. Census/gap-matrix work will reclassify these. |
| `phase_invalid_rate_7d` | FAIL | **Mostly expected** | Worst = `COMPILE_EA` 46.7% invalid (non-trading utility churn). All *trading* phases are healthy (Q02 0.2%, Q04 0.0%, Q08 4.8%). Not a dispatch-correctness defect. |
| `review_lane_count` | WARN | **Backlog (Claude lane)** | 105 tasks in REVIEW (>100) — the review lane that only Claude closes; head-blocks agent routing if it grows. |
| `schtask:QM_StrategyFarm_FactoryON_AtLogon` | FAIL | **Expected** | `0x800710E0 interactive-launch-queued` — normal for the interactive/visible Factory_ON logon task. |
| `terminal_account_profiles` | WARN | **Transient** | Latest T5 launch has not yet proved account readiness (`20260823.log`). Self-resolves once the terminal proves the account. |
| `backup_calendar_continuity` / `ks_baseline_*` / `ftmo_trial_pulse` / `schtask:QM_Public_Snapshot_Hourly` / `MailboxSourceIntake` | FAIL/WARN | **Not dispatch** | Backup infra (G: mount absent 08-18), live-book/KS baseline, FTMO pulse, snapshot/mailbox recurring non-zero — none affect factory backtest dispatch. |

**Net dispatch picture:** two *real* factory issues gate the rebaseline frontier — the **Q09 autoseal/bind-plan failure** (`q09_autoseal_hold_census`, `q09_sealed_plan_hold_age`) which stalls Q08→Q09→Q10 advancement, and the **stale pump lock** (transient). Everything else is either backlog consistent with the drain directive, an artifact of this uncommitted worktree (dirty-guard, binding-drift subset), or non-dispatch infra. No evidence of a gate-advancement routing bug at runtime today (invalid rates on trading phases are ~0).

---

## 4 · Files referenced (for follow-up work)
- Contract: `tools/strategy_farm/config/gate_manifest.v3.json`, `tools/strategy_farm/gate_manifest.py`, `tools/strategy_farm/phase_ids.py`
- Advancement: `tools/strategy_farm/farmctl.py` (lines 280-287, 10034, 10214, 15587, 15705, 15892, 15999, 21621-21790, 22176, 22503-22660, 24835-25007), `tools/strategy_farm/evidence_cascade_driver.py`, `tools/strategy_farm/terminal_worker.py`
- Factory lifecycle: `tools/strategy_farm/Factory_ON.ps1`, `Factory_OFF.ps1`, `build_runtime_activation_decision.py`, `factory_runtime_activation.py`, `run_pump_task.py`
- Enqueue/sweep/repair: `sweep_enqueue_built_eas.py`, `r_eval_drain.py`, `repair.py`, `requeue_stranded_infra.py`, `invalidate_unprofitable_cascade.py`, `unbuilt_cards_disposition.py`
- Book/portfolio: `q09_news_schema.py` (view `portfolio_candidates_eligible`), `deploy_tlive_book.py`, `portfolio/portfolio_periodic_report.py`
- Optimization fork: `framework/scripts/q16_head_to_head.py` (via `enqueue_head_to_head`)
