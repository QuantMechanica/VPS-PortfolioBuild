# PHASE A — CURRENT TRUTH SNAPSHOT (Continuous Book Evolution)

**Authoritative synthesis of 18 read-only Phase-A audits.** Directive:
`docs/ops/evidence/2026-09-15_continuous_book_evolution/owner_directive_verbatim.md` (§68 Phase A) +
follow-up `owner_followup_directive_completeness_verbatim.md`. As-of 2026-09-15 ~12:2x–14:2xZ,
canonical runtime host, branch `agents/board-advisor`. Truth precedence per directive §1
(OWNER directive > signed decisions > repo code > runtime/SQLite/filesystem > immutable reports > Vault > historical docs).
Every number carries a source path. A fresh orchestrator can act on this without chat history.
Source audits: `docs/ops/evidence/2026-09-15_continuous_book_evolution/audit/*.md`.

## Headline (3 lines)

1. **Both engines are live but neither is being weekly-recomposed yet.** DXZ runs a healthy 24-sleeve book (9.7499% risk, acct 4000090541, DD 2.44%); a 28-sleeve/29-chart v2 is staged (cutover risk 9.8013%, post-burn-in target 11.0%) but **has not cut over**. FTMO runs an 8-sleeve *explorative* demo (acct 1514536732, Standard 2-Step/100k), **not** a frozen intended-challenge book.
2. **The one qualified pool = 26 (EA,symbol) pairs** (contiguous-through-Q14, `book_build_guard`); the "25-candidate" trigger is already SATISFIED and is the rule §4 supersedes. **FTMO fitness = 0 candidates today** (Q10 admits 0/42; best FUND_SCORE 0.41 vs floor 1.0). The binding gaps are *composition, evidence and documentation*, not candidate count.
3. **Two live incidents + broad doc drift.** Factory: 6/10 terminals idle ~3h on an un-winnable 44 GB RAM reservation (QM5_10025). Agent lane: Claude `--max-sessions 3` fan-out double-worked a ticket. Docs: 4 superseded rules still written as binding across 9+ vault pages + code mirrors; Kimi real-quota endpoint exists but the governor still runs artificial caps; research disk guard (80 GB) permanently blocks research below the 60 GB purge floor.

---

## 1. DXZ — current live book + planned v2

**Source:** `audit/dxz_live_book.md`; `audit/candidate_universe.md`; `audit/robust_rebuild_census.md`.

### 1.1 Current live book (running NOW)
| Field | Value | Source |
|---|---|---|
| Account | 4000090541 (Darwinex-Live) | `D:/QM/reports/state/live_book_dd_guard_state.json` |
| Sleeves | **24** | `live_book_pulse.json → book_manifest = portfolio_manifest_live_24sleeve_20260724.json` (sha 8c719b08) |
| Total risk | **9.7499%** (Σ RISK_PERCENT of 24 deployed `.set`) | `C:/QM/mt5/T_Live/MT5_Base/MQL5/Presets/01..24_*.set` |
| Equity / HWM | 99,389.17 / 101,871.44 | `live_book_dd_guard_state.json` (obs 12:29:29Z) |
| Drawdown / halt | 2.4367% / 10.0% (breached=false) | same |
| Runtime | RUNNING, pid 9288, dxz_contract_ok=true, verdict WARN | `live_uptime_watchdog.json`, `live_book_pulse.json` |
| ENV / risk mode | all sleeves `environment: live`, `RISK_FIXED=0` | `.set` files |
| Live WARNs | loaded_ok 23/24 (1 missing file); journal stale >120m (open pos) | `live_book_pulse.json → alarms` |
| **3 dark sleeves (0 fills, 46–47d)** | 12778/AUDUSD, 12969/USDJPY, 13117/EURGBP — hard-compiled `.DWX` symbol literal vs bare broker name (Hard Rule 2026-09-06 violation) | `live_sleeve_drift.json`; `ANLEITUNG_DXZ_V2.md` |
| Balke live sleeves | 13301/GDAXI (preset 01), 13213/USDJPY (preset 02) — both `portfolio_candidates=EVIDENCE_STALE` yet deployed (drift) | `audit/robust_rebuild_census.md` |

### 1.2 Planned v2 (Sunday 2026-09-20 cutover — NOT yet executed)
| Field | Value | Source |
|---|---|---|
| Profile | `DarwinexZero_Book2_LiveOps` (n_sleeves 28, n_charts **29** = 28 trading + `QM_AccountMonitor`) | `C:/QM/deploy/DXZ_V2_20260913/profile/DarwinexZero_Book2_LiveOps/profile_manifest.json` |
| **Cutover risk** | **9.801297%** (VERIFIED = Σ 28 non-monitor chart risks) | `profile_manifest.json` |
| **Post-burn-in target** | **11.0%** (design budget, cap 1.5%/sleeve) | `manifest_v2_28_r11.json` |
| Change vs live | **+4 new sleeves** (1537/XAGUSD, 9641/WS30, 10700/XAUUSD, 13013/NDX at burn-in weight), 0 removals, 24 reweights, 41470 **replaces** 12969/USDJPY (symbol-literal fix) | `manifest_v2_28_r11.json`, `copy_plan_v3_cutover.json` |
| Deploy plan | 34 copy items, preflight all-green 08:01Z | `tlive_book_cutover_plan_20260915T080123Z.jsonl` |
| Deferred | 13054/XTIUSD, 21505/XAGUSD (`DEFERRED_SYMBOL_LITERAL_FIX`); 12778/13117 stay dark no-ops in v2 | `copy_plan_v3_cutover.json → skipped_pending` |
| Cutover status | **NOT executed** — recovery pointer absent, presets still 01–24, profile still `DarwinexZero_V2_LiveOps` | absent `tlive_recovery_profile.json`; preflight `recovery_pointer_absent ok=true` |
| OWNER-only acts | (a) add XAGUSD+WS30 to T_Live Market Watch Sunday; (b) AutoTrading toggle | `decisions/2026-09-15_owner_freifahrtsschein_scope_1_to_3.md` |

**Note on the "55-pair DXZ book":** `research_universe_whitespace` cites `dxz23_execution_contracts.json` = 55 ea×symbol contracts. That is the broader **execution-contract registry** (DXZ-23 fidelity-remediation set), NOT the deployed live sleeve count. **Live-deployed = 24 sleeves** (`live_book_pulse.json`) is authoritative; I overrule the "55 book pairs" phrasing as a book-size statement.

### 1.3 §6/§58 weekly-recomposition live feeds MISSING
Per-sleeve live PnL attribution is **~10 days stale** (`D:/QM/reports/portfolio/live_attribution_20260905_054540/`); no live correlation / trade-overlap matrix from `Bases/Darwinex-Live/trades/4000090541/deals_*.dat`; `book_monitor_state.json` tracks a stale 5-sleeve pool (not the live 24/28); **no internal DXZ D-Score ingestion** exists.

---

## 2. FTMO — current Demo state + bottleneck today

**Source:** `audit/ftmo_demo_state.md`; `audit/ftmo_fitness_candidates.md`.

| Field | Value | Source |
|---|---|---|
| Terminal / account | pid 10836; login **1514536732**, FTMO-Demo, **Standard** 2-Step / 100k Free-Trial, 1:100 | `…/81A933A9…/config/common.ini`; `2026-09-06_ftmo_demo_account_terms.md` |
| Running book | **8 trading sleeves** (10706 GBPUSD, 11421 EURUSD, 11422 USDCAD, 11910 NZDUSD, 13054 USOIL.cash, 20048 USOIL.cash, 1537 XAGUSD, 21505 XAGUSD) @ RISK_PERCENT 0.3125 + 13206 governor + QM_FTMO_TrialTelemetry | `…/Profiles/Charts/Default/chart*.chr`; `roster_ftmo_demo_v2.json` |
| Live state | RUNNING, AutoTrading effectively ON, equity **99,811.51**, total_dd 0.19%, 0 open / 1 pending, magics 8/8, verdict WARN | `D:/QM/reports/state/ftmo_trial_pulse.json` (12:19:54Z) |
| Character | **explorative "M13" capture, all DXZ-derived D1/H1/H4 swing** — none purpose-built for FTMO; NOT a frozen intended-challenge book | `FTMO_ACCELERATION_2026-09-09.md`; roster |
| Demo track record | cycle-1 (Jun29–Jul24, reset 08-02): net **−9.95%**, realized max-DD **−10.26% → BREACHES FTMO 10% total-loss**; cycle-2 (Aug2–Sep4): −0.15%, near-dormant | `…/journal/live_deals_normalized.csv` parse |
| FTMO fitness | **0 candidates**: Q10 FTMO gate admits **0/42** (34 EVIDENCE_MISSING, 3 NOT_CONFIG_LOCKED, 5 SCOPE_NOT_FTMO); best FUND_SCORE **0.41** (12989 XAUUSD) vs floor **1.0** | `q09_ftmo_recommendation.collect()`; `fund_scores.json`; `BOOK_SPRINT_2026-09-20.md:54` |
| Planned demo-book v2 | DXZ v2 28-sleeve roster remapped to FTMO symbols, sha-bound, **no rebuild, no qualification claim**; census 24 ADMIT / 4 EXCLUDE | `evidence/2026-09-15_ftmo_demo_v2_census/README.md`; ticket 42a437a4 IN_PROGRESS (RECYCLE→merge after collision) |
| Rule snapshot | `2026-09-04_ftmo_official_rules_snapshot.json` — **11 days stale** (own max 7); labelled **Swing** (account is Standard); missing instrument-restriction list (trading-symbols 404) + Standard provider leverage | snapshot file |

**Bottleneck TODAY = evidence + definition, NOT compute.** No frozen intended-challenge portfolio has completed a representative rule-faithful 2-week demo (§12); FTMO_FITNESS (first-passage / breach probability) is uncomputed for any pool; the economic gap is structural (all proven inventory is low-density swing — the opposite of the FTMO-fit profile §17–§19). Secondary: stale/wrong-profile rule snapshot; stalled v2-census ticket. **Not** the bottleneck: uptime, MT5 compute.

---

## 3. Canonical candidate universe — ONE definition of "qualified"

**Source:** `audit/candidate_universe.md` (the §68A reconciliation task — authoritative).

**Canonical definition (adopt this one, retire all others):**
> **`qualified` = a (EA,symbol) pair whose highest *contiguous* valid gate is the active contract's terminal requalification gate (today Q14): every gate on Q02..Q14 has a `done` row with an economic PASS-class verdict, no earlier gate has a hole, and no invalidating hold sits on the chain.**

This is `book_build_guard.check_book_build_allowed` predicate A (`book_build_guard.py:111-124` + `gate_manifest.terminal_requalification_gate`). **Why this one:** it is the predicate the book builder and OWNER-order guard already enforce; it is the strict, contiguity-respecting count; the other published numbers do not enforce contiguity and are diagnostics.

**Count today = 26** distinct (EA,symbol) pairs; 26 distinct EAs; 21 strategy families (`book_build_guard --status`, live DB mode=ro). Book-build guard **ALLOWED for both dxz and ftmo** (26 ≥ 25, both OWNER orders present: `decisions/2026-09-13_owner_book_order_dxz.md`, `2026-09-14_owner_book_order_ftmo.md`).

**Pair list:** `docs/ops/evidence/2026-09-15_continuous_book_evolution/audit/candidate_universe.csv` (`status=QUALIFIED`). All 26 are `.DWX`; **all 26 Q10-recommend DXZ, NONE recommends FTMO**. Flag: QM5_41219 XAUUSD's *latest* news row is REVIEW_REQUIRED (qualifies via an earlier CONFIG_LOCKED row → needs Q10 refresh).

**The three simultaneously-published "Q14 candidate" numbers (reconciled):**
| # | Number | What it is | Source |
|---|---|---|---|
| **26** | **QUALIFIED (canonical)** | contiguous-through-Q14, guard predicate | `book_build_guard.py`; `pipeline_state.json path_to_25.frontier_histogram.Q14` |
| 28 | reservoir diagnostic | distinct pairs with a *done* Q14 terminal-verdict row (no contiguity) | `pipeline_state.json … reservoir.q14_terminal_rows` |
| 29 | observed diagnostic | pairs that reached any Q14 row regardless of holes below | `pipeline_state.json by_gate_v4.Q14` |
| 34 | verdict-row count | Q14 terminal verdict rows (KEEP_INCUMBENT 33 + SUPERSEDED_DUPLICATE 1) | `pipeline_state.json path_to_25.opt_fork.terminal_verdicts` |

**Frontier (live contiguous census, `rebaseline_census.build_pairs`):** 1–2 gates short of Q14 = **0 pairs**; 3 short = QM5_10911 & QM5_11294 GDAXI.DWX (at Q11, blocked at Q12); 4 short = QM5_1354 XAUUSD.DWX (at Q10, blocked at Q11). Large reservoir far back: **72 pairs valid through Q09** awaiting Q10 news (56 news holds/pending).

**DXZ membership vs pool:** DXZ book v2b roster = 24 (all from the 26; excludes 20266 XTIUSD, 21507 XAUUSD, `roster_v2b.json`). Live staged 28-sleeve `manifest_v2_28_r11.json` overlaps the qualified-26 by **only 10** — the incumbent book predates and diverges from the current qualified pool (Phase-E reconciliation input).

---

## 4. Recent robust / commercial rebuild census

**Source:** `audit/robust_rebuild_census.md` (+ full CSV `audit/robust_rebuild_census.csv`).

| EA | Strategy | Symbol | Highest contiguous gate | Live? | §56 class | Note |
|---|---|---|---|---|---|---|
| **QM5_13213** balke-gmt3-range-breakout | René Balke session range breakout (H1) | USDJPY | **Q11** (PF 1.16, 1624 tr, DD 22.8%) | **LIVE DXZ** | B (better impl of parent 9936) | XAUUSD leg = Q02 RETIRE; blocked by NEWS_CALENDAR_TAINTED pin 86b2c0b5 + BALKE_PATTERN_REPAIR_REVIEW hold at Q12 |
| **QM5_13301** balke-minute-range-breakout | Balke on M5 clock | GDAXI | **Q10** (PF 1.28–1.35, DD 14.5%) | **LIVE DXZ** | E (materially distinct) | blocked by NEWS_CALENDAR_TAINTED |
| QM5_13036 balke-go-long-regime | SMA200 regime long-only (YT seed) | GDAXI | Q10 (PF **1.04** near-breakeven) | no | E (distinct, not a range breakout) | NDX = Q02 FAIL; §59 anti-churn candidate |
| QM5_21501 …-ppcensus | DL-089 census mirror of 13213 | USDJPY | Q11 (metrics identical) | no (by design) | D (duplicate) | "must never reach a book" |
| QM5_41097/41324/41398/41405 | Balke USDJPY opt strand | USDJPY | OPT_CENSUS, all NOT_APPROVED | no | C (param variant) | window sweep 2026-09-11: **s0_l8 00:00–08:00 UTC+3 OOS PF 1.21 beats live 03:00–06:00** |
| QM5_9936 ff-range-breakout-gmt3-h1 | Balke parent | USDJPY | Q09 PASS, Q10 REVIEW_REQUIRED | no | — | 13213 differs only in range_start_hour + one 18:00 exit |
| Gold Reaper (QM5_31008) | Schrynemakers gold breakout | — | REJECTED seed, 0 work_items, never built | no | B/D (clone of killed Balke XAU) | `GOLD_REAPER_BREAKOUT_MINING_2026-07-23.md` = "do NOT clone" |
| ORB cohort (~80 dirs) | Zarattini/Unger/Grimes/FTMO-ORB… | various | none past Q08 except Balke family | no | — | not a live diversification source |
| Commercial band 30000–41999 | Pardo/Unger/Kaufman/Chan/GARCH… | various | cap Q05–Q08 (41219/41221 Q11 are internal requal, not commercial) | no | — | no commercial rebuild besides Balke near a book |

**Gap:** no cross-variant trade-overlap/return-correlation file exists; `tools/strategy_farm/window_sweep.py` deal-list comparison over `D:/QM/reports/work_items/<id>/.../summary.json` is the tool to compute §56 numeric overlap. No Q10 FTMO-recommendation field is populated for any Balke → FTMO suitability formally UNKNOWN.

---

## 5. Pipeline / factory state + top-3 bottlenecks

**Source:** `audit/pipeline_factory_state.md`; `audit/candidate_universe.md`.

- **work_items:** total 149,116 — done 96,100 / failed 49,229 / pending 3,783 / active 4 (`farm_state.sqlite`).
- **Book precondition already MET** both venues (qualified 26 ≥ 25, OWNER orders present); no Q15 construction has run. Book *quality* now depends on the optimisation frontier, which is nearly static and produces mostly "no change" (Q12 33 NO_FILTER_CHANGE, Q13 35 NO_PARAMETER_CHANGE, Q14 33 KEEP_INCUMBENT).
- **Frontier histograms disagree (drift, resolved):** `pipeline_state.json by_gate_v4` = Q08:52 Q09:107 Q10:32 **Q11:51** Q12:2 Q13:0 **Q14:29** (used by `pipeline_factory_state`, `wiki_sync_tooling`); the live contiguous census (`rebaseline_census.build_pairs`, used by `candidate_universe`) = Q09:72 **Q11:2** Q12:0 **Q14:26**. **Resolution:** the contiguous census (26 at Q14, 2 at Q11) is authoritative for *qualified/contiguous*; `by_gate_v4` (29/51) is the more-permissive *observed-gate reservoir*. I follow `candidate_universe` (the §68A reconciliation task) for the qualified definition and note `by_gate_v4` as reservoir diagnostics. Both agree `book_guard.qualified_pairs = 26`.
- **Active holds 3,062:** PRESCREEN_SKIPPED 2,555 (benign inert), RAM_44GB_NOT_WINNABLE 144, NEWS_CALENDAR_TAINTED 99, Q08_DSR_CONTEXT_UNAVAILABLE 49. Unheld claimable pending = **732** (Q02 389, Q04 219, Q12 54).
- **agent_tasks:** TODO build_ea 274, review_ea 22, ops_issue 20, **325 unassigned TODO rows**; Q10_NEWS REVIEW_REQUIRED 95 + INVALID_EVIDENCE 48.
- **Resources:** 8C/16T, RAM 67.8 GB total / ~27 GB free, pagefile 64 GB fixed. C: 86.9 GB free, **D: 61.2 GB free (6.4%, 1 GB above the 60 GB purge low-water)**, G: 82.5 GB.
- **candidate_qualifications table is EMPTY (0 rows)** though nominally the qualification ledger — qualification is tracked via `portfolio_candidates` + `by_gate_v4`.

**Top-3 bottlenecks (ranked by business value):**
1. **[CRITICAL] Un-winnable 44 GB RAM reservation head-of-line-blocks 6/10 terminals.** QM5_10025 (`heavy_or_unknown_multisymbol`, flat 44 GB) has 6 un-held Q02 rows at the claim head; 6 terminals idle ~2.95h in `drain_predrain_open` (`ram_class_skipped=251`), census 0/h against 732 claimable rows. `terminal_worker_*.log`, `drain_window.json`. **GRÜN fix:** apply RAM_44GB hold to the 6 rows OR reclassify to measured footprint.
2. **[HIGH] Optimisation frontier frozen at Q12 Pattern Filter.** The only lever left on book quality; Q12 lane nearly static (74 pending / 54 un-held; mostly NO_CHANGE). Shift compute to frontier-first Q12→Q14 per `gate_manifest.v4.json.backfill_planner_contract`.
3. **[MEDIUM] Un-dispositioned holds + review + 325 unassigned tasks.** NEWS_CALENDAR_TAINTED 99, Q08_DSR 49, Q10_NEWS 95+48, 325 uncommissioned agent_tasks — deterministic dispositions, worked as capacity permits (§23) without blocking the books.

---

## 6. AI quotas, scheduled tasks, routing, resources

**Source:** `audit/quota_tasks_routing_resources.md`; `audit/mission_control_briefing.md`.

| Seat | State | Detail | Source |
|---|---|---|---|
| Claude | THROTTLED | weekly 83% @65.7% elapsed, 5h 72%; `CLAUDE_DISABLED.flag` set; router `enabled:false` | `quota_governor_state.json`, `CLAUDE_DISABLED.flag` |
| Codex | THROTTLED | weekly 80% @45.2%; budget-line target 92%, reset 2026-09-19; `CODEX_LOW_TOKENS.flag`; gate `codex_budget_line_exceeded` | `codex_budget_line.json` |
| agy (gemini lane) | UNKNOWN | HTTP 401 `token_expired`; `AGY_LOW_QUOTA.flag`; **needs OWNER Antigravity relogin** | `agy_quota.json` |
| Kimi | NORMAL | 2/40 day, 2/200 week, `usage_source=local_ledger_only` (artificial); no `KIMI_LOW_QUOTA.flag` | `kimi_governor_state.json` |

- **Scheduled tasks:** 74 QM_* tasks; 6 Running healthy; 8 Disabled (incl. retired `TerminalWorkers_AT_STARTUP` — expected). **Failing (triage):** `QM_NewsCalendar_Refresh` 0x1, `QM_MailboxSourceIntake_Daily` 0x1, `QM_Public_Snapshot_Hourly` 0x1, `QM_WorkItemLogPruner_Daily_0310` 0x1, `QM_EvidenceCohortWatch_Daily_0420` 0x3 (path), `QM_StrategyFarm_Cockpit_2min` 0x800710E0 (abort). Stale one-offs: `QM_TMP_*` (0x41306).
- **Routing: no drift.** `agent_router.py` code, router `registry_contract.ok:true`, and vault Annex 2026-09-15 agree; Kimi authority guard intact (no code/tests/repo_edit/ops caps, cost_rank 12, max_parallel 1). Claude `enabled:false` is the quota-flag runtime override, not contract drift.
- **Mission Control:** primary surface `render_cockpit_v2.py` (data `mission_control_v2_data.build_contract`), task `QM_StrategyFarm_Cockpit_2min` (2 min, currently aborting). "Way to 25" lives on **three** surfaces (cockpit v2 "Weg zu 25", morning-brief §3, `path_to_25.py` hardcoded `/25`). **No Book Evolution / FTMO Readiness / Research section exists yet**; the read-model JSON the §60/§62 sections need mostly exists but is not persisted/wired.
- **Claude-lane fan-out defect (§35):** `--max-sessions 3` spawns N task-agnostic sessions; no per-task pid-owned lease (router writes `agent_task:<id>` with `owner_pid=NULL`); ticket 42a437a4 was double-worked. Fix ticket = **3e0c8b83** (per-slot exec-lease + `QM_ASSIGNED_TASK_ID` pin). **Interim GRÜN mitigation: `--max-sessions 1`.** Does not block portfolio/FTMO/Kimi.

---

## 7. Kimi state + recommended real-quota source

**Source:** `audit/kimi_quota_discovery.md`; `audit/quota_tasks_routing_resources.md`.

- **State:** NORMAL, subscription Allegro USD 99, 2026-09-15 → 2026-10-15, usage_source `local_ledger_only`, artificial caps 40/day 200/week; ledger = 2 smoke rows (`usage:null`). **Orchestration lane `QM_StrategyFarm_KimiOrchestration_15min` is NOT installed** (defined behind `-IncludeKimi`, default OFF) — the §29 "continuously available" gap. Governor task `QM_StrategyFarm_KimiGovernor_15min` = Ready. No real campaign has run yet (§16 follow-up: integrated but not researching).
- **RECOMMENDED real-quota source (definitive):** the endpoint the official CLI's own usage panel calls —
  **`GET https://api.kimi.com/coding/v1/usages`** with `Authorization: Bearer <access_token>` (from `C:/Users/Administrator/.kimi-code/credentials/kimi-code.json`, read at runtime, never logged) + `Accept: application/json`, 8 s timeout. Returns `usages.{limit_5h, limit_7d, limit_month_total, limit_month_code}` each `{used_ratio, reset_time}` + `boosterWallet` (the "additional quota"). Plan name ("Allegro") comes from a second call `GET .../coding/v1/me` field `user_level_name` (PII-bearing → keep only `user_level_name`/`status`/`region`). This **refutes** the stale "no programmatic usage endpoint" claim in `KIMI_INTEGRATION_ARCHITECTURE.md §1/§7`, `kimi_adapter.v1.json:88`, `2026-09-15_kimi_integration/audit/kimi_cli.md §6`.
- **Governor seam already present:** `kimi_governor.compute_state` flips `usage_source` to `usage_snapshot` when a ledger row carries non-null usage (`kimi_governor.py:168-173,252`) — a fetcher closes the loop with no schema change. Keep 40/200 as runaway/anomaly guards only (§33). Token-stale → `fetch_status=auth_stale`, fall back to ledger; **do NOT re-implement the OAuth refresh grant**.

---

## 8. Research disk guard — measurement + recommended threshold

**Source:** `audit/research_disk_guard.md`; `audit/quota_tasks_routing_resources.md`; `audit/rule_inventory_code.md` F13.

- **Measured:** D: 61.2 GB free / 953.9 GB (6.4%); the tester-cache purge parks D: at its **60 GB** low-water (`QM_StrategyFarm_TesterCachePurge` runs `-LowWaterGB 60`). The research guard refuses at **D: < 80 GB** (`research_env.py:51 RESEARCH_DISK_MIN_FREE_GB=80.0`, `:66 DEFAULT_RESEARCH_DRIVE=D:/`). **80 > 60 ⇒ research on D: is structurally, permanently refused.** Live guard now: `allowed:false … DISK_LOW:61.2GB<80.0GB`.
- **Research's real footprint is ~0.3 GB** (the venv `D:/QM/research/venv`); its dataset output already writes to **C:** (`observe_projector.py:57 DEFAULT_OUT_ROOT=C:\QM\repo\artifacts\research_datasets`). CPU 0%, free RAM 27.8 GB — not binding. The 80 GB floor is not evidence-based; it watches the wrong drive at the wrong threshold. ~30 GB idle tester cache is reclaimable now under the existing evidence-guarded purge (no evidence deleted).
- **RECOMMENDED threshold (primary, R1):** point the guard at the drive research actually uses — `DEFAULT_RESEARCH_DRIVE = C:/`, `RESEARCH_DISK_MIN_FREE_GB = 20.0` (= measured 0.3 GB ×2 with a 20 GB safety floor; C: has 86.9 GB free), add env overrides `QM_RESEARCH_DRIVE`/`QM_RESEARCH_DISK_MIN_FREE_GB`, and relocate the venv to C:. **Fallback (R2):** keep D: but set the floor to **60** (= the purge low-water; documented as "must equal tester_cache_purge low-water"). Retire the stale `tester_cache_purge.ps1:30` default (150→60). Never delete canonical evidence to free space. Record the invariant `worker_floor(40) ≤ purge_low_water(60) ≤ research_floor`.

---

## 9. Documentation drift register (merged — one row per superseded/stale statement)

**Sources:** `audit/vault_doc_drift.md`, `candidate_universe.md`, `rule_inventory_code.md`, `dxz_live_book.md`, `robust_rebuild_census.md`, `research_disk_guard.md`, `wiki_*`, `kimi_quota_discovery.md`. Supersession = mark obsolete + update current guidance; never delete history (§3/§65).

| # | Doc/Vault/code says | Runtime / directive says | Path | Target action |
|---|---|---|---|---|
| 1 | Fixed ≥25 book trigger (binding/fail-closed) | §4 supersedes; evaluate any valid pool | vault `Q15…:29,79`, `Pipeline Overview.md:100/141/198`, `Pipeline Operations Workflow.md:144,192`, `Gate Manifest v4 Diff.md:91`; `BOOK_CEREMONY_RUNBOOK_2026-09.md:1,6`; `book_build_guard.py:31,238-242`; `gate_manifest.v4.json:370-384` | rewrite/annotate to "no fixed minimum"; keep OWNER-order requirement |
| 2 | Family≤3 / Symbol≤2 / |r|<0.5 "non-negotiable" caps | §8 → default guardrails / risk inputs | vault `Q15…:132-141`, `Pipeline Overview.md:72`; `ftmo_probability_contract.v1.json:39` | convert to guardrails + dependence panel |
| 3 | Q17 mandatory min-lot + fixed 14-day + "no demo gate" | §10 → evidence-based introduction/probation | vault `Q17…:29,36,58-60,95-97`, `Q16…:47,73`, `Pipeline Overview.md:74,185,201`, `Risk Conventions.md:22,95-102`; `PIPELINE_V5_SUB_GATE_SPEC.md:253-257`; `BOOK_CEREMONY_RUNBOOK_2026-09.md:162` | refactor to evidence-based; leave QM_News.mqh 14d staleness untouched |
| 4 | "Drain everything before a book" Zwischenziel | §23 pipeline continuous | vault `Current Objective.md:24-43`, `Claude.md:29`, `12 ToDo/10_Pipeline_Leerlauf.md:6` | mark superseded + rewrite |
| 5 | HR16 "one research/one EA at a time" as Hard Rule | §24 controlled parallelism allowed | vault `Hard Rules.md:1,87-94`, `Operational Disciplines.md:156,164`, `Determinism…:81,116`, `Pipeline Overview.md:202`, `Research Methodology.md:13` | append HR16 annex; keep determinism-first framing |
| 6 | "Way to 25 / Nordstern ≥25" on live surfaces | §3 abolished as business target; §60 replace with Book Evolution | `Heartbeat.md:33-40` (gen `heartbeat_snapshot.py`), 23× `10 Morning Briefing/*` (gen `morning_brief.py`), `Claude.md:89-90`; cockpit `render_cockpit_v2.py:880-999`, `path_to_25.py:617` | fix generators; keep dated files as history |
| 7 | FTMO "+10% / ≤30d / 60-day sprint" | §15 success-probability > speed | vault `Current Objective.md:19-21`, `07_FTMO_Kampagne.md:21` | reframe metrics as secondary diagnostics |
| 8 | `_HOME.md:53-55`: canonical manifest v2, pipeline Q00–Q13+Q14–Q16 | runtime v4 linear Q00–Q17 ACTIVE | `_HOME.md:53,55` | rewrite to v4 |
| 9 | `START_HERE.md`: "no self-chosen work", "research only if cards<5", "no ML" | §37 Fable may originate; §38/§49/§50 autonomous discovery; §41/§42 ML offline allowed (HR14 annex) | `START_HERE.md:21,27,28` | rewrite/annex |
| 10 | AI Spend & Quota Governance page: Codex+Claude only, no Kimi | §29–§33 add Kimi lane + real telemetry | `06 Infrastructure/AI Spend and Quota Governance.md` (mtime 2026-07-22) | append Kimi section |
| 11 | `gate_manifest.v4.json:5 draft_note` "PROPOSAL ONLY, default stays v3" | v4 is ACTIVE default (`:4`, activation_guard ACTIVE) | `gate_manifest.v4.json:5` | remove stale note |
| 12 | "OWNER counter counts terminal Q14 pairs" (⇒28/29) | guard qualified = **26** contiguous | `CLAUDE.md`, `COMPANY_AUDIT_LIVE_SOURCES_2026-05-30.md` | relabel 28/29 as diagnostics |
| 13 | `pairs_valid_at_least_Q16` key | terminal is Q14 under v4 (value 26 correct, key stale) | `rebaseline_census.py:640-641` | rename `pairs_valid_at_least_terminal` |
| 14 | tester purge "no-op ≥150GB / LowWater 80→150" | live task `-LowWaterGB 60` | `CLAUDE.md`, `COMPANY_AUDIT_LIVE_SOURCES_2026-05-30.md:135`; `tester_cache_purge.ps1:30` | reconcile to 60 |
| 15 | Kimi "no programmatic usage endpoint" | endpoint exists: `GET /coding/v1/usages` | `KIMI_INTEGRATION_ARCHITECTURE.md §1/§7`, `kimi_adapter.v1.json:88`, `kimi_cli.md §6` | correct; ledger = fallback |
| 16 | `ftmo_probability_contract.v1.json:39` family/symbol caps "OWNER_RATIFIED, enforced at build_book_ftmo.py:60,66" | those lines are FUND_SCORE_FLOOR + a comment rejecting per-symbol caps; no builder enforces the discrete caps | contract `:39` vs `build_book_ftmo.py:60,66` | fix stale source pointer; status ADVISORY |
| 17 | `portfolio_candidates`: 13213/USDJPY, 13301/GDAXI = EVIDENCE_STALE | both deployed LIVE in DXZ | `portfolio_candidates` vs T_Live baselines/journal | reconcile off EVIDENCE_STALE |
| 18 | `live_risk_freeze.json status=LIFTED` contradicted by BLOCKED/PARTIAL sub-conditions | OWNER 2026-09-14 written lift overrides; condition block stale | `live_risk_freeze.json` | clean stale condition block |
| 19 | `book_monitor_state.json` = 5-sleeve candidate pool | live book = 24 sleeves | `book_monitor_state.json` vs `live_book_pulse.json` | retire/repoint to live roster |
| 20 | SPEC 13213 lists XAUUSD as best symbol; memory treats 13036 as GDAXI+NDX | XAUUSD = Q02 RETIRE; NDX = Q02 FAIL, GDAXI PF 1.04 | `SPEC.md:44`; MEMORY.md vs ea_metrics | correct SPEC/memory |
| 21 | Q10 = "News Impact + FTMO Recommendation" | Q10 aggregates carry no FTMO recommendation field | `CLAUDE.md` vs `…/Q10/…/aggregate.json` | document the gap / populate field |
| 22 | Named canonical pages MISSING | Mission Control doc, Kimi doc pages do not exist in Vault; FTMO Campaign only partial | vault `find` | create pages (§60/§65) |
| 23 | Strategy Wiki: `_INDEX.md` "2026-05-08, 28 cards" | 45 nodes exist (0 generated); ~3,750 canonical records → **0.35% coverage** | `09 Strategy Wiki/`; `wiki_completeness_summary.json` | build deterministic exporter |
| 24 | `research_dedup_check.py:60` wiki path `G:\My Drive\09 Strategy Wiki` | real root `…\QuantMechanica - Company Reference\09 Strategy Wiki` — dedup fail-closed since inception | `research_dedup_check.py:60` | fix path (shared `vault_paths.py`) |
| 25 | `FTMO_ON.ps1` header account 1514165262; account terms "AutoTrading OFF"; snapshot profile Swing | runtime account 1514536732, AutoTrading ON, account Standard | `FTMO_ON.ps1:59`; `2026-09-06_ftmo_demo_account_terms.md` | fix metadata |
| 26 | `assemble_stream_bundle.py:8` default incumbent = stale July `dxz_final_20260719` | live book is 24-sleeve 2026-07-24 manifest | `assemble_stream_bundle.py:8` (defect D4) | repoint to current live book |

---

## 10. Rule inventory (rule → enforcement path → class → directive disposition)

**Source:** `audit/rule_inventory_code.md` (§20/§21). Class: A=safety/evidence (keep), B=economic/selection (relax to guardrail), C=process (optimise), D=historical (superseded).

| Rule | Enforcement path | Class | Directive disposition |
|---|---|---|---|
| Fixed 25-candidate trigger | `book_build_guard.py:31,238-242`; `gate_manifest.v4.json:370-385`; `path_to_25.py:29` (sealed `decisions/2026-08-27_owner_count_definition_option_a.md`); tests `test_book_build_guard.py:58,91,107` | B (D-shaped hard block) | **§4 supersede** — <25 becomes a diagnostic; keep OWNER-order + fail-closed on unqualified |
| Q17 mandatory min-lot | **no code gate** (`gate_manifest.v4.json:277-288` OWNER/MANUAL); `PIPELINE_V5_SUB_GATE_SPEC.md:253-257`; `BOOK_CEREMONY_RUNBOOK_2026-09.md:162` | A/D | **§10 supersede** — evidence-based introduction; live toggle stays OWNER-only |
| Q17 fixed 14-day wait | no code gate; spec/runbook only (distinct from QM_News.mqh 14d staleness = A, keep) | C/D | **§10 supersede** — evidence-dependent probation window |
| Family cap ≤3 | documented `ftmo_probability_contract.v1.json:39` (stale source pointer); **not builder-enforced** | B | **§8** — status ADVISORY; keep `concentration_tail.py` %-budget cap as risk input |
| Symbol cap ≤2 | documented `:39`; `build_book_ftmo.py:66-69` comment explicitly rejects it; **not enforced** | B | **§8** — ADVISORY |
| Pairwise correlation cap 0.50 | `portfolio_correlation.py:77` (ROT_SEALED), `build_book_ftmo.py:196`, `book_reoptimizer.py:91`; Q09 marginal 0.40 `ftmo_timebox_eval.py:112-114` (DL-083) | A (mechanism) / B (number) | **§8** — admit-with-WARN + dependence panel; keep CLUSTER_CORRELATION_UNVERIFIED fail-closed; dated decision |
| HR16 one-at-a-time | no code gate; vault doctrine; `agent_router.py:645` max_parallel 1 (kimi), `min_ready_strategy_cards=5` | D | **§24** — controlled parallelism; raise max_parallel where compute/quota allow |
| Research source R1–R4 | `qb_reputable_source_criteria.md`; `card_intake_prescreen.py`; `research_source.py` (QM-RESEARCH sha256 fail-closed) | A | **already aligned** (§36/§37/§41/§42); generalize `source_author` to Fable/multi-agent; keep R4 runtime-ML reject |
| FTMO purchase thresholds (FUND_SCORE 1.0, P1-lower 0.80, DSR) | `build_book_ftmo.py:60,478`; `ftmo_probability_contract.v1.json` (PENDING_OWNER_RATIFICATION, ROT); **no purchase automation exists** | B | **§15** — keep as evidence gates; reframe ≤30d/60d speed as secondary; purchase stays OWNER-only |
| FTMO density rules | `build_book_ftmo.py:400-438`; `audit_activity_criterion.py:78` (≥10 entry-days/yr, OQ-18) | B | **§16/§18** — keep as positive input; make per-sleeve check a warning not hard reject; no upper cap penalising scalping |
| Redundant/serial gates | `gate_manifest.v4.json:290-310` linear chain; Q05/Q09/Q11 full-history re-runs; `reuse_rule` allows hash-bound reuse | C | **§22/§23** — enforce hash-bound reuse across Q05/Q09/Q11; parallelize Q07; lower no criterion |
| AI quota caps | `agent_quota_gate.v1.json`; `quota_governor.py` (FLOOR 15/CEIL 90); `codex_budget_line.py` (92); `kimi_governor.py` (40/200/70) | A/C | **§33** — Kimi 40/200/70 = fallback guardrails; prefer real telemetry; backtests never throttled; Codex/Claude governors stay |
| 80 GB research disk guard | `research_env.py:48-51` | D | **§34** — lower to measured margin / relocate scratch (see §8) |
| Worker CPU/RAM/disk safety | `terminal_worker.py:168-328` (measured RAM classes, CPU 97/90); tester purge LowWater 60 | A | **keep** unchanged |

---

## 11. Genuinely open OWNER questions

Per §21/§68B, everything already decided in the directive is implemented without re-approval. **No new blocking OWNER decision** arose from any of the 18 audits. Standing OWNER-only gates (not "open questions", already known and unchanged):
- **Sunday DXZ v2 cutover:** add XAGUSD+WS30 to T_Live Market Watch; AutoTrading toggle (`decisions/2026-09-15_owner_freifahrtsschein_scope_1_to_3.md`).
- **Antigravity (agy) OAuth relogin** to clear the 401/`AGY_LOW_QUOTA.flag` (known OWNER action).
- **FTMO paid Challenge purchase / account provisioning / AutoTrading** remain OWNER-only (§64) — not decisions requested now.
- Two pre-existing tensions to *dissolve in Phase E* (not re-ask OWNER): OQ9 sleeve-vs-EA budget (`ftmo_probability_contract.v1.json:39`); relaxing the ROT_SEALED 0.50 correlation cap (carry a dated decision record).

---

## 12. Phase B–H work breakdown (deduplicated, dependency-ordered)

Estimates S (≤½ day) / M (≤2 days) / L (multi-day). "Where auditors contradicted, resolved by runtime" notes appended. Phase A immediate GRÜN items listed first.

### Phase A — immediate GRÜN (factory + hygiene, before/with this snapshot)
- Factory unblock: apply `RAM_RESERVATION_44GB_NOT_WINNABLE` hold to QM5_10025's 6 un-held Q02 rows OR reclassify `heavy_or_unknown_multisymbol` to measured footprint — `tools/strategy_farm/` claim/RAM logic, `drain_window.json` — **S**
- Backlog dispositions: NEWS_CALENDAR_TAINTED 99 (calendar rebind + `enqueue-backtest --append-only-rerun-of`), Q08_DSR_CONTEXT 49 (context regen), Q10_NEWS 95+48 (Claude review), commission/park 325 unassigned agent_tasks — **M**
- Reconcile `portfolio_candidates` 13213/USDJPY + 13301/GDAXI off EVIDENCE_STALE — **S**
- Triage failing scheduled tasks (NewsCalendar 0x1, EvidenceCohortWatch 0x3, Public_Snapshot, MailboxIntake, WorkItemLogPruner); remove `QM_TMP_*` — **S**

### Phase B — OWNER policy implementation (code + doc)
- `book_build_guard.py:31,238-242` <25 refusal → diagnostic (keep OWNER-order + fail-closed on unqualified) + `gate_manifest.v4.json:373-383` drop `qualified_candidates_ge_25` + `tests/test_book_build_guard.py:58,71,91` — **M**
- Mint superseding decision (fold into `decisions/2026-09-15_owner_continuous_book_evolution.md`) — **S**
- `ftmo_probability_contract.v1.json:39` discrete caps → ADVISORY + fix stale source pointer — **S**
- `build_book_dxz.py:208` / `build_book_ftmo.py` `concentration_reject` → warnings + keep a named hard safety cap; §70 test — **M**
- `portfolio_correlation.py:77` / `build_book_ftmo.py:196` hard corr → admit-with-WARN + dependence panel; keep CLUSTER_CORRELATION_UNVERIFIED fail-closed; dated decision — **M**
- Q17 docs `PIPELINE_V5_SUB_GATE_SPEC.md §P10` + `BOOK_CEREMONY_RUNBOOK_2026-09.md:162` → evidence-based (leave QM_News.mqh) — **S**
- Relabel qualified diagnostics: `path_to_25.py`, `mission_control_v2_data.py`, `operator_surfaces.py`; rename `rebaseline_census.py:640-641` key — **M**
- Fix `gate_manifest.v4.json:5` draft_note; reconcile `CLAUDE.md` + `COMPANY_AUDIT_LIVE_SOURCES_2026-05-30.md:135` (LowWater 60, Q00–Q17) — **S**
- HR16: raise `max_parallel` on eligible `agent_router.py` lanes; keep `min_ready_strategy_cards` anti-spam pacer — **S**
- Backfill planner hash-bound reuse Q05/Q09/Q11 (`gate_manifest.v4.json:386-395`) + parallelize Q07 seeds — **M**
- Vault rewrites (Q15, Pipeline Overview, Pipeline Operations Workflow, Gate Manifest v4 Diff, Q17, Q16, Risk Conventions, Current Objective, Hard Rules HR16 annex, Operational Disciplines, Determinism, Research Methodology, _HOME:53-55, START_HERE:21/27/28, AI Spend & Quota Governance) — **L**
- `docs/ops/RULE_EFFECTIVENESS_AUDIT_2026-09.md` (§21, all superseded rules with purpose/benefit/cost/safety/recommendation/rollback) — **M**

### Phase C — Kimi + agent infra operationalization
- Interim: retask `QM_StrategyFarm_ClaudeOrchestration_15min` → `--max-sessions 1` (record in `docs/ops/OPEN_ITEMS_STATUS.md`) — **S**
- Land fix ticket 3e0c8b83 in `run_agent_orchestration_task.py` (per-slot `agent_task_exec:<id>` pid-owned lease + `QM_ASSIGNED_TASK_ID` prompt pin; router `agent_router.py:1535-1561` unchanged) + `tests/test_run_agent_orchestration_fanout.py` — **M**
- `tools/strategy_farm/kimi_quota_fetcher.py` + `config/kimi_quota_fetcher.v1.json` (GET `/usages`, normalize to `D:/QM/reports/state/kimi_quota_state.json`, no token logging) — **M**
- `kimi_governor.py compute_state` read `kimi_quota_state.json`; prefer real ratios when ok; keep 40/200 as runaway floor; wire into `QM_StrategyFarm_KimiGovernor_15min` — **S**
- After smoke: `install_agent_orchestration_scheduled_tasks.ps1 -IncludeKimi` (register `QM_StrategyFarm_KimiOrchestration_15min`, MaxSessions=1) — **S**
- `research_env.py:51/66/65` fix guard (primary: watch C:, floor 20 GB, relocate venv; fallback: D: floor 60); env overrides — **S** *(resolved: prefer research_disk_guard R1 over R2)*
- Correct stale Kimi docs (`KIMI_INTEGRATION_ARCHITECTURE.md §1/§7`, `kimi_adapter.v1.json:88`, `kimi_cli.md §6`) — **S**
- `research_source.py` + `card_intake_prescreen.py:539-548` generalize `source_author` (Fable/multi-agent); keep R4 reject — **S**
- Tests `test_kimi_quota_fetcher.py` — **S**

### Phase D — Mission Control
- D0 (blocks D, belongs to E infra): persist read-models `book_evolution_dxz.json`, `book_evolution_ftmo.json`, `ftmo_challenge_readiness.json`, `research_state.json` (each with `meta{source,source_as_of,staleness}`) — **M**
- `mission_control_v2_data.py`: add loaders + contract keys `book_evolution`/`ftmo_challenge_readiness`/`research_state`; reclassify `path_to_25` as Factory diagnostic — **M**
- `render_cockpit_v2.py`: `_render_book_evolution` + `_render_ftmo_challenge_readiness`; remove `_render_path_to_25` from primary flow — **M**
- `morning_brief.py` replace §3 "WEG ZU 25"; `heartbeat_snapshot.py` Book-Evolution block; rewrite `Claude.md:89-90,29` — **M**
- Fix `QM_StrategyFarm_Cockpit_2min` abort (0x800710E0) — **S**
- Add "terminals-idle-in-drain vs claimable-pending" bottleneck tile; tighten `q08_head_of_line_claim_starvation` health check (FAIL when census 0/h AND ≥N idle in drain) — `render_dashboards.py`, `render_cockpit.py`, 15-min health task — **S**
- Create Mission Control canonical vault page (Book Evolution / FTMO Readiness / Research / Factory §60) — **S**
- Tests `test_mission_control_v2_data.py`, `test_render_cockpit_v2.py` (no "/25" goal headline, missing read-model degrades gracefully) — **S**

### Phase E — Portfolio engine
- New subpackage `tools/strategy_farm/portfolio/recompose/`: `frozen_snapshot.py` (schema `qm.recompose-frozen-inputs/v1`, per-input sha256, reuse `assemble_stream_bundle` + `portfolio_freeze_gate`), `metrics.py` (add **effective_number_of_bets**, explicit **downside_correlation**, holding_time), `dxz_fitness.py`, `ftmo_fitness.py`, `decide.py`, `materiality.py` (§59 seven-factor + economic band) — **L**
- `portfolio/ftmo_next_book_trigger.py` (FTMO analog of `dxz_next_book_trigger.py`) — **M**
- Fix `assemble_stream_bundle.py:8` stale incumbent default (D4) — **S**
- §70 regression test: two runs from one frozen snapshot → byte-identical output — **S**
- Live feed: automated per-sleeve live attribution refresh; live correlation/trade-overlap matrix from `Bases/Darwinex-Live/trades/4000090541/deals_*.dat`; live-vs-book compare keyed to live roster (repoint `book_monitor_state.json`); ingest DXZ D-Score into `reports/state/` — **L**
- Reconcile incumbent-vs-qualified (live 28-manifest overlaps qualified-26 by only 10; per-sleeve KEEP/REPLACE) — **M**

### Phase F — FTMO acceleration
- Refresh + hash-bind Standard FTMO rule snapshot `docs/ops/evidence/2026-09-15_ftmo_official_rules_snapshot.json` (fix trading-symbols 404 + Standard leverage); rebind `config/target_rulepacks/FTMO_2S_100K_STANDARD_V2.json` — **M**
- `docs/ops/FTMO_DEMO_VALIDATION_CONTRACT.md`: freeze ONE intended challenge portfolio + risk + execution policy; §14 material-change semantics — **M**
- `docs/ops/FTMO_CHALLENGE_READINESS.md`: compute FTMO_FITNESS (`challenge_firstpassage.py` + `challenge_two_phase.py` + `fund_score.py` + `ftmo_density_compare.py` vs STANDARD_V2) — **M**
- Unblock v2 census ticket 42a437a4 (merge per RECYCLE) + land 3e0c8b83; bind US500.cash/NATGAS.cash from `ftmo_demo_attach_map.json` (admit 2 of 3 EXCLUDEs) — **M**
- Start §12 two-week demo on a representative intraday-leaning roster; instrument §16 sleeve-level metrics in `ftmo_trial_pulse.py` + collector — **M**
- Fix `FTMO_ON.ps1` account comment (1514165262→1514536732); reconcile AutoTrading note; refresh RUNNING review before 2026-09-30; locate/produce authoritative FTMO builder dry-run (D2) — **S**

### Phase G — Autonomous edge discovery
- `docs/research/AUTONOMOUS_EDGE_DISCOVERY.md` + preregistered experiment; commission first Kimi FTMO-gap campaign H1 (intraday session MR vs swing first-passage), H2 (density is binding FTMO constraint), H3 (failure-mine loser daily-loss clusters); cross-vendor critic ≠ Kimi; mechanization gate before Q00 — **M**
- Extend `research/observe_projector.py` (timeframe, session, holding_class, symbol_class per gate_outcomes row; new `parameter_sensitivity.csv` from OPT_CENSUS) — **M**
- Add per-EA `origin` field to `framework/registry/ea_id_registry.csv` (external_source/internal_discovery/owner_mission) — §49 ROI computable — **M**
- Seed §45 failure-mining on densest clusters (`economic_failures_family_symbol_gate.csv`: trend/momentum & other × EURUSD/GBPUSD/XAUUSD/USDJPY × Q04); study 1,195 ZERO_TRADES separately — **M**

### Phase H — Weekly automation
- `docs/ops/CONTINUOUS_BOOK_EVOLUTION.md` + weekly recomposition contract (Friday cut → Sat analysis → cross-review → Sun recommendation → OWNER handoff) — **M**
- Scheduled Friday-cut → Sunday-recommendation task (deterministic from frozen inputs; §70) — **M**
- Friday evidence cut includes FTMO demo-cycle metrics + FUND_SCORE-vs-floor delta — **S**

### Phase I — completeness/gap follow-up (second directive)
- `tools/strategy_farm/strategy_wiki_sync.py` (build/index/lint), one generated node per canonical id (§4 fields), + `STRATEGY_WIKI_SYNC` Mission Control health key — **L**
- `tools/strategy_farm/lineage_map.py` + `tests/test_lineage_map.py` (behaviour-first J/ρ + rule-hash; §9) — **M**
- Fix `research_dedup_check.py:60` wiki path via shared `tools/strategy_farm/vault_paths.py` (reused by `check_repo_vault_refs.py`) — **S**
- Persist `card_sha256` at approve-time (`strategy_card_v3.py`) so staleness = hash mismatch — **S**
- `QUANTMECHANICA_COMPLETENESS_AND_GAP_AUDIT_2026-09-15.md` — **M**

---

### Contradictions resolved (by runtime evidence)
1. **Qualified count / frontier histogram** — `candidate_universe` (contiguous census: 26 qualified, Q11:2, Q14:26) vs `pipeline_factory_state`/`wiki_sync_tooling` (`by_gate_v4`: Q11:51, Q14:29). Resolved: **26 contiguous is canonical qualified** (both agree `book_guard=26`); `by_gate_v4` numbers are the more-permissive observed reservoir. Followed `candidate_universe` (the §68A task); flagged as drift.
2. **DXZ book size** — `research_universe_whitespace` "55 book pairs" (`dxz23_execution_contracts.json`) vs `dxz_live_book`/`candidate_universe` "24 live sleeves". Resolved: **24 live-deployed sleeves** (`live_book_pulse.json`) is the book; 55 is the broader execution-contract registry. Overruled the "55 book" phrasing.
3. **DXZ v2 risk number** — deploy manifest 11.0% vs profile 9.8013%. Resolved: **cutover 9.8013%** (4 new sleeves at burn-in weight) → **post-burn-in target 11.0%**; both correct for different stages.
4. **v2 chart count** — prose "28 charts" vs profile "29 charts". Resolved: **29 charts = 28 trading + 1 QM_AccountMonitor**.
5. **FTMO demo equity/state** — `ftmo_fitness_candidates` "flat at 100k since 09-04" (stale snapshot) vs `ftmo_demo_state` fresh pulse. Resolved: **current equity 99,811.51** (fresh `ftmo_trial_pulse.json`); the two losing cycles are the historical journal record.
6. **Research disk guard threshold** — `research_disk_guard` R1 (watch C:, floor 20) vs R2 (D:, floor 60) vs `quota`/`rule_inventory` (relocate/env-param). Resolved: **primary R1 (C:, 20 GB, relocate venv), fallback R2 (D:, 60 = purge low-water)**.
7. **portfolio_candidates EVIDENCE_STALE vs live** — `robust_rebuild_census` DB says 13213/13301 stale; T_Live baselines/journal say deployed. Resolved: **live is authoritative** (runtime > DB flag); reconcile the DB.
