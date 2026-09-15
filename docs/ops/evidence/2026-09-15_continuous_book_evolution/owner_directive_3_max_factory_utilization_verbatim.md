# OWNER follow-up directive 2026-09-15 (third) — MAXIMUM FACTORY UTILIZATION · DYNAMIC AI ROUTING · STRATEGY ELIGIBILITY V2 · SECOND-CHANCE PROGRAMME · PORTFOLIO TAIL-RISK RESEARCH · FIXED-HARDWARE THROUGHPUT · DECISION-GRADE VAULT COMPLETENESS (verbatim)

Received 2026-09-15 ~17:3xZ in the Claude orchestrator session
(https://claude.ai/code/session_01EbahMJqzhTCfpmWAPcTaoE), prefixed `ULTRACODE`, after the master directive
(`owner_directive_verbatim.md`) and the completeness follow-up (`owner_followup_directive_completeness_verbatim.md`)
had been executed (phases A–I landed, audit `docs/ops/QUANTMECHANICA_COMPLETENESS_AND_GAP_AUDIT_2026-09-15.md`).
Transcribed verbatim; only heading levels and code fences added. Decision record:
`decisions/2026-09-15_owner_max_factory_utilization_eligibility_v2.md`.

---

ULTRACODE
QUANTMECHANICA — OWNER FOLLOW-UP DIRECTIVE
MAXIMUM FACTORY UTILIZATION
DYNAMIC AI ROUTING
STRATEGY ELIGIBILITY V2
SECOND-CHANCE PROGRAMME
PORTFOLIO TAIL-RISK RESEARCH
FIXED-HARDWARE THROUGHPUT
DECISION-GRADE VAULT COMPLETENESS
Authority: OWNER
Date: 2026-09-15
This directive extends the Continuous Book Evolution / FTMO Acceleration / Autonomous Edge Discovery operating model already implemented.
Do NOT rebuild systems that are already working.
The next objective is:
extract substantially more useful economic throughput from the AI factory, MT5 factory, existing strategy universe and existing VPS.
The company goal remains:
reach sustainable profitability as quickly as possible without taking stupid, poorly understood or uncontrolled risks.

## 1. CURRENT OWNER VIEW
QuantMechanica has become much better at preventing bad evidence.
It may still be too conservative about:

* which AI is allowed to do which task,
* which strategy styles are allowed,
* which historical strategies deserve another look,
* how aggressively existing prepaid AI capacity is used,
* how the fixed VPS is scheduled.

The next stage is not simply more caution.
The next stage is:
better allocation of constrained resources toward expected economic value.

## 2. MAXIMIZE THE WHOLE FACTORY — NOT INDIVIDUAL PROVIDERS
QuantMechanica currently has access to multiple AI providers/model tiers.
Current known lanes include approximately:
Codex family

* Astra
* Sol
* Luna

Claude family

* Fable
* Opus
* Sonnet
* Haiku

Other providers

* Antigravity / agy
* Kimi

Do not assume these aliases or exact model mappings remain permanent.
Inspect the actual current registry/configuration.
The OWNER objective is:
use all prepaid/available AI capacity intelligently.
Historically Claude and Codex often hit quota limits while Antigravity and Kimi retain substantial unused capacity.
This is economically inefficient when spare providers are capable of performing useful work.

## 3. PROVIDER ROLES MUST BECOME EMPIRICAL, NOT DOGMATIC
Provider specialization remains useful.
Provider silos do not.
Do not permanently say:

* "only Codex may code",
* "Kimi may never code",
* "Antigravity only discovers sources",
* "Claude must do every difficult review",

unless measured quality requires it.
Instead determine:
Which provider/model is sufficiently capable for this exact task at this exact risk level, given current quota and opportunity cost?
Small, reversible programming tasks may potentially be completed by:

* Codex,
* Claude,
* Antigravity,
* Kimi,

if the provider has demonstrated acceptable performance.
Do not assume capability.
Measure it.

## 4. CREATE AN AI CAPABILITY BENCHMARK
Build a small deterministic benchmark suite using representative QuantMechanica tasks.
Include examples such as:
Coding

* small Python bugfix,
* small Python feature,
* small MQL5 fix,
* simple `.mqh` module change,
* test repair,
* schema migration,
* small dashboard/read-model change.

Review

* code review,
* regression review,
* strategy-spec review,
* adversarial strategy critique.

Research

* source synthesis,
* long-context analysis,
* edge hypothesis,
* experiment interpretation.

Operations

* deterministic incident triage,
* documentation correction,
* task classification.

Run equivalent tasks through eligible providers/models.
Use sandbox/worktree tasks, never live-risk work for benchmarking.
Score at minimum:

* correctness,
* tests passed,
* regressions introduced,
* reviewer corrections required,
* task completion time,
* retries,
* context efficiency,
* quota consumption where measurable,
* ability to follow repository constraints.

Create a persistent:
`AI_CAPABILITY_SCORECARD`
per provider/model/task class.

## 5. EXPAND CAPABILITIES BASED ON EVIDENCE
The current Kimi lane is deliberately research-restricted.
That was appropriate for integration safety.
It does not have to remain permanent if Kimi demonstrates reliable software-engineering capability.
Likewise for Antigravity.
After benchmark success, Fable may grant additional scoped capabilities such as:

* `code_small`
* `tests_small`
* `repo_edit_scoped`
* `documentation`
* `readmodel`
* `review`

to underused providers.
Initial implementation work must remain:

* reversible,
* branch/worktree isolated,
* path-scoped,
* test-gated,
* independently reviewed when material.

Do NOT grant through this mechanism:

* T_Live authority,
* AutoTrading authority,
* financial purchase authority,
* unrestricted production ops,
* verdict manipulation,
* evidence deletion.

Those boundaries remain unchanged.

## 6. TASK-RISK ROUTING
Classify tasks by implementation risk.
Conceptually:
LOW RISK
Examples:

* docs,
* deterministic data transform,
* small isolated function,
* simple test,
* generated read-model,
* obvious bug with regression test.

Route to any provider/model with proven capability and spare capacity.
MEDIUM RISK
Examples:

* strategy implementation,
* larger Python module,
* MQL5 strategy logic,
* database migration,
* portfolio tooling.

Use a provider with strong measured performance.
Require tests and suitable review.
HIGH RISK
Examples:

* gate semantics,
* evidence contracts,
* portfolio risk engine,
* execution framework,
* live-readiness logic.

Use the strongest suitable provider/model and independent cross-provider review.
OWNER / LIVE RISK
Remain OWNER-controlled where existing authority requires it.

## 7. MODEL TIER SHOULD MATCH TASK DIFFICULTY
Do not waste the most capable models on mechanical work if another model reliably solves it.
Likewise do not assign genuinely difficult architecture/research to a small model merely because quota is available.
Fable should choose dynamically based on:

* task complexity,
* required context,
* failure cost,
* provider/model benchmark,
* current quota,
* time until reset,
* current queue,
* need for provider independence.

Use smaller/cheaper/faster tiers for easy work.
Reserve the most capable reasoning tiers for work where their marginal intelligence creates value.

## 8. AI CAPACITY SHOULD HAVE A SHADOW PRICE
The router should understand that remaining quota has changing opportunity cost.
Example:
Claude nearly exhausted with three days until reset
+
Kimi largely unused
+
Kimi is benchmark-qualified for a task
→ route the task to Kimi.
Likewise:
Codex nearly exhausted
+
Antigravity has ample capacity
+
task is an isolated small code fix
+
Antigravity benchmark is strong
→ use Antigravity.
Do not let a preferred provider consume scarce quota on work that another qualified provider can perform.
Conversely:
do not burn Kimi/agy calls on meaningless filler merely to achieve "100% usage".
The target is:
maximum useful value before each quota reset.

## 9. QUOTA PACING SHOULD USE ALL AVAILABLE CAPACITY
Re-measure current state now.
The OWNER has added additional Claude capacity since the previous audit.
Do not use stale quota snapshots.
Quota governance should forecast:

* usage remaining,
* time to reset,
* backlog value,
* model capability,
* current burn rate.

The objective is neither:

* quota hoarding,

nor:

* consuming everything immediately and starving later critical work.

Optimize expected useful throughput across the reset period.
Fable may adjust provider pacing accordingly without asking OWNER for routine approval.

## 10. CROSS-PROVIDER REVIEW SHOULD USE SPARE CAPACITY
Underused providers are particularly valuable as independent critics.
Restore Antigravity authentication when the OWNER completes relogin.
Then prefer true provider diversity where available.
Do not waste expensive primary-provider capacity duplicating work when a competent underused provider can provide independent challenge.
Track:

* creator provider,
* critic provider,
* same-vendor share,
* critic quality,
* critic correction yield.

Provider independence is useful only if critique quality is real.

## 11. MAXIMUM FACTORY UTILIZATION INCLUDES MT5
AI throughput is only one half of the factory.
MT5 throughput must also be optimized.
The OWNER explicitly does NOT currently want:

* a VPS migration,
* a VPS replacement,
* a hardware upgrade.

Do not propose these as the normal solution.
Optimize the existing host.

## 12. FIXED-VPS THROUGHPUT PROGRAMME
Measure the real resource footprint of test classes.
Maintain empirical estimates for:

* RAM,
* CPU,
* disk I/O,
* duration,
* symbol,
* gate,
* strategy family.

Replace simplistic queue ordering with resource-aware scheduling where useful.
A single 44-GB-class job must not head-of-line block multiple terminals when many smaller useful jobs can run.
Implement/adapt scheduling similar to bin packing:
fill available capacity with the highest-value combination of runnable jobs.
Heavy jobs may run:

* alone,
* in quieter windows,
* with reduced worker concurrency,

while smaller jobs fill remaining capacity.
The objective is:
maximum useful evidence per wall-clock hour on the existing VPS.

## 13. NO HARDWARE-UPGRADE PROJECT
For the current planning horizon:
no VPS move and no VPS hardware upgrade.
Record this as an OWNER decision.
If a task genuinely cannot run on the current machine:

* classify it,
* park it,
* find a more resource-efficient implementation,
* schedule it differently,
* reduce redundant computation,
* use hash-bound reuse where valid.

Do not repeatedly surface "buy a bigger VPS" as the solution.
Continue measuring constraints so the OWNER understands opportunity cost, but solve them in software/scheduling first.

## 14. STRATEGY ELIGIBILITY V2 — STYLE-AGNOSTIC
QuantMechanica has historically rejected or discouraged entire strategy styles too early.
This is superseded.
From now on:
strategy style alone is not a rejection reason.
The relevant questions are:

* Is the strategy mechanical?
* Is it testable?
* Is its risk measurable?
* Is its risk bounded sufficiently for the intended portfolio?
* Does the evidence support positive portfolio value?

## 15. MACHINE LEARNING BOUNDARY REMAINS
Carry forward the existing OWNER distinction:
Machine Learning MAY be used offline by the research system to discover mechanical relationships.
Machine Learning remains prohibited from the EA's trading decision engine.
Final EAs remain mechanical and deterministic.
No:

* runtime ML inference,
* online learning,
* black-box adaptive prediction.

## 16. NO EXTERNAL SOURCE IS REQUIRED
A strategy does NOT require:

* a book,
* video,
* paper,
* trader,
* website,
* external author.

Original strategies from:

* Fable,
* Kimi,
* OWNER,
* another authorized agent,
* internal statistical research,

are valid.
No external source is required.
Provenance remains required.
Internally originated strategies use:
`QM-RESEARCH://...`
or the canonical internal-research mechanism.
Do not confuse:
"no external source"
with
"no provenance".

## 17. EXPLICITLY ALLOWED STRATEGY FAMILIES
The following are explicitly valid research and strategy candidates:

* scalping,
* high-frequency-enough mechanical intraday trading,
* trailing-stop systems,
* positive pyramiding / adding to winners,
* negative pyramiding / adding to losers,
* martingale,
* reverse martingale / anti-martingale,
* bounded grid systems,
* bounded recovery systems,
* multiple simultaneous positions,
* basket management,
* partial exits,
* break-even logic,
* time exits,
* session strategies,
* pattern filters,
* price-action filters,
* volatility filters,
* regime filters,
* portfolio hedges,
* hybrids of the above.

Do not reject them simply because old QuantMechanica doctrine disliked the style.
Evidence decides.

## 18. MARTINGALE / GRID / NEGATIVE PYRAMIDING — NEW RULE
Martingale-like logic is NOT automatically prohibited.
However:
uncontrolled ruin risk is prohibited.
A tail-amplifying strategy must expose a deterministic risk contract.
At minimum quantify where applicable:

* maximum levels,
* sizing multiplier/progression,
* maximum open positions,
* maximum basket exposure,
* maximum gross notional,
* maximum margin consumption,
* maximum basket loss,
* deterministic emergency exit/equity-stop logic,
* gap sensitivity,
* spread/slippage sensitivity,
* worst historical sequence,
* stress sequence.

No infinite recovery sequence.
No "eventually price must return" assumption without a bounded account-loss condition.
A hard portfolio-level safety boundary may substitute for individual-trade SLs where the strategy design requires basket management.

## 19. DIVERSIFICATION MAY MAKE AGGRESSIVE STRATEGIES USEFUL — BUT MUST BE PROVEN
The OWNER explicitly wants QuantMechanica to investigate whether multiple individually aggressive strategies can form a safer, profitable total portfolio through genuine diversification.
This includes martingale / pyramiding / grid/recovery systems.
Do NOT assume this effect.
Measure it.
Normal-period correlation alone is insufficient.
Analyze:

* simultaneous adverse regimes,
* correlation convergence,
* common-symbol exposure,
* common-volatility exposure,
* news shocks,
* gap events,
* margin usage,
* drawdown clustering,
* worst-day overlap,
* tail dependence,
* joint basket escalation.

Ask:
Can these strategies support each other economically without creating a hidden common ruin mode?
Portfolio diversification is accepted only when the evidence supports it.

## 20. ONE EA MUST NOT BE ABLE TO DESTROY THE ACCOUNT
Regardless of strategy style:
a single sleeve must not be allowed to create uncontrolled account-terminating risk.
The portfolio risk layer should be capable of:

* limiting sleeve risk,
* limiting simultaneous basket risk,
* limiting account-wide open risk,
* detecting risk escalation,
* stopping further additions,
* applying venue-specific constraints.

This is more valuable than banning a strategy label.

## 21. POSITIVE AND NEGATIVE PYRAMIDING SHOULD BOTH BE RESEARCHED
Treat separately:
POSITIVE PYRAMIDING
Add exposure to winning positions.
Potential benefits:

* convex capture of strong trends,
* capital concentration when edge is confirmed.

Risks:

* late trend concentration,
* giveback,
* clustered exposure.

NEGATIVE PYRAMIDING
Add exposure as price moves adversely.
Potential benefits:

* mean-reversion capture,
* improved average price.

Risks:

* nonlinear tail exposure,
* margin escalation,
* regime failure.

Do not mix the two into one generic "pyramiding" label.
Test them as different mechanisms.

## 22. PATTERN FILTERS DESERVE A FRESH PROGRAMME
Audit the existing:

* PatternFilter framework,
* Patterns library,
* Q12 pattern-filter process,
* Andrea Unger-related pattern/filter concepts already available in sources/code.

Do not assume the historical pattern-filter implementation exhausts the opportunity.
Test pattern filters as modular overlays.
Measure:

* base strategy,
* strategy + each filter,
* combinations where justified,
* trade reduction,
* expectancy,
* DD,
* regime effect,
* portfolio effect.

Use proper ablation.
Keep a null/no-filter baseline.
Control multiple-testing risk.
Do not keep an arbitrary old "max N filters" rule as a Hard Rule unless evidence supports it.

## 23. SECOND-CHANCE STRATEGY PROGRAMME
The now-complete Strategy Wiki gives QuantMechanica the ability to systematically revisit historical strategies.
Create:
`STRATEGY_SECOND_CHANCE_PROGRAMME`
Audit:

* REJECTED strategies,
* RETIRED strategies,
* DRAFT strategies,
* strategies blocked by superseded rules,
* strategies that failed due to style rather than economics.

The current universe contains a large historical population.
Do not blindly retest all of it.

## 24. REJECTION-REASON RECLASSIFICATION
For every historical rejected/retired strategy determine the primary reason.
Classify reasons such as:

* NO_EXTERNAL_SOURCE
* MARTINGALE
* GRID
* PYRAMIDING
* MULTI_POSITION
* SCALPING
* HISTORICAL_POLICY
* OLD_PORTFOLIO_CAP
* OLD_HR16
* ML_RUNTIME
* ECONOMIC_FAIL
* INFRA_FAIL
* DUPLICATE
* INSUFFICIENT_EVIDENCE
* OTHER

Then determine:
`STILL_INVALID`
or
`ELIGIBLE_FOR_RECONSIDERATION`.
Strategies rejected only because of now-superseded style/policy restrictions should become second-chance candidates.
Historical verdicts remain immutable.
Create new lineage/review state.

## 25. DO NOT WASTE FACTORY TIME ON CLONES
Before re-testing a second-chance candidate:
use the current lineage/duplicate map.
Do not spend full MT5 validation on:

* exact clones,
* trivial parameter copies,
* already-refuted identical mechanics,

unless a materially different implementation or portfolio role justifies it.
Use the 5,000+ generated strategy knowledge nodes and behaviour-based lineage data to reduce redundant work.

## 26. PRIORITIZE SECOND-CHANCE CANDIDATES BY EXPECTED PORTFOLIO VALUE
Rank candidates using:

* novelty,
* expected edge,
* current evidence,
* validation cost,
* portfolio white-space,
* FTMO relevance,
* DXZ relevance,
* likely independence,
* execution complexity,
* tail risk.

FTMO currently deserves substantial weighting because it remains the larger business gap.

## 27. STANDALONE PERFORMANCE RULES MAY ALSO BE TOO STRICT
Audit whether current early gates discard strategies that could be valuable portfolio components.
Examples:

* modest standalone PF,
* low standalone Sharpe,
* low frequency,
* unusual payoff shape,

may still be valuable when they have:

* positive expected contribution,
* strong diversification,
* tail protection,
* specific venue utility.

Do not simply lower numeric thresholds globally.
Perform counterfactual analysis.
Ask:
Which historically rejected candidates would have improved the current portfolio out-of-sample if they had been allowed to reach portfolio evaluation?

## 28. CREATE A PORTFOLIO-UTILITY CHALLENGER CONCEPT IF JUSTIFIED
If evidence shows standalone gates are discarding useful portfolio components, Fable is authorized to design an additional classification such as:
`PORTFOLIO_UTILITY_CHALLENGER`
This does NOT rewrite the original gate PASS.
It means:
sufficient evidence exists to test portfolio utility despite failing an old standalone selection threshold.
Such candidates require:

* valid evidence,
* bounded risk,
* independent holdout,
* explicit portfolio-role hypothesis.

They may be evaluated against the current book.
They do NOT receive automatic live eligibility.

## 29. FABLE MAY DERIVE SELECTION THRESHOLDS STATISTICALLY
The OWNER delegates to Fable the determination of:

* weekly book-change materiality,
* FTMO Demo material-change significance,
* portfolio-utility thresholds,
* appropriate strategy-selection thresholds,

using statistical and economic evidence.
Fable may perform this itself or delegate analysis.
Do not repeatedly ask OWNER to choose arbitrary percentages.
When changing non-live selection/admission logic:

* create a versioned decision record,
* preserve historical verdicts,
* test the new rule,
* make it reversible,
* demonstrate expected economic benefit.

Evidence/data-integrity protections remain non-negotiable.

## 30. GATE RULES MAY EVOLVE WHEN THEY ARE SELECTION RULES
Historically gate thresholds were treated as nearly immutable.
The OWNER now explicitly authorizes review of numeric/economic strategy-selection gates where they may conflict with portfolio profitability.
Do NOT weaken:

* evidence integrity,
* provenance,
* lookahead protection,
* holdout separation,
* deterministic execution,
* data validity.

But economic thresholds such as:

* standalone PF,
* activity,
* filter assumptions,
* style exclusions,

may be challenged.
Before changing a threshold:

1. estimate what candidates it excluded,
2. evaluate their subsequent/counterfactual portfolio value,
3. assess false-positive risk,
4. test the proposed alternative on historical cohorts,
5. version the contract.

The goal is not more PASSes.
The goal is better books.

## 31. FTMO SECOND-CHANCE PRIORITY
For FTMO specifically search for candidates that may provide:

* higher opportunity density,
* shorter holding periods,
* lower swap,
* low overnight exposure,
* lower duration risk,
* controlled daily loss,
* robust recovery,
* uncorrelated intraday engines.

Review especially:

* scalpers,
* session systems,
* pattern systems,
* intraday mean reversion,
* trailing-stop systems,
* positive pyramiding,
* bounded negative pyramiding,
* bounded grid/recovery systems.

The FTMO portfolio does not need to resemble the DXZ portfolio.

## 32. DXZ SECOND-CHANCE PRIORITY
For DXZ evaluate second-chance strategies based on:

* marginal portfolio return,
* drawdown reduction,
* diversification,
* tail behaviour,
* D-Score relevance,
* long-term sustainability.

A strategy may be useful even if it would never be selected for FTMO.

## 33. LIVE MONEY SIGNAL IS A HIGH-PRIORITY MISSING INPUT
Current portfolio recomposition still lacks robust realized live PnL attribution per sleeve.
This is now a high-priority data gap.
Build the deterministic attribution feed from real DXZ execution data.
Produce per sleeve:

* realized PnL,
* floating PnL where relevant,
* gross/net result,
* swap,
* commission,
* trade count,
* realized DD,
* contribution to book return,
* contribution to book DD,
* live correlation / overlap where statistically meaningful.

Wire this into:

* DXZ fitness,
* weekly recomposition,
* research ROI,
* strategy lineage evaluation.

Backtest evidence remains important.
But a live trading company must eventually learn from live money.

## 34. FTMO FIRST-PASSAGE / BREACH MODEL IS ALSO HIGH PRIORITY
Current FTMO decision state lacks complete first-passage evidence for the intended future portfolio.
Implement/complete:

* probability of profit-target hit,
* probability of daily-loss violation,
* probability of total-loss violation,
* expected time distribution,
* conditional failure modes.

Use the representative intended Demo portfolio.
Do not reduce the result to a single misleading score.

## 35. VAULT MUST CONTAIN DECISION-GRADE COMPANY KNOWLEDGE
The Company Reference Vault must contain enough current information that:

* Fable,
* Claude,
* Codex,
* Antigravity,
* Kimi,
* and an external decision-support agent such as ChatGPT

can understand the company and make informed recommendations without relying on old chat history or direct access to the VPS.
This does NOT mean storing secrets.
Do NOT copy:

* passwords,
* access tokens,
* private keys,

into general company documentation.
Instead store:

* generated summaries,
* identities/hashes,
* state,
* evidence references,
* timestamps.

## 36. ADD / MAINTAIN AN AI FACTORY CAPACITY PAGE
The Vault needs a canonical current page covering:
`AI Factory Capacity & Routing`
At minimum include:

* providers,
* model tiers,
* allowed capabilities,
* capability benchmark scores,
* quota/reset windows,
* current pacing state,
* current disabled/throttled state,
* active routing policy,
* known provider strengths,
* known weaknesses,
* independent-review availability,
* most recent benchmark date.

This page should distinguish:
CONTRACT
from
CURRENT RUNTIME STATE.

## 37. ADD A STRATEGY ELIGIBILITY & TAIL-RISK DOCTRINE
Create/update a canonical page documenting:

* allowed strategy styles,
* runtime ML prohibition,
* internal-source policy,
* martingale policy,
* grid policy,
* pyramiding policy,
* scalping policy,
* trailing-stop policy,
* multi-position policy,
* pattern-filter policy,
* bounded-risk requirements,
* portfolio tail-risk requirements.

A future research agent must not resurrect old prohibitions accidentally.

## 38. ADD A SECOND-CHANCE STRATEGY REGISTER
Vault should expose:

* historical candidate,
* old rejection reason,
* whether reason is superseded,
* second-chance status,
* new lineage,
* re-test priority,
* DXZ potential,
* FTMO potential,
* duplicate status.

Do not manually maintain it.
Generate from canonical strategy state.

## 39. ADD A CURRENT VPS CAPACITY & SCHEDULING PAGE
Document:

* current hardware,
* live-reserved resources,
* RAM classes,
* heavy-job handling,
* disk low-water,
* research scratch placement,
* current scheduler/admission rules,
* current bottlenecks,
* OWNER decision:
`NO VPS UPGRADE / NO VPS MIGRATION CURRENTLY`.

Do not treat volatile free-RAM values as permanent facts.
Use generated current state plus stable policy.

## 40. ADD / MAINTAIN A PATTERN & FILTER CATALOG
The company knowledge layer should make the filter universe visible.
Include:

* existing Patterns,
* PatternFilter modules,
* Andrea Unger-derived patterns where available,
* price-action patterns,
* trend filters,
* volatility filters,
* news filters,
* session filters,
* historical filter test results,
* null/no-filter results.

This should feed Q12 and autonomous research.

## 41. DECISION-GRADE VAULT MIRROR
Important runtime facts should be projected to the Vault on a regular cadence.
At minimum include summaries for:

* current DXZ book,
* latest weekly recomposition,
* current FTMO Demo book,
* FTMO validation day/status,
* Challenge readiness,
* live PnL attribution health,
* factory bottleneck,
* AI capacity,
* active Kimi/Fable research,
* strategy-wiki health,
* active material OWNER decisions.

Do not manually copy SQLite.
Generate a human-readable read-model.

## 42. DO NOT OVERLOAD THE VAULT WITH RAW RUNTIME
The Vault is company knowledge.
It should not become:

* a dump of millions of DB rows,
* a duplicate runtime database,
* a log archive.

Store decision-grade summaries and links/hashes to evidence.
Runtime truth remains runtime truth.
Vault explains it.

## 43. IMPLEMENTATION ORDER
Execute this follow-up in the following order.
A — RE-MEASURE AI CAPACITY
Because Claude has been topped up since the prior audit:

* refresh all provider quotas,
* clear stale throttle state only through the authoritative governor,
* restore Antigravity when authenticated,
* measure Kimi available capacity.

B — AI CAPABILITY BENCHMARK
Benchmark providers/models and create the empirical task-capability matrix.
C — DYNAMIC ROUTING
Adjust router capabilities and quota-aware routing.
Begin offloading suitable low-risk work from saturated providers.
D — STRATEGY ELIGIBILITY V2
Update current strategy doctrine.
Remove obsolete style-based rejection.
E — SECOND-CHANCE SCAN
Reclassify historic rejects/retirements against the new doctrine.
Generate prioritized candidates.
F — TAIL-RISK ENGINE
Ensure martingale/grid/pyramiding strategies can be evaluated with explicit portfolio tail-risk evidence.
G — VPS THROUGHPUT
Eliminate resource head-of-line blocking and improve scheduling on the existing server.
H — MONEY SIGNAL
Build live per-sleeve PnL attribution.
I — FTMO PROBABILITY MODEL
Finish first-passage/breach analysis.
J — VAULT COMPLETENESS
Add/update all decision-grade canonical pages and generated state.

## 44. REQUIRED DELIVERABLES
Use existing canonical conventions and avoid duplicate documentation.
At minimum produce/update:
`docs/ops/AI_FACTORY_CAPACITY_AND_ROUTING.md`
`docs/ops/AI_CAPABILITY_BENCHMARK_2026-09.md`
`docs/research/STRATEGY_ELIGIBILITY_V2.md`
`docs/research/STRATEGY_SECOND_CHANCE_PROGRAMME.md`
`docs/research/PORTFOLIO_TAIL_RISK_RESEARCH.md`
`docs/research/PATTERN_FILTER_CATALOG.md`
`docs/ops/VPS_CAPACITY_AND_SCHEDULING.md`
`docs/ops/LIVE_SLEEVE_PNL_ATTRIBUTION.md`
appropriate generated second-chance read-model
appropriate AI capacity read-model
Vault projections of all current company policies.
Where equivalent canonical pages already exist:
update them instead of duplicating them.

## 45. MISSION CONTROL ADDITIONS
Mission Control should make factory efficiency visible.
Add decision-useful indicators such as:
AI FACTORY

* provider/model utilization,
* time to reset,
* queued eligible work,
* disabled/auth-failed providers,
* offload opportunities,
* useful completion rate,
* review-independence health.

MT5 FACTORY

* useful worker utilization,
* resource-blocked workers,
* RAM head-of-line stalls,
* runnable backlog,
* evidence produced per hour.

SECOND CHANCE

* eligible historical candidates,
* highest expected-value re-evaluations,
* currently re-testing,
* first survivors.

Avoid vanity utilization metrics.
100% busy doing useless work is worse than 70% busy doing valuable work.

## 46. SUCCESS CRITERIA
This directive succeeds when:

* Claude/Codex no longer routinely exhaust while qualified Agy/Kimi capacity sits unused,
* low-risk work can flow to multiple proven providers,
* strong models are reserved for strong-model work,
* cross-provider review independence improves,
* MT5 no longer suffers avoidable heavy-job head-of-line blocking,
* strategy style is not an arbitrary rejection reason,
* martingale/grid/pyramiding can be tested under explicit bounded-risk contracts,
* old strategies blocked by obsolete rules receive systematic second-chance review,
* portfolio utility can rescue useful nontraditional candidates,
* live money contribution becomes measurable per sleeve,
* FTMO Challenge probability becomes quantitatively measurable,
* Vault contains sufficient decision-grade state for informed company-level decisions.

## 47. OWNER AUTHORITY / STOP CONDITIONS
The OWNER authorizes Fable to statistically/economically determine:

* portfolio-change materiality,
* Demo material-change thresholds,
* provider routing thresholds,
* low/medium-risk AI capability expansion,
* non-live strategy admission/selection improvements,
* second-chance prioritization.

These changes must remain:

* evidence-based,
* versioned,
* tested,
* reversible,
* historically auditable.

OWNER still controls:

* FTMO paid Challenge purchase,
* additional paid account purchases,
* live AutoTrading activation where current authority requires it,
* irreversible live financial actions.

This directive explicitly does NOT authorize:

* runtime ML trading,
* uncontrolled/unbounded recovery risk,
* evidence deletion,
* historical verdict rewriting,
* hardware/VPS purchase or migration.

## 48. FINAL OPERATING PRINCIPLE
QuantMechanica should not ask:
Which strategies are respectable?
It should ask:
Which mechanical strategies improve our probability of making money while keeping total portfolio risk survivable?
It should not ask:
Which AI was historically assigned this type of task?
It should ask:
Which currently available model can complete this task to the required standard fastest, with the lowest opportunity cost?
It should not ask:
Which old strategy rules are easiest to preserve?
It should ask:
Which rules actually improve economic outcomes?
And:
Martingale is not automatically bad.
Scalping is not automatically good.
A published source does not create edge.
An unconventional strategy is not automatically dangerous.
A conventional strategy is not automatically safe.
Evidence decides.
At portfolio level.
With real money outcomes as the final feedback signal.
