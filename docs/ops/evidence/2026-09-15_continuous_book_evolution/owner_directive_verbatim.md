# OWNER directive 2026-09-15 — MASTER OWNER DIRECTIVE: CONTINUOUS BOOK EVOLUTION / FTMO ACCELERATION / AUTONOMOUS EDGE DISCOVERY / KIMI QUANT RESEARCH (verbatim)

Received 2026-09-15 ~12:1xZ in the Claude orchestrator session
(https://claude.ai/code/session_01EbahMJqzhTCfpmWAPcTaoE), prefixed `ULTRACODE`. Transcribed verbatim below; the only
edits are Markdown fences around the YAML block and heading levels. Decision record:
`decisions/2026-09-15_owner_continuous_book_evolution.md`. Programme evidence: this directory.

---

ULTRACODE
QUANTMECHANICA — MASTER OWNER DIRECTIVE
CONTINUOUS BOOK EVOLUTION
FTMO ACCELERATION
AUTONOMOUS EDGE DISCOVERY
KIMI QUANT RESEARCH
Date: 2026-09-15
Authority: OWNER
Priority: COMPANY-LEVEL OPERATING DIRECTIVE

## 0. PURPOSE OF THIS DIRECTIVE
This directive defines the current operating objective and supersedes older QuantMechanica intermediate goals, process constraints and portfolio rules wherever they conflict with the decisions stated here.
QuantMechanica is a systematic trading business.
The objective is:
make money through continuously improving systematic portfolios on DarwinexZero and FTMO.
The system must remain evidence-driven.
But the evidence machinery exists to help us make better trading decisions.
It must not become an end in itself.
Do not optimize QuantMechanica for:

* number of Strategy Cards,
* number of tested EAs,
* number of completed tickets,
* number of AI calls,
* number of pipeline rows,
* arbitrary candidate-count milestones,
* or historical process compliance for its own sake.

Optimize for:
validated expected economic improvement of the DarwinexZero and FTMO books.

## 1. TRUTH HIERARCHY
Before making changes, reconstruct the CURRENT system from the actual VPS.
Truth precedence:

1. explicit current OWNER directives,
2. current signed decisions/contracts,
3. current repo implementation,
4. runtime / SQLite / filesystem state,
5. immutable reports and evidence,
6. Company Reference Vault,
7. historical documents,
8. Notion and other legacy material as context only.

Inspect at minimum:

* `C:\QM\repo`
* current Git status and branch state
* `D:\QM\strategy_farm\state\farm_state.sqlite`
* `D:\QM\reports`
* current MT5 worker state
* current Scheduled Tasks
* current gate manifest
* current agent registry
* current routing configuration
* current AI quota state
* current DXZ runtime state
* current FTMO Demo state
* current Mission Control state
* current OWNER decisions
* current Company Reference Vault

Read the CURRENT versions of at least:

* `_HOME`
* `START_HERE`
* `Current Objective`
* `Hard Rules`
* `Company Structure`
* `AI Agent Routing and Role Contracts`
* `Research Methodology`
* `Pipeline Overview`
* `Q15`
* `Q16`
* `Q17`
* `FTMO Campaign`
* `Lessons Learned`
* `Determinism Over LLM Calls`
* `AI Spend / Quota Governance`
* Standing Authority / OWNER delegation
* current operating state

Do not trust stale Vault numbers over current runtime truth.

## 2. NORTH STAR
QuantMechanica has two primary economic engines.
ENGINE A — DARWINEXZERO
Purpose:
long-term systematic performance → strong D-Score → increasing external allocation / AUM.
DarwinexZero is already LIVE.
The DXZ book is therefore a production portfolio.
Its job is to:

* produce sustainable returns,
* control drawdown,
* diversify genuine sources of risk,
* remain operationally robust,
* improve over time,
* increase its attractiveness for external allocation.

The live book is not a final static portfolio.
It is a continuously evolving book.
ENGINE B — FTMO
Purpose:
successful Challenges → funded accounts → repeatable payouts → scalable cash generation.
FTMO is currently still primarily in Demo / validation.
That is too far from the desired economic outcome.
FTMO must be accelerated.
However:
acceleration does not mean gambling on paid Challenges.
OWNER preference is explicit:
It is better to need longer and pass one paid Challenge with the greatest realistically achievable confidence than to repeatedly lose paid Challenges.

## 3. THE NUMBER OF STRATEGIES IS NOT A BUSINESS GOAL
The former objective:
`WAY TO 25`
is abolished as a business target.
The OWNER does not care whether the best portfolio is selected from:

* 8 candidates,
* 15 candidates,
* 25 candidates,
* 50 candidates,
* 100 candidates,
* or 500 candidates.

Candidate count is a diagnostic.
It is not success.
Remove the prominent "Way to 25" objective from:

* Mission Control,
* Morning Briefing,
* current operating dashboards,
* current objective documentation,

wherever it is presented as a prerequisite to portfolio progress.
Historical records explaining the old rule must remain available.
Do not rewrite history.
Mark obsolete rules as superseded.

## 4. SUPERSEDE THE FIXED Q15 25-CANDIDATE TRIGGER
The old rule:
`BOOK BUILD PERMITTED ⇔ qualified_candidates >= 25`
is explicitly superseded.
There is no OWNER-mandated arbitrary minimum number of candidates before portfolio construction may be evaluated.
The portfolio engine may evaluate any currently valid qualified pool.
This does NOT mean weak/unqualified strategies become eligible.
The distinction is:
OLD:
We cannot evaluate/build a book because there are fewer than 25 candidates.
NEW:
We evaluate whatever valid candidate pool exists and determine whether a better feasible portfolio exists.
A pool of 9 genuinely strong independent strategies may produce a useful portfolio.
A pool of 50 poor/correlated strategies may not.
Update the relevant:

* Q15 contract,
* book guard,
* Mission Control logic,
* portfolio builder assumptions,
* current documentation,
* tests,
* decision records.

Create an explicit OWNER decision artifact superseding the old 25-candidate trigger.

## 5. TWO PERMANENTLY EVOLVING BOOKS
QuantMechanica operates two living books:
`DXZ_BOOK`
and
`FTMO_BOOK`
They are related through shared research and infrastructure.
They are NOT the same optimization problem.
Every suitable candidate should eventually have independent:
`DXZ_FITNESS`
and
`FTMO_FITNESS`.
Possible result:

* DXZ only
* FTMO only
* both
* neither

Never assume that a Darwinex survivor is automatically a good FTMO strategy.
Never force the FTMO portfolio to mirror DXZ.

## 6. WEEKLY BOOK RECOMPOSITION IS A CORE BUSINESS PROCESS
Every trading week ends with a portfolio re-evaluation.
Primary decision window:
Friday market close → Saturday → Sunday → before next market open
During the week:

* candidates progress through validation,
* existing live/demo evidence accumulates,
* external research continues,
* internal edge research continues,
* Kimi research continues,
* portfolio analytics may be precomputed.

During the weekend:
Fable evaluates independently:
`CURRENT DXZ BOOK`
vs.
`BEST CURRENT DXZ ALTERNATIVE`
and
`CURRENT FTMO BOOK`
vs.
`BEST CURRENT FTMO ALTERNATIVE`.
The relevant question is not:
Did we receive new strategies?
The relevant question is:
Has the evidence changed enough that the optimal portfolio decision changed?
Valid weekly outcomes include:

* KEEP
* ADD SLEEVE
* REMOVE SLEEVE
* REPLACE SLEEVE
* CHANGE RISK WEIGHT
* PLACE ON PROBATION
* PROMOTE
* RETIRE
* CONTINUE OBSERVATION
* NO VALID CHANGE

The weekly default is NOT CHANGE.
The weekly default is:
KEEP unless material evidence supports improvement.

## 7. THE PORTFOLIO IS THE PRODUCT
Do not optimize EAs in isolation from their portfolio role.
A strategy with lower standalone PF may materially improve:

* diversification,
* drawdown,
* robustness,
* return consistency,
* effective number of bets.

A high-PF strategy may add almost no value when it duplicates an incumbent.
Evaluate marginal portfolio contribution.
Use at minimum:

* expected return,
* realized/simulated volatility,
* max drawdown,
* tail loss,
* Sharpe or equivalent,
* marginal Sharpe,
* correlations,
* downside correlations,
* trade overlap,
* session overlap,
* symbol exposure,
* strategy mechanism,
* family exposure,
* regime exposure,
* trade frequency,
* holding time,
* transaction cost,
* swap,
* execution uncertainty,
* effective number of independent bets.

## 8. OLD PORTFOLIO CAPS ARE NOT HARD RULES
Historical restrictions such as:

* maximum 3 EAs per family,
* maximum 2 EAs per symbol,
* fixed pairwise correlation limit,
* other static concentration cutoffs,

must no longer be treated as absolute Hard Rules unless a separate risk/safety reason requires it.
Convert them into:

* default guardrails,
* warnings,
* diagnostics,
* portfolio risk inputs.

Examples:
Three genuinely different XAUUSD mechanisms are not automatically the same risk merely because they trade Gold.
Three differently named strategies with almost identical trades are not diversification.
Measure real economic dependence.
Use:

* trade overlap,
* return dependence,
* tail dependence,
* timing dependence,
* mechanism similarity,
* common factor exposure.

Do not replace the old static caps with another arbitrary set of permanent caps.
Portfolio-level risk is the real constraint.

## 9. DARWINEXZERO — CONTINUOUS LIVE EVOLUTION
DXZ is already live.
It must remain operational while the research/factory system continues improving the candidate universe.
A newly qualified candidate does not automatically replace an incumbent.
For every proposed change, Fable must answer:

* What exactly changes?
* What evidence changed?
* What does the challenger contribute?
* Which incumbent is displaced?
* What improves at portfolio level?
* What could become worse?
* Is the improvement material?
* What is the confidence?
* What is the operational risk?

Do not change the book for cosmetic optimization.

## 10. Q17 MIN-LOT RULE IS SUPERSEDED
The OWNER explicitly rejects a universal mandatory min-lot live burn-in.
The historic rule:
every new DXZ sleeve must run at minimum lot for 14 calendar days
is superseded.
Mandatory min-lot does not automatically produce meaningful evidence.
Likewise:
a fixed 14-day waiting period must not automatically prevent weekly portfolio evolution merely because it historically existed.
Refactor Q17 into an:
evidence-based live introduction / probation / deployment stage.
Appropriate initial live risk should depend on:

* amount of validated historical evidence,
* novelty,
* strategy tail risk,
* execution uncertainty,
* broker-equivalence confidence,
* current portfolio risk,
* available live evidence,
* liquidity,
* expected trade frequency.

Valid introduction choices may include:

* intended full portfolio weight,
* reduced probation weight,
* staged risk increase,
* incumbent/challenger parallel observation,
* no introduction.

Do not use min-lot merely to satisfy a procedural checkbox.
Any reduced-risk probation must have an explicit evidence/risk reason.
Actual live activation remains subject to OWNER authority defined below.

## 11. FTMO — BUSINESS OBJECTIVE
Current preferred path:
`FTMO DEMO`
→ `two-week serious validation`
→ `OWNER purchase decision`
→ `100k 2-Step Challenge`
→ `Verification if applicable`
→ `FTMO Account`
→ `Payouts`
→ `Scale`
FTMO is not an academic project.
The Demo is supposed to help QuantMechanica reach a rational paid decision.
Do not remain indefinitely on Demo because an internal process rule is impossible to satisfy.
But do not pay for a Challenge merely because the system is impatient.

## 12. MANDATORY FTMO TWO-WEEK DEMO BEFORE PURCHASE
Before purchasing a paid FTMO Challenge:
run at least one complete serious two-week FTMO Demo validation cycle using the intended Challenge portfolio and execution policy as closely as practical.
At the end of the period:
Fable produces an OWNER decision package.
The result may be:

* BUY RECOMMENDED
* EXTEND DEMO
* RECOMPOSE AND RESTART VALIDATION
* NOT READY

The two-week rule is a minimum evidence period before purchase.
It is NOT:
automatically buy after 14 days.
If substantial uncertainty remains:
continue Demo.
If the intended Challenge portfolio changes materially during the validation period:
assess whether the Demo remains representative.
A material strategy/risk/compliance change should normally trigger a new or extended representative validation period.
Do not pretend stale Demo evidence validates a materially different portfolio.

## 13. FTMO PAID CAPITAL POLICY
OWNER current preference:
100k, 2-Step.
Treat this as the default target.
Fable is allowed to evaluate other CURRENT FTMO account/product structures.
If another product has a materially better economic fit for the proven portfolio:
prepare a recommendation.
Do not change product merely because one headline rule looks easier.
Compare full economics.
Purchase remains OWNER-only.

## 14. ONLY ONE PAID FTMO CHALLENGE AT A TIME
Current OWNER policy:
one active paid Challenge at a time.
Default size:
100k.
Do not build a business model around:

* buying many Challenges,
* tolerating frequent failures,
* cycling resets,
* statistical mass attempts.

The objective is:
maximize the probability that the single paid Challenge succeeds.
A slower successful Challenge is preferable to a fast failed Challenge.
Any second simultaneous paid Challenge requires a future OWNER decision.

## 15. FTMO SUCCESS PROBABILITY > SPEED
Previous objectives around:

* fastest possible +10%,
* <=30 days,
* hard 60-day first-passage targets,

must be re-evaluated where they conflict with the OWNER's current priority.
The priority is:
highest realistically achievable probability of successfully completing the paid Challenge while still operating a positive-expectancy business.
Metrics such as:

* FUND_SCORE,
* first-passage probability,
* median time,
* P(pass ≤30d),
* P(pass ≤60d),

remain valuable evidence.
They are not automatically eternal Hard Rules.
The final paid decision should answer:
Is buying this one 100k Challenge now a sufficiently high-confidence positive-EV business decision?

## 16. FTMO DEMO MUST BE USED AGGRESSIVELY
The FTMO Demo is a research and validation environment.
Measure at account and sleeve level:

* progression toward profit target,
* daily-loss behaviour,
* total drawdown,
* recovery time,
* losing streaks,
* trade density,
* open risk,
* correlated risk,
* stop-risk concentration,
* simultaneous exposure,
* spread,
* commissions,
* swaps,
* slippage proxies,
* session behaviour,
* news behaviour,
* holding time,
* gap exposure,
* target passage dynamics.

Do not ask only:
Did Demo make money?
Ask:
Would we rationally risk a paid Challenge fee on this exact system?

## 17. FTMO MAY NEED COMPLETELY DIFFERENT STRATEGIES
Do not constrain FTMO to strategies designed for DXZ.
Useful FTMO properties may include:

* robust higher trade frequency,
* short holding time,
* low overnight exposure,
* low swap burden,
* controlled intraday risk,
* predictable stops,
* rapid recovery,
* stable positive drift,
* good opportunity density,
* low tail dependence.

A strategy may be highly valuable for FTMO and irrelevant to DXZ.
That is acceptable.

## 18. SCALPING IS EXPRESSLY ALLOWED
The OWNER explicitly allows scalping.
Do NOT reject strategies merely because they:

* trade low timeframes,
* trade frequently,
* have short holding periods.

Evaluate actual net economics.
For scalping investigate carefully:

* spread,
* commission,
* slippage,
* execution latency sensitivity,
* realistic fill assumptions,
* broker symbol conditions,
* stop-distance restrictions,
* robustness across execution regimes.

Scalping may be particularly valuable for FTMO if it improves:

* opportunity density,
* time to target,
* intraday capital efficiency,
* overnight risk,
* swap cost.

## 19. TRAILING STOPS ARE EXPRESSLY ALLOWED
Trailing-stop systems are permitted.
Research may include:

* ATR trailing,
* volatility trailing,
* swing/structure trailing,
* candle trailing,
* stepped trailing,
* breakeven + trailing,
* profit-lock trailing,
* time-dependent trailing,
* hybrid trailing logic.

If a simple mechanical scalping strategy with trailing management produces superior FTMO economics:
pursue it.

## 20. RULES SERVE THE BUSINESS — NOT THE OTHER WAY ROUND
QuantMechanica's early rules were intentionally conservative.
Some may now be stronger than required.
For each important rule distinguish:
A. SAFETY / EVIDENCE
Prevents:

* invalid evidence,
* data contamination,
* hidden live risk,
* non-deterministic results,
* accidental live actions,
* lost provenance.

Protect these strongly.
B. ECONOMIC / SELECTION
Represents current beliefs about what makes a strategy good.
These may evolve.
C. PROCESS
Represents how work is organized.
These may be optimized.
D. HISTORICAL CONSTRAINT
May exist because of old infrastructure or prior limitations.
These should not survive automatically.
For each material rule ask:

* Why was this introduced?
* What failure does it prevent?
* Is that failure still relevant?
* Is it stronger than necessary?
* What is its opportunity cost?
* Is there a cheaper/easier protection?
* Does it improve economic outcomes?
* Does it merely create waiting?

Do not confuse bureaucracy with robustness.

## 21. RULE EFFECTIVENESS AUDIT
Create:
`RULE_EFFECTIVENESS_AUDIT_2026-09.md`
Audit at minimum:

* fixed 25-candidate rule,
* Q17 min-lot,
* Q17 14-day fixed waiting period,
* family caps,
* symbol caps,
* fixed correlation caps,
* HR16,
* Research source restrictions,
* FTMO purchase thresholds,
* FTMO density rules,
* redundant pipeline gates,
* serial dependencies,
* AI quota restrictions,
* resource thresholds.

For each:

* original purpose,
* current benefit,
* current cost,
* safety impact,
* recommendation,
* rollback.

Implement items already explicitly decided by this directive.
Only return genuinely unresolved high-impact OWNER questions.

## 22. PIPELINE REMAINS THE VALIDATION ENGINE
This directive does NOT authorize weak validation.
Preserve meaningful:

* real-tick testing,
* deterministic execution,
* IS/OOS separation,
* walk-forward,
* robustness,
* parameter plateaus,
* stress testing,
* multiple seeds where economically meaningful,
* statistical validation,
* news analysis,
* evidence lineage,
* operational verification.

The pipeline protects QuantMechanica from fooling itself.
But audit whether every current gate:

* still detects a meaningful failure mode,
* duplicates another gate,
* uses stale assumptions,
* wastes excessive compute for little information,
* is unnecessarily serial.

Do not lower criteria merely to create more PASSes.
Improve efficiency when the same evidence quality can be achieved more intelligently.

## 23. PIPELINE IS CONTINUOUS — NOT A GLOBAL DRAIN BARRIER
The old doctrine:
everything must completely drain before another book can be built
is superseded.
Maintain two objectives simultaneously.
FRONTIER PROGRESSION
Advance promising/current candidates toward book eligibility.
BACKLOG HYGIENE
Resolve:

* stale items,
* infra failures,
* unknown dispositions,
* historical backlog,

as capacity permits.
Do not allow thousands of old early-stage items to globally block a material live portfolio improvement.

## 24. CONTROLLED PARALLELISM IS EXPRESSLY ALLOWED
The old absolute HR16 concept:
only one research / one EA development at a time
is no longer binding as an absolute restriction.
OWNER authorizes controlled parallelism.
Fable may run multiple parallel:

* research programmes,
* mechanization tasks,
* coding tasks,
* reviews,
* analyses,

when:

* evidence remains isolated,
* task identity remains clear,
* repo changes do not conflict,
* compute allows it,
* MT5 capacity is protected,
* AI quotas allow it,
* critical-path work is protected.

Do not create uncontrolled idea spam.
But do not serialize independent useful work merely because the old system did so.

## 25. FABLE IS THE ORCHESTRATION INTELLIGENCE
Fable owns resource prioritisation.
Available resources include:

* deterministic Python/SQL tooling,
* MT5 factory,
* Claude,
* Codex,
* Antigravity/agy,
* Kimi.

Fable decides which tool/provider is appropriate.
Optimize for:
expected economic information/value per unit of time, compute and AI capacity.
Not provider loyalty.
Not equal distribution.

## 26. DETERMINISM FIRST
For every task ask:
A. Is there already a deterministic tool?
Use it.
B. Can Python / SQL / statistics reliably solve it?
Build/use the deterministic method.
C. Does it require:

* interpretation,
* hypothesis generation,
* ambiguity resolution,
* synthesis,
* adversarial reasoning?

Then use an LLM.
Never waste LLM capacity on:

* PnL calculation,
* DD calculation,
* Sharpe,
* PF,
* correlations,
* path lookup,
* magic numbers,
* setfiles,
* queue counts,
* file existence,
* gate arithmetic,
* dedup that can be scripted.

LLMs reason about evidence.
They do not replace the evidence engine.

## 27. EXISTING KIMI IMPLEMENTATION IS THE BASELINE
The Kimi integration from 2026-09-15 has already been implemented.
Do NOT rebuild it.
Treat the current implementation as baseline unless an actual defect is found.
Existing components include:

* `kimi_adapter.py`
* `kimi_governor.py`
* Kimi router lane
* Kimi orchestration adapter
* Creator → Critic integration
* internal research source contract
* research environment
* observation projector
* search-history ledger
* preregistration tooling
* mechanization check
* experiment memory
* usage ledger
* fail-closed mutation protection
* internal R1 validation
* cross-vendor review

Preserve existing successful tests and safety properties.
Do not refactor unrelated pieces for aesthetics.

## 28. KIMI PERMANENT ROLE
Kimi is a first-class QuantMechanica:
Quant Research / Edge Discovery provider.
Primary capabilities:

* deep research,
* large-context synthesis,
* edge discovery,
* cross-experiment analysis,
* hypothesis authoring,
* ML research,
* research review,
* research criticism.

Kimi is NOT primarily:

* a log summarizer,
* a general coding worker,
* an ops worker.

Keep the research specialization unless empirical evidence later supports expansion.

## 29. ACTIVATE KIMI AS A CONTINUOUSLY AVAILABLE RESEARCH LANE
The existing implementation intentionally left unattended Kimi orchestration disabled until first campaign validation.
That was appropriate for initial rollout.
It is not the desired long-term state.
After reconfirming the existing adapter/governor/router smoke tests:
make Kimi continuously AVAILABLE to Fable.
This does NOT mean:
Kimi must continuously consume quota.
It means:
Fable may commission Kimi research whenever expected value justifies it.
Use the existing orchestration architecture.
Do not create a second parallel research operating system.

## 30. KIMI SUBSCRIPTION REALITY
Current subscription:
Kimi / Allegro — USD 99 for one month.
Current period began around:
`2026-09-15`
and the account UI shows the next monthly reset/renewal around:
`2026-10-15`.
The subscription is already paid.
Do not optimize for preserving unused quota at the end of the month.
Do not waste quota either.
Optimize for:
research value from the already-paid capacity.
No automatic:

* upgrade,
* renewal,
* additional quota purchase.

Those remain OWNER actions.

## 31. KIMI REAL QUOTA / USAGE MUST BE DISCOVERED
IMPORTANT:
The previous implementation concluded that the CLI exposes no direct usage query and therefore created a local ledger with conservative artificial limits.
The OWNER has now confirmed that the Kimi account UI DOES expose real quota/usage information.
Observed UI snapshot on 2026-09-15:

* plan/account UI: `Allegro`
* monthly credits reset monthly
* next automatic renewal/reset shown: `2026-10-15`
* total usage shown: approximately `0.01%`
* rolling 5-hour Code usage shown: approximately `0.32%`
* 5-hour reset timestamp visible in UI
* rolling 7-day Code usage shown: approximately `0.06%`
* 7-day reset timestamp visible in UI
* additional quota currently NOT activated

Treat these percentages only as an observation from that moment.
Do NOT hardcode them.
The key finding is:
an authoritative or near-authoritative usage source exists somewhere behind the account UI.
Investigate how to retrieve it safely and programmatically.

## 32. KIMI QUOTA DISCOVERY TASK
Before accepting the conclusion that only local usage estimates are possible, investigate read-only options in this order:

1. built-in Kimi CLI commands / diagnostics,
2. official Kimi documentation available to the installed client,
3. installed CLI source/package behaviour,
4. authenticated client state/cache,
5. network/API calls already used by the official CLI or account UI,
6. stable official endpoints used by the product.

Do NOT:

* leak OAuth tokens,
* log secrets,
* commit credentials,
* implement brittle credential scraping,
* bypass authentication/security controls.

Do not use invasive TLS interception merely to obtain usage statistics.
Prefer:
the same legitimate read-only endpoint/state already used by the official product.
If a stable usage source exists, implement a:
`kemi/kimi quota fetcher`
consistent with current architecture.
It should expose, where available:

* subscription plan,
* subscription period,
* monthly total usage,
* monthly reset timestamp,
* 5-hour usage,
* 5-hour reset timestamp,
* 7-day usage,
* 7-day reset timestamp,
* Kimi vs Code usage breakdown if available,
* authoritative source timestamp,
* fetch status.

Store normalized state in the existing reports/state architecture.

## 33. LOCAL KIMI LIMITS ARE FALLBACK GUARDRAILS, NOT CONTRACT LIMITS
Current locally imposed limits such as:

* `40 calls/day`
* `200 calls/week`
* CONSERVE at 70%

were useful rollout protections.
They are NOT OWNER Hard Rules.
They are NOT assumed to equal actual Kimi contractual limits.
Once reliable real quota telemetry exists:
prefer real capacity state.
Use local call-count limits only as:

* fallback,
* anomaly protection,
* runaway-loop protection.

Fable may adjust these conservative defaults based on measured provider behaviour and research yield.
Do not preserve an arbitrary low ceiling that wastes most of an already-paid subscription.
Do not remove runaway protection.

## 34. KIMI RESOURCE GUARDS MUST BE EVIDENCE-BASED
The existing Kimi research stack currently blocks research when D: free space is below approximately 80 GB.
This is not an OWNER Hard Rule.
Current reports indicated D: had approximately 68 GB free.
Audit actual research requirements:

* scratch disk,
* dataset size,
* temporary artifacts,
* memory,
* CPU,
* duration.

If 80 GB is unnecessarily conservative:
replace it with measured safety margins.
If research scratch data belongs elsewhere:
relocate temporary/cache workloads to an appropriate available volume.
Do NOT delete:

* canonical evidence,
* verdicts,
* immutable reports,
* trade streams,

to create space.
Disposable caches may be managed according to retention policy.
Research should not remain permanently disabled because of an arbitrary threshold.

## 35. FIX KIMI/AGENT INFRA DEFECTS WITHOUT MAKING THEM A BUSINESS BLOCKER
The existing implementation report identified an independent Claude-lane session fan-out defect where one ticket may create two sessions.
Investigate and repair it using normal safe engineering.
Do not let an unrelated agent-lane defect indefinitely block:

* portfolio evaluation,
* FTMO Demo,
* Kimi research,

if those activities can continue safely.

## 36. KIMI AUTHORSHIP AND R1
Kimi may originate a strategy.
A durable internal QuantMechanica research artifact is a valid R1 source.
Valid form:

```yaml
source_type: internal_research
source: QM-RESEARCH://2026-XXXX
source_author: Kimi
source_artifact: <canonical durable reference>
source_hash: <sha256>
```

`author = Kimi`
without a durable resolvable research artifact is NOT sufficient.
Preserve fail-closed provenance.

## 37. FABLE MAY ALSO ORIGINATE STRATEGIES
The OWNER explicitly authorizes Fable itself to originate new trading hypotheses.
QuantMechanica research is NOT restricted to ideas supplied by the OWNER.
Fable may:

* formulate a market hypothesis,
* commission deterministic exploratory analysis,
* ask Kimi to investigate,
* ask another provider to criticize,
* preregister the experiment,
* progress the idea toward a Strategy Card.

If current internal-source tooling is unnecessarily Kimi-specific:
generalize it safely so internal research may record an explicit author such as:

* Kimi,
* Fable,
* another authorized research agent,
* documented multi-agent collaboration.

The same provenance/hash/lineage requirements remain.

## 38. AUTONOMOUS EDGE DISCOVERY IS A CORE OBJECTIVE
QuantMechanica's existing external research programme has examined enormous numbers of sources.
External sources have not produced enough high-quality strategies.
Therefore:
external sources are no longer the boundary of QuantMechanica's strategy universe.
Fable and Kimi are explicitly expected to discover new edges.
They may ask:
What market behaviour could constitute an exploitable mechanical edge that QuantMechanica has never tested?
They may design experiments to answer that question.

## 39. VALID ORIGINS OF A NEW STRATEGY
A strategy may originate from:

* a book,
* a paper,
* a video,
* a trader,
* a commercial EA reconstruction,
* QuantMechanica test results,
* failed Strategy Cards,
* live data,
* Demo data,
* trade streams,
* parameter landscapes,
* statistical analysis,
* machine-learning-supported discovery,
* market microstructure reasoning,
* economic reasoning,
* an original Kimi hypothesis,
* an original Fable hypothesis,
* multi-agent synthesis.

No external human source is required for a genuinely internal discovery.
Its internal research artifact is the source.

## 40. DO NOT REDUCE AUTONOMOUS DISCOVERY TO RANDOM INDICATOR COMBINATIONS
Autonomous research does not mean:
randomly combine RSI + MA + ATR until something backtests well.
Prefer hypotheses involving meaningful market behaviours such as:

* session transitions,
* market opens/closes,
* liquidity changes,
* volatility compression,
* volatility expansion,
* trend persistence,
* trend exhaustion,
* breakout continuation,
* breakout failure,
* false breakouts,
* structural mean reversion,
* overnight effects,
* intraday inventory effects,
* opening auction behaviour,
* post-event behaviour,
* prior-day structure,
* range expansion,
* range contraction,
* cross-timeframe structure,
* gap behaviour,
* recurring regime transitions.

Pure empirical discoveries without an obvious prior mechanism are still allowed.
But they require stronger data-mining scrutiny.

## 41. MACHINE LEARNING IS ALLOWED IN RESEARCH
OWNER explicitly permits Machine Learning in the offline research process.
Kimi and deterministic research tooling may use:

* clustering,
* classification,
* regression,
* tree models,
* feature importance,
* interaction analysis,
* dimensionality reduction,
* anomaly detection,
* regime identification,
* unsupervised discovery,
* statistical learning.

Purpose:
discover robust candidate relationships.
Not:
deploy a black-box trading model.

## 42. MACHINE LEARNING REMAINS FORBIDDEN IN EA RUNTIME
Final Strategy Cards and EAs must remain mechanical.
Valid:
ML discovers:
Under A + B + C, outcome distribution changes materially.
Then:

* formulate mechanical rules,
* define parameters,
* preregister,
* implement deterministic EA,
* validate normally.

Invalid:
ML model outputs BUY/SELL during trading.
No:

* runtime inference,
* remote inference API,
* online learning,
* runtime retraining,
* opaque adaptive model dependency.

The EA must remain executable from its mechanical specification alone.

## 43. AUTONOMOUS RESEARCH LOOP
Use:
OBSERVE
→ ASK
→ HYPOTHESIZE
→ DESIGN EXPERIMENT
→ DISCOVER
→ MECHANIZE
→ ATTACK
→ PREREGISTER
→ TEST
→ LEARN
Where practical:
the hypothesis must exist before decisive validation data is examined.
Do not continuously modify a hypothesis after seeing holdout results and pretend it remained the same strategy.
Material change = new lineage/version.

## 44. OBSERVE
Use QuantMechanica's accumulated evidence.
Potential inputs:

* PASSes,
* economic FAILs,
* trade streams,
* symbol outcomes,
* sessions,
* holding periods,
* parameter sweeps,
* plateaus,
* walk-forward,
* stress,
* seeds,
* news tests,
* pattern-filter tests,
* portfolio rejections,
* live behaviour,
* Demo behaviour,
* correlations,
* Lessons Learned.

Keep separate:

* INFRA failures,
* setup failures,
* NO_REPORT,
* symbol/data failures,

from genuine economic failures.
Never teach Kimi that an infrastructure crash proves a trading idea is bad.

## 45. FAILURE MINING IS A FIRST-CLASS RESEARCH PROGRAMME
Most research systems study winners.
QuantMechanica has a large failed-strategy population.
Use it.
Search across economic failures for:

* recurring losing conditions,
* regime dependence,
* shared hidden factors,
* filters that repeatedly destroy edge,
* conditions where failed edges temporarily work,
* strategy families that fail identically,
* symbol-specific asymmetries,
* time-of-day effects,
* parameters that do not matter,
* failure clusters.

Ask:
What do thousands of failures collectively teach us about where an edge might exist?
Negative knowledge is valuable.

## 46. WHITE-SPACE RESEARCH
Continuously measure the research universe.
Ask:

* Which mechanisms dominate existing EAs?
* Which mechanisms are missing?
* Which sessions are underexplored?
* Which symbols are underexplored?
* Which holding durations are absent?
* Which portfolio risks remain concentrated?
* Which FTMO needs are poorly served?
* Which strategy families are overrepresented?
* Which rejected ideas suggest an unexplored conditional relationship?

Prioritize valuable white space.
Do not endlessly create cousins of the same breakout strategy.

## 47. FTMO GAP RESEARCH IS A MAJOR KIMI MISSION
FTMO is currently the larger strategic gap.
Use Kimi heavily to answer:
What type of mechanical edge is our FTMO book missing?
Analyze:

* current FTMO candidates,
* Demo trades,
* previous Demo results,
* failed candidates,
* DXZ strategies rejected for FTMO,
* frequency,
* holding duration,
* swap burden,
* spread sensitivity,
* intraday DD,
* losing streaks,
* recovery,
* session exposure,
* target progression,
* first-passage simulations,
* correlation,
* concentration.

Search for strategies that increase:
probability of successful Challenge completion
rather than merely standalone PF.

## 48. FTMO RESEARCH MAY INCLUDE
Explicitly permitted directions include:

* scalping,
* high-frequency-enough mechanical intraday systems,
* session systems,
* opening-range systems,
* short-duration momentum,
* mean reversion,
* volatility compression,
* volatility expansion,
* breakout,
* failed breakout,
* pullback,
* liquidity/session phenomena,
* trailing-stop systems,
* intraday reversal,
* range systems,
* hybrid mechanical systems.

No style is privileged.
Evidence decides.

## 49. EXTERNAL RESEARCH REMAINS USEFUL — BUT MEASURE ITS ROI
Continue external strategy research.
But after tens of thousands of sources:
do not automatically assume another 10,000 sources are the highest-value next action.
Measure:

* sources processed,
* mechanical strategies extracted,
* candidates reaching Q02,
* candidates reaching Q08,
* candidates reaching Q14,
* candidates entering books,
* resulting economic contribution.

Compare:
`EXTERNAL HARVEST ROI`
against
`INTERNAL DISCOVERY ROI`.
Allocate research capacity accordingly.

## 50. SOURCE RESEARCH AND INTERNAL DISCOVERY RUN IN PARALLEL
Maintain two complementary research programmes:
EXTERNAL EDGE HARVEST
Books, papers, videos, commercial systems, traders.
INTERNAL EDGE DISCOVERY
QuantMechanica's own market evidence and autonomous hypotheses.
Both ultimately produce:
mechanical Strategy Cards.
Both must face proper validation.

## 51. MECHANIZATION GATE BEFORE NORMAL VALIDATION
No ML or abstract discovery may proceed as a trading candidate until it can be written as exact mechanical logic.
Required:

* long entry,
* short entry,
* no-trade conditions,
* stop logic,
* exit logic,
* trailing logic where relevant,
* session rules,
* filters,
* parameter ranges,
* timeframe,
* symbol assumptions,
* risk rules,
* expected frequency,
* invalidation conditions.

Test:
Could Codex implement this EA correctly from the Strategy Card without access to the original ML model or Kimi conversation?
If NO:
research is incomplete.

## 52. CROSS-VENDOR ATTACK
Before promotion of an internally discovered candidate:
have another provider attempt to falsify it.
Creator and Critic should differ whenever possible.
For Kimi Creator:
Critic must not be Kimi.
For Fable/Claude Creator:
use an independent eligible provider.
Critic asks:

* data leakage?
* look-ahead?
* post-selection?
* multiple testing?
* tiny sample?
* one-symbol artifact?
* one-period artifact?
* parameter explosion?
* cost sensitivity?
* duplicate edge?
* hidden regime dependency?
* simpler null explanation?

Critic remains read-only.
Pipeline remains final judge.

## 53. PREREGISTRATION AND DATA-SNOOPING DEFENCE
Track:

* hypothesis count,
* hypothesis family,
* data used for discovery,
* symbols searched,
* timeframes searched,
* feature families,
* parameter ranges,
* holdouts consumed,
* variants attempted.

Separate:

* discovery,
* mechanization,
* selection,
* validation,
* holdout.

Do not repeatedly mine the same holdout and call it out-of-sample.
When a holdout becomes contaminated by repeated iteration:
mark it accordingly.
Preserve research lineage.

## 54. EXPERIMENT MEMORY
Do not create another disconnected database unless necessary.
Audit existing:

* SQLite,
* reports,
* research ledgers,
* evidence stores.

Extend additively.
Make it possible to query:

* what was tried,
* why,
* what failed,
* what succeeded,
* what was duplicate,
* what depended on a regime,
* what worked only on one symbol,
* what was overfit,
* which filters added value,
* which filters removed value,
* which hypotheses were already falsified.

Every material research conclusion should resolve to evidence.

## 55. RECENT ROBUST / COMMERCIAL REBUILD CENSUS
Perform a current exact census of recently rebuilt/reference EAs including at minimum:

* René Balke Time Range Breakout,
* Gold Reaper,
* other René Balke systems,
* ORB / range-breakout reconstructions,
* other recent robust/commercial/reference rebuilds.

Do not trust old Vault state.
Resolve each against current runtime.
For each provide:

* canonical EA ID,
* source,
* actual mechanics,
* implementation status,
* current gate,
* highest contiguous valid gate,
* current blocker,
* tested symbols,
* estimated remaining validation,
* DXZ suitability,
* FTMO suitability,
* duplicate/variant relationship.

## 56. NEW EDGE VS BETTER IMPLEMENTATION
Classify each rebuild:
A. NEW EDGE
B. EXISTING EDGE — BETTER IMPLEMENTATION
C. CONFIG / PARAMETER VARIANT
D. DUPLICATE
E. MATERIALLY DISTINCT DESPITE SIMILAR LABEL
Use deterministic evidence:

* rule signatures,
* signal timestamps,
* trade overlap,
* return correlation,
* holding profile,
* session exposure,
* regime behaviour.

A better implementation of an old edge may still be extremely valuable.
Do not discard it merely because it is not a new family.
But do not count clones as independent diversification.

## 57. VENUE-SPECIFIC FITNESS
Create explicit target fitness layers.
DXZ FITNESS
Optimize portfolio-level:

* sustainable return,
* drawdown,
* consistency,
* diversification,
* tail robustness,
* allocation/D-Score suitability,
* long-term capital attraction.

FTMO FITNESS
Optimize:

* Challenge survival,
* probability of eventual pass,
* daily-loss survival,
* total-loss survival,
* stable positive drift,
* time to target as a secondary objective,
* trade density,
* cost burden,
* swap burden,
* payout suitability.

OWNER priority for FTMO:
probability of success first, speed second.

## 58. CONTINUOUS PORTFOLIO RECOMPOSITION ENGINE
Build/improve a deterministic process that can evaluate book composition at any time.
Inputs:

* eligible candidate universe,
* incumbent portfolio,
* latest pipeline evidence,
* live evidence,
* Demo evidence,
* trade/equity streams,
* strategy mechanism,
* symbol exposure,
* venue constraints,
* operational readiness.

Outputs separately for DXZ and FTMO:

* KEEP / CHANGE,
* recommended roster,
* proposed weights,
* additions,
* removals,
* replacements,
* expected portfolio metrics,
* marginal contribution,
* uncertainty,
* operational risk.

Portfolio calculations should be deterministic.
AI interprets the result.

## 59. MATERIALITY / ANTI-CHURN
Weekly review does not imply weekly change.
Define an evidence-based materiality framework.
A proposed swap should quantify:

* expected improvement,
* statistical/economic confidence,
* downside risk,
* model uncertainty,
* live uncertainty,
* switching cost,
* operational complexity.

Tiny theoretical optimization should not cause unnecessary portfolio churn.

## 60. MISSION CONTROL — NEW PRIMARY VIEW
Remove:
`WAY TO 25`
Replace with:
BOOK EVOLUTION
DXZ SECTION
Show:

* current live book,
* sleeve count,
* risk allocation,
* current performance,
* DD,
* current portfolio estimates,
* candidate challengers,
* expected marginal value,
* proposed changes,
* current probation/new sleeves,
* next recomposition time,
* Fable recommendation,
* OWNER action if needed.

FTMO SECTION
Show:

* current account type,
* current Demo cycle,
* start date,
* validation day count,
* intended Challenge book,
* current Demo performance,
* daily-loss behaviour,
* total DD,
* estimated Challenge success metrics,
* target progression,
* current challengers,
* strongest blocker,
* next recomposition,
* recommendation:

`NOT READY`
`CONTINUE DEMO`
`RECOMPOSE`
`READY FOR OWNER REVIEW`
`BUY 100K 2-STEP RECOMMENDED`
RESEARCH SECTION
Show:

* active research programmes,
* Kimi campaigns,
* newly generated hypotheses,
* hypotheses under criticism,
* preregistered experiments,
* mechanized candidates,
* most important failed hypothesis lesson.

FACTORY SECTION
Show:

* useful pipeline frontier,
* bottlenecks,
* resource constraints,
* infra problems,
* compute utilization.

Candidate counts may be displayed.
Do not elevate them into business goals.

## 61. WEEKLY COMPANY OPERATING RHYTHM
MONDAY–FRIDAY

* factory validates candidates,
* research progresses,
* Kimi researches,
* Fable commissions new hypotheses,
* live evidence accumulates,
* Demo evidence accumulates,
* blockers repaired,
* portfolio analytics updated.

FRIDAY AFTER MARKET CLOSE
Create immutable weekly evidence cut.
Freeze/reconcile inputs for weekend portfolio analysis.
SATURDAY
Compute:

* DXZ incumbent vs challengers,
* FTMO incumbent vs challengers,
* portfolio alternatives,
* risk changes,
* marginal contribution,
* robustness.

Cross-review material proposals.
SATURDAY NIGHT / SUNDAY
Fable produces final venue recommendations.
Prepare all technical artifacts.
BEFORE MARKET OPEN
OWNER receives only required decisions/actions.
After OWNER action:
verify runtime identity and state.
Repeat every week.

## 62. FTMO CHALLENGE READINESS METRIC
Mission Control must maintain a living:
FTMO CHALLENGE READINESS
Do not reduce readiness to one number.
Include:

* current two-week Demo equivalence,
* Demo stability,
* first-passage simulations,
* daily-loss survival,
* max-loss survival,
* expected time,
* uncertainty,
* cost fidelity,
* density,
* concentration,
* rule compliance,
* runtime readiness,
* strongest failure mode.

Fable must explain:
Why do we believe this single paid Challenge is now worth purchasing?

## 63. CURRENT OFFICIAL FTMO RULES MUST BE VERIFIED
Before:

* paid purchase recommendation,
* major FTMO book rule change,
* operational deployment,

verify current official FTMO rules.
Bind current:

* account type,
* account size,
* targets,
* daily loss,
* max loss,
* trading-day requirements,
* news rules,
* overnight rules,
* weekend rules,
* leverage,
* instrument restrictions,
* relevant execution constraints.

Track source timestamp/freshness.
Do not rely indefinitely on an old rule snapshot.

## 64. LIVE AND MONEY AUTHORITY
Fable may autonomously:

* research,
* analyze,
* create hypotheses,
* route AI tasks,
* implement approved reversible system improvements,
* build portfolio alternatives,
* recommend final portfolio composition,
* prepare setfiles,
* prepare manifests,
* prepare deployment actions,
* prepare FTMO purchase analysis.

OWNER retains authority over:

* paid FTMO Challenge purchase,
* buying additional paid accounts,
* live AutoTrading activation,
* irreversible live account actions,
* other financial purchases unless separately delegated.

Make OWNER interaction minimal.
The desired operating model is:
Fable does the work.
OWNER receives:

* decision,
* evidence,
* recommendation,
* exact action.

## 65. VAULT = COMPANY DOCUMENTATION
The Company Reference Vault is the canonical company documentation.
It is NOT optional documentation.
If relevant company information is missing:
add it.
If current documentation contradicts actual architecture:
correct it.
If a decision exists only in chat:
record it canonically.
If an old rule is superseded:
mark it superseded and update current guidance.
Update where relevant:

* `_HOME`
* `START_HERE`
* `Current Objective`
* `Hard Rules`
* `Company Structure`
* `AI Agent Routing and Role Contracts`
* `Research Methodology`
* `Pipeline Overview`
* `Q15`
* `Q16`
* `Q17`
* `FTMO Campaign`
* `Lessons Learned`
* `Current Operating State`
* Mission Control documentation
* Kimi documentation
* research contracts.

Notion remains secondary where appropriate for:

* marketing,
* outward communication,
* complementary presentation.

Operational truth belongs in the canonical company systems.

## 66. DOCUMENTATION MUST EVOLVE WITH THE SYSTEM
Every material change should update:

* implementation,
* tests,
* decision record,
* canonical docs,
* Mission Control/read models where relevant,
* evidence.

A fresh Fable/Claude/Codex session should be able to reconstruct QuantMechanica without relying on OWNER chat history.

## 67. LESSONS MUST BECOME SYSTEM IMPROVEMENTS
When a recurring failure teaches something:
do not merely write prose.
Ask:
Can this lesson become a script, guard, preflight check, feature, dataset field or research exclusion?
Examples:

* repeated setup failures → preflight
* repeated duplicate strategies → deterministic similarity detection
* recurring symbol mismatch → registry check
* recurring overfit signature → research guard

Institutional memory should reduce repeated mistakes.

## 68. IMMEDIATE EXECUTION PLAN
Execute in this order.
PHASE A — CURRENT TRUTH RECONCILIATION
Produce one authoritative snapshot of:

* DXZ current live book,
* FTMO current Demo book,
* all currently valid candidates,
* recent robust rebuilds,
* current pipeline states,
* current AI quotas,
* Kimi state,
* current resource constraints,
* current documentation drift.

Reconcile contradictory historical candidate counts.
Do not preserve multiple simultaneous definitions of "qualified".
PHASE B — OWNER POLICY IMPLEMENTATION
Implement this directive's already-decided changes:

* remove Way to 25,
* remove fixed 25-candidate book trigger,
* continuous two-book model,
* weekly recomposition,
* remove mandatory min-lot Q17,
* remove fixed 14-day DXZ wait as universal hard block,
* replace hard portfolio caps with evidence-based portfolio risk analysis,
* controlled parallelism,
* FTMO two-week Demo requirement,
* one paid Challenge at a time,
* 100k/2-Step default,
* success probability over speed,
* scalping allowed,
* trailing stops allowed,
* ML research allowed,
* autonomous strategy ideation allowed,
* Fable/Kimi internal authorship allowed.

Do NOT ask OWNER to reapprove decisions already explicit here.
PHASE C — KIMI OPERATIONALIZATION
Do not rebuild Kimi.
Instead:

* re-run relevant smoke,
* enable continuously available research routing,
* investigate real quota telemetry,
* integrate authoritative usage if safely accessible,
* audit 80-GB research guard,
* launch first valuable research campaign.

PHASE D — MISSION CONTROL
Replace obsolete milestone views.
Implement:

* Book Evolution,
* FTMO Challenge Readiness,
* Research state,
* meaningful factory bottleneck information.

PHASE E — PORTFOLIO ENGINE
Make continuous portfolio evaluation operational.
Compute current best:

* DXZ book,
* FTMO Demo book.

Compare against incumbent.
PHASE F — FTMO ACCELERATION
Determine the real current FTMO bottleneck TODAY.
Do not blindly repeat August conclusions.
Build the strongest current FTMO Demo portfolio.
Identify:

* what is economically missing,
* what is operationally missing,
* what evidence is missing.

Commission Kimi research against the highest-value gap.
PHASE G — AUTONOMOUS EDGE DISCOVERY
Launch internal research.
Fable and Kimi may create original hypotheses.
The first campaign should favor high expected business value.
Current company priority suggests:
FTMO gap research
unless measured evidence shows another question has clearly larger expected value.
PHASE H — WEEKLY AUTOMATION
Implement recurring:
Friday evidence cut
→ Saturday analysis
→ cross-review
→ Sunday final Fable recommendation
→ OWNER handoff
→ verified operational state.

## 69. REQUIRED DURABLE OUTPUTS
Create/update durable artifacts consistent with current repo conventions.
At minimum:
`decisions/2026-09-15_owner_continuous_book_evolution.md`
`docs/ops/CONTINUOUS_BOOK_EVOLUTION.md`
`docs/ops/FTMO_DEMO_VALIDATION_CONTRACT.md`
`docs/ops/FTMO_CHALLENGE_READINESS.md`
`docs/research/AUTONOMOUS_EDGE_DISCOVERY.md`
`docs/ops/RULE_EFFECTIVENESS_AUDIT_2026-09.md`
current Kimi architecture documentation
Kimi quota-discovery evidence
Mission Control implementation/update
current robust-rebuild census
weekly recomposition contract
first Kimi research campaign receipt
documentation drift report.
Use existing canonical paths when equivalent artifacts already exist rather than creating duplicates.

## 70. TEST REQUIREMENTS
Regression-test all changed contracts.
At minimum test:

* Q15 no longer hard-blocked solely by `<25`,
* invalid/unqualified candidates still fail closed,
* Mission Control no longer treats 25 as objective,
* DXZ portfolio evaluation works with smaller valid pool,
* portfolio cap warnings do not silently become no-op risk analysis,
* Q17 no longer forces arbitrary min-lot,
* live authority remains protected,
* FTMO two-week Demo state tracked correctly,
* paid purchase cannot occur through automation,
* only one paid-Challenge policy represented,
* venue fitness remains separate,
* Kimi internal source remains fail-closed,
* Fable/internal author provenance works,
* ML research is allowed,
* ML runtime strategy remains rejected,
* Creator/Critic provider separation,
* Kimi real quota fetch failure falls back safely,
* no secret leakage,
* MT5 factory unaffected by Kimi failure,
* weekly recomposition is deterministic/reproducible from frozen inputs.

## 71. SAFETY / STOP CONDITIONS
This directive does NOT authorize:

* deleting historical verdicts,
* rewriting trade streams,
* fabricating evidence,
* bypassing candidate qualification,
* live AutoTrading without OWNER authority,
* automatic FTMO purchases,
* automatic subscription upgrades,
* hiding failed research,
* silently changing live book without proper authority.

If a genuine new RED decision appears:
prepare:

* issue,
* options,
* evidence,
* economic impact,
* recommendation,
* rollback.

Continue all unaffected work.
Do not stop the entire programme for one unrelated OWNER decision.

## 72. EXECUTIVE OWNER REPORTING
OWNER should not need to manually analyze the research universe.
Maintain a concise report answering:
DXZ
What is live?
Is there a better book?
What exactly should change?
Why?
Expected benefit?
Main risk?
OWNER action?
FTMO
What is running on Demo?
How representative is the Demo?
How close are we to rationally buying the 100k 2-Step Challenge?
What is the strongest remaining failure risk?
Would Fable spend the OWNER's Challenge fee TODAY?
Why / why not?
RESEARCH
What genuinely new edge hypotheses were created?
Which survived criticism?
Which failed?
What did failures teach?
Which new ideas matter for:

* DXZ,
* FTMO?

KIMI
Current subscription usage?
Current:

* monthly quota,
* 5h quota,
* 7d quota,

where retrievable?
Current research value generated?
Any reason to conserve?
FACTORY
What is the highest-value current bottleneck?
Is compute being allocated optimally?
Which process rule currently costs the most business value?

## 73. FINAL OPERATING PHILOSOPHY
QuantMechanica is not a backtesting project.
QuantMechanica is not an EA collection.
QuantMechanica is not a strategy-count project.
QuantMechanica is not a pipeline-drain project.
QuantMechanica is a systematic trading company.
The pipeline exists to prevent self-deception.
Research exists to discover edge.
Kimi and Fable are expected to create original trading knowledge.
The portfolio engine exists to turn validated edge into money.
DarwinexZero is the long-term allocation engine.
FTMO is the payout engine.
For DarwinexZero:
continuously improve the live production portfolio whenever material evidence supports improvement.
For FTMO:
prepare one paid 100k Challenge so thoroughly that its probability of success is as high as reasonably achievable; speed is secondary to not wasting paid attempts.
For research:
do not limit QuantMechanica to what other traders have already published.
The long-term evolution is:
external strategy harvesting
→ internal empirical learning
→ autonomous hypothesis generation
→ systematic falsification
→ mechanical validation
→ institutional research memory
→ continuously improving portfolios.
Final principles:
Do not optimize for more strategies.
Do not optimize for more activity.
Do not optimize for unused quota.
Do not optimize for arbitrary milestones.
Optimize for:
more genuine edge, less false discovery, better portfolios, higher expected economic value.
And:
the correct weekly portfolio decision may be to change nothing.
But:
the research system should never stop looking for something better.
