---
name: Research pre-check — G0/P1 vs T6 field-gating pattern (QUA-395)
description: External overlap scan for proposed Pipeline-Operator prompt-scope patch separating Strategy Card extraction / P1 build phases from T6 deploy-manifest phase
type: research-memo
---

# Research Pre-Check Memo — Phase-Scoped Field Gating

Date: 2026-04-28
Requesting issue: [QUA-395](/QUA/issues/QUA-395) (parent: [QUA-394](/QUA/issues/QUA-394))
Requesting role: CTO
Author: Research (`7aef7a17-d010-4f6e-a198-4a8dc5deb40d`)
Scope: External-overlap survey on the proposed prompt/routing guard that blocks `ea_name`/`setfile_path`/`ea_id` requests during G0 Strategy Card extraction and P1 build preconditions, separating extraction/build phases from deploy-manifest phases.

## Verdict — GO

The pattern is a **textbook re-implementation** of the Build/Release/Run separation principle applied to LLM-agent prompt scope. Standard practice across at least a dozen well-known frameworks (CI/CD, MLOps, agent orchestration, algo-trading toolchains, IaC). Novelty delta is essentially zero at the architectural level. Adoption risk is **LOW**.

## Overlaps found (cited)

### Foundational principle

1. **The Twelve-Factor App § V. Build, release, run** — Adam Wiggins / Heroku (2011). https://12factor.net/build-release-run
   > "The build stage is a transform which converts a code repo into an executable bundle known as a build. […] The release stage takes the build produced by the build stage and combines it with the deploy's current config. […] Strict separation between the build, release, and run stages."

   Direct analogue to G0 (extraction) → P1 (build) → T6 (release+config+run). Each stage has a distinct allowed input set; cross-stage field requests are an anti-pattern.

### MLOps / model lifecycle

2. **MLflow Model Registry — Stage transitions** (Databricks). https://mlflow.org/docs/latest/model-registry.html
   Models transition `None → Staging → Production → Archived`. Production-stage requires a deployment-config payload that staging does not. Schema requirements differ per stage; the registry enforces this via the stage transition API.

3. **Kubeflow Pipelines — Typed component I/O** (Google/CNCF). https://www.kubeflow.org/docs/components/pipelines/v2/components/
   Components declare typed inputs/outputs at compile time. A training-stage component cannot consume a deploy-stage URI without an explicit edge in the pipeline DAG.

4. **dbt — manifest.json vs run_results.json** (dbt Labs). https://docs.getdbt.com/reference/artifacts/manifest-json
   dbt strictly separates compile-time artifact (`manifest.json`, project graph) from run-time artifact (`run_results.json`). Models cannot reference run-time artifacts during compilation; this is enforced by the parser.

### CI/CD

5. **GitHub Actions — Environment-scoped secrets** (GitHub). https://docs.github.com/en/actions/deployment/targeting-different-environments/managing-environments-for-deployment
   Secrets bound to `environment: production` are visible only to jobs that target that environment. Build-stage jobs cannot read deploy-stage secrets — phase-scoped capability.

6. **Apache Airflow — DAG-time vs task-time context** (Apache). https://airflow.apache.org/docs/apache-airflow/stable/core-concepts/dags.html
   Airflow forbids referencing task-time data (e.g., XCom return values) at DAG parse time. Enforced via Jinja templating evaluation order. Same architectural shape as "do not request T6 fields at G0 time."

### Infrastructure-as-Code

7. **Terraform — Plan vs Apply, data sources vs resources** (HashiCorp). https://developer.hashicorp.com/terraform/cli/commands/plan
   Plan phase reads via `data` blocks; apply phase mutates `resource` blocks. Depending on apply-time computed values at plan time is a documented anti-pattern (`depends_on` with computed unknowns).

### LLM agent orchestration (closest fit to our use case)

8. **LangGraph — State-conditional tool binding** (LangChain Inc.). https://langchain-ai.github.io/langgraph/concepts/low_level/
   Nodes can scope tool availability per state via `model.bind_tools(state_specific_tools)`. The graph topology guarantees a node never sees tools outside its phase. **This is the most direct analogue** for the proposed prompt-routing guard, but enforced as code rather than free-text prompt.

9. **Microsoft AutoGen — Per-agent function registration** (Microsoft Research). https://microsoft.github.io/autogen/0.2/docs/Use-Cases/agent_chat
   `ConversableAgent.register_function(...)` binds tools per agent role. A research-phase agent without `deploy_to_prod` cannot invoke it. Capability-scoped enforcement.

10. **Anthropic Model Context Protocol — Server-scoped tool registries** (Anthropic). https://spec.modelcontextprotocol.io/specification/server/tools/
    MCP servers declare available tools; clients can filter by metadata at session boundaries. Phase-scoped tool exposure at the protocol level.

11. **CrewAI — Role-scoped tools** (CrewAI Inc.). https://docs.crewai.com/concepts/tools
    Each `Agent` declares `tools=[...]`; tools are bound to role definitions. Same pattern at the role level.

### Algo-trading toolchains (domain-specific)

12. **MetaTrader 4/5 — `.mq5` source vs `.ex5` binary vs `.set` parameter file vs broker terminal config** (MetaQuotes). https://www.mql5.com/en/docs/development_environment/expert_advisors and https://www.mql5.com/en/articles/21
    MetaTrader treats source code, compiled binary, parameter set-files, and live broker config as four distinct artifact types with different file extensions, different editors, and different deployment paths (Experts/, Files/, Profiles/, Templates/). The QM `ea_name`/`setfile_path` fields land at the `.ex5`/`.set` layer — exactly the artifact-level analogue to our T6 deploy phase. **The QM phase split mirrors MetaTrader's own artifact split.**

13. **QuantConnect / LEAN — Research vs Algorithm vs Live deployment** (QuantConnect Corp.). https://www.quantconnect.com/docs/v2/writing-algorithms
    Research notebooks (read-only data exploration via `QuantBook`), `QCAlgorithm` class (backtest + live with same code path), live deployment node (separate brokerage config). The brokerage-credentials API is unavailable inside the algorithm class; you configure it externally. Three-phase split.

14. **Backtrader — Cerebro vs Strategy vs Broker** (Daniel Rodriguez). https://www.backtrader.com/docu/cerebro/
    `Strategy` subclasses cannot access broker credentials directly; they're injected by `Cerebro.addbroker(...)` from the harness. Phase-separation enforced by class boundary.

## Novelty delta — what's actually new in the QM patch

The QM patch applies phase-scoped capability gating **at the free-text agent prompt level**, not at the code/API/registry level. Among the closest analogues:

- LangGraph / AutoGen / MCP / CrewAI all enforce at the agent-definition / tool-registry layer. Retrofitting the same guard into a free-text role prompt without modifying the tool registry is a less rigorous but more accessible enforcement layer.
- 12-Factor / MLflow / dbt / Airflow / Terraform / GitHub Actions all enforce at the system/artifact layer with parser/runtime checks.
- MetaTrader / QuantConnect / Backtrader enforce via artifact-type and class boundaries.

**The proposed QM patch is a soft, prompt-level fail-soft layer** that complements (does not replace) the upstream issue-thread schema. It's the cheapest possible guard that prevents Pipeline-Operator from spinning when an issue carries G0/P1 scope only. Equivalent in shape to all 14 references above; novel only in the implementation surface (LLM role-prompt text vs code).

## Standard method's limitation that motivates our version

- LangGraph/AutoGen-style hard scoping requires Pipeline-Operator's tool registry to declare phase-aware tools, which is a larger surgery than a prompt-line patch. Not blocked, but not on the immediate roadmap.
- Issue-thread schema enforcement at the Paperclip layer (e.g., reject T6 fields on a G0-class issue at API time) would be the rigorous fix but lives outside CTO's scope (Paperclip platform, not QM company prompts).
- The free-text prompt patch is the lowest-friction, in-scope-for-CTO mitigation. It loses on rigor (a malformed model could ignore the guard) but wins on speed-to-fix and zero coupling to Paperclip platform changes.

## Adoption risk — LOW

- Pattern is well-established (12-Factor, MLflow, LangGraph, MetaTrader artifact split).
- The QM patch lives in a single role-prompt file (`paperclip-prompts/pipeline-operator.md`) and changes prompt copy, not control flow. Reversible.
- Failure mode is graceful: if the prompt fails to gate a G0/P1 request that includes a T6 field, the agent behaves as it does today (i.e., the QUA-342 spin pattern). It cannot be made worse by this patch.
- No new abstractions, no new artifact types, no new public API.

## Recommendation — GO for the CTO patch

CTO is cleared to:

1. Land the prompt-scope patch on `paperclip-prompts/pipeline-operator.md` clarifying that during G0 Strategy Card extraction and P1 build preconditions, only the Strategy Card header fields (`strategy_id`, slug, source citation) are required — `ea_name`, `setfile_path`, `ea_id` are T6-only and must NOT be requested or spun on at G0/P1.
2. File a corresponding DL-NNN entry citing the 14 references above as basis for the separation-of-phases principle (suggest naming pattern: "G0/P1 vs T6 prompt-scope guard").
3. If CTO wants stronger enforcement later, the upgrade path is LangGraph-style state-conditional tool binding at the Pipeline-Operator orchestration layer — not in scope for this patch.

No `request_confirmation` to OWNER required strictly on overlap grounds; the pattern is well-precedented. Confirmation is still warranted on the broadened-autonomy rule per AGENTS.md "Pre-flight rule for prompt patches" if CTO judges the change beyond the DL-aligned threshold.

## Sources cited (concrete)

| # | Framework | Reference |
|---|---|---|
| 1 | The Twelve-Factor App § V | https://12factor.net/build-release-run |
| 2 | MLflow Model Registry | https://mlflow.org/docs/latest/model-registry.html |
| 3 | Kubeflow Pipelines components | https://www.kubeflow.org/docs/components/pipelines/v2/components/ |
| 4 | dbt manifest.json | https://docs.getdbt.com/reference/artifacts/manifest-json |
| 5 | GitHub Actions environments | https://docs.github.com/en/actions/deployment/targeting-different-environments/managing-environments-for-deployment |
| 6 | Apache Airflow DAGs | https://airflow.apache.org/docs/apache-airflow/stable/core-concepts/dags.html |
| 7 | Terraform plan/apply | https://developer.hashicorp.com/terraform/cli/commands/plan |
| 8 | LangGraph low-level | https://langchain-ai.github.io/langgraph/concepts/low_level/ |
| 9 | Microsoft AutoGen | https://microsoft.github.io/autogen/0.2/docs/Use-Cases/agent_chat |
| 10 | Anthropic MCP tools | https://spec.modelcontextprotocol.io/specification/server/tools/ |
| 11 | CrewAI tools | https://docs.crewai.com/concepts/tools |
| 12 | MetaTrader MQL5 EA docs | https://www.mql5.com/en/docs/development_environment/expert_advisors |
| 13 | QuantConnect docs | https://www.quantconnect.com/docs/v2/writing-algorithms |
| 14 | Backtrader Cerebro | https://www.backtrader.com/docu/cerebro/ |

— Research (`7aef7a17-d010-4f6e-a198-4a8dc5deb40d`), 2026-04-28.
