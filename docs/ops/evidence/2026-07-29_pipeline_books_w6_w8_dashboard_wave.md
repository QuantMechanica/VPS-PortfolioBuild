# Pipeline Books W6-W8 and dashboard continuation evidence

Date: 2026-07-29
Scope: source implementation, read-only production census, isolated compile checks and generated status surfaces
Authority: `SOURCE_STATUS_ONLY_NO_RUNTIME_AUTHORITY`

## Safety boundary

- The Factory remains intentionally OFF. This wave does not authorize or perform Factory ON, scheduler enablement, task enqueue, MT5 launch, AutoTrading changes, deployment, FTMO purchase or trading.
- Productive SQLite inspection used URI `mode=ro` plus `PRAGMA query_only=ON`. The production database was not migrated or mutated.
- Q08 v3 remains shadow-only and not OWNER-approved. Historical Q08 rows are inventoried, not rewritten.
- The DXZ and FTMO target lanes remain `NOT_EVALUATED`; every deployment, purchase and trading action remains `NONE`.
- The two generated HTML targets are projections of a repository-owned, hash-bound status contract. They do not grant runtime authority.

## W6 — partial source implementation

Implemented source controls:

1. `QM_RuntimeExecutionContract.mqh` adds an immutable opt-in, one-way V3 runtime identity contract covering EA ID, magic, symbol, timeframe, account/server identity, card, bundle, rulepack and the exact magic-registry hash. Contract generation must equal a separately supplied positive source generation. Reinitialization/rebinding blocks the process; the only reset symbol is compiled under `QM_RUNTIME_EXECUTION_TESTING`. Legacy EAs remain explicitly `LEGACY_UNDECLARED`; there is no fleet-complete claim.
2. `QM_Common.mqh` exposes the additive `QM_FrameworkInitV3` entry point and arms `REQUIRED_BLOCKED` before framework side effects. A legacy initializer cannot downgrade an armed or ready V3 process.
3. `QM_Entry.mqh` validates the V3 contract at every entry boundary and restricts the current V3 schema to its exact single EA/symbol/magic identity. It requires a fresh account-wide FTMO governor decision for FTMO-bound V3 entries. A governor may only reduce, never enlarge, requested risk.
4. `QM_RiskSizer.mqh` uses directional `OrderCalcProfit` loss in account currency at a legal reference lot. Any snapshot fallback is explicit and visible; the existing margin cap remains in force.
5. `update_magic_resolver.py` is strict by default. Missing active EA directories abort replacement; `--allow-dropped` is an explicit, visible recovery escape hatch.
6. `QM_BasketOrder.mqh` applies the same V3 identity, directional risk, broker-margin and FTMO-governor rails to basket submissions. The current single-identity schema refuses alternate EA IDs, symbols and magics; a real multi-identity V3 basket requires a later versioned contract. Legacy basket compatibility remains explicit.
7. `windows_job_object.py` creates both runner launch paths suspended and performs exact retained-handle assignment, immutable identity capture and registry retention before resuming the sole primary thread. Assignment, identity, registry or resume failures close the kill-on-close Job and kill/wait the spawned process. Handles remain held while `ActiveProcesses` is non-zero, so root-process exit does not orphan a surviving child tree; query failures retain containment state fail-closed.
8. `mt5_history_isolation.py` is a read-only topology audit with a pure evaluator. It detects exact and ancestor/descendant overlap across terminals/components and symmetric overlap with protected T5/T_Live roots. The observed production topology is `FAIL_CLOSED`: 27 inventory rows, one exact cross-terminal collision and eight cross-terminal ancestor overlaps. Audit SHA-256: `b00efde1c0dfdb4cbb189e8f60ec0f8c4ff1bbaa7e1a98fc2ffeabb31e9ea325`.
9. `work_item_lifecycle_v2.py` provides a typed, deterministic read-only lifecycle projection with disjoint explicit verdict classes and unknown-verdict rejection. Against database SHA-256 `28c3eac195c2aeb778f2d677679990949f124f05407d8f9116f7ed30be8f6cc5`, the productive census covered 104,120 rows with plan SHA-256 `4527d105d2c7f239f4509f8e2da29c8ed3182c2d841df116643048ee1575636b`: ACTIVE 0, BLOCKED 28, FAILED 77,314, PENDING 2,175, QUARANTINED 165, SUCCEEDED 24,425, WAITING_INPUT 13.

Isolated MetaEditor checks used a disposable worktree-local compiler/include tree. All staged sources, EX5 files and logs were removed after their final result lines were re-read:

- `risk_sizer_smoke.mq5`: 0 errors, 0 warnings.
- `runtime_execution_contract_smoke.mq5`: 0 errors, 0 warnings.
- `entry_execution_identity_smoke.mq5`: 0 errors, 0 warnings.
- `basket_order_execution_policy_smoke.mq5`: 0 errors, 0 warnings.
- legacy basket `QM5_10009`: 0 errors, 0 warnings.

The fixtures were compiled only; no terminal/tester execution was authorized or performed.

W6 status is therefore `PARTIAL_SOURCE_IMPLEMENTED_RUNTIME_MIGRATION_BLOCKED`. Fleet migration, physical history isolation, canonical lifecycle apply, the exact FTMO book, prospective runtime evidence and signed money/deploy decisions remain open.

## W7 — deterministic dry-run only

`q08_v3_migration_inventory.py` and `q08_v3_migration_plan.py` implement a strict, content-addressed, read-only inventory and migration-plan contract. Inventory and plan bind the single repository-owned Q08-v3 policy by repository path, raw file SHA-256, semantic canonical SHA-256 and policy version. A supplied decision is never trusted as a verdict declaration: typed subtest results are normalized and the production `aggregate_shadow` function must reproduce the exact decision. The normalized binding manifest is embedded in the plan and revalidated, so re-hashing a fabricated decision or complete fabricated plan does not make it valid. There is no apply, `INSERT`, `UPDATE`, `DELETE`, enqueue or historical-rewrite path.

The productive read-only inventory contained 536 legacy Q08 rows:

- disposition: CURRENT 0, ELIGIBLE_REEVALUATION 194, INVALID 0, LEGACY_UNVERIFIED 341, SUPERSEDED 1;
- legacy verdict: FAIL_HARD 127, FAIL_SOFT 176, INFRA_FAIL 214, PASS 18, SUPERSEDED_DUPLICATE 1;
- 46 blocking collision groups affecting 315 rows;
- inventory SHA-256: `9165e1f976260dcbdfc090ea5dbe244231a8621dfc5e6a5e2042ce8975411fb8` (default source label `farm_state.sqlite`, no target or artifact manifest);
- plan SHA-256: `5c3c2b84e0657f3c28b02fc9a11e016108520deefe69be76a9a20b6b39b83010`;
- normalized empty-shadow manifest SHA-256: `17a94c94ecb536aac1dd7ced7bc678a92814f4f17a7ad503199a2232ab8a3d79`;
- overlay plan: COLLISION_HOLD 315, NO_RESULT 220, NOT_ELIGIBLE 1, candidate verdict states 0.

No migration output was retained and no productive row was changed. W7 status is `DRY_RUN_SOURCE_IMPLEMENTED_OWNER_APPLY_BLOCKED`. A current-target manifest, collision resolution, real V3 decisions, an OWNER authorization and a separately reviewed append-only apply path remain prerequisites.

## W8 — shadow evaluator source, no outcome claim

`target_outcome_dossier.py` and its strict schema implement a combined, content-addressed DXZ/FTMO outcome dossier. It binds both target rulepacks and ten lane-specific evidence slots. Every declared artifact must resolve under the configured root and match a freshly computed file hash. `SEALED` additionally requires a distinct, real seal file whose own bytes match its hash and whose strict payload exactly binds evidence ID, lane, slot, artifact path/hash and fidelity. Reuse across DXZ/FTMO is rejected independently by resolved artifact path, artifact hash, resolved seal path and seal hash. DXZ metric bounds, FTMO 0–100 probability bounds, lower-bound ordering and joint-probability relationships are validated. Its maximum state is `READY_FOR_OWNER_DECISION`; it cannot authorize deployment, purchase or trading, and all action fields are fixed to `NONE`.

No real candidate evidence was supplied in this wave. W8 status is `SHADOW_EVALUATOR_SOURCE_IMPLEMENTED_NO_GO`; both target lanes remain `RESEARCH_EVALUATOR_SOURCE_IMPLEMENTED / NOT_EVALUATED`.

## Dashboard contract and render boundaries

- `pipeline_books_program_status.py` validates an exact W0-W8 programme source, safety flags, plan/evidence/policy/test-lane/rulepack hashes, five Q08-v3 evidence states, both target lanes, the exact five external residual tests and OWNER blockers.
- Missing, invalid, future or stale programme data renders visibly non-fresh and never as a clear/pass state.
- `render_dashboards.py --strategies-only` renders only `D:\QM\strategy_farm\dashboards\strategies.html` and returns before ancillary metrics, portfolio or page refreshes.
- `render_cockpit.py` opens every SQLite source read-only with `PRAGMA query_only=ON` and writes only `D:\QM\strategy_farm\dashboards\cockpit.html`.
- The full hourly `render_dashboards.py` path skips its ancillary `ea_metrics` DB build whenever `FACTORY_OFF.flag` exists (or its state cannot be read), while every remaining dashboard SQLite query uses `mode=ro` plus `PRAGMA query_only=ON`.
- Both pages consume the same repository-owned programme status source. Historical archive Q08 verdicts are marked `LEGACY`; the canonical gate range is Q00-Q13.
- The managed dashboard tasks are intentionally ALWAYS_ON during Factory OFF and execute the canonical checkout. Therefore an integration-worktree render at either managed `D:` path is a transient preview until this wave is integrated into `C:\QM\repo`; no task was stopped, disabled or repointed to conceal that deployment boundary.

## Verification before final hash refresh

- Combined final-source W6/W7/W8/dashboard contract lane: 244 passed and 9 subtests passed.
- Windows Job Object, worker/adoption/history-lock and cascade adjacency lane: 115 passed and 4 subtests passed.
- MQL compile checks: four final-source fixtures/legacy basket, each 0 errors and 0 warnings.
- Dashboard-focused contract/render lane: 34 passed.
- Pre-hardening repository Green baseline: 2,960 passed, 1 skipped, 5 deselected and 34 subtests passed. Because the later identity/authenticity hardening added code and tests, this number is not the final completion claim; the post-binding Green and external-residual reruns belong in the final render receipt.

The final status binding, full green rerun, exact external-residual rerun, rendered HTML hashes and post-run safety snapshot are recorded after this immutable implementation receipt in `2026-07-29_pipeline_books_dashboard_render_receipt.md`.

## Productive database read-only baseline

At the first read-only census, `D:\QM\strategy_farm\state\farm_state.sqlite` was 350,314,496 bytes with SHA-256 `de3c74d740f266f994d36122245e3f8884effb5c5989a75a364d41dacbc835ae`. At 16:01:04 local time the enabled canonical `QM_StrategyFarm_Dashboard_Hourly` task ran its pre-integration renderer and changed the database autonomously; the resulting hash used for the final W6/W7 read-only projections is `28c3eac195c2aeb778f2d677679990949f124f05407d8f9116f7ed30be8f6cc5`. The worktree renderer now suppresses that ancillary writer whenever Factory OFF is asserted, but the canonical task will retain its legacy behaviour until this source wave is integrated. The final safety receipt must re-check and time-bind any further drift; none of the lifecycle, history or W7 commands opens SQLite writable.

## Honest completion boundary

This receipt proves source implementation and read-only analysis only. It is not evidence that the Factory may be restarted, that legacy EAs have migrated, that Q08 v3 has replaced historical Q08, that a Darwinex Zero challenger book is admitted, or that an FTMO challenge may be bought, deployed or traded. It also does not claim durable publication at the two managed `D:` URLs before canonical integration; the final render receipt records both the verified transient render and the expected canonical-task replacement.
