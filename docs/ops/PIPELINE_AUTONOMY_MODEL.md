# Pipeline Autonomy Model

Purpose: define what is fixed, what Paperclip executes, and what Paperclip may improve.

## Current Decision

Keep the 10-phase V5 pipeline spine for now:

```text
Strategy Card -> P1 Smoke -> P2 Baseline -> P3 Optimization -> P4 Selection -> P5 Walk-Forward -> P6 Robustness -> P7 Live Candidate -> P8 DarwinexZero Demo/Live Test -> P9 Live Activation -> P10 Portfolio Monitor
```

This is the operating map. Paperclip does not silently invent a new testing process.

## What We Give Paperclip

- Source queue and source-selection constraints
- Strategy Card template
- Pipeline phase gates
- Evidence requirements
- MT5/T1-T6 ownership rules
- Risk limits
- Website/dashboard export contract
- Hard rules from V1-V4 learnings

## What Paperclip Does Autonomously

- Research extracts Strategy Cards from one approved source at a time.
- CTO turns approved cards into technical specs.
- Development implements one EA at a time.
- Pipeline-Operator runs factory jobs on T1-T5.
- Quality-Tech and Quality-Business challenge PASS decisions.
- CEO decides gate progression.
- LiveOps executes approved T6/DarwinexZero deploy manifests.
- Observability-SRE watches health and pages risk.
- Controlling publishes dashboard KPIs.

## What Paperclip Cannot Do Alone

- Change the pipeline spec silently.
- Promote old V1-V4 results into V5 PASS without re-test.
- Deploy to T6/DarwinexZero without manifest approval.
- Turn AutoTrading on for money-at-risk without Fabian approval.
- Call the project a hedge fund publicly without legal/compliance review.

## How Pipeline Changes Happen

1. R-and-D proposes a change with prior-art check.
2. CTO reviews technical validity.
3. Quality-Tech checks statistical/overfit risk.
4. CEO approves or rejects the process change.
5. Codex audits at phase boundary.
6. Documentation-KM updates Notion and repo docs.

Until that sequence completes, the 10-phase map remains binding.
