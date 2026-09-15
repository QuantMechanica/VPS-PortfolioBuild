# OWNER directive 2026-09-15 (third) — Maximum Factory Utilization / Dynamic AI Routing / Strategy Eligibility v2 / Second-Chance / Portfolio Tail-Risk / Fixed-Hardware Throughput / Decision-Grade Vault

- Author: OWNER (chat, 2026-09-15 ~17:3xZ, message headed "ULTRACODE / QUANTMECHANICA — OWNER FOLLOW-UP DIRECTIVE:
  MAXIMUM FACTORY UTILIZATION …"), transcribed by Orchestrator Claude/Fable
  (session https://claude.ai/code/session_01EbahMJqzhTCfpmWAPcTaoE). Full verbatim text:
  `docs/ops/evidence/2026-09-15_continuous_book_evolution/owner_directive_3_max_factory_utilization_verbatim.md`.
  This file records the binding decisions; the verbatim file is the source.
- Decision id: `OWNER-DEC-D3-20260915`
- Status: BINDING and FINAL. The directive states (§47) that the listed authority delegations are granted and (per the
  programme convention §68B of the master directive) already-explicit decisions must NOT be re-surfaced for OWNER
  re-approval. The items below are decided; they are implemented across several slices — the "Implementation" line names
  which slice, and "LATER SLICE" means the decision is final now but its code lands later.
- Extends (does not replace): `OWNER-DEC-CBE-20260915` (Continuous Book Evolution,
  `decisions/2026-09-15_owner_continuous_book_evolution.md`) and `OWNER-DEC-KIMI-INTEGRATION-20260915`
  (`decisions/2026-09-15_owner_kimi_integration_ml_research_r1_internal.md`). "Do NOT rebuild systems that are already
  working" (§23 preamble / §1). Where this directive conflicts with older intermediate goals or style rules, this
  directive wins; superseded rules are marked superseded, never deleted; historical verdicts remain immutable.

## 0. Scope and precedence

The objective (§1, §2): extract substantially more useful economic throughput from the AI factory, the MT5 factory, the
existing strategy universe and the existing VPS — by **better allocation of constrained resources toward expected economic
value**, not by more caution and not by vanity utilization (§45: "100% busy doing useless work is worse than 70% busy
doing valuable work"). Company goal unchanged: reach sustainable profitability as fast as possible without stupid,
poorly-understood or uncontrolled risk.

The RED boundaries are unchanged and are never dissolved by this directive (§5 never-list, §47 stop conditions): gate
integrity (evidence integrity, provenance, lookahead protection, holdout separation, deterministic execution, data
validity) and verdict semantics; T_Live and the FTMO demo terminal; AutoTrading; live deployment; FTMO/paid-account
purchase; deleting/rewriting evidence, verdicts, trade streams or dated decisions; farm-DB writes by an unauthorized
path; hardware/VPS purchase or migration; runtime ML in the EA; uncontrolled/unbounded recovery risk.

## Decisions (OWNER, binding)

Each item: directive section(s) · what it supersedes/changes · implementation slice · what stays unchanged.

### 1. Maximize the whole factory, not individual providers
- **Directive:** §2, §3, §48.
- **Decision:** provider specialization stays useful but provider *silos* are abolished as permanent rules. No permanent
  "only Codex may code / Kimi may never code / Antigravity only discovers sources / Claude must do every hard review".
  Roles become **empirical** — measured, not dogmatic. Inspect the actual current registry/config; aliases and model
  mappings are not permanent.
- **Implementation:** `a1_ai_capacity_remeasure` (this slice) records the runtime picture; `c1_dynamic_routing` (LATER
  SLICE) adjusts router capabilities and quota-aware routing; capability grants gated on the benchmark (item 4).
- **Stays unchanged:** the §5 never-list; Kimi's research-only contract until a benchmark-backed grant; verdict-write
  exclusions.

### 2. AI capacity re-measure (NOW) + shadow price + pacing across all providers
- **Directive:** §8, §9, §43A.
- **Decision:** re-measure current provider quotas **now** through the authoritative governors only (OWNER topped up
  Claude since the prior audit — no stale snapshots). AI capacity has a **shadow price**: remaining quota's opportunity
  cost changes with time-to-reset and backlog value. Route away from scarce providers toward qualified spare providers;
  do not burn Kimi/agy on filler for vanity 100%. Optimize expected useful throughput across the reset period (neither
  hoard nor starve). Fable may adjust provider pacing without routine OWNER approval, versioned + reversible. Never
  hand-delete a quota flag — the governor that owns it clears it.
- **Implementation:** `a1_ai_capacity_remeasure` (this slice): re-measurement (see the measurement annex below);
  `tools/strategy_farm/ai_capacity_readmodel.py` → `D:/QM/reports/state/ai_capacity.json` (`qm.ai-capacity/v1`) with a
  documented shadow-price formula, offload opportunities and review independence; wired into
  `book_evolution_runner._default_state_builds`; canonical doc `docs/ops/AI_FACTORY_CAPACITY_AND_ROUTING.md` + vault
  `02 Org/AI Factory Capacity & Routing.md`.
- **Stays unchanged:** backtests are never throttled; the existing governors (`quota_governor.py`, `codex_budget_line.py`,
  `codex_fleet_pacer.py`, `agy_governor.py`, `kimi_governor.py`) remain the pacing authority.

### 3. Cross-provider review uses spare capacity
- **Directive:** §10.
- **Decision:** underused providers are the most valuable independent critics. Restore Antigravity authentication when
  OWNER relogs in; then prefer true provider diversity. Do not duplicate expensive primary-provider capacity when a
  competent underused provider can provide the independent challenge. Track creator/critic vendor, same-vendor share,
  critic quality and correction yield — independence is useful only if critique quality is real.
- **Implementation:** `a1_ai_capacity_remeasure` surfaces `review_independence` (same_vendor_share) + per-provider
  `independent_review_available` in `ai_capacity.json`; the agy CLI auth probe (below) confirms relogin;
  `c1_dynamic_routing` (LATER SLICE) prefers spare cross-vendor critics in the chain.
- **Stays unchanged:** `agent_chain.py` cross-vendor critic construction; Kimi never critiques Kimi and is never a
  formatter.

### 4. AI capability benchmark + evidence-based capability expansion
- **Directive:** §4, §5.
- **Decision:** build a small **deterministic** benchmark suite of representative QM tasks (coding, review, research,
  operations), run equivalent sandbox/worktree tasks (never live-risk) through eligible providers/models, score
  correctness / tests passed / regressions / reviewer corrections / time / retries / context efficiency / quota /
  constraint-following, and persist an `AI_CAPABILITY_SCORECARD` per provider/model/task-class. After benchmark success
  Fable may grant scoped capabilities (`code_small`, `tests_small`, `repo_edit_scoped`, `documentation`, `readmodel`,
  `review`) to underused providers. Grants stay reversible, branch/worktree-isolated, path-scoped, test-gated,
  independently reviewed when material.
- **NEVER granted through this mechanism (§5, unchanged):** T_Live authority, AutoTrading authority, financial purchase
  authority, unrestricted production ops, verdict manipulation, evidence deletion — plus (carried from the RED
  boundaries) gate-threshold and book-construction authority, live deployment.
- **Implementation:** `b1_ai_capability_benchmark` (LATER SLICE) → `docs/ops/AI_CAPABILITY_BENCHMARK_2026-09.md` +
  `AI_CAPABILITY_SCORECARD`. Until it lands, `ai_capacity.json` reports `last_benchmark_utc = EVIDENCE_MISSING` and every
  code/tests/repo_edit/ops offload is `benchmark_gated`.
- **Stays unchanged:** the never-list; Kimi research-only until a grant lands.

### 5. Task-risk routing + model-tier-matches-difficulty
- **Directive:** §6, §7.
- **Decision:** classify tasks LOW / MEDIUM / HIGH / OWNER-LIVE. LOW → any proven provider with spare capacity; MEDIUM →
  strong measured performer + tests + review; HIGH → strongest suitable provider + independent cross-provider review;
  OWNER-LIVE → OWNER-controlled. Match model tier to difficulty — don't waste the most capable model on mechanical work,
  don't put hard architecture/research on a small model just because quota is free. Fable chooses dynamically on
  complexity, context, failure cost, benchmark, quota, time-to-reset, queue, and provider-independence need.
- **Implementation:** documented in `docs/ops/AI_FACTORY_CAPACITY_AND_ROUTING.md` CONTRACT (this slice);
  `c1_dynamic_routing` (LATER SLICE) enforces in the router.
- **Stays unchanged:** codex model-tier doctrine (`config/agent_quota_gate.v1.json`), claude headless model choice.

### 6. Maximum factory utilization includes MT5 + fixed-VPS throughput
- **Directive:** §11, §12, §39.
- **Decision:** MT5 throughput must also be optimized on the **existing** host. Measure the real resource footprint (RAM,
  CPU, disk I/O, duration) per symbol/gate/strategy family; replace simplistic queue ordering with resource-aware
  scheduling (bin-packing): a single 44-GB-class job must not head-of-line block many terminals when smaller useful jobs
  can run; heavy jobs run alone / in quiet windows / at reduced concurrency while smaller jobs fill remaining capacity.
  Objective: maximum useful evidence per wall-clock hour.
- **Implementation:** `g1_vps_throughput` (LATER SLICE) + `docs/ops/VPS_CAPACITY_AND_SCHEDULING.md`.
- **Stays unchanged:** the RAM-class table and containment/isolation invariants (OWNER 2026-09-14); backtests never
  throttled.

### 7. NO VPS UPGRADE / NO VPS MIGRATION (OWNER decision, §13)
- **Directive:** §11, §13, §39.
- **Decision (record verbatim intent):** for the current planning horizon there is **NO VPS move and NO VPS hardware
  upgrade**. Do not propose a bigger VPS as the normal solution and do not repeatedly surface it. If a task genuinely
  cannot run on the current machine: classify it, park it, find a more resource-efficient implementation, schedule it
  differently, reduce redundant computation, use hash-bound reuse. Continue measuring constraints so OWNER understands
  opportunity cost, but solve in software/scheduling first.
- **Implementation:** recorded here by `a1_ai_capacity_remeasure`; surfaced on the VPS capacity page by `g1_vps_throughput`
  (LATER SLICE). This is a standing OWNER decision, not a slice deliverable to be re-decided.
- **Stays unchanged:** everything; this only forbids the upgrade/migration path.

### 8. Strategy eligibility v2 — style-agnostic
- **Directive:** §14, §16, §17.
- **Decision:** strategy **style alone is not a rejection reason**. The relevant questions: is it mechanical, testable,
  risk-measurable, risk bounded enough for the intended portfolio, and does the evidence support positive portfolio
  value. No external source is required — original strategies from Fable / Kimi / OWNER / another authorized agent /
  internal statistical research are valid (provenance still required via `QM-RESEARCH://…`; "no external source" ≠ "no
  provenance"). Explicitly valid families: scalping, mechanical intraday, trailing-stop, positive/negative pyramiding,
  martingale, reverse/anti-martingale, bounded grid, bounded recovery, multi-position, basket management, partial exits,
  break-even, time exits, session strategies, pattern/price-action/volatility/regime filters, portfolio hedges, hybrids.
- **Implementation:** `d1_strategy_eligibility_v2` (LATER SLICE) → `docs/research/STRATEGY_ELIGIBILITY_V2.md` + vault
  Strategy Eligibility & Tail-Risk doctrine (§37); removes obsolete style-based rejection.
- **Stays unchanged:** HR14 ML boundary (item 9); mechanical/deterministic EA requirement; provenance fail-closed.

### 9. Machine-learning boundary remains
- **Directive:** §15.
- **Decision:** ML MAY be used **offline** by the research system to discover mechanical relationships; ML remains
  **prohibited** in the EA's trading decision engine. Final EAs stay mechanical + deterministic: no runtime inference, no
  online learning, no black-box adaptive prediction.
- **Implementation:** already in force (HR14 + the 2026-09-15 annex, `OWNER-DEC-KIMI-INTEGRATION-20260915`); re-affirmed
  here; no code change.
- **Stays unchanged:** HR14 in full.

### 10. Tail-risk contract + one-EA-cannot-destroy-account
- **Directive:** §18, §19, §20, §21.
- **Decision:** martingale-like logic is not automatically prohibited, but **uncontrolled ruin risk is**. A
  tail-amplifying strategy must expose a **deterministic risk contract** quantifying where applicable: max levels, sizing
  progression, max open positions, max basket exposure, max gross notional, max margin, max basket loss, deterministic
  emergency/equity-stop, gap sensitivity, spread/slippage sensitivity, worst historical sequence, stress sequence. No
  infinite recovery sequence; no "price must return" assumption without a bounded account-loss condition; a hard
  portfolio-level safety boundary may substitute for per-trade SLs where basket management requires it. Diversification
  may make aggressive strategies useful **but must be proven** (measure simultaneous adverse regimes, correlation
  convergence, common exposure, news/gap shocks, margin, drawdown clustering, worst-day overlap, tail dependence, joint
  escalation — normal-period correlation alone is insufficient). A single sleeve must not be able to create
  account-terminating risk; the portfolio risk layer must be able to limit sleeve/basket/account-wide open risk, detect
  escalation, stop additions, apply venue constraints. Positive and negative pyramiding are researched **separately** as
  different mechanisms (never one generic "pyramiding" label).
- **Implementation:** `f1_tail_risk_engine` (LATER SLICE) → `docs/research/PORTFOLIO_TAIL_RISK_RESEARCH.md` + the
  deterministic risk-contract schema + portfolio tail-risk evaluation.
- **Stays unchanged:** RISK_FIXED backtest / RISK_PERCENT live; no invented commission/swap/DST.

### 11. Pattern & filter fresh programme + catalog
- **Directive:** §22, §40.
- **Decision:** audit PatternFilter framework, Patterns library, Q12 pattern-filter process and Andrea-Unger-derived
  concepts; test pattern filters as modular overlays with proper ablation (base vs base+filter vs justified
  combinations), a null/no-filter baseline, and multiple-testing control; measure trade reduction, expectancy, DD,
  regime and portfolio effect. Do **not** keep an arbitrary "max N filters" rule as a Hard Rule unless evidence supports
  it. Expose a Pattern & Filter Catalog feeding Q12 and autonomous research.
- **Implementation:** `f2_pattern_filter_programme` (LATER SLICE) → `docs/research/PATTERN_FILTER_CATALOG.md`; interacts
  with DL-089 (the DL-089 selection *rule* stays ROT until challenged via item 14's procedure).
- **Stays unchanged:** DL-089 census selection rule until a versioned §30 change lands.

### 12. Second-chance strategy programme + rejection reclassification
- **Directive:** §23, §24, §25, §26, §31, §32, §38.
- **Decision:** create `STRATEGY_SECOND_CHANCE_PROGRAMME`. Reclassify every historical rejected/retired/draft/style-blocked
  strategy by primary reason (NO_EXTERNAL_SOURCE, MARTINGALE, GRID, PYRAMIDING, MULTI_POSITION, SCALPING,
  HISTORICAL_POLICY, OLD_PORTFOLIO_CAP, OLD_HR16, ML_RUNTIME, ECONOMIC_FAIL, INFRA_FAIL, DUPLICATE,
  INSUFFICIENT_EVIDENCE, OTHER) → `STILL_INVALID` or `ELIGIBLE_FOR_RECONSIDERATION`. Strategies rejected only for
  now-superseded style/policy become second-chance candidates. Do not blindly retest the whole population; use the
  lineage/duplicate map + the 5,000+ Strategy-Wiki nodes to skip clones/trivial copies/already-refuted mechanics.
  Prioritize by novelty, expected edge, current evidence, validation cost, portfolio white-space, FTMO/DXZ relevance,
  independence, complexity, tail risk — **FTMO weighted heavily** (larger business gap). Historical verdicts remain
  immutable; create new lineage/review state. Expose a generated Second-Chance Register (not hand-maintained).
- **Implementation:** `e1_second_chance` (LATER SLICE) → `docs/research/STRATEGY_SECOND_CHANCE_PROGRAMME.md` + generated
  read-model + vault register.
- **Stays unchanged:** immutability of historical verdicts; duplicate/lineage map as the anti-clone guard.

### 13. Standalone-gate review + PORTFOLIO_UTILITY_CHALLENGER
- **Directive:** §27, §28.
- **Decision:** audit whether early standalone gates discard strategies that could be valuable portfolio components
  (modest PF, low Sharpe, low frequency, unusual payoff) despite positive expected contribution / diversification / tail
  protection / venue utility. Do **not** simply lower thresholds globally — perform counterfactual analysis (which
  historically rejected candidates would have improved the current portfolio out-of-sample). If justified, Fable is
  authorized to design a `PORTFOLIO_UTILITY_CHALLENGER` classification: it does NOT rewrite the original gate PASS; it
  means enough evidence exists to test portfolio utility despite failing an old standalone threshold. Such candidates
  require valid evidence, bounded risk, independent holdout, an explicit portfolio-role hypothesis; they may be evaluated
  against the current book but receive **no automatic live eligibility**.
- **Implementation:** `e2_portfolio_utility_challenger` (LATER SLICE) via the counterfactual procedure (item 14).
- **Stays unchanged:** original gate PASS records; live eligibility remains OWNER-gated.

### 14. Fable may derive selection thresholds statistically (counterfactual procedure)
- **Directive:** §29, §30, §47.
- **Decision:** OWNER delegates to Fable the determination of weekly book-change materiality, FTMO-Demo material-change
  significance, portfolio-utility thresholds and strategy-selection thresholds using statistical + economic evidence
  (self or delegated); do not ask OWNER for arbitrary percentages. Economic/**selection** gate thresholds (standalone PF,
  activity, filter assumptions, style exclusions) **may be challenged** — but ONLY via the §30 procedure: (1) estimate
  the candidates the threshold excluded, (2) evaluate their counterfactual portfolio value, (3) assess false-positive
  risk, (4) test the alternative on historical cohorts, (5) version the contract. Reversible, tested, historically
  auditable. **Never** weaken evidence integrity, provenance, lookahead protection, holdout separation, deterministic
  execution or data validity. "The goal is not more PASSes; the goal is better books."
- **Implementation:** the procedure is authorized now; each concrete threshold change is its own versioned decision +
  slice (LATER). No threshold is changed by this record.
- **Stays unchanged:** all gate *integrity* rules (RED); verdict semantics.

### 15. Live money signal + FTMO first-passage/breach model (high-priority data gaps)
- **Directive:** §33, §34.
- **Decision:** build the deterministic per-sleeve live PnL attribution feed from real DXZ execution data (realized/
  floating/gross/net, swap, commission, trade count, realized DD, contribution to book return + DD, live correlation/
  overlap where meaningful) and wire it into DXZ fitness, weekly recomposition, research ROI and lineage evaluation.
  Complete the FTMO first-passage/breach model (P[profit-target], P[daily-loss violation], P[total-loss violation],
  expected-time distribution, conditional failure modes) on the representative intended Demo portfolio; do not collapse it
  to a single misleading score.
- **Implementation:** `h1_live_sleeve_pnl` (LATER SLICE) → `docs/ops/LIVE_SLEEVE_PNL_ATTRIBUTION.md`;
  `i1_ftmo_probability` (LATER SLICE) completes `config/ftmo_probability_contract.v1.json`.
- **Stays unchanged:** T_Live/FTMO terminals read-only to AI; backtest evidence still matters.

### 16. Decision-grade vault completeness
- **Directive:** §35, §36, §37, §38, §39, §40, §41, §42, §44.
- **Decision:** the vault must contain enough current, decision-grade company knowledge that Fable/Claude/Codex/
  Antigravity/Kimi and an external decision-support agent can understand the company without old chat history or VPS
  access — **generated summaries, identities/hashes, state, evidence references, timestamps**, never secrets. Add/maintain
  the canonical pages: AI Factory Capacity & Routing (§36, this slice), Strategy Eligibility & Tail-Risk doctrine (§37),
  Second-Chance Register (§38), VPS Capacity & Scheduling (§39), Pattern & Filter Catalog (§40), and a decision-grade
  runtime mirror on a cadence (§41: DXZ book, weekly recomposition, FTMO Demo book, FTMO validation/readiness, live-PnL
  health, factory bottleneck, AI capacity, active research, strategy-wiki health, active OWNER decisions). Do not overload
  the vault with raw runtime (§42) — decision-grade summaries + hashes/links only. Each page distinguishes CONTRACT from
  CURRENT RUNTIME STATE.
- **Implementation:** `a1_ai_capacity_remeasure` lands the AI Factory Capacity & Routing page (docs + vault) + its
  generator; `j1_vault_completeness` (LATER SLICE) lands the remaining pages + the §41 mirror cadence.
- **Stays unchanged:** no secrets in docs/vault (§35); runtime truth stays runtime truth.

### 17. Mission Control additions
- **Directive:** §45.
- **Decision:** Mission Control surfaces factory efficiency: AI FACTORY (provider/model utilization, time-to-reset, queued
  eligible work, disabled/auth-failed providers, offload opportunities, useful completion rate, review-independence
  health); MT5 FACTORY (useful worker utilization, resource-blocked workers, RAM head-of-line stalls, runnable backlog,
  evidence/hour); SECOND CHANCE (eligible candidates, highest expected-value re-evaluations, currently re-testing, first
  survivors). Avoid vanity utilization metrics.
- **Implementation:** `d2_mission_control_efficiency` (LATER SLICE) consumes `ai_capacity.json` + the other read-models.
- **Stays unchanged:** Mission Control as the canonical decision-status surface.

### 18. Authority / stop conditions
- **Directive:** §47.
- **Decision:** OWNER authorizes Fable to statistically/economically determine portfolio-change materiality, Demo
  material-change thresholds, provider routing thresholds, low/medium-risk AI capability expansion, non-live strategy
  admission/selection improvements and second-chance prioritization — all evidence-based, versioned, tested, reversible,
  historically auditable. OWNER still controls: FTMO paid Challenge purchase, additional paid-account purchases, live
  AutoTrading activation, irreversible live financial actions. This directive does NOT authorize: runtime ML trading,
  uncontrolled/unbounded recovery risk, evidence deletion, historical verdict rewriting, hardware/VPS purchase or
  migration.
- **Implementation:** binding across all slices; enforced by the RED boundaries in every slice brief.
- **Stays unchanged:** the entire ROT zone (`CLAUDE.md` Stehende Vollmacht) and the Hard Rules.

## Implementation order (§43) — slice map

A `a1_ai_capacity_remeasure` (this slice: re-measure + AI capacity read-model + capacity/routing page + this decision) ·
B `b1_ai_capability_benchmark` · C `c1_dynamic_routing` · D `d1_strategy_eligibility_v2` / `d2_mission_control_efficiency`
· E `e1_second_chance` / `e2_portfolio_utility_challenger` · F `f1_tail_risk_engine` / `f2_pattern_filter_programme` ·
G `g1_vps_throughput` · H `h1_live_sleeve_pnl` · I `i1_ftmo_probability` · J `j1_vault_completeness`. (Slice keys are
descriptive; the orchestrator assigns the canonical ticket ids when commissioning each.)

## Measurement annex — AI capacity re-measure 2026-09-15T17:4xZ (§43A, this slice)

Re-measured through the authoritative tools only (not cached snapshots). Evidence:
`D:/QM/reports/state/ai_capacity.json` (`qm.ai-capacity/v1`), `quota_governor.log`, `agy_quota.json`,
`kimi_governor_state.json`.

| Provider | Weekly used | Remaining | Reset (UTC) | Pacing flag | Auth | Shadow price |
|---|---|---|---|---|---|---|
| Claude | 100% (hard ceiling) | 0% | 2026-09-17T22:00Z | `CLAUDE_DISABLED` (headless lane; interactive orchestrator unaffected) | ok | scarce (capped) |
| Codex | 80% (+31.7pts ahead of pace) | 20% | 2026-09-19T08:29Z | `CODEX_LOW_TOKENS`; budget line within (target 92% at reset) | ok | 1.86 (scarce) |
| Antigravity (agy) | 14.5% | 85.5% | 2026-09-15T~21:2xZ (rolling) | none | ok — `agy -p "Reply OK"` returned `OK` exit 0 (OWNER re-logged in) | 0.02 (spare) |
| Kimi (Allegro) | 0% (rolling_7d) | 100% | 2026-09-22T09:31Z | none (state NORMAL) | ok (managed usage endpoint) | 0.68 (spare) |

- **Finding:** the directive's inefficiency (§2/§8) is confirmed — Claude (100%) and Codex (80%) are both throttled while
  Antigravity (85.5% spare) and Kimi (100% spare) sit idle. Governor re-run (`quota_governor.py`) HELD both flags: they
  are warranted, not stale (OWNER's Claude top-up did **not** reduce the vendor's reported weekly utilization; the
  interactive orchestrator runs on the separate 5-hour window, at 48%). Both burn-authorization flags are expired and
  correctly ignored by the governor. No flag was hand-deleted.
- **agy auth:** the headless research-lane CLI now authenticates (OWNER completed relogin), so cross-vendor critique and
  research offload to agy are available again (§10). `agy_quota.json` (Gemini Code Assist API) independently shows 85.5%
  binding remaining.

## Observed-drift / notes

- `codex_fleet_pacer.py` and `codex_budget_line.py` remain the Codex weekly pacing authority (OWNER 2026-09-13); this
  directive does not change them, only adds the fleet-level shadow-price view on top.
- `last_benchmark_utc = EVIDENCE_MISSING` in `ai_capacity.json` until slice B lands the scorecard; every code/tests/
  repo_edit/ops offload opportunity is therefore `benchmark_gated` and NOT actionable yet — research/strategy/summary
  offloads to agy/kimi are actionable now because those providers already hold the capability in-contract.

## Rollback

- Delete `tools/strategy_farm/ai_capacity_readmodel.py` + its test + the `docs/ops/AI_FACTORY_CAPACITY_AND_ROUTING.md`
  page, revert the one-line append in `book_evolution_runner._default_state_builds`, and remove
  `D:/QM/reports/state/ai_capacity.json`. No governor, router, gate, verdict or DB state is touched by this slice, so
  rollback is inert. This decision record and the vault page are documentation; superseding them is a future OWNER
  decision, not a rollback.
