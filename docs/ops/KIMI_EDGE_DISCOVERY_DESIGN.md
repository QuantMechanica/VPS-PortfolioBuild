# KIMI_EDGE_DISCOVERY_DESIGN.md

**Pre-Q00 Internal Edge Discovery layer — OBSERVE → DISCOVER → HYPOTHESIZE → MECHANIZE → ATTACK → PRE-REGISTER → STRATEGY CARD → Q00–Q17 → LEARN**

- Status: **FINAL v1 (2026-09-15)**. Design document (implementation not yet done). No code is changed by this file.
- Authority: `decisions/2026-09-15_owner_kimi_integration_ml_research_r1_internal.md` (OWNER-DEC-KIMI-INTEGRATION-20260915, BINDING); full directive `docs/ops/evidence/2026-09-15_kimi_integration/owner_directive_verbatim.md`.
- Companion docs: `KIMI_INTEGRATION_ARCHITECTURE.md` (adapter/router/quota/critic mechanics), `INTERNAL_RESEARCH_SOURCE_CONTRACT.md` (R1 / QM-RESEARCH source contract). This file owns the *research workflow*; the source contract and provider mechanics are cross-referenced, not duplicated.
- Orchestrator (Fable) design decisions this file works within: D1 (Kimi adapter), D2 (Kimi quota governance), D3 (router lane), D4 (chain critic tables), D5 (internal R1 / QM-RESEARCH store), D6 (research package). These are fixed; this document designs the research substance inside them and cites them, and does not reopen them.
- Binding orchestrator resolutions applied here (R-A … R-I) are the resolution of the adversarial review; each is cited at the point of use and summarised in the **Review disposition** appendix.

---

## 0. Position in the pipeline — no new Q-gate

The Internal Edge Discovery layer is entirely **pre-Q00**. It produces exactly one output that touches the existing pipeline: a normal Strategy Card carrying a durable internal source (`source_type: internal_research`, `source_id: QM-RESEARCH-YYYY-NNNN`). From Q00 onward there is **no special treatment** — directive §17; the deterministic Q00–Q17 pipeline stays the sole judge, and Kimi authorship or ML-assisted discovery never improves a gate score.

Three hard invariants bound this whole layer:

1. **ML lives only offline.** Directive §1.3 / decision #3: ML/statistical methods are permitted as *research instruments*; the EA and its live/backtest decision engine stay ML-free and fully mechanical. Runtime enforcement is already scoped to `.mq5/.mqh` in `framework/scripts/build_check.ps1 Invoke-ForbiddenScan` (audit `cards_r1_research.md` §4a, L888-960) and is untouched by this layer.
2. **The LLM interprets; scripts compute.** Directive §4/§6. Every metric a script can compute is computed deterministically in Python/SQL; Kimi never computes a metric, a p-value, or a correction — it reads prepared datasets + summaries and authors hypotheses and critiques. This invariant is made *enforceable* by the numeric-provenance rule of §2.4 (R-C), not merely asserted.
3. **No gate/verdict/live authority.** The layer never writes a gate verdict, never mutates `farm_state.sqlite`, adds no second SQLite DB (audit `data_memory.md` §6), and touches no gate threshold or contract criterion (ROT). All new state is append-only JSONL ledgers + rebuildable read-model projections + in-repo artifacts.

Nothing in this layer feeds a Q08 DSR gate input; the trial-accounting question raised by the audit (`critic.md` §7) is answered inside the research layer without altering any gate computation — see §6.4 (R-C).

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
| DSR cohorts `qm.dsr-cohort/v1` | `(ea_id,symbol,timeframe)` | ea_id/symbol/tf | Q08 artifact; carries `search_history`, `research_trial_count`, `effective_trial_count` (**read-only reference; never written by this layer** — §6.4) | `dsr_cohort.py:26,753-768` |
| `evidence_cohort_baseline.json` (9.7 MB) | run | `work_item_id` | forward evidence-survival snapshot | audit §2 |

### 1.2 INFRA vs economic separation (the load-bearing caveat)

Every OBSERVE dataset **must** split on `verdict_taxonomy` (`work_item_clean_view.py:132-163`), never on raw `status`. The taxonomy families and their **single** dataset disposition (F7 fix — one disposition per taxonomy, enumerated in the manifest so the separation is provably complete):

| Taxonomy | Rows (audit) | Dataset disposition |
|---|---|---|
| `infra` (`INFRA_FAIL`; setup/data/host failures — never economic evidence) | 56,044 | `infra_runs.parquet` |
| `strategy` (gate pass/fail: `PASS*`/`FAIL*`/`ZERO*`/`RETIR*`, `work_item_clean_view.py:151-158`) | 53,752 | `economic_runs.parquet` |
| `measurement` + `prescreen_measurement` (DL-089 OPT_CENSUS + prescreen; **deliberately DISJOINT from `strategy`**, `work_item_clean_view.py:147-150`, DL-089 §3) | 19,962 + 350 | `measurement_runs.parquet` |
| `invalid` (`INVALID*` → `invalid`, `work_item_clean_view.py:141-142`) | 2,001 | `invalid_runs.parquet` (its **own** file — F7; not bundled into `infra_runs`) |
| `open`, `artifact`, `build`, `governance`, `review`, `draft_defect`, `unknown`, NULL (legacy/open) | remainder incl. 14,418 NULL | **explicitly excluded** from every economic/infra/measurement dataset; enumerated as `excluded` in the manifest split |

Directive §10 restates this: "Keep INFRA / NO_REPORT / SETUP_DATA errors separate from economic strategy failures." A dataset that conflates them is a defective dataset and OBSERVE must refuse to emit it. The manifest's `verdict_taxonomy_split` (§1.3) lists **every** taxonomy → destination so the completeness of the split is auditable, not implicit.

### 1.3 `observe_projector.py` — outputs and manifest

`tools/strategy_farm/research/observe_projector.py` (D6). Opens `farm_state.sqlite` in `mode=ro` (URI, read-only — audit §1) and reads `work_items_clean` + `ea_metrics` + `work_item_holds` + `work_item_transition_ledger` + `poison_pill_quarantine` + `sources`, joined idea→EA via `ea_id_registry.csv`. It emits a **versioned dataset directory** (D6). Canonical location and the disk-gate tension are reconciled in §2.3 (F5); the directory shape is:

```
<research-datasets-root>/2026-09-15T18-00-00Z/
  manifest.json            # schema qm.research-dataset/v1
  economic_runs.parquet    # verdict_taxonomy='strategy' only
  infra_runs.parquet       # verdict_taxonomy='infra'
  invalid_runs.parquet     # verdict_taxonomy='invalid'  (own file, F7)
  measurement_runs.parquet # OPT_CENSUS / prescreen, disjoint
  idea_family_map.parquet  # ea_id -> strategy_id, slug, family tags
  holds.parquet
```

`manifest.json` fields (deterministic, content-addressed): `schema`, `stamp_utc`, `source_db_path`, `source_db_size_bytes`, `row_counts` per file, `verdict_taxonomy_split` (maps **every** taxonomy → its destination file or `excluded`, proving the separation), `column_dictionary`, `sha256` per emitted file, `git_commit` of the projector, `farm_state_snapshot_note` (mtime; the DB is live, so datasets are timestamped snapshots not reproducible-forever — flagged, not hidden). The manifest is the *only* thing later stages hash; a dataset with a missing sha256 is not consumable (fail closed).

> **Open design note (inherited, per plan open-question):** `farm_state.sqlite` is a live, growing DB (audit reports ~1.26 GB). A per-stamp snapshot manifest gives content-addressability but two runs on different days over the same query yield different datasets. Whether "reproducibility" additionally requires pinning a per-campaign DB copy (a disk cost) is **not decided by D1-D6** and is deferred to the source contract / OWNER, not resolved here.

Datasets are small columnar files (economic runs ≈ 53,752 rows × ~15 cols), well under the disk guard (§2.3). **Raw gzip trees are never copied into a dataset** (audit §7).

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
- **Disk:** D6 gate — refuse to start when the research-output drive is below its free-space gate. The worker floor that already protects backtests is `DISK_MIN_FREE_GB=40.0` (`terminal_worker.py:146`).

A single `research_guard()` in the package checks all three before any batch and logs the refusal reason; this is the deterministic gate, not a judgement call.

**Disk-gate reconciliation note (F5 — inherited D6 tension, requires OWNER/Fable decision, not silently resolved here).** D6 fixes *both* an 80 GB D: self-gate *and* a fixed D: output location, while research outputs are only a few MB and D: was 65.6 GB free at audit time (`data_memory.md` §5) — so as literally inherited the two D6 constraints deadlock and the layer would be dead-on-arrival until a tester-cache purge frees space. This is an inherited constraint conflict, not a fault of this design. The recommended reconciliation, to be recorded as an explicit decision before the first campaign runs:
- **(a)** lower the research disk gate to a value consistent with few-MB outputs while staying safely above the 40 GB worker floor that already protects backtests; **or**
- **(b)** make the small dataset artifacts on C:/G: the canonical research-output location and reserve an 80 GB D: gate only for any large D: intermediate.

Until that decision is recorded, `research_guard()` enforces the strict D6 gate (fail-closed) and the campaign refuses to start rather than contend with backtests. The §11 "write to C:/G:" escape MUST NOT silently override D6's fixed D: path without the decision above being recorded. *(UNVERIFIED: the live D: free figure varies — the tester-cache purge runs every 10 min; treat the gate value, once decided, as the constraint, not 65.6 GB as a fixed state.)*

### 2.4 How Kimi receives data — paths + summaries, never raw dumps; and the numeric-provenance rule

Directive §10/§4/§6: deterministic prep first. Kimi is handed, via its prompt **file** (D1: prompt file + short argv pointer, Windows cmdline limit):

1. **File paths** to the dataset (`manifest.json` + the parquet/CSV) inside the read-scoped scratch/worktree it is `--add-dir`-limited to (D1; and R-D read-only posture, §5).
2. **Deterministic summaries** the projector produced (row counts, group-wise aggregates, feature distributions, the taxonomy split) — so Kimi reasons over compact statistics, not a 100k-row dump.
3. The **hypothesis-family registry** state (§2.5) so Kimi knows what has already been searched.

Kimi never gets the raw gzip evidence, never the live DB.

**Numeric-provenance rule (F3 fix, R-C) — determinism-first made enforceable.** Every quantitative claim in a QM-RESEARCH artifact (an observed edge magnitude, a cluster separation, a conditional probability, a confidence) **must reference a computed output file** — a projector or campaign JSON that carries its own sha256, recorded in `research.json` — and may cite **only** figures present in the deterministic summaries / dataset outputs handed to Kimi. **An LLM-computed number is never the evidence** (directive §6). Enforcement is a deterministic check in `research_source.verify` (§3.1) / `mechanization_check.py` (§4.3): an artifact whose stated metrics have no backing computed-file hash is rejected (`RESEARCH_NUMERIC_UNBACKED`). If Kimi's own tooling runs ML inside the scoped dir, its outputs are re-derived deterministically in Python and written to such a computed-output file before any number enters an artifact.

### 2.5 Hypothesis-family taxonomy (multiple-testing control at the source)

Directive §11/§18: "Track the number and family of hypotheses explored." Every DISCOVER question is registered under a **hypothesis family** before it is run, in the `search_history_ledger.jsonl` (§6.3). A family is the coarse mechanism class, aligned to the existing dedupe vocabulary in `farmctl.strategy_card_fingerprint` (`farmctl.py:4561-4565`: momentum, mean-reversion, breakout, carry, seasonal, volatility, gap, news, fomc, trend, pairs) extended with structural classes (regime-conditioning, session/time-of-day, failure-mode, cross-strategy-redundancy). Families exist so the research-layer trial accounting (§6.4) counts *how many bites of the apple* were taken per mechanism, not per winner.

### 2.6 Discovery vs prediction (what counts)

Directive §11:

- **A discovery** (permitted output): *"When condition A + B + C holds, subsequent market behaviour differs materially from baseline"* — conditional, interpretable, mechanizable.
- **A prediction** (NOT an output): *"Model X predicts next return with P=0.612"* — remains research evidence only; it may never become the EA (directive §1.3 invalid progression). A DISCOVER result phrased as a prediction is returned to research for restatement as a conditional relationship before HYPOTHESIZE.

---

## 3. HYPOTHESIZE — Kimi as author (QM-RESEARCH artifact)

When DISCOVER surfaces a candidate edge, Kimi authors an **immutable research-source artifact**. This is the R1 source for any card that follows (directive §12/§14; decision #2). The full contract, including immutability and the resolvability semantics enforced at intake, is `INTERNAL_RESEARCH_SOURCE_CONTRACT.md`; the research-facing shape is below.

### 3.1 Artifact template — `QM-RESEARCH-YYYY-NNNN`

Durable store (D5), git-tracked in-repo on C: (audit `cards_r1_research.md` §3, following the established `strategy-seeds/sources/AI-CODEX-...` precedent §1e):

```
strategy-seeds/sources/QM-RESEARCH-2026-0001/
  source.md          # the research artifact (Kimi-authored) — carries a fenced manifest block (R-B)
  research.json      # machine record incl. sha256 of source.md + computed-output hashes (§2.4)
  critic_receipt.json # cross-vendor critique receipt (§5)
  lineage.json       # version / discovery-vs-validation lineage (§6)
```

`source.md` frontmatter + body must carry every field the directive requires (§12/§14):

| Field | Source |
|---|---|
| `source_id: QM-RESEARCH-2026-0001` | §14 |
| `source_type: internal_research` | §14; new informational label, optionally `farmctl.VALID_SOURCE_TYPES += 'internal_research'` only if a routable DB `sources` row is wanted (audit §2b/§2c — deferrable) |
| `source_author: Kimi` | §12 |
| `source_model` (exact Kimi model recorded **at runtime**, e.g. `kimi-code/kimi-for-coding`) | §12; the running model id is captured per call (D1: `--version` per run) because the CLI self-updates (audit `kimi_cli.md` §7). *(UNVERIFIED: the "K2.8" display string in `kimi_cli.md` §3 is a point-in-time reading, not a fixed contract.)* |
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
| a `## Research provenance` section (holds the ML-derived narrative) | D5 — exempted from the prescreen ML scan (§7) and the `mechanization_check` ML scan (§4.3); the exact heading string is a **shared constant** between `card_intake_prescreen.py` and `mechanization_check.py` so the two exemptions cannot drift |

**Hash anchoring (R-B).** `source.md` carries a **fenced manifest block** listing the sha256 of `research.json`, `lineage.json`, `critic_receipt.json`, and any dataset manifests it cites. The card's `source_hash` (= `source_sha256`) is `sha256(source.md)`; the append-only `research_source_ledger.jsonl` row records the same hash. Immutability is by **content hash + append-only ledger + git history**: any later edit mints a **new version id with a parent link** (`lineage.json`), never a silent rewrite. The resolver `tools/strategy_farm/research_source.py` (D5) does mint / resolve / verify (`QM-RESEARCH://id` → path + sha check + manifest-block hash check + ledger-status check). The ledger row is `{id, created, author, model, task_id, sha256, parent_id, status: draft|reviewed|preregistered|carded|retired}`. `source = Kimi` without a resolvable, sha-verified artifact is invalid (decision #2) and is rejected at intake, not merely at authoring — see §7 (R-A).

### 3.2 Kimi prompt contract

Delivered as a prompt **file** with a short argv pointer (D1). The prompt: (a) states the research question + hypothesis family; (b) points at the dataset paths + summaries (§2.4); (c) requires the output to fill the §3.1 template exactly, in the mechanizable "condition → behaviour differs from baseline" form (§2.6); (d) requires it to name confounders and related existing strategies; (e) forbids it from asserting any metric it did not receive pre-computed, and requires every quantitative claim to cite a computed-output file (§2.4, R-C). Model selection and the `--auto` / scoped-worktree mechanics are owned by `KIMI_INTEGRATION_ARCHITECTURE.md` (D1); a Kimi **creator** runs in an isolated worktree/scratch dir. *(UNVERIFIED: exact default model id and `--auto` semantics are per D1 / `kimi_cli.md`; recorded at runtime, not fixed here.)*

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
2. **No ML/inference terms in the mechanics sections** — reuse the pattern set from `card_intake_prescreen._affirmative_prohibited_mechanics` (`card_intake_prescreen.py:470-489`), scanning the mechanical sections only (the `## Research provenance` narrative is exempt, keyed on the shared heading constant §3.1). Emits `MECH_ML_IN_RULES` on an affirmative hit.
3. **Finite parameter count** — every parameter has a bounded numeric range; unbounded / open-ended params → `MECH_PARAM_UNBOUNDED:<name>`.
4. **Codex-implementability checklist** — deterministic entry, exit, stop, sizing, filter each resolvable to a rule with no external model reference; a dangling reference to the dataset/model → `MECH_MODEL_DEPENDENCY`.
5. **No runtime data feed** beyond native MT5 + the live news filter (CLAUDE.md Hard Rules; live EAs never read the backtest news archive).
6. **Numeric provenance** (R-C, §2.4) — every quantitative claim in the accompanying artifact resolves to a computed-output-file hash, else `RESEARCH_NUMERIC_UNBACKED`.

A spec that fails any rule is returned to research with the finding list; it does not proceed to ATTACK.

---

## 5. ATTACK — cross-vendor falsification

Before Strategy Card promotion the mechanized hypothesis is attacked by a **non-Kimi critic** (directive §8/§15; decision #7). This runs on the existing `agent_chain` (D4): Kimi is the creator, and the `by_creator_vendor.kimi` table lists **only non-Kimi critics**. **This table is a D4 design target to be created** — `agent_chain.v1.json` today carries vendors `claude/codex/agy` and has **no `kimi` key** (audit `router_providers.md` §4; the "never list a kimi seat inside `by_creator_vendor.kimi`" invariant is **risk item 7 under `router_providers.md` §9 (Risks)**, `agent_chain.py:258-269`) — F6 correction to the prior citation. The invariant is unchanged: Kimi is never in its own critic table.

### 5.1 Critic read-only posture (R-D) — prevention, not just detection

The prior detection-only posture (a git-status hash of `C:/QM/repo` before/after) was flagged blocking by the architecture review because `--auto` is full tool execution and `farm_state.sqlite`/verdicts/evidence live under `D:/QM`, outside the repo tree the hash guard covers. The binding posture is R-D:

- **Primary (prevention):** the Kimi critic runs under a **read-only agent-file/posture that denies file-writing tools**, with `--add-dir` limited to a **scratch dir that has read access to the repo** — never `--add-dir` the live tree under `--auto`. This posture is **verified by the probe battery** (owned by `KIMI_INTEGRATION_ARCHITECTURE.md`): *does `--add-dir` grant write? does `--plan` deny writes?* The critique scheduled task is gated on these probes passing, not merely on a smoke receipt. *(UNVERIFIED: `--plan` write-denial and `--add-dir` write semantics — resolved by the probe battery at implementation time, per D1.)*
- **Secondary (detection):** the adapter's git-status hash guard before/after (extended to cover the `D:/QM` verdict/evidence paths, per the architecture doc).
- **Failure handling:** a critic run that **wrote anything is FAILED and its output is discarded** — `agent_chain` marks status `critic_wrote` and **no formatter runs**. And `research_source.verify` **fails closed when `critic_receipt.json` carries `repo_write=true`**.

Single-flight: because the OAuth credential file refresh is a shared-file race, `kimi_adapter.py` holds a **machine-wide single-flight lock** around every Kimi invocation regardless of caller (R-E); `max_parallel=1` on the lane is the second belt. Details in `KIMI_INTEGRATION_ARCHITECTURE.md`.

### 5.2 Falsification checklist (directive §15)

The critic must explicitly assess: data snooping; leakage; selection bias; symbol bias; time-period bias; regime dependence; transaction costs; trade-count sufficiency; parameter flexibility; multiple testing (fed the research-layer trial count §6.4, never a Q08 DSR count); **similarity to existing QuantMechanica strategies**; dependence on a single feature or period; simpler null explanations. It must answer the directive's core question: *is this a genuinely distinct mechanical edge, or another expression of something QuantMechanica already trades/tests?* Criticism does not kill a hypothesis by opinion — it creates evidence for Fable's preregistration decision (directive §15).

### 5.3 Critic receipt → source record

The chain writes its receipt (`qm.agent-chain.receipt.v1`, audit `router_providers.md` §6). The real receipt field paths (R-I) are: `plan.creator` / `plan.critic` (each `vendor`, `model`), `stages[].seat`, `critic_verdict`, `finding_counts`, `scope_drift`, `receipt_path`, `critic_fallback_used`, `critic_seat_final` (receipt schema at `router_providers.md` §6, L42). MECHANIZE/ATTACK copies the receipt into `strategy-seeds/sources/QM-RESEARCH-YYYY-NNNN/critic_receipt.json` and records its sha256 in `research.json` (and in the `source.md` manifest block, R-B), so the source record carries its own cross-vendor review (directive §12 field `Critic receipt`; decision #2 "cross-vendor review receipt"). No card is minted before the critic receipt exists and `research_source.verify` confirms `repo_write != true`.

---

## 6. PRE-REGISTER — freeze before validation

Directive §16/§18: before the candidate is tested, freeze the hypothesis so a later holdout result cannot be retrofitted.

### 6.1 Freeze record

`tools/strategy_farm/research/preregister.py` (D6) writes an immutable freeze record (sha256-stamped, appended to `research_source_ledger.jsonl` with `status: preregistered`) capturing directive §16: research hypothesis; exact mechanical translation (sha256 of the spec); allowed parameter ranges; **parameter count**; discovery sample; validation sample; holdout logic; expected behaviour; success criteria; failure criteria; known risks.

### 6.2 Lineage / versioning rule

Directive §16: once holdout results are observed, the hypothesis may not be modified and passed off as the original. Any modification mints a **new lineage version** (`lineage.json` + a new `QM-RESEARCH` version id in the ledger with a parent link, R-B). `strategy_card_fingerprint` (`farmctl.py:4548-4566`) folds `source_id` in, so one child id per idea keeps near-duplicate detection honest (audit `cards_r1_research.md` §5 risk 3).

### 6.3 Holdout discipline + `search_history_ledger.jsonl`

`<research-state-root>/search_history_ledger.jsonl` (D6), `schema: qm.research-search-history/v1`: one line per search/experiment — hypothesis family, dataset id, period, instruments, feature families, parameter-space size, holdout id, outcome (directive §18 list). It records: number of hypotheses attempted, families, datasets/periods/instruments/feature-families searched, parameter spaces, reused holdouts, rejected hypotheses, modified/recycled hypotheses. Kimi never runs unbounded searches over the full history reporting only the winner (directive §18); untouched validation data is preserved where practical, and a holdout is not re-mined.

### 6.4 Trial accounting — research-layer evidence, NOT a gate-input write (F1 blocking → R-C)

The audit named the real risk: "no auditor connected Kimi's hypothesis volume to DSR multiple-testing correction; uncounted trials silently inflate survivorship" (audit `critic.md` §7). The **draft's original resolution — injecting the research family count into `dsr_cohort.research_trial_count` / `effective_trial_count` for a QM-RESEARCH candidate — is rejected as written**, because those fields are the deflated-Sharpe inputs to the **Q08 DSR gate**; changing a gate input for a class of candidates is a gate-contract/ROT change (directive §5/§23; CLAUDE.md ROT: "gate thresholds & contract criteria"), it contradicts this layer's own no-gate-change invariant (§0), and it is a category error — the DSR field counts **sealed DL-089 parameter-census candidate configurations** (`dsr_cohort.py:751-768`, `search_history.unit='candidate_configuration'`, `annual_measurements_are_trials=False`), not research-search families, and `dsr_cohort` is fail-closed: it accepts only counts reconstructable from the sealed ledger and cannot ingest an injected value without breaking its sealing (`dsr_cohort.py` docstring L1-8).

**Binding resolution (R-C).** There is **no change to the DSR/FDR formula and no change to how `dsr_cohort` computes counts** (ROT untouched). Instead:

1. `search_history_ledger.jsonl` is the **evidence** for the `research_trial_count` that the existing card / single-configuration contract **already declares**. An internal QM-RESEARCH card must declare `research_trial_count >= the ledger's count for its hypothesis family`.
2. The intake check (§7) **fails closed** when the ledger shows searches for a hypothesis family but the card declares `research_trial_count = 0` (reject code `RESEARCH_TRIAL_COUNT_UNDERSTATED`).
3. Research-layer multiple-testing correction (Deflated Sharpe / Benjamini-Hochberg FDR across a family's attempt count) is computed by `tools/strategy_farm/research/stats_corrections.py` **on the research ledger** — as research reporting, never written into the Q08 cohort.
4. The research trial count is surfaced only to (a) Fable's preregistration decision, (b) the ATTACK critic prompt (§5.2), and (c) research reporting.

If OWNER later wants the research family-count folded into the Q08 DSR deflation, that is an **explicit ROT gate-contract decision package**, raised separately — it is not implemented in this layer. *(UNVERIFIED design detail, deferred to that package: the exact contract by which any such count would augment `effective_trial_count` without breaking the sealed-ledger invariant — a new source-of-trials field vs a wrapper cohort — per plan open-question.)*

---

## 7. STRATEGY CARD handoff — fail-closed internal-source enforcement (F2 blocking → R-A)

Once a hypothesis has valid internal R1 provenance, a mechanical spec, a cross-vendor critic receipt, and a preregistration, it becomes a normal Strategy Card (directive §17). The card cites the research source in frontmatter (audit `cards_r1_research.md` §2a):

```
source_id: QM-RESEARCH-2026-0001
source_type: internal_research
source_author: Kimi
source_uri: QM-RESEARCH://2026-0001
source_sha256: <hex of source.md>
```

R1 is already author/type-agnostic — `_card_r1_build_ready` returns `bool(str(fm.get("source_id")...).strip())` (`farmctl.py:4229-4237`) and approve-card's strict pass fields are R2/R3/R4 only, R1 excluded (`farmctl.py:4219,4464-4471`; audit §1b). **But R1 passing on a non-empty `source_id` alone means an internal card with an unresolvable/hallucinated source would falsely PASS** (the agy-video-hallucination precedent). The directive-mandated tests "author=Kimi without artifact FAILS" / "missing hash fails closed" require a real gate. The binding enforcement is R-A — a concrete, deterministic, fail-closed check at **both** intake points, external cards unchanged:

1. **`card_intake_prescreen.evaluate_card` gets a new branch:** when frontmatter `source_type == internal_research` **OR** `source_id` matches `^QM-RESEARCH-\d{4}-\d{4}$`, then `research_source.verify(id)` must succeed — artifact dir present; `source.md` sha256 == card `source_hash`; `research.json` / `lineage.json` / `critic_receipt.json` hashes present in the `source.md` manifest block (R-B); ledger row `status IN {reviewed, preregistered, carded}` — else **REJECT** with reason `INTERNAL_SOURCE_UNRESOLVED`. (Companion reject codes named at their checks: `INTERNAL_SOURCE_HASH_MISMATCH`, `RESEARCH_NUMERIC_UNBACKED` §2.4, `RESEARCH_TRIAL_COUNT_UNDERSTATED` §6.4, and `repo_write=true` critic failure §5.1.) These reasons are added to the prescreen reason set so `--apply` routes the card to `cards_rejected`.
2. **`farmctl approve-card` (the G0 promotion path, `_card_r1_build_ready`)** performs the same `research_source.verify` and refuses on any miss.
3. **`author = Kimi` without a resolvable artifact is exactly that REJECT** (`INTERNAL_SOURCE_UNRESOLVED`).

**External cards: unchanged code path** — the branch only fires on the internal-source class, so external book/paper/forum attribution is untouched (audit §2b, §1e).

The **one additional required code change** for honest ML-provenance prose (already noted in the audit `critic.md` §5, `cards_r1_research.md` §2b): scope `card_intake_prescreen._affirmative_prohibited_mechanics` (`card_intake_prescreen.py:464-489`) so its ML text-scan **skips the `## Research provenance` section** (keyed on the shared heading constant §3.1) — today it scans the whole card body and would emit `PROHIBITED_MECHANICS:ML` for an honest ML-provenance sentence. External cards unchanged. From Q00 the card runs the identical Q00–Q17 path; Kimi authorship confers no advantage (directive §17).

---

## 8. LEARN — experiment memory

Directive §19: make both success and failure queryable, built additively on the existing SQLite/report architecture — no manually maintained duplicate research universe.

### 8.1 `experiment_memory_ledger.jsonl` + projector

`<research-state-root>/experiment_memory_ledger.jsonl` (audit `data_memory.md` §6.1), `schema: qm.experiment_memory/v1`: `{schema, ts_utc, strategy_id, ea_id, symbol, timeframe, phase, hypothesis, verdict, verdict_taxonomy, reason, evidence_path, work_item_id, search_history_ref}`. It mirrors the proven `tester_memory_ledger.jsonl` convention.

The read-model `tools/strategy_farm/research/experiment_memory_projector.py` (modeled on `ea_metrics.py`) emits a versioned `idea_outcome_projection.json` (audit §6.2) by SELECTing from `work_items_clean` + `ea_metrics` + `work_item_holds` + `work_item_transition_ledger` + `poison_pill_quarantine`, joined idea→EA via `ea_id_registry.csv`. Pure derived, rebuildable. INFRA rows are excluded from every economic answer (§1.2).

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

*(UNVERIFIED: the exact per-year / fold / seed fields inside `ea_metrics.detail_json` were not opened this session; confirm against a live `detail_json` before the regime/consistency queries are written. UNVERIFIED: the Q02 frequency floor `≥5 trades/yr` is cited from `OPERATING_RULES_2026-07-03.md` via CLAUDE.md and was not re-opened this session.)*

PASS/FAIL outcomes flow back automatically: each terminal gate verdict already lands in `work_item_transition_ledger`; the projector picks it up on its next rebuild and the experiment-memory ledger is appended when a QM-RESEARCH-lineage run reaches a terminal verdict, keyed by `search_history_ref` back to the originating search. Each conclusion resolves to a `work_item_id`/`evidence_path` (directive §19: "Each conclusion must resolve back to evidence").

---

## 9. Anti-data-snooping controls (directive §18)

The layer materially increases multiple-testing risk; the defence is deterministic and in Python (directive §18 — "If advanced statistical correction can be done deterministically, implement it in Python rather than asking an LLM to estimate whether overfitting looks bad"):

1. **Trial accounting is mandatory and pre-committed.** Every DISCOVER question is logged to `search_history_ledger.jsonl` *before* it runs (§6.3); the winner-only report pattern is structurally impossible because attempts are counted, not just successes.
2. **Research-layer trial count backs the card declaration.** The per-family attempt count is the evidence for the card's already-declared `research_trial_count` (§6.4, R-C), and the intake check fails closed when the ledger shows searches but the card declares 0. **No value is written into the sealed Q08 DSR cohort** (ROT untouched).
3. **Research-layer deflation reporting.** `stats_corrections.py` computes Deflated Sharpe / BH-FDR across a family's attempt count **on the research ledger** — never estimated by an LLM, never written into a gate (§6.4).
4. **Holdout preservation + preregistration.** Discovery sample and validation sample are frozen at PRE-REGISTER (§6.1); a reused holdout is flagged in the ledger and the candidate is down-weighted.
5. **Lineage on modification.** A post-holdout edit is a new version (§6.2), never a silent rewrite.
6. **Discovery ≠ prediction.** A prediction-shaped result cannot proceed (§2.6), removing the "tune a predictor until it backtests well" path.
7. **Cross-vendor ATTACK** independently scores selection bias / multiple testing / similarity-to-existing (§5.2).
8. **Numeric provenance.** Every quantitative claim resolves to a computed-output-file hash (§2.4, R-C); no LLM-asserted number becomes evidence.

---

## 10. Research objective metrics — authoring-time vs post-pipeline (F4 → R-H)

Directive §9/§20: optimise for quality, not card count. The prior single table conflated metrics that need a backtested EA with metrics computable at authoring time — but the layer is explicitly **pre-Q00** (§0), so at HYPOTHESIZE/PRE-REGISTER time there is no backtest, no DSR cohort, no correlation vector, no portfolio candidacy. R-H splits them, and a research-time proxy **never substitutes for the pipeline's own robustness/portfolio evidence**.

### 10.1 Authoring-time metrics (computable pre-Q00, recorded in `research.json` at mint)

| Objective | Measured as | Computed by |
|---|---|---|
| **Novelty** | strategy-fingerprint distance (1 − max cosine/overlap vs all existing fingerprints; low collision) + hypothesis-family taxonomy position | `farmctl.strategy_card_fingerprint` `farmctl.py:4548-4566`; §2.5 |
| **Mechanizability** | `mechanization_check.py` PASS with finite bounded parameter count (binary + param count) | §4.3 |
| **Falsifiability** | presence + specificity of the `FALSIFICATION` section **with a numeric kill rule** (binary + critic score) | `card_intake_prescreen.py:408-409`; §4.1; critic §5.2 |
| **Reproducibility** | dataset manifest sha256 chain resolves + `research_source.verify` passes + preregistration freeze intact | §1.3, §3.1, §6.1 |

### 10.2 Post-pipeline observed metrics (UNAVAILABLE at mint; populated by the LEARN projector after terminal verdicts)

| Objective | Measured as | Computed by (post-Q00) |
|---|---|---|
| **Robustness** | multi-seed dispersion + walk-forward stability + stress outcome | Q08 DSR cohort `dsr_cohort.py`; OPT_CENSUS |
| **Independence** | max abs. return correlation of the validated variant vs existing book members (lower = better) | `portfolio/correlation_dev.json` |
| **Portfolio usefulness** | marginal contribution to portfolio-candidate risk-adjusted return after correlation | `portfolio_candidates`; correlation artifact |

At mint, the §10.2 fields are written as `UNAVAILABLE` (never a research-time or LLM proxy score) and are backfilled by the LEARN projector (§8) once the card has run Q00–Q17 and reached a terminal verdict. A month's research is judged on the four authoring-time axes plus, where the pipeline has run, the three observed axes — not on strategy count (directive §20: "5 genuinely independent hypotheses > 500 RSI/MA/breakout variations").

---

## 11. First concrete research campaign proposal

Sized to the CPU/disk rules (§2.3) and answerable **now** from existing evidence with no gzip re-walk.

- **OBSERVE dataset:** `observe_projector.py` emits `economic_runs.parquet` = `verdict_taxonomy='strategy'` runs (≈53,752 rows) at Q02/Q04, with columns `ea_id, strategy_id, symbol, timeframe, verdict, trades, profit_factor, drawdown_pct, sharpe, net_profit`, plus per-year consistency extracted from `ea_metrics.detail_json` *(UNVERIFIED per-year fields — §8.2)*, joined to family tags via `ea_id_registry.csv`. Single pandas job, fits in RAM, output a few MB.
- **DISCOVER question (family: `failure-mode` / `robust-but-inactive`):** *Among strategy-taxonomy backtests, is there a cluster of `(ea_id, symbol)` candidates with healthy risk metrics (profit_factor > 1, drawdown_pct within the FTMO 10% box, positive sharpe) that are killed **only** by insufficient activity — trades/yr below the Q02 frequency floor of ≥5 (`OPERATING_RULES_2026-07-03.md`, UNVERIFIED §8.2)?* Method: k-means / DBSCAN over the standardized feature vector, isolating the "robust but inactive" cluster (directive §19 explicit question).
- **Why answerable now:** every input is in `ea_metrics` + `work_items_clean`; no trade-level gzip needed. This directly answers directive §19's "Which strategies are robust but too inactive?" and feeds a mechanizable hypothesis: a bounded activity-relaxation (e.g. a widened but finite entry-filter range) that could revive a robust engine — a genuinely mechanical, finite-parameter edge, not a predictor.
- **HYPOTHESIZE output:** if a coherent cluster exists, Kimi authors `QM-RESEARCH-2026-0001` proposing the mechanical relaxation with its economic rationale (why the engine is sound but under-triggered), confounders (survivorship in the census; symbol concentration), and related existing strategies — every quantitative claim citing the campaign's computed-output JSON (§2.4).
- **Disk caveat:** the campaign's D:-writing steps are subject to the §2.3 disk gate and the F5 reconciliation note; `research_guard()` fails closed until either the gate is satisfied or the OWNER/Fable disk-gate reconciliation (§2.3) records C:/G: as the canonical small-artifact location. The campaign refuses to start rather than contend with backtests.

---

## 12. What this layer never does — code-level vs process-level guards (R-F)

No gate-threshold change, no T_Live/AutoTrading/deployment/live-book change, no verdict write, no evidence deletion, no second SQLite DB, no ML in an EA, no unbounded holdout mining, no LLM-computed metric, no card without a resolvable sha-verified source (directive §5/§23; decision #5). The prohibitions are enforced at two distinct levels, and this document is explicit about which is which:

**Code-level guards (structural — a Kimi task cannot do the thing):**
- Capability omission → rows unclaimable: Kimi declares no `code`/`ops`/`repo_edit`/`scalpel_mechanization` caps, so `build_ea`/`ops_issue` rows are never routable to it (`agent_router.py:1678-1680`; audit `router_providers.md` §2).
- No verdict-write path in any Kimi branch: verdicts/`APPROVED` are written only by the human `close-review` CLI; Kimi is REVIEW-terminal and out of `AGENT_TASK_TYPE_LANES` (audit §2 "No gate/live/deployment/verdict authority").
- T_Live paths never in `--add-dir`; no `farmctl` subcommand callable by a Kimi task in its tool envelope (R-D read-only posture).
- Internal source fail-closed at intake (§7, R-A); no gate-input write for trial counts (§6.4, R-C); critic read-only enforced (§5.1, R-D).

**Process-level guards (receipts + human review):**
- Cross-vendor critic receipt required before card mint (§5.3); Fable's preregistration decision (§6); orchestrator manual `close-review`; Q00–Q17 remains the sole judge (directive §17).

Every artifact is append-only or rebuildable; every step is reversible by clearing a flag / deleting a derived projection / not installing a scheduled task.

---

## Appendix A — Review disposition

Two review files exist in `docs/ops/evidence/2026-09-15_kimi_integration/design/`. This document had **no** `KIMI_EDGE_DISCOVERY_DESIGN.review.json`; per the task's fallback instruction the reviews whose findings discuss this document's topics were used. The file named `INTERNAL_RESEARCH_SOURCE_CONTRACT.review.json` is in fact the adversarial review of **this** document (all seven findings cite this document's sections §0/§1/§2/§5/§6.4/§7/§9.2/§10/§11); it is labelled EDD-F1…F7 below. The one blocking finding in `KIMI_INTEGRATION_ARCHITECTURE.review.json` that lands on this document's ATTACK section is labelled ARCH-B1.

| Finding | Claim (abbreviated) | Disposition |
|---|---|---|
| **EDD-F1** (blocking) | §6.4/§9.2 inject research family count into `dsr_cohort.research_trial_count`/`effective_trial_count` — a Q08 gate input | **resolved-by-orchestrator (R-C).** Coupling to the sealed Q08 cohort removed (ROT untouched); the search_history_ledger is instead the *evidence* for the card's already-declared `research_trial_count`, intake fails closed if the ledger shows searches but the card declares 0, and Deflated-Sharpe/BH-FDR run on the research ledger only. Any Q08 folding is a separate ROT package. §6.4, §9 rewritten. The review's "delete all DSR coupling" intent is honoured; R-C keeps the honest coupling (card declaration + evidence) it did not forbid. |
| **EDD-F2** (blocking) | §7/§3.1 claim "source=Kimi without artifact is invalid" but wire no gate; unbacked internal source would PASS | **applied (= R-A).** §7 now specifies the fail-closed `research_source.verify` branch in `card_intake_prescreen.evaluate_card` AND `farmctl approve-card`, reject code `INTERNAL_SOURCE_UNRESOLVED` (+ companions), external path unchanged. |
| **EDD-F3** (major) | §2.4 numeric re-derivation asserted but nothing enforces it | **applied (R-C numeric-provenance rule).** §2.4 adds the rule: every quantitative claim references a computed-output file with sha256 in `research.json`; check `RESEARCH_NUMERIC_UNBACKED` in `research_source.verify`/`mechanization_check.py` (§4.3 rule 6). |
| **EDD-F4** (major) | §10 presents all seven objective metrics as measured, but four need a backtested EA at a pre-Q00 stage | **applied (= R-H).** §10 split into §10.1 authoring-time (novelty, mechanizability, falsifiability, reproducibility) and §10.2 post-pipeline observed (robustness, independence, portfolio usefulness) marked UNAVAILABLE at mint, backfilled by the LEARN projector. |
| **EDD-F5** (minor) | §2.3/§1.3/§11 D6 disk gate (80 GB D:) deadlocks with D6 fixed D: output path; §11 C:/G: escape contradicts it | **applied.** §2.3 adds an explicit inherited-D6 reconciliation note (options a/b), flags it as an OWNER/Fable decision, keeps the strict gate fail-closed until decided, and forbids the §11 C:/G: escape silently overriding D6. Concrete free-space numbers marked UNVERIFIED/varying. |
| **EDD-F6** (minor) | §5 presents `by_creator_vendor.kimi = [claude,codex,agy]` as present config and miscites the audit | **applied.** §5 marks the kimi critic table a D4 design target to be created (no `kimi` key today), corrects the citation to `router_providers.md` §9 risk 7, keeps the invariant. |
| **EDD-F7** (minor) | §1.2 says `invalid` is excluded/dropped while the §1.3 manifest bundles it into `infra_runs` | **applied.** §1.2 gives `invalid` its own `invalid_runs.parquet` file, and the manifest `verdict_taxonomy_split` now enumerates every taxonomy → destination (incl. `excluded`) so the separation is provably complete. |
| **ARCH-B1** (blocking, from the architecture review; lands on this doc's §5) | Kimi critic read-only enforced only by a post-hoc repo git-hash guard; detection not prevention; D:/QM out of scope; `--plan` unverified | **applied (= R-D).** §5.1 replaces detection-only with prevention-first: read-only agent-file/posture denying file-writing tools + `--add-dir` limited to a read-scoped scratch dir, verified by the probe battery; secondary git-hash guard extended to D:/QM; a critic that wrote is FAILED (`critic_wrote`, no formatter), `research_source.verify` fails closed on `repo_write=true`. Single-flight lock (R-E) noted. |

**Other binding orchestrator resolutions incorporated:** R-B (hash anchoring — §3.1 fenced manifest block, `source_hash=sha256(source.md)`, ledger records same, edit = new version id + parent link); R-E (machine-wide single-flight lock in `kimi_adapter.py` — §5.1); R-F (code-level vs process-level guard split — §12); R-I (real `agent_chain` receipt field paths — §5.3). R-G (governor caps / gemini-down interaction) is `KIMI_INTEGRATION_ARCHITECTURE.md` territory and is cross-referenced rather than restated here.

**Kept verbatim per the review's "keep" list:** §0 hard invariants; §1 evidence-inventory row counts (all match the audit); §1.2 INFRA-vs-economic separation as a refuse-to-emit rule; DB `mode=ro` + content-addressed datasets with per-file sha256; §2.2/§2.3 resource discipline subordinate to never-throttled backtests; §4 MECHANIZE deterministic checks + Codex-implementability test; §7 R1-already-source-agnostic recognition (now with the added resolvability check); §8 LEARN additive ledger + rebuildable projector; §2.6 discovery-not-prediction gate; §5 cross-vendor ATTACK posture (upgraded per R-D); §12 reversibility.

## Appendix B — UNVERIFIED items (carried forward, not guessed)

- Live D: free-space figure and the final research disk-gate value (§2.3, §11) — varies with the 10-min tester-cache purge; treat the decided gate as the constraint.
- The exact `agent_chain.v1.json by_creator_vendor.kimi` contents (D4 target; today vendors are `claude/codex/agy`, no `kimi` key — `router_providers.md` §4) — created by the architecture-doc work, not this doc (§5).
- Kimi model display string ("K2.8" for `kimi-code/kimi-for-coding`, `kimi_cli.md` §3) and `--plan`/`--add-dir` write semantics — recorded at runtime / resolved by the probe battery, per D1 (§3.1, §5.1).
- The exact per-year/fold/seed fields in `ea_metrics.detail_json` — confirm against a live `detail_json` before the regime/consistency and first-campaign queries are written (§8.2, §11).
- The Q02 frequency floor `≥5 trades/yr` — cited from `OPERATING_RULES_2026-07-03.md` via CLAUDE.md; not re-opened this session (§8.2, §11).
