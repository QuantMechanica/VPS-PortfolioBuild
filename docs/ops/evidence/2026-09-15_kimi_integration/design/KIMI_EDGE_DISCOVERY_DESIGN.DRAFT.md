# KIMI_EDGE_DISCOVERY_DESIGN.md

**Pre-Q00 Internal Edge Discovery layer — OBSERVE → DISCOVER → HYPOTHESIZE → MECHANIZE → ATTACK → PRE-REGISTER → STRATEGY CARD → Q00–Q17 → LEARN**

- Status: DESIGN (implementation not yet done). Read-only draft, 2026-09-15.
- Authority: `decisions/2026-09-15_owner_kimi_integration_ml_research_r1_internal.md` (OWNER-DEC-KIMI-INTEGRATION-20260915, BINDING); full directive `docs/ops/evidence/2026-09-15_kimi_integration/owner_directive_verbatim.md`.
- Companion docs: `KIMI_INTEGRATION_ARCHITECTURE.md` (adapter/router/quota), `INTERNAL_RESEARCH_SOURCE_CONTRACT.md` (R1 / QM-RESEARCH). This file owns the *research workflow*; the source contract and provider mechanics are cross-referenced, not duplicated.
- Orchestrator (Fable) design decisions this file works within: D1 (Kimi adapter), D2 (Kimi quota governance), D3 (router lane), D4 (chain critic tables), D5 (internal R1 / QM-RESEARCH store), D6 (research package). These are fixed; this document designs the research substance inside them and cites them, and does not reopen them.

---

## 0. Position in the pipeline — no new Q-gate

The Internal Edge Discovery layer is entirely **pre-Q00**. It produces exactly one output that touches the existing pipeline: a normal Strategy Card carrying a durable internal source (`source_type: internal_research`, `source_id: QM-RESEARCH-YYYY-NNNN`). From Q00 onward there is **no special treatment** — directive §17; the deterministic Q00–Q17 pipeline stays the sole judge, and Kimi authorship or ML-assisted discovery never improves a gate score.

Two hard invariants bound this whole layer:

1. **ML lives only offline.** Directive §1.3 / decision #3: ML/statistical methods are permitted as *research instruments*; the EA and its live/backtest decision engine stay ML-free and fully mechanical. Runtime enforcement is already scoped to `.mq5/.mqh` in `framework/scripts/build_check.ps1 Invoke-ForbiddenScan` (audit `cards_r1_research.md` §4a, L888-960) and is untouched by this layer.
2. **The LLM interprets; scripts compute.** Directive §4/§6. Every metric a script can compute is computed deterministically in Python/SQL; Kimi never computes a metric, a p-value, or a correction — it reads prepared datasets + summaries and authors hypotheses and critiques.

The layer never writes a gate verdict, never mutates `farm_state.sqlite`, and adds no second SQLite DB (audit `data_memory.md` §6). All new state is append-only JSONL ledgers + rebuildable read-model projections + in-repo artifacts.

---

## 1. OBSERVE — the evidence inventory

OBSERVE assembles machine-readable datasets from QuantMechanica's own accumulated evidence. It never re-walks the 45,008 gzip evidence trees at runtime (audit `data_memory.md` §7, §2); it reads the normalized layers.

### 1.1 Canonical sources (grain + join keys)

| Source | Grain | Join key | Use | Evidence |
|---|---|---|---|---|
| `work_items_clean` (TEMP view over `work_items`, 149,094 rows) | one backtest/compile/analytic run | `id`; `ea_id`,`symbol`,`phase` | status + INFRA-vs-economic taxonomy | `work_item_clean_view.py:132-163`; audit §1.2 |
| `ea_metrics` (100,110 rows) | one run's headline scalars | `work_item_id` (PK), `ea_id` | net_profit, profit_factor, trades, drawdown_money/pct, sharpe + `detail_json` (folds/seeds/sub-gates) | `ea_metrics.py` docstring L1-25; audit §1.3 — **read this, not the gzip trees** |
| `work_item_transition_ledger` (4,340) | state change | `work_item_id` | verdict/status history | audit §1.5 |
| `work_item_holds` (5,366) | hold on a run | `work_item_id`,`hold_code` | why a run is parked (e.g. `PRESCREEN_SKIPPED`, `Q08_DSR_CONTEXT_UNAVAILABLE`) | audit §1.5 |
| `poison_pill_quarantine` (219) | `(ea_id,symbol,phase)` | ea_id+symbol | repeated INFRA/setup failures | audit §1.5 |
| `q09_news_cells` / `q09_news_tests` | arm×temporal×compliance×seed / test | `work_item_id` | News A/B behaviour | audit §1.6 |
| `portfolio_candidates` (41) | `(ea_id,symbol,q11_work_item_id)` | ea_id+symbol | portfolio state / rejection | audit §1.6 |
| `sources` (118) | research source | `id` | DISCOVER intake feed + provenance | audit §1.6 |
| `framework/registry/ea_id_registry.csv` (583 KB) | idea identity | `ea_id`,`strategy_id`(UUID),`slug` | idea↔EA↔family map | audit §2 |
| DSR cohorts `qm.dsr-cohort/v1` | `(ea_id,symbol,timeframe)` | ea_id/symbol/tf | already carries `search_history`, `research_trial_count`, `effective_trial_count` | `dsr_cohort.py:26,753-768` |
| `evidence_cohort_baseline.json` (9.7 MB) | run | `work_item_id` | forward evidence-survival snapshot | audit §2 |

### 1.2 INFRA vs economic separation (the load-bearing caveat)

Every OBSERVE dataset **must** split on `verdict_taxonomy` (`work_item_clean_view.py:132-163`), never on raw `status`. The taxonomy families:

- `infra` (56,044 rows) — `INFRA_FAIL`; setup/data/host failures. **Never economic evidence.**
- `strategy` (53,752) — gate pass/fail (`PASS*`/`FAIL*`/`ZERO*`/`RETIR*`, `work_item_clean_view.py:151-158`); the real economic outcomes.
- `measurement` / `prescreen_measurement` (19,962 + 350) — DL-089 OPT_CENSUS + prescreen; **deliberately DISJOINT from `strategy`** (`work_item_clean_view.py:147-150`, DL-089 §3). Never fold into economic pass/fail.
- `invalid`, `open`, `artifact`, `build`, `governance`, `review`, `draft_defect`, `unknown` — excluded from economic analysis; 14,418 rows carry NULL taxonomy (legacy/open) and are dropped from economic datasets.

Directive §10 restates this: "Keep INFRA / NO_REPORT / SETUP_DATA errors separate from economic strategy failures." A dataset that conflates them is a defective dataset and OBSERVE must refuse to emit it.

### 1.3 `observe_projector.py` — outputs and manifest

`tools/strategy_farm/research/observe_projector.py` (D6). Opens `farm_state.sqlite` in `mode=ro` (URI, read-only — audit §1) and reads `work_items_clean` + `ea_metrics` + `work_item_holds` + `work_item_transition_ledger` + `poison_pill_quarantine` + `sources`, joined idea→EA via `ea_id_registry.csv`. It emits a **versioned dataset directory** under `D:/QM/reports/research/datasets/<stamp>/` (D6):

```
D:/QM/reports/research/datasets/2026-09-15T18-00-00Z/
  manifest.json            # schema qm.research-dataset/v1
  economic_runs.parquet    # verdict_taxonomy='strategy' only
  infra_runs.parquet       # verdict_taxonomy IN ('infra','invalid')  — kept SEPARATE
  measurement_runs.parquet # OPT_CENSUS / prescreen, disjoint
  idea_family_map.parquet  # ea_id -> strategy_id, slug, family tags
  holds.parquet
```

`manifest.json` fields (deterministic, content-addressed): `schema`, `stamp_utc`, `source_db_path`, `source_db_size_bytes`, `row_counts` per file, `verdict_taxonomy_split` (proves the separation), `column_dictionary`, `sha256` per emitted file, `git_commit` of the projector, `farm_state_snapshot_note` (mtime; the DB is live, so datasets are timestamped snapshots not reproducible-forever — flagged, not hidden). The manifest is the *only* thing later stages hash; a dataset with a missing sha256 is not consumable (fail closed).

Datasets are small columnar files (economic runs ≈ 54k rows × ~15 cols), well under the disk guard (§2.3). **Raw gzip trees are never copied into a dataset** (audit §7).

---

## 2. DISCOVER — ML/statistical exploration (offline)

DISCOVER is the one place ML is allowed (directive §11). Its objective is **not** predictive backtest accuracy; it is to surface *simple, robust, interpretable market relationships that can later be expressed mechanically* (directive §11, §20).

### 2.1 Permitted methods

Directive §11: clustering, dimensionality reduction, exploratory classification, regression, tree-based feature importance, interaction analysis, regime clustering, anomaly detection, conditional-probability modelling, survival/failure clustering, unsupervised pattern discovery, statistical learning. Run offline in Python; results are **evidence**, not a strategy.

### 2.2 The research venv (never the farm Python)

D6 + audit `data_memory.md` §5, §7: the farm Python `...Python311\python.exe` (3.11.9) carries **numpy only** — pandas/scipy/sklearn/statsmodels/duckdb all MISSING, and it is the live MT5 worker runtime. **Never pip-install into it.** Provision a separate uv-managed venv (uv 0.11.7 present):

```
uv venv D:/QM/research/venv
uv pip install --python D:/QM/research/venv pandas duckdb scipy scikit-learn statsmodels pyarrow
```

All DISCOVER code runs under `D:/QM/research/venv`.

### 2.3 CPU / RAM / disk rules (research is subordinate to MT5)

MT5 saturation is the primary throughput metric and backtests are never throttled (CLAUDE.md; audit §7). Research jobs must yield. Concretely (D6 + `terminal_worker.py` latches):

- **CPU:** below-normal OS priority, **max 2 worker processes**, ≤1–2 cores. Refuse to start when sustained fleet load is above the worker pause line — `CPU_MAX_LOAD_PERCENT=97.0` / resume `90.0` (`terminal_worker.py:210-211`); target ≤90% headroom before each batch.
- **RAM:** hold **≥20 GB free** (workers defer claims below `RAM_MIN_FREE_GB=14.0` and only resume at `RAM_RESUME_FREE_GB=20.0`, `terminal_worker.py:168-169`); a batch aborts if free RAM trends toward 14 GB.
- **Disk:** D6 gate — **refuse to start when D: free < 80 GB**. Today D: has only 65.6 GB free (audit §5), below both this 80 GB gate and the worker `DISK_MIN_FREE_GB=40.0` (`terminal_worker.py:146`). **Consequence for the first campaign: DISCOVER cannot run a D:-writing job until the tester-cache purge or a cleanup restores ≥80 GB free.** Datasets/outputs are small JSONL/parquet; prefer C:/G: for any non-trivial intermediate.

A single `research_guard()` in the package checks all three before any batch and logs the refusal reason; this is the deterministic gate, not a judgement call.

### 2.4 How Kimi receives data — paths + summaries, never raw dumps

Directive §10/§4/§6: deterministic prep first. Kimi is handed, via its prompt **file** (D1: prompt file + short argv pointer, Windows cmdline limit):

1. **File paths** to the dataset (`manifest.json` + the parquet/CSV) inside the worktree it is `--add-dir`-scoped to (D1: research creator runs in an isolated worktree/scratch dir).
2. **Deterministic summaries** the projector produced (row counts, group-wise aggregates, feature distributions, the taxonomy split) — so Kimi reasons over compact statistics, not a 100k-row dump.
3. The **hypothesis-family registry** state (§2.5) so Kimi knows what has already been searched.

Kimi never gets the raw gzip evidence, never the live DB. If Kimi's own tooling runs ML it does so inside the scoped dir over the provided dataset; the resulting numbers are re-derived deterministically in Python before they enter an artifact (the LLM's numbers are never the evidence — directive §6).

### 2.5 Hypothesis-family taxonomy (multiple-testing control at the source)

Directive §11/§18: "Track the number and family of hypotheses explored." Every DISCOVER question is registered under a **hypothesis family** before it is run, in the `search_history_ledger.jsonl` (§6.3). A family is the coarse mechanism class, aligned to the existing dedupe vocabulary in `farmctl.strategy_card_fingerprint` (`farmctl.py:4561-4565`: momentum, mean-reversion, breakout, carry, seasonal, volatility, gap, news, fomc, trend, pairs) extended with structural classes (regime-conditioning, session/time-of-day, failure-mode, cross-strategy-redundancy). Families exist so the DSR correction (§6.4) counts *how many bites of the apple* were taken per mechanism, not per winner.

### 2.6 Discovery vs prediction (what counts)

Directive §11:

- **A discovery** (permitted output): *"When condition A + B + C holds, subsequent market behaviour differs materially from baseline"* — conditional, interpretable, mechanizable.
- **A prediction** (NOT an output): *"Model X predicts next return with P=0.612"* — remains research evidence only; it may never become the EA (directive §1.3 invalid progression). A DISCOVER result phrased as a prediction is returned to research for restatement as a conditional relationship before HYPOTHESIZE.

---

## 3. HYPOTHESIZE — Kimi as author (QM-RESEARCH artifact)

When DISCOVER surfaces a candidate edge, Kimi authors an **immutable research-source artifact**. This is the R1 source for any card that follows (directive §12/§14; decision #2). Full contract in `INTERNAL_RESEARCH_SOURCE_CONTRACT.md`; the research-facing shape:

### 3.1 Artifact template — `QM-RESEARCH-YYYY-NNNN`

Durable store (D5), in-repo on C: (audit `cards_r1_research.md` §3):

```
strategy-seeds/sources/QM-RESEARCH-2026-0001/
  source.md          # the research artifact (Kimi-authored)
  research.json      # machine record incl. sha256 of source.md
  critic_receipt.json # cross-vendor critique receipt (§5)
  lineage.json       # version / discovery-vs-validation lineage (§6)
```

`source.md` frontmatter + body must carry every field the directive requires (§12/§14):

| Field | Source |
|---|---|
| `source_id: QM-RESEARCH-2026-0001` | §14 |
| `source_type: internal_research` | §14; new label, `farmctl.VALID_SOURCE_TYPES += 'internal_research'` (D5; currently `farmctl.py:33580-33583`) |
| `source_author: Kimi` | §12 |
| `source_model` (exact Kimi model, e.g. `kimi-code/kimi-for-coding` K2.8) | §12; `kimi_cli.md` §3 |
| `source_artifact` (canonical durable path) + `source_sha256` | §14 |
| creation `timestamp`, originating `task_id` | §12 |
| `research_question` | §12 |
| `source_datasets` (dataset stamp + manifest sha256), `evidence_paths` + hashes | §12 |
| `ml_method` used (if any) | §12 |
| `observations` | §12 |
| `proposed_market_mechanism` (economic/behavioural cause) | §12 |
| `candidate_edge` | §12 |
| `confidence` / `uncertainties` | §12 |
| `likely_confounders` | §12/§15 |
| `related_existing_strategies` (ea_id/strategy_id refs) | §12 |
| `critic_receipt` ref | §12 |
| `hypothesis_lineage` | §12/§16 |
| a `## Research provenance` section (holds the ML-derived narrative) | D5 — exempted from the prescreen ML scan (§7 below) |

The append-only registry `D:/QM/reports/state/research_source_ledger.jsonl` (D5) gives immutability: `{id, created, author, model, task_id, sha256, status: draft|reviewed|preregistered|carded|retired}`; any later edit mints a new version id. The resolver `tools/strategy_farm/research_source.py` (D5) does mint / resolve / verify (`QM-RESEARCH://id` → path + sha check). `source = Kimi` without a resolvable, sha-verified artifact is invalid (decision #2).

### 3.2 Kimi prompt contract

Delivered as a prompt **file** with a short argv pointer (D1). The prompt: (a) states the research question + hypothesis family; (b) points at the dataset paths + summaries (§2.4); (c) requires the output to fill the §3.1 template exactly, in the mechanizable "condition → behaviour differs from baseline" form (§2.6); (d) requires it to name confounders and related existing strategies; (e) forbids it from asserting any metric it did not receive pre-computed (directive §6). Model: default `kimi-code/kimi-for-coding` (K2.8, 1M ctx) for large-context synthesis; `k3-256k`/highspeed for lighter authoring (D1). Creator runs `--auto` in the scoped worktree (`kimi_cli.md` §9).

---

## 4. MECHANIZE — required before any Strategy Card

No ML-discovered hypothesis may enter Q00 while it still depends on a research model (directive §13). MECHANIZE converts the edge into an exact mechanical specification.

### 4.1 Mechanical specification template (all directive §13 fields)

`processes/qm_research_mechanization_template.md` (new). Required sections, each explicit and bounded:

- long entry; short entry; no-trade conditions; exit; stop loss; take profit (if applicable); position sizing (`RISK_FIXED` backtest / `RISK_PERCENT` live — CLAUDE.md Hard Rules); session rules; filters; **parameter ranges** (finite, bounded); required indicators / data; timeframe; symbol applicability (symbols are inputs, never literals — CLAUDE.md 2026-09-06); expected trade frequency; invalidation conditions.

It must also satisfy the existing card charter sections that `card_intake_prescreen.missing_charter_sections` enforces (`card_intake_prescreen.py:379-425`), so the eventual card passes prescreen: `STRUCTURAL_CAUSE`, `PRICE_SIGNATURE`, `PERSISTENCE`, `FALSIFICATION`, `Q08_Q11_RISK`, `FTMO_FIT`. These map 1:1 to the Edge Lab thesis schema (`docs/ops/EDGE_LAB_CHARTER_2026-05-22.md` §"Thesis schema").

### 4.2 The Codex-implementability test

Directive §13 acceptance test: *"Could Codex implement this EA from the Strategy Card without access to the research model?"* If NO → return to research. If YES → proceed. This is the single binding gate of MECHANIZE and it is deterministic in intent: the spec is self-contained iff it never references the dataset, the ML model, or a Kimi lookup.

### 4.3 `mechanization_check.py` rules (deterministic)

`tools/strategy_farm/research/mechanization_check.py` (D6). Pure static checks over the mechanical spec `.md`, no LLM:

1. **All required sections present** (§4.1 list + the six charter sections) — else `MECH_SECTIONS_MISSING:<list>`.
2. **No ML/inference terms in the mechanics sections** — reuse the pattern set from `card_intake_prescreen._affirmative_prohibited_mechanics` (`card_intake_prescreen.py:470-489`), scanning the mechanical sections only (the `## Research provenance` narrative is exempt). Emits `MECH_ML_IN_RULES` on an affirmative hit.
3. **Finite parameter count** — every parameter has a bounded numeric range; unbounded / open-ended params → `MECH_PARAM_UNBOUNDED:<name>`.
4. **Codex-implementability checklist** — deterministic entry, exit, stop, sizing, filter each resolvable to a rule with no external model reference; a dangling reference to the dataset/model → `MECH_MODEL_DEPENDENCY`.
5. **No runtime data feed** beyond native MT5 + the live news filter (CLAUDE.md Hard Rules; live EAs never read the backtest news archive).

A spec that fails any rule is returned to research with the finding list; it does not proceed to ATTACK.

---

## 5. ATTACK — cross-vendor falsification

Before Strategy Card promotion the mechanized hypothesis is attacked by a **non-Kimi critic** (directive §8/§15; decision #7). This runs on the existing `agent_chain` (D4): Kimi is the creator, and `agent_chain.v1.json by_creator_vendor.kimi` lists only non-Kimi critics — `[claude sonnet, codex terra, agy]` (D4); Kimi is never in its own critic table (audit `router_providers.md` §4 risk 7). Critics stay read-only; the adapter verifies via a git status hash before/after that no file under `C:/QM/repo` changed — a critic that wrote is a failed run (D1). Critic prompts are unchanged; the Kimi critic (when critiquing another vendor's creator) gets the same read-only envelope (D4).

### 5.1 Falsification checklist (directive §15)

The critic must explicitly assess: data snooping; leakage; selection bias; symbol bias; time-period bias; regime dependence; transaction costs; trade-count sufficiency; parameter flexibility; multiple testing; **similarity to existing QuantMechanica strategies**; dependence on a single feature or period; simpler null explanations. It must answer the directive's core question: *is this a genuinely distinct mechanical edge, or another expression of something QuantMechanica already trades/tests?* Criticism does not kill a hypothesis by opinion — it creates evidence for Fable's preregistration decision (directive §15).

### 5.2 Critic receipt → source record

The chain writes its receipt (`qm.agent-chain.receipt.v1`, audit `router_providers.md` §6). MECHANIZE/ATTACK copies the receipt into `strategy-seeds/sources/QM-RESEARCH-YYYY-NNNN/critic_receipt.json` and records its sha256 in `research.json`, so the source record carries its own cross-vendor review (directive §12 field `Critic receipt`; decision #2 "cross-vendor review receipt"). No card is minted before the critic receipt exists.

---

## 6. PRE-REGISTER — freeze before validation

Directive §16/§18: before the candidate is tested, freeze the hypothesis so a later holdout result cannot be retrofitted.

### 6.1 Freeze record

`tools/strategy_farm/research/preregister.py` (D6) writes an immutable freeze record (sha256-stamped, appended to `research_source_ledger.jsonl` with `status: preregistered`) capturing directive §16: research hypothesis; exact mechanical translation (sha256 of the spec); allowed parameter ranges; **parameter count**; discovery sample; validation sample; holdout logic; expected behaviour; success criteria; failure criteria; known risks.

### 6.2 Lineage / versioning rule

Directive §16: once holdout results are observed, the hypothesis may not be modified and passed off as the original. Any modification mints a **new lineage version** (`lineage.json` + a new `QM-RESEARCH` version id in the ledger). `strategy_card_fingerprint` (`farmctl.py:4548-4566`) folds `source_id` in, so one child id per idea keeps near-duplicate detection honest (audit `cards_r1_research.md` §5 risk 3).

### 6.3 Holdout discipline + `search_history_ledger.jsonl`

`D:/QM/reports/research/search_history_ledger.jsonl` (D6), `schema: qm.research-search-history/v1`: one line per search/experiment — hypothesis family, dataset id, period, instruments, feature families, parameter-space size, holdout id, outcome (directive §18 list). It records: number of hypotheses attempted, families, datasets/periods/instruments/feature-families searched, parameter spaces, reused holdouts, rejected hypotheses, modified/recycled hypotheses. Kimi never runs unbounded searches over the full history reporting only the winner (directive §18); untouched validation data is preserved where practical, and a holdout is not re-mined.

### 6.4 Coupling to DSR `research_trial_count`

The layer's trial accounting feeds the **existing** multiple-testing machinery rather than duplicating it. `dsr_cohort.py` already defines `research_trial_count` / `effective_trial_count` / a `search_history` block (`dsr_cohort.py:753-768`) inside `qm.dsr-cohort/v1`. The critic gap the audit named — "no auditor connected Kimi's hypothesis volume to DSR multiple-testing correction; uncounted trials silently inflate survivorship" (audit `critic.md` §7) — is closed here: `search_history_ledger.jsonl` contributes its per-family attempt count as `research_trial_count` when a sealed cohort is assembled for a QM-RESEARCH-derived candidate, so the deflated Sharpe reflects how many bites the *research search* took, not just the DL-089 census count.

---

## 7. STRATEGY CARD handoff — no special treatment

Once a hypothesis has valid internal R1 provenance, a mechanical spec, a cross-vendor critic receipt, and a preregistration, it becomes a normal Strategy Card (directive §17). The card cites the research source in frontmatter (audit `cards_r1_research.md` §2a):

```
source_id: QM-RESEARCH-2026-0001
source_type: internal_research
source_author: Kimi
source_uri: QM-RESEARCH://2026-0001
source_sha256: <hex of source.md>
```

R1 already passes on any non-empty `source_id` — `_card_r1_build_ready` returns `bool(str(fm.get("source_id")...).strip())` (`farmctl.py:4229-4237`) and approve-card's strict pass fields are R2/R3/R4 only, R1 excluded (`farmctl.py:4219,4464-4471`). The **one required code change** so an internal-research card is not falsely rejected: scope `card_intake_prescreen._affirmative_prohibited_mechanics` (`card_intake_prescreen.py:464-489`) so its ML text-scan skips the `## Research provenance` section — today it scans the whole card body and would emit `PROHIBITED_MECHANICS:ML` for an honest ML-provenance sentence (audit `critic.md` §5, `cards_r1_research.md` §2b). External cards are unchanged (audit `cards_r1_research.md` §2). From Q00 the card runs the identical Q00–Q17 path; Kimi authorship confers no advantage (directive §17).

---

## 8. LEARN — experiment memory

Directive §19: make both success and failure queryable, built additively on the existing SQLite/report architecture — no manually maintained duplicate research universe.

### 8.1 `experiment_memory_ledger.jsonl` + projector

`D:/QM/reports/state/experiment_memory_ledger.jsonl` (audit `data_memory.md` §6.1), `schema: qm.experiment_memory/v1`: `{schema, ts_utc, strategy_id, ea_id, symbol, timeframe, phase, hypothesis, verdict, verdict_taxonomy, reason, evidence_path, work_item_id, search_history_ref}`. It mirrors the proven `tester_memory_ledger.jsonl` convention.

The read-model `tools/strategy_farm/research/experiment_memory_projector.py` (modeled on `ea_metrics.py`) emits a versioned `D:/QM/reports/state/idea_outcome_projection.json` (audit §6.2) by SELECTing from `work_items_clean` + `ea_metrics` + `work_item_holds` + `work_item_transition_ledger` + `poison_pill_quarantine`, joined idea→EA via `ea_id_registry.csv`. Pure derived, rebuildable.

### 8.2 The §19 questions, each resolving to evidence

| Directive §19 question | Answered from | Evidence anchor |
|---|---|---|
| Which ideas repeatedly failed, and why? | `strategy`-taxonomy FAIL runs grouped by `strategy_id`, with `reason` | `ea_metrics` + `work_item_clean_view.py:151-158` |
| Which families are redundant / which discoveries are duplicates? | `strategy_card_fingerprint` clusters + correlation artifacts | `farmctl.py:4548-4566`; `portfolio/correlation_dev.json` |
| Which regimes favour which mechanisms? | regime-conditioned outcome slices from `detail_json` | `ea_metrics.detail_json` |
| Which features/filters add no / marginal value? | pattern-filter (DL-089) census + News A/B deltas | OPT_CENSUS rows; `q09_news_tests` |
| Which symbol families respond similarly? | symbol-grouped economic outcome vectors | `ea_metrics` by symbol |
| Which strategies fail only on economics? | `verdict=FAIL`/`ZERO_TRADES`, taxonomy=`strategy`, healthy risk metrics | `work_items_clean` + `ea_metrics` |
| Which are robust but too inactive? | good risk metrics but trades/yr below the Q02 floor (≥5/yr, `OPERATING_RULES_2026-07-03.md`) | `ea_metrics.trades` |
| Which discoveries share a search family? | `search_history_ledger` family tags | §6.3 |

PASS/FAIL outcomes flow back automatically: each terminal gate verdict already lands in `work_item_transition_ledger`; the projector picks it up on its next rebuild and the experiment-memory ledger is appended when a QM-RESEARCH-lineage run reaches a terminal verdict, keyed by `search_history_ref` back to the originating search. Each conclusion resolves to a `work_item_id`/`evidence_path` (directive §19: "Each conclusion must resolve back to evidence").

---

## 9. Anti-data-snooping controls (directive §18)

The layer materially increases multiple-testing risk; the defence is deterministic and in Python (directive §18 — "If advanced statistical correction can be done deterministically, implement it in Python rather than asking an LLM to estimate whether overfitting looks bad"):

1. **Trial accounting is mandatory and pre-committed.** Every DISCOVER question is logged to `search_history_ledger.jsonl` *before* it runs (§6.3); the winner-only report pattern is structurally impossible because attempts are counted, not just successes.
2. **DSR deflation consumes the real trial count.** `research_trial_count` (`dsr_cohort.py:753`) is fed the per-family attempt count (§6.4), so the deflated Sharpe reflects the search breadth.
3. **Holdout preservation + preregistration.** Discovery sample and validation sample are frozen at PRE-REGISTER (§6.1); a reused holdout is flagged in the ledger and the candidate is down-weighted.
4. **Lineage on modification.** A post-holdout edit is a new version (§6.2), never a silent rewrite.
5. **Discovery ≠ prediction.** A prediction-shaped result cannot proceed (§2.6), removing the "tune a predictor until it backtests well" path.
6. **Cross-vendor ATTACK** independently scores selection bias / multiple testing / similarity-to-existing (§5.1).

Deterministic correction functions (Deflated Sharpe / Benjamini-Hochberg FDR across a family's attempt count) live in the research venv's `research/stats_corrections.py`, computed in Python — never estimated by an LLM.

---

## 10. Research objective metrics — how each is measured

Directive §9/§20: optimise for quality, not card count. Each objective is given a *measured* proxy, computed deterministically:

| Objective | Measured as | Source |
|---|---|---|
| **Novelty** | 1 − max cosine/overlap of the card fingerprint against all existing fingerprints; low `strategy_card_fingerprint` collision | `farmctl.py:4548-4566` |
| **Independence** | max abs. return correlation of the mechanized variant vs existing book members; lower = better | `portfolio/correlation_dev.json` |
| **Falsifiability** | presence + specificity of the `FALSIFICATION` section and a concrete kill test (binary + critic score) | `card_intake_prescreen.py:408-409`; §5.1 |
| **Robustness** | multi-seed dispersion + walk-forward stability + stress outcome from the DSR cohort / OPT_CENSUS | `dsr_cohort.py`; OPT_CENSUS |
| **Mechanizability** | `mechanization_check.py` PASS with finite bounded parameter count (binary + param count) | §4.3 |
| **Portfolio usefulness** | marginal contribution to portfolio-candidate risk-adjusted return after correlation | `portfolio_candidates`; correlation artifact |
| **Reproducibility** | dataset manifest sha256 chain resolves + `research_source.py verify` passes + preregistration freeze intact | §1.3, §3.1, §6.1 |

These are recorded per QM-RESEARCH id in `research.json` so a month's research can be judged on the seven axes, not on strategy count (directive §20: "5 genuinely independent hypotheses > 500 RSI/MA/breakout variations").

---

## 11. First concrete research campaign proposal

Sized to the CPU/disk rules (§2.3) and answerable **now** from existing evidence with no gzip re-walk.

- **OBSERVE dataset:** `observe_projector.py` emits `economic_runs.parquet` = `verdict_taxonomy='strategy'` runs (≈53,752 rows) at Q02/Q04, with columns `ea_id, strategy_id, symbol, timeframe, verdict, trades, profit_factor, drawdown_pct, sharpe, net_profit`, plus per-year consistency extracted from `ea_metrics.detail_json`, joined to family tags via `ea_id_registry.csv`. Single pandas job, fits in RAM, output a few MB.
- **DISCOVER question (family: `failure-mode` / `robust-but-inactive`):** *Among strategy-taxonomy backtests, is there a cluster of `(ea_id, symbol)` candidates with healthy risk metrics (profit_factor > 1, drawdown_pct within the FTMO 10% box, positive sharpe) that are killed **only** by insufficient activity — trades/yr below the Q02 frequency floor of ≥5 (`OPERATING_RULES_2026-07-03.md`)?* Method: k-means / DBSCAN over the standardized feature vector, isolating the "robust but inactive" cluster (directive §19 explicit question). 
- **Why answerable now:** every input is in `ea_metrics` + `work_items_clean`; no trade-level gzip needed. This directly answers directive §19's "Which strategies are robust but too inactive?" and feeds a mechanizable hypothesis: a bounded activity-relaxation (e.g. a widened but finite entry-filter range) that could revive a robust engine — a genuinely mechanical, finite-parameter edge, not a predictor.
- **HYPOTHESIZE output:** if a coherent cluster exists, Kimi authors `QM-RESEARCH-2026-0001` proposing the mechanical relaxation with its economic rationale (why the engine is sound but under-triggered), confounders (survivorship in the census; symbol concentration), and related existing strategies.
- **Disk caveat (blocking today):** D: is at 65.6 GB free, below the 80 GB DISCOVER gate (§2.3); the campaign's D:-writing steps must wait for the tester-cache purge to restore ≥80 GB, or write the dataset to C:/G:. `research_guard()` enforces this — the campaign refuses to start rather than contending with backtests.

---

## 12. What this layer never does

No gate-threshold change, no T_Live/AutoTrading/deployment/live-book change, no verdict write, no evidence deletion, no second SQLite DB, no ML in an EA, no unbounded holdout mining, no LLM-computed metric, no card without a resolvable sha-verified source (directive §5/§23; decision #5). Every artifact is append-only or rebuildable; every step is reversible by clearing a flag / deleting a derived projection / not installing a scheduled task.
