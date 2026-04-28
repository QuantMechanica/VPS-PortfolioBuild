---
dl: DL-038
date: 2026-04-28
title: Seven Binding Backtest Rules — .DWX-only / 36-symbol / 5-MT5-parallel / fail-fast-next / EA-on-all-terminals / Drive-resource Tier 1.5 / fixed-risk set file
authority_basis: OWNER directive 2026-04-28 ~11:15 local (relayed via Board Advisor) + DL-023 (CEO broadened-autonomy waiver, class 4 — internal process choices → factory rules-of-engagement); OWNER directive ratifies the rule set itself
recording_issue: QUA-422
companion_to: DL-029 (Rule 4 fail-fast operationalises DL-029 "all blocked except the first" pattern); DL-035 (Rule 3 binds the parallel-fleet floor on the existing dispatch policy); DL-036 (Rule 5 review prerequisite). Canonical operator-facing spec: [`processes/16-backtest-execution-discipline.md`](../processes/16-backtest-execution-discipline.md)
status: active
---

# DL-038 — Seven Binding Backtest Rules (OWNER 2026-04-28)

Date: 2026-04-28
Source directive: OWNER directive 2026-04-28 ~11:15 local (verbatim 7 rules)
Parent issue: [QUA-400](/QUA/issues/QUA-400) — consolidated 7-rule directive
Recording issue: [QUA-422](/QUA/issues/QUA-422) (CEO/G child) — DL recording sibling
Process recording: [QUA-426](/QUA/issues/QUA-426) (Doc-KM) — `processes/16-backtest-execution-discipline.md`
Owner: CEO (`7795b4b0-8ecd-46da-ab22-06def7c8fa2d`) — convention; Pipeline-Operator + DevOps + Research + CTO — execution
Recorder: Documentation-KM (`8c85f83f-db7e-4414-8b85-aa558987a13e`)
Authority: [DL-023](./2026-04-27_ceo_autonomy_waiver_v2.md) — class 4 "internal process choices → factory rules-of-engagement", plus the OWNER directive ratifying the rule set itself
Status: Active. Binding for all V5 phases (P1 → P10), all `.DWX` backtest runs, all factory terminals (T1–T5). T6 explicitly out of scope.

> **Recorder's note (Doc-KM scope per BASIS).** This DL records the seven binding rules CEO ratified under broadened-authority on 2026-04-28 in response to OWNER directive ~11:15 local. The full operator-facing spec — actor table, per-rule tooling, dispatch flow, acceptance signals — is the canonical [`processes/16-backtest-execution-discipline.md`](../processes/16-backtest-execution-discipline.md) authored under QUA-426. This DL is the at-a-glance ADR for cross-reference; the process file is the operational source of record.

## Decision

Seven concrete operational constraints govern V5 strategy backtesting from 2026-04-28 onward. Some restate spec already in `framework/V5_FRAMEWORK_DESIGN.md` (`.DWX` suffix, fixed-risk ENV); others elevate prior partial practice (round-robin parallelism, full-fleet EA deploy) to binding. Together they form the backtest-execution discipline.

### Rule 1 — Test ONLY on `.DWX` symbols

Every backtest run uses the `.DWX`-suffixed custom symbols, never native broker symbols. Codifies `framework/V5_FRAMEWORK_DESIGN.md` § ".DWX suffix discipline" as binding for all phases including smoke. P2 baseline INI generation must validate `Symbol=*.DWX` before dispatch; reject INIs targeting native symbols. Pipeline-Op enforces. Job validator: `framework/scripts/pipeline_dispatcher.py` → `validate_job` rejects non-`.DWX` symbols.

### Rule 2 — Backtest on ALL 36 `.DWX` symbols

Every EA gets backtested across the full 36-symbol `.DWX` universe per phase. Not one-symbol-only. The strategy survives a phase if at least N symbols PASS (Quality-Tech sets N per-phase per `PIPELINE_V5_SUB_GATE_SPEC.md`; default starts at `>= 1` PASS for P2 baseline). Pipeline-Op backtest matrix per EA per phase = `(36 .DWX symbols) × (1 EA)` = 36 runs distributed across T1–T5. Matrix payload validator: `framework/scripts/pipeline_dispatcher.py` → `validate_matrix_payload` requires exactly 36 symbols, all `.DWX`.

### Rule 3 — All 5 MT5 instances run in parallel

QUA-307 already codified the round-robin + 3-cap-per-terminal × 5 = 15 concurrent ceiling. Currently only T1 and T2 have EAs deployed; T3, T4, T5 sit idle (verified 2026-04-28 ~11:15 — `D:\QM\mt5\T3\MQL5\Experts\QM\` does not exist). Rule 3 mandates that all five participate. Verify: all `.ex5` EAs are present on T1 + T2 + T3 + T4 + T5 simultaneously. DevOps owns the deploy step (Rule 5). Dispatch policy is [DL-035](./2026-04-28_pipeline_loadbalance_convention.md) (least-loaded round-robin + symbol-affinity tie-break).

### Rule 4 — Fail-fast: jump to next strategy on phase failure

If a strategy fails its current phase verdict (e.g. P2 baseline produces 0 PASS symbols), Pipeline-Op aborts remaining phases for that strategy and unblocks the NEXT sub-issue under the same SRC parent (per [QUA-236](/QUA/issues/QUA-236) / [DL-029](./DL-029_strategy_research_workflow.md) "all blocked except the first" pattern — failure of the active sub-issue triggers the next sibling to unblock). Pipeline-Op writes `verdict: FAIL_PHASE_<X>` + `next_strategy_unblocked: SRC<NN>_S<n+1>` to `dedup_index.json`. CEO confirms unblock-on-fail behaviour.

### Rule 5 — Every EA available on ALL 5 MT5 instances

When Development scaffolds + CTO review-passes a new EA (`<filename>.ex5`), it must be deployed to:

- `D:\QM\mt5\T1\MQL5\Experts\QM\<filename>.ex5`
- `D:\QM\mt5\T2\MQL5\Experts\QM\<filename>.ex5`
- `D:\QM\mt5\T3\MQL5\Experts\QM\<filename>.ex5`
- `D:\QM\mt5\T4\MQL5\Experts\QM\<filename>.ex5`
- `D:\QM\mt5\T5\MQL5\Experts\QM\<filename>.ex5`

DevOps owns the deploy script: `framework/scripts/deploy_ea_to_all_terminals.ps1 -EaPath <abs path>` — copies + creates dirs + verifies SHA256 match across all 5. Idempotent. Mandatory step of every Development build close.

### Rule 6 — Drive `QuantMechanica` strategy resource is V5 INPUT (concepts-only, not backtest results)

OWNER 2026-04-28 (verbatim): *"In Google Drive Quantmechanica you also will find a good strategy resource (but don't take the backtest results from there!)"*

Locations:

- `G:\My Drive\QuantMechanica\Company\Research\strategies\` — V4-era research output (highest signal for strategy CONCEPTS)
- `G:\My Drive\QuantMechanica\MT5 Marketplace\` — V4 SM_XXX strategy folders (e.g. `SM_124_Gotobi`, `SM_128_NexusGoldMR`)
- `G:\My Drive\QuantMechanica\Website\strategy-database\strategies\` — strategy database for the website
- `G:\My Drive\QuantMechanica\Backups\`, `Archive\`, `Reviews\` — V4 historical artifacts

Discipline (binding per OWNER + V5 clean-slate rule):

- Research treats these as **inspiration / concept references**, not as direct V5 inputs.
- Every V5 Strategy Card produced from a Drive document MUST cite the original book / paper / blog the V4 doc itself cited — NOT the V4 doc as primary source. If V4 doc is uncited, the strategy is `C-tier` and `BLOCKED_NO_PRIMARY_SOURCE` until traceable.
- **Backtest results from V4 are NEVER cited** (per OWNER) and NEVER imported as PASS evidence into V5. V5 PASS is what V5 produces from its own pipeline.
- V4 SM_XXX names stay V4-namespace. Any V5 EA that re-implements a V4-flavoured strategy gets a fresh V5 `ea_id` (1000–9999) per `framework/V5_FRAMEWORK_DESIGN.md` § ea_id range.

Add this resource pool to Research's source taxonomy as **Tier 1.5** — between T1 (OWNER PDFs) and T2 (named public containers). Process after T1 (PDFs) but before T2 (Babypips / Forex Factory / etc.).

### Rule 7 — Backtest ENV uses `RISK_FIXED` (not `RISK_PERCENT`)

Restates `framework/V5_FRAMEWORK_DESIGN.md` § Risk Sizing — Dual Mode + ENV Convention:

> Backtest = `RISK_FIXED` (default $1000). Live = `RISK_PERCENT`. Both inputs always present. The set-file ENV (`backtest` / `demo` / `shadow` / `live`) determines which mode is active by default; the other input must be 0. Hard-fail per `EA_INPUT_RISK_MODE_MISMATCH`.

Current gap: `QM5_SRC04_S03_lien_fade_double_zeros.ex5` ran without an explicit set file. The `.ex5` hardcoded defaults probably have `RISK_FIXED=1000`, `RISK_PERCENT=0` per the framework, but **without an explicit `<EA>_<symbol>_<TF>_backtest.set` file the ENV-mismatch check doesn't run**.

Verify: every Pipeline-Op P2 dispatch must reference a `<EA>_<symbol>_<TF>_backtest.set` file (per `framework/V5_FRAMEWORK_DESIGN.md` § Set file naming). The set file must contain `ENV=backtest`, `RISK_FIXED=1000`, `RISK_PERCENT=0`. Pipeline-Op refuses to dispatch if missing. DevOps owns the generator (`framework/scripts/gen_setfile.ps1`).

## Owner-per-rule mapping

Each rule has a child issue under QUA-400 driving operationalisation. Acceptance for the parent directive lives on QUA-400 itself.

| Rule | Owner | Child issue | Status as of 2026-04-28 |
|---|---|---|---|
| Rule 1 (.DWX-only) + Rule 2 (36-symbol) + Rule 4 (fail-fast) | Pipeline-Op | [QUA-414](/QUA/issues/QUA-414) (P0 dispatcher) + [QUA-421](/QUA/issues/QUA-421) (matrix dispatcher) | in_progress / blocked |
| Rule 3 (5-MT5-parallel) | Pipeline-Op (round-robin already shipped via QUA-307 / [DL-035](./2026-04-28_pipeline_loadbalance_convention.md)) + DevOps (Rule 5 dependency) | covered by Rule 5 deploy + QUA-307 | done (load-balancer); rule 3 unlocks once Rule 5 ships |
| Rule 5 (EA on T1-T5) | DevOps | [QUA-413](/QUA/issues/QUA-413) (deploy script + 4-EA deploy) + [QUA-411](/QUA/issues/QUA-411) / [QUA-412](/QUA/issues/QUA-412) (rollout) | in_progress |
| Rule 5 retroactive review | CTO | [QUA-417](/QUA/issues/QUA-417) (review-only policy) + [QUA-424](/QUA/issues/QUA-424) (QM5_SRC04_S03 retroactive review) | done |
| Rule 6 (Drive QuantMechanica Tier 1.5) | Research | [QUA-416](/QUA/issues/QUA-416) (SOURCE_QUEUE update) + [QUA-423](/QUA/issues/QUA-423) (survey-pass) | in_review / in_progress |
| Rule 7 (set-file ENV) | DevOps + Pipeline-Op | [QUA-415](/QUA/issues/QUA-415) (gen_setfile.ps1 + dispatch refusal) + [QUA-419](/QUA/issues/QUA-419) (rollout) | todo |
| Process codification (all 7 rules) | Doc-KM | [QUA-418](/QUA/issues/QUA-418) (`processes/16-backtest-execution-discipline.md` draft) + [QUA-426](/QUA/issues/QUA-426) (canonical publish + DL recording) | in_progress |
| DL recording (this doc) | CEO | [QUA-422](/QUA/issues/QUA-422) | this commit (Doc-KM author per DL-028 worktree convention) |

## Boundary

- T6 OFF LIMITS as ever — none of these rules apply to T6 live deploys ([DL-025](./DL-025_t6_deploy_boundary_refinement.md)).
- V4 SM_XXX EAs / sleeves / set names stay V4 namespace. V5 reimplementations get fresh `ea_id`s (1000–9999).
- Backtest results from V4 / Drive are NOT V5 PASS evidence per OWNER. V5 produces its own PASS evidence via its own pipeline.

## Cross-links

- [DL-023](./2026-04-27_ceo_autonomy_waiver_v2.md) — authority basis for CEO recording this without Board pre-approval (class 4: factory rules-of-engagement).
- [DL-025](./DL-025_t6_deploy_boundary_refinement.md) — T6 boundary preserved verbatim. None of the seven rules cross into T6.
- [DL-029](./DL-029_strategy_research_workflow.md) — Rule 4 (fail-fast unblock-next) operationalises DL-029's "all blocked except the first" pattern under SRC parents.
- [DL-035](./2026-04-28_pipeline_loadbalance_convention.md) — Rule 3 (5-MT5-parallel) inherits the dispatch policy DL-035 codified (least-loaded round-robin + symbol-affinity tie-break + binding de-dup tuple).
- [DL-036](./2026-04-28_ea_review_gate.md) — Rule 5 (EA on T1–T5) is gated upstream by the EA Review-only policy on every `SRC*_S* — APPROVED card → P1..P10 pipeline run` issue.
- QUA-307 — parent of Rule 3's load-balancing implementation (round-robin + 3-cap × 5 terminals = 15 concurrent ceiling). Already shipped; Rule 3 elevates the ceiling-utilisation expectation from "available" to "binding".
- QUA-236 — Strategy research workflow OWNER directive that Rule 4 inherits.
- `framework/V5_FRAMEWORK_DESIGN.md` § ".DWX suffix discipline" (Rule 1) / § "Risk Sizing — Dual Mode + ENV Convention" (Rule 7) / § "Set file naming" (Rule 7) / § "ea_id range" (Rule 6 V5 reimplementation).
- `processes/16-backtest-execution-discipline.md` — Doc-KM canonical operator-facing process doc covering all 7 rules (committed in this same close-out under QUA-426).
- DL-027 propagation classification: `reference_only` — no agent prompt body change. Process discoverability comes via `process_registry.md` § "Backtest Execution Discipline (DL-038)".

## Why this is binding (not just guidance)

OWNER's 2026-04-28 ~11:15 directive consolidated seven concrete constraints across previously-fragmented spec (`.DWX` suffix, RISK_FIXED ENV) and previously-aspirational practice (T3-T5 idle, single-symbol backtests, no set-file gate). The fragmentation produced concrete failures:

- `QM5_SRC04_S03` (Lien double-zero fade) ran on 1 symbol with no explicit set file — Rules 1, 2, 5, 7 all violated in a single dispatch.
- T3-T5 sat idle for the entire SRC04 cohort — Rules 3 + 5 violated by absence.
- V4 doc citations leaked into Strategy Cards as primary sources — Rule 6 violated by ambiguity.

Codifying as a binding rule set means Pipeline-Op and DevOps have hard-fail gates, not soft conventions. Aligns with the V5 hard-rule pattern (`.DWX` suffix, Friday Close default, ML ban, magic-formula registry) that DL-025 preserved at the framework level.

## Implications

- Pipeline-Op dispatcher must be matrix-aware (36-symbol fan-out) before any new SRC card P2 dispatch lands. QUA-414 + QUA-421 unblock the matrix dispatcher; QUA-415 + QUA-419 add the set-file gate.
- DevOps deploy script ([QUA-413](/QUA/issues/QUA-413)) is on the critical path for Rule 3 utilisation — until T3-T5 have the EAs, the 15-cap is a 6-cap (T1 + T2 only).
- Research source taxonomy gains a Tier 1.5 row (Drive QuantMechanica) — slots between T1 PDFs and T2 public containers in the SOURCE_QUEUE order. Already in flight on [QUA-416](/QUA/issues/QUA-416) / [QUA-423](/QUA/issues/QUA-423).
- CTO Review-only execution policy ([QUA-417](/QUA/issues/QUA-417), DL-036) covers Rule 5's "every EA review-passed before deploy" requirement; [QUA-424](/QUA/issues/QUA-424) already retroactively closed the QM5_SRC04_S03 review gap.
- Doc-KM `processes/16-backtest-execution-discipline.md` ([QUA-426](/QUA/issues/QUA-426)) is the operator-facing canonical reference. Process registry links to it.

## Reversal / lifecycle

DL-038 stays "active" while the V5 factory operates on the 36-symbol .DWX matrix. If the universe expands (more `.DWX` symbols added) or contracts, the rule body for Rule 2 updates and a successor DL-NNN records the new constant. Rules 3 + 5 are coupled — if a future hardware change adds T6/T7 to the factory (currently T6 = live only, OFF LIMITS), CEO files a successor DL extending the parallel discipline.

## Materialisation

- `decisions/2026-04-28_seven_backtest_rules.md` (this file) — canonical document.
- `decisions/REGISTRY.md` — DL-038 row + cross-link rows added in this commit.
- `processes/16-backtest-execution-discipline.md` — operator-facing process doc (companion).
- `processes/process_registry.md` — registry pointer added in this commit.

— CEO operational ratification under DL-023 broadened-autonomy waiver, ratifying OWNER directive 2026-04-28 ~11:15 local. Recorded by Documentation-KM 2026-04-28 on `agents/docs-km` per DL-028 worktree convention.
