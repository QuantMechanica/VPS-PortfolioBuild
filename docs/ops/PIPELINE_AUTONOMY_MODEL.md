# Pipeline Autonomy Model

Purpose: define what is fixed in the V5 pipeline, what Paperclip executes, and what Paperclip may improve.

For the *content* of the phase spec (gates, criteria, evidence per phase), see `PIPELINE_PHASE_SPEC.md`. This file governs *who may change it and how*.

## Current Decision

The V5 / V2.1 pipeline operates on the following 15-phase spine:

```text
G0 -> P1 -> P2 -> P3 -> P3.5 -> P4 -> P5 -> P5b -> P5c -> P6 -> P7 -> P8 -> P9 -> P9b -> P10 -> Live
```

Phase names and gate criteria are in `PIPELINE_PHASE_SPEC.md`. Paperclip executes and instruments this map. Paperclip does not silently invent a new testing process.

This supersedes the older 10-phase `Strategy Card → P1 Smoke → … → P8 DarwinexZero Demo → P9 Live → P10 Monitor` outline that appeared in the Notion `V5 Pipeline Design` page and earlier versions of this file. See `decisions/2026-04-25_pipeline_15_phase_override.md`.

## What We Give Paperclip

- Source queue and source-selection constraints
- Strategy Card template
- Pipeline phase gates (per `PIPELINE_PHASE_SPEC.md`)
- Evidence requirements
- MT5 / T1-T6 ownership rules
- Risk limits
- Website / dashboard export contract
- Hard rules from V1-V4 learnings

## What Paperclip Does Autonomously

- Research extracts Strategy Cards from one approved source at a time.
- CTO turns approved cards into technical specs.
- Development implements one EA at a time.
- Pipeline-Operator runs G0-P8 jobs on T1-T5.
- Quality-Tech and Quality-Business challenge PASS decisions.
- CEO decides gate progression up to P8.
- LiveOps executes approved P9b/P10/Live deploy manifests on T6.
- Observability-SRE watches health and pages risk.
- Controlling publishes dashboard KPIs.

## What Paperclip Cannot Do Alone

- Change the pipeline spec silently.
- Promote V1-V4 results into V5 PASS without re-test.
- Pass P9, P9b, or P10 without OWNER manifest approval.
- Deploy to T6 / live without manifest approval.
- Turn AutoTrading on for money-at-risk without OWNER approval.
- Call the project a hedge fund publicly without legal/compliance review.

## How Pipeline Changes Happen

1. R-and-D proposes a change with prior-art check.
2. CTO reviews technical validity.
3. Quality-Tech checks statistical / overfit risk.
4. CEO approves or rejects the process change.
5. Codex audits at phase boundary.
6. Documentation-KM updates `PIPELINE_PHASE_SPEC.md` here, the laptop `doc/pipeline-v2-1-detailed.md`, and the corresponding Notion page.
7. New decision entry in `decisions/`.

Until that sequence completes, the spine in `PIPELINE_PHASE_SPEC.md` remains binding.
