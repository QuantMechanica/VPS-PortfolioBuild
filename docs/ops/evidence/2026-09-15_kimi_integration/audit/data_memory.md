# Pre-Q00 OBSERVE/DISCOVER Evidence Inventory & Experiment-Memory Audit
Read-only audit, 2026-09-15. All facts carry evidence (path+lines, SQL+result, or command+output). Truth precedence: runtime/SQLite > repo contracts > Company Reference.

---
## 1. farm_state.sqlite — the authority

- File: `D:/QM/strategy_farm/state/farm_state.sqlite` = **1,266,081,792 bytes (1.26 GB)**. Opened `file:...?mode=ro` (URI, read-only). 37 tables + 2 views.

### 1.1 Full table/view row counts
```
agent_registry 4                              agent_task_transition_ledger 69
agent_tasks 2307                              build_task_reconciliation_ledger 2
candidate_qualifications 0                    claim_class_ledger 64
ea_metrics 100110                             event_dedupe_state 23
events 686209                                 factory_runtime_activation_consumptions 1
factory_runtime_activation_consumptions_v2 35 gate_contract_activations 2
gate_contract_cutover_log 28                  gate_contract_provenance_repairs 3
ingest_phase_aggregate_ledger 23             news_calendar_bundle_files 2
news_calendar_bundles 1                       parent_task_transition_ledger 486
poison_pill_quarantine 219                    portfolio_candidates 41
q09_news_arms 142                             q09_news_cell_occurrences 2450
q09_news_cells 1937                           q09_news_migration_runs 0
q09_news_schema_meta 1                        q09_news_tests 187
router_writer_contract 1                      sources 118
spawn_leases 40                               sqlite_sequence 7
tasks 8949                                    work_item_contracts 0
work_item_dependencies 376                    work_item_holds 5366
work_item_supersedes 1720                     work_item_transition_ledger 4340
work_items 149094
VIEWS: portfolio_candidates_eligible 0        q09_news_cells_by_work_item 2469
```

### 1.2 Where verdicts / phases / windows / symbols / ea_id / failure classes live
**`work_items` (149,094)** is the central per-run record. `PRAGMA table_info`:
`id(PK) kind phase ea_id symbol setfile_path status verdict attempt_count parent_task_id evidence_path claimed_by payload_json created_at updated_at verdict_taxonomy_stored clean_status_stored gate_contract_version ex5_sha256 setfile_sha256 mq5_sha256 include_closure_sha256 build_id data_window_start data_window_end news_calendar_sha256 verdict_taxonomy sh3_enforced`
- **kind**: backtest 147651, compile 1058, analytic 198, disposition 163, ...
- **phase** (gate + research phases): `Q02 76125, OPT_CENSUS 34342, Q04 18854, Q03 13297, Q05 1312, COMPILE_EA 1057, Q08 951, Q07 723, Q06 661, P2 446, Q09 337, Q10_NEWS 322, Q09_NEWS 232, Q09_PORTFOLIO 139, Q12 111, Q14 53, Q10 41, Q13 35, Q11 33, Q00 7, WINDOW_SWEEP_OWNER 3, Q15 1`
- **symbol** (always `.DWX` custom name in factory): XAUUSD 20102, EURUSD 17561, GBPUSD 14901, USDJPY 14095, NDX 13034, XTIUSD 10136, GDAXI 7382, SP500 6154, WS30 6118, ... (`''` 1057 = compile rows).
- **ea_id**: 3,454 distinct.
- **data window**: `data_window_start` / `data_window_end` (e.g. `2015.01.01`→`2024.12.31` on 22,701 rows; per-year splits like `2019.01.01`→`2019.12.31`).
- **timestamps**: `created_at` / `updated_at` (ISO-8601 UTC). Range `2026-05-23` → `2026-09-15`.
- **evidence_path**: absolute path to the run's `summary.json(.gz)` under `D:/QM/reports/work_items/<wid>/...`.

**INFRA vs economic failure class = `verdict_taxonomy`** (the single most important caveat column):
```
infra 56044 | strategy 53752 | measurement 19962 | NULL 14418 | invalid 2001
open 1277 | artifact 617 | prescreen_measurement 350 | build 203 | governance 166
review 145 | unknown 110 | draft_defect 49
```
Raw **verdict** (economic/gate outcome): `INFRA_FAIL 55882, PASS 27468, FAIL 23327, MEASURED 19967, SKIPPED_EXCLUDED 6219, SKIPPED_PRESCREEN 5240, INVALID 2270, ZERO_TRADES 1250, COMPILE_OK 629, PASS_SOFT 420, PRESCREEN_MEASURED 350, COMPILE_FAIL 306, ... RETIRE 154, FAIL_PORTFOLIO 85, KEEP_INCUMBENT 33`.
**status**: done 96032, failed 49229, pending 3830, active 3.

**Canonical classifier** — `tools/strategy_farm/work_item_clean_view.py`:
- `verdict_taxonomy(status, verdict)` (lines 132-158): `INFRA_FAIL`→`infra` (139-140); `MEASURED`/prescreen→`measurement` (146-150, *deliberately DISJOINT from `strategy`* per DL-089 §3, lines 64-68); gate pass/fail→`strategy` (158); open statuses→`open`.
- `TERMINAL_STATUS_BY_TAXONOMY` (58-69): infra/invalid→`failed`, strategy→`done`, measurement→`done`.
- Installed as a **read-only TEMP view `work_items_clean`** consumed by Mission Control (MNT-016 taxonomy).

### 1.3 Normalized metric projection — `ea_metrics` (100,110)
`PRAGMA`: `work_item_id(PK) ea_id phase symbol verdict status net_profit profit_factor trades drawdown_money drawdown_pct sharpe detail_json source evidence_path evidence_mtime extracted_at is_ablation parent_work_item_id`. Built by `tools/strategy_farm/ea_metrics.py` (docstring lines 1-25): reads every `work_items.evidence_path` **once**, normalizes headline scalars, keeps phase-specific structure (folds/seeds/sub-gates/portfolio) in `detail_json`. Phase coverage mirrors work_items (OPT_CENSUS 31787, Q02 31270, Q04 18357, ...). **This is the join-friendly numeric layer — read this, not the gzip trees.**

### 1.4 opt_census / winsweep / window-sweep storage
- **OPT_CENSUS** = DL-089 parameter-sweep census, stored as `work_items(phase='OPT_CENSUS')` (34,342) + `ea_metrics` (31,787). Each row's `payload_json` carries `cell_key` (e.g. `DL089_QM5_41097_USDJPY_DWX_2019_2025:2019:baseline`), `arm`, `boost_authority`. Program-level artifacts under `D:/QM/strategy_farm/artifacts/opt_census/<program>/`: `ledger.json` (all cells: arm, cell_key, direction, from/to_date, predicate_id, setfile_path, work_item_id, year), `q12_selection_receipt.json` (cell_evidence w/ evidence_path+sha256+verdict), `runner_registration.json`.
- **WINDOW_SWEEP_OWNER** (3 rows) are *program declarations* only — `verdict=DECLARED`, `evidence_path=EVIDENCE_UNAVAILABLE`, `payload_json` has `program_id=WINSWEEP_...`, `owner_contract=qm.window-sweep.queue-owner/v1`. The actual per-cell measurements are OPT_CENSUS/backtest rows under `WINSWEEP_*` cell_keys, surfaced as CSV (see §2).

### 1.5 Failure/verdict history & quarantine memory
- `work_item_transition_ledger` (4,340): `seq, ts, work_item_id, action, from_status, to_status, from_verdict, to_verdict, reason, run_id, detail_json` — full state-change history.
- `work_item_holds` (5,366): `work_item_id, hold_code, reason, active, ...` (e.g. `PRESCREEN_SKIPPED` 2555, `RAM_RESERVATION_44GB_NOT_WINNABLE_20260914`, `NEWS_CALENDAR_TAINTED` 99, `Q08_DSR_CONTEXT_UNAVAILABLE`).
- `poison_pill_quarantine` (219): PK `(ea_id, symbol, phase)`, `verdict_reason` (e.g. `summary_missing_retries_exhausted` 185, `ACTIVE_TIMEOUT`, `run_smoke_fail:ONINIT_FAILED;INCOMPLETE_RUNS`), `consecutive_failures`, `successes_ever`, `evidence_path`.
- `claim_class_ledger` (64), `events` (686,209 generic event log: `ts, entity_type, entity_id, event, detail_json`).

### 1.6 News A/B, portfolio, qualification, sources
- News: `q09_news_cells` (1,937; grain PK `work_item_id x arm x temporal_mode x compliance_mode x seed`, with selection/holdout/full metrics_json), `q09_news_tests` (187; selection/holdout windows, chosen_temporal/compliance, verdict), `q09_news_arms` (142), `q09_news_cell_occurrences` (2,450).
- Portfolio: `portfolio_candidates` (41): PK `(ea_id, symbol, q11_work_item_id)`, state ∈ {Q12_REVIEW_READY 24, EVIDENCE_STALE 9, RETIRED 6, DUPLICATE_SUPERSEDED 2}; view `portfolio_candidates_eligible` = 0.
- `candidate_qualifications` (schema present, **0 rows now**): ties `q08/q09_news/q09_portfolio/q10_work_item_id` + evidence SHAs per `(ea_id, symbol)` — the per-candidate qualification record.
- `sources` (118) — **research provenance for a DISCOVER layer**: `id, priority, lane, source_type, uri, title, status, notes_path, assigned_worker`; status done 96 / pending 13 / blocked 9.
- Router: `agent_tasks` (2,307) state machine (`build_ea`, `review_ea`, `research_strategy`, `ops_issue`, `triage_failure`, `q02_infra_repair`); legacy `tasks` (8,949).

---
## 2. Filesystem evidence families (D:/QM/reports, D:/QM/strategy_farm/artifacts, C:/QM/repo/artifacts)

| Family | Example path | Size | Format | Grain / join key |
|---|---|---|---|---|
| Per-work-item gate evidence | `D:/QM/reports/work_items/000240bb-.../QM5_20072/20260731_062935/summary.json.gz` (+ `raw/run_01/report.htm.gz`, `tester.ini`) | 45,008 dirs (tree size **UNKNOWN** — du timed out; dominant D: consumer) | **gzipped JSON** (schema `run_smoke/v2`, has `reason_classes`) + **gzipped HTML** report | keyed by `work_item_id` = `work_items.evidence_path` |
| tester_memory_ledger | `D:/QM/reports/state/tester_memory_ledger.jsonl` | 11 MB / 19,077 lines | **append-only JSONL** (`schema:qm.tester_memory_ledger/v1`) | ea_id, `lookup_key`=`class\|TF\|kind`, phase, symbol, RAM/runtime metrics |
| tester_memory rollup | `D:/QM/reports/state/tester_memory_expectations.json` | 143 KB | JSON | per `lookup_key` p95/max GB |
| opt_census (DL-089) | `D:/QM/strategy_farm/artifacts/opt_census/DL089_QM5_10145_XAUUSD_DWX_2019_2025/ledger.json` (+`q12_selection_receipt.json`) | **284 MB** dir | JSON | `cell_key`, `work_item_id` |
| winsweep programs | `D:/QM/reports/research/WINSWEEP_QM5_41398_USDJPY_DWX_2019_2025/` | in 675 MB `reports/research` | JSON | program_id, cell_key |
| window-sweep surface | `C:/QM/repo/docs/ops/evidence/2026-09-09_window_sweep_surface.csv` (+ `_stage_b_surface.csv/.json`, `_plan/_dry_run/_verification.json`) | KBs | **CSV** + JSON | `cell_key, work_item_id, start,length,exit, year, verdict, trades, entry_days, net_native, maxdd, score, native_report+sha256, summary+sha256, window_admissible` |
| evidence_cohort_baseline | `C:/QM/repo/artifacts/evidence_cohort_baseline.json` | 9.7 MB | JSON (`qm.evidence-cohort-baseline/v1`) | keyed by `work_item_id`; forward evidence-survival snapshot |
| DSR cohorts (multi-seed/trial) | `D:/QM/strategy_farm/artifacts/dsr_cohorts/QM5_10290_XAUUSD_DWX_D1/` | per (EA,sym,TF) | JSON (`qm.dsr-cohort/v1`) | ea_id/symbol/timeframe; **has `search_history` + trial_count fields** |
| portfolio / correlation | `D:/QM/strategy_farm/artifacts/portfolio/correlation_dev.json`, `book_*` | dir | JSON | ea_id/symbol |
| DL-089 census plan (doc) | `docs/research/PATTERN_FILTER_WF_OPT_PLAN_V3_2026-08-21.md` | doc | md | sealed decisions |
| idea↔EA registry | `framework/registry/ea_id_registry.csv` | 583 KB | CSV | `ea_id, slug, strategy_id(UUID), status, retired_reason, retired_evidence` |
| reports/state (all read-models) | `D:/QM/reports/state/` (incl. `mission_control_v2_preview.json`) | **1,035 MB** dir | JSON/JSONL | — |

Note: German-locale MT5 report exports can be UTF-16; the gzipped `summary.json` is UTF-8 JSON.

---
## 3. Join graph
```
ea_id_registry.csv (strategy_id UUID = idea identity, slug)
        │  ea_id
        ▼
   work_items ──id──► work_item_transition_ledger / work_item_holds / work_item_dependencies / work_item_supersedes
     │  │  │          poison_pill_quarantine (ea_id+symbol+phase)
     │  │  └─ work_item_id ─► ea_metrics (net/PF/trades/dd/sharpe + detail_json)
     │  │                     evidence_cohort_baseline (survival)
     │  │                     winsweep surface CSV (cell_key + evidence sha)
     │  └─ evidence_path ─► D:/QM/reports/work_items/<wid>/.../summary.json(.gz) + report.htm.gz
     │  └─ payload_json.cell_key ◄──► opt_census/<program>/ledger.json.cells[].cell_key
     └─ parent_task_id ─► agent_tasks.id (build/research idea task)

candidate_qualifications (ea_id+symbol) ─► q08 / q09_news / q09_portfolio / q10 work_item_ids
q09_news_tests.work_item_id ─► q09_news_cells (arm×temporal×compliance×seed)
work_items_clean TEMP view = canonical status/taxonomy projection of work_items
```
**INFRA vs economic caveat:** always split on `verdict_taxonomy` (or read `work_items_clean`). `measurement`/`prescreen_measurement` (OPT_CENSUS) is DISJOINT from `strategy` — never fold it into gate_pass/economic_fail. 14,418 rows have NULL taxonomy (open/legacy).

---
## 4. Existing read-models that already answer "which ideas failed and why"
- `tools/strategy_farm/ea_metrics.py` → `ea_metrics` table (normalized per-run metrics; "which survived / with what numbers"). CLI: `ea_metrics.py show --ea QM5_xxxx`.
- `tools/strategy_farm/work_item_clean_view.py` → `work_items_clean` TEMP view (the INFRA-vs-economic "why" separator).
- `tools/strategy_farm/mission_control_v2_data.py` → `D:/QM/reports/state/mission_control_v2_preview.json` (`qm.mission_control.v2`; read-only; funnel/queue/terminals/holds from work_items_clean; carries staleness/degraded_reason).
- `tools/strategy_farm/render_cockpit.py` → `cockpit.html` (funnel/throughput/health).
- `tools/strategy_farm/measure_archive_matrix_hash_coverage.py` (strategy archive matrix coverage).
- **GAP:** no idea-grain, pre-Q00 "experiment memory" / "search-history" ledger exists. Closest precedents: the `search_history`/`research_trial_count`/`effective_trial_count` fields already defined in `qm.dsr-cohort/v1` (per sealed candidate), and the resource-grain `tester_memory_ledger.jsonl`.

---
## 5. Python research environment & resource constraints
Farm python `C:/Users/Administrator/AppData/Local/Programs/Python/Python311/python.exe` = **3.11.9**. Imports:
```
numpy 2.4.6   ✓        pandas      MISSING   scipy    MISSING   sklearn  MISSING
statsmodels MISSING    lightgbm    MISSING   xgboost  MISSING   pyarrow  MISSING
polars      MISSING    duckdb      MISSING   matplotlib MISSING
sqlite3 3.45.1 ✓
```
Other installed (pip list): `uv 0.11.7` ✓ (isolated-venv path), `metatrader5 5.0.5735`, `openpyxl 3.1.5`, `beautifulsoup4 4.15.0`, `playwright 1.61.0`, `pymupdf/pypdf`, `yt-dlp`, `requests`, `pytest 9.1.1`.

**Resources:** RAM 63.1 GB total / **50.3 GB free**; D: **65.6 GB free** of ~953 GB (below the 150 GB tester-cache-purge no-op line ⇒ purge active); C: 89.5 GB free; G: 85 GB free.

**Worker self-throttle (research must yield to these)** — `tools/strategy_farm/terminal_worker.py`:
- CPU: `CPU_MAX_LOAD_PERCENT=97.0` / `CPU_RESUME_LOAD_PERCENT=90.0` (lines 210-211); hysteresis latch, emits `cpu_high_pause`, sleeps `CPU_GUARD_SLEEP_SECONDS + jitter` (13203-13215).
- RAM: `RAM_MIN_FREE_GB=14.0` / `RAM_RESUME_FREE_GB=20.0` (168-169); `MULTISYMBOL_RAM_MIN_FREE_GB=12` (268).
- Disk: `DISK_MIN_FREE_GB=40.0` (146); Commit: `COMMIT_MIN_FREE_GB=24.0` (234).
- Prestage claims also gate on `config.max_cpu_percent` (7465). **Backtests are never throttled** (quota governor) and must win contention.

---
## 6. Additive extension points (no new database)
1. **New append-only ledger** `D:/QM/reports/state/experiment_memory_ledger.jsonl`, `schema:"qm.experiment_memory/v1"`, one line per idea/experiment observation: `{schema, ts_utc, strategy_id, ea_id, symbol, timeframe, phase, hypothesis, verdict, verdict_taxonomy, reason, evidence_path, work_item_id, search_history_ref}`. Directly mirrors the proven `tester_memory_ledger.jsonl` convention.
2. **New read-only projector** (modeled on `ea_metrics.py`) emitting `D:/QM/reports/state/idea_outcome_projection.json` (versioned): SELECT from `work_items_clean` + `ea_metrics` + `work_item_holds` + `work_item_transition_ledger` + `poison_pill_quarantine`, joined idea→ea via `ea_id_registry.csv`. Pure derived, rebuildable.
3. **Reuse `qm.dsr-cohort/v1.search_history`** as the canonical search-history/trial-count shape; reference sealed cohorts rather than duplicating trial accounting.
4. If OBSERVE/DISCOVER runs must be recorded as farm work, use a **new non-gate `work_items.phase` token with measurement taxonomy** (the way OPT_CENSUS/WINDOW_SWEEP_OWNER already sit beside the Qxx gates) so they never pollute the gate funnel.
5. Feed the DISCOVER layer from the existing `sources` table + the throttled `research_strategy` router lane; keep the "<5 ready cards" research throttle.
**Do NOT** create a second sqlite DB or mutate `farm_state.sqlite`.

---
## 7. CPU/RAM budget rule for research jobs
Research runs offline and **subordinate to MT5 workers** (MT5 saturation is the primary throughput metric; backtests are never throttled):
- **CPU:** keep sustained load below the worker resume line (**≤90%**); pin research to ≤1-2 cores, low OS priority, and check `_cpu_load_percent`-equivalent before each batch.
- **RAM:** hold **≥20 GB free** (workers defer claims below 14 and only resume at 20); a research process should reserve a small budget and abort/pause a batch if free RAM drops toward 14 GB.
- **Disk:** respect **DISK_MIN_FREE_GB=40** on D: — with only 65.6 GB free today, write research outputs as small JSONL/parquet, ideally to C:/G:, never large intermediates on D:.
- **Dependencies:** build pandas/duckdb/scipy in a **uv-managed venv** (uv 0.11.7 present) — never pip-install into Python311 (the MT5 worker runtime).
- **I/O:** read `farm_state.sqlite` in `mode=ro` + `ea_metrics` + the JSONL ledgers; do **not** re-walk the 45,008 gzip evidence trees at runtime.
