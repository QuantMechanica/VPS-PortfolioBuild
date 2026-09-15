# OWNER directive 2026-09-15 — Kimi integration, ML in offline research, internal R1 source (ULTRACODE)

- Author: OWNER (chat, 2026-09-15 ~09:5xZ, message headed "ULTRACODE / QUANTMECHANICA V5 — KIMI INTEGRATION & AUTONOMOUS
  EDGE DISCOVERY"), transcribed by Orchestrator Claude/Fable (session
  https://claude.ai/code/session_01EbahMJqzhTCfpmWAPcTaoE). The full directive text is preserved verbatim in
  `docs/ops/evidence/2026-09-15_kimi_integration/owner_directive_verbatim.md`; this file records the binding decisions.
- Decision id: `OWNER-DEC-KIMI-INTEGRATION-20260915`
- Status: BINDING. The OWNER instructed: "Do not escalate this interpretation back to OWNER as an unresolved question."

## Decisions (OWNER, binding)

1. **Kimi is a capability provider inside the existing Strategy Farm**, not a second orchestration system. Kimi CLI is
   installed; a USD 99 one-month Kimi subscription is active. No purchase, upgrade or renewal by any AI seat. The
   operational resource is quota/capacity/rate limits, not a USD 50 pay-per-token budget.
2. **Kimi may be the author and original source of a QuantMechanica-discovered strategy.** For an internally discovered
   edge the canonical Kimi research artifact is the source. R1 is satisfied by a durable, verifiable internal source
   record carrying at least: research id, author = Kimi, exact model, creation timestamp, originating task id, immutable
   artifact path / canonical reference, content hash, data/evidence provenance, hypothesis lineage, cross-vendor review
   receipt. Cards reference it as `QM-RESEARCH://<research_id>` (resolvable). `source = Kimi` without a resolvable artifact
   is invalid. External strategies keep the unchanged external attribution requirement.
3. **Machine learning is allowed in the offline research layer and stays forbidden in EA / trading logic.** The Hard Rule
   against ML is to be read as "NO ML IN THE EA OR ITS LIVE/BACKTEST DECISION ENGINE", not as a ban on ML as an offline
   research instrument. Before a candidate enters Q00 it must be reduced to explicit mechanical rules (finite parameters,
   bounded ranges, deterministic entry/exit/risk/filter logic, no inference API, no model file, no online learning, no
   retraining, no adaptive black box). Historical evidence is not altered.
4. **Fable decides which intelligence to use** per task (capability, expected research value, context size, independence,
   quota, latency, observed quality). Kimi is intended for deep quantitative research, autonomous edge discovery,
   large-context synthesis, cross-experiment analysis, ML/statistical exploration, hypothesis generation, research critique.
5. **RED boundaries unchanged**: no gate-threshold changes, no T_Live changes, no AutoTrading, no live deployment, no
   live-book changes, no destruction/rewriting of evidence, no silent reinterpretation of historic verdicts. Kimi gets no
   gate, live, deployment, verdict-write, T_Live or unrestricted-queue authority by default.
6. **Determinism-first stays binding for operational mechanics**; edge discovery is a research problem where deterministic
   data preparation → statistical/ML exploration → LLM interpretation → explicit mechanical hypothesis → deterministic
   validation is the required pattern. LLMs never compute metrics a script can compute.
7. **Creator → Critic → Formatter stays and extends**: a Kimi-authored hypothesis receives a non-Kimi critic; critics stay
   read-only; the deterministic pipeline remains the judge; an LLM "PASS" is never a pipeline PASS.
8. **Pre-Q00 "Internal Edge Discovery" layer** (no new Q-gate): OBSERVE → DISCOVER → HYPOTHESIZE → MECHANIZE → ATTACK →
   PRE-REGISTER → STRATEGY CARD → Q00–Q17 → LEARN, with search-history tracking against data snooping, preregistration
   before validation, and an experiment memory built additively on the existing SQLite/report architecture.
9. **Research objective**: novelty, independence, falsifiability, robustness, mechanizability, portfolio usefulness,
   reproducibility, not the number of strategies.

## Explicitly authorized by this directive

Adding Kimi as provider and its capabilities; Kimi authoring internal strategy research; canonical internal Kimi research
artifacts satisfying R1; updating R1 tooling for that source class; ML/statistical methods in offline edge discovery;
documenting that ML remains forbidden inside EAs; building the research tooling; annexing the canonical documentation.

## Required deliverables (OWNER list)

`KIMI_INTEGRATION_ARCHITECTURE.md`, `KIMI_EDGE_DISCOVERY_DESIGN.md`, `INTERNAL_RESEARCH_SOURCE_CONTRACT.md`, implementation
code/configuration, router integration, quota/subscription-state integration, Creator → Critic integration, R1
internal-source implementation, automated tests, Kimi smoke-test receipt, ML-research vs mechanical-EA policy update in
canonical documentation, architecture drift report, final implementation report.
