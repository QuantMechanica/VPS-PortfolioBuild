# OWNER follow-up directive 2026-09-15 — COMPANY KNOWLEDGE COMPLETENESS · STRATEGY UNIVERSE SYNC · SYSTEM GAP AUDIT (verbatim)

Received 2026-09-15 ~12:3xZ in the Claude orchestrator session
(https://claude.ai/code/session_01EbahMJqzhTCfpmWAPcTaoE), prefixed `ULTRACODE`, while Phase A of the master
directive (`owner_directive_verbatim.md`, same directory) was running. Transcribed verbatim; only heading levels
and code fences added. Execution timing per its own preamble: after the master directive is implemented or
materially progressed — scheduled as the closing phase (Phase I) of this programme; the read-only Strategy-Wiki
completeness measurement (§2) was started early because it is independent.

---

ULTRACODE
QUANTMECHANICA — FOLLOW-UP DIRECTIVE
COMPANY KNOWLEDGE COMPLETENESS · STRATEGY UNIVERSE SYNC · SYSTEM GAP AUDIT
Authority: OWNER
Execution timing: Run immediately after the Continuous Book Evolution / FTMO Acceleration / Autonomous Edge Discovery master directive has been implemented or materially progressed.
This is NOT a request to rebuild the architecture again.
The purpose is to verify that the new operating model is actually complete, internally consistent and durably documented.

## 1. PRIMARY QUESTION
After implementing the previous OWNER directive, answer:
Is QuantMechanica now operating as a coherent continuously learning trading company, or are there still architectural, documentation, research, portfolio, FTMO, DXZ or automation gaps that can materially slow or distort progress?
Do not answer this from documents alone.
Audit:

* repo,
* runtime,
* SQLite,
* scheduled tasks,
* Mission Control,
* reports,
* Company Reference Vault,
* current AI providers,
* current strategy universe.

## 2. STRATEGY CARD VAULT COMPLETENESS — HIGH PRIORITY
The current Strategy Wiki must NOT be assumed complete.
Audit the exact relationship between:

* canonical Repo Strategy Cards,
* raw/draft Cards,
* approved Cards,
* EA Registry,
* current pipeline universe,
* generated Strategy Wiki nodes in the Company Reference Vault.

Determine exact counts for:

* canonical Cards,
* valid Cards,
* Draft Cards,
* retired/rejected Cards,
* Cards with EA IDs,
* Cards without EA IDs,
* current pipeline EAs,
* Vault strategy projections,
* missing Vault projections,
* stale Vault projections,
* duplicate Vault projections,
* orphaned Vault projections.

Do not infer completeness from `_INDEX.md`.
Measure it.

## 3. EVERY CANONICAL STRATEGY MUST BE FINDABLE IN THE VAULT
The OWNER wants the Company Reference Vault to represent the complete company knowledge base.
Therefore:
every canonical Strategy Card must be discoverable from the Vault.
This does NOT mean maintaining a second manual Strategy Card copy.
Implement/finish the existing Strategy Wiki Sync concept as a deterministic generated projection.
Desired flow:
`EA Registry`
+
`Canonical Strategy Cards`
+
`Current Gate Readmodel`
+
`Report/Evidence Manifest`
+
`Research Source/Lineage`
→
`Generated Strategy Wiki Node`
→
`Rebuilt Wiki Index`
→
`Completeness + staleness lint`
Repo Card remains authoritative.
Vault Strategy Wiki node is the human/company knowledge projection.

## 4. REQUIRED FIELDS PER GENERATED STRATEGY NODE
Each Vault strategy projection should contain or resolve to at least:

* Strategy / EA ID
* Name
* Slug
* lifecycle status
* source type
* source / internal research ID
* author
* mechanical strategy summary
* strategy family
* key mechanism
* timeframe(s)
* intended / tested symbols
* long/short direction
* parameter family summary
* canonical Repo path
* Card hash
* source hash
* build identity where relevant
* current highest contiguous valid gate
* current pipeline status
* terminal verdict where applicable
* current blocker
* duplicate / clone / variant relationships
* parent/child lineage
* current DXZ status / relevance
* current FTMO status / relevance
* live/demo status if relevant
* evidence freshness
* last synchronization timestamp.

Do not invent a value when none exists.
Use explicit values such as:

* `NOT_EVALUATED`
* `UNKNOWN`
* `NOT_APPLICABLE`
* `EVIDENCE_MISSING`

rather than silently leaving ambiguity.

## 5. DO NOT SYNC GARBAGE AS IF IT WERE CANONICAL KNOWLEDGE
The system may contain thousands of:

* raw ideas,
* old imports,
* drafts,
* duplicates,
* rejected cards,
* stale lineages,
* historical experimental Cards.

Do not blindly make every file appear as a current approved strategy.
Define and document clear projection classes such as:

* ACTIVE / CANONICAL
* DRAFT
* RETIRED
* REJECTED
* DUPLICATE
* SUPERSEDED
* HISTORICAL

They may all be findable where useful.
But their status must be unmistakable.
The Vault should help a reader understand the strategy universe, not create an illusion that every historic idea is currently viable.

## 6. COMPLETENESS MUST BECOME A MACHINE CHECK
Implement a deterministic health check.
Conceptually:
`canonical_strategy_records`
vs.
`valid_vault_strategy_projections`
Report:

* missing,
* stale,
* hash mismatch,
* duplicate,
* orphan,
* invalid link,
* unresolved source,
* unresolved lineage.

The check should run automatically after relevant Strategy Card changes and/or on a scheduled cadence.
Expose the result in documentation/Mission Control health.
Target state:
`STRATEGY_WIKI_SYNC = GREEN`
when the canonical universe and Vault projection are consistent.
Do not rely on humans remembering to update `_INDEX.md`.

## 7. NEW STRATEGIES MUST APPEAR AUTOMATICALLY
Any future Strategy Card created by:

* external source extraction,
* Kimi,
* Fable,
* Codex,
* Antigravity,
* OWNER,
* another authorized research process,

should automatically enter the appropriate generated Vault projection lifecycle.
No manual Google Drive copy step.
The projection must be idempotent.
Same canonical inputs → same generated result.

## 8. SOURCE NODES AND RESEARCH NODES MUST ALSO BE COMPLETE ENOUGH TO EXPLAIN ORIGIN
A strategy without understandable provenance is poor company knowledge.
Audit whether strategy projections link correctly to:

* external source nodes,
* internal `QM-RESEARCH://...` artifacts,
* author,
* related research hypothesis,
* criticism/review,
* lineage.

Kimi/Fable internal research must be as navigable from the Vault as a book/video source.
A future reader should be able to answer:
Where did this strategy come from?
without searching old chat logs.

## 9. DUPLICATE / EDGE-LINEAGE MAP
QuantMechanica needs a company-wide view of strategy relationships.
Build or improve a deterministic lineage/duplicate map.
Identify:

* exact clone,
* close implementation clone,
* parameter variant,
* same edge / different implementation,
* materially different edge,
* child challenger,
* superseded strategy.

Use actual mechanics and deterministic behaviour where possible.
Names are insufficient.
This is particularly important for:

* Gold Reaper,
* René Balke systems,
* ORB,
* session breakouts,
* breakout families,
* XAU systems,
* other heavily represented strategy families.

Make these relationships visible in the Vault.

## 10. COMPANY DOCUMENTATION COMPLETENESS
Do not limit this audit to Strategy Cards.
The Vault is the complete company documentation.
Audit whether the following currently exist and match the real system:
COMPANY

* mission / North Star
* economic model
* DXZ purpose
* FTMO purpose
* authority model
* AI/provider roles

RESEARCH

* external research process
* internal edge discovery
* Kimi research
* Fable autonomous hypothesis generation
* ML research policy
* mechanization policy
* preregistration
* failure mining
* Lessons Learned

FACTORY

* Q00-Q17 current contracts
* pipeline operation
* evidence semantics
* deterministic truth model

PORTFOLIOS

* continuous DXZ evolution
* FTMO evolution
* weekly recomposition
* portfolio fitness methodology
* current risk policy
* live change authority

FTMO

* Demo validation contract
* Challenge readiness
* one paid Challenge policy
* current 100k/2-Step preference
* success probability priority
* current product/rule snapshot

OPERATIONS

* Mission Control
* quota governance
* Kimi quota
* backups
* live controls
* current scheduled automation.

Any meaningful current operating fact that exists only in code/chat but not in the company documentation should be documented.

## 11. SEARCH FOR OLD RULES THAT STILL SURVIVE IN CODE OR UI
The previous OWNER directive superseded several historical policies.
Search not only documentation but also:

* Python conditions,
* SQL,
* dashboard queries,
* scheduled jobs,
* gate guards,
* environment flags,
* configuration files,
* tests.

Specifically look for surviving assumptions such as:

* `>=25 candidates`
* "Way to 25"
* global pipeline drain before book analysis
* mandatory min-lot Q17
* mandatory fixed 14-day DXZ wait
* max 2 strategies per symbol
* max 3 per family
* absolute fixed correlation cap
* absolute HR16 single-development restriction
* hard legacy FTMO speed targets that conflict with success-probability priority.

Classify each occurrence:

* HISTORICAL ONLY
* STILL ACTIVE AND INTENTIONAL
* ACTIVE BUT OBSOLETE
* UNKNOWN

Remove/replace obsolete active logic safely.

## 12. WEEKLY RECOMPOSITION END-TO-END TEST
Prove that the new weekly operating model actually works.
Using frozen current data, run a dry-run end to end:
Friday evidence cut
→ candidate universe
→ DXZ fitness
→ FTMO fitness
→ incumbent comparison
→ alternative portfolios
→ materiality test
→ Fable recommendation
→ OWNER decision package.
Do NOT change live trading as part of this test.
Demonstrate that the workflow can conclude either:
`KEEP`
or
`CHANGE`
without being blocked by an arbitrary candidate-count condition.

## 13. FTMO DEMO END-TO-END TEST
Audit the current FTMO Demo process.
Verify that the system can answer:

* Which exact portfolio is under Demo validation?
* When did the representative two-week period begin?
* Has composition changed materially?
* Is the current evidence still representative?
* What is current daily loss / max DD / target progression?
* What is simulated Challenge survival?
* What is the strongest current failure mode?
* What remains before OWNER should buy a Challenge?

If this cannot be answered deterministically today:
fix the observability/data model.

## 14. FTMO DEMO MATERIAL-CHANGE SEMANTICS
Define a deterministic policy for when a portfolio change makes existing Demo evidence no longer representative enough.
Do NOT invent an excessively rigid rule.
Consider:

* sleeve added/removed,
* risk materially changed,
* strategy mechanics changed,
* compliance/news rules changed,
* execution product changed.

The goal is to avoid both extremes:

* resetting the two-week validation for every tiny change,
* pretending an entirely different portfolio has already been validated.

Create a recommended materiality contract and document it.
If the decision is economically consequential and no existing OWNER directive resolves it, present the recommendation to OWNER.

## 15. KIMI QUOTA TELEMETRY GAP
Continue the quota investigation from the master directive.
The account UI clearly exposes:

* total/month usage,
* rolling 5-hour usage,
* rolling 7-day usage,
* reset times.

Determine whether a stable legitimate read-only data source can be integrated.
Final desired state:
Mission Control shows actual Kimi capacity rather than only artificial local call counts.
If authoritative telemetry is technically unavailable:
document exactly why and retain the local ledger fallback.
Do not claim impossibility without proving the available client/UI paths were inspected.

## 16. KIMI RESEARCH MUST ACTUALLY RUN
Verify that Kimi has moved beyond "integration complete".
Check:

* Is the research lane enabled?
* Has at least one real campaign run?
* Did it produce a research artifact?
* Was it criticized cross-provider?
* Was the artifact sealed?
* Did it create a mechanical hypothesis or useful negative finding?
* Is it visible in experiment memory and Vault?

If no:
identify the exact blocker and remove it where authorized.
An integrated research provider that never researches creates no business value.

## 17. RESEARCH RESOURCE CAPACITY
Audit:

* D: disk guard,
* tester cache,
* research scratch paths,
* memory requirements,
* CPU thresholds.

The prior ~80 GB research guard must be justified by actual measurements.
Find the best safe storage/process architecture.
Do not let research remain blocked indefinitely by a threshold that was never empirically validated.
Do not threaten MT5/live stability to free resources.

## 18. AI ORCHESTRATION HEALTH
Audit current:

* Claude,
* Codex,
* Antigravity,
* Kimi,
* Creator/Critic/Formatter chain,
* task routing,
* quota governor.

Resolve known issues such as:

* duplicate session fan-out,
* double claims,
* stale tasks,
* provider fallbacks that silently reduce review independence.

Do not create a hierarchy war between AI providers.
Measure whether work is actually routed correctly.

## 19. CURRENT STRATEGY UNIVERSE ECONOMIC MAP
Once the Strategy Wiki is complete enough, create a generated overview of the current strategy universe.
Group by:

* strategy mechanism,
* holding duration,
* session,
* symbol/asset class,
* trend vs mean-reversion vs breakout etc.,
* frequency,
* DXZ fitness,
* FTMO fitness,
* pipeline status.

Use this to identify white space.
Example questions:

* Are 60% of candidates breakout derivatives?
* Do we have almost no mean-reversion?
* No short-duration FX systems?
* Too much Gold?
* Too little session diversification?
* Missing high-density FTMO systems?

This map should directly feed Kimi/Fable research prioritisation.

## 20. EXTERNAL SOURCE PROGRAMME ROI
QuantMechanica has processed or accumulated a very large external research universe.
Measure whether continued source harvesting remains high-value.
Generate:

* total sources considered,
* total Strategy Cards created,
* total candidates reaching Q02,
* Q08,
* Q14,
* portfolio admission,
* current economic contribution.

Compare with:

* internal autonomous research,
* commercial/rebuild programme,
* failure mining.

The objective is to intelligently allocate research effort.
Do not continue a programme merely because it has historically existed.

## 21. OPEN OWNER QUESTIONS — STRICT STANDARD
At completion, do NOT ask OWNER dozens of minor questions.
Only bring decisions that meet BOTH:

1. material economic/operational impact,
2. cannot reasonably be resolved under existing authority/current directives.

For each OWNER question provide:

* issue,
* current evidence,
* alternatives,
* expected impact,
* recommendation,
* rollback.

Maximum emphasis on decisions that materially affect:

* money,
* live risk,
* research speed,
* FTMO Challenge success,
* DXZ performance.

## 22. FINAL DELIVERABLE
Create:
`QUANTMECHANICA_COMPLETENESS_AND_GAP_AUDIT_2026-09-15.md`
Executive section must answer:
COMPANY KNOWLEDGE

* Is Vault complete enough?
* How many canonical strategies exist?
* How many are represented?
* What was fixed?

DXZ

* Is continuous weekly recomposition operational?
* Any blocker?

FTMO

* Is Demo validation operational?
* Current main blocker to a paid Challenge?

RESEARCH

* Is autonomous edge discovery actually operating?
* Is Kimi actually producing research?

ARCHITECTURE

* Which obsolete rules still existed?
* Which were removed?
* Which remain intentionally?

DOCUMENTATION

* Any remaining drift?

OWNER

* What genuinely requires OWNER action now?

Do not merely produce an audit report.
Where issues are reversible, authorized and safe:
FIX THEM.
Then report the final state.

## FINAL OWNER PRINCIPLE
The Company Reference should allow a new competent QuantMechanica agent to understand:

* what the company is trying to achieve,
* what strategies exist,
* where each strategy came from,
* how each strategy performed,
* where it is in validation,
* whether it matters for DXZ,
* whether it matters for FTMO,
* what the current books contain,
* what research is running,
* what failed before,
* and what should happen next.

Without requiring old chat history.
If the system cannot answer those questions:
the company knowledge layer is incomplete.
Fix it.
