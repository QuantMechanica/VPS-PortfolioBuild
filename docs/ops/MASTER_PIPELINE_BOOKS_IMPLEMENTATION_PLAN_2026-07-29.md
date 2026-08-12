# QuantMechanica Pipeline and Books — Master Implementation Plan

- **Status:** FOUNDATION_WAVE_SOURCE_IMPLEMENTED; CONTROLLED FOLLOW-UP WAVES OPEN
- **Baseline commit:** `b62cf063878fa4ff43bd7e48d74e2c04d2fefa4d`
- **Created:** 2026-07-29
- **Safety mode:** Factory OFF; no implicit Factory-ON, deployment, T_Live or AutoTrading authority
- **Business outcomes:** better Darwinex Zero books and the first successfully completed FTMO Challenge

## 1. Programme decision

The maintenance convergence commit is the accepted technical baseline. Its runtime and
safety claims were independently audited as `PASS WITH FINDINGS`. This programme does not
re-open that commit; it implements the audit follow-ups and the separate methodological
review of the research, backtest, gate, EA-framework and portfolio layers.

The programme retains a soft Q08 research lane. Historical evidence shows that the old
universal Q08 contract produced effectively no clean survivors because low-frequency and
archetype-inappropriate tests dominated the verdict. The correction is not to make every
sub-gate hard. The correction is to separate evidence strength, measured contradiction,
target suitability and promotion authority.

The programme has two product profiles over one common evidence platform:

1. `DXZ_BETTER_BOOK_V1` optimizes stable rolling six-month DARWIN return, drawdown,
   risk-engine stability, costs and same-owner diversification.
2. `FTMO_2S_100K_SWING_V1` optimizes the probability of completing both FTMO 2-Step
   phases without a rule breach, using exact account-wide mark-to-market risk.

An EA may be eligible for one target and ineligible for the other.

## 2. Non-negotiable invariants

- Factory remains OFF unless the OWNER separately authorizes a controlled state change.
- Factory automation state, deployment authority and trading authority are independent.
- No task in this programme toggles T_Live AutoTrading.
- Existing live books are observation-only until an OWNER-signed deploy manifest exists.
- Historical evidence is never overwritten; corrections use append-only overlays.
- Missing identity, evidence, authorization, data or rule versions fail closed.
- An agent may recommend G0 decisions but may not manufacture OWNER authorization.
- A hard contradiction cannot be compensated by weights or portfolio diversification.
- `LOW_SAMPLE`, `INFORMATIONAL` and `NOT_APPLICABLE` are never positive quality evidence.
- Official provider rules and internal guardrails remain explicitly distinguishable.

## 3. Programme dependency chain

```text
Safety baseline
  -> canonical contracts and immutable execution identity
  -> OWNER/Card/experiment control plane
  -> return, cost, stress and statistical foundations
  -> Q08 v3 evidence dossiers
  -> target-specific admission and synchronized portfolio truth
  -> controlled re-adjudication
  -> DXZ challenger / FTMO challenge book
  -> shadow, OWNER money gate and separate deployment decision
```

The FTMO outcome lane may re-adjudicate a small, frozen current cohort before the entire
legacy corpus is migrated. It may not bypass the shared identity, Q08-v3, MTM, cost,
governor or fidelity contracts.

## 4. Work packages

### W0 — Audit and safety closure

**Deliverables**

- Port the weak-reference plus identity-revalidation cache pattern to all affected FTMO
  screen modules and add real object-ID-reuse regression tests.
- Keep the `ENFORCE_DISABLED` task set disabled while Factory OFF even though the normal
  hourly monitor is quiesced.
- Add an isolated contract test for `FACTORY_OFF.flag` racing a normal worker claim. A
  post-OFF claim must be impossible; a claim admitted before OFF may drain under an
  explicit lease.
- Add restore-intent authorization expiry and future-timestamp rejection.
- Strengthen stale mutation-lock ownership checks against PID reuse and prevent stale-lock
  reaping from deleting a replacement lock.
- Add a bounded Python interpreter-flag contract to factory process classification.
- Correct the audit's documentation and receipt precision findings.
- Move MNT-024..029 into this sequenced master backlog.
- Preserve fail-closed residual tests while separating them from the green merge suite.

**Exit criteria**

- All new safety tests pass without a live filesystem, Scheduler or MT5 mutation.
- Factory OFF still produces no autonomous work admission.
- No audit finding is silently closed; every item has code evidence or a deferred OWNER
  decision.

#### W0.1 — Sequenced Vault-maintenance backlog

The Vault items are not an unsequenced appendix. They execute in the following order;
steps that require `G:` run only after a healthy root-sentinel check in the interactive
`qm-admin` context and must leave their result outside the Vault.

| Order | Item | Implementation unit | Entry condition | Acceptance / hand-off |
|---|---|---|---|---|
| 1 | MNT-024 | Define the closed page-status enum and live-Vault runner; inventory `_HOME`, `START_HERE` and current-state links; relabel or move historical targets. | Runner, root sentinel and off-Vault evidence path are fixed. | Every canonical link targets a `CURRENT` page; legacy violations are baselined and new unlabeled historical links fail. |
| 2 | MNT-025 | Inventory active consumers, replace the three legacy target names and add scoped preflight codes `MOUNT_UNAVAILABLE`, `TARGET_MISSING` and `TARGET_INVALID`. | MNT-024 status semantics exist. | A healthy mount plus missing/invalid required target hard-fails only the dependent action; mount outage never masquerades as a missing page. |
| 3 | MNT-026 | Implement fail-closed UTF-8/path/dedup checks and negative False-CLEAN fault tests. | Path authority and active-target set from MNT-024/025 are frozen. | Decode, path or comparison failure cannot yield `CLEAN`; fixtures cover malformed UTF-8, aliases and unavailable targets. |
| 4 | MNT-027 | Materialize the Q01-Q10 Decision/Doku/Code/Test matrix, including the Q04 venue-cost contract and Q08 `strategy_*` baseline inputs; version emitted verdicts and effective dates. | Canonical gate manifest is available. | Each row has authority, code, positive/negative test and legacy-evidence rule; Vault and repo views lint identically. |
| 5 | MNT-028 | Regenerate the Company manifest; include MAINTENANCE and the convergence ledger by reference; classify all 31 broken-link occurrences in a reviewed versioned baseline and reactivate checks with explicit semantics. | MNT-024..027 corrections are review-complete. | No unexplained internal broken link remains, new drift blocks, and each run binds manifest/baseline hashes, Vault identity, principal and timestamp. |
| 6 | MNT-029 | Upgrade the Claude-owned OWNER-decision feed with stable IDs/status/supersession; join append-only execution and verification receipts; make `FRESH`, `STALE`, `MISSING` and `INVALID` visible in the renderer and Morning Brief. | Stable IDs and off-Vault evidence storage are available. | Source failure is never rendered as an empty feed; an answered item leaves the open brief only after required execution and verification evidence. |

**Required OWNER decision — `QM_StrategyFarm_UnreadableLinks_Friday`.** The audit found
the task disabled even though it is outside the Factory-OFF keyset, while the inventory
records an earlier 2026-07-23 authorization. OWNER must durably confirm whether the
current disabled state is intentional and declare the desired enabled state separately
for Factory OFF and normal operation. Until that decision exists, implementation and
tests must preserve the observed disabled state; this programme neither enables nor
starts the task.

### W1 — Canonical contracts and execution identity

**Deliverables**

- One versioned machine-readable gate manifest for Q00..Q13.
- Generated phase labels, documentation checks, runner registry and compatibility map.
- Strict phase validation on writes; legacy aliases are read/migration adapters only.
- Immutable `execution_bundle` created at accepted build generation, binding:
  Git tree, Card, MQ5, recursive include tree, EX5, set file, effective tester inputs,
  compiler/terminal build, symbol specification, history snapshot, cost model, calendar
  bundle and rulepack version.
- Build completion, enqueue and deferral use one transaction or transactional outbox.
- Orthogonal state fields:
  `execution_status`, `evidence_strength`, `economic_merit`, `target_eligibility` and
  `promotion_decision`.
- Incremental extraction of bounded domains from `farmctl.py`; no big-bang rewrite.

**Exit criteria**

- Any byte or rule-version change creates a new bundle ID and prevents continuation of the
  old gate chain.
- Unknown phases and impossible state transitions fail closed.
- Identical inputs yield byte-identical canonical bundle hashes.

### W2 — OWNER control, Strategy Card V3 and experiment ledger

**Deliverables**

- Append-only `source_authorizations` and `g0_decisions` with OWNER, source and card hashes.
- Agents can write only `RECOMMEND_APPROVE`, `RECOMMEND_REJECT` or
  `RECOMMEND_CHANGES_REQUIRED`.
- One Strategy Card V3 schema and linter used by extraction, G0 and build.
- Required Card fields: mechanism, prediction, falsifier, assumptions, primary archetype,
  independent cluster unit, degrees of freedom, trial budget, data cut and DEV/OOS seals.
- Source-independent strategy-family fingerprint and fail-closed corpus manifest.
- Append-only experiment and negative-hypothesis ledger covering cards, parameter cells,
  symbols, timeframes, variants, repairs, salvage and retired attempts.
- Infra retries remain linked to one experiment and are not counted as independent trials.
- Vault becomes a generated navigation projection rather than another mutable truth.

**Exit criteria**

- No promotion-capable card lacks current OWNER and schema receipts.
- DSR/FDR candidate counts can be derived from the complete experiment ledger.
- A post-result rule or parameter change necessarily creates a new experiment ID.

### W3 — Return, cost, stress and statistical foundations

**Deliverables**

- Full zero-filled calendar return series and synchronized intraday mark-to-market paths.
- Explicit trade, day, event, year, package and strategy-family cluster identities.
- Q04 becomes either a true nested walk-forward or is renamed to locked-parameter
  sequential OOS validation.
- Q05 becomes reproducibility/full-history diagnostics rather than a stress claim.
- Q06 uses venue-calibrated joint spread, slippage, latency, rejection, gap, commission and
  swap scenarios.
- Q07 uses block/stationary bootstrap and execution Monte Carlo; MT5 seeds are parity checks.
- Q08.2 uses actual experiment counts, full calendar returns and tested DSR/FDR routines.
- Q09 news inference clusters by independent events/days/months and controls mode-selection
  multiplicity.
- Q10 receives the exact Q09-selected temporal/compliance mode and bound set hashes.

**Exit criteria**

- Statistical goldens, null simulations and property tests reproduce known results.
- Portfolio Sharpe/correlation never annualize only active-trade days as calendar days.
- A final holdout is used once; later changes create a new prospective experiment.

### W4 — Q08 v3 evidence dossier

**Aggregate verdicts**

- `SUPPORTED`: all applicable mandatory evidence is measured and passes.
- `CONDITIONAL`: positive costed edge and no veto, with explicit evidence debt or measured
  target-mitigable weakness.
- `INSUFFICIENT`: no contradiction, but inadequate independent evidence.
- `CONTRADICTED`: a measured hard counterexample.
- `INVALID`: identity, data, cost or execution evidence cannot be trusted.

**Deliverables**

- Versioned archetype policy matrix with `required`, `diagnostic` and `not_applicable` tests.
- Universal hard dimensions: identity, costed expectancy, global selection bias, temporal
  decay, execution and tail/ruin risk.
- Archetype suites for trend/breakout, mean reversion, seasonal/event, intraday,
  carry/overnight and basket/cointegration strategies.
- Portfolio correlation and tail dependence leave single-EA quality and move to book gates.
- Deterministic evidence hashes, explicit reason codes and target-neutral dossiers.
- Q08 v2 remains frozen while v3 runs in an additive shadow namespace.

**Exit criteria**

- No `LOW_SAMPLE`, `INFORMATIONAL` or `NOT_APPLICABLE` result yields `SUPPORTED`.
- No hard contradiction is softened by aggregation.
- Unknown archetype or incomplete lineage is fail closed.
- Pass rate is not an acceptance criterion; prediction and calibration quality are.

### W5 — Target admission and portfolio truth

**Deliverables**

- Versioned `DXZ_BETTER_BOOK_V1` and `FTMO_2S_100K_SWING_V1` rulepacks.
- Q11/Q12 consume only authenticated, fully qualified candidate views.
- Missing/invalid DB or evidence is `SOURCE_INVALID`, never an empty first-sleeve book.
- Frozen candidate-set and return-stream snapshots.
- Synchronized realized/floating P&L, margin, conversion, gap and liquidation paths.
- Family, symbol, session, currency and tail-concentration controls.
- Marginal book contribution rather than standalone PF drives admission.

**Exit criteria**

- The same Q08 dossier can produce different, explained DXZ and FTMO eligibility.
- Target policies never rewrite Q08 evidence.
- Every accepted book is reproducible from one content-addressed manifest.

### W6 — EA framework and account-wide risk authority

**Deliverables**

- Immutable execution contract is mandatory in `QM_FrameworkInit`.
- Production entries require framework state `READY`.
- Atomic, checksummed, generation-bound kill-switch state.
- One account-wide FTMO governor; every sleeve is a fail-closed client.
- Risk in account currency uses exact directional `OrderCalcProfit` where available.
- Tester history stores are isolated from each other and from live-adjacent history.
- Windows Job Objects contain each runner process tree.
- Typed work-item lifecycle with nonterminal `WAITING_INPUT`, `BLOCKED` and `QUARANTINED`.
- Registry generation is strict by default; incomplete news modes are not gate-capable.

**Exit criteria**

- Missing governor, manifest, baseline, account, server, symbol, calendar or generation
  blocks production entries.
- Python/MQL governor parity and Windows fault-injection suites pass.
- No test runner can mutate a shared live-related history store.

### W7 — Migration and re-adjudication

**Deliverables**

- Immutable inventory of all cards, artifacts, evidence, candidates and negative results.
- Classification as `CURRENT`, `LEGACY_UNVERIFIED`, `ELIGIBLE_REEVALUATION`, `INVALID` or
  `SUPERSEDED`.
- Alias/lineage records preserve existing IDs and expose collisions.
- Dry-run replay and old/new verdict discordance matrix.
- Append-only Q08-v3 overlays; no historical report rewrite.
- Priority: current DXZ/FTMO candidates, then v2 PASS/FAIL_SOFT, then remaining backlog.
- Idempotent apply after OWNER approval of inventory and delta report.

**Exit criteria**

- Every inventoried object has a disposition and no row is silently dropped.
- A second migration apply produces no change.
- No migration action changes a deployed live book.

### W8 — Outcome lanes

#### DXZ challenger

- Freeze current book, live metrics and exact deployed identities as the incumbent baseline.
- Build an offline challenger using rolling six-month net return, maximum drawdown,
  rating proxy, risk-engine intervention, divergence, cost and correlation.
- Admit `CONDITIONAL` sleeves only when exact-book stress demonstrates mitigation.
- Run minimum-weight prospective probation before any OWNER deploy decision.

**DXZ Go:** challenger beats the preregistered incumbent comparison net of costs on sealed
evidence without exceeding the signed risk and concentration policy.

#### FTMO challenge book

- Freeze a small current dense/intraday-capable cohort rather than wait for full migration.
- Close all standalone/joint/terminal fidelity gaps.
- Bind exact 100k 2-Step Swing rules, binaries, sets, costs, clock and governor policy.
- Run joint MTM simulation, block Monte Carlo and one clean Free-Trial/shadow observation.
- Require a separate OWNER money gate before purchase or launch.

**Initial internal money-gate proposal:** P1 point estimate >= 80%, P1 lower 95% confidence
bound >= 70%, loss-breach upper 95% bound <= 10%, conditional P2 >= 85%, joint P1+P2 >=
65%. These are model-based purchase criteria, not provider rules or guarantees.

## 5. Rollout states

1. `R0_BASELINE`: accepted commit and immutable audit inventory.
2. `R1_OFFLINE_SHADOW`: new code reads historical inputs and writes a separate namespace.
3. `R2_DUAL_EVALUATION`: v2/v3 comparison; no automatic promotion.
4. `R3_CANONICAL_MANUAL`: new contracts canonical, execution still explicitly initiated.
5. `R4_DXZ_CHALLENGER`: offline/prospective comparison against frozen incumbent.
6. `R5_FTMO_FREE_TRIAL`: exact rulepack, book and governor under observation.
7. `R6_OWNER_MONEY_GATE`: separate signed decisions for deployment/challenge purchase.

Factory-ON is not a rollout state and is not implied by any state above.

## 6. Verification strategy

- Unit and schema tests for every contract and state transition.
- Negative authorization, missing-data, stale-hash and stale-generation tests.
- Statistical reference fixtures, null simulations and property tests.
- Three-run deterministic artifact/hash checks.
- Migration cardinality, checksum and idempotency tests.
- Exact-book MTM tests with DST, gaps, costs, margin and correlated exposure.
- Python/MQL policy parity.
- Windows fault injection for OFF-during-claim, parent death, surviving MT5 children,
  SQLite transaction boundaries and corrupt kill-switch state.
- External-state residual checks remain explicit and fail closed; merge tests remain green.

## 7. Programme completion

The programme is complete only when:

- Q08 keeps a legitimate conditional research lane without calling absent evidence PASS;
- all active evidence is bound to immutable execution identity;
- global experiment history drives selection-bias controls;
- DXZ and FTMO have independent, versioned target eligibility;
- Q09/Q12 cannot fail open;
- the DXZ challenger demonstrates a preregistered improvement;
- the FTMO book clears fidelity, simulation, shadow and OWNER money gates; and
- neither Factory-ON nor AutoTrading follows automatically from a pipeline verdict.

## 8. Current implementation status

| Work package | Status | Implemented in this wave | Still required before exit |
|---|---|---|---|
| W0 audit/safety closure | `SOURCE_IMPLEMENTED_WITH_OWNER_RESIDUALS` | Weakref cache repair; OFF hazard enforcement; OFF-during-claim fence; restore-intent freshness; nonce-/byte-/process-start-bound mutation locks; bounded interpreter flags; receipt corrections; explicit test lanes | Vault MNT-024..029 runtime work and the OWNER/design decisions in W0.2 |
| W1 canonical contracts | `FOUNDATION_SOURCE_IMPLEMENTED` | Strict Q00..Q13 manifest and content-addressed execution-bundle contract | Generated consumers, central write-path integration, transactional outbox and domain extraction from `farmctl.py` |
| W2 governance/experiment ledger | `FOUNDATION_SOURCE_IMPLEMENTED` | Source authorization, separate OWNER/agent G0 records, Strategy Card V3 and immutable experiment records | Persistent append-only store, strategy-family fingerprint, corpus manifest, consumer wiring and Vault projection |
| W3 statistical foundations | `PARTIAL_SHADOW_SOURCE_IMPLEMENTED` | Complete zero-filled calendar panels, synchronized sleeves, bound PnL capital basis, frequency-correct Sharpe and deterministic joint moving-block bootstrap | Intraday MTM paths, nested walk-forward, calibrated joint costs, execution Monte Carlo, DSR/FDR goldens, Q09 multiplicity and Q10 propagation |
| W4 Q08 v3 | `SHADOW_FOUNDATION_SOURCE_IMPLEMENTED` | Additive archetype policy, strict evidence contracts and non-weighted five-state aggregation | Production subtests, calibration, dual evaluation and OWNER-approved canonical promotion |
| W5 target admission | `RULEPACK_FOUNDATION_SOURCE_IMPLEMENTED` | Strict, versioned DXZ and FTMO research rulepacks with separate evidence/eligibility semantics | Authenticated candidate views, synchronized book simulation, marginal-contribution engine and book manifests |
| W6 EA framework | `PARTIAL_SOURCE_IMPLEMENTED_RUNTIME_MIGRATION_BLOCKED` | Additive one-way V3 runtime identity/READY contract binds independent source generation and the exact magic registry; standard and basket entries are single-EA/symbol/magic fail-closed; V3 baskets share directional risk, margin and FTMO-governor rails; strict-default Magic Resolver; suspended-before-assign Windows Job containment; symmetric read-only history-overlap audit; complete fail-closed lifecycle taxonomy | Cohort migration of legacy EAs; a versioned multi-identity contract for genuine baskets; atomic generic kill-switch persistence; physical isolation of the shared `Bases/Custom` store; canonical typed-lifecycle apply; exact three-sleeve simulation and prospective Python/MQL/fault-injection evidence |
| W7 migration | `DRY_RUN_SOURCE_IMPLEMENTED_OWNER_APPLY_BLOCKED` | Deterministic read-only Q08 inventory bound to the one canonical policy artifact; lineage/alias/collision analysis; embedded normalized shadow manifest whose decisions are recomputed from typed subtest results; self-validating content-addressed migration plan and old/new discordance contract; no apply or historical rewrite exists | Bind OWNER-ratified current DXZ/FTMO selectors and real evidence-producing V3 subtests, resolve collision holds, obtain OWNER approval, then implement and prove an idempotent append-only apply |
| W8 outcome lanes | `SHADOW_EVALUATOR_SOURCE_IMPLEMENTED_NO_GO` | Strict combined DXZ/FTMO outcome dossier re-hashes every real evidence and seal file under an allowed root, binds seal-to-lane/slot/artifact semantics, forbids cross-lane reuse by resolved path and hash, validates metric/probability bounds, and is capped at `READY_FOR_OWNER_DECISION` with every action `NONE` | Exact book/simulation/shadow evidence, DXZ prospective probation, FTMO free-trial observation, semantic evidence review, fidelity closure and separate signed deploy/purchase decisions |

### W0.2 — Deferred OWNER and design decisions

These are visible blockers, not silently accepted implementation gaps:

| Decision | Safe default until decided | Downstream dependency |
|---|---|---|
| Desired OFF/ON state of `QM_StrategyFarm_UnreadableLinks_Friday` | Preserve the observed disabled state | MNT-028 link-check reactivation |
| MNT-012 R-gate rule for frontmatter-only `PASS` without a body decision table, plus repair of both contradictory R3 cards | Warn and refuse the known contradictory cards; do not broaden historical claims | W7 re-adjudication |
| Q09 Wave-2 tail handling when fewer than 25 eligible rows remain | Do not run an undersized implicit tail wave | MNT-007/Q09 migration |
| Q09 migration companion path for live/staged requalification overlays | No migration apply | W7 inventory and apply |
| Health-quarantine list and minimum-worker sensitivity | Retain the current fail-closed floor | Factory restart readiness |
| DXZ10939/DXZ12567 amendments and QM20009 calendar ratification | Keep hash mismatches visible in the external-residual lane | W7 priority cohort and both W8 lanes |
| FTMO three-sleeve set, exact governor policy and any paid challenge action | No compile/run/purchase/deploy authority | W6 and W8 FTMO money gate |

## 9. Delivered foundation wave

The source wave is intentionally additive where the new methodology has not yet earned
canonical authority. It contains:

- a strict canonical gate manifest, immutable execution-bundle schema and create-new-only
  loaders/writers;
- separate source-authorization, G0, Strategy Card V3 and experiment contracts, so agent
  recommendations cannot be mistaken for OWNER approval;
- Q08 v3 shadow semantics in which hard contradiction or invalid lineage cannot be
  weighted away, and low sample or missing mandatory evidence cannot become `SUPPORTED`;
- complete zero-filled calendar evidence panels and joint block-bootstrap paths, removing
  active-day-only annualization from the new evidence foundation;
- research-only DXZ and FTMO target rulepacks that may interpret one dossier differently
  without rewriting it; and
- all Factory-OFF-compatible audit hardening and exact external-residual test separation.

The implementation receipt is
`docs/ops/evidence/2026-07-29_pipeline_books_foundation_wave.md`.

### W6-W8 and dashboard continuation

The controlled continuation implements the remaining source-only decisions without
crossing the Factory-OFF, deployment, money or AutoTrading boundaries:

- W6 production-boundary primitives are present, but the new V3 contract is opt-in until
  legacy EAs migrate in compile-tested cohorts. Its initialization is one-way, its source
  generation and registry identity are independently bound, and every V3 standard/basket
  entry is restricted to the exact single EA/symbol/magic identity. Legacy compatibility
  remains explicit and is not described as `READY`; multi-identity V3 baskets remain
  blocked until a separate versioned contract exists.
- Windows runner children are created suspended and only resumed after exact-handle Job
  assignment, identity capture and registry retention. Assignment, identity, registry or
  resume failure kills and waits the contained tree instead of exposing a pre-assignment
  execution race.
- The live read-only topology audit currently returns `FAIL_CLOSED`: all nine runner
  terminals resolve `Bases/Custom` to one shared store. No junction was changed during
  this wave.
- The typed lifecycle projection inventories the legacy encoding without changing the
  database; `WAITING_INPUT`, `BLOCKED` and `QUARANTINED` remain nonterminal in the V2
  contract, all observed PASS-like verdicts map to `SUCCEEDED`, and unknown or internally
  inconsistent verdict/status combinations fail closed.
- W7 inventories all 536 current legacy Q08 rows. It accepts only the repository-owned
  Q08-v3 policy binding and recomputes every supplied decision from normalized typed
  subtest results; the normalized binding manifest is embedded and revalidated with the
  plan. Without an OWNER-ratified current-target manifest or real Q08-v3 evidence, the
  generated plan is advisory and cannot apply.
- W8 can produce only `NO_GO` or `READY_FOR_OWNER_DECISION`; declared evidence must exist,
  match its re-computed hash and, when sealed, carry a distinct real seal that exactly
  binds lane, slot, identity, artifact and fidelity. Cross-lane reuse and incoherent
  probability bounds fail closed. It has no code path for purchase, deployment, Factory,
  scheduler, MT5 or AutoTrading actions.
- The versioned `strategies.html` and `cockpit.html` generators now render the same
  hash-bound W0-W8 source view, distinguish legacy Q08 `FAIL_SOFT` from Q08-v3 evidence
  states, expose the exact five external residuals and surface all OWNER blockers.
  Missing, stale or hash-drifted input renders visibly invalid instead of empty/green.
- Durable publication to the two managed `D:\QM\strategy_farm\dashboards` paths remains
  a release step: the enabled ALWAYS_ON dashboard tasks execute `C:\QM\repo`, so they
  replace any integration-worktree preview at the next two-minute/hourly run. This wave
  did not alter or stop those tasks. After the reviewed commit is integrated into the
  canonical checkout, the unchanged tasks materialize the new views automatically.
- The hourly generator now treats Factory OFF as a hard boundary for its ancillary
  `ea_metrics` upserts and opens all remaining dashboard SQLite reads with `mode=ro` plus
  `query_only=ON`. The legacy canonical task can continue to change the DB until this
  source wave is integrated; that autonomous pre-integration drift must remain explicit.

The continuation receipt is
`docs/ops/evidence/2026-07-29_pipeline_books_w6_w8_dashboard_wave.md`.

## 10. Next controlled implementation sequence

1. Integrate this reviewed wave into the canonical checkout and let the unchanged
   ALWAYS_ON render tasks publish both managed dashboard files; do not repoint or disable
   the tasks merely to preserve a worktree preview.
2. Integrate the gate manifest, execution bundle and orthogonal state fields into one
   transactional build/enqueue path; keep Q08 v3 shadow-only.
3. Persist Card/G0/experiment records append-only and derive full family-level trial
   counts before enabling DSR/FDR decisions.
4. Complete W3 MTM, cost, nested-validation and statistical reference suites.
5. Migrate a small compile-tested EA cohort to the implemented W6 V3 runtime contract,
   isolate the shared Custom history store in an OWNER window, and complete kill-switch
   persistence plus Python/MQL/Windows fault injection.
6. Ratify the W7 current-target manifest, resolve collision holds, attach real Q08-v3
   decisions and request OWNER approval before implementing any append-only apply.
7. Feed the implemented W8 dossier with a frozen DXZ challenger and a separate FTMO
   free-trial/shadow lane. Neither outcome
   authorizes deployment, challenge purchase, Factory-ON or AutoTrading.
