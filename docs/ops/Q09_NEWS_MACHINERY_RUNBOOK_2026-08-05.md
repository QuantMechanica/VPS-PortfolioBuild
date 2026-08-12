# Q09 News Machinery Runbook

**Date:** 2026-08-05
**Purpose:** Single consolidated contract + operational reference for the Q09_NEWS gate machinery, replacing the drifted Obsidian vault page and eight scattered evidence docs. This document is the **current contract only**, cross-checked against the source at canonical checkout `C:/QM/repo` (HEAD after commits `a20ded0c4`/`aabb9f244`); where a claim could only be verified against an evidence doc and not current source, it is marked as such. Every factual claim in the Current Contract section carries an inline `(file:line)` citation verified by reading that line this session.

Q09_NEWS is the pipeline's news-blackout/news-filter admission gate. It runs a sealed, paired A/B tester experiment (news-policy OFF vs. ON across temporal blackout modes), adjudicates whether a news policy robustly helps, and — only on a `CONFIG_LOCKED` result — feeds the DXZ qualification chain (Q10 dependency gate) and the additive FTMO admission consumer. Storage keeps the legacy phase key `Q09_NEWS`; operator surfaces display `Q09`.

---

## 1. Current Contract

### 1.1 Sealed plans

A **sealed plan** (`run_plan.json`) is an immutable, hash-bound description of one Q09 experiment: its per-cell setfiles, source-artifact identities, windows, and calendar bundle. `build_run_plan` seals it (`q09_news_runner.py:208`) by writing each per-cell setfile and the plan with `_write_immutable`, which refuses to overwrite existing bytes with different content (`q09_news_runner.py:135`). The plan is self-hashed: `plan_sha256` covers the logical JSON (`q09_news_runner.py:153`, set at `q09_news_runner.py:355`), and callers additionally authenticate the exact file bytes via an optional `expected_file_sha256` (`q09_news_runner.py:399`).

The plan is bound to exactly one pending canonical `Q09_NEWS` work-item row by `bind_plan_to_work_item` (`q09_news_runner.py:549`), which authenticates the Q08→Q07 lineage, registers the immutable calendar bundle, writes a self-hashed dispatch binding (`q09_news_runner.py:707`), and flips the row's activation state to `RUNNABLE_BOUND` (`q09_news_runner.py:693`). Until a sealed plan is bound, the row is held out of every claimant by a `Q09_AWAITING_SEALED_PLAN` work-item hold (`q09_news_schema.py:44`, `q09_news_schema.py:60`); binding releases only that exact hold in the same transaction (`q09_news_schema.py:114`).

The tester period is **not** a free CLI argument: it is derived from the hash-bound Q08 `baseline_run.period` inside the sealed input manifest (`q09_news_runner.py:447`), and an explicit `--period` that contradicts the sealed period fails closed (`q09_news_runner.py:477`). Execution requires a sealed `REAL_TICKS` tester model (`q09_news_runner.py:571`) and Model 4 (`q09_news_runner.py:2035`); each cell setfile is validated to carry `RISK_FIXED > 0` and `RISK_PERCENT = 0` (`q09_news_runner.py:1528`) and a stale-news ceiling `qm_news_stale_max_hours <= 336` (`q09_news_runner.py:1536`).

### 1.2 Arms and scopes — the 7x1 → 7x4 expansion

The experiment has **two logical arms** (`q09_news_contract.py:9`):

- `CONTROL_OFF` — temporal mode `OFF`, compliance `NONE` (the negative control).
- `POLICY_ON` — sweeps all seven temporal blackout modes against the deployment target's fixed compliance policy.

The seven temporal modes are `OFF, PRE30, PRE60, PRE30_POST30, PRE60_POST60, SKIP_DAY, CLOSE_ALL_PRE` (`q09_news_contract.py:37`); the four compliance modes are `NONE, DXZ, FTMO, 5ERS` (`q09_news_contract.py:47`); the five canonical seeds are `42, 17, 99, 7, 2026` (`q09_news_contract.py:48`). Every `POLICY_ON` run is paired to a `CONTROL_OFF` run at the same seed and immutable base identity (`q09_news_contract.py:11`).

The cell matrix is built by `_cell_specs` (`q09_news_runner.py:172`): 5 control cells, plus for each compliance × each temporal × each seed a `POLICY_ON` cell.

- **7x1 (`7x1_target_compliance`, 40 cells):** the default. 1 target compliance × 7 temporal × 5 seeds = 35 `POLICY_ON`, plus 5 control = **40 cells**. Tagged `matrix_scope="7x1_target_compliance"` (`q09_news_runner.py:339`).
- **7x4 (145 cells):** the expanded matrix. `expanded` is true when `force_expanded_matrix`, `news_or_event_strategy`, or a prop deployment target (FTMO/5ERS) is set (`q09_news_runner.py:286`, prop test `q09_news_runner.py:167`). 4 compliance × 7 temporal × 5 seeds = 140 `POLICY_ON`, plus 5 control = **145 cells**. Tagged `matrix_scope="7x4"` (`q09_news_runner.py:339`).

Even when the plan is authored 7x1, the adjudicator can *demand* the 7x4 matrix at collection time: if the DXZ policy shows a **material effect** (or the strategy is news/event-flagged, or the target is prop), and the expanded cells are absent, it returns `REVIEW_REQUIRED` with reason `expanded_7x4_matrix_required` (`q09_news_contract.py:651`). This is exactly the round-6→round-7 escalation in the evidence: a 40-cell 7x1 round adjudicated `expanded_7x4_matrix_required`, and the append-only round-7 row regenerated the 145-cell 7x4 plan with the original 40 identities preserved.

### 1.3 Adjudication verdicts

The three canonical verdicts are `CONFIG_LOCKED, REVIEW_REQUIRED, INVALID_EVIDENCE` (`q09_news_contract.py:62`), enforced as a DB CHECK constraint on `q09_news_tests.verdict` (`q09_news_schema.py:265`).

- **`CONFIG_LOCKED`** — the only "good"/locking verdict. Emitted when a robust policy is selected, or as an explicit `off_fallback_no_robust_improvement` when no policy robustly beats control (chosen mode falls back to `OFF`, `q09_news_contract.py:678`, `q09_news_contract.py:706`). It locks exactly two arms (`CONTROL_OFF` + `POLICY_ON`) with all five seeds (`q09_news_contract.py:684`). Robustness requires: per-seed selection PF > 1, trades ≥ 20, DD ≤ 25%, Q07 seed-stability pass (`q09_news_contract.py:340`); mean selection Δ-Sharpe ≥ 0.06, positive holdout Δ-Sharpe, ≥ 4/5 non-worse pairs, worst-seed DD worsening ≤ 0.05pp (`q09_news_contract.py:369`). Ties break toward the *less interventionist* policy inside an explicit equivalence band (`q09_news_contract.py:408`).
- **`REVIEW_REQUIRED`** — non-locking; Claude review input, never a retry authorization. Adjudicator reasons: `control_or_policy_off_not_qualifiable` (`q09_news_contract.py:633`) or `expanded_7x4_matrix_required` (`q09_news_contract.py:663`). The runner also emits `REVIEW_REQUIRED` for incomplete execution: `cell_execution_failed` or `partial_cell_execution` (`q09_news_runner.py:1309`, `q09_news_runner.py:1323`).
- **`INVALID_EVIDENCE`** — malformed or contradictory evidence. Adjudicator: `contract_invalid`, `required_matrix_cells_missing` (`q09_news_contract.py:603`, `q09_news_contract.py:626`). Runner: `cell_receipt_invalid` (`q09_news_runner.py:1296`). The runner may only ever emit the two non-locking verdicts (`q09_news_runner.py:1200`); it never fabricates `CONFIG_LOCKED`.

A plain `PASS` is **not** a Q09 success verdict — only `CONFIG_LOCKED` is accepted by the DXZ Q10 gate and FTMO admission (see §3, §4).

### 1.4 Persistence model — occurrence ledger + by_work_item view

Q09 sidecar schema is version 3 (`q09_news_schema.py:42`), additive and append-only (BEFORE UPDATE/DELETE triggers reject mutation of every Q09 table).

Persistence separates two lifetimes that a naive design conflated:

- **`q09_news_cells`** — the canonical, globally deduplicated **economic** cell, keyed by the sealed `run_identity_sha256` (`q09_news_schema.py:279`, unique run identity at `q09_news_schema.py:290`). Because run identities are global sealed experiment identities, an append-only rerun of the same plan legitimately re-encounters cells first written by an earlier work item.
- **`q09_news_cell_occurrences`** — the append-only **occurrence ledger** (`q09_news_schema.py:312`). One row per execution records the physical, per-run provenance: `evidence_sha256`, `report_sha256`, `evidence_path`, `report_path`, and `created_at`, keyed by an `occurrence_identity_sha256` (`q09_news_schema.py:313`) hashed over that provenance (`q09_news_schema.py:990`). It never rewrites the canonical cell bytes (`_record_cell_occurrence`, `q09_news_schema.py:973`).
- **`q09_news_cells_by_work_item`** — the compatibility **view** (`q09_news_schema.py:336`) that re-attributes each canonical economic cell to its per-work-item occurrence (newest occurrence wins, `q09_news_schema.py:346`), with a UNION-ALL fallback for canonical cells that have no occurrence row (`q09_news_schema.py:356`). All work-item-scoped readers (Q10 dependency gate `q09_news_schema.py:1277`, qualification trigger `q09_news_schema.py:620`, FTMO admission `portfolio/ftmo_q09_admission.py:89`) consume this view rather than the canonical owner's `q09_news_work_item_id` column.

**Restart idempotency** is achieved by exact-match-or-fail-closed resume. `record_q09_adjudication` (`q09_news_schema.py:1017`) compares only the 14 deterministic fields — identities, seeds, arm/modes, setfile hash, all three metrics JSONs, seed-stability, flat-at-event receipt (`_CELL_DETERMINISTIC_FIELDS`, `q09_news_schema.py:955`) — via `_assert_persistence_match` (`q09_news_schema.py:930`). An identical row is a no-op that lets persistence resume; any deterministic divergence raises a structured `SchemaError` naming the row kind, exact identity, and divergent field names (`q09_news_schema.py:949`). Execution-local `evidence_sha256`/`report_sha256`/paths are **excluded** from that comparison and recorded only in the occurrence ledger — the c8ee2dabe→2a0a0186f fix (see §5, defect classes 3 and 6).

### 1.5 Retry/requeue semantics with ceilings

A **transient cell failure** (`TransientCellError`, `q09_news_runner.py:78`) is specifically a production child exit code 1 that produced *no* fresh run_smoke summary or receipt (`q09_news_runner.py:2063`). It is distinct from a permanent `RunnerError`.

On a transient cell failure the executor (`q09_news_runner.py:2394`):
1. writes the immutable failure sidecar (`q09_news_runner.py:2395`);
2. waits for the exact claimed terminal root to exit (`q09_news_runner.py:2405`, see §1.6);
3. re-authenticates the factory claim and sealed plan (`q09_news_runner.py:2406`);
4. permits **exactly one** same-attempt retry (`q09_news_runner.py:2419`).

If that retry is also transient, and the bounded work-item attempt budget is not exhausted, it raises `CapacityError` **without** collecting or persisting an aggregate (`q09_news_runner.py:2438`) — letting the ordinary worker return the row to `pending` while existing receipts stay resumable. The ceiling is `WORK_ITEM_ATTEMPT_CEILING = 3` (`q09_news_runner.py:64`). "**Bound mixed Q09 transient retries**" (`aabb9f244`) means both the worker's generic `attempt_count` **and** its separately-governed history-lock `transient_infra_attempts` count toward that single ceiling (`q09_news_runner.py:2434`), so a mixed sequence of generic and history-lock retries cannot open a second unbounded retry budget. A permanent failure, or a repeated transient at the ceiling, follows the normal immutable-sidecar → occurrence-persistence → collection → adjudication path (`q09_news_runner.py:2444`, `adjudicate_cell_failure` at `q09_news_runner.py:2320`).

Failure sidecars themselves are append-only and retry-stable: the first is `cell_failure.json`, later same-cell failures append as `cell_failure_2.json`, `cell_failure_3.json`, … (`q09_news_runner.py:1117`), matched by `CELL_FAILURE_SIDECAR_RE` (`q09_news_runner.py:55`). Only 8 stable identity fields are compared across occurrences (`CELL_FAILURE_STABLE_FIELDS`, `q09_news_runner.py:45`); divergent error text or artifact manifests are preserved as evidence but never crash the resumed attempt (`d22dfee9e`, see §5 defect class 5). An authenticated `cell_receipt.json` takes precedence over stale failure sidecars during resume (`q09_news_runner.py:2357`).

### 1.6 Terminal-succession wait

Before every Q09 `run_smoke` child launch the executor runs a read-only gate, `_wait_for_claimed_terminal_exit` (`q09_news_runner.py:1965`, called at `q09_news_runner.py:2044`). It considers only `terminal64.exe` processes whose CIM `ExecutablePath` is path-anchored below the exact claimed `D:\QM\mt5\Tn` directory (`_claimed_terminal_processes`, `q09_news_runner.py:1950`; root resolver `q09_news_runner.py:1887`). Sibling factory terminals, `T_Live`, and FTMO paths never delay the claimed terminal. It waits at most `TERMINAL_EXIT_WAIT_SEC = 180` seconds, polling every `TERMINAL_EXIT_POLL_SEC = 2.0` (`q09_news_runner.py:59`); it never stops a process and never adds `-AllowRunningTerminal`. A timeout raises through the standard executor exception path, producing the immutable failure sidecar (`a51d4faae`, see §5 defect class 4).

### 1.7 Diagnostic non-admission variant and its anchor rules

`q09_live_news_backfill.py` reuses the sealed 7x1/40-cell execution machinery to backfill news-filter validation on the **live book** without ever gating admission. Its differences from the main admission path:

- It binds via `bind_diagnostic_plan_to_work_item` (`q09_news_runner.py:746`), which manufactures **no** Q08 dependency and requires the canonical 40-cell / `7x1_target_compliance` matrix (`q09_news_runner.py:773`). Diagnostic persistence is kept out of `q09_news_tests` entirely (`q09_news_runner.py:823`).
- At persist time, a diagnostic row (`diagnostic_non_admission is True`) is refused if any canonical `q09_news_tests` row exists for it (`q09_news_runner.py:2179`) and is forced to `REVIEW_REQUIRED` with reason `diagnostic_non_admission` regardless of the underlying Q09 adjudication (`q09_news_runner.py:2185`), writing only a sibling `summary.json` under its isolated work-item report root (`q09_news_runner.py:2181`). Diagnostic rows are excluded from cascade promotion.
- Execution is capped to terminals **T1–T5** (`DIAGNOSTIC_ALLOWED_TERMINALS`, `q09_news_runner.py:44`), with a hard exclusion of T6–T10 (`q09_live_news_backfill.py:52`) and at most 5 concurrent diagnostic rows (`q09_live_news_backfill.py:499`). The exact deployed live EX5 is hash-staged under the claiming worker's expert label (`q09_news_runner.py:1439`) and `run_smoke` uses `-SkipExpertDeploy` (`q09_news_runner.py:2315`); T_Live artifacts are read-only.

**Anchor rules** (what pins a diagnostic result so it cannot silently become an admission signal): each sleeve writes an immutable `diagnostic_anchor.json` carrying `schema_version = q09-live-news-diagnostic-anchor/v1` (`DIAGNOSTIC_ANCHOR_SCHEMA`, `q09_news_runner.py:41`), `diagnostic_contract = q09-live-news-backfill/v1` (`DIAGNOSTIC_CONTRACT`, `q09_news_runner.py:43`), and `diagnostic_non_admission = True` (`q09_live_news_backfill.py:393`). The anchor is carried only in the sealed plan's historical `q08_evidence` identity slot so the v2 plan/collector format stays reusable; the binder proves the anchor's contract markers, authenticates a real completed Q07 seed-stability PASS (exact work-item evidence or a `DURABLE_PIPELINE_FALLBACK`, `q09_news_runner.py:871`), matches the anchor's EA/symbol/EX5 to the work item, and requires the payload's non-admission/cap/exact-EX5 controls including `avoid_terminals == {T6..T10}` (`q09_news_runner.py:911`). Any anchor-hash or lineage contradiction fails the bind closed (`q09_news_runner.py:819`). Append-only reruns (`q09_live_news_backfill.py:942`), fresh-build generation-2 reruns (`q09_live_news_backfill.py:1315`), and generation-3 transient reruns (`q09_live_news_backfill.py:699`) each reuse the exact predecessor anchor hash — because that hash is part of every sealed cell identity — and carry rerun lineage in the new work-item payload rather than rewriting the anchor and silently defining a different experiment.

The runtime-policy basis for the live book is **preset omission plus compiled-default inheritance**, not loaded chart bytes: all 17 source presets carry the historical no-op lines `qm_filter_news_enabled=1`/`qm_filter_news_mode=3` and pin none of the four current `qm_news_*` inputs, so the effective live policy is the EA source default `PRE30_POST30/DXZ/HIGH/336` (temporal id 3, compliance id 1) — the diagnostic's nearest sealed cell (verified against evidence doc `2026-08-05_live_book_news_policy_diagnostic_backfill.md`, not runtime state).

---

## 2. Operational Playbook

### 2.1 What each verdict means for the gate-walk

| Verdict | Gate-walk consequence |
|---|---|
| `CONFIG_LOCKED` | The **only** verdict that advances the chain. On the DXZ side it may open a fresh same-Q08 `Q09_PORTFOLIO` row; only a resulting `PASS_PORTFOLIO` may open a Q10 append-only rerun (`assert_q10_dependency_gate`, `q09_news_schema.py:1237`). On the FTMO side it is a precondition for admission (§4). Locks two arms + five paired seeds. |
| `REVIEW_REQUIRED` | Stops the chain. It is Claude review input, **never** a retry authorization. `expanded_7x4_matrix_required` specifically directs an append-only 7x4 expansion round; other reasons (`control_or_policy_off_not_qualifiable`, `cell_execution_failed`, `partial_cell_execution`) require human classification of transient vs. structural cause. |
| `INVALID_EVIDENCE` | Stops the chain. Immutable evidence contradiction (`cell_receipt_invalid`) or malformed experiment (`contract_invalid`, `required_matrix_cells_missing`). Never self-heals; needs a fresh sealed plan/round. |

No downstream row (Q09_PORTFOLIO, Q10, or the next serial candidate) is created on any verdict other than a genuine `CONFIG_LOCKED` followed by a fresh same-lineage `PASS_PORTFOLIO`.

### 2.2 Known transient classes and self-heal behavior

| Class | Self-heals via retry? | Operator note |
|---|---|---|
| Child exit-1 with no fresh summary/receipt (`TransientCellError`) | Yes — one bounded same-attempt retry after terminal-exit wait, then bounded requeue up to attempt ceiling 3 | Genuine tester flake / transport. Sidecars preserved; receipts resume. |
| Same-terminal window succession ("terminal already running") | Yes — the pre-launch wait gate (§1.6) absorbs a lagging terminal exit up to 180s | Was round-5's terminal stop; fixed by `a51d4faae`. A 180s timeout converts to a fail-closed sidecar. |
| Logger reset between selection→holdout windows | Yes, once `-RequireFreshLoggerSample` is in effect | Fixed by `744d6111f`; a rewritten logger is refused, not silently published. |
| Cross-round persistence divergence (`SchemaError: Q09 persistence divergence`) | Fixed at source — no longer occurs for provenance-only differences | Pre-`2a0a0186f` this consumed generic retry budget deterministically. If it recurs now, it signals **genuine economic non-determinism** and requires investigation, not retry. |
| `--period` argparse refusal, malformed dispatch command | No — structural. Requires a code/command-composition fix | Round-1 fail; fixed by `e21136822`. |
| Transient at the attempt ceiling, or any permanent `RunnerError` | No — terminalizes as `REVIEW_REQUIRED`/`INVALID_EVIDENCE` | Requires review/new sealed round, not in-place retry. |

Retry ceilings (from Codex forensics, verified against `WORK_ITEM_ATTEMPT_CEILING`): generic `attempt_count` ceiling 3; the shared history-lock `transient_infra_attempts` ceiling is 6, but both counters are jointly bounded against the Q09 ceiling by `aabb9f244` (`q09_news_runner.py:2434`).

### 2.3 How to read q09_plan trees

There is no dedicated "plan-tree" renderer; a plan is read from its on-disk JSON structure plus two status commands.

- **`run_plan.json`** (built at `q09_news_runner.py:344`) contains: `schema_version`, `work_item_id`, `candidate_lineage_key`, `input_manifest_path` + `input_manifest_sha256`, `matrix_scope` (`7x1_target_compliance` or `7x4`), `target_compliance`, `cell_count`, `cells[]`, and `plan_sha256`. Each cell (`q09_news_runner.py:314`) has `arm`, `temporal_mode`, `compliance_mode`, `seed`, `run_identity_sha256`, `setfile_path` + `setfile_sha256`, and `receipt_path`.
- **Cell directory naming** (`q09_news_runner.py:299`): `cells/{arm.lower()}__m{temporal_id}__c{compliance_id}__s{seed}`, e.g. `control_off__m0__c0__s42` or `policy_on__m3__c1__s17`. Temporal ids: OFF=0, PRE30=1, PRE60=2, PRE30_POST30=3, PRE60_POST60=4, SKIP_DAY=5, CLOSE_ALL_PRE=6 (`q09_news_contract.py:46`). Compliance ids: NONE=0, DXZ=1, FTMO=2, 5ERS=3 (`q09_news_runner.py:56`). A completed cell holds `cell_receipt.json` + `cell_evidence.json` + `report_manifest.json`; a failed cell holds `cell_failure*.json` instead.
- **Status of a sealed plan:** `python tools/strategy_farm/q09_news_runner.py collect --plan <run_plan.json>` runs `collect_run_plan_status` (`q09_news_runner.py:1253`), which reports planned/authenticated/failed/missing/invalid cell counts and the resulting non-locking verdict without executing testers.
- **Status of the diagnostic campaign:** `python tools/strategy_farm/q09_live_news_backfill.py status` runs `campaign_status` (`q09_live_news_backfill.py:1706`), which enforces the concurrency/terminal cap, asserts zero canonical `q09_news_tests` rows, and writes `campaign_status.json`.
- **DB view for cell attribution:** query `q09_news_cells_by_work_item` (never the canonical `q09_news_cells.q09_news_work_item_id` column) to see which cells a given work-item round owns, including reused cross-round identities.

---

## 3. OWNER Semantics

The Q09 news-gate usage was ratified by OWNER on 2026-08-04 across two contracts.

### 3.1 Ratified news-gate decision (FTMO consumption contract, router `b2770c48`)

Source: `docs/ops/evidence/2026-08-04_ftmo_q09_news_consumption_contract.md` (router task `b2770c48-5cad-4b87-9cbc-b0aed0e41bff`, verified line 3 of that doc). OWNER re-ratified the original Q09_NEWS consumption rules (framed as "FTMO-safe?"):

1. an EA that is not prop-firm/FTMO-safe is **excluded** from the FTMO portfolio; and
2. when performance is **worse on news days**, the locked temporal recommendation must **block** those news periods in the consumed configuration — this is exactly the A/B-backtest → recommendation logic the adjudicator implements (news-OFF control vs. news-ON temporal modes, selecting a robust blackout policy or falling back to OFF).

The consumer is fail-closed and additive: **absence is exclusion**. Principal reason codes: `FTMO_Q09_EVIDENCE_MISSING`, `FTMO_Q09_NOT_CONFIG_LOCKED`, `FTMO_Q09_EVIDENCE_UNAUTHENTICATED`, `FTMO_Q09_SCOPE_NOT_FTMO`, `FTMO_Q09_FTMO_CELLS_INCOMPLETE`, `FTMO_Q09_FTMO_CONFIG_NOT_VIABLE`, `FTMO_Q09_ADMITTED` (`portfolio/ftmo_q09_admission.py:35`).

### 3.2 DXZ consumption is enforced

DXZ consumption of Q09 verdicts is enforced through the pipeline schema, not left advisory: the Q10 dependency gate requires the bound `Q09_NEWS` parent to be `CONFIG_LOCKED` with matching evidence hash and complete paired five-seed arms (`assert_q10_dependency_gate`, `q09_news_schema.py:1262`), and the `candidate_qualifications` insert trigger requires `q09n.verdict='CONFIG_LOCKED'` plus the two-arm lock and five-seed cell counts for any `QUALIFIED` row (`q09_news_schema.py:602`, `q09_news_schema.py:607`). A plain `PASS` is rejected; `REVIEW_REQUIRED`/`INVALID_EVIDENCE` remain non-locking (activation/Q10 contract, `2026-08-04_q09_news_activation_and_q10_contract.md`).

### 3.3 FTMO consumption ticket

The additive FTMO-side consumer is `tools/strategy_farm/portfolio/ftmo_q09_admission.py` (router task **`b2770c48`**). Admission requires the latest completed `Q09_NEWS` row to be `CONFIG_LOCKED`, its aggregate to authenticate (path/SHA + embedded adjudication hash), and either a `7x1_target_compliance` matrix that directly targets FTMO **or** a complete `7x4` matrix whose FTMO cells for `chosen_temporal` are viable under the Q09 selection floor (`portfolio/ftmo_q09_admission.py:172`). The admitted deployment always carries the locked `chosen_temporal` and forces FTMO compliance, even when the source 7x4 row was adjudicated for DXZ (`portfolio/ftmo_q09_admission.py:290`); a DXZ-only 7x1 row does not prove FTMO coverage. This consumer changes no DXZ gate and synthesizes no pipeline verdict.

### 3.4 Activation requires an OWNER window

Source: `docs/ops/evidence/2026-08-04_q09_news_activation_and_q10_contract.md` (router `b0bbc95d-1b16-4211-99fc-88dd9bfa872b`, verified line 5 of that doc). Turning the gate on "for real" requires an OWNER-approved window:

1. OWNER ratifies the exact content-addressed **`q09cal-*` bundle** (`q09cal-20150101-20260809-0bb19b5bb9790b76`, confirmed live in `q09_live_news_backfill.py:360` and multiple evidence docs) derived from the governed calendar publication, and review produces the exact recursive include-closure manifest per current EX5.
2. `farmctl.py` is part of the Factory runtime-decision source binding; the additive edits deliberately do not satisfy that decision, and a read-only validation fails closed with a SHA-256 mismatch. **A future Factory activation/restart requires a fresh OWNER-ratified runtime decision that binds the landed source bytes (manifest remint).**
3. The broader W7 migration/apply programme remains `DRY_RUN_SOURCE_IMPLEMENTED_OWNER_APPLY_BLOCKED`; the general calendar publication is not silently promoted to the sealed q09cal contract.

The append-only bridge (enqueue Q09_NEWS rerun → require `CONFIG_LOCKED` → fresh same-Q08 `PASS_PORTFOLIO` → Q10 rerun, serially per candidate) stops on every refusal or non-good verdict.

---

## 4. Defect-Class Ledger

| Class | Commit(s) | Evidence Doc | One-line description |
|---|---|---|---|
| Sealed-period dispatch (PT3) | `e21136822` | `docs/ops/evidence/2026-08-04_q09_news_book_candidate_execution.md` | Executor now derives the tester period from the hash-bound Q08 baseline and the farmctl bridge no longer strips `--period` from Q09, fixing the argparse-refusal fail-closed stop. |
| Multi-window logger isolation | `744d6111f` | `docs/ops/evidence/2026-08-04_q09_news_book_candidate_execution.md` | `-RequireFreshLoggerSample` archives/verifies each window's EA logger so a selection→holdout logger reset can no longer silently publish a Q09-usable summary; adds row-bound `cell-failure/v1` evidence. |
| Restart-idempotent persistence | `c8ee2dabe` | `docs/ops/evidence/2026-08-04_q09_news_book_candidate_execution.md`, `2026-08-05_q09_persist_divergence_claude_forensics.md`, `2026-08-05_q09_persist_divergence_codex_forensics.md` | Final sidecar transaction accepts an existing summary/cell only after every immutable content field matches; any contradiction fails closed with named divergent fields (no overwrite). |
| Same-terminal window succession | `a51d4faae` | `docs/ops/evidence/2026-08-04_q09_news_book_candidate_execution.md` | Pre-launch read-only gate waits up to 180s for `terminal64.exe` under the exact claimed terminal root to exit, closing the "terminal already running" succession race without stopping any process. |
| Retry-stable failure sidecars | `d22dfee9e` | `docs/ops/evidence/2026-08-05_q09_cell_failure_retry_stability.md`, `2026-08-05_q09_persist_divergence_codex_forensics.md` | First failure stays immutable as `cell_failure.json`; later same-cell failures append as `cell_failure_2.json`…; only 8 stable identity fields compared, so divergent error text can't crash the resumed attempt; receipts still precede stale sidecars. |
| Cross-round provenance / occurrence ledger | `2a0a0186f` | `docs/ops/evidence/2026-08-05_q09_cross_round_provenance_and_round6_stop.md`, `2026-08-05_q09_persist_divergence_claude_forensics.md`, `2026-08-05_q09_persist_divergence_codex_forensics.md` | Splits globally-deterministic economic identity from work-item-local provenance: canonical `q09_news_cells` stays deduped, per-execution evidence/report hashes+paths move to append-only `q09_news_cell_occurrences`, readers use the `by_work_item` view — cross-round reruns no longer deterministically die at persist. |
| Bounded transient retry/requeue with ceilings | `a20ded0c4` + `aabb9f244` | `docs/ops/evidence/2026-08-04_q09_news_book_candidate_execution.md`, `docs/ops/evidence/2026-08-05_live_book_news_policy_diagnostic_backfill.md` | A child exit-1/no-receipt is a transient cell failure: one bounded same-attempt retry after terminal-exit wait, else a `CapacityError` requeue with no aggregate; generic `attempt_count` and history-lock `transient_infra_attempts` are jointly bounded by the attempt-3 ceiling. |
| Diagnostic non-admission variant | `q09_live_news_backfill.py` (reruns via `589e170f9`, `6bed121bb`) | `docs/ops/evidence/2026-08-05_live_book_news_policy_diagnostic_backfill.md` | Reuses the sealed 7x1/40-cell machinery to backfill live-book news validation while forcing `REVIEW_REQUIRED`, staying out of `q09_news_tests`, capping to T1–T5, and anchoring every result as explicit non-admission. |

---

## 5. Related Documents

- `docs/ops/evidence/2026-08-04_q09_news_book_candidate_execution.md` — round-by-round governed execution ledger (sealed-period, logger-isolation, restart-idempotence, terminal-succession, transient-retry rounds).
- `docs/ops/evidence/2026-08-04_q09_news_activation_and_q10_contract.md` — activation-hold contract, `CONFIG_LOCKED`-only success verdict, OWNER activation-window / q09cal-bundle / runtime-decision remint requirement.
- `docs/ops/evidence/2026-08-04_ftmo_q09_news_consumption_contract.md` — OWNER-ratified FTMO consumption semantics; fail-closed admission predicate (router `b2770c48`).
- `docs/ops/evidence/2026-08-05_q09_cell_failure_retry_stability.md` — `d22dfee9e` retry-stable numbered failure sidecars.
- `docs/ops/evidence/2026-08-05_q09_cross_round_provenance_and_round6_stop.md` — `2a0a0186f` occurrence-ledger repair, round-6 `expanded_7x4_matrix_required` stop, round-7 7x4 handoff.
- `docs/ops/evidence/2026-08-05_q09_persist_divergence_claude_forensics.md` — Claude independent persist-divergence forensics (single-cell file-level proof).
- `docs/ops/evidence/2026-08-05_q09_persist_divergence_codex_forensics.md` — Codex independent forensics + Phase-B cross-review (matrix-wide/live-system closure, joint verdict: root cause confirmed / fix complete / no evidence damage).
- `docs/ops/evidence/2026-08-05_live_book_news_policy_diagnostic_backfill.md` — diagnostic non-admission campaign, anchor rules, generation-2/3 reruns, transient-recovery cutover.
